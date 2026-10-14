#!/usr/bin/env python3
"""Run the Duskfall probe without anybody typing anything.

The beta client is withdrawn on 2026-10-21. Seven of the eight Phase 1
questions need a running client, and one of them, the only one the whole
audio-led product rests on, cannot be answered from Lua at all: the client can
report that it AGREED to play a sound, which is a proxy for audibility and not
the thing. So the probe plays known sounds inside windows it timestamps, and
this script records the speaker output and measures them.

    tools/probe.py arm      write the autorun flag, then start the game
    tools/probe.py watch    record audio and wait for the probe to finish
    tools/probe.py report   print the results, audio included
    tools/probe.py run      arm, watch, report

The only step left for a human is launching the client and getting a character
into the world. Everything after that happens by itself.
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)

WOW = ("/home/mycomputer/Games/battlenet/pfx/drive_c/Program Files (x86)"
       "/World of Warcraft/_classic_beta_")
SV_DIR_GLOB = os.path.join(WOW, "WTF", "Account")
OUT_DIR = os.path.join(REPO, "probe-results")

# Every window the probe plays is 7 seconds, of which the last half second is a
# fade. Measuring the middle avoids both the attack and the stop.
WINDOW_TRIM = 1.0


def sv_path():
    """The account-level SavedVariables file the addon writes.

    Account names are of the form 916451#1 and there can be more than one, so
    this picks the most recently touched rather than assuming.
    """
    candidates = []
    for entry in os.listdir(SV_DIR_GLOB):
        d = os.path.join(SV_DIR_GLOB, entry, "SavedVariables")
        if os.path.isdir(d):
            candidates.append(d)
    if not candidates:
        sys.exit("no SavedVariables directory under %s" % SV_DIR_GLOB)
    candidates.sort(key=os.path.getmtime, reverse=True)
    return os.path.join(candidates[0], "Duskfall.lua")


def read_sv(path, global_name="DuskfallDB"):
    if not os.path.exists(path):
        return None
    out = subprocess.run(["lua", os.path.join(HERE, "sv2json.lua"), path, global_name],
                         capture_output=True, text=True)
    if out.returncode != 0:
        return None
    try:
        return json.loads(out.stdout)
    except json.JSONDecodeError:
        return None


def serialise(value, indent=1):
    """Write a Python value back out as the Lua the client expects.

    The client rewrites this file wholesale on logout, so the formatting only
    has to be loadable, not pretty. Keys are quoted unconditionally because a
    saved setting could legally be named `end`.
    """
    pad = "\t" * indent
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return repr(value)
    if isinstance(value, str):
        return '"%s"' % value.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
    if isinstance(value, list):
        items = ["%s%s," % (pad, serialise(v, indent + 1)) for v in value]
        return "{\n%s\n%s}" % ("\n".join(items), "\t" * (indent - 1))
    if isinstance(value, dict):
        items = []
        for k in sorted(value, key=str):
            items.append('%s["%s"] = %s,' % (pad, k, serialise(value[k], indent + 1)))
        return "{\n%s\n%s}" % ("\n".join(items), "\t" * (indent - 1))
    return "nil"


def stable(path, seconds=4.0):
    """True if the file has not been written for a while, so nothing is mid-write."""
    if not os.path.exists(path):
        return True
    return time.time() - os.path.getmtime(path) > seconds


def arm(quiet=False):
    path = sv_path()
    db = read_sv(path) or {}

    if os.path.exists(path) and not os.path.exists(path + ".preprobe"):
        shutil.copy2(path, path + ".preprobe")
        print("backed up existing settings to %s.preprobe" % path)

    db["probe"] = {"autorun": True, "results": {}, "order": [], "armedAt": int(time.time())}
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        f.write("-- written by tools/probe.py, %s\n" % time.strftime("%Y-%m-%d %H:%M:%S"))
        f.write("DuskfallDB = %s\n" % serialise(db))
    os.replace(tmp, path)
    if not quiet:
        print("armed: %s" % path)
        print("the probe will run itself once a character is in the world.")
    return path


def default_monitor():
    """The PulseAudio monitor name of whatever sink is currently the default.

    ffmpeg's pulse input is used rather than pw-record because pw-record's
    stream.capture.sink property did not take on this box: it attached to the
    motherboard analog capture instead and recorded a flat -72 dB noise floor,
    which would have read as "the game is silent" for every window. Verified
    the other way before trusting it: ffmpeg on this monitor name captured the
    running client at -39.5 dB RMS.
    """
    sink_id = None
    out = subprocess.run(["wpctl", "status"], capture_output=True, text=True).stdout
    in_sinks = False
    for line in out.splitlines():
        if "Sinks:" in line:
            in_sinks = True
            continue
        if in_sinks:
            if "Sources:" in line:
                break
            m = re.search(r"\*\s+(\d+)\.", line)
            if m:
                sink_id = m.group(1)
    if not sink_id:
        sys.exit("could not find the default sink in wpctl status")

    info = subprocess.run(["wpctl", "inspect", sink_id], capture_output=True, text=True).stdout
    m = re.search(r'node\.name = "([^"]+)"', info)
    if not m:
        sys.exit("could not read node.name for sink %s" % sink_id)
    return m.group(1) + ".monitor"


def watch(timeout=900):
    """Record the speaker output until the probe says it is done."""
    os.makedirs(OUT_DIR, exist_ok=True)
    wav = os.path.join(OUT_DIR, "capture.wav")
    path = sv_path()

    sink = default_monitor()
    started = time.time()
    rec = subprocess.Popen(
        ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
         "-f", "pulse", "-i", sink, "-ar", "48000", "-ac", "2", wav],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    print("recording %s to %s (started at epoch %d)" % (sink, wav, int(started)))
    with open(os.path.join(OUT_DIR, "capture.json"), "w") as f:
        json.dump({"startedAt": started, "wav": wav, "sink": sink}, f)

    print("waiting for the probe. Log out to character select and back in.")
    print("(the flag is re-armed automatically whenever the client overwrites it)")
    last_stage = None
    try:
        while time.time() - started < timeout:
            time.sleep(3)
            db = read_sv(path)
            probe = (db or {}).get("probe") or {}
            stage = probe.get("stage")

            if stage != last_stage:
                print("  stage: %s" % (stage or "not started"))
                last_stage = stage

            if stage == "done":
                time.sleep(3)
                print("probe finished after %ds" % (time.time() - started))
                return True

            # The client writes SavedVariables from memory on every /reload and
            # on logout, so a flag written while it is running is simply
            # overwritten. Rather than ask for the one moment where that is not
            # true, re-arm whenever the file comes back without the flag and has
            # stopped changing. The sticking point is character select: nothing
            # writes there, and the addon reads the file on the way into the
            # world. Stop once any stage exists, because the probe is running.
            if stage is None and not probe.get("autorun") and stable(path):
                arm(quiet=True)
                print("  re-armed")

        print("timed out after %ds" % timeout)
        return False
    finally:
        rec.terminate()
        try:
            rec.wait(timeout=10)
        except subprocess.TimeoutExpired:
            rec.kill()


def rms_db(wav, start, length):
    """Mean RMS of a slice, in dBFS. -inf becomes -120."""
    if length <= 0:
        return None
    out = subprocess.run(
        ["sox", wav, "-n", "trim", "%.3f" % start, "%.3f" % length, "stats"],
        capture_output=True, text=True).stderr
    m = re.search(r"RMS lev dB\s+(-?[\d.]+|-inf)", out)
    if not m:
        return None
    return -120.0 if m.group(1) == "-inf" else float(m.group(1))


def report():
    path = sv_path()
    db = read_sv(path)
    if not db or not db.get("probe"):
        sys.exit("no probe results in %s" % path)
    P = db["probe"]

    print("\nDuskfall probe, build %s\n" % (
        (P.get("results") or {}).get("geometry", {}).get("build", "unknown")))

    order = P.get("order") or sorted(P.get("results") or {})
    width = max([len(k) for k in order] + [10])
    for key in order:
        r = (P.get("results") or {}).get(key)
        if not r:
            continue
        print("  %-*s  %-8s %s" % (width, key, r.get("verdict"), r.get("detail")))

    audio = P.get("audio")
    if not audio or not audio.get("windows"):
        print("\nno audio windows recorded.")
        return

    capfile = os.path.join(OUT_DIR, "capture.json")
    wav = os.path.join(OUT_DIR, "capture.wav")
    if not (os.path.exists(capfile) and os.path.exists(wav)):
        print("\naudio windows were played but nothing was recorded. "
              "Run `tools/probe.py watch` next time.")
        return
    cap = json.load(open(capfile))

    print("\naudio, measured off the speaker output:\n")
    print("  %-20s %-9s %-9s %s" % ("window", "willPlay", "RMS dBFS", "note"))
    levels = {}
    for w in audio["windows"]:
        offset = w["t0"] - cap["startedAt"] + WINDOW_TRIM
        length = max(0.0, (w.get("t1", w["t0"]) - w["t0"]) - 2 * WINDOW_TRIM)
        level = rms_db(wav, offset, length) if offset >= 0 and length > 0 else None
        levels[w["name"]] = level
        print("  %-20s %-9s %-9s %s" % (
            w["name"], w.get("willPlay"),
            "n/a" if level is None else "%.1f" % level,
            "%s on %s" % (w.get("file"), w.get("channel")) if w.get("file") else "silence"))

    base = levels.get("baseline")
    control = levels.get("control_master")
    answer = levels.get("ambience_nomusic")
    print()
    if base is None or control is None or answer is None:
        print("  VERDICT: unknown. A window is missing, so nothing is comparable.")
        return

    # A negative result needs a positive control. If the control window is not
    # clearly louder than silence, the recording never captured the game at all
    # and a quiet answer window says nothing about ambience.
    if control - base < 6.0:
        print("  VERDICT: unknown. The control (%.1f dB) is not above the baseline "
              "(%.1f dB), so the recording is not capturing the game. "
              "Check the default sink." % (control, base))
        return

    if answer - base >= 6.0:
        print("  VERDICT: ambience SURVIVES Sound_EnableMusic=0. "
              "Answer %.1f dB vs baseline %.1f dB, control %.1f dB."
              % (answer, base, control))
    else:
        print("  VERDICT: ambience is SILENCED with the music. "
              "Answer %.1f dB vs baseline %.1f dB, while the control reached %.1f dB. "
              "The ambience-led product thesis needs rebuilding."
              % (answer, base, control))


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("command", choices=["arm", "watch", "report", "run", "path"])
    ap.add_argument("--timeout", type=int, default=900)
    args = ap.parse_args()

    if args.command == "path":
        print(sv_path())
    elif args.command == "arm":
        arm()
    elif args.command == "watch":
        watch(args.timeout)
    elif args.command == "report":
        report()
    elif args.command == "run":
        arm()
        if watch(args.timeout):
            report()


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Check every client API the addon uses against the client binary, headless.

Why this exists: the beta client is withdrawn on 2026-10-21 and the next one
lands on 2026-11-04. For those two weeks there is no way to find out whether an
API we call exists on this build, and "Unknown frame type 'ModelSceneFrame'"
already cost one wasted probe round. The names are in the executable, so the
question can be answered without logging in at all.

What it does:
  1. Pulls every global, C_ namespace member and widget method the addon calls
     out of the Lua source.
  2. Looks each one up in the strings of WowB.exe.
  3. Writes test/api-manifest.txt, which the suite then checks against, so the
     answer survives the client being uninstalled.

How a name appears in the binary matters, and the naive matcher is wrong. Some
are registered as a bare name ("Hide"), some only ever appear inside a usage
string ("Usage: local x, y = self:GetCenter()"). Matching only bare lines
reports GetCenter and GetPoint as absent, which they are not. So a name counts
as present if it appears as a whole line OR immediately before an open paren.

What it CANNOT see, and this is the limit of the method rather than a result:
anything implemented in the client's own Lua rather than in C. FrameXML lives
in the data archives, not the executable, so ReloadUI, SlashCmdList,
UISpecialFrames, CreateColor, Enum and the font objects are all genuinely
absent from the strings and are listed separately as unverifiable here.

Controls run on every invocation and the script refuses to write a manifest if
they fail: five APIs that must be found, four fabricated names that must not.
A zero from a broken method is worth nothing, and a scan that quietly stopped
working would otherwise read as "the addon calls nothing that exists".

Usage: api_audit.py [--exe PATH] [--write]
"""
import argparse
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ADDON = os.path.join(ROOT, "ComfyRain")
MANIFEST = os.path.join(ROOT, "test", "api-manifest.txt")

DEFAULT_EXE = os.path.expanduser(
    "~/Games/battlenet/pfx/drive_c/Program Files (x86)/"
    "World of Warcraft/_classic_beta_/WowB.exe")

# Must be found. If one of these misses, the scan is broken and every other
# answer it gave is an artifact.
PRESENT_CONTROLS = ["GetUnitSpeed", "CreateFrame", "SetCVar",
                    "GetCenter", "GetPoint"]
# Must not be found. Catches a matcher so loose it says yes to anything.
ABSENT_CONTROLS = ["GetBananaCount", "ComfyRainIsReal",
                   "SetWeatherForReal", "GetPointlessThing"]

# Implemented in the client's own Lua (FrameXML), which is not in the
# executable. Being absent from the strings says nothing about these.
LUA_SIDE = {
    "ReloadUI", "SlashCmdList", "UISpecialFrames", "CreateColor", "Enum",
    "ChatFontNormal", "AddSearchTags", "Settings", "GameTooltip", "Minimap",
    "UIParent", "WorldFrame", "GetAddOnMetadata", "SOUNDKIT",
    # Settings.* is the Blizzard options API, and SetBackdrop comes from
    # BackdropTemplate. Both being absent here is a confirmation rather than a
    # surprise: it is exactly why every call to them in this addon is pcall'd
    # and has a hand-drawn fallback behind it.
    "RegisterAddOnCategory", "RegisterCanvasLayoutCategory", "SetBackdrop",
    # Vector2DMixin, on the object C_Map.GetPlayerMapPosition returns. The
    # function is in the executable and the mixin method on its result is not,
    # which is why MapPos() tries GetXY and then falls back on .x / .y.
    "GetXY",
}

# Methods the addon defines on its own widgets. Not client API at all.
OURS = {"Set", "SetLabel", "SetOn", "SetSelected", "SetIcon", "Type", "Press",
        "SetLabelText",
        # Our own saved variables, and the two we migrate from.
        "ComfyRainDB", "DuskfallDB", "AlwaysRainDB"}

# Lua standard library and language globals, which are not client API either.
STDLIB = {
    "assert", "collectgarbage", "error", "getfenv", "getmetatable", "ipairs",
    "load", "loadstring", "next", "pairs", "pcall", "print", "rawequal",
    "rawget", "rawlen", "rawset", "select", "setfenv", "setmetatable",
    "tonumber", "tostring", "type", "unpack", "xpcall", "math", "string",
    "table", "os", "coroutine", "debug", "bit", "time", "date", "difftime",
    "format", "strsplit", "strjoin", "wipe", "tinsert", "tremove", "sort",
    "max", "min", "abs", "floor", "ceil",
}


def source():
    out = []
    for name in sorted(os.listdir(ADDON)):
        if name.endswith(".lua"):
            with open(os.path.join(ADDON, name), encoding="utf-8") as fh:
                out.append(fh.read())
    return "\n".join(out)


def strip_comments_and_strings(text):
    """Only what the addon actually CALLS, not what it talks about.

    Every one of these files carries long comment blocks naming APIs that were
    considered and rejected, and the chat strings name commands. Counting those
    would audit the prose.
    """
    text = re.sub(r"--\[\[.*?\]\]", " ", text, flags=re.S)
    text = re.sub(r"--[^\n]*", " ", text)
    text = re.sub(r'"(?:[^"\\\n]|\\.)*"', '""', text)
    text = re.sub(r"'(?:[^'\\\n]|\\.)*'", "''", text)
    return text


def used(text):
    globals_ = set(re.findall(r"(?<![\w.:])([A-Z][A-Za-z0-9_]{2,})\s*\(", text))
    globals_ |= set(re.findall(r"(?<![\w.:])(C_[A-Za-z]+)\.", text))
    namespaced = set(re.findall(r"(?<![\w.:])(C_[A-Za-z]+\.[A-Za-z0-9_]+)", text))
    methods = set(re.findall(r":([A-Z][A-Za-z0-9_]{2,})\s*\(", text))

    # An API guarded by pcall is REFERENCED, not called, so the patterns above
    # miss it - and the guarded ones are exactly the APIs we are least sure
    # exist. pcall(Screenshot) and pcall(panel.SetBackdrop, ...) are the two
    # shapes this addon uses, and both are the ones worth auditing most.
    globals_ |= set(re.findall(r"pcall\(\s*([A-Z][A-Za-z0-9_]{2,})\s*[,)]", text))
    methods |= set(re.findall(r"pcall\(\s*[\w.]+\.([A-Z][A-Za-z0-9_]{2,})\s*,", text))
    methods |= set(re.findall(r"type\(\s*\w+\.([A-Z][A-Za-z0-9_]{2,})\s*\)", text))
    globals_ |= set(re.findall(r"type\(\s*([A-Z][A-Za-z0-9_]{2,})\s*\)", text))
    return globals_, namespaced, methods


def load_strings(exe):
    raw = subprocess.run(["strings", "-n", "4", exe],
                         capture_output=True, text=True, check=True).stdout
    whole, called = set(), set()
    for line in raw.splitlines():
        whole.add(line)
        for m in re.finditer(r"(?<![A-Za-z0-9_])([A-Za-z_][A-Za-z0-9_]*)\(", line):
            called.add(m.group(1))
    return whole, called


def addon_api(text):
    globals_, namespaced, methods = used(text)
    names = {n for n in globals_ | namespaced | methods
             if n not in STDLIB and n not in OURS}
    # Anything the addon declares itself is not client API.
    local = set(re.findall(r"(?:local\s+)?function\s+([A-Za-z_][\w.]*)", text))
    local |= set(re.findall(r"local\s+([A-Za-z_]\w*)\s*=\s*function", text))
    local |= {n.split(".")[-1] for n in local}
    return {n for n in names if n not in local}


def read_manifest():
    if not os.path.exists(MANIFEST):
        sys.exit("no %s - run this with --write against a client binary first"
                 % MANIFEST)
    out = {}
    with open(MANIFEST, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            verdict, _, name = line.partition(" ")
            out[name] = verdict
    return out


def check(text):
    manifest = read_manifest()
    unchecked = sorted(n for n in addon_api(text) if n not in manifest)
    if unchecked:
        print("%d client API%s used by the addon and NOT in the manifest:"
              % (len(unchecked), "" if len(unchecked) == 1 else "s"))
        for n in unchecked:
            print("  %s" % n)
        print("\nNone of these has been checked against a client binary. With a\n"
              "client installed: tools/api_audit.py --write. Without one, they\n"
              "are an unverified bet that the API exists on the build we ship to.")
        return 1
    print("every client API the addon calls is in the manifest (%d checked)"
          % len(manifest))
    return 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--exe", default=DEFAULT_EXE)
    ap.add_argument("--write", action="store_true",
                    help="update test/api-manifest.txt")
    ap.add_argument("--check", action="store_true",
                    help="audit the source against the committed manifest; "
                         "needs no client binary")
    args = ap.parse_args()

    text = strip_comments_and_strings(source())

    # --check runs anywhere, including CI and the two weeks with no client
    # installed: it compares what the addon calls today against the manifest
    # that WAS derived from a binary. A new API call is then a build failure
    # with a name attached, rather than something found by logging in.
    if args.check:
        return check(text)

    if not os.path.exists(args.exe):
        sys.exit("no client binary at %s\n"
                 "The manifest in test/ is the committed answer from the last "
                 "build that was installed; pass --exe to re-derive it, or "
                 "--check to audit the source against it." % args.exe)

    whole, called = load_strings(args.exe)

    def present(name):
        leaf = name.rsplit(".", 1)[-1]
        return leaf in whole or leaf in called

    bad = [c for c in PRESENT_CONTROLS if not present(c)]
    bad += [c for c in ABSENT_CONTROLS if present(c)]
    if bad:
        sys.exit("CONTROLS FAILED on %s - the scan is not measuring what it "
                 "claims and nothing below is evidence." % ", ".join(bad))
    print("controls: %d found, %d correctly absent"
          % (len(PRESENT_CONTROLS), len(ABSENT_CONTROLS)))

    names = addon_api(text)
    found = sorted(n for n in names if present(n))
    unverifiable = sorted(n for n in names if not present(n) and n in LUA_SIDE)
    missing = sorted(n for n in names
                     if not present(n) and n not in LUA_SIDE)

    build = os.path.basename(os.path.dirname(args.exe))
    print("%d verified present, %d client-Lua (unverifiable here), %d MISSING"
          % (len(found), len(unverifiable), len(missing)))
    for n in missing:
        print("  MISSING  %s" % n)

    if args.write:
        with open(MANIFEST, "w", encoding="utf-8") as fh:
            fh.write("# Generated by tools/api_audit.py. Do not edit by hand.\n")
            fh.write("# Every client API ComfyRain calls, checked against the\n"
                     "# strings of %s.\n" % os.path.basename(args.exe))
            fh.write("# Flavour dir: %s\n" % build)
            fh.write("#\n# PRESENT: found in the executable.\n")
            fh.write("# LUA: implemented in FrameXML, which is not in the\n"
                     "#      executable, so this scan cannot see it either way.\n\n")
            for n in found:
                fh.write("PRESENT %s\n" % n)
            for n in unverifiable:
                fh.write("LUA %s\n" % n)
        print("wrote %s" % MANIFEST)

    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())

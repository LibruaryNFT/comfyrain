#!/usr/bin/env python3
"""Would a player notice the difference? Every setting, rendered and compared.

    python3 tools/perceive.py ASSETS_DIR

ASSETS_DIR holds the generated sheets (rain-near.tga and friends): ComfyRain/
after ./install.sh, or wherever CI built them. Exits 1 if any two settings a
player can choose between would look and sound the same.

Why this exists. The spec suite checks that each setting sends the renderer the
numbers it meant to, and on 2026-10-23 it was 294 for 294 while light and
normal snow looked identical in the game. Both were true: normal had twice the
alpha, and on that sheet alpha only changed how bright flakes were, not how
many there were, which is the thing an eye reads as "more snow". A number
changing is not the same as a picture changing. This renders the picture.

What it renders. test/dump_scenes.lua builds a world per setting and reports
every layer the addon draws: sheet, alpha, blend mode, how many copies of the
sheet fit the screen, the gloom and time-of-day quads, the whiteout. This
composites them in the client's draw order over flat ground, at 1920x1080, from
the real generated sheets. Two parts are approximate and say so: Blizzard's
mist texture is not on disk here, so mist is an even haze at half its alpha,
and the ground is flat, which flatters faint flakes against real terrain.

What it judges, and where each threshold comes from:
  * steps (intensity) - each step has to be a different AMOUNT of weather,
    read off the near layer, the one the eye locks onto: at least 1.35x the
    visible flakes, or 1.30x the fall speed, or a different sprite. Brightness
    alone does not count, and that is not a guess: it is the one cue the old
    light snow did have (2x), and it read as no difference in the game. The
    old light snow is kept here as a negative control the judge must fail.
  * choices - every pair must differ in something: the steps test, or the
    whole frame's colour by CIE76 dE >= 5 on the brighter ground (a grade
    multiplies, so it shows on the sky, not in a dark forest), or what is
    sounding.
  * range - a slider's two ends, judged as choices.
  * toggle - every row against the first, which is Off.
Sound counts as different when the set of files changes or the summed volume
moves by 3 dB or more.
"""

import json
import math
import os
import subprocess
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
W, H = 1920, 1080
VISIBLE = 6 / 255        # faintest flake counted: a moving dot this bright reads
COUNT_RATIO = 1.35
SPEED_RATIO = 1.30
DELTA_E = 5.0
SOUND_DB = 3.0
GROUNDS = {"dark ground": (0.18, 0.20, 0.16), "snowfield": (0.72, 0.75, 0.80)}
MIST_COVER = 0.5         # Blizzard's mist sheet is not on disk; assume half cover

_sheets = {}


def copy(assets, texture, tilesY):
    """One copy of the sheet as RGBA floats, at the size it is drawn on screen."""
    name = texture.replace("\\", "/").split("/")[-1]
    px = max(1, round(H / tilesY))
    key = (name, px)
    if key not in _sheets:
        img = Image.open(os.path.join(assets, name)).convert("RGBA")
        a = np.asarray(img).astype(np.float32) / 255
        # Resample premultiplied, the way a mipmapped texture filters.
        pre = np.concatenate([a[..., :3] * a[..., 3:], a[..., 3:]], axis=-1)
        chans = [np.asarray(Image.fromarray(pre[..., c]).resize((px, px), Image.BOX))
                 for c in range(4)]
        pre = np.stack(chans, axis=-1)
        alpha = pre[..., 3:]
        rgb = np.where(alpha > 1e-6, pre[..., :3] / np.maximum(alpha, 1e-6), 0)
        _sheets[key] = np.concatenate([rgb, alpha], axis=-1)
    return _sheets[key]


def tiled(s):
    reps = (H // s.shape[0] + 2, W // s.shape[1] + 2, 1)
    return np.tile(s, reps)[:H, :W]


# Each rain layer fades out towards the bottom of the screen (HorizonFade):
# vertex alpha 0.12 at the bottom edge, 1 at the top.
FADE = np.linspace(1.0, 0.12, H, dtype=np.float32)[:, None, None]


WHITE = np.array([0.95, 0.97, 1.0], np.float32)


def behind(scene, ground):
    """The flat colour the precipitation is drawn over: ground, time-of-day
    grade, gloom, then mist."""
    f = np.array(ground, np.float32)
    if scene["curtain"]:
        f = f * np.array(scene["dim"], np.float32) + np.array([1, 0.97, 0.90], np.float32) * scene["lift"]
    if not scene["shown"]:
        return np.clip(f, 0, 1)
    o = scene["alpha"]
    f = f * (1 - o * (1 - np.array(scene["gloom"], np.float32)))
    mist = scene["layers"].get("mist")
    if mist and mist["alpha"] > 0:
        tint = np.array((mist.get("tint") or [1, 1, 1])[:3], np.float32)
        a = mist["alpha"] * MIST_COVER * o
        f = f * (1 - a) + tint * a
    return np.clip(f, 0, 1)


def render(scene, assets, ground):
    """The whole frame, in the client's draw order."""
    f = np.empty((H, W, 3), np.float32)
    f[:] = behind(scene, ground)
    if not scene["shown"]:
        return f
    o = scene["alpha"]
    for name in ("far", "near"):
        l = scene["layers"].get(name)
        if l and l.get("texture") and l["alpha"] > 0:
            s = tiled(copy(assets, l["texture"], l["tilesY"]))
            a = s[..., 3:] * l["alpha"] * o * FADE
            if l["blend"] == "ADD":
                f = f + s[..., :3] * a
            else:
                f = f * (1 - a) + s[..., :3] * a
            f = np.clip(f, 0, 1)
    wa = scene["whiteout"] * o
    if wa > 0:
        f = f * (1 - wa) + WHITE * wa
    return f


def lum(img):
    return img @ np.array([0.2126, 0.7152, 0.0722], np.float32)


NEIGHBOURS = [(dy, dx) for dy in (-1, 0, 1) for dx in (-1, 0, 1) if dy or dx]
_blobs = {}


def components(mask):
    """Label 8-connected blobs. numpy only, because CI has no scipy: every
    pixel starts as its own label and takes its smallest neighbour's until
    nothing changes. A flake is a few pixels across and a streak a few dozen,
    so this settles in a few dozen passes."""
    h, w = mask.shape
    big = h * w + 1
    lab = np.where(mask, np.arange(1, h * w + 1).reshape(h, w), big)
    while True:
        p = np.pad(lab, 1, constant_values=big)
        m = lab.copy()
        for dy, dx in NEIGHBOURS:
            np.minimum(m, p[1 + dy:h + 1 + dy, 1 + dx:w + 1 + dx], out=m)
        m[~mask] = big
        if np.array_equal(m, lab):
            return lab
        lab = m


def count(s, alpha, blend, behind, keep=1.0):
    """Flakes a player could pick out in one copy of the sheet, drawn over a
    flat `behind` at full strength (the top of the screen, where HorizonFade
    leaves the layer alone and the eye reads it). `keep` is what the whiteout
    drawn over everything leaves of their contrast.

    Counted two ways, because where one flake ends and the next begins is not
    obvious on a dense sheet: every blob of the sheet's own alpha, however
    faint, that has a visible peak in it; and every blob of visible pixels.
    The first merges flakes whose faint halos touch and the second splits a
    streak that dims along its length. A step has to pass both.

    Returns (by alpha blob, by visible blob, median peak contrast)."""
    key = (id(s), alpha, blend, tuple(np.asarray(behind).tolist()), keep)
    if key in _blobs:
        return _blobs[key]
    if id(s) not in _blobs:
        mask = s[..., 3] > 0.004
        _blobs[id(s)] = (components(mask), mask)
    lab, mask = _blobs[id(s)]
    a = s[..., 3] * alpha
    if blend == "ADD":
        after = np.minimum(1, behind + s[..., :3] * a[..., None])
    else:
        after = behind * (1 - a[..., None]) + s[..., :3] * a[..., None]
    c = np.abs(lum(after) - lum(np.asarray(behind, np.float32))) * keep

    labels, cm = lab[mask], c[mask]
    order = np.argsort(labels, kind="stable")
    lab_sorted, c_sorted = labels[order], cm[order]
    starts = np.flatnonzero(np.r_[True, lab_sorted[1:] != lab_sorted[:-1]])
    peak = np.maximum.reduceat(c_sorted, starts) if starts.size else np.zeros(0)
    seen = peak >= VISIBLE
    vis = c >= VISIBLE
    n_vis = int(np.unique(components(vis)[vis]).size) if vis.any() else 0
    out = (int(seen.sum()), n_vis, float(np.median(peak[seen])) if seen.any() else 0.0)
    _blobs[key] = out
    return out


def lab(rgb):
    """Mean frame colour, sRGB in, CIELAB out."""
    c = np.asarray(rgb, np.float64)
    lin = np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
    M = np.array([[0.4124, 0.3576, 0.1805], [0.2126, 0.7152, 0.0722],
                  [0.0193, 0.1192, 0.9505]])
    xyz = M @ lin / np.array([0.95047, 1.0, 1.08883])
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    return np.array([116 * f[1] - 16, 500 * (f[0] - f[1]), 200 * (f[1] - f[2])])


def measure(scene, assets):
    out = {}
    L = scene["layers"]
    for gname, ground in GROUNDS.items():
        m = {"lab": lab(render(scene, assets, ground).reshape(-1, 3).mean(0))}
        back = behind(scene, ground)
        for name in ("far", "near"):
            l = L.get(name) or {}
            n, nv, c = 0, 0, 0.0
            if scene["shown"] and l.get("texture") and l.get("alpha", 0) > 0:
                s = copy(assets, l["texture"], l["tilesY"])
                n, nv, c = count(s, l["alpha"] * scene["alpha"], l["blend"], back,
                                 keep=1 - scene["whiteout"] * scene["alpha"])
                # Flakes on screen: as many copies of the sheet as fit.
                copies = l["tilesY"] ** 2 * W / H
                n, nv = round(n * copies), round(nv * copies)
            m[name], m[name + "_seen"], m[name + "_contrast"] = n, nv, c
        out[gname] = m
    near = L.get("near") or {}
    out["speed"] = near.get("speed", 0) if scene["shown"] and near.get("alpha", 0) > 0 else 0
    return out


def loudness(scene):
    return sum(s["volume"] for s in scene["sounds"])


def sound_differs(a, b):
    fa = sorted((str(s["file"]), s["channel"]) for s in a["sounds"])
    fb = sorted((str(s["file"]), s["channel"]) for s in b["sounds"])
    if fa != fb:
        return "different sounds"
    if a.get("started", []) != b.get("started", []):
        return "different sounds over time"
    la, lb = loudness(a), loudness(b)
    if (la > 0) != (lb > 0):
        return "silent against audible"
    if la > 0 and lb > 0 and abs(20 * math.log10(lb / la)) >= SOUND_DB:
        return f"{20 * math.log10(lb / la):+.1f} dB"
    return None


def ratio(x, y):
    lo, hi = min(x, y), max(x, y)
    return math.inf if lo == 0 and hi > 0 else (hi / lo if lo else 1.0)


def amount_differs(ma, mb):
    """The steps test: is this a different amount of weather? Worst ground wins."""
    if ratio(ma["speed"], mb["speed"]) >= SPEED_RATIO:
        return f"speed x{ratio(ma['speed'], mb['speed']):.2f}"
    worst = min(min(ratio(ma[g]["near"], mb[g]["near"]),
                    ratio(ma[g]["near_seen"], mb[g]["near_seen"])) for g in GROUNDS)
    if worst >= COUNT_RATIO:
        return f"flakes x{worst:.2f}"
    return None


def anything_differs(a, b, ma, mb):
    why = amount_differs(ma, mb)
    if why:
        return why
    # Light is judged where it shows, the brightest ground. Gloom and the time
    # of day multiply, so on dark ground they have little to work on, but
    # every outdoor frame has a sky in it, and the sky is where a player sees
    # dusk arrive.
    best = max(float(np.linalg.norm(ma[g]["lab"] - mb[g]["lab"])) for g in GROUNDS)
    if best >= DELTA_E:
        return f"colour dE {best:.1f}"
    return sound_differs(a, b)


def describe(m):
    d = m["dark ground"]
    return (f"near flakes {d['near']:5d}/{d['near_seen']:5d} (snowfield "
            f"{m['snowfield']['near']:5d}/{m['snowfield']['near_seen']:5d})  "
            f"contrast {d['near_contrast'] * 255:4.1f}/255  speed {m['speed']:.2f} H/s")


def judge(group, rows, assets):
    kind = rows[0]["kind"]
    ms = [measure(r, assets) for r in rows]
    fails, lines = [], []
    for r, m in zip(rows, ms):
        lines.append(f"    {r['label']:14s} {describe(m)}")
    if kind == "steps":
        pairs = [(i, i + 1) for i in range(len(rows) - 1)]
    elif kind == "range":
        pairs = [(0, len(rows) - 1)]
    elif kind == "toggle":
        pairs = [(0, j) for j in range(1, len(rows))]
    else:
        pairs = [(i, j) for i in range(len(rows)) for j in range(i + 1, len(rows))]
    for i, j in pairs:
        a, b = rows[i], rows[j]
        if kind == "steps":
            why = amount_differs(ms[i], ms[j])
        else:
            why = anything_differs(a, b, ms[i], ms[j])
        verdict = "ok  " if why else "SAME"
        lines.append(f"  {verdict} {a['label']} -> {b['label']}: {why or 'a player would not tell these apart'}")
        if not why:
            fails.append(f"{group}: {a['label']} and {b['label']}")
    return fails, lines


def scenes():
    lua = os.environ.get("LUA") or os.path.expanduser("~/.local/bin/lua")
    if not os.path.exists(lua):
        lua = "lua5.1"
    out = subprocess.run([lua, os.path.join(REPO, "test", "dump_scenes.lua")],
                         capture_output=True, text=True, check=True).stdout
    return [json.loads(l) for l in out.splitlines() if l.strip()]


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    assets = sys.argv[1]
    rows = scenes()
    groups = {}
    for r in rows:
        groups.setdefault(r["group"], []).append(r)

    # The negative control. Light snow as it shipped until 2026-10-23: the full
    # near sheet at 0.30, which the player saw as no different from normal. If
    # the judge passes this pair, the judge is broken and every "ok" below is
    # worthless, so it is checked first and it stops the run.
    snow = groups["Snow intensity"]
    old = json.loads(json.dumps(snow[0]))
    old["label"] = "old light"
    old["layers"]["near"]["texture"] = snow[1]["layers"]["near"]["texture"]
    old["layers"]["near"]["alpha"] = 0.30 / 0.52 * snow[0]["layers"]["near"]["alpha"]
    ctrl_fails, ctrl_lines = judge("control", [old, snow[1]], assets)
    print("Negative control: light snow as it shipped, which looked like normal in game")
    print("\n".join(ctrl_lines))
    if not ctrl_fails:
        sys.exit("\nThe judge passed a pair a player could not tell apart. Fix the judge first.")

    # The same for the ear: one sound, and the same sound 1.6 dB louder, which
    # is under SOUND_DB. A judge that calls any change in a number a change in
    # the sound would pass every sound group below whether or not it was heard.
    quiet = groups["Volume, a quiet step"][0]
    louder = json.loads(json.dumps(quiet))
    louder["label"] = quiet["label"] + " +1.6 dB"
    for s in louder["sounds"]:
        s["volume"] *= 1.2
    ctrl_fails, ctrl_lines = judge("control", [quiet, louder], assets)
    print("\nNegative control: the same sound 1.6 dB louder, under what a player hears")
    print("\n".join(ctrl_lines))
    if not ctrl_fails:
        sys.exit("\nThe judge passed a pair a player could not tell apart. Fix the judge first.")

    all_fails = []
    for name, rs in groups.items():
        fails, lines = judge(name, rs, assets)
        all_fails += fails
        print(f"\n{name} ({rs[0]['kind']})")
        print("\n".join(lines))
    print(f"\n{len(all_fails)} pair(s) a player would not tell apart")
    for f in all_fails:
        print(f"  {f}")
    sys.exit(1 if all_fails else 0)


if __name__ == "__main__":
    main()

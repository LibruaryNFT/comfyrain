#!/usr/bin/env python3
"""Check every shipped art asset against what WoW and the overlay require.

This tests the TGA files themselves, not the generators that wrote them - the
file on disk is what the client loads, and a generator that runs clean can
still emit something WoW silently refuses to draw.

Seven checks, each with a stated failure mode that has either bitten this addon
or would be invisible until a player saw it:

1. TGA format      WoW needs power-of-two, 32-bit, UNCOMPRESSED. An RLE TGA
                   loads as nothing at all, with no error.
2. Alpha range     The shape lives in the alpha channel. A sheet that saturates
                   has lost its soft ends and will read as hard-edged.
3. Flat RGB        Colour comes from the Lua tint, so RGB must be constant. A
                   gradient here fights the tint and tints the gloom.
4. Seam            Sheets tile 1-7 times across the screen. A discontinuity at
                   the wrap is repeated that many times and is impossible to
                   unsee. Compared against an interior line as a control: the
                   wrap must be no worse than an arbitrary row/column.
5. Uniformity      A bald patch or a clump is likewise repeated across the
                   screen. Measured as the spread of coverage over an 8x8 grid,
                   against a Poisson expectation as a control.
6. On-screen size  Sheet pixels are not screen pixels. tilesY is multiplied by
                   the per-intensity density, so every preset magnifies the
                   sheet differently. The largest element is measured off the
                   sheet's own alpha and put through every preset's scale. This
                   is the check that was missing when the rain streaks shipped
                   at 51% of the frame height.
7. Icon            64x64, and still legible once the addon list shrinks it.

Usage: check_art.py <dir>        (defaults to the installed _forever_ addon)
Exit status is non-zero if any check fails.
"""
import math
import os
import struct
import sys

import numpy as np
from PIL import Image

SCREEN_H, SCREEN_W = 1080, 1920          # the reference screen for check 6
SIZE = 512

# key -> tilesY, straight out of LAYERS in ComfyRain.lua
TILES_Y = {"far": 3.0, "near": 1.5}

# weather -> intensity -> density, straight out of the preset tables
DENSITY = {
    "rain": {"light": 1.35, "normal": 1.00, "heavy": 0.78, "monsoon": 0.58},
    "snow": {"light": 1.20, "normal": 1.00, "heavy": 0.82, "blizzard": 0.66},
}

# A single element may not exceed this share of the frame along its own axis -
# height for a falling streak, width for a wind-driven one. Above it the eye
# stops reading "weather" and starts reading "line drawn on the screen".
#
# Calibrated against known-bad and known-good art rather than picked. The
# sheets that shipped and were called bars measured 16.4% (rain near), 14.8%
# (snow near) and 21.5% (gale); the retuned ones measure 7.0%, 5.7% and 8.9%.
MAX_FRAME_SHARE = 0.12

SHEETS = ["rain-far.tga", "rain-near.tga",
          "snow-far.tga", "snow-near.tga", "snow-gale.tga"]

fails = []
warns = []


def fail(asset, msg):
    fails.append(f"{asset}: {msg}")


def warn(asset, msg):
    warns.append(f"{asset}: {msg}")


def tga_header(path):
    """Parse the 18-byte TGA header. PIL will happily decode an RLE TGA that
    WoW will not, so the raw image-type byte is the thing to look at."""
    with open(path, "rb") as fh:
        raw = fh.read(18)
    (idlen, cmaptype, imgtype, _cmo, _cml, _cmd,
     _x, _y, w, h, bpp, desc) = struct.unpack("<BBBHHBHHHHBB", raw)
    return dict(idlen=idlen, cmaptype=cmaptype, imgtype=imgtype,
                w=w, h=h, bpp=bpp, desc=desc)


def check_format(name, path):
    hd = tga_header(path)
    if hd["imgtype"] != 2:
        fail(name, f"image type {hd['imgtype']}, must be 2 (uncompressed true "
                   f"colour); 10 is RLE and WoW draws nothing")
    if hd["bpp"] != 32:
        fail(name, f"{hd['bpp']}-bit, must be 32")
    for axis, v in (("width", hd["w"]), ("height", hd["h"])):
        if v == 0 or (v & (v - 1)):
            fail(name, f"{axis} {v} is not a power of two")
    return hd


def check_channels(name, img):
    a = np.asarray(img, dtype=np.float32)[..., 3] / 255.0
    rgb = np.asarray(img, dtype=np.float32)[..., :3] / 255.0
    cov = float((a > 0.01).mean())
    if a.max() >= 0.999:
        warn(name, f"alpha saturates at 1.0 ({int((a >= 0.999).sum())} px); "
                   f"soft ends may be clipped")
    if cov < 0.01:
        fail(name, f"coverage {100*cov:.2f}% - sheet is effectively empty")
    if cov > 0.60:
        fail(name, f"coverage {100*cov:.1f}% - sheet is a wash, not elements")
    spread = float(rgb.reshape(-1, 3).std(axis=0).max())
    if spread > 0.01:
        fail(name, f"RGB is not flat (max channel sd {spread:.3f}); colour "
                   f"must come from the Lua tint")
    return a, cov


def check_seam(name, a):
    """The wrap edge must be no more of a discontinuity than an interior line.

    Comparing it against interior lines IS the positive control: a sheet full
    of hard edges would fail an absolute threshold while tiling perfectly.
    """
    h, w = a.shape
    rng = np.random.default_rng(0)

    def step(arr, i, axis):
        if axis == 0:
            return float(np.abs(arr[i % h] - arr[(i - 1) % h]).mean())
        return float(np.abs(arr[:, i % w] - arr[:, (i - 1) % w]).mean())

    for axis, n, label in ((0, h, "top/bottom"), (1, w, "left/right")):
        wrap = step(a, 0, axis)
        interior = [step(a, int(i), axis)
                    for i in rng.integers(2, n - 2, size=200)]
        lim = float(np.percentile(interior, 99))
        if wrap > max(lim, 1e-6) * 1.5:
            fail(name, f"{label} seam: wrap step {wrap:.5f} vs interior p99 "
                       f"{lim:.5f} - sheet does not tile")


def check_uniformity(name, a, cov):
    """Coverage per cell over an 8x8 grid, against a Poisson control.

    Placement is random, so some spread is expected and an absolute threshold
    would be arbitrary. The control is the spread random placement would give
    at the same coverage.
    """
    g = 8
    cells = a.reshape(g, a.shape[0] // g, g, a.shape[1] // g)
    per = (cells > 0.01).mean(axis=(1, 3))
    npx = (a.shape[0] // g) * (a.shape[1] // g)
    expect = math.sqrt(max(cov, 1e-9) * (1 - cov) / npx)   # Poisson/binomial sd
    got = float(per.std())
    ratio = got / max(expect, 1e-9)
    if ratio > 12.0:
        fail(name, f"clumpy: cell coverage sd is {ratio:.1f}x the random "
                   f"expectation (min cell {100*per.min():.1f}%, max "
                   f"{100*per.max():.1f}%)")
    elif ratio > 8.0:
        warn(name, f"cell coverage sd is {ratio:.1f}x random expectation")


def longest_run(mask, axis):
    """Longest unbroken run of set pixels along one axis, wrapping.

    Wrapping matters: the sheet tiles, so an element split across the seam is
    one element on screen, and measuring the file without wrapping would report
    it as two short ones. Doubling the array and capping the answer at the
    original length is the cheap way to get that.
    """
    m = mask if axis == 0 else mask.T
    n = m.shape[0]
    d = np.vstack([m, m])
    # Vectorised run length: a running counter that resets to zero on a gap.
    run = np.zeros(d.shape[1], dtype=np.int32)
    best = 0
    for row in d:
        run = np.where(row, run + 1, 0)
        best = max(best, int(run.max()))
    return min(best, n)


def measure_largest(name, a):
    """Largest element in the sheet, measured from the sheet, per axis.

    Taken at alpha > 0 rather than at a visible-ish threshold. A streak's ends
    taper to nothing, and on an ADD layer tiled over a dark sky even the faint
    tail registers - thresholding at 2/255 or higher cut the measured length
    roughly in half and could no longer tell the sheets that shipped apart from
    the retuned ones. The eye sees the tail; so does the check.
    """
    mask = a > 0.0
    return longest_run(mask, 0), longest_run(mask, 1)


def check_on_screen(name, a):
    """Largest element, in screen pixels, at every preset that uses the sheet.

    The sheet is scaled by H/(tilesY*density*512), and density is inverted, so
    the preset with the SMALLEST density magnifies the most. Each axis is
    judged against its own screen dimension: a wind-driven streak lying nearly
    flat crosses the 1920px width, not the 1080px height, and calling it 16% of
    the frame because the vertical number was the only one measured would
    condemn art that looks right.
    """
    vert, horz = measure_largest(name, a)
    weather = "rain" if name.startswith("rain") else "snow"
    key = "far" if "far" in name else "near"        # the gale sheet is a near
    worst = (0.0, None)
    for intensity, dens in DENSITY[weather].items():
        if name == "snow-gale.tga" and intensity != "blizzard":
            continue
        if name == "snow-near.tga" and intensity == "blizzard":
            continue                                 # gale replaces near there
        scale = SCREEN_H / (TILES_Y[key] * dens * SIZE)
        for ext, screen, axis in ((vert, SCREEN_H, "tall"),
                                  (horz, SCREEN_W, "wide")):
            px = ext * scale
            if px / screen > worst[0]:
                worst = (px / screen, (intensity, px, axis))
    share, (intensity, px, axis) = worst
    if share > MAX_FRAME_SHARE:
        fail(name, f"largest element is {px:.0f}px {axis} at {intensity} = "
                   f"{100*share:.0f}% of the frame, over the "
                   f"{100*MAX_FRAME_SHARE:.0f}% ceiling")
    return intensity, px, share, axis


def check_icon(path):
    if not os.path.exists(path):
        fail("icon.tga", "missing")
        return
    hd = tga_header(path)
    if (hd["w"], hd["h"]) != (64, 64):
        fail("icon.tga", f"{hd['w']}x{hd['h']}, must be 64x64")
    if hd["imgtype"] != 2 or hd["bpp"] != 32:
        fail("icon.tga", f"type {hd['imgtype']} / {hd['bpp']}-bit, "
                         f"must be 2 / 32")
    small = np.asarray(Image.open(path).convert("RGB")
                       .resize((20, 20), Image.LANCZOS), dtype=np.float32) / 255
    # At 20px the icon is a smudge unless something still varies across it.
    contrast = float(small.reshape(-1, 3).mean(axis=1).std())
    if contrast < 0.04:
        fail("icon.tga", f"at 20px the contrast is {contrast:.3f}; it will "
                         f"read as a flat blob in the addon list")
    print(f"  icon.tga        64x64 32-bit    contrast at 20px {contrast:.3f}")


def main():
    default = (os.path.expanduser("~") + "/Games/battlenet/pfx/drive_c/"
               "Program Files (x86)/World of Warcraft/_forever_/Interface/"
               "AddOns/ComfyRain")
    d = (sys.argv[1] if len(sys.argv) > 1 else default).rstrip("/")
    print(f"checking art in {d}\n")
    print(f"  {'sheet':16s} {'format':15s} {'cover':>6s}  "
          f"{'largest element on a %dx%d screen' % (SCREEN_W, SCREEN_H):40s}")
    for name in SHEETS:
        path = f"{d}/{name}"
        if not os.path.exists(path):
            fail(name, "missing")
            continue
        hd = check_format(name, path)
        img = Image.open(path).convert("RGBA")
        a, cov = check_channels(name, img)
        check_seam(name, a)
        check_uniformity(name, a, cov)
        intensity, px, share, axis = check_on_screen(name, a)
        print(f"  {name:16s} {hd['w']}x{hd['h']} {hd['bpp']}-bit  "
              f"{100*cov:5.1f}%  {px:5.0f}px {axis:4s} at {intensity:<9s} "
              f"= {100*share:4.1f}% of the frame")
    check_icon(f"{d}/icon.tga")

    print()
    for w in warns:
        print(f"  WARN  {w}")
    for f in fails:
        print(f"  FAIL  {f}")
    print(f"\n{len(SHEETS)+1} assets, {len(fails)} failed, {len(warns)} warnings")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())

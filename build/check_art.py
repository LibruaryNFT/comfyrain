#!/usr/bin/env python3
"""Check every shipped art asset against what WoW and the overlay require.

This tests the TGA files themselves, not the generators that wrote them - the
file on disk is what the client loads, and a generator that runs clean can
still emit something WoW silently refuses to draw.

Eight checks, each with a stated failure mode that has either bitten this addon
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
5. Uniformity      A bald patch or a blotch is likewise repeated across the
                   screen. Measured two ways - the emptiest cell, and the
                   overall spread of coverage - each against this sheet's own
                   elements re-scattered at random as the control.
6. Landmarks       One element far brighter than the rest is what the eye
                   re-identifies when the sheet tiles, so it is the thing that
                   gives the repeat away. Measured as the brightest pixel
                   against the 99th percentile of lit ones.
7. On-screen size  Sheet pixels are not screen pixels. tilesY is multiplied by
                   the weather's tiling and by the zoom, so the same sheet is
                   magnified differently in different views. The largest
                   element is measured off the sheet's own alpha, followed
                   at its own slant and cut from any neighbour touching it,
                   and put through the worst of those. This is the check
                   that was missing when the rain streaks shipped at 51% of
                   the frame height.
8. Icon            64x64, and still legible once the addon list shrinks it.

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

# weather -> tiling, straight out of the WEATHER table. One number each: it is
# no longer per-intensity, because intensity used to magnify the sheet and that
# was issue #11. Intensity is carried by alpha and speed now.
TILING = {"rain": 1.35, "snow": 1.20}

# Zoom still moves the tiling, and first person is the magnifying end of it:
# ZOOM_PIVOT 0.65 and ZOOM_RANGE 0.55 in the Lua, at zoomNorm 0. This is the
# largest the sheet is ever drawn, so it is the case the ceiling has to hold at.
ZOOM_WORST = 1 + (0.0 - 0.65) * 0.55

# A single element may not exceed this share of the frame along its own axis -
# height for a falling streak, width for a wind-driven one. Above it the eye
# stops reading "weather" and starts reading "line drawn on the screen".
#
# Checked against the truth rather than picked. Rasterising each generator's
# elements one at a time gives every element's real size to hold the ruler
# against (2026-10-23): the rain bars that shipped at 80-190px measure 187px
# here, true 187, = 28% of the frame, and fail. Every sheet shipped since
# measures 7-12%, within 20% of its true largest element, over it where a
# dense sheet stands two elements end to end. The figures this used to quote,
# 16.4% rain near, 14.8% snow near and 21.5% gale, came from a ruler that read
# straight down a column: it measured those bars at 73px, and passed them once
# the tiling stopped depending on intensity.
MAX_FRAME_SHARE = 0.12

SHEETS = ["rain-far.tga", "rain-near.tga", "rain-near-heavy.tga",
          "rain-near-monsoon.tga",
          "snow-far.tga", "snow-near.tga", "snow-near-light.tga",
          "snow-near-heavy.tga",
          "snow-gale.tga"]

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


def grid_sd(a, g=8):
    """Spread of coverage over a g*g grid of cells."""
    cells = a.reshape(g, a.shape[0] // g, g, a.shape[1] // g)
    per = (cells > 0.01).mean(axis=(1, 3))
    return float(per.std()), per


def blobs(a, thresh=0.01):
    """Connected lit regions, as (patch, height, width), wrapping both axes.

    Label propagation rather than a library call: the only dependencies this
    build has are numpy and Pillow, and pulling in scipy for one ndimage.label
    is not worth it. Every lit pixel starts as its own label and then takes the
    maximum of its four neighbours until nothing changes, which merges each
    connected region onto a single id in as many passes as the region is long.
    Rolls rather than slices, so a blob crossing the sheet edge stays one blob
    - the sheet tiles, so on screen it is one.
    """
    mask = a > thresh
    lab = np.where(mask, np.arange(a.size).reshape(a.shape), -1)
    while True:
        nxt = lab
        for sh, ax in ((1, 0), (-1, 0), (1, 1), (-1, 1)):
            nxt = np.maximum(nxt, np.roll(lab, sh, axis=ax))
        nxt = np.where(mask, nxt, -1)
        if np.array_equal(nxt, lab):
            break
        lab = nxt

    out = []
    for v in np.unique(lab[mask]):
        ys, xs = np.nonzero(lab == v)
        # Un-wrap: if the blob spans the seam it will have pixels at both
        # edges, so shift it until it is contiguous before cutting the patch.
        for arr, n in ((ys, a.shape[0]), (xs, a.shape[1])):
            if arr.max() - arr.min() > n // 2:
                arr[arr > n // 2] -= n
        y0, x0 = ys.min(), xs.min()
        h, w = ys.max() - y0 + 1, xs.max() - x0 + 1
        patch = np.zeros((h, w), dtype=np.float32)
        patch[ys - y0, xs - x0] = a[(ys) % a.shape[0], (xs) % a.shape[1]]
        out.append(patch)
    return out


def check_uniformity(name, a):
    """Is this sheet blotchier than its own elements, scattered at random?

    The control is the sheet's own blobs, lifted off it and re-scattered at
    uniform random positions. That is a true null: identical elements, known
    random placement, so whatever spread it produces is the spread that random
    placement of THIS population produces, and anything much worse is real
    structure - a bald patch, or a blotch - which the sheet then repeats
    across the screen. Two statistics come off it, because one did not catch
    both defects; see each below.

    Two controls were tried and rejected before this one, both recorded here
    because each looked right:

    A binomial sd over PIXELS assumed pixels were placed independently. They
    are not; they arrive in elements tens of pixels across, so it overstated
    the expected evenness by roughly the square root of the pixels per element.
    That was survivable while placement was a jittered grid, which is much more
    even than random. Once placement became genuinely Poisson, the close pairs
    and holes that are the whole point of the change tripped it - snow-near
    scored 12.1x and failed for doing the right thing.

    A block shuffle, cutting the sheet into 32px tiles and permuting them, was
    worse: it is INERT. Shuffling preserves the distribution of block
    densities, so a sheet with a quarter of it wiped shuffles into a sheet
    with a quarter of its blocks empty, scattered about, and the measured
    spread barely moves. It passed a deliberately bald quadrant, which is the
    one defect this check exists to catch.
    """
    parts = blobs(a)
    rng = np.random.default_rng(7)
    n = a.shape[0]
    coarse, fine = [], []
    for _ in range(32):
        s = np.zeros_like(a)
        for p in parts:
            ph, pw = p.shape
            ys = (rng.integers(0, n) + np.arange(ph)) % n
            xs = (rng.integers(0, n) + np.arange(pw)) % n
            idx = np.ix_(ys, xs)
            s[idx] = np.maximum(s[idx], p)
        coarse.append(grid_sd(s, 4)[1])
        fine.append(grid_sd(s, 8)[1])

    # Holes, on a 4x4 grid. One-sided and on the emptiest cell only, because a
    # bald patch is a hole and nothing else: the overall spread below is
    # dominated by where the few largest elements happened to land, which swamps
    # it. 128px cells rather than 64, because averaging over the larger cell is
    # what suppresses that same large-element noise - measured on a deliberately
    # wiped quadrant, 4x4 separates by 4 sigma and 8x8 does not separate at all.
    emptiest = grid_sd(a, 4)[1].min()
    nulls = np.array([c.min() for c in coarse])
    z = (emptiest - nulls.mean()) / max(nulls.std(), 1e-9)
    if z < -4.0:
        fail(name, f"bald patch: emptiest 128px cell is {100*emptiest:.1f}% "
                   f"covered against {100*nulls.mean():.1f}% for these same "
                   f"elements re-scattered ({z:.1f} sigma) - that hole tiles "
                   f"across the screen")
    elif z < -3.0:
        warn(name, f"emptiest 128px cell is {z:.1f} sigma below the same "
                   f"elements re-scattered")

    # Blotchiness: overall spread on the 8x8 grid, two-sided, for structure
    # that is not a single hole - a density gradient, or banding.
    got, per = grid_sd(a)
    expect = float(np.mean([c.std() for c in fine]))
    ratio = got / max(expect, 1e-9)
    if ratio > 2.0:
        fail(name, f"blotchy: cell coverage sd is {ratio:.2f}x the same "
                   f"elements re-scattered (min cell {100*per.min():.1f}%, max "
                   f"{100*per.max():.1f}%) - there is structure here bigger "
                   f"than the elements, and it tiles across the screen")
    elif ratio > 1.6:
        warn(name, f"cell coverage sd is {ratio:.2f}x the same elements "
                   f"re-scattered")


def check_landmarks(name, a):
    """No element may be conspicuously brighter than the rest of the field.

    Both research passes landed on this independently, and it is the one that
    decides whether the tiling is noticeable. The eye does not find a repeat by
    cross-correlating the screen; it finds it by recognising a LANDMARK and
    then seeing it again 500px away. A sparse caste of bright elements is
    therefore the most expensive thing a tiling sheet can contain, and both
    sheets used to have one on purpose: one rain drop in twelve was multiplied
    by 1.9, one snow flake in ten by 1.8, filed under "variety".

    Measured as the brightest pixel over the 99th percentile of lit pixels.
    Calibrated, not picked: the sheets with the bright caste score 1.95 to 2.18
    and the continuous lognormal ones 1.15 to 1.25.
    """
    nz = a[a > 0]
    if nz.size == 0:
        return
    p99 = float(np.percentile(nz, 99))
    ratio = float(a.max()) / max(p99, 1e-9)
    if ratio > 1.5:
        fail(name, f"brightest pixel is {ratio:.2f}x the 99th percentile of "
                   f"lit pixels - that element is a landmark, and the sheet "
                   f"repeats it across the screen")


# Where a lit run dips below this share of the dimmer of the peaks either side
# of it, it is two elements touching, not one. See measure_largest.
VALLEY = 0.5


def pieces(seg):
    """Lengths of the elements in one unbroken lit run, cut at deep valleys.

    A cut goes at a local minimum lower than VALLEY times the brightest pixel
    on its dimmer side. A single streak tapers smoothly from one peak, so its
    only minima are noise in the tail, where the brightest pixel behind them is
    barely above them, and it comes back whole.
    """
    n = len(seg)
    if n < 3:
        return np.array([n])
    left = np.maximum.accumulate(seg)
    right = np.maximum.accumulate(seg[::-1])[::-1]
    mid = seg[1:-1]
    low = (mid <= seg[:-2]) & (mid <= seg[2:])
    deep = mid < VALLEY * np.minimum(left[:-2], right[2:])
    cuts = np.flatnonzero(low & deep) + 1
    return np.diff(np.concatenate([[-1], cuts, [n]])) - 1


# The lines an element is followed along: every slope from 45 degrees one way
# to 45 the other, in steps fine enough that a streak the length of the old
# bars (190px, a hair wide) drifts at most a pixel off its line from end to
# end. 0.02 drifted off them and read the bars at 144px. The other axis's
# pass covers the steeper half.
SLOPES = np.arange(-1.0, 1.0001, 0.01)


def longest_element(a, axis):
    """Longest element's extent along one axis, following it at its own slant.

    Straight down a pixel column was the first ruler, and it cannot measure a
    slanted streak: the column crosses it and leaves, so it reads the crossing,
    not the streak. Rain falls at 7.5 degrees, and the 190px bars this check
    was written for measured 73px straight down, under the ceiling. So the
    sheet is sheared at each slope in SLOPES until the streak stands in one
    column, and the longest run over every slope is the element.

    Wrapping matters: the sheet tiles, so an element split across the seam is
    one element on screen, and measuring the file without wrapping would report
    it as two short ones. Doubling the array and capping the answer at the
    original length is the cheap way to get that.

    A slope whose longest unbroken run is no longer than the best element
    found so far is skipped, and the runs of the rest are visited longest
    first, stopping at the same bound, because cutting a run can only shorten
    it. Each sheared column is gathered as a contiguous row, padded with an
    unlit pixel at each end, so every run in the sheet is one pair of sign
    changes in a single flat diff. Together that keeps 201 slopes on two axes
    to about a second a sheet.
    """
    m = a if axis == 0 else a.T
    n = m.shape[0]
    # Doubled down the run, so a run crossing the seam is whole; doubled
    # across, so a shifted column can be read without a modulo.
    d = np.tile(m, (2, 2))
    flat = d.ravel()
    on = flat > 0
    y = np.arange(2 * n)
    width = 2 * n + 2
    padded = np.zeros((n, width), dtype=bool)
    best = 0
    for s in SLOPES:
        # Sheared column c is d[y, c + shift(y)], laid out as row c here.
        start = y * (2 * n) + np.round(s * y).astype(np.int64) % n
        idx = start[None, :] + np.arange(n)[:, None]
        padded[:, 1:-1] = on[idx]
        edges = np.flatnonzero(np.diff(padded.ravel().view(np.int8)))
        starts, ends = edges[::2], edges[1::2]
        lengths = ends - starts
        if lengths.size == 0 or lengths.max() <= best:
            continue
        for k in np.argsort(-lengths):
            if lengths[k] <= best:
                break
            c, i = divmod(int(starts[k]), width)
            run = flat[idx[c, i:i + lengths[k]]]
            best = max(best, int(pieces(run).max()))
    return min(best, n)


def measure_largest(name, a):
    """Largest element in the sheet, measured from the sheet, per axis.

    Taken at alpha > 0 rather than at a visible-ish threshold. A streak's ends
    taper to nothing, and on an ADD layer tiled over a dark sky even the faint
    tail registers - thresholding at 2/255 or higher cut the measured length
    roughly in half and could no longer tell the sheets that shipped apart from
    the retuned ones. The eye sees the tail; so does the check.

    But at alpha > 0 the tails of neighbouring elements touch, and on a dense
    sheet (heavy snow, monsoon) a plain run of lit pixels chains several of
    them into one "element" that no player sees: heavy snow's longest run was
    five separate flakes, its alpha falling to 2/255 between each. So a run is
    cut where it dips to under half the dimmer peak beside it (pieces).
    control() holds both halves of that, whole streak and split pair, every
    time this runs.
    """
    return longest_element(a, 0), longest_element(a, 1)


def control():
    """The ruler has to measure one long slanted streak whole and cut two
    touching flakes apart. Abort rather than judge the art with a ruler that
    does neither."""
    n = 256
    ys = np.arange(n, dtype=np.float32)

    # A 200px streak at rain's 7.5 degrees, 2px wide, its head bright and its
    # tail tapering to nothing, with faint ripple along it.
    streak = np.zeros((n, n), dtype=np.float32)
    t = np.clip((ys - 20) / 200, 0, 1)
    along = np.where((ys >= 20) & (ys < 220), 0.4 * (1 - t) ** 0.5 + 0.002, 0)
    along *= 1 + 0.05 * np.sin(ys * 1.7)
    cx = 40 + 0.1317 * ys
    xs = np.arange(n, dtype=np.float32)
    streak[:] = along[:, None] * np.exp(-((xs[None, :] - cx[:, None]) / 1.0) ** 2)
    streak[streak < 1 / 255] = 0                 # as the 8-bit file stores it

    # Two 60px flakes, one above the other, overlapping by their faint edges.
    pair = np.zeros((n, n), dtype=np.float32)
    for c in (80, 135):
        pair[:, 128] = np.maximum(pair[:, 128],
                                  np.clip(0.3 * (1 - np.abs(ys - c) / 30), 0, None))

    whole, split = longest_element(streak, 0), longest_element(pair, 0)
    if not (190 <= whole <= 200 and split <= 61):
        sys.exit(f"control failed: a 200px slanted streak measured {whole}px "
                 f"and two 60px flakes touching measured {split}px; the size "
                 f"check cannot be trusted")


def check_on_screen(name, a):
    """Largest element, in screen pixels, at the scale that magnifies the most.

    The sheet is scaled by H/(tilesY*tiling*512), so the SMALLER the tiling the
    bigger the element. Intensity no longer touches tiling, so the only thing
    left that does is zoom, and first person is its magnifying end.

    Each axis is judged against its own screen dimension: a wind-driven streak
    lying nearly flat crosses the 1920px width, not the 1080px height, and
    calling it 16% of the frame because the vertical number was the only one
    measured would condemn art that looks right.
    """
    vert, horz = measure_largest(name, a)
    weather = "rain" if name.startswith("rain") else "snow"
    key = "far" if "far" in name else "near"        # the gale sheet is a near
    scale = SCREEN_H / (TILES_Y[key] * TILING[weather] * ZOOM_WORST * SIZE)
    worst = (0.0, None)
    for ext, screen, axis in ((vert, SCREEN_H, "tall"),
                              (horz, SCREEN_W, "wide")):
        px = ext * scale
        if px / screen > worst[0]:
            worst = (px / screen, (px, axis))
    share, (px, axis) = worst
    if share > MAX_FRAME_SHARE:
        fail(name, f"largest element is {px:.0f}px {axis} in first person = "
                   f"{100*share:.0f}% of the frame, over the "
                   f"{100*MAX_FRAME_SHARE:.0f}% ceiling")
    return px, share, axis


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
    print(f"  {'icon.tga':22s} 64x64 32-bit    contrast at 20px {contrast:.3f}")


def main():
    default = (os.path.expanduser("~") + "/Games/battlenet/pfx/drive_c/"
               "Program Files (x86)/World of Warcraft/_forever_/Interface/"
               "AddOns/ComfyRain")
    d = (sys.argv[1] if len(sys.argv) > 1 else default).rstrip("/")
    control()
    print(f"checking art in {d}\n")
    print(f"  {'sheet':22s} {'format':15s} {'cover':>6s}  "
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
        check_uniformity(name, a)
        check_landmarks(name, a)
        px, share, axis = check_on_screen(name, a)
        print(f"  {name:22s} {hd['w']}x{hd['h']} {hd['bpp']}-bit  "
              f"{100*cov:5.1f}%  {px:5.0f}px {axis:4s} "
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

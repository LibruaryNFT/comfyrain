#!/usr/bin/env python3
"""Generate seamless snow and blizzard TGAs for the ComfyRain WoW addon.

Same rule as make_rain_tga.py: nothing here is Blizzard's. A sheet composited
from their Snowflake01 sprite would be redistributing their art, so every flake
is rasterised from a model instead.

The model, and why snow is not slow rain:

A raindrop is a sphere acting as a lens, and at any ordinary shutter it smears
into a streak, which is why the rain sheets are streaks. A snow crystal is a
flat, low-density aggregate perhaps a hundred times lighter for its area.
Locatelli and Hobbs measured natural solid particles falling at roughly 0.3 to
1.5 m/s against a raindrop's 9, and with a startlingly weak dependence on size:
for unrimed dendritic aggregates V = 0.80*D^0.16, so a 10mm aggregate falls
only 30% faster than a 2mm one. So a flake barely moves over one frame, and it
reads as a soft blob rather than a line. Drawing snow as short rain is the
single most common way fake snow gives itself away.

Three things follow, and all three are in here:

- Flakes are round, with a soft edge, because they are mostly out of focus. The
  far layer is pure Gaussian; only the largest near flakes resolve any
  structure.
- A faint six-fold modulation, on the biggest near flakes only. Nakaya's
  morphology diagrams and the 80 categories of the Magono-Lee scheme describe a
  population far wider than the textbook stellar dendrite, and most of what
  reaches the ground is irregular AGGREGATES rather than single crystals.
  Below a few pixels across none of it survives anyway. So this is weak,
  randomly phased, and rare - it is there to break the perfect circle on the
  handful of flakes big enough to show one, not to draw a snowflake icon.
- Elongation comes from wind, not from gravity. In still snow it is almost
  nothing. In a blizzard the horizontal wind dominates the fall speed entirely,
  so the streaks lie close to flat, and that is what the gale sheet is.

The POPULATION the flakes are drawn from is in precip.py, and matters more than
the drawing does. The snow sheets are where that mattered most: they were a
jittered grid of near-identical discs, which is a lattice, which is why they
read as a starfield. See that file's docstring.

WoW addon art must be power-of-two and, for TGA, 32-bit uncompressed. Flakes
wrap in both axes so the sheets tile without a seam.

Usage: make_snow_tga.py <out_dir>
"""
import math
import sys

import numpy as np
from PIL import Image

from precip import power_law, lognormal, cox_field, poisson_centres, stamp

SIZE = 512

# p(sigma) proportional to sigma^-EXP_SIZE. For a field of one physical size,
# projection gives exactly -4; real flakes span 1 to 6mm and more, which
# flattens it. 3.2 is the compromise. The consequence is the point: the median
# flake sits near the bottom of its range and the top of the range is a thin
# tail, so a sheet has a great many almost invisible flakes, a few obvious
# ones, and a handful of big soft close ones - instead of 800 discs all the
# same size, which is what a starfield is.
EXP_SIZE = 3.2

# Only flakes in the top HEX_TOP of the size distribution get the six-fold
# modulation, and only on the near sheet. Anything smaller is a couple of
# pixels across and the structure is invisible; putting it on everything was
# spending detail where it could not be seen and making the flakes more alike.
HEX_TOP = 0.90


def make_flake(sigma, elong, angle, hex_strength, hex_phase):
    """One flake, as a float alpha array.

    sigma is the across-wind radius in pixels, elong how many times longer it
    is along the wind, and angle the wind direction in radians measured from
    straight down.
    """
    reach = sigma * 3.0
    half = int(math.ceil(reach * max(elong, 1.0))) + 2
    n = half * 2 + 1

    g = np.arange(n) - half
    x, y = np.meshgrid(g, g)

    # Rotate into the flake's own frame: u along the direction of travel.
    ca, sa = math.cos(angle), math.sin(angle)
    u = x * sa + y * ca
    v = x * ca - y * sa

    core = np.exp(-((u / (sigma * elong)) ** 2 + (v / sigma) ** 2))

    if hex_strength > 0:
        # Six-fold modulation in the unstretched frame, weak and off-phase, so
        # the silhouette is a lumpy disc rather than a drawn snowflake.
        theta = np.arctan2(v, u / max(elong, 1e-6))
        core = core * (1.0 + hex_strength * np.cos(6.0 * theta + hex_phase))

    # A crystal is brighter at its centre where the most ice is in the path.
    core = core * (0.75 + 0.25 * np.exp(-((u / (sigma * elong * 0.5)) ** 2
                                          + (v / (sigma * 0.5)) ** 2)))

    core = np.clip(core, 0.0, None)
    peak = core.max()
    return (core / peak if peak > 0 else core).astype(np.float32)


def scatter(count, sig_lo, sig_hi, a_med, a_sig, a_lo, a_hi, seed,
            elong=1.0, elong_sig=0.0, angle=0.0, angle_sd=0.0,
            hex_strength=0.0, gust=None, thin=None):
    """Strew flakes over a sheet that wraps in both axes.

    Placement is independent and uniform. It used to be a jittered grid, one
    flake per cell, which guaranteed no bald patches - and in doing so deleted
    every close pair and every hole, which is what real snow is made of and
    what stops it looking like a pattern. See precip.poisson_centres.

    `gust`, on the gale sheet only, is (sigma, along, across): a log-Gaussian
    Cox field that makes the placement intensity vary smoothly across the
    sheet, so blowing snow comes in patches rather than at one flat density.

    `thin`, when given, also returns a second sheet holding each flake with
    that probability. The choice comes from its own generator, so the full
    sheet is bit-identical with or without it, and thinning a Poisson field
    leaves a Poisson field: light snow is the same snowfall with fewer flakes
    in it, not the same flakes drawn fainter.
    """
    rng = np.random.default_rng(seed)
    sheet = np.zeros((SIZE, SIZE), dtype=np.float32)

    sigmas = power_law(rng, count, sig_lo, sig_hi, EXP_SIZE)

    # Brightness rises with size, because a bigger flake puts more ice in the
    # path, but only as a power of 0.8 and with a wide lognormal on top. The
    # exponent is what keeps big flakes from also being the faint ones; the
    # lognormal is what stops every flake of a given size being identical.
    scale = (sigmas / sig_lo) ** 0.8
    alphas = np.clip(lognormal(rng, count, a_med, a_sig, 0.0, 1e9) * scale,
                     a_lo, a_hi)

    # Elongation is lognormal too. On the gale sheet this is the whole fix for
    # the "one motion-blur command" look: the old sheet drew every streak at
    # 5.0 +/- 2.0 uniform, a coefficient of variation of 0.23, so they really
    # were all the same length. A lognormal at sigma 0.5 gives a CV above 0.5,
    # which is what a depth-generated length distribution looks like.
    elongs = (np.maximum(1.0, lognormal(rng, count, elong, elong_sig,
                                        1.0, elong * 5.0))
              if elong_sig > 0 else np.full(count, elong))

    # Angle spread is Gaussian, not a uniform cone. A coherent mean wind with
    # turbulence around it is a few degrees of scatter; 20 degrees of uniform
    # jitter is a shower of confetti going in all directions.
    angles = angle + rng.standard_normal(count) * angle_sd

    intensity = cox_field(rng, SIZE, gust[0], gust[1], gust[2], angle) \
        if gust else None
    ys, xs = poisson_centres(rng, count, SIZE, intensity)

    thinned = np.zeros_like(sheet) if thin else None
    keep = np.random.default_rng(seed + 7919).random(count) < thin if thin else None

    big = np.quantile(sigmas, HEX_TOP)
    for i in range(count):
        hexs = (hex_strength * float(rng.uniform(0.4, 1.0))
                if hex_strength > 0 and sigmas[i] >= big else 0.0)
        f = make_flake(sigma=float(sigmas[i]), elong=float(elongs[i]),
                       angle=float(angles[i]), hex_strength=hexs,
                       hex_phase=float(rng.uniform(0, math.pi))) * alphas[i]
        stamp(sheet, f, ys[i], xs[i])
        if thin and keep[i]:
            stamp(thinned, f, ys[i], xs[i])
    return (sheet, thinned) if thin else sheet


def to_tga(alpha, path, tint):
    a = np.clip(alpha, 0.0, 1.0)
    rgb = np.stack([np.full_like(a, c) for c in tint], axis=-1)
    rgba = np.concatenate([rgb, a[..., None]], axis=-1)
    Image.fromarray((rgba * 255).astype(np.uint8), mode="RGBA").save(
        path, format="TGA", compression=None)


def main():
    out = sys.argv[1].rstrip("/")

    # Sheet pixels are not screen pixels, and sigma is not the flake either: a
    # flake's visible diameter is about 3*sigma, and the Lua then magnifies the
    # whole sheet by H/(tilesY*tiling*512) with tiling 1.20 for snow. On 1080p
    # that is 0.59 screen px per far-sheet px and 1.17 per near-sheet px.
    #
    # Sigma ranges are now the bounds of a power law, not a uniform band, so
    # the median sits near the bottom of each and the top is a thin tail. On
    # the near sheet the median flake arrives about 2.4 screen px across, the
    # 90th percentile about 5, and under 1% exceed 20.
    #
    # The history: far 900 @ 1.1-2.3, near 210 @ 2.6-6.2, gale 300 @ 1.5-3.2
    # elong 7.0, which grew as the snow got heavier because tiling was
    # per-intensity and inverted. Then far 1500 @ 0.9-1.9, near 800 @ 1.3-3.0,
    # gale 900 @ 0.9-1.9 elong 5.0, which was the right SIZE and still read as
    # a starfield, because the sizes were uniform over a factor of 2, the
    # brightnesses uniform over a factor of 2.7, one flake in ten was a bright
    # landmark, and all of them sat on a grid.

    # far: a haze of tiny out-of-focus flakes, the depth of the fall
    far = scatter(2200, 0.50, 2.60, a_med=0.077, a_sig=0.62,
                  a_lo=0.010, a_hi=0.26, seed=101,
                  elong=1.15, elong_sig=0.18, angle=0.0, angle_sd=0.18)

    # near: the layer that carries the character of the snowfall. A few large
    # soft flakes close to the camera, a great many small ones behind them.
    #
    # Light snow draws near-light, the same sheet with about half its flakes.
    # Intensity used to be layer alpha alone, and on this sheet alpha is not a
    # count control: 87% of its flakes are already visible at light's alpha,
    # so normal drew 12% more flakes at twice the brightness and light and
    # normal looked the same, 2026-10-23. A light snowfall is fewer flakes,
    # each as bright as ever.
    near, near_light = scatter(900, 1.00, 7.00, a_med=0.111, a_sig=0.70,
                               a_lo=0.012, a_hi=0.40, seed=207,
                               elong=1.3, elong_sig=0.30, angle=0.0,
                               angle_sd=0.24, hex_strength=0.07, thin=0.45)

    # gale: the wind beats gravity, so the streaks lie close to flat. 85
    # degrees off vertical, which is what ComfyRain.lua's blizzard slant of
    # 11.4301 = tan(85) scrolls at: the sheet and its travel have to point
    # the same way or it reads as a filter applied to the screen. The angle is
    # atan(wind / fall speed), and a flake settling at 0.9 m/s is already at 85
    # in the 10 m/s that defines a blizzard; 78 needs only 4.2 m/s, which is a
    # breezy flurry. Stopping short of 90 still matters - a perfectly
    # horizontal field looks like a screen wipe rather than weather.
    #
    # The gust field is what makes this a blizzard rather than a hatch
    # pattern: blowing snow is suspended by turbulence and measured
    # concentrations vary strongly from place to place, so the density here
    # varies smoothly, stretched 150px along the wind against 55px across it.
    gale = math.radians(85)
    bliz = scatter(1600, 0.55, 2.30, a_med=0.118, a_sig=0.68,
                   a_lo=0.010, a_hi=0.32, seed=313,
                   elong=4.2, elong_sig=0.50, angle=gale, angle_sd=0.13,
                   gust=(0.45, 150.0, 55.0))

    to_tga(far, f"{out}/snow-far.tga", (0.92, 0.95, 1.00))
    to_tga(near, f"{out}/snow-near.tga", (0.97, 0.98, 1.00))
    to_tga(near_light, f"{out}/snow-near-light.tga", (0.97, 0.98, 1.00))
    to_tga(bliz, f"{out}/snow-gale.tga", (0.95, 0.97, 1.00))
    print(f"wrote snow-far.tga, snow-near.tga, snow-near-light.tga and "
          f"snow-gale.tga "
          f"({SIZE}x{SIZE} 32-bit TGA), flakes rasterised from the model "
          f"- no Blizzard art")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Generate seamless snow and blizzard TGAs for the ComfyRain WoW addon.

Same rule as make_rain_tga.py: nothing here is Blizzard's. A sheet composited
from their Snowflake01 sprite would be redistributing their art, so every flake
is rasterised from a model instead.

The model, and why snow is not slow rain:

A raindrop is a sphere acting as a lens, and at any ordinary shutter it smears
into a streak, which is why the rain sheets are streaks. A snow crystal is a
flat, low-density aggregate perhaps a hundred times lighter for its area. It
falls at roughly 1 m/s rather than 9, and it tumbles. So over one frame it
barely moves, and it reads as a soft blob rather than a line. Drawing snow as
short rain is the single most common way fake snow gives itself away.

Three things follow, and all three are in here:

- Flakes are round, with a soft edge, because they are mostly out of focus. The
  far layer is pure Gaussian; only the near layer resolves any structure.
- The near layer gets a faint six-fold modulation. Real aggregates are not
  tidy hexagons, so this is weak and randomly phased - it is there to break the
  perfect circle, not to draw a snowflake icon.
- Elongation comes from wind, not from gravity. In still snow it is almost
  nothing. In a blizzard the horizontal wind dominates the fall speed entirely,
  so the streaks lie close to flat, and that is what the blizzard sheet is.

WoW addon art must be power-of-two and, for TGA, 32-bit uncompressed. Flakes
wrap in both axes so the sheets tile without a seam.

Usage: make_snow_tga.py <out_dir>
"""
import math
import sys

import numpy as np
from PIL import Image

SIZE = 512


def make_flake(sigma, elong, angle, hex_strength, hex_phase, rng):
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


def scatter(count, sigma_lo, sigma_hi, a_lo, a_hi, seed,
            elong=1.0, elong_jitter=0.0, angle=0.0, angle_jitter=0.0,
            hex_strength=0.0):
    """Strew flakes over a sheet that wraps in both axes.

    Placement is a jittered grid, not uniform random. With only a couple of
    hundred flakes, uniform random reliably leaves bald patches and clumps, and
    a 512px sheet that tiles across the screen repeats any such blotch four or
    five times where it is impossible to unsee. One flake per cell at a random
    offset inside it keeps the spacing irregular without ever leaving a hole.
    """
    rng = np.random.default_rng(seed)
    sheet = np.zeros((SIZE, SIZE), dtype=np.float32)

    cells = int(math.ceil(math.sqrt(count)))
    step = SIZE / cells
    slots = [(i, j) for i in range(cells) for j in range(cells)]
    rng.shuffle(slots)
    slots = slots[:count]

    for ci, cj in slots:
        f = make_flake(
            sigma=float(rng.uniform(sigma_lo, sigma_hi)),
            elong=max(1.0, elong + rng.uniform(-elong_jitter, elong_jitter)),
            angle=angle + rng.uniform(-angle_jitter, angle_jitter),
            hex_strength=hex_strength * float(rng.uniform(0.4, 1.0)),
            hex_phase=float(rng.uniform(0, math.pi)),
            rng=rng,
        ) * float(rng.uniform(a_lo, a_hi))

        # One flake in ten is a clump of several crystals and reads brighter.
        if rng.random() < 0.10:
            f = np.clip(f * 1.8, 0.0, 1.0)

        fh, fw = f.shape
        cy = int((ci + rng.random()) * step) % SIZE
        cx = int((cj + rng.random()) * step) % SIZE
        ys = (cy + np.arange(fh)) % SIZE
        xs = (cx + np.arange(fw)) % SIZE
        idx = np.ix_(ys, xs)
        sheet[idx] = np.maximum(sheet[idx], f)
    return sheet


def to_tga(alpha, path, tint):
    a = np.clip(alpha, 0.0, 1.0)
    rgb = np.stack([np.full_like(a, c) for c in tint], axis=-1)
    rgba = np.concatenate([rgb, a[..., None]], axis=-1)
    Image.fromarray((rgba * 255).astype(np.uint8), mode="RGBA").save(
        path, format="TGA", compression=None)


def main():
    out = sys.argv[1].rstrip("/")

    # far: a haze of tiny out-of-focus flakes, the depth of the fall
    far = scatter(900, 1.1, 2.3, 0.05, 0.16, seed=101,
                  elong=1.15, elong_jitter=0.2, angle=0.0, angle_jitter=0.35)

    # near: fewer, larger, resolved enough to show an edge
    near = scatter(210, 2.6, 6.2, 0.14, 0.38, seed=207,
                   elong=1.3, elong_jitter=0.35, angle=0.0, angle_jitter=0.45,
                   hex_strength=0.07)

    # blizzard: the wind beats gravity, so the streaks lie close to flat. 78
    # degrees off vertical, not 90, because a perfectly horizontal field looks
    # like a screen wipe rather than weather.
    gale = math.radians(78)
    bliz = scatter(300, 1.5, 3.2, 0.09, 0.30, seed=313,
                   elong=7.0, elong_jitter=3.0, angle=gale, angle_jitter=0.12)

    to_tga(far, f"{out}/snow-far.tga", (0.92, 0.95, 1.00))
    to_tga(near, f"{out}/snow-near.tga", (0.97, 0.98, 1.00))
    to_tga(bliz, f"{out}/snow-gale.tga", (0.95, 0.97, 1.00))
    print(f"wrote snow-far.tga, snow-near.tga and snow-gale.tga "
          f"({SIZE}x{SIZE} 32-bit TGA), flakes rasterised from the model "
          f"- no Blizzard art")


if __name__ == "__main__":
    main()

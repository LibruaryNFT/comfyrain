#!/usr/bin/env python3
"""Generate seamless rain-streak TGAs for the AlwaysRain WoW addon.

The drops are Blizzard's own particle sprite, Textures/WEATHER/RainDrop01.blp
(FileDataID 186226), scattered into a tiling sheet instead of drawn by hand.
The client renders that sprite one drop at a time through its particle system;
an addon cannot reach the particle system, so we tile it into a curtain.

The sprite is fetched once from wago.tools and cached in build/assets/. It is
read-only reference art - nothing is shipped from it except the composited
sheet, which is regenerated on every install.

WoW addon art must be power-of-two and, for TGA, 32-bit uncompressed.
Drops wrap in both axes so the sheet tiles without a seam.

Usage: make_rain_tga.py <out_dir>
"""
import os
import subprocess
import sys

import numpy as np
from PIL import Image

SIZE = 512
SLANT_DEG = 7.5          # must match SLANT in AlwaysRain.lua as tan(SLANT_DEG)
DROP_FDID = 186226
CACHE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "assets")


def drop_sprite():
    """Blizzard's RainDrop01 alpha channel, cached locally."""
    os.makedirs(CACHE, exist_ok=True)
    path = os.path.join(CACHE, f"{DROP_FDID}.blp")
    if not os.path.exists(path):
        subprocess.run(
            ["curl", "-sL", "--max-time", "60", "-o", path,
             f"https://wago.tools/api/casc/{DROP_FDID}?download"], check=True)
    im = Image.open(path).convert("RGBA")
    return np.asarray(im)[..., 3].astype(np.float32) / 255.0


def scatter(sprite, count, h_lo, h_hi, w_lo, w_hi, a_lo, a_hi, seed):
    """Width is set in absolute pixels, not scaled with length: the source
    sprite is 16x128 and scaling it proportionally gives 30px-wide bars."""
    rng = np.random.default_rng(seed)
    sheet = np.zeros((SIZE, SIZE), dtype=np.float32)
    for _ in range(count):
        h = int(rng.uniform(h_lo, h_hi))
        w = max(1, int(round(rng.uniform(w_lo, w_hi))))
        drop = Image.fromarray((sprite * 255).astype(np.uint8)).resize((w, h), Image.BILINEAR)
        if SLANT_DEG:
            drop = drop.rotate(-SLANT_DEG, resample=Image.BILINEAR, expand=True)
        d = np.asarray(drop).astype(np.float32) / 255.0 * rng.uniform(a_lo, a_hi)
        dh, dw = d.shape
        y0 = int(rng.integers(0, SIZE))
        x0 = int(rng.integers(0, SIZE))
        ys = (y0 + np.arange(dh)) % SIZE
        xs = (x0 + np.arange(dw)) % SIZE
        patch = sheet[np.ix_(ys, xs)]
        sheet[np.ix_(ys, xs)] = np.maximum(patch, d)
    return sheet


def to_tga(alpha, path, tint):
    a = np.clip(alpha, 0.0, 1.0)
    rgb = np.stack([np.full_like(a, c) for c in tint], axis=-1)
    rgba = np.concatenate([rgb, a[..., None]], axis=-1)
    Image.fromarray((rgba * 255).astype(np.uint8), mode="RGBA").save(
        path, format="TGA", compression=None)


def main():
    out = sys.argv[1].rstrip("/")
    sprite = drop_sprite()

    # far: short, thin, faint - reads as the depth of the downpour
    far = scatter(sprite, 260, 20, 46, 1.0, 1.4, 0.06, 0.18, seed=11)
    # near: long, brighter streaks passing close to the camera
    near = scatter(sprite, 70, 80, 190, 1.2, 2.2, 0.18, 0.46, seed=29)

    to_tga(far, f"{out}/rain-far.tga", (0.86, 0.90, 0.97))
    to_tga(near, f"{out}/rain-near.tga", (0.93, 0.96, 1.00))
    print(f"wrote rain-far.tga and rain-near.tga ({SIZE}x{SIZE} 32-bit TGA) "
          f"from Blizzard RainDrop01 (fdid {DROP_FDID})")


if __name__ == "__main__":
    main()

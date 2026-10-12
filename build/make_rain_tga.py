#!/usr/bin/env python3
"""Generate seamless rain-streak TGAs for the AlwaysRain WoW addon.

Nothing here is Blizzard's. Blizzard's addon policy forbids redistributing their
copyrighted material, and a sheet composited from their RainDrop01 sprite would
be exactly that, so every drop is rasterised from an optical model instead.

That model: a raindrop is a small sphere acting as a lens, and over one frame it
smears into a streak. Across its width that gives a Gaussian - the drop's own
blur circle. Along its length it is bright at the leading end and fades towards
the tail, because the head is where the specular highlight sits. Both ends are
windowed to nothing so no drop terminates in a chopped edge.

Deriving it rather than copying it also buys variety a single sprite cannot
have: every drop gets its own taper rate and a little curvature, and the slant
is sheared in while rasterising, so no pixel is ever resampled and the thin
streaks stay crisp.

WoW addon art must be power-of-two and, for TGA, 32-bit uncompressed. Drops wrap
in both axes so the sheet tiles without a seam.

Usage: make_rain_tga.py <out_dir>
"""
import math
import sys

import numpy as np
from PIL import Image

SIZE = 512
SLANT_DEG = 7.5                            # must match SLANT in AlwaysRain.lua
SLANT = math.tan(math.radians(SLANT_DEG))  # ... as its tangent, 0.1317


def make_drop(length, core_w, taper, curve, rng):
    """One motion-blurred drop, as a float alpha array."""
    shear = SLANT * length
    width = int(math.ceil(core_w * 3.0 + abs(shear))) + 2

    t = np.arange(length) / max(length - 1, 1)   # 0 at the tail, 1 at the head

    # Bright at the head, fading up the tail.
    env = np.exp(-taper * (1.0 - t))
    # Window both ends to zero over roughly one drop-width, so the streak has
    # rounded ends instead of being sliced off.
    env *= np.clip((1.0 - t) * length / max(core_w * 1.2, 1.0), 0.0, 1.0)
    env *= np.clip(t * length / max(core_w * 2.5, 1.0), 0.0, 1.0)

    # Centre line: the shear that produces the slant, plus a little curvature.
    cx = (width - 1) / 2.0 + (t - 0.5) * shear + curve * (t - 0.5) ** 2 * core_w

    xs = np.arange(width)[None, :]
    sigma = max(core_w / 2.0, 0.45)
    g = np.exp(-(((xs - cx[:, None]) / sigma) ** 2))

    drop = g * env[:, None]
    peak = drop.max()
    return (drop / peak if peak > 0 else drop).astype(np.float32)


def scatter(count, h_lo, h_hi, w_lo, w_hi, a_lo, a_hi, seed):
    """Strew drops over a sheet that wraps in both axes.

    Width is an absolute pixel count, not a fraction of length: real rain stays
    hair-thin however long the streak is.
    """
    rng = np.random.default_rng(seed)
    sheet = np.zeros((SIZE, SIZE), dtype=np.float32)
    for _ in range(count):
        h = int(rng.uniform(h_lo, h_hi))
        w = float(rng.uniform(w_lo, w_hi))
        d = make_drop(h, w,
                      taper=rng.uniform(1.4, 3.2),
                      curve=rng.uniform(-1.5, 1.5),
                      rng=rng) * rng.uniform(a_lo, a_hi)
        # One drop in twelve catches the light and reads noticeably brighter.
        if rng.random() < 0.08:
            d = np.clip(d * 1.9, 0.0, 1.0)

        dh, dw = d.shape
        ys = (int(rng.integers(0, SIZE)) + np.arange(dh)) % SIZE
        xs = (int(rng.integers(0, SIZE)) + np.arange(dw)) % SIZE
        idx = np.ix_(ys, xs)
        sheet[idx] = np.maximum(sheet[idx], d)
    return sheet


def to_tga(alpha, path, tint):
    a = np.clip(alpha, 0.0, 1.0)
    rgb = np.stack([np.full_like(a, c) for c in tint], axis=-1)
    rgba = np.concatenate([rgb, a[..., None]], axis=-1)
    Image.fromarray((rgba * 255).astype(np.uint8), mode="RGBA").save(
        path, format="TGA", compression=None)


def main():
    out = sys.argv[1].rstrip("/")

    # far: short, thin, faint - reads as the depth of the downpour
    far = scatter(260, 20, 46, 1.0, 1.4, 0.06, 0.18, seed=11)
    # near: long, brighter streaks passing close to the camera
    near = scatter(70, 80, 190, 1.2, 2.2, 0.18, 0.46, seed=29)

    to_tga(far, f"{out}/rain-far.tga", (0.86, 0.90, 0.97))
    to_tga(near, f"{out}/rain-near.tga", (0.93, 0.96, 1.00))
    print(f"wrote rain-far.tga and rain-near.tga ({SIZE}x{SIZE} 32-bit TGA), "
          f"drops rasterised from the optical model - no Blizzard art")


if __name__ == "__main__":
    main()

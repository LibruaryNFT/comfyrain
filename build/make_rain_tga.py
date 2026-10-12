#!/usr/bin/env python3
"""Generate seamless rain-streak TGAs for the AlwaysRain WoW addon.

WoW addon art must be power-of-two and, for TGA, 32-bit uncompressed.
Streaks wrap in both axes so the texture tiles without a visible seam.

Usage: make_rain_tga.py <out_dir>
"""
import sys
import numpy as np
from PIL import Image

SIZE = 256
SLANT = 0.14  # x drift per y pixel; must match the scroll vector in Lua


def streak_layer(n_streaks, len_lo, len_hi, width_lo, width_hi, a_lo, a_hi, seed):
    rng = np.random.default_rng(seed)
    buf = np.zeros((SIZE, SIZE), dtype=np.float32)
    for _ in range(n_streaks):
        x0 = rng.uniform(0, SIZE)
        y0 = rng.uniform(0, SIZE)
        length = rng.uniform(len_lo, len_hi)
        width = rng.uniform(width_lo, width_hi)
        peak = rng.uniform(a_lo, a_hi)
        steps = int(length * 2)
        for i in range(steps):
            t = i / max(steps - 1, 1)
            y = (y0 + t * length) % SIZE
            x = (x0 + t * length * SLANT) % SIZE
            # taper head and tail so streaks look like falling drops
            taper = min(1.0, (1.0 - abs(2.0 * t - 1.0)) * 2.2)
            amp = peak * taper
            half = max(width, 0.6)
            lo = int(np.floor(x - half))
            hi = int(np.ceil(x + half))
            yi = int(y)
            for xi in range(lo, hi + 1):
                d = abs((xi + 0.5) - x)
                if d > half:
                    continue
                falloff = 1.0 - (d / half) ** 2
                xw = xi % SIZE
                buf[yi, xw] = max(buf[yi, xw], amp * falloff)
    return buf


def to_tga(alpha, path, tint=(1.0, 1.0, 1.0)):
    a = np.clip(alpha, 0.0, 1.0)
    rgb = np.stack([a * tint[0], a * tint[1], a * tint[2]], axis=-1)
    # premultiplied look is wrong for WoW's ADD/BLEND layers; keep flat white RGB
    rgb = np.stack([np.full_like(a, tint[0]), np.full_like(a, tint[1]),
                    np.full_like(a, tint[2])], axis=-1)
    rgba = np.concatenate([rgb, a[..., None]], axis=-1)
    img = Image.fromarray((rgba * 255).astype(np.uint8), mode="RGBA")
    img.save(path, format="TGA", compression=None)
    return path


def main():
    out = sys.argv[1].rstrip("/")
    # far layer: thin faint streaks -> reads as distance haze of rain
    far = streak_layer(120, 12, 26, 0.5, 0.8, 0.07, 0.20, seed=11)
    # near layer: fewer, longer, brighter streaks -> reads as rain close to camera
    near = streak_layer(42, 34, 76, 0.8, 1.5, 0.22, 0.55, seed=29)
    to_tga(far, f"{out}/rain-far.tga", tint=(0.86, 0.90, 0.97))
    to_tga(near, f"{out}/rain-near.tga", tint=(0.93, 0.96, 1.0))
    print(f"wrote {out}/rain-far.tga and {out}/rain-near.tga ({SIZE}x{SIZE} 32-bit TGA)")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Generate seamless rain-streak TGAs for the ComfyRain WoW addon.

Nothing here is Blizzard's. Blizzard's addon policy forbids redistributing their
copyrighted material, and a sheet composited from their RainDrop01 sprite would
be exactly that, so every drop is rasterised from an optical model instead.

That model: a raindrop is a small sphere acting as a lens, and over one frame it
smears into a streak. Across its width that gives a Gaussian - the drop's own
blur circle. Along its length Garg and Nayar's measurements of real streaks show
no single profile at all: refraction, surface reflection and the drop's own
oscillation give a different pattern of lobes and highlights for every viewing
and lighting direction, usually but not always brightest near the head. Both
ends are windowed to nothing so no drop terminates in a chopped edge.

Deriving it rather than copying it also buys variety a single sprite cannot
have: every drop gets its own longitudinal profile, its own curvature, and a
slant sheared in while rasterising, so no pixel is ever resampled and the thin
streaks stay crisp.

The POPULATION the drops are drawn from is in precip.py, and matters more than
the drawing does. See that file's docstring.

WoW addon art must be power-of-two and, for TGA, 32-bit uncompressed. Drops wrap
in both axes so the sheet tiles without a seam.

Usage: make_rain_tga.py <out_dir>
"""
import math
import sys

import numpy as np
from PIL import Image

from precip import power_law, lognormal, poisson_centres, stamp

SIZE = 512
SLANT_DEG = 7.5                            # must match rain.slant in ComfyRain.lua
SLANT = math.tan(math.radians(SLANT_DEG))  # ... as its tangent, 0.1317

# p(L) proportional to L^-EXP_LENGTH. Streak length is f*v(D)*T/z, so it
# inherits the 1/z of the projection and would be s^-4 for one drop size; drop
# diameter varies too, and v goes as D^0.67 rather than D, which flattens it.
# 3.0 is the compromise, and the shape is what matters: most streaks near the
# short end, a thin tail of long close ones, no streaks that are all one length.
EXP_LENGTH = 3.0


def make_drop(length, core_w, curve, rng):
    """One motion-blurred drop, as a float alpha array."""
    shear = SLANT * length
    width = int(math.ceil(core_w * 3.0 + abs(shear))) + 2

    t = np.arange(length) / max(length - 1, 1)   # 0 at the tail, 1 at the head

    # Longitudinal brightness: two to four broad lobes, each with its own
    # period, phase and weight, over a floor.
    #
    # This replaces a single exp(-taper*(1-t)) that every drop in the sheet
    # shared. One universal profile is a repeated cue - every streak was the
    # same shape, so the eye learned it once and then found it everywhere - and
    # it is not what real streaks look like either. Garg and Nayar photographed
    # thousands of them across lighting and view directions and found multiple
    # smeared highlights and non-monotonic brightness, not a head with a tail.
    env = np.full_like(t, 0.30)
    for _ in range(int(rng.integers(2, 5))):
        cycles = rng.uniform(0.5, 2.5)
        phase = rng.uniform(0.0, 2.0 * math.pi)
        env += rng.uniform(0.15, 0.55) * (
            0.5 + 0.5 * np.cos(2.0 * math.pi * cycles * t + phase))

    # Keep a head bias on average, because the specular highlight usually does
    # sit near the leading end, but let how much of one vary per drop.
    head = rng.uniform(0.2, 0.9)
    env *= (1.0 - head) + head * np.exp(-rng.uniform(1.4, 3.2) * (1.0 - t))

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


def scatter(count, len_lo, len_hi, w_lo, w_hi, a_med, a_sig, a_lo, a_hi, seed):
    """Strew drops over a sheet that wraps in both axes.

    Width is an absolute pixel count, not a fraction of length: real rain stays
    hair-thin however long the streak is. It is CORRELATED with length rather
    than drawn independently, because both are the same 1/z: a drop close
    enough to leave a long streak is also close enough to be a wide one, and
    close enough to be out of the camera's focus. Independent draws produced
    long hairlines and short fat dashes, neither of which is a raindrop.
    """
    rng = np.random.default_rng(seed)
    sheet = np.zeros((SIZE, SIZE), dtype=np.float32)

    lengths = power_law(rng, count, len_lo, len_hi, EXP_LENGTH)
    alphas = lognormal(rng, count, a_med, a_sig, a_lo, a_hi)
    ys, xs = poisson_centres(rng, count, SIZE)

    # Where each drop sits between the shortest and the longest, which is a
    # stand-in for how close it is. Widths ride it, loosely: the scatter is
    # there because drop diameter varies independently of depth.
    depth = np.clip((lengths - len_lo) / max(len_hi - len_lo, 1e-9), 0.0, 1.0)
    widths = np.clip((w_lo + (w_hi - w_lo) * depth ** 0.7)
                     * rng.uniform(0.82, 1.22, count), w_lo * 0.75, w_hi * 1.15)

    for i in range(count):
        d = make_drop(int(lengths[i]), float(widths[i]),
                      curve=rng.uniform(-1.5, 1.5), rng=rng) * alphas[i]
        stamp(sheet, d, ys[i], xs[i])
    return sheet


def to_tga(alpha, path, tint):
    a = np.clip(alpha, 0.0, 1.0)
    rgb = np.stack([np.full_like(a, c) for c in tint], axis=-1)
    rgba = np.concatenate([rgb, a[..., None]], axis=-1)
    Image.fromarray((rgba * 255).astype(np.uint8), mode="RGBA").save(
        path, format="TGA", compression=None)


def main():
    out = sys.argv[1].rstrip("/")

    # Sheet pixels are not screen pixels. The Lua scales each sheet so tilesY
    # copies span the screen height, and tilesY is multiplied by the weather's
    # tiling, 1.35 for rain. On a 1080p screen that makes a far-sheet pixel
    # 0.52 screen pixels and a near-sheet pixel 1.04, so these numbers have to
    # be read through that factor before they mean anything.
    #
    # Lengths are now a range for a power law to fill rather than a uniform
    # band, and the bands below land where photography does. At 21ms, the film
    # standard, Marshall-Palmer drops at 25 mm/h give streaks whose 5th to 95th
    # percentiles run about 29 to 95 screen pixels for the resolvable ones.
    # far arrives as 5-21 screen px and near as 10-75, with the power law
    # putting the great majority of both near the short end.
    #
    # The history: these were far 20-46 / near 80-190 uniform, which measured
    # 546px on screen - 51% of the frame height - across 53 streaks. Then far
    # 14-34 / near 16-40 uniform, which was the right size and still read as a
    # pattern, because every streak was within a factor of 2.5 of every other
    # one and one in twelve was a bright landmark.

    # far: short, thin, faint - reads as the depth of the downpour
    far = scatter(850, 10, 40, 0.75, 1.60,
                  a_med=0.128, a_sig=0.50, a_lo=0.020, a_hi=0.30, seed=11)

    # near: streaks passing close to the camera. Longer, but mostly only a
    # little longer: the depth cue is brightness and width, and the width here
    # is deliberately the greater of the two, because rain this close to the
    # lens is out of its focus. Garg and Nayar treat near rain as defocused
    # even where the scene behind it is sharp, and a near layer made only of
    # razor-thin high-alpha bars is the look that reads as drawn-on.
    def near_drops(count, seed):
        return scatter(count, 10, 72, 0.95, 2.90,
                       a_med=0.163, a_sig=0.62, a_lo=0.030, a_hi=0.46, seed=seed)

    near = near_drops(420, 29)

    # Heavy and monsoon draw denser near sheets: normal's drops with more
    # strewn among them, 1.8x and then 2x again. Intensity used to be alpha
    # and speed alone, and every drop on this sheet is already visible at
    # normal's alpha, so heavy and monsoon showed the same 420 drops brighter
    # and barely faster (tools/perceive.py, 2026-10-23). A heavier downpour is
    # more drops. The extra ones come from their own seeds, so normal is
    # unchanged, and adding one Poisson field to another leaves a Poisson field.
    # Overlapping drops merge into one streak, so the count a player sees
    # grows slower than the count drawn: these land at about 1.5x each.
    heavy = np.maximum(near, near_drops(336, 31))
    monsoon = np.maximum(heavy, near_drops(756, 37))

    to_tga(far, f"{out}/rain-far.tga", (0.86, 0.90, 0.97))
    to_tga(near, f"{out}/rain-near.tga", (0.93, 0.96, 1.00))
    to_tga(heavy, f"{out}/rain-near-heavy.tga", (0.93, 0.96, 1.00))
    to_tga(monsoon, f"{out}/rain-near-monsoon.tga", (0.93, 0.96, 1.00))
    print(f"wrote rain-far.tga, rain-near.tga, rain-near-heavy.tga and "
          f"rain-near-monsoon.tga ({SIZE}x{SIZE} 32-bit TGA), "
          f"drops rasterised from the optical model - no Blizzard art")


if __name__ == "__main__":
    main()

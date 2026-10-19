#!/usr/bin/env python3
"""Generate Duskfall's addon icon.

Two things read this file. The in-game addon list draws it next to the title
(`## IconTexture` in the .toc), and the minimap button uses the same art, so it
has to survive being drawn at 64px, at 20px, and on top of whatever the player
has behind the minimap.

That constraint is the whole design. At 20 pixels there is room for exactly one
silhouette, so the icon is a dusk gradient with rain falling across it and a
dark horizon line - three shapes, no detail, no text. It is deliberately NOT a
cloud: a cloud at 20px is an indistinct blob, and half the addons in the
"weather" category already use one.

Nothing here is Blizzard's. Same rule as the rain sheets: every pixel is
rasterised from a model rather than lifted from the client's art.

WoW addon art must be power-of-two and, for TGA, 32-bit uncompressed. 64x64 is
the size the addon list and the minimap both want; anything larger is downsampled
by the client with no mipmaps, which is how an icon ends up shimmering.

Usage: make_icon_tga.py <out_dir>
"""
import math
import sys

import numpy as np
from PIL import Image

SIZE = 64
HORIZON = 0.82          # fraction down the icon where the ground starts
SLANT_DEG = 7.5         # matches the rain sheets, so the two read as one addon
SLANT = math.tan(math.radians(SLANT_DEG))

# Dusk, top to bottom: a cold deep blue overhead falling to a warmer band at the
# horizon. Sampled to read as evening rather than as night, because a near-black
# icon disappears against the addon list's dark background.
SKY_TOP = (0.106, 0.139, 0.243)
SKY_LOW = (0.325, 0.267, 0.310)
GROUND = (0.055, 0.067, 0.102)
DROP = (0.84, 0.90, 1.00)


def vignette():
    """Darken the corners so the icon reads as round-ish at minimap size."""
    y, x = np.mgrid[0:SIZE, 0:SIZE]
    cy = cx = (SIZE - 1) / 2.0
    r = np.hypot(y - cy, x - cx) / (SIZE / 2.0)
    return np.clip(1.0 - 0.55 * np.clip(r - 0.55, 0, None) ** 1.6, 0.0, 1.0)


def sky():
    """The dusk gradient, a glow at the horizon, and the ground band under it.

    The glow is doing real work and is not decoration. At 20 pixels the rain is
    gone and all that survives is large-scale contrast, so the icon needs one
    unmistakable light-to-dark edge to read as "a sky above a landscape" rather
    than as a grey square. That edge is the horizon.
    """
    rows = np.linspace(0.0, 1.0, SIZE)[:, None]
    t = np.clip(rows / HORIZON, 0.0, 1.0) ** 1.35
    rgb = np.empty((SIZE, SIZE, 3), dtype=np.float64)
    for c in range(3):
        rgb[..., c] = SKY_TOP[c] + (SKY_LOW[c] - SKY_TOP[c]) * t

    # A warm band hugging the horizon from above, falling off over ~18% of the
    # icon. Brightest right at the line, which is where the contrast is wanted.
    d = np.clip((HORIZON - rows) / 0.18, 0.0, 1.0)
    glow = np.clip(1.0 - d, 0.0, 1.0) ** 2.2
    glow = np.where(rows >= HORIZON, 0.0, glow)
    for c, warm in enumerate((0.74, 0.47, 0.42)):
        rgb[..., c] += (warm - rgb[..., c]) * glow * 0.55

    for c in range(3):
        rgb[..., c] = np.where(rows >= HORIZON, GROUND[c], rgb[..., c])
    return rgb


def rain(rng, count=18):
    """Slanted streaks, fading out as they approach the ground.

    Few and long rather than many and short. A dense field of short drops is
    the physically honest version and it is also the one that dissolves into
    grey noise the moment the icon is drawn at minimap size; eighteen streaks
    that each cross a third of the sky still read as rain at 20 pixels.

    They stop at the horizon. Rain drawn over the dark band below reads as
    scratches on the icon, not as weather.
    """
    acc = np.zeros((SIZE, SIZE), dtype=np.float64)
    for _ in range(count):
        length = int(rng.integers(14, 27))
        x0 = rng.uniform(-6, SIZE + 6)
        y0 = rng.uniform(-14, SIZE * HORIZON - 6)
        bright = rng.uniform(0.55, 1.0)
        for i in range(length):
            t = i / max(length - 1, 1)
            y = y0 + i
            x = x0 + SLANT * i
            if not (0 <= y < SIZE * HORIZON):
                continue
            # Bright at the head, tapering to nothing at the tail, and dimmed
            # as it nears the horizon so the streaks do not pile up into a bar.
            a = bright * (0.30 + 0.70 * t)
            a *= 1.0 - 0.55 * (y / (SIZE * HORIZON)) ** 2
            # Written with a one-pixel smear either side, so a slanted line is
            # not a staircase at this size.
            xi = int(math.floor(x))
            frac = x - xi
            for dx, w in ((0, 1.0 - frac), (1, frac)):
                px = xi + dx
                if 0 <= px < SIZE:
                    acc[int(y), px] = max(acc[int(y), px], a * w)
    return acc


def main():
    out = sys.argv[1].rstrip("/")
    rng = np.random.default_rng(7)

    rgb = sky()
    streaks = rain(rng)[..., None]
    rgb = rgb * (1.0 - streaks) + np.array(DROP) * streaks
    rgb *= vignette()[..., None]

    # Fully opaque. An icon with soft edges looks like a rendering bug in the
    # addon list, which draws it inside its own square frame.
    rgba = np.concatenate([np.clip(rgb, 0, 1), np.ones((SIZE, SIZE, 1))], axis=-1)
    Image.fromarray((rgba * 255).astype(np.uint8), mode="RGBA").save(
        f"{out}/icon.tga", format="TGA", compression=None)
    print(f"wrote icon.tga ({SIZE}x{SIZE} 32-bit TGA)")


if __name__ == "__main__":
    main()

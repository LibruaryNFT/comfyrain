#!/usr/bin/env python3
"""Generate ComfyRain's addon icon.

Two things read this file. The in-game addon list draws it next to the title
(`## IconTexture` in the .toc), and the minimap button uses the same art, so it
has to survive being drawn at 64px, at 20px, and on top of whatever the player
has behind the minimap.

That constraint is the whole design, and the first version of this icon lost
to it. It was a dusk gradient with rain streaks across it, which at 64 pixels
looks like weather and at 20 pixels looks like grey noise with a pink line in
it, because streaks are high-frequency detail and high-frequency detail is the
first thing a downsample throws away. What survives a downsample is one bold
silhouette against a contrasting ground, and nothing else.

So: a single raindrop, filling most of the frame, dark-outlined, over a dusk
sky with the horizon glow behind it. The drop is glassy rather than flat and
carries a reflection of the same horizon inside it, which is detail that is
allowed to exist because it is *inside* a shape that still reads when the
detail is gone. The streaks are still there and are now background texture at
low contrast rather than the subject.

Not a cloud, deliberately. A cloud at 20px is an indistinct blob and half the
weather category already uses one. A drop is the one weather shape with a
silhouette distinctive enough to survive at that size.

Nothing here is Blizzard's. Same rule as the rain sheets: every pixel is
rasterised from a model rather than lifted from the client's art.

WoW addon art must be power-of-two and, for TGA, 32-bit uncompressed. 64x64 is
the size the addon list and the minimap both want; anything larger is downsampled
by the client with no mipmaps, which is how an icon ends up shimmering. This
renders at 4x and resamples once, here, where the filter is a good one.

Usage: make_icon_tga.py <out_dir>
"""
import math
import sys

import numpy as np
from PIL import Image

SIZE = 64
SS = 4                  # supersample factor; everything below works at SIZE*SS
N = SIZE * SS

HORIZON = 0.84          # fraction down the frame where the ground starts
SLANT_DEG = 7.5         # matches the rain sheets, so the two read as one addon
SLANT = math.tan(math.radians(SLANT_DEG))

# Dusk, top to bottom: a cold deep blue overhead falling to a warmer band at the
# horizon. Sampled to read as evening rather than as night, because a near-black
# icon disappears against the addon list's dark background.
SKY_TOP = (0.071, 0.098, 0.196)
SKY_LOW = (0.325, 0.267, 0.310)
GROUND = (0.035, 0.043, 0.071)
WARM = (0.80, 0.49, 0.40)

# The drop. Cooler than the sky it sits in, so it separates by hue as well as
# by value - a greyscale-only separation vanishes for the ~8% of players with
# a colour vision deficiency only if the values match, so the values differ too.
DROP_DEEP = (0.129, 0.243, 0.392)
DROP_PALE = (0.72, 0.88, 1.00)
DROP_RIM = (0.58, 0.80, 1.00)
OUTLINE = (0.016, 0.031, 0.063)


def grid():
    """Pixel-centre coordinates in 0..1 across the supersampled frame."""
    y, x = np.mgrid[0:N, 0:N]
    return (y + 0.5) / N, (x + 0.5) / N


def sky(yy):
    """The dusk gradient, a glow at the horizon, and the ground band under it.

    The glow is doing real work and is not decoration. At 20 pixels the rain is
    gone and all that survives is large-scale contrast, so the icon needs one
    unmistakable light-to-dark edge. That edge is the horizon, and the drop is
    posed in front of it.
    """
    t = np.clip(yy / HORIZON, 0.0, 1.0) ** 1.35
    rgb = np.empty((N, N, 3), dtype=np.float64)
    for c in range(3):
        rgb[..., c] = SKY_TOP[c] + (SKY_LOW[c] - SKY_TOP[c]) * t

    # A warm band hugging the horizon from above, falling off over ~22% of the
    # frame. Brightest right at the line, which is where the contrast is wanted.
    d = np.clip((HORIZON - yy) / 0.22, 0.0, 1.0)
    glow = np.clip(1.0 - d, 0.0, 1.0) ** 2.0
    glow = np.where(yy >= HORIZON, 0.0, glow)
    for c in range(3):
        rgb[..., c] += (WARM[c] - rgb[..., c]) * glow * 0.60

    for c in range(3):
        rgb[..., c] = np.where(yy >= HORIZON, GROUND[c], rgb[..., c])
    return rgb


def streaks(rng, yy, count=22):
    """Background rain: slanted, low contrast, stopping at the horizon.

    Demoted from subject to texture. These are what made the old icon mush at
    minimap size, so they are drawn at a third of the old brightness: present
    at 64px, invisible at 20px, and never competing with the drop.
    """
    acc = np.zeros((N, N), dtype=np.float64)
    top = N * HORIZON
    for _ in range(count):
        length = int(rng.integers(0.22 * N, 0.42 * N))
        x0 = rng.uniform(-0.1 * N, 1.1 * N)
        y0 = rng.uniform(-0.2 * N, top - 0.1 * N)
        bright = rng.uniform(0.35, 0.75)
        half = max(1, int(round(0.008 * N)))
        for i in range(length):
            t = i / max(length - 1, 1)
            y = int(y0 + i)
            if not (0 <= y < top):
                continue
            x = x0 + SLANT * i
            a = bright * (0.30 + 0.70 * t)
            a *= 1.0 - 0.55 * (y / top) ** 2
            for dx in range(-half, half + 1):
                px = int(x) + dx
                if 0 <= px < N:
                    acc[y, px] = max(acc[y, px], a)
    return acc


def teardrop(yy, xx, cx=0.50, cy=0.590, r=0.258, apex=0.095):
    """Signed coverage of a classic teardrop: a disc with a cone on top.

    Built from the tangent lines rather than from a squashed curve, because the
    join has to be exactly smooth - a teardrop with a visible kink in its
    shoulder reads as a bad polygon, and at 64 pixels one wrong row is 1.5% of
    the height. Returns distance in frame units, negative inside.
    """
    d = cy - apex                      # apex to circle centre
    sin_t = r / d
    cos_t = math.sqrt(max(1e-9, 1.0 - sin_t * sin_t))
    y_tan = cy - r * sin_t             # where the cone meets the disc
    slope = sin_t / cos_t              # half-width gained per unit of height

    dx = np.abs(xx - cx)
    dy = yy - apex

    # Cone region: distance to the two tangent lines through the apex.
    cone = (dx * cos_t - dy * sin_t)
    # Behind the apex the nearest point of the cone is the apex itself.
    cone = np.where(dy < 0, np.hypot(dx, dy), cone)

    disc = np.hypot(xx - cx, yy - cy) - r

    return np.where(yy < y_tan, cone, disc)


def coverage(sdf, softness=0.0035):
    """Antialiased 0..1 fill from a signed distance field."""
    return np.clip(0.5 - sdf / softness, 0.0, 1.0)


def main():
    out = sys.argv[1].rstrip("/")
    rng = np.random.default_rng(11)

    yy, xx = grid()

    rgb = sky(yy)
    s = streaks(rng, yy)[..., None]
    rgb = rgb * (1.0 - s * 0.45) + np.array((0.84, 0.90, 1.00)) * s * 0.45

    sdf = teardrop(yy, xx)
    inside = coverage(sdf)
    # The outline is an annulus just outside the fill. It is the single most
    # load-bearing element at minimap size: without it the drop's lower half
    # sits on the horizon glow at nearly the same value and the silhouette
    # breaks in two.
    ring = coverage(sdf - 0.022) - inside

    # Glass. A vertical ramp from pale at the shoulder to deep at the belly,
    # plus the horizon reflected back as a bright band across the lower third,
    # which is what stops it reading as a flat blue pebble.
    g = np.clip((yy - 0.12) / 0.62, 0.0, 1.0)
    drop = np.empty_like(rgb)
    for c in range(3):
        drop[..., c] = DROP_PALE[c] + (DROP_DEEP[c] - DROP_PALE[c]) * g ** 0.85

    refl = np.exp(-(((yy - 0.625) / 0.075) ** 2))
    for c in range(3):
        drop[..., c] += (WARM[c] - drop[..., c]) * refl * 0.50

    # Rim light down the lower right, where the horizon glow would catch it.
    rim = coverage(sdf + 0.030)
    rimband = np.clip(inside - rim, 0.0, 1.0) * np.clip((xx - 0.46) / 0.3, 0, 1)
    for c in range(3):
        drop[..., c] += (DROP_RIM[c] - drop[..., c]) * rimband * 0.75

    # One specular highlight, upper left, soft. Two highlights on a 64px icon
    # is one too many.
    spec = np.exp(-((((xx - 0.428) / 0.055) ** 2 + ((yy - 0.320) / 0.090) ** 2)))
    for c in range(3):
        drop[..., c] += (1.0 - drop[..., c]) * spec * 0.80

    rgb = rgb * (1.0 - inside[..., None]) + drop * inside[..., None]
    rgb = rgb * (1.0 - ring[..., None]) + np.array(OUTLINE) * ring[..., None]

    # Darken the corners so the icon reads as round-ish inside the minimap's
    # circular mask and does not look like a photograph in the addon list.
    r = np.hypot(yy - 0.5, xx - 0.5) / 0.5
    vig = np.clip(1.0 - 0.70 * np.clip(r - 0.50, 0, None) ** 1.5, 0.0, 1.0)
    rgb *= vig[..., None]

    # Fully opaque. An icon with soft edges looks like a rendering bug in the
    # addon list, which draws it inside its own square frame.
    rgba = np.concatenate([np.clip(rgb, 0, 1), np.ones((N, N, 1))], axis=-1)
    big = Image.fromarray((rgba * 255).astype(np.uint8), mode="RGBA")
    big.resize((SIZE, SIZE), Image.LANCZOS).save(
        f"{out}/icon.tga", format="TGA", compression=None)
    print(f"wrote icon.tga ({SIZE}x{SIZE} 32-bit TGA, rendered at {N}x{N})")


if __name__ == "__main__":
    main()

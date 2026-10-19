#!/usr/bin/env python3
"""Generate ComfyRain's icon: a raindrop.

Two things read this file. The in-game addon list draws it next to the title
(`## IconTexture` in the .toc) and the minimap button draws it, so the art has
to survive being seen at 64px, at 20px, and inside a circular hole with its
corners cut off.

Each of those has killed a design.

The first was a dusk sky with rain streaks across it. Streaks are
high-frequency detail and high-frequency detail is the first thing a downsample
throws away, so at minimap size it was grey noise with a pink line in it. Fixed
by giving the icon one big subject and demoting the streaks to texture.

The second was a lit cottage window, which read as comfy and did not read as
weather. "make it a rain icon or something", 2026-10-19. An icon's first job is
to name the thing it opens, and a window names a house.

So: a single raindrop, filling most of the frame, dark-outlined. It is the one
weather shape whose silhouette survives at 20px, and it is the picture the
addon is named after.

One icon, not one per weather. A matching snowflake was built and dropped the
same day - "do the rain drop i guess first one". The button says which weather
is running through its tooltip and the panel says it in words, and an icon that
changes under the player is a worse readout than one they can learn.

Not a cloud, deliberately. A cloud at 20px is an indistinct blob and half the
weather category already uses one.

The backdrop is radial: a glow behind the subject, falling off into the
corners. It used to be a dusk horizon with a ground band under it, and a
straight band inside a circular crop becomes a chord - that composition only
worked as a square, and the minimap does not give it one.

Nothing here is Blizzard's. Same rule as the rain sheets: every pixel is
rasterised from a model rather than lifted from the client's art.

WoW addon art must be power-of-two and, for TGA, 32-bit uncompressed. 64x64 is
the size the addon list and the minimap both want; anything larger is downsampled
by the client with no mipmaps, which is how an icon ends up shimmering. This
renders at 4x and resamples once, here, where the filter is a good one.

Usage: make_icon_tga.py <out_dir> [--preview <png>]
"""
import math
import sys

import numpy as np
from PIL import Image

SIZE = 64
SS = 4                  # supersample factor; everything below works at SIZE*SS
N = SIZE * SS

SLANT_DEG = 7.5         # matches the rain sheets, so the two read as one addon
SLANT = math.tan(math.radians(SLANT_DEG))

# Dusk, centre to corner. Never black: a near-black icon disappears against the
# addon list's dark background and against an unexplored minimap.
SKY_NEAR = (0.180, 0.205, 0.330)
SKY_FAR = (0.045, 0.058, 0.110)
WARM = (0.90, 0.58, 0.42)

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


def coverage(sdf, softness=0.0035):
    """Antialiased 0..1 fill from a signed distance field."""
    return np.clip(0.5 - sdf / softness, 0.0, 1.0)


def sky(yy, xx):
    """A dusk glow behind the subject, falling off towards the corners.

    The glow is doing real work and is not decoration. At 20 pixels the rain is
    gone and all that survives is large-scale contrast, so the icon needs one
    unmistakable light-to-dark field, and the subject is posed against it. It
    is placed a little low and left of centre, which puts the brightest sky
    behind the drop's widest part and keeps the whole thing from looking like a
    sticker centred in a box.
    """
    d = np.hypot((xx - 0.44) / 0.62, (yy - 0.62) / 0.58)
    t = np.clip(d, 0.0, 1.0) ** 1.15
    rgb = np.empty((N, N, 3), dtype=np.float64)
    for c in range(3):
        rgb[..., c] = SKY_NEAR[c] + (SKY_FAR[c] - SKY_NEAR[c]) * t

    # A warm core inside the cool glow, so the backdrop is evening rather than
    # a blue vignette, and so the drop's blues have something to sit against.
    warm = np.exp(-(((xx - 0.44) / 0.30) ** 2 + ((yy - 0.66) / 0.28) ** 2))
    for c in range(3):
        rgb[..., c] += (WARM[c] - rgb[..., c]) * warm * 0.42
    return rgb


def streaks(rng, count=22):
    """Background rain: slanted, low contrast, over the whole frame.

    Demoted from subject to texture. These are what made the first icon mush at
    minimap size, so they are drawn at a third of the old brightness: present
    at 64px, invisible at 20px, and never competing with the subject.
    """
    acc = np.zeros((N, N), dtype=np.float64)
    for _ in range(count):
        length = int(rng.integers(0.22 * N, 0.42 * N))
        x0 = rng.uniform(-0.1 * N, 1.1 * N)
        y0 = rng.uniform(-0.2 * N, 0.9 * N)
        bright = rng.uniform(0.35, 0.75)
        half = max(1, int(round(0.008 * N)))
        for i in range(length):
            y = int(y0 + i)
            if not (0 <= y < N):
                continue
            t = i / max(length - 1, 1)
            x = x0 + SLANT * i
            a = bright * (0.30 + 0.70 * t)
            for dx in range(-half, half + 1):
                px = int(x) + dx
                if 0 <= px < N:
                    acc[y, px] = max(acc[y, px], a)
    return acc


def teardrop(yy, xx, cx=0.500, cy=0.572, r=0.287, apex=0.072):
    """Signed coverage of a classic teardrop: a disc with a cone on top.

    Built from the tangent lines rather than from a squashed curve, because the
    join has to be exactly smooth - a teardrop with a visible kink in its
    shoulder reads as a bad polygon, and at 64 pixels one wrong row is 1.5% of
    the height. Returns distance in frame units, negative inside.

    Sized to come within 0.14 of the frame edge at its widest, which is as big
    as it can be and still keep its outline clear of the minimap's circular
    crop at 0.5. "maybe bigger", 2026-10-19: it was r=0.258 before.
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


def glass(yy, xx, sdf, inside):
    """Shade the drop as a lit glassy solid.

    A vertical ramp pale to deep, the warm backdrop reflected across the lower
    third, a rim light down the side the glow is on, and exactly one specular.
    Two highlights on a 64px icon is one too many, and the reflection is what
    stops it reading as a flat blue pebble.
    """
    lo, hi = 0.12, 0.74
    g = np.clip((yy - lo) / (hi - lo), 0.0, 1.0)
    body = np.empty((N, N, 3), dtype=np.float64)
    for c in range(3):
        body[..., c] = DROP_PALE[c] + (DROP_DEEP[c] - DROP_PALE[c]) * g ** 0.85

    refl = np.exp(-(((yy - (lo + (hi - lo) * 0.82)) / 0.075) ** 2))
    for c in range(3):
        body[..., c] += (WARM[c] - body[..., c]) * refl * 0.50

    rim = coverage(sdf + 0.030)
    rimband = np.clip(inside - rim, 0.0, 1.0) * np.clip((xx - 0.46) / 0.3, 0, 1)
    for c in range(3):
        body[..., c] += (DROP_RIM[c] - body[..., c]) * rimband * 0.75

    spec = np.exp(-((((xx - 0.428) / 0.055) ** 2 + ((yy - 0.320) / 0.090) ** 2)))
    for c in range(3):
        body[..., c] += (1.0 - body[..., c]) * spec * 0.80
    return body


def render(seed=11):
    rng = np.random.default_rng(seed)
    yy, xx = grid()

    rgb = sky(yy, xx)
    weather = streaks(rng)[..., None]
    tint = np.array((0.84, 0.90, 1.00))
    rgb = rgb * (1.0 - weather * 0.45) + tint * weather * 0.45

    sdf = teardrop(yy, xx)
    inside = coverage(sdf)
    # The outline is an annulus just outside the fill. It is the single most
    # load-bearing element at minimap size: without it the drop's lower half
    # sits on the glow at nearly the same value and the silhouette breaks.
    ring = coverage(sdf - 0.022) - inside

    body = glass(yy, xx, sdf, inside)

    rgb = rgb * (1.0 - inside[..., None]) + body * inside[..., None]
    rgb = rgb * (1.0 - ring[..., None]) + np.array(OUTLINE) * ring[..., None]

    # Radial, not rectangular. The minimap cuts this to a circle and the addon
    # list does not, so the darkening has to be the same shape as the crop or
    # it shows as four dark corners in a round hole.
    r = np.hypot(yy - 0.5, xx - 0.5) / 0.5
    vig = np.clip(1.0 - 0.75 * np.clip(r - 0.46, 0, None) ** 1.4, 0.0, 1.0)
    rgb = rgb * vig[..., None]

    # Fully opaque. An icon with soft edges looks like a rendering bug in the
    # addon list, which draws it inside its own square frame.
    rgba = np.concatenate([np.clip(rgb, 0, 1), np.ones((N, N, 1))], axis=-1)
    return Image.fromarray((rgba * 255).astype(np.uint8), mode="RGBA")


def preview(im, path):
    """The icon at 64px and at the 20px the minimap button draws it."""
    pad, cell = 12, 256
    canvas = Image.new("RGB", (cell + 160 + pad * 3, cell + pad * 2), (26, 27, 31))
    rgb = im.convert("RGB").resize((SIZE, SIZE), Image.LANCZOS)
    canvas.paste(rgb.resize((cell, cell), Image.NEAREST), (pad, pad))
    small = rgb.resize((20, 20), Image.LANCZOS)
    canvas.paste(small.resize((160, 160), Image.NEAREST), (cell + pad * 2, pad + 48))
    canvas.save(path)


def main():
    args = sys.argv[1:]
    out = args[0].rstrip("/")
    big = render()
    big.resize((SIZE, SIZE), Image.LANCZOS).save(
        f"{out}/icon.tga", format="TGA", compression=None)
    print(f"wrote icon.tga ({SIZE}x{SIZE} 32-bit TGA, rendered at {N}x{N})")
    if "--preview" in args:
        preview(big, args[args.index("--preview") + 1])


if __name__ == "__main__":
    main()

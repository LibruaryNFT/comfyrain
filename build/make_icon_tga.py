#!/usr/bin/env python3
"""Generate ComfyRain's icon: a raindrop, and a snowflake.

Three things read these files. The in-game addon list draws `icon.tga` next to
the title (`## IconTexture` in the .toc), and the minimap button draws whichever
of the two matches the current weather, so the art has to survive being seen at
64px, at 20px, and inside a circular hole with its corners cut off.

Each of those has killed a design.

The first was a dusk sky with rain streaks across it. Streaks are
high-frequency detail and high-frequency detail is the first thing a downsample
throws away, so at minimap size it was grey noise with a pink line in it. Fixed
by giving the icon one big subject and demoting the streaks to texture.

The second was a lit cottage window, which read as comfy and did not read as
weather. "make it a rain icon or something", 2026-10-19. An icon's first job is
to name the thing it opens, and a window names a house.

So: a single raindrop, filling most of the frame, dark-outlined, and a
snowflake built the same way for the snow setting. A drop and a six-armed star
are the two weather shapes with silhouettes distinctive enough to survive at
20px, and they are distinguishable from each other at a glance, which matters
because the button is the only place both ever appear.

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

# The flake, built from the same three-stop recipe so the two icons are
# obviously siblings: a deep end, a pale end and a rim light.
FLAKE_DEEP = (0.400, 0.560, 0.720)
FLAKE_PALE = (0.980, 0.995, 1.000)
FLAKE_RIM = (0.780, 0.900, 1.000)

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


def specks(rng, count=26):
    """Background snow, playing the part the streaks play in the rain icon."""
    yy, xx = grid()
    acc = np.zeros((N, N), dtype=np.float64)
    for _ in range(count):
        cx, cy = rng.uniform(0.0, 1.0), rng.uniform(0.0, 1.0)
        r = rng.uniform(0.007, 0.016)
        a = rng.uniform(0.35, 0.75)
        acc = np.maximum(acc, coverage(np.hypot(xx - cx, yy - cy) - r) * a)
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


def flake(yy, xx, cx=0.500, cy=0.500, r=0.335):
    """Signed coverage of a six-armed snowflake.

    Six rounded bars through the centre at 30 degree steps, each with a pair of
    barbs two thirds of the way out, unioned by taking the minimum distance.
    Deliberately fat: a botanically correct flake is all hairline detail and
    turns to a grey smudge the moment it is resampled, so these arms are a
    twelfth of the frame thick and the barbs are short. What has to survive at
    20px is "a star, not a drop", and nothing finer than that.
    """
    def bar(ang, length, half, ox=0.0, oy=0.0):
        ca, sa = math.cos(ang), math.sin(ang)
        px, py = xx - cx - ox, yy - cy - oy
        # Into the bar's own frame, then distance to a segment along its x axis.
        u = px * ca + py * sa
        v = -px * sa + py * ca
        u = np.abs(u) - length
        return np.hypot(np.maximum(u, 0.0), v) - half

    d = None
    for k in range(3):
        ang = math.radians(k * 60)
        arm = bar(ang, r, 0.046)
        d = arm if d is None else np.minimum(d, arm)
        # Barbs: a short bar at +-60 degrees, crossing each arm near its tip.
        for s in (1, -1):
            ox = math.cos(ang) * r * 0.60 * s
            oy = math.sin(ang) * r * 0.60 * s
            # Both barbs, not one. A single barb per tip makes the flake read
            # as six bent arms rather than as a symmetric crystal, which at
            # icon size looks like a mistake rather than like snow.
            for b in (60, -60):
                d = np.minimum(
                    d, bar(ang + math.radians(b), r * 0.19, 0.030, ox, oy))
    # A hub, so the six arms meet in a shape rather than a spike cluster.
    return np.minimum(d, np.hypot(xx - cx, yy - cy) - 0.082)


def glass(yy, xx, sdf, inside, deep, pale, rim_colour, lo, hi, spec_at, warmth=0.45):
    """Shade a silhouette as a lit glassy solid.

    Shared by the drop and the flake so the two read as one set: a vertical
    ramp pale to deep, the warm backdrop reflected across the lower third, a
    rim light down the side the glow is on, and exactly one specular. Two
    highlights on a 64px icon is one too many.
    """
    g = np.clip((yy - lo) / (hi - lo), 0.0, 1.0)
    body = np.empty((N, N, 3), dtype=np.float64)
    for c in range(3):
        body[..., c] = pale[c] + (deep[c] - pale[c]) * g ** 0.85

    refl = np.exp(-(((yy - (lo + (hi - lo) * 0.82)) / 0.075) ** 2))
    for c in range(3):
        body[..., c] += (WARM[c] - body[..., c]) * refl * warmth

    rim = coverage(sdf + 0.030)
    rimband = np.clip(inside - rim, 0.0, 1.0) * np.clip((xx - 0.46) / 0.3, 0, 1)
    for c in range(3):
        body[..., c] += (rim_colour[c] - body[..., c]) * rimband * 0.75

    sx, sy = spec_at
    spec = np.exp(-((((xx - sx) / 0.055) ** 2 + ((yy - sy) / 0.090) ** 2)))
    for c in range(3):
        body[..., c] += (1.0 - body[..., c]) * spec * 0.80
    return body


def render(kind, seed):
    rng = np.random.default_rng(seed)
    yy, xx = grid()

    rgb = sky(yy, xx)
    weather = (streaks(rng) if kind == "rain" else specks(rng))[..., None]
    tint = np.array((0.84, 0.90, 1.00))
    rgb = rgb * (1.0 - weather * 0.45) + tint * weather * 0.45

    if kind == "rain":
        sdf = teardrop(yy, xx)
        shade = (DROP_DEEP, DROP_PALE, DROP_RIM, 0.12, 0.74, (0.428, 0.320), 0.50)
    else:
        sdf = flake(yy, xx)
        shade = (FLAKE_DEEP, FLAKE_PALE, FLAKE_RIM, 0.10, 0.90, (0.410, 0.330), 0.14)

    inside = coverage(sdf)
    # The outline is an annulus just outside the fill. It is the single most
    # load-bearing element at minimap size: without it the subject's lower half
    # sits on the glow at nearly the same value and the silhouette breaks.
    ring = coverage(sdf - 0.022) - inside

    deep, pale, rim_colour, lo, hi, spec_at, warmth = shade
    body = glass(yy, xx, sdf, inside, deep, pale, rim_colour, lo, hi,
                 spec_at, warmth)

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


def preview(images, path):
    """Both icons at 64px and at the 20px the minimap button draws them."""
    pad, cell = 12, 256
    w = pad + len(images) * (cell + 160 + pad * 2)
    canvas = Image.new("RGB", (w, cell + pad * 2), (26, 27, 31))
    x = pad
    for im in images:
        rgb = im.convert("RGB").resize((SIZE, SIZE), Image.LANCZOS)
        canvas.paste(rgb.resize((cell, cell), Image.NEAREST), (x, pad))
        x += cell + pad
        small = rgb.resize((20, 20), Image.LANCZOS)
        canvas.paste(small.resize((160, 160), Image.NEAREST), (x, pad + 48))
        x += 160 + pad
    canvas.save(path)


def main():
    args = sys.argv[1:]
    out = args[0].rstrip("/")
    images = []
    for kind, seed, name in (("rain", 11, "icon.tga"), ("snow", 7, "icon-snow.tga")):
        big = render(kind, seed)
        big.resize((SIZE, SIZE), Image.LANCZOS).save(
            f"{out}/{name}", format="TGA", compression=None)
        images.append(big)
        print(f"wrote {name} ({SIZE}x{SIZE} 32-bit TGA, rendered at {N}x{N})")
    if "--preview" in args:
        preview(images, args[args.index("--preview") + 1])


if __name__ == "__main__":
    main()

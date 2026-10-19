#!/usr/bin/env python3
"""Generate ComfyRain's icon, in rain and snow.

Three things read these files. The in-game addon list draws `icon.tga` next to
the title (`## IconTexture` in the .toc), and the minimap button draws whichever
of the two matches the current weather, so the art has to survive being seen at
64px, at 20px, and inside a circular hole with its corners cut off.

That last constraint is the one the previous two designs lost to.

Design one was a dusk sky with rain streaks across it. Streaks are
high-frequency detail and high-frequency detail is the first thing a downsample
throws away, so at minimap size it was grey noise with a pink line in it.

Design two was a single large raindrop over a dusk horizon, which fixed the
silhouette and failed on the frame. Its horizon and ground were straight bands
running edge to edge, and a straight band inside a circular crop becomes a
chord: the composition only worked as a square. It was also cold. Every colour
in it was blue, for an addon called Comfy Rain.

Design three, this one, is what the name actually describes. Nobody calls rain
comfy from outside in it. They call it comfy from indoors with a light on, and
that is the picture: a warm lit window at dusk with the weather coming down in
front of it.

Why it survives all three sizes:

- The subject is one bright warm shape on one dark cool ground. That contrast
  is the lowest-frequency thing in the frame, so it is the last thing a
  downsample destroys - at 20px the panes and the rain are gone and a warm
  glow in a dark circle is still legible, and still reads as the same icon.
- Nothing load-bearing goes near the edge. The composition is radial: a bloom
  around the window and a vignette into the corners, so cropping it to a circle
  removes only vignette. No horizons, no ground line, no straight bands.
- Rain and snow differ in the one layer that is allowed to be fine detail,
  because by the time it is too small to resolve, the minimap button has the
  tooltip and the panel to say which it is.

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

# The window, in fractions of the frame. Centred, a little above the middle so
# the sill and its spill have somewhere to go, and small enough that its corners
# sit at 0.27 of the frame from the centre - comfortably inside the 0.5 the
# minimap's circle cuts at, with room for the bloom to fall off before the edge.
WIN_CX, WIN_CY = 0.500, 0.448
WIN_HW, WIN_HH = 0.240, 0.205
WIN_R = 0.045           # corner radius, so it reads as a cottage casement
FRAME = 0.034           # how thick the dark surround is
MULLION = 0.019         # the cross bar between the panes

# Night outside. Cool, and never black: a near-black icon disappears against
# the addon list's dark background and against an unexplored minimap.
SKY_TOP = (0.105, 0.130, 0.225)
SKY_LOW = (0.045, 0.060, 0.115)

# Inside. The warm end is the entire point of the icon, so it is allowed to be
# the brightest thing in the frame by a wide margin.
LAMP_CORE = (1.000, 0.880, 0.640)
LAMP_EDGE = (0.960, 0.600, 0.230)
BLOOM = (1.000, 0.640, 0.260)
WOOD = (0.115, 0.085, 0.075)

RAIN = (0.820, 0.890, 1.000)
SNOW = (1.000, 1.000, 1.000)


def grid():
    """Pixel-centre coordinates in 0..1 across the supersampled frame."""
    y, x = np.mgrid[0:N, 0:N]
    return (y + 0.5) / N, (x + 0.5) / N


def rrect(yy, xx, cx, cy, hw, hh, r):
    """Signed distance to a rounded rectangle, negative inside."""
    dx = np.abs(xx - cx) - (hw - r)
    dy = np.abs(yy - cy) - (hh - r)
    outside = np.hypot(np.maximum(dx, 0.0), np.maximum(dy, 0.0))
    inside = np.minimum(np.maximum(dx, dy), 0.0)
    return outside + inside - r


def coverage(sdf, softness=0.0035):
    """Antialiased 0..1 fill from a signed distance field."""
    return np.clip(0.5 - sdf / softness, 0.0, 1.0)


def night(yy, xx):
    """The dark outside: a cool vertical ramp, darkened towards the corners."""
    t = np.clip(yy, 0.0, 1.0) ** 0.9
    rgb = np.empty((N, N, 3), dtype=np.float64)
    for c in range(3):
        rgb[..., c] = SKY_TOP[c] + (SKY_LOW[c] - SKY_TOP[c]) * t
    return rgb


def glow(yy, xx, rgb):
    """Lamplight spilling out through the glass.

    Two falloffs rather than one. The tight one is the halo that touches the
    wall around the frame and gives the window a sense of being set into
    something; the wide one is the only part of the icon still doing work at
    20 pixels, where the frame, the panes and the weather have all gone and a
    warm cloud in a dark circle is the whole picture.
    """
    d2 = ((xx - WIN_CX) / 0.44) ** 2 + ((yy - WIN_CY) / 0.40) ** 2
    wide = np.exp(-d2 * 2.1) * 0.46
    tight = np.exp(-(((xx - WIN_CX) / 0.26) ** 2
                     + ((yy - WIN_CY) / 0.23) ** 2) * 2.0) * 0.34
    g = np.clip(wide + tight, 0.0, 1.0)
    for c in range(3):
        rgb[..., c] += (BLOOM[c] - rgb[..., c]) * g
    return rgb


def window(yy, xx, rgb):
    """The frame, the glass, the cross bar and the sill."""
    outer = rrect(yy, xx, WIN_CX, WIN_CY, WIN_HW, WIN_HH, WIN_R)
    glass = rrect(yy, xx, WIN_CX, WIN_CY,
                  WIN_HW - FRAME, WIN_HH - FRAME, max(0.008, WIN_R - FRAME))

    # Lit glass: brightest low and centre, where a lamp on a table would be,
    # falling to the warmer orange at the top corners. A flat fill here reads
    # as a sticker; this reads as a room.
    lamp = np.exp(-((((xx - WIN_CX) / 0.17) ** 2
                     + ((yy - (WIN_CY + 0.075)) / 0.15) ** 2)))
    pane = np.empty_like(rgb)
    for c in range(3):
        pane[..., c] = LAMP_EDGE[c] + (LAMP_CORE[c] - LAMP_EDGE[c]) * lamp

    rgb = rgb * (1.0 - coverage(outer)[..., None]) \
        + np.array(WOOD) * coverage(outer)[..., None]
    gi = coverage(glass)[..., None]
    rgb = rgb * (1.0 - gi) + pane * gi

    # The cross. Drawn after the glass and clipped to it, so the bars stop at
    # the frame instead of poking into it.
    gmask = coverage(glass)
    bar = np.maximum(
        coverage(np.abs(xx - WIN_CX) - MULLION / 2),
        coverage(np.abs(yy - WIN_CY) - MULLION / 2),
    ) * gmask
    rgb = rgb * (1.0 - bar[..., None]) + np.array(WOOD) * bar[..., None]

    # A sill, wider than the frame, with the light catching its upper face.
    sill = rrect(yy, xx, WIN_CX, WIN_CY + WIN_HH + 0.028,
                 WIN_HW + 0.040, 0.024, 0.011)
    si = coverage(sill)
    lit = np.clip((WIN_CY + WIN_HH + 0.028 - yy) / 0.048, 0.0, 1.0)
    sill_rgb = np.empty_like(rgb)
    for c in range(3):
        sill_rgb[..., c] = WOOD[c] + (LAMP_EDGE[c] - WOOD[c]) * lit * 0.55
    rgb = rgb * (1.0 - si[..., None]) + sill_rgb * si[..., None]
    return rgb


def rain(rng, rgb, count=26):
    """Slanted streaks in front of everything, brighter across the glow.

    Allowed to be fine detail because it is the layer whose job is done at
    64px. At 20px it disappears, which is correct: what is left is the window,
    and the window is the icon.
    """
    acc = np.zeros((N, N), dtype=np.float64)
    for _ in range(count):
        length = int(rng.integers(0.16 * N, 0.34 * N))
        x0 = rng.uniform(-0.1 * N, 1.1 * N)
        y0 = rng.uniform(-0.25 * N, 0.95 * N)
        bright = rng.uniform(0.45, 0.95)
        half = max(1, int(round(0.007 * N)))
        for i in range(length):
            t = i / max(length - 1, 1)
            y = int(y0 + i)
            if not (0 <= y < N):
                continue
            x = x0 + SLANT * i
            a = bright * (0.25 + 0.75 * t)
            for dx in range(-half, half + 1):
                px = int(x) + dx
                if 0 <= px < N:
                    acc[y, px] = max(acc[y, px], a)
    return blend_weather(rgb, acc, RAIN, 0.55)


def snow(rng, rgb, count=34):
    """Round flakes, varied in size, with no slant. Same job, same layer."""
    yy, xx = grid()
    acc = np.zeros((N, N), dtype=np.float64)
    for _ in range(count):
        cx, cy = rng.uniform(0.02, 0.98), rng.uniform(0.02, 0.98)
        r = rng.uniform(0.008, 0.019)
        a = rng.uniform(0.45, 1.0)
        acc = np.maximum(acc, coverage(np.hypot(xx - cx, yy - cy) - r) * a)
    return blend_weather(rgb, acc, SNOW, 0.80)


def blend_weather(rgb, acc, colour, strength):
    a = (acc * strength)[..., None]
    return rgb * (1.0 - a) + np.array(colour) * a


def render(kind, seed):
    rng = np.random.default_rng(seed)
    yy, xx = grid()
    rgb = night(yy, xx)
    rgb = glow(yy, xx, rgb)
    rgb = window(yy, xx, rgb)
    rgb = rain(rng, rgb) if kind == "rain" else snow(rng, rgb)

    # Radial, not rectangular. The minimap cuts this to a circle and the addon
    # list does not, so the darkening has to be the same shape as the crop or
    # it shows as four dark corners in a round hole.
    r = np.hypot(yy - 0.5, xx - 0.5) / 0.5
    vig = np.clip(1.0 - 0.80 * np.clip(r - 0.42, 0, None) ** 1.4, 0.0, 1.0)
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
    args = [a for a in sys.argv[1:]]
    out = args[0].rstrip("/")
    images = []
    for kind, seed, name in (("rain", 11, "icon.tga"), ("snow", 7, "icon-snow.tga")):
        big = render(kind, seed)
        small = big.resize((SIZE, SIZE), Image.LANCZOS)
        small.save(f"{out}/{name}", format="TGA", compression=None)
        images.append(big)
        print(f"wrote {name} ({SIZE}x{SIZE} 32-bit TGA, rendered at {N}x{N})")
    if "--preview" in args:
        preview(images, args[args.index("--preview") + 1])


if __name__ == "__main__":
    main()

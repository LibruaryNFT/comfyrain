#!/usr/bin/env python3
"""Draw ComfyRain's icon and store logo from geometry.

Two things read the icon. The in-game addon list draws it next to the title
(`## IconTexture` in the .toc) and the minimap button draws it, so the art has
to survive being seen at 64px, at 20px, and inside a circular hole.

Each of those has killed a design.

The first was a dusk sky with rain streaks across it. Streaks are
high-frequency detail and high-frequency detail is the first thing a downsample
throws away, so at minimap size it was grey noise with a pink line in it.

The second was a lit cottage window, which read as comfy and did not read as
weather. "make it a rain icon or something", 2026-10-19.

The third was a flame burning inside a raindrop. In a WoW icon vocabulary a
drop with fire in it is a Fire or Frost spell. "why would it be a flame drop,
thats stupid", 2026-10-20.

The fourth was a painted logo of three glossy drops, with the icon cropped out
of its middle drop. The glow, the mottled texture inside the glass and the
blobby specular highlight are what generated art looks like, and that is what
it read as: "can we get a non-ai looking logo", 2026-10-23.

So this draws one drop the way a person with a vector tool would: a circle and
two tangent lines, two flat blues for lit side and shade, one crisp highlight
stroke, on a flat night-blue ground. Nothing is textured and nothing glows.
Every shape is a measurement below, so it can be changed by editing a number
rather than by regenerating a picture.

THE CIRCLE IS IN THE FILE. The icon's corners are transparent, so it is round
on every client whether or not that client honours Texture:SetMask. The
painted version was a full square, and on a live client the button showed
dark corners outside the brass ring (2026-10-23).

Drawn at SS times the target size and reduced once with a good filter, which
is the anti-aliasing. PIL only, because the release workflow already
installs it and nothing else.

WoW addon art must be power-of-two and, for TGA, 32-bit uncompressed. 64x64 is
the size the addon list and the minimap both want.

Usage: make_icon_tga.py <out_dir> [--preview <png>] [--logo <png>]
"""
import math
import sys

from PIL import Image, ImageChops, ImageDraw

SIZE = 64
LOGO = 512
SS = 8

GROUND = (24, 35, 58)       # night blue
STREAK = (38, 55, 88)       # rain behind the drop, logo only
SHADE = (44, 120, 205)      # the drop's unlit side
LIT = (92, 172, 240)        # the drop's lit side
GLINT = (236, 247, 255)     # the highlight stroke

# The drop, in units of the canvas width. r is the round body's radius, d the
# distance from the body's centre up to the tip; d/r sets how pointed it is.
# mid is where the drop's bounding box is centred vertically.
ICON_DROP = dict(r=0.25, d=0.445, mid=0.49)
LOGO_DROP = dict(r=0.20, d=0.36, mid=0.50)


def drop_shape(draw, cx, cy, r, d, fill):
    """A circle plus the two lines tangent to it from the tip."""
    a = math.acos(r / d)
    tip = (cx, cy - d)
    left = (cx - r * math.sin(a), cy - r * math.cos(a))
    right = (cx + r * math.sin(a), cy - r * math.cos(a))
    draw.polygon([tip, right, (cx, cy), left], fill=fill)
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=fill)


def draw_drop(img, n, spec):
    r, d = spec["r"] * n, spec["d"] * n
    cx = 0.5 * n
    cy = spec["mid"] * n - (r - d) / 2

    # Shade first, then the lit side as the same drop nudged up and left and
    # clipped to the first one. What is left showing is a crescent of shade
    # down the right, which is all the modelling a 20px drop can carry.
    mask = Image.new("L", img.size, 0)
    drop_shape(ImageDraw.Draw(mask), cx, cy, r, d, 255)
    img.paste(SHADE, mask=mask)

    lit = Image.new("L", img.size, 0)
    drop_shape(ImageDraw.Draw(lit), cx - 0.17 * r, cy - 0.07 * r, r, d, 255)
    img.paste(LIT, mask=ImageChops.darker(lit, mask))

    # One stroke along the upper left of the body, with round ends. A dot of
    # white reads as a glossy render; a curved line reads as drawn.
    g = ImageDraw.Draw(img)
    hr, w = 0.64 * r, 0.14 * r
    a0, a1 = 196, 248
    g.arc([cx - hr, cy - hr, cx + hr, cy + hr], a0, a1, fill=GLINT, width=round(w))
    for ang in (a0, a1):
        t = math.radians(ang)
        # arc() strokes inward from its bounding circle, so the cap sits on
        # the stroke's midline, half a width inside it.
        mr = hr - w / 2
        x, y = cx + mr * math.cos(t), cy + mr * math.sin(t)
        g.ellipse([x - w / 2, y - w / 2, x + w / 2, y + w / 2], fill=GLINT)
    return cx, cy, r, d


def streaks(img, n, keep_out):
    """Short slanted rain on a staggered grid, cut away around the drop."""
    layer = Image.new("L", img.size, 0)
    g = ImageDraw.Draw(layer)
    slant = math.radians(14)
    length, width = 0.085 * n, 0.018 * n
    col, row = 0.125 * n, 0.17 * n
    for i in range(-1, 10):
        for j in range(-1, 8):
            x = i * col + (0.06 * n if j % 2 else 0)
            y = j * row + (0.085 * n if i % 2 else 0)
            dx, dy = length * math.sin(slant), length * math.cos(slant)
            g.line([(x, y), (x - dx, y + dy)], fill=255, width=round(width))
            for px, py in ((x, y), (x - dx, y + dy)):
                g.ellipse([px - width / 2, py - width / 2,
                           px + width / 2, py + width / 2], fill=255)
    cx, cy, r, d = keep_out
    gap = 0.07 * n
    hole = Image.new("L", img.size, 0)
    drop_shape(ImageDraw.Draw(hole), cx, cy, r + gap, d + gap * d / r, 255)
    img.paste(STREAK, mask=ImageChops.subtract(layer, hole))


def render_icon():
    n = SIZE * SS
    img = Image.new("RGB", (n, n), GROUND)
    draw_drop(img, n, ICON_DROP)
    disc = Image.new("L", (n, n), 0)
    ImageDraw.Draw(disc).ellipse([0, 0, n - 1, n - 1], fill=255)
    img = img.convert("RGBA")
    img.putalpha(disc)
    return img.resize((SIZE, SIZE), Image.LANCZOS)


def render_logo():
    # Square and full-bleed: CurseForge rounds the corners of the avatar
    # itself, and transparency there shows as a white or black box depending
    # on the page theme.
    n = LOGO * SS
    img = Image.new("RGB", (n, n), GROUND)
    keep_out = draw_drop(Image.new("RGB", (n, n)), n, LOGO_DROP)
    streaks(img, n, keep_out)
    draw_drop(img, n, LOGO_DROP)
    return img.resize((LOGO, LOGO), Image.LANCZOS)


def preview(icon, logo, path):
    """The logo, the icon at 64px, and the icon at the ~25px the ring shows."""
    pad = 16
    bg = (26, 27, 31)
    small = icon.resize((25, 25), Image.LANCZOS)
    cells = [logo.resize((256, 256), Image.LANCZOS),
             icon.resize((256, 256), Image.NEAREST),
             small.resize((250, 250), Image.NEAREST)]
    w = sum(c.width for c in cells) + pad * (len(cells) + 1)
    canvas = Image.new("RGB", (w, 256 + pad * 2), bg)
    x = pad
    for c in cells:
        canvas.paste(c, (x, pad + (256 - c.height) // 2),
                     c if c.mode == "RGBA" else None)
        x += c.width + pad
    canvas.save(path)


def main():
    args = sys.argv[1:]
    out = args[0].rstrip("/")
    icon = render_icon()
    icon.save(f"{out}/icon.tga", format="TGA", compression=None)
    print(f"wrote icon.tga ({SIZE}x{SIZE} 32-bit TGA, round, drawn)")
    logo = None
    if "--logo" in args:
        logo = render_logo()
        logo.save(args[args.index("--logo") + 1])
    if "--preview" in args:
        preview(icon, logo or render_logo(), args[args.index("--preview") + 1])


if __name__ == "__main__":
    main()

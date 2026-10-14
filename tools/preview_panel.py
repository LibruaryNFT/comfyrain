#!/usr/bin/env python3
"""Render the settings window to a PNG, outside the game.

The beta client is withdrawn on 2026-10-21 and the next one exists on
4 November. For those two weeks there is no way to look at the panel at all,
and a settings window is judged entirely on how it looks. So the layout is
drawn here from the same numbers UI.lua uses.

What this proves: arrangement, proportion, whether a label fits its pill,
whether a row collides with the next one, and how the window reads as a whole.

What it cannot prove: WoW draws Friz Quadrata and this draws DejaVu Sans, so
text is within a few percent of the real width, not equal to it. Treat a label
that only just fits here as one that does not fit there.

The constants below MUST match the ones at the top of Duskfall/UI.lua, the same
way SLANT_DEG in make_rain_tga.py must match SLANT in the addon.

Usage: preview_panel.py <out.png> [--state rain|snow|blizzard|time]
"""
import argparse

from PIL import Image, ImageDraw, ImageFont

# --- must match Duskfall/UI.lua -------------------------------------------
WIDTH = 330
PAD = 14
ROW = 24
GAP = 7

ACCENT = (128, 184, 255)
BG = (10, 13, 18)
EDGE = (128, 184, 255, 90)
PILL = (41, 46, 59)
PILL_ON = (56, 107, 184)
DIM = (158, 163, 179)
WHITE = (255, 255, 255)
LAMP_OFF = (64, 66, 77)

SCALE = 3        # the window is small; render big enough to judge
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("--state", default="rain",
                    choices=["rain", "snow", "blizzard", "time"])
    args = ap.parse_args()
    s = args.state

    snow = s in ("snow", "blizzard")
    order = (["Light", "Normal", "Heavy", "Blizzard"] if snow
             else ["Light", "Normal", "Heavy", "Monsoon"])
    intensity = {"rain": "Normal", "snow": "Normal",
                 "blizzard": "Blizzard", "time": "Normal"}[s]
    timeMode = "fixed" if s == "time" else "off"

    # Measure the height the same way Relayout does, then draw into it.
    rows = []           # (kind, height, payload)
    rows.append(("top", ROW, None))
    rows.append(("pills", ROW, (order, intensity)))
    rows.append(("slider", 36, ("How visible it is", "1.00", 1.0 / 1.5)))
    rows.append(("slider", 36, ("How fast it falls", "1.00", (1.0 - 0.2) / 2.8)))
    rows.append(("slider", 36, ("How dark it gets", "1.00", 1.0 / 2.0)))
    rows.append(("heading", 18, "Sound"))
    rows.append(("audio", ROW, snow))
    rows.append(("pill", ROW, "Volume: Ambience"))
    rows.append(("heading", 18, "Time of day"))
    rows.append(("pills", ROW, (["Off", "My clock", "Shifted", "Held"],
                                "Held" if timeMode == "fixed" else "Off")))
    if timeMode != "off":
        rows.append(("slider", 36, ("Hold this hour", "21", 21 / 23)))
        rows.append(("slider", 36, ("How strongly", "1.00", 1.0)))
    rows.append(("foot", ROW, None))
    rows.append(("hint", 14, "Hover anything to see the command for it."))

    y = PAD + 20
    for kind, h, _ in rows:
        gap = 4 if kind == "heading" else (2 if kind == "hint" else GAP)
        y += h + gap
    height = y + PAD

    img = Image.new("RGB", (WIDTH * SCALE, height * SCALE), (26, 30, 24))
    d = ImageDraw.Draw(img, "RGBA")

    # A dull outdoor backdrop, so the panel is judged over the world and not
    # over white. The window is translucent in game and this matters.
    for i in range(height * SCALE):
        t = i / (height * SCALE)
        d.line([(0, i), (WIDTH * SCALE, i)],
               fill=(int(38 + 26 * t), int(44 + 24 * t), int(36 + 20 * t)))

    small = ImageFont.truetype(FONT, 10 * SCALE)
    normal = ImageFont.truetype(FONT, 12 * SCALE)
    tiny = ImageFont.truetype(FONT, 9 * SCALE)

    def box(x, yy, w, h, colour):
        d.rectangle([x * SCALE, yy * SCALE, (x + w) * SCALE, (yy + h) * SCALE],
                    fill=colour)

    def text(x, yy, t, font, colour, anchor="la"):
        d.text((x * SCALE, yy * SCALE), t, font=font, fill=colour, anchor=anchor)

    def fits(t, font, w):
        return d.textlength(t, font=font) <= (w - 8) * SCALE

    warnings = []

    box(0, 0, WIDTH, height, BG + (240,))
    d.rectangle([0, 0, WIDTH * SCALE - 1, height * SCALE - 1], outline=EDGE, width=SCALE)

    text(PAD, PAD, "Duskfall", normal, ACCENT)
    text(WIDTH - PAD, PAD, "x", normal, DIM, anchor="ra")

    def pill(x, yy, w, label, on, font=small, lamp=None):
        box(x, yy, w, ROW - 4, PILL_ON if on else PILL)
        colour = WHITE if on or lamp else DIM
        if lamp is not None:
            box(x + 7, yy + (ROW - 4) / 2 - 3.5, 7, 7, ACCENT if lamp else LAMP_OFF)
            text(x + 19, yy + 5, label, font, WHITE if lamp else DIM)
            if not fits(label, font, w - 19):
                warnings.append("label overflows its pill: %r" % label)
        else:
            text(x + w / 2, yy + 5, label, font, colour, anchor="ma")
            if not fits(label, font, w):
                warnings.append("label overflows its pill: %r" % label)

    inner = WIDTH - PAD * 2
    y = PAD + 20
    for kind, h, payload in rows:
        if kind == "top":
            third = inner / 3
            pill(PAD, y, third - 3, "Rain", not snow)
            pill(PAD + third, y, third - 3, "Snow", snow)
            pill(PAD + third * 2, y, third, "Weather on", False, lamp=True)
        elif kind == "pills":
            labels, sel = payload
            n = len(labels)
            w = inner / n
            for i, label in enumerate(labels):
                pill(PAD + i * w, y, w - 3, label, label == sel)
        elif kind == "slider":
            label, value, frac = payload
            text(PAD, y, label, small, (222, 226, 236))
            text(WIDTH - PAD, y, value, small, ACCENT, anchor="ra")
            box(PAD, y + 16 + 5.5, inner, 3, (38, 41, 51))
            box(PAD + frac * (inner - 8), y + 16 + 1, 8, 14, ACCENT)
        elif kind == "heading":
            text(PAD, y + 2, payload, small, ACCENT)
            box(PAD, y + h - 1, inner, 1, (255, 255, 255, 20))
        elif kind == "audio":
            third = inner / 3
            pill(PAD, y, third - 3, "Sound", False, lamp=True)
            pill(PAD + third, y, third - 3,
                 "Gusts" if payload else "Thunder", False, lamp=True)
            pill(PAD + third * 2, y, third, "Indoors", False, lamp=False)
        elif kind == "pill":
            pill(PAD, y, inner, payload, False)
        elif kind == "foot":
            half = inner / 2
            pill(PAD, y, half - 3, "All commands", False)
            pill(PAD + half, y, half, "Reset", False)
        elif kind == "hint":
            text(PAD, y, payload, tiny, (120, 124, 134))
        gap = 4 if kind == "heading" else (2 if kind == "hint" else GAP)
        y += h + gap

    img.save(args.out)
    print("%s  %dx%d game pixels" % (args.out, WIDTH, height))
    for warn in sorted(set(warnings)):
        print("  WARNING: %s" % warn)


if __name__ == "__main__":
    main()

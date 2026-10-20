#!/usr/bin/env python3
"""Cut ComfyRain's in-game icon out of the store logo.

Two things read the output. The in-game addon list draws it next to the title
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

The third was a flame burning inside a raindrop, meant to say comfy and rain in
one shape. In a WoW icon vocabulary a drop with fire in it is a Fire or Frost
spell. "why would it be a flame drop, thats stupid", 2026-10-20.

What replaced all three is the painted art in docs/logo.png, and this file no
longer rasterises anything. It crops.

WHY A CROP AND NOT A STRAIGHT DOWNSAMPLE. The logo is three drops falling on a
diagonal, which is what makes a 512px store image read as rain rather than as
water. Resampled whole to the 20px the minimap button draws, those three drops
smear into one diagonal blur and the silhouette is gone. The crop below takes
the middle drop and lets it fill the frame, so the icon keeps the logo's
palette, painting and shape language while having the one big subject that
survives a circular 20px hole. Checked by resampling, not by eye on the 512.

CROP is in the logo's own 512x512 pixel coordinates. It moves when the logo
does, so re-run with --preview after any logo change and look at the 20px panel
before shipping it.

Nothing here is Blizzard's. The source art was generated, not lifted from the
client, and the repo ships the PNG it was cut from.

WoW addon art must be power-of-two and, for TGA, 32-bit uncompressed. 64x64 is
the size the addon list and the minimap both want; anything larger is
downsampled by the client with no mipmaps, which is how an icon ends up
shimmering.

Usage: make_icon_tga.py <out_dir> [--preview <png>]
"""
import pathlib
import sys

from PIL import Image

SIZE = 64

# The logo is the source of truth for both images, so the icon cannot drift
# away from the store art by someone editing one and forgetting the other.
SOURCE = pathlib.Path(__file__).resolve().parent.parent / "docs" / "logo.png"

# Left, top, right, bottom, in the logo's 512x512 space. Centred on the middle
# drop, wide enough to keep its outline clear of the minimap's circular mask.
CROP = (126, 107, 406, 387)


def render():
    im = Image.open(SOURCE).convert("RGB")
    if im.size != (512, 512):
        raise SystemExit(
            f"{SOURCE} is {im.size}, expected 512x512; CROP is in that space")
    return im.crop(CROP)


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
    icon = big.resize((SIZE, SIZE), Image.LANCZOS).convert("RGBA")
    # Fully opaque. An icon with soft edges looks like a rendering bug in the
    # addon list, which draws it inside its own square frame.
    icon.putalpha(255)
    icon.save(f"{out}/icon.tga", format="TGA", compression=None)
    print(f"wrote icon.tga ({SIZE}x{SIZE} 32-bit TGA, cropped from {SOURCE.name})")
    if "--preview" in args:
        preview(big, args[args.index("--preview") + 1])


if __name__ == "__main__":
    main()

# The CurseForge gallery: what to shoot, and why

The three gallery stills and the launch GIF on the page right now all show the art from
before 2026-10-22. They have to be re-shot anyway. This is what to replace them with, and
what the addons that do this well actually do.

## What everyone else does

**CurseForge's own guidance** is thin: in-game screenshots with the addon enabled, plus
images that show how to turn it on. Logo must be PNG, at least 400x400, 1:1, original
artwork, not a blank square. Nothing about counts, GIFs, or dimensions.

**The addons that sell well do a three-part page.** BetterBlizzPlates (17M downloads) is
the clearest example:

| Where | What goes there |
|---|---|
| Gallery, first two slots | the hook, and **both are GIFs** - the features that move |
| Gallery, rest | one shot per distinct thing the addon does |
| Description | a headed section per feature, each with its own inline image |
| Near the end, once | **one** settings screenshot |

The settings shot is last on purpose. Nobody installs an addon because it has a nice
options panel; they install it for the thing in the first two slots, and then they want
to know they can configure it.

**Our actual competitors are weak, and this is the opening.** The top result for WoW
weather overlays, Dynamic Weather, has 20.7K downloads and **two uncaptioned
screenshots**, no GIF, no menu shot, and has not been updated since 9.1.0 in 2021.
Dynamic Azeroth Weather has 379 downloads. A page built to the BetterBlizzPlates pattern
is better than anything currently in this category.

## The thing this category gets wrong

**A still of rain is a still of a texture.** The product here is motion: fall speed,
slant, sway, gust, the lightning flash. None of it survives a JPEG, which is exactly why
a competitor with two stills reads as a colour tint. GIFs are not a nice-to-have on this
page, they are the only honest way to show what was built.

**Nobody in this category does a before/after.** It is the single most convincing frame
an overlay addon can show, because the reader's objection is "is this actually doing
anything". Same camera, same spot, addon off and on. We get it for free - the toggle is
one slash command.

## The shoot

Nine frames. Numbers 1, 2 and 5 are the ones that do the work.

| # | Frame | Type | Preset / state | Note |
|---|---|---|---|---|
| 1 | Storm over the Stormwind gates | **GIF** | rain / monsoon | the hero. Catch a lightning flash in the loop |
| 2 | Blizzard | **GIF** | snow / blizzard | the most dramatic thing it does. Dun Morogh or Alterac |
| 3 | Cozy, warm scene at dusk | still | rain / light | the name of the addon is Comfy Rain. This frame is the promise |
| 4 | Snow falling in a town | still | snow / normal | Ironforge gates or Goldshire in winter |
| 5 | **Before / after, same camera** | still, split | off \| rain / heavy | the proof frame. Nobody else has one |
| 6 | **The menu, over live rain** | still | `/comfyrain`, rain / normal | does double duty: shows the control AND the product. Do not shoot it over a grey screen |
| 7 | Time of Day grade | still | overcast / dusk | the third feature, and the one people do not know is there |
| 8 | Minimap button + addon compartment | still | any | small, goes inline in the description, not the gallery |
| 9 | Indoors, rain stopping at the door | **GIF** | rain / heavy | the detail that proves it is not a screen filter. Walk through an inn door |

### Order in the gallery

1, 2, 3, 5, 4, 7, 6. The menu goes last, per the pattern above. 8 and 9 are description
inline images, not gallery slots.

## Shooting notes, so this does not have to be re-derived

- **`Screenshot()` is protected on this build.** The GIFs have to be recorded from
  outside the client, not from an addon. Stills are PrintScreen.
- **The menu shot keeps the UI visible.** Every other frame hides it first.
- **Default gamma, always.** A screenshot taken at `/console gamma 1.6` is a screenshot
  of something the player will not get.
- `/console screenshotFormat png` and `/console screenshotQuality 10` before the stills.
- **Do not lead with warm lamps against cold rain.** The gloom layer is a fullscreen MOD
  multiply, so it dims torches by the same factor as everything else and cannot make a
  light source glow. That composition is the one this addon loses.
- **New TGAs need a full client restart**, not `/reload`. WoW reads the addon file list
  once at launch.

### The 2MB gallery ceiling

Already solved once and the numbers still hold. Rain is close to worst case for GIF -
every pixel changes every frame, so size tracks width x height x frames almost linearly.
**480x270, 10fps, 3.2s, 64 colours = 1,910,182 bytes.** Measured and rejected: 512w/3.0s
at 2,016,756; 520w/3.0s at 2,072,441; 560w/48c at 2,194,160.

Three GIFs at that budget is ~5.7MB of gallery, which is fine - the ceiling is per image.

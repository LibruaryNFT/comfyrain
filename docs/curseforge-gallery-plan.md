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

## Words go in the caption, not on the image

Checked 2026-10-24 by opening the actual image files from five galleries: BetterBlizzPlates,
DialogueUI, Narcissus, Immersion and Dynamic Weather. **None of them put text, arrows or
titles on the picture.** Every image is a clean in-game shot, and the explaining is done in
CurseForge's caption field, which shows under each image (the pencil on each tile in the
Media tab). DialogueUI's before/after is two bare panels side by side; "Before and After"
is its caption, not a label on the image. BetterBlizzPlates captions read like
"Totem Indicator with Icon+Glow, all configurable."

The big names barely bother: Details and Leatrix Plus have one gallery image each, and
DynamicCam has none. A new addon has no name to lean on, so it needs the gallery more.

Our three live images are captioned with their filenames (`preview1.jpg`), which is the
"uncaptioned" look this doc calls weak in Dynamic Weather. Caption every image:

| # | Caption |
|---|---|
| 1 | A thunderstorm over Stormwind. The rain, the wind and the lightning are all Comfy Rain. |
| 2 | A blizzard in Dun Morogh, with the snow blowing on the wind. |
| 3 | Light rain at dusk. The weather the game would not give you. |
| 5 | Same spot, same moment: Comfy Rain off on the left, heavy rain on the right. |
| 4 | Gentle snow in town. |
| 7 | Time of Day holds the world at dusk, whatever the realm clock says. |
| 6 | Every setting in one window, previewed live behind it. Hover a control to see its slash command. |

Fix the place names once the frames exist; the caption names where it was shot.

## The clip: first gallery item, 30 seconds, with sound

Added 2026-10-26. Both next-steps reports put a clip with sound first: the page has no
proof of the audio, and the audio is what neither Weather nor Cinematic does. Cinematic's
first gallery item is a YouTube video, so the clip goes to YouTube and its link goes in
the Media tab as item 1. Shoot it on Retail now; Forever is not up until 4 Nov.

**Recorder: OBS**, from Ubuntu's own archive (`obs-studio` 32.1.0, needs `sudo`). This
is a Wayland session and GNOME's built-in recorder has no audio, so it cannot make this
clip. OBS is driven from the agent side, set up 2026-10-26:

- Profile `ComfyRain`: canvas 3440x1440 (the whole monitor), 60 fps, NVENC H.264 at
  "Indistinguishable Quality", MKV, into `~/Videos`.
- Scene `Scene`: one *Screen Capture (PipeWire)* source called `Screen` (whole monitor,
  no cursor) and `Desktop Audio`. No microphone source, on purpose.
- obs-websocket on 127.0.0.1:4455 with a generated password that lives only in OBS's
  own config. `python3 -I tools/obs_ws.py StartRecord` / `StopRecord` /
  `GetSourceScreenshot` drive it; the script reads the password from that config.

**The take is one `/run` line**, so nobody has to press keys on cue. Stand still, game
music off, ambience and effects up, default gamma. The agent starts recording; paste
this, then Alt+Z to hide the UI within 8 seconds:

```
/run local c,a=ComfyRainAPI.Command,C_Timer.After c("stop")a(8,function()c("preset storm")end)a(13,function()c("strike")end)a(19,function()c("strike")end)a(24,function()c("blizzard")c("thunder off")end)a(36,function()c("preset cozy")c("preset dusk")end)
```

253 characters, under the 255 the chat box takes; `luac -p` clean. Dry until 8 s,
storm with thunderclaps at 13 and 19 s, blizzard at 24 s, light rain at dusk from 36 s.
The cut (centre 2560x1440, scaled to 1920x1080, about 30 s) and the stills are done
from the raw file with ffmpeg, then the raw file is deleted.

**Shot list**, as originally planned for separate takes. The `/run` take covers every
shot except the inn door.

| Time | Shot | Keys |
|---|---|---|
| 0-4 s | A dry street in daylight, camera still. Only the game's own sound | 1 |
| 4-12 s | Press 2: the storm comes in, rain and sound together. Slow pan. Press 3 for a thunderclap with its flash | 2, then 3 |
| 12-18 s | Walk in through an inn door: the rain fades under the roof. Back out | - |
| 18-24 s | A snowy zone, blizzard with gusts | 4 |
| 24-30 s | Light rain at dusk, camera still. The end frame | 5 |

A zone that never rains (Durotar, Westfall) makes 0-12 s stronger than Stormwind, if the
character can get there.

**Publish:** upload to YouTube, public, title "Comfy Rain: rain and snow anywhere in World
of Warcraft". Then the YouTube link as the first item in the CurseForge Media tab.

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

The clip first, then 1, 2, 3, 5, 4, 7, 6. The menu goes last, per the pattern above. 8 and 9 are description
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

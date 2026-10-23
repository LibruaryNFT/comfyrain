# The shoot card

**7 photos, 3 clips, three spots.** CurseForge takes images only; each clip becomes a 2-4 s
looping GIF. The throwaway HTML copy used on shoot day is a hand-made mirror of this file.

- **Daylight only.** The gloom layer is a fullscreen multiply and cannot make a lamp glow,
  so Stormwind at night is the one scene the addon loses.
- **Buttons only.** A frame of a hand-tuned config advertises something a fresh install
  does not give.

## Where the buttons are

Left-click the Comfy Rain minimap icon. The top of the window:

- **Scenes:** Cozy, Storm, Snow, Overcast
- **Light only:** Dusk, Night

Every capture names the one to click. Clicking a scene also turns the rain back on.

## Before you start

1. **Launch WoW.** The fall-speed pass changed `snow-gale.tga`, so it needs a full launch,
   not a `/reload`.
2. Paste this into chat. `Alt+Z` does not hide chat bubbles, which are drawn in the world:

   ```
   /run SetCVar("chatBubbles",0);SetCVar("chatBubblesParty",0)
   ```

3. Already done, verified on disk 2026-10-22: PNG screenshots (`screenshotFormat png`,
   `screenshotQuality 10` in `Config.wtf`) and the `/comfy strike` macro
   (`macros-cache.txt`, account-wide).

## Keys

| Key | What |
|---|---|
| `PrintScreen` | photo, to `_classic_beta_/Screenshots/` |
| `Ctrl+Shift+Alt+R` | start / stop a clip, to `~/Videos/Screencasts/` |
| `Alt+Z` | hide / show the UI |
| strike key | one thunderclap, now |

## The captures

| # | Type | Spot | Click | Then |
|---|---|---|---|---|
| 1 | CLIP 15s | SW gates | **Storm** | Hide UI. Record, strike, wait 5s, strike, stop |
| 2 | PHOTO | SW gates | nothing | PrintScreen |
| 3 | PHOTO | SW gates | right-click the minimap icon (rain off) | Hide UI, PrintScreen. Don't move the camera: 2 and 3 are a before/after |
| 4 | PHOTO | SW gates | **Storm** (rain back on) | UI showing, window in the left third. PrintScreen |
| 5 | PHOTO | SW gates | **Cozy** | Hide UI. PrintScreen |
| 6 | CLIP 15s | Gilded Rose | **Storm** | Hide UI, start outside. Record, walk in, turn, walk out, stop |
| 7 | PHOTO | anywhere | nothing | UI showing. PrintScreen (cropped to the minimap button) |
| 8 | PHOTO | IF gates | **Snow** | Hide UI. PrintScreen |
| 9 | CLIP 20s | IF gates | right arrow on **Intensity** until it reads **Blizzard** | Hide UI. Record 20s, stop |
| 10 | PHOTO | anywhere | **Dusk** | optional. Hide UI. PrintScreen |

- **SW gates:** Valley of Heroes, statues framing the road. Same camera for 1 to 5.
- **Gilded Rose:** the inn on the right as you enter the Trade District. Capture 6 is the
  one that proves the rain is not a screen filter.
- **IF gates:** Deeprun Tram from the Trade District, stand on the ramp facing Dun Morogh.

## After

```
/run SetCVar("chatBubbles",1);SetCVar("chatBubblesParty",1)
```

Cropping, the before/after split and getting the GIFs under the 2MB ceiling are mine.

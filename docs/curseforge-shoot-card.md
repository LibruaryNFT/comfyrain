# The shoot card

9 captures: **6 PHOTO, 3 VIDEO.** Three spots, one tram ride.

**Everything is a button in the Comfy Rain window.** No slash commands - the shots are
supposed to show off the presets, so every frame is something a player gets by clicking
one button on a fresh install. Open the window with the minimap drop.

## Keys

| Key | What | Lands in |
|---|---|---|
| `PrintScreen` | **PHOTO** | `_classic_beta_/Screenshots/` |
| `Ctrl+Shift+Alt+R` | **VIDEO** - once to start, again to stop | `~/Videos/Screencasts/` |
| `Alt+Z` | hides / shows the UI | - |

## The table

| # | Type | Spot | **Set this** | What you do |
|---|---|---|---|---|
| 1 | **VIDEO** 90s | SW gates | **Storm** | hide UI, record, stand still 90s, stop |
| 2 | PHOTO | SW gates | **Storm** | same camera, shoot |
| 3 | PHOTO | SW gates | **master switch OFF** | don't move the camera, shoot |
| 4 | PHOTO | SW gates | **Storm**, master back ON | UI **visible**, window dragged left, shoot |
| 5 | PHOTO | SW gates | **Cozy** | hide UI, shoot |
| 6 | **VIDEO** 15s | Gilded Rose | **Storm** | record, walk in, turn, walk out, stop |
| 7 | PHOTO | anywhere | - | UI **visible**, shoot (I crop the minimap) |
| 8 | PHOTO | IF gates | **Snow** | hide UI, shoot |
| 9 | **VIDEO** 20s | IF gates | **Snow**, then Intensity up to **Blizzard** | record 20s, stop |
| 10 | PHOTO | anywhere | **Dusk** | optional. hide UI, shoot |

**Blizzard is not a preset button.** Click **Snow**, then step the **Intensity** control up
to its top notch - under Snow the top step is named Blizzard.

**Touch nothing else.** No Darkness, Speed, Scale, Sound or gamma. A frame of a
hand-tuned config advertises something a fresh install does not give.

---

## Step 0 - restart the client

Required. The new rain and snow TGAs are new files, and WoW reads the addon file list
once at launch. You are on `_classic_beta_`; the new build went in there at 11:47.

Log back in and paste this once. It is the only typing in the whole shoot - there is no
UI for it:

```
/console screenshotFormat png
/console screenshotQuality 10
```

**Shoot in daylight.** If the realm is dark, come back when it is not. The gloom layer is
a fullscreen MOD multiply: it dims torches by the same factor as everything else and
cannot make a light source glow, so warm lamps against cold rain is the one composition
this addon loses - and Stormwind at night is exactly that.

---

## SPOT 1 - Valley of Heroes, facing the Stormwind gates

Stand where the statues frame the road. Captures 1-5, **same camera for all five**.

- **1 VIDEO.** Click **Storm**. `Alt+Z`. `Ctrl+Shift+Alt+R`, wait **90 seconds**,
  `Ctrl+Shift+Alt+R`. Stand still, do not move the camera. 90 and not 10 because
  lightning fires about every 48 s and I need a strike to cut the loop around.
- **2 PHOTO.** Still on Storm, UI still hidden. `PrintScreen`.
- **3 PHOTO.** `Alt+Z`, flip the **master switch off**, `Alt+Z`. `PrintScreen`.
  **Do not move the camera** - 2 and 3 are the before/after pair I split-screen.
- **4 PHOTO.** Master switch back **on**, UI **visible**, drag the window to the left
  third so the rain and the gates show behind it. `PrintScreen`.
- **5 PHOTO.** Click **Cozy**, `Alt+Z`. `PrintScreen`.

## SPOT 2 - the Gilded Rose, Trade District

The inn on the right as you come in from the gates.

- **6 VIDEO.** Click **Storm**. `Alt+Z`. Stand **outside** facing the door.
  `Ctrl+Shift+Alt+R`, walk in, turn around, walk back out, `Ctrl+Shift+Alt+R`. ~15 s.
  This is the one that proves it is not a screen filter.
- **7 PHOTO.** `Alt+Z` to show the UI. `PrintScreen`.

## SPOT 3 - Ironforge, out the front gates

Deeprun Tram from the Trade District. Stand on the ramp looking down at Dun Morogh.

- **8 PHOTO.** Click **Snow**, `Alt+Z`. `PrintScreen`.
- **9 VIDEO.** Step **Intensity** up to **Blizzard**, `Alt+Z`. `Ctrl+Shift+Alt+R`,
  **20 seconds**, `Ctrl+Shift+Alt+R`. No lightning in a blizzard, so no long take.
- **10 PHOTO.** Optional. Click **Dusk**, `Alt+Z`. `PrintScreen`.

---

Tell me when they are down. Cropping, the before/after split, and the GIFs under the 2MB
ceiling are mine - nothing else needs your hands.

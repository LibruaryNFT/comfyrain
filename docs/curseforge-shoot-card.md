# The shoot card

One pass, two cities, one tram ride. Everything after the capture is mine: cropping, the
before/after split, webm to GIF under the 2MB ceiling, and the assembly.

**Two keys and that is all:**

| Key | Does | Lands in |
|---|---|---|
| `PrintScreen` | still | `_forever_/Screenshots/` |
| `Ctrl+Shift+Alt+R` | start / stop a clip | `~/Videos/Screencasts/` |

`Alt+Z` hides the UI. **Hide it for every frame except the menu shot.**

## Before you start

The client must be **fully restarted**, not `/reload` - the new rain and snow TGAs are new
files and WoW reads the addon file list once at launch.

Then paste this into chat once:

```
/console screenshotFormat png
/console screenshotQuality 10
/comfy time 15
```

`time 15` pins mid-afternoon so every frame is lit the same way and the shoot does
not change character as the realm clock moves. The dusk frame undoes it at the end.

---

## Spot 1 - Valley of Heroes, facing the Stormwind gates

Stand where the two statues frame the road in. This composition is already proven.
Four frames here.

**1a. Storm, the hero GIF.** `Alt+Z`, then:

```
/comfy preset storm
```

`Ctrl+Shift+Alt+R`, **wait 90 seconds**, `Ctrl+Shift+Alt+R`. Ninety, not ten: monsoon
fires lightning about every 48 s and I need a strike in the footage to cut the loop
around. Stand still, do not move the camera.

**1b. Before / after.** Same camera, do not touch the mouse:

```
/comfy preset storm
```

`PrintScreen`, then

```
/comfy off
```

`PrintScreen`. Two files, I split-screen them.

**1c. The menu, over live rain.** `Alt+Z` to bring the UI *back*, then:

```
/comfy on
/comfy preset storm
/comfy ui
```

Drag the window to the left third so the rain and the gates are visible behind it.
`PrintScreen`.

**1d. Cozy.** Close the window, `Alt+Z` to hide the UI:

```
/comfy preset cozy
```

`PrintScreen`.

---

## Spot 2 - the Gilded Rose, Trade District

The inn on the right as you come into the Trade District.

**2a. Indoors, the rain stopping at the door.** UI hidden, stand outside facing the door:

```
/comfy preset storm
```

`Ctrl+Shift+Alt+R`, walk in, turn around, walk out, `Ctrl+Shift+Alt+R`. About 15 seconds.
This is the frame that proves it is not a screen filter.

**2b. Minimap button.** UI visible, any spot:

`PrintScreen`. I crop the corner.

---

## Spot 3 - Deeprun Tram to Ironforge, then out the front gates

Stand on the ramp outside the gates looking down at Dun Morogh.

**3a. Snow.** UI hidden:

```
/comfy preset snow
```

`PrintScreen`.

**3b. Blizzard, the second GIF.**

```
/comfy blizzard
```

`Ctrl+Shift+Alt+R`, **20 seconds**, `Ctrl+Shift+Alt+R`. No lightning in a blizzard, so
this one does not need the long take.

---

## Spot 4 - anywhere outdoors with a view

**4a. Dusk.** UI hidden:

```
/comfy preset dusk
```

`PrintScreen`.

Then put the clock back:

```
/comfy time local
```

---

## What comes back

Nine captures: six stills, three clips. Tell me when they are down and I will take it
from there - nothing else needs your hands.

| # | Spot | Capture |
|---|---|---|
| 1a | SW gates | clip, 90s, storm |
| 1b | SW gates | 2 stills, on and off |
| 1c | SW gates | still, menu over rain |
| 1d | SW gates | still, cozy |
| 2a | Gilded Rose | clip, 15s, walking in |
| 2b | anywhere | still, minimap button |
| 3a | IF gates | still, snow |
| 3b | IF gates | clip, 20s, blizzard |
| 4a | anywhere | still, dusk |

## Why these spots and not others

- **Do not shoot warm lamps against cold rain.** The gloom layer is a fullscreen MOD
  multiply: it dims torches by the same factor as everything else and cannot make a
  light source glow. That composition is the one this addon loses, and the Stormwind
  braziers at night are exactly it. Mid-afternoon is why the clock is pinned.
- **Default gamma.** A frame shot at `/console gamma 1.6` is a frame of something the
  player will not get.
- The gates, the inn and the Ironforge ramp are three spots inside one tram ride. Most of
  the cost of this shoot is travel, not capture.

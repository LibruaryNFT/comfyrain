# The shoot card

9 captures: **6 PHOTO, 3 VIDEO.** Three spots, one tram ride. Everything after the
capture is mine - cropping, the before/after split, webm to GIF under 2MB, assembly.

## The two keys

| Key | What | Lands in |
|---|---|---|
| `PrintScreen` | **PHOTO** | `_classic_beta_/Screenshots/` |
| `Ctrl+Shift+Alt+R` | **VIDEO** - press once to start, again to stop | `~/Videos/Screencasts/` |
| `Alt+Z` | toggles the UI | - |

## The settings: don't touch any slider

**Use the preset buttons and nothing else.** No Darkness, no Sound, no Speed, no scale.
Every frame has to be something a player gets by clicking one button on a fresh install,
otherwise the page is advertising a config they do not have. The only typed commands are
the ones on this card.

Default gamma too. Do not touch `/console gamma`.

## Step 0 - restart the client

Required. New rain and snow TGAs are new files and WoW reads the addon file list once at
launch. You are on `_classic_beta_`; the new build is installed there as of 11:47.

Log back in, then paste once:

```
/console screenshotFormat png
/console screenshotQuality 10
/comfy time 15
```

`time 15` pins mid-afternoon so all nine frames are lit the same way. Step 9 puts it back.

---

# SPOT 1 - Valley of Heroes, facing the Stormwind gates

Stand where the statues frame the road. Four captures here, same camera for all of them.
**Do not move the mouse between steps 2 and 3.**

### 1 - VIDEO - storm, 90 seconds

`Alt+Z` to hide the UI, then:

```
/comfy preset storm
```

`Ctrl+Shift+Alt+R` → **wait 90 seconds** → `Ctrl+Shift+Alt+R`.

Stand still, don't move the camera. 90 and not 10: lightning fires about every 48 s and
I need a strike in the footage to cut the loop around.

### 2 - PHOTO - storm, "after"

UI still hidden, same camera. `PrintScreen`.

### 3 - PHOTO - "before"

```
/comfy off
```

`PrintScreen`. That is the pair I split-screen. **Don't move the camera.**

### 4 - PHOTO - the menu over live rain

`Alt+Z` to bring the UI **back**, then:

```
/comfy on
/comfy ui
```

Drag the window to the left third so the rain and the gates show behind it.
`PrintScreen`.

### 5 - PHOTO - cozy

Close the window, `Alt+Z` to hide the UI again:

```
/comfy preset cozy
```

`PrintScreen`.

---

# SPOT 2 - the Gilded Rose, Trade District

The inn on the right as you come in from the gates.

### 6 - VIDEO - walking in out of the rain, ~15 seconds

UI hidden, stand **outside** facing the door:

```
/comfy preset storm
```

`Ctrl+Shift+Alt+R` → walk in, turn around, walk back out → `Ctrl+Shift+Alt+R`.

This is the frame that proves it is not a screen filter.

### 7 - PHOTO - minimap button

`Alt+Z` to show the UI. `PrintScreen`. Anywhere, I crop the corner.

---

# SPOT 3 - Ironforge, out the front gates

Deeprun Tram from the Trade District. Stand on the ramp looking down at Dun Morogh.

### 8 - PHOTO - snow

`Alt+Z` to hide the UI:

```
/comfy preset snow
```

`PrintScreen`.

### 9 - VIDEO - blizzard, 20 seconds

```
/comfy blizzard
```

`Ctrl+Shift+Alt+R` → **20 seconds** → `Ctrl+Shift+Alt+R`.

No lightning in a blizzard, so this one doesn't need the long take.

---

# Step 10 - dusk, then put the clock back

UI hidden, anywhere outdoors with a view:

```
/comfy preset dusk
```

`PrintScreen`. That is a 10th frame and the only one that is optional.

Then:

```
/comfy time local
```

---

## Checklist

| # | Type | Spot | What |
|---|---|---|---|
| 1 | **VIDEO** 90s | SW gates | storm, catch a lightning strike |
| 2 | PHOTO | SW gates | storm, "after" |
| 3 | PHOTO | SW gates | addon off, "before" |
| 4 | PHOTO | SW gates | the menu over live rain |
| 5 | PHOTO | SW gates | cozy |
| 6 | **VIDEO** 15s | Gilded Rose | walking in out of the rain |
| 7 | PHOTO | anywhere | minimap button |
| 8 | PHOTO | IF gates | snow |
| 9 | **VIDEO** 20s | IF gates | blizzard |
| 10 | PHOTO | anywhere | dusk (optional) |

Tell me when they are down. Nothing else needs your hands.

## Why these spots

- **Never shoot warm lamps against cold rain.** The gloom is a fullscreen MOD multiply:
  it dims torches by the same factor as everything else and cannot make a light source
  glow. Stormwind braziers at night are exactly that composition, and it is the one this
  addon loses. Pinning the clock to 15 is what avoids it.
- The gates, the inn and the Ironforge ramp are three spots inside one tram ride. Most
  of the cost here is travel, not capture.

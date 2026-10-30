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
| 1 | A thunderstorm in Elwynn Forest. The rain, the wind and the lightning are all Comfy Rain. |
| 2 | A blizzard in Elwynn Forest, with the snow blowing on the wind. |
| 3 | Light rain at dusk. The weather the game would not give you. |
| 5 | Same spot, same camera: Comfy Rain off on the left, a storm on the right. |
| 4 | Gentle snow in town. |
| 7 | Time of Day holds the world at dusk, whatever the realm clock says. |
| 6 | Every setting in one window, previewed live behind it. Hover a control to see its slash command. |

Place names updated 2026-10-30 to where 1, 2 and 5 were actually shot. 4 and 7 have no
frame yet.

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
this, then Alt+Z to hide the UI. The storm comes in at 15 s; the first version of this
line used 8 s and that was not long enough to get to Alt+Z:

```
/run local c,a=ComfyRainAPI.Command,C_Timer.After c("stop")a(15,function()c("preset storm")end)a(20,function()c("strike")end)a(26,function()c("strike")end)a(31,function()c("blizzard")c("thunder off")end)a(43,function()c("preset cozy")c("preset dusk")end)
```

**Turn the game's own weather off first.** Comfy Rain stands aside while the game is
raining (`defer`, on by default), so a take shot in real rain shows only Blizzard's rain
and has no dry opening. This saves the old value with the name lines below:

```
/run R=R or{}R.weatherDensity=R.weatherDensity or C_CVar.GetCVar("weatherDensity")C_CVar.SetCVar("weatherDensity","0")
```

NPC voices and emotes are muted the same way:

```
/run R=R or{}for _,n in ipairs{"Sound_EnableDialog","Sound_EnableEmoteSounds"}do R[n]=R[n]or C_CVar.GetCVar(n)C_CVar.SetCVar(n,"0")end
```

**Graphics go up in Options, not by CVar.** Setting `graphicsQuality` and `RenderScale`
with `C_CVar.SetCVar` changed nothing visible on 2026-10-30. Options > Graphics: Render
Scale 100%, and click Base Game Quality once so it re-applies the preset (it said 7 with
shadows Low and SSAO off underneath).

Names over heads, nameplates and chat bubbles are drawn by the world, so Alt+Z leaves
them on. Before the take, this saves the current values and turns them off (names
checked against Retail's `Wow.exe`, 2026-10-30):

```
/run R={}local c=C_CVar for n in("Own NPC FriendlyPlayerName EnemyPlayerName HostleNPC InteractiveNPC nameplateShowAll nameplateShowSelf chatBubbles"):gmatch"%S+"do n=n:find"^%u"and"UnitName"..n or n R[n]=c.GetCVar(n)c.SetCVar(n,"0")end
```

That leaves critters, pets and neutral NPCs named, so these two follow it (they add to
the same saved set, so one restore covers all three):

```
/run R=R or{}local c=C_CVar for n in("NonCombatCreatureName FriendlyPetName EnemyPetName FriendlyMinionName EnemyMinionName FriendlyGuardianName FriendlySpecialNPCName"):gmatch"%S+"do n="UnitName"..n R[n]=R[n]or c.GetCVar(n)c.SetCVar(n,"0")end
```

```
/run R=R or{}local c=C_CVar for n in("Enemies FriendlyNpcs FriendlyPlayers"):gmatch"%S+"do n="nameplateShow"..n R[n]=R[n]or c.GetCVar(n)c.SetCVar(n,"0")end
```

**The menu shot** keeps the UI, but the player frame shows the character's name and chat
shows NPC yells, and the Comfy Rain window is a child of UIParent so Alt+Z hides it too.
Hide just those two:

```
/run PlayerFrame:Hide()ChatFrame1:Hide()
```

This puts everything back, in the same session (the saved values do not survive a
`/reload`). It leaves graphics as set in Options:

```
/run R.graphicsQuality=nil R.RenderScale=nil for n,v in pairs(R)do C_CVar.SetCVar(n,v)end PlayerFrame:Show()ChatFrame1:Show()
```

The take line is 254 characters, under the 255 the chat box takes; `luac -p` clean. Dry until 15 s,
storm with thunderclaps at 20 and 26 s, blizzard at 31 s, light rain at dusk from 43 s.

**The cut.** WoW runs windowed, so crop to the window's client area, not the screen
centre. Find the edges from a raw frame by sampling pixel rows and columns (the title
bar is flat grey 57, the browser under it is white). On 2026-10-30 the client was
x 1940-3439, y 224-1127, and the 16:9 crop was `crop=1472:828:1954:262`, scaled with
lanczos to 1920x1080, x264 CRF 16, 60 fps, 0.3 s audio fade in, 1.5 s fade out. Find the
storm, blizzard and dusk changes with `signalstats` YAVG per half-second; they are step
changes. The lightning flashes are single bright frames on the strike second. The raw
file is deleted afterwards.

**Shot 2026-10-30, Elwynn Forest on Retail:** the clip (38 s) and stills 1, 2, 3, 5 and
6, in `~/comfyrain-media-2026-10-30/`. Stills 4 (snow in town) and 7 (Time of Day) were
not shot; 3 already shows the dusk grade.

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

Thumbnail: `~/comfyrain-media-2026-10-30/youtube-thumbnail.jpg`, 1280x720, 256 KB. It is
frame 5 (before / after) with OFF and ON in Lato Black 150px and a white divider at the
split. Rain streaks vanish at sidebar size (168x94); the labels and the light/dark halves
do not, so the proof frame beats any storm frame here.

YouTube description:

```
Comfy Rain is a World of Warcraft addon that makes it rain or snow wherever you are, for as long as you want. Thunder, wind and a time-of-day colour grade come with it, and the sound is built from Blizzard's own weather audio.

Filmed in Elwynn Forest on Retail. The rain, the snow, the thunder, the wind and the dusk light are all Comfy Rain.

Works on WoW Forever and Retail. Free and open source (MIT).

Download: https://www.curseforge.com/wow/addons/comfy-rain
Source: https://github.com/LibruaryNFT/comfyrain

In game, type /comfyrain to open the settings, or /comfy to turn the weather on and off.
```

Tags:

```
World of Warcraft, WoW addon, WoW Forever, Comfy Rain, rain ambience, WoW ambience, cozy, Elwynn Forest, CurseForge
```

No chapters: YouTube needs every chapter to be at least 10 s, and dusk runs 6 s.

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

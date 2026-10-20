# CurseForge project page — every field, paste-ready

Create the project here:

```
https://authors.curseforge.com/#/projects/create/choose-game
```

Each block below is one field. Copy the block, paste it in the field named above it.
Nothing in this file is commentary; the fenced blocks are the copy.

---

## Project Name

```
Comfy Rain
```

## URL slug

```
comfy-rain
```

## Summary

```
Makes it rain or snow anywhere in the game, with weather sounds, wind and thunder, all set from a settings panel or the minimap button.
```

## Logo

Required. 512x512, rendered rather than upscaled from the 64px in-game icon:

```
/home/mycomputer/code/wow-alwaysrain/docs/logo.png
```

## Class

```
Addons
```

## Description

Set the editor to **Markdown**, not WYSIWYG, then paste this. (CurseForge offers both;
it does not take BBCode.)

```
## What it does

World of Warcraft decides when it rains. The server picks the weather, it picks it per zone, and plenty of zones never get any. Comfy Rain gives you the switch: rain or snow wherever you are, for as long as you want it.

It is built for ambience. If you spend time sitting in Goldshire, fishing in Stranglethorn, or running a roleplay night, this is the weather the game would not give you.

## Features

- **Rain and snow**, four intensities each, from a drizzle up to a monsoon or a whiteout blizzard
- **Weather audio** built from the game's own sound files, layered so it does not loop obviously, with distant thunder
- **Wind** that gusts, moving the rain, the sound and the light together rather than on a timer
- **Time of day**, hold the world at dusk or run it on your own clock instead of the realm's
- **Indoors handling**, it fades down under a roof instead of raining on the ceiling, and it knows places like Ironforge have no sky even when the game says otherwise
- **A settings panel** with a minimap button, everything previews live, no Apply button
- **Shareable settings**, export your setup as one line of text and send it to someone

## Using it

Click the minimap button, or type `/comfyrain`. Everything is in the panel.

Every control in the panel also shows the slash command it just ran, so if you prefer typing you pick the commands up by using the window. `/comfy` on its own turns the weather on and off.

## Real storms

When the server sends an actual storm, Comfy Rain stands aside and lets it fall. The game's own rain is 3D, so it stops under an arch or a bridge the way rain should, and where the real thing exists it is the better of the two.

## What it is, honestly

Comfy Rain draws a screen-space overlay: scrolling layers of rain in front of the camera, with the frame dimmed behind them. Addons are not allowed near the game's 3D weather, its particles, its lighting or its sky. So:

- It looks right when you are looking at the world.
- It cannot put rain outside a window while you stand indoors. There is one overlay and no way to ask the client which pixels are sky, so indoors it fades to a faint wash instead.
- It cannot change the sky, the clouds or the fog.
- It does not make puddles, wet the ground, or stop you drowning.

Three textured quads and a timer. No combat log parsing, no unit scanning, no taint, and it stops drawing entirely when the weather is off.

## Found a problem?

Type `/comfy bug`. It writes one line carrying your settings, where you were standing and what the addon was doing, already selected and ready to copy. Paste it into an issue on GitHub. The addon sends nothing anywhere.

## Free and open source

MIT licensed. The code is on GitHub: read it, fork it, take what you like.
```

## Main category

```
Audio & Video
```

## Additional categories

```
Roleplay
```

```
Artwork
```

## Toggles

- **Allow Comments:** on. It is the only feedback channel CurseForge gives you.
- **Unlisted project:** off. Unlisted means it never appears in search, which is the
  whole point of being on CurseForge.

## Owner / Author

```
LibruaryNFT
```

## License

```
MIT License
```

## Source URL

```
https://github.com/LibruaryNFT/comfyrain
```

## Issues URL

CurseForge has no issue tracker of its own, only a comments section. This field is the
only place a tracker link goes.

```
https://github.com/LibruaryNFT/comfyrain/issues
```

## Wiki URL

Leave empty.

---

## The file to upload

Attach the preview build so the project does not enter moderation empty — a project with
no downloadable file sits in the queue longer and reads as abandoned to whoever approves
it. Mark it **Alpha**, not Release.

```
https://github.com/LibruaryNFT/comfyrain/releases/tag/v0.9.1-alpha
```

Release type: **Alpha**. Game version: **Forever (1.60.1)**.

File changelog:

```
Pre-launch preview. The build that ran on the beta client all week. First Release is 4 November.
```

---

## Still to do on the page after it is approved

| Item | Status |
|---|---|
| Project avatar / icon | Done at creation: `docs/logo.png` |
| Gallery image | `docs/preview.jpg` is a real in-game frame, upload it now |
| Launch GIF | Not captured. Issue #10. Rain is motion and a still undersells it |
| Description screenshots | None yet; the beta client is gone until 4 November |

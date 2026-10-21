# Comfy Rain

**Rain or snow wherever you are, for as long as you want.**

World of Warcraft decides when it rains. The server picks the weather, it picks it per
zone, and a lot of zones never get any. Comfy Rain is the switch the game does not give you:
type `/comfy` and it is raining, in Durotar, in Elwynn, at the top of a mountain, on the
deck of the boat. Type it again and it stops.

It knows when to get out of the way. If the server sends a real storm, Comfy Rain stands
aside and lets it fall: the game's own rain is 3D, so it stops under an arch or a bridge
the way rain should, and where the real thing exists it is simply the better of the two.

![Comfy Rain, rain over the Stormwind Trade District](https://raw.githubusercontent.com/LibruaryNFT/comfyrain/main/docs/preview.jpg)

<!-- Swap this line for docs/preview.gif once the loop is captured. The still
     is a real in-game frame, not a mock-up, so it is an honest placeholder -
     but rain is motion and a still undersells it. -->


## What you get

| | |
|---|---|
| **Rain and snow** | Four intensities each, from a drizzle to a monsoon or a whiteout blizzard |
| **Sound** | Blizzard's own weather loops, layered and endlessly varied, with distant thunder |
| **Wind** | Gusts that move the rain, the sound and the light together, not on a timer |
| **Time of day** | Hold the world at dusk, or run it on your clock instead of the realm's. Works on its own, with the rain switched off |
| **Indoors** | Fades down under a roof instead of raining on the ceiling |
| **One-press scenes** | Cozy, Storm, Snow, Overcast for the weather; Dusk and Night for the light alone, with nothing falling |
| **A settings window** | `/comfyrain`, the minimap button, the addon compartment, or a keybind of your own. Every slider shows you the command it ran, so you learn them by using it |

## Getting started

```
/comfy
```

That is the whole thing. Everything below is optional.

| Command | What it does |
|---|---|
| `/comfy` | Turn the weather on or off |
| `/comfy preset cozy` · `storm` · `snow` · `overcast` | A whole look in one go. Also buttons at the top of the settings window |
| `/comfy preset dusk` · `night` | Just the light, no weather at all. Press a weather scene after it to have both |
| `/comfy rain` · `/comfy snow` | Pick which |
| `/comfy light` · `normal` · `heavy` | How hard |
| `/comfy monsoon` · `/comfy blizzard` | The two extremes |
| `/comfy auto` | Match whatever the server is doing right now |
| `/comfyrain` | Open the settings window |

<details>
<summary>The rest of the commands</summary>

| Command | What it does |
|---|---|
| `/comfy alpha 0.75` | How visible the rain is |
| `/comfy speed 1.4` | How fast it falls |
| `/comfy dim 0.5` | How much it darkens the world. `0` leaves the light alone |
| `/comfy gust 0.5` | How hard the wind gusts. `0` is dead calm |
| `/comfy indoors off \| dim \| on` | What happens under a roof. `dim` is the default |
| `/comfy sound on \| off` | The ambience bed |
| `/comfy volume 0.5` | How loud, over the weather only |
| `/comfy thunder on \| off` | Lightning and thunder |
| `/comfy channel Ambience \| SFX \| Master` | Which of the game's volume sliders owns it |
| `/comfy time local` | Light the world by your clock, not the realm's. Works with the rain off |
| `/comfy time 21` · `/comfy time +9` | Hold one hour, or shift the realm's by that many |
| `/comfy time strength 0.6` | How far towards that hour. The rest is in the settings window |
| `/comfy status` | What it currently thinks it is doing |
| `/comfy reset` | Back to defaults |

`/rain` is an alias for `/comfy`, and `/comfyui` also opens the window.

</details>

## What it is, honestly

Comfy Rain is a **screen-space overlay**. It draws scrolling layers of rain in front of the
camera and dims the frame behind them. It does not touch the game's 3D weather system,
its particles, its lighting or its sky, because addons are not allowed anywhere near any
of those.

In practice that means:

- It looks right when you are looking at the world. It is weather on your screen.
- It cannot put rain *outside* a window while you stand indoors. There is one overlay and
  no way to ask the client which pixels are sky, so indoors it fades to a faint wash
  instead. `/comfy indoors off` turns it off entirely.
- It cannot change the sky, the clouds or the fog. Nothing an addon draws can go behind
  the world.
- It does not make puddles, wet the ground, or stop you drowning.

If you want the game's own weather turned *off*, that is a graphics setting, not this
addon: `/console weatherDensity 0`.

## Performance

Three textured quads and a timer. There is no per-frame scanning, no combat log parsing,
no unit scanning and no taint. It stops drawing entirely when the weather is off, and
hidden frames cost nothing.

## Credits and licence

MIT. See [LICENSE](LICENSE).

The rain and snow sheets and the fallback audio are generated from the scripts in
`build/` — rasterised from an optical model of a raindrop rather than lifted from the
client's art. The addon icon is cut from `docs/logo.png`, which is original art made for
this project. Nothing of Blizzard's is redistributed.

Comfy Rain does play several of Blizzard's own weather and thunder sounds, by FileDataID.
Those files are already on your disk as part of the game; the addon just asks the client
to play them.

## Bugs

[Open an issue.](https://github.com/LibruaryNFT/comfyrain/issues) Include your `/comfy status`
output and the zone you were in.

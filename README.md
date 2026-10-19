# Duskfall

**Rain or snow wherever you are, for as long as you want.**

World of Warcraft decides when it rains. The server picks the weather, it picks it per
zone, and a lot of zones never get any. Duskfall is the switch the game does not give you:
type `/dusk` and it is raining, in Durotar, in Elwynn, at the top of a mountain, on the
deck of the boat. Type it again and it stops.

It runs on top of the game's own weather rather than fighting it. If the server sends a
real storm, you get both.

![Duskfall](https://raw.githubusercontent.com/LibruaryNFT/duskfall/main/docs/preview.gif)

## What you get

| | |
|---|---|
| **Rain and snow** | Four intensities each, from a drizzle to a monsoon or a whiteout blizzard |
| **Sound** | Blizzard's own weather loops, layered and endlessly varied, with distant thunder |
| **Wind** | Gusts that move the rain, the sound and the light together, not on a timer |
| **Time of day** | Hold the world at dusk, or run it on your clock instead of the realm's |
| **Indoors** | Fades down under a roof instead of raining on the ceiling |
| **A settings window** | `/duskfall`. Every slider shows you the command it ran, so you learn them by using it |

## Getting started

```
/dusk
```

That is the whole thing. Everything below is optional.

| Command | What it does |
|---|---|
| `/dusk` | Turn the weather on or off |
| `/dusk rain` · `/dusk snow` | Pick which |
| `/dusk light` · `normal` · `heavy` | How hard |
| `/dusk monsoon` · `/dusk blizzard` | The two extremes |
| `/dusk auto` | Match whatever the server is doing right now |
| `/duskfall` | Open the settings window |

<details>
<summary>The rest of the commands</summary>

| Command | What it does |
|---|---|
| `/dusk alpha 0.75` | How visible the rain is |
| `/dusk speed 1.4` | How fast it falls |
| `/dusk dim 0.5` | How much it darkens the world. `0` leaves the light alone |
| `/dusk gust 0.5` | How hard the wind gusts. `0` is dead calm |
| `/dusk indoors off \| dim \| on` | What happens under a roof. `dim` is the default |
| `/dusk sound on \| off` | The ambience bed |
| `/dusk volume 0.5` | How loud, over the weather only |
| `/dusk thunder on \| off` | Lightning and thunder |
| `/dusk channel Ambience \| SFX \| Master` | Which of the game's volume sliders owns it |
| `/dusk time` | Time-of-day grading. See the settings window |
| `/dusk status` | What it currently thinks it is doing |
| `/dusk reset` | Back to defaults |

`/rain` is an alias for `/dusk`, and `/duskui` also opens the window.

</details>

## What it is, honestly

Duskfall is a **screen-space overlay**. It draws scrolling layers of rain in front of the
camera and dims the frame behind them. It does not touch the game's 3D weather system,
its particles, its lighting or its sky, because addons are not allowed anywhere near any
of those.

In practice that means:

- It looks right when you are looking at the world. It is weather on your screen.
- It cannot put rain *outside* a window while you stand indoors. There is one overlay and
  no way to ask the client which pixels are sky, so indoors it fades to a faint wash
  instead. `/dusk indoors off` turns it off entirely.
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

Every texture and the fallback audio are generated from the scripts in `build/` —
rasterised from an optical model of a raindrop rather than lifted from the client's art.
Nothing of Blizzard's is redistributed.

Duskfall does play several of Blizzard's own weather and thunder sounds, by FileDataID.
Those files are already on your disk as part of the game; the addon just asks the client
to play them.

## Bugs

[Open an issue.](https://github.com/LibruaryNFT/duskfall/issues) Include your `/dusk status`
output and the zone you were in.

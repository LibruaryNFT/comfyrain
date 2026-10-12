# AlwaysRain — permanent rain in World of Warcraft

**What this is:** a WoW addon that makes it look and sound like it is always raining,
because the client cannot be told to actually change the weather.

**Status 2026-10-12:** v2 installed to `_classic_beta_`. v1 was confirmed running in
Stormwind. v2 switches all audio and the drop sprite to Blizzard's own assets and stops
the rain indoors; needs `/reload` to pick up (no new files, so no client restart).

## The finding that shaped it

Investigated client `WowB.exe`, build **1.60.1.70338** (`_classic_beta_`, portal `test`).
There is no supported way to force weather:

| Candidate | What it actually is |
|---|---|
| `C_Weather.GetCurrentWeather()` | the only Lua weather API — read-only, no setter |
| `ApplyWeather` / `RemoveWeather` | methods on the server-driven *scene script* object (next to `ApplyTimeOfDay`, `ApplyScreenEffect`), not addon-callable |
| `AllWeather` / `WeatherRain` / `WeatherSnow` / `WeatherSand` | values of the **transmog situation** enum ("wear this outfit when raining"), not setters |
| `weatherDensity`, `RAIDweatherDensity` | graphics CVars (0–3) controlling density of weather the server already sent |
| a `weather` console command | does not exist in this build — grepped every string |

Weather arrives from the server as `WEATHER_CHANGED`. The only way to force it client-side
is patching memory, which is bannable. Not doing that.

**Also found:** `weatherDensity` was `"0"` in both `_classic_beta_` and `_retail_` Config.wtf,
so real in-game weather was not being rendered at all. And `Sound_MasterVolume "0.10000000149012"`,
`Sound_MusicVolume "0"` in beta.

## Blizzard assets used, by FileDataID

Addons can pass a numeric FileDataID to `SetTexture` and `PlaySoundFile`, so the client's own
files are reachable with nothing extracted and nothing shipped. **A FileDataID needs no client
restart** — only new files on disk do. Durations below were measured from the real files
(pulled via `https://wago.tools/api/casc/<fdid>?download`) and must stay in sync with `BEDS`
in the Lua, because the loop ticker is driven by them.

| Asset | FileDataID | Measured |
|---|---|---|
| RainLightLoop.ogg | 538983 | 20.0 s, mean -35.8 dB |
| RainMediumLoop.ogg | 538981 | 30.0 s, mean -30.5 dB |
| RainHeavyLoop.ogg | 538982 | 25.0 s, mean -20.8 dB |
| FX_TKIsle_MWThunderRumble ×10 | 838830, 838832, 838834, 839725, 839727, 839729, 839731, 839733, 839735, 839737 | 5.5–7.6 s |
| WeatherMistGrainy01.blp | 396498 | 256×256, the mist veil |
| RainDrop01.blp | 186226 | 16×128 tapered streak, composited into our sheets |

Snow (538985 / 538989 / 538984) and sandstorm (538988 / 538987 / 538986) loops exist on the
same naming scheme if the addon ever grows other weather.

Rejected after looking at them: `UI_Worgen_Rain01` (313250, faint horizontal streaks) and
`worgen_RainEffects_01` (304844, a splash/puddle decal). **Blizzard ships no tiling rain-curtain
sheet** — only single particle sprites, placed by a particle system an addon cannot reach. That
is why the curtain is still ours; only the drop in it is theirs.

FileDataIDs came from `listfile/verified-listfile.csv` (community listfile, tag `202610111812`,
1,087,814 rows — not checked in, 71 MB).

## How the addon works

- A frame parented to **`WorldFrame`** (not `UIParent`) at strata `BACKGROUND`: draws above the
  3D scene, below every UI frame, and stays visible when the UI is hidden with Alt+Z.
- Three scrolling layers — Blizzard's mist texture, then far and near rain sheets — using
  `SetTexture(..., "REPEAT", "REPEAT")` and `SetTexCoord` offsets > 1 to tile. `tilesX` is derived
  from screen aspect each frame so drops stay the right shape at 2125x1080 and at any other size.
- An additive white flash texture for lightning, with thunder trailing 0.6–3.2 s behind it.
- Audio: Blizzard's rain loop for the current intensity, relooped by
  `C_Timer.NewTicker(len - 0.12)` using that file's exact measured duration. Falls back to the
  bundled `rain.ogg` only if `PlaySoundFile` refuses the FileDataID, and says so in `/rain status`.
- **Indoors:** `IsIndoors()` is polled every 0.3 s with a 0.9 s debounce (so an archway does not
  restart the audio), plus the `ZONE_CHANGED*` events. Going inside fades the overlay out over
  0.7 s and stops the bed; `/rain indoors on` opts back into raining inside.

### Asset generation
Assets are not checked in; they are deterministic output of the build scripts.
- `build/make_rain_tga.py` — 512×512 32-bit **uncompressed** TGA (WoW rejects RLE TGA), built by
  scattering Blizzard's RainDrop01 sprite so it wraps in both axes. `SLANT_DEG = 7.5` here **must
  match** `SLANT` in `AlwaysRain.lua` as its tangent (0.1317). Widths are set in absolute pixels,
  not scaled with length — scaling the 16×128 source proportionally gives 30 px bars, not rain.
- `build/make_rain_audio.py` — the fallback bed only. Noise is shaped in the frequency domain over
  exactly one loop length, so the result is periodic and the join is sample-exact; that removed
  the end fades v1 needed, which were what made two clips audibly swell over each other.
- `build/assets/` caches the Blizzard files pulled for reference. Read-only, never shipped.

## Install

```
./install.sh                # _classic_beta_
./install.sh _retail_
```
A **full client restart** is required for a first install — WoW only scans `Interface/AddOns`
at launch. Later Lua edits need only `/reload`.

## Commands

`/rain` toggle · `/rain light|normal|heavy|monsoon` · `/rain alpha 0.75` · `/rain speed 1.4` ·
`/rain gloom 0.5` · `/rain indoors on|off` · `/rain sound on|off` · `/rain thunder on|off` ·
`/rain channel Ambience|SFX|Master` · `/rain status`

## What this can never match

Blizzard's rain is **3D particles in world space**. They have depth, they parallax
correctly as you move, buildings and terrain occlude them, and they splash. This is a flat
sheet in front of the camera. Two of the gaps are now papered over — a MOD-blend quad fakes
the lighting change, and yaw parallax sweeps the curtain when you turn — but occlusion and
splashes are not reachable from an addon at all, and the depth is faked with two layers
rather than real.

World lighting is the hard limit: `SetFogColor`, `SetLight` and `SetFogNear`/`SetFogFar`
exist in this client but are **Model-widget methods** (they sit beside `SetModel` and
`GetModelFileID` in the API table), so they apply to a model frame, not the world. There is
no world fog or ambient-light setter exposed to addons.

## Open / unverified

- **v2 has not been seen running.** v1 was; the Blizzard FileDataIDs, the mist texture and the
  indoor fade are all unconfirmed against a live client. `/rain status` reports
  `(bundled audio)` if the sound IDs were refused.
- `IsIndoors()` is the client's own notion of inside and it is imperfect — it reads true under
  some large awnings and false in some open-roofed buildings. Nothing better is exposed.
- Dungeons and raids are not specially handled; they report indoors, so the rain stops there.
- `## Interface: 16001` is inferred from `SET engineSurveyPatch "16001"` in Config.wtf.
- **`weatherDensity` is still `"0"`.** the author has therefore never seen this client render real
  Blizzard rain, so there is no side-by-side to judge the overlay against. `/console
  weatherDensity 3` and a rainy zone (Stranglethorn, Hillsbrad, Dustwallow) would give one.
- Yaw parallax uses `GetPlayerFacing()`, which is the player, not the camera. Free-look
  (right-mouse held) moves the camera without moving facing, so the rain will not sweep then.
- the author's beta client runs very low graphics (`RenderScale 0.65`, particles off). The overlay is
  4 fullscreen quads plus one `OnUpdate`, so cost is negligible, but in-client weather
  (`weatherDensity 3`, `particulatesEnabled 1`) is not free on a GTX 1660.

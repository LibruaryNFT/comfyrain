# AlwaysRain — permanent rain in World of Warcraft

**What this is:** a WoW addon that makes it look and sound like it is always raining,
because the client cannot be told to actually change the weather.

**Status 2026-10-12:** built and installed to `_classic_beta_`. Not yet seen running —
WoW was open during the build, so it has never been loaded by the client.

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

## How the addon works

- A frame parented to **`WorldFrame`** (not `UIParent`) at strata `BACKGROUND`: draws above the
  3D scene, below every UI frame, and stays visible when the UI is hidden with Alt+Z.
- Two scrolling rain-streak textures (far/near) using `SetTexture(file, "REPEAT", "REPEAT")` and
  `SetTexCoord` offsets > 1 to tile. `tilesX` is derived from screen aspect each frame so drops
  stay round at 2125x1080 and at any other size.
- A flat grey `SetColorTexture` mist veil, and an additive white flash texture for lightning.
- Audio: a 24 s synthesised rain bed looped by `C_Timer.NewTicker(24 - 0.35)`; the 0.35 s overlap
  lands on the clip's fades so the join crossfades instead of clicking. Thunder is a separate
  one-shot fired 0.6–3.2 s after a flash. Both play on the **Ambience** channel by default.

### Asset generation
Assets are not checked in; they are deterministic output of the build scripts.
- `build/make_rain_tga.py` — 256x256 32-bit **uncompressed** TGA (WoW rejects RLE TGA), streaks
  wrap in both axes. `SLANT = 0.14` here **must match** `SLANT` in `AlwaysRain.lua`.
- `build/make_rain_audio.sh` — ffmpeg-synthesised, three noise layers (brown roar / mid body /
  high patter) merged to a slightly decorrelated stereo pair. `DUR` and `FADE` **must match**
  `RAIN_LEN` and `RAIN_OVERLAP` in `AlwaysRain.lua`.

## Install

```
./install.sh                # _classic_beta_
./install.sh _retail_
```
A **full client restart** is required for a first install — WoW only scans `Interface/AddOns`
at launch. Later Lua edits need only `/reload`.

## Commands

`/rain` toggle · `/rain light|normal|heavy|monsoon` · `/rain alpha 0.75` · `/rain speed 1.4` ·
`/rain sound on|off` · `/rain thunder on|off` · `/rain channel Ambience|SFX|Master` · `/rain status`

## Open / unverified

- **Never launched.** Nothing below is confirmed against a running client.
- `## Interface: 16001` is inferred from `SET engineSurveyPatch "16001"` in Config.wtf, not read
  from the binary. If the addon does not appear in the list, tick **Load out of date AddOns** on
  the character-select AddOns screen and read the real number off the warning.
- TGA loading is unverified. If the streaks come up blank/black, the textures need converting to
  BLP (no BLP tooling on this box yet) or swapping for an in-client texture path.
- Rain currently also falls indoors and in dungeons/raids — literally "always". An `IsIndoors()`
  suppression toggle is a few lines in `Refresh()` if that turns out to be annoying.
- the author's beta client runs very low graphics (`RenderScale 0.65`, particles off). The overlay is
  3 fullscreen quads plus one `OnUpdate`, so cost is negligible, but in-client weather
  (`weatherDensity 3`, `particulatesEnabled 1`) is not free on a GTX 1660.

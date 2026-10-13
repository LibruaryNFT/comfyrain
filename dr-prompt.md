You are advising a solo developer on an unpublished World of Warcraft addon called **AlwaysRain**. Three prior deep-research reports have already been commissioned and read. Two of them got the target client wrong and built their recommendations on that error. Your job is not to repeat that work. It is to answer the questions that survived it.

Read the **Verified facts** section as established ground truth. It was checked against the shipped client binary and the repository, not inferred. **Do not re-derive it, do not contradict it without new evidence stronger than a string in the executable, and do not spend a single paragraph restating it back.** If you believe something in it is wrong, say so in one line with your evidence and move on.

---

## Verified facts — do not re-research these

### The client is WoW: Forever, not Classic Era

Build `1.60.1.70338`. The executable identifies itself as **`wow-forever-client`**. The TOC game-type pair `camelot` / `forever` sits adjacent in the string table at `0x51B3BE8`. The addon's `.toc` declares `## Interface: 16001`.

Consequences, and the reason two prior reports were useless: Forever shares **Mainline's** UI architecture, not Classic Era's. Advice premised on Classic Era, Season of Discovery or Hardcore as the primary audience is void. The install folder on this machine is `_classic_beta_`, which is misleading and is not evidence of a Classic API family.

Forever carries **Midnight's addon-disarmament machinery**. All of these are present in the binary: `canaccessvalue`, `issecurevariable`, `secretvalue`, `SecretValue`.

### API presence, verified by string extraction with `GetUnitSpeed` as the positive control

| Symbol | Result |
|---|---|
| `GetUnitSpeed` (control) | present |
| `WEATHER_CHANGED` | present, in the event table beside `VIGNETTES_UPDATED` |
| `C_Weather` / `GetCurrentWeather` / `intensity` / `WeatherType` = `Rain`, `Snow`, `Sandstorm` | present at offset 81939440. Read-only; there is no setter |
| `C_AddOnProfiler`, `AddOnProfilerMetric` | present |
| `SetTempCVar` | present |
| `IsDayTime` | present |
| `GetBestMapForUnit` | present |
| `SetParticlesEnabled` | present |
| `IsSubmerged` | present |
| `canaccessvalue`, `issecurevariable` | present |
| **`GetCameraPitch`** | **absent.** There is no camera pitch source. Vertical parallax is impossible. Do not propose it |
| `Settings.RegisterVerticalLayoutCategory` and every other `Settings.*` call | zero hits — **but this is the wrong instrument, not an absence.** `Settings` is implemented in FrameXML Lua, not in the executable. Unresolved; see the open questions |

There is **no weather setter of any kind** exposed to Lua. `SetFogColor`, `SetLight`, `SetFogNear` and `SetFogFar` exist but sit in the API table immediately beside `SetModel` and `GetModelFileID`, making them **Model widget** methods that apply to a model frame rather than the world. World lighting, fog and post-processing are unreachable. The addon cannot sample the rendered framebuffer, so nothing requiring the rendered scene as an input is possible: no refraction, no occlusion, no true wet-surface sheen.

### Legality is settled. Do not re-answer it.

All three prior reports independently concluded that publishing is ToS-safe, and they agreed on the reasoning: the addon is free, its Lua is unobfuscated, it ships no Blizzard assets, it references Blizzard audio only by FileDataID so nothing is redistributed, it reads no combat state, and Blizzard's restrictions target computational combat addons rather than cosmetics. Dynamic Weather has advertised itself as ToS-compliant since 2020 with roughly 20,600 downloads and no known challenge. CurseForge Author Rewards are compatible with the free-addon rule because the platform pays the author and the user is never charged.

**Only these legal questions remain open, and each gets at most a short paragraph:**

- Blizzard's UI Add-On Development Policy point 3 bars addons that cause "slow frame rates", at Blizzard's sole discretion. Is there any case of that clause being applied to a visual overlay, and what frame-time figure would make it a real risk rather than a theoretical one?
- Does any published Blizzard guidance for Midnight or Forever specifically address cosmetic overlays, beyond Ion Hazzikostas's April 2025 statement that aesthetic and display mods would be preserved? Quote it if it exists.
- Is the separate "World of Warcraft Terms of Use" still a live document in 2026, or was it fully absorbed into the Blizzard EULA of 21 March 2024? One report could not resolve this.

### What has been built

694 lines of Lua in one file, two Python asset generators (111 and 144 lines) run at install time, a shell installer and a `.toc`. No C++, no runtime dependencies, no external libraries. Nine commits on a local `main`. **No git remote. Nobody but the author has ever run it.**

- Three scrolling layers parented to `WorldFrame` (mist, far, near), tiled by `SetTexCoord` beyond 1.
- A **MOD-blend fullscreen quad** that multiplies the finished frame. This is the only way an addon can darken the world given that world lighting is unreachable. Tinted toward `{0.55, 0.62, 0.78}`.
- An ADD-blend quad for lightning.
- **Yaw parallax** from `GetPlayerFacing()`, at per-layer rates (mist 0.25, far 0.9, near 1.0).
- Horizon fade via `SetGradient("VERTICAL", ...)`.
- Speed response from `GetUnitSpeed("player")`.
- Four presets: light, normal, heavy, monsoon.
- Suppressed indoors via `IsIndoors()` with a 0.9 s debounce, and during cinematics.
- **Time-of-day grading** (below).
- Both overlay frames call `EnableMouse(false)`. One prior report called mouse capture a fatal flaw in this design; it does not apply, and you should not raise it.
- Restricted getters now pass through a `Readable()` helper that returns nil for anything `canaccessvalue` rejects, so parallax and speed response freeze in encounters instead of throwing. A secret value is non-nil and looks like a number until arithmetic touches it, so a nil check alone was insufficient.
- Slash commands only. **There is no options GUI.**

### Assets are original, deliberately

An early build composited the rain sheets from Blizzard's `RainDrop01` (FileDataID 186226). That was removed because shipping it would redistribute Blizzard art.

Every drop is now rasterised from an **optical model**: a raindrop is a sphere acting as a lens that smears into a streak over one frame, giving a Gaussian across its width and a head-bright, tail-fading envelope along its length, with both ends windowed to zero. Each drop gets its own taper and curvature, and the 7.5-degree slant is sheared in during rasterisation rather than applied by rotation, so no pixel is resampled and thin streaks stay crisp. Drops wrap in both axes. Output is two 512x512 32-bit uncompressed TGAs, under 1 MB total. Dynamic Weather, for comparison, ships 46 MB of uncompressed TGA.

Audio is synthesised in the **frequency domain over exactly one loop length**, so the signal is periodic and the loop point is sample-exact with no crossfade. Five gain variants exist because `PlaySoundFile` takes no volume argument, so level has to live in the file. At runtime the addon prefers Blizzard's own loops by FileDataID (`RainLightLoop` 538983, `RainMediumLoop` 538981, `RainHeavyLoop` 538982, plus ten thunder IDs) and falls back to the generated `.ogg`.

### Time-of-day grading, the differentiating feature

The author's framing: *"I want it to always rain, and I want my game's day and night to run on a different clock to the realm's, because I want my game cosy."* The use case given was an Australian player on a US realm who wants the game dark when it is dark for him.

A second MOD-blend quad over `WorldFrame`, independent of whether rain is on. A twelve-point curve maps hour to an RGB triple, `{1,1,1}` being full daylight and midnight roughly `{0.30, 0.36, 0.62}`. The grade is the **ratio** of the wanted hour's colour to the realm hour's colour, so when the clocks agree the multiplier is exactly 1 and the filter is a no-op rather than a permanent tint. Brightening past 1 goes to a small ADD lift quad capped at 0.13 alpha, because MOD can only darken. Modes: off, local, offset ±N, fixed hour, plus a strength scalar.

**No addon in the competitive survey does this.** All three prior reports agreed it should be the headline feature rather than the rain.

### The calibration problem

On this machine `weatherDensity` is `0` and `graphicsEnvironmentDetail` is `1`. At those values the client never draws Blizzard's real weather. **The author has never seen this client render real rain, and every visual default in the addon is therefore uncalibrated against the thing it imitates.** A `/rain density` command now reports and can raise both CVars.

### The competitive field

| Addon | Provenance | Size | What it does |
|---|---|---|---|
| Dynamic Weather (Scroll_Keeper) | CurseForge, Public Domain, ~20,600 downloads, **unmaintained since Jul 2021**, `## Interface: 40300` | 1,895 Lua lines, 46 MB TGA | 18 weather states; ~200 zones mapped to biomes; four seasonal tables keyed off the real calendar; a Mersenne Twister in Lua seeded from `GetServerTime()` so every copy agrees with no comms; hourly forecast bar; flavour text per transition; Blizzard soundkit IDs; 14 lens droplets; continent overrides |
| Dynamic Azeroth Weather (ForgeDMC) | CurseForge, 2026, ~355 downloads | 1,061 lines, 7 files | FNV-1a hash of `zone .. "::" .. serverHourBucket` into a weighted choice; 4-hour forecast; per-zone climate weights; minimap button; options panel; thunder flash and fake screen shake. Parents particles to `UIParent`, so **its rain draws over the action bars**. Its "rain" is 200 white 2x20 rectangles moved in `OnUpdate` |
| Weather (CurseForge / WoWInterface) | ~2,300 downloads, updated Aug 2026 | small | Muffled indoor weather ambience, a screen colour overlay scaled to real in-game weather intensity, day/night minimap icon. **Its Lua has not been read. Nobody has confirmed whether it uses MOD blending** |
| RainingBlood | MIT, 2019 | **2 lines** | `SetCVar("weatherDensity", 3)`, `SetCVar("violencelevel", 5)` |
| ImmersiveWeather | 2025, ~135 downloads | ~40 lines | A text label by the minimap. No visuals |
| DayNight | MIT, 2015, 136 downloads | tiny | Drives the `gamma` CVar down at night. Darkens the UI too |

**Not one rival calls `SetBlendMode` at all**, so nothing in the survey except AlwaysRain can darken the sky — with the Weather addon unread and therefore unconfirmed.

Known Blizzard weather soundkit IDs harvested from Dynamic Weather: overcast 18414, light rain 111995, heavy rain 112759, thunder 111998, blizzard 39789, high wind 39821, sandstorm 21436, snow flurry 4197.

### Consensus from the three prior reports, for you to stress-test rather than repeat

All three independently ranked an **options GUI** as the single biggest adoption blocker and a **data-driven effect schema** (weather types as table entries rather than code) as the biggest architectural change. One argued the schema should come *after* the real-weather calibration, because refactoring first risks encoding the wrong parameters. Decide which ordering is right and say why.

They also converged, without prompting, on: deferring to real weather via `C_Weather`; capping lightning at three flashes per second on photosensitivity grounds; deterministic weather from a zone-plus-hour hash; crossfading audio beds with `StopSound(handle, fadeMs)`; and an atlas rather than individual textures for lens droplets.

---

## What to actually research

Weight these as given. Skip anything already settled above.

### A. Forever as a launch opportunity (20%)

- Forever launched 4 November 2026 after a beta from 17 September. **Find out what actually happened to its addon ecosystem.** Which addons shipped Forever builds, how fast, and which categories are crowded versus empty? Is "immersion and atmosphere" occupied?
- Classic addons do not carry over to Forever, so the ecosystem was rebuilt. Is that window still open, or has it closed? Name the specific competitors that appeared.
- **What do secret values actually break for a cosmetic addon on Forever?** Find real authors' accounts of what `canaccessvalue` returns false for in practice: `GetPlayerFacing` in instances, map IDs, anything else a weather overlay would touch. This is the highest-value unknown, because it determines whether yaw parallax works at all in the content people spend time in.
- Does Forever use the `_retail_` AddOns directory or its own? One report claimed `_retail_`; this machine installs to `_classic_beta_`. Resolve it.
- Give a real population estimate with a stated method, or say that none exists. One prior report found claims of 600,000 and 37,470 and could not reconcile them; do not repeat that.

### B. Shipping it properly (20%)

- Confirm whether the **native Settings API** is available and working on Forever (TOC 16001), and give the exact current call sequence with correct signatures. This is unresolved and blocks the top-ranked feature. If AceConfig-3.0 is the safer choice on Forever, say so and justify the dependency.
- **BigWigsMods/packager**: does a released version support the `forever` flavour, or only an unreleased commit? One report cited a merged PR from 17 September 2026 but could not confirm a release. Pin a version.
- The exact multi-flavour TOC recipe for one package covering Forever (16001) and retail 12.1.x, including `AllowLoadGameType` / `ExcludeLoadGameType` and per-flavour TOC filenames, with the behaviour on clients that do not recognise `forever`.
- Positioning: is "the maintained successor to Dynamic Weather" worth anything when that addon's 20,600 users are on retail, were last served in 2021, and are reachable only through CurseForge search? Two reports said lead with it; one said use it once for SEO and lead with time-of-day instead. Pick one and give the reasoning.
- What specifically gets attacked in CurseForge comments on fullscreen-overlay addons? Find real examples.

### C. Making it the best weather addon that has ever existed (60%)

Be concrete and technical: specific API calls with correct signatures, specific numbers, implementation sketches. **Verify every API you name.** Prior consultations on this project invented `GetCameraPitch()` and `C_Weather.GetWeatherInfo()`; both returned zero hits against the binary while a control API returned hits. If you cannot verify something exists, label it and say how to check.

- **Calibration.** The author has never seen real rain in this client. Design the side-by-side experiment: which zone, which CVar values, what to measure, and which of the addon's defaults each measurement should move. Specifically: does Blizzard's real rain already darken the scene? If it does, the MOD gloom quad double-darkens and the whole preset table is wrong.
- **Real-weather behaviour.** `C_Weather.GetCurrentWeather()` and `WEATHER_CHANGED` both exist, but the **field names of the returned table are unconfirmed**. Find them, from `WeatherScriptDocumentation.lua` in Gethe's wow-ui-source or equivalent. Then specify the behaviour when the server really is raining, snowing or sandstorming, including what happens to the gloom quad and the audio bed, and how to avoid doubling Blizzard's own rain loops.
- **The depth problem.** Three layers plus mist plus yaw parallax is where it stands, with no vertical parallax available. How much further can layering, baked per-layer blur, and scale-with-distance get before returns vanish? Is a fourth layer worth it?
- **Model frames and `SetParticlesEnabled`.** This is the most interesting unexplored direction and it is verified present in the binary. Can a `Model` or `ModelScene` frame render a Blizzard weather M2 by FileDataID with a transparent background, over `WorldFrame`, with particles enabled? What does it cost in frame time? One report claimed a measurable penalty even for an empty model frame. Settle it, or give the exact test.
- **Lens droplets** done well: atlas layout, pool size, animation groups, and specifically how to stop them reading as dirt on the monitor rather than water on a lens.
- **Audio.** `PlaySoundFile` has no volume, pan or pitch argument. Given five pre-baked gain variants and `StopSound(handle, fadeMs)` for fade-out but no fade-in, design the layered crossfading soundscape: intensity beds, indoor muffling, a near-surface layer when stationary, and thunder timed to the flash by distance.
- **Determinism.** Both rivals hash localised **zone names**, so players in different locales would see different weather. `GetBestMapForUnit` exists. Specify the hash, the bucket size, and the transition handling so weather does not snap at bucket boundaries. Is `SendAddonMessage` ever worth it, or does determinism make it redundant?
- **Performance.** Five or more fullscreen blended quads plus droplets. Give a real budget in `C_AddOnProfiler` terms, the measurement procedure, and the specific optimisations that matter. Note that the MOD gloom quad and the MOD time-of-day quad can be collapsed into one by multiplying their colours in Lua, since MOD composed with MOD equals MOD of the product — confirm that is exact and worth doing.
- **Time-of-day 2.0, the headline.** What does a complete version look like? Cover at minimum: smooth periodic interpolation instead of 12-point linear lookup; whether to interpolate in linear light rather than sRGB; warm sunrise and sunset ramps given that MOD can only darken and the ADD lift is capped at 0.13; golden-hour-forever and blue-hour modes; a "live on Sydney time" offset; moon phase from the real date; per-zone strength overrides for already-dark zones like Duskwood; and how `C_DateAndTime.IsDayTime` should be used as a cross-check on Forever, whose day/night may not be simple wall-clock.
- **What is missing entirely.** What would an experienced addon author or a graphics programmer say is the wrong approach here, or the obvious direction nobody has considered? One prior report questioned whether *permanent* rain should even be the default, on the grounds that constant rain habituates and contrast is what makes rain feel cosy. Take a position on that.

### D. One thing to go and read

The CurseForge/WoWInterface addon simply called **"Weather"** (~2,300 downloads, updated August 2026) has never had its Lua read, and it is the only rival that might also darken the screen. Download it, read it, and report what it actually does. The claim "nothing else in this field can darken the sky" currently rests on that gap.

---

## Output format

1. **Corrections** — anything in the verified-facts section you believe is wrong, with evidence. One line each. If nothing, say so in one line.
2. **Forever opportunity** — the ecosystem state, the secret-value reality, and a go or no-go on timing.
3. **Shipping** — the resolved Settings API answer, the pinned packager version, the TOC recipe, and the positioning call.
4. **Ranked roadmap** — each item with effort in developer-days, the specific APIs, and why it earns its rank. Take an explicit position on whether the GUI or the schema comes first.
5. **Unverified** — everything you could not confirm, and the exact in-game command or file that would confirm it.

Cite URLs throughout. Where community opinion conflicts with documentation, say which you weight and why. Do not pad: if a section has one sentence of real content, give one sentence.

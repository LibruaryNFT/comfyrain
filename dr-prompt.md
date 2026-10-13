You are researching on behalf of a solo developer who has built a World of Warcraft addon called **AlwaysRain** and is deciding whether to publish it, whether it is legally safe to do so, and what it would take to make it genuinely world class rather than merely working. Produce a decision-grade report, not a summary of what WoW addons are.

Answer three questions, in this order, and weight them roughly 20 / 30 / 50:

1. **Is it legal and ToS-safe to publish?**
2. **Should it be published at all, and if so where and how?**
3. **What specifically would make it the best weather addon that has ever existed?**

---

## Full context on what has been built

### What the addon does

AlwaysRain makes it rain in World of Warcraft permanently, visually and audibly, regardless of what the server says the weather is. It is 694 lines of Lua in a single file, plus two Python scripts (111 and 144 lines) that generate the art and audio at install time, a shell installer and a `.toc`. No C++, no binary, no external dependencies at runtime.

It is currently **unpublished**. There is no git remote; nine commits exist on a local `main` branch only. Nobody other than the author has ever run it.

### Target client

WoW Classic beta, build `1.60.1.70338`, flavour `_classic_beta_`, portal `test`. Running on Linux under Steam Proton / XWayland on GNOME Wayland. The author also has `_retail_` and `_classic_era_` installed. The installer takes the flavour as an argument.

### The constraint that shaped everything

There is **no supported way for an addon to force weather in this client**. This was verified by extracting the strings from `WowB.exe` and searching them, not inferred:

- There is no weather setter of any kind exposed to Lua.
- `SetFogColor`, `SetLight`, `SetFogNear` and `SetFogFar` all exist in the binary, but they sit in the API table immediately beside `SetModel` and `GetModelFileID`, so they are **Model widget** methods that apply to a model frame, not to the world. There is no world fog or ambient light setter.
- `C_Weather` **does** exist, at offset 81939440, with `GetCurrentWeather`, an `intensity` field and `Enum.WeatherType` of `Rain` / `Snow` / `Sandstorm`. It is read-only. It reports weather; it cannot set it.

Memory patching the client was considered and rejected outright as bannable. Running a private server was never on the table.

So the addon is a **screen-space illusion drawn in front of the camera**, parented to `WorldFrame` so the game UI stays on top of it.

### How it works today

- Three scrolling layers parented to `WorldFrame`: a `mist` layer (BACKGROUND strata), a `far` rain layer and a `near` rain layer, each a tiling texture scrolled by manipulating `SetTexCoord` with values greater than 1.
- A **MOD-blend fullscreen quad** that multiplies the finished frame, which is the only way an addon can darken the world given that world lighting is unreachable. Tinted toward `{0.55, 0.62, 0.78}`.
- An ADD-blend quad for lightning flashes.
- **Yaw parallax**: the layers slide horizontally in response to `GetPlayerFacing()`, at different rates per layer (`mist` 0.25, `far` 0.9, `near` 1.0), so turning the camera sweeps the curtain and the rain reads as having depth.
- A horizon fade using `SetGradient("VERTICAL", ...)` so the sheet does not terminate in a hard line at the skyline.
- Speed response tied to `GetUnitSpeed("player")`.
- Four presets: `light`, `normal`, `heavy`, `monsoon`, each a tuple of mist/far/near alpha, drop density, fall speed and gloom.
- Suppressed indoors via `IsIndoors()` with a 0.9 s debounce so walking under an arch does not restart the audio, and during cinematics.
- **Time-of-day grading**, the author's own idea, described below.
- Slash commands only: `/rain` and `/alwaysrain` with `on|off`, the four presets, `alpha`, `speed`, `gloom`, `time`, `indoors`, `sound`, `thunder`, `channel`, `cycle`, `density`, `status`, `help`. **There is no options GUI.**
- SavedVariables for all settings.

### The art is original, and that was deliberate

An early version composited the rain sheets from Blizzard's own `RainDrop01` sprite (FileDataID 186226). That was removed because shipping it would redistribute Blizzard's copyrighted art, which their addon policy forbids. The cached `.blp` was deleted from the repo.

Every drop is now rasterised from an **optical model** in `build/make_rain_tga.py`: a raindrop is a small sphere acting as a lens that smears into a streak over one frame, giving a Gaussian across its width and a head-bright, tail-fading envelope along its length. Both ends are windowed to zero so no streak terminates in a chopped edge. Each drop gets its own taper rate and a little curvature, and the 7.5-degree slant is sheared in during rasterisation rather than applied by rotating the sheet, so no pixel is ever resampled and thin streaks stay crisp. Drops wrap in both axes so the sheet tiles seamlessly. Output is two 512x512 32-bit uncompressed TGAs.

Audio in `build/make_rain_audio.py` is synthesised in the **frequency domain over exactly one loop length**, so the signal is periodic and the loop point is sample-exact with no crossfade. Five gain variants are written because `PlaySoundFile` takes no volume argument, so level has to live in the file. A thunder one-shot is synthesised separately from a low rumble plus a filtered crack.

At runtime the addon **prefers Blizzard's own weather audio by FileDataID** (`RainLightLoop` 538983, `RainMediumLoop` 538981, `RainHeavyLoop` 538982, plus ten thunder IDs) and falls back to the generated `.ogg` only if those will not play. Referencing a FileDataID uses the player's own installed files and ships nothing, so it is not redistribution. The author believes this distinction matters and wants it checked.

The installed folder contains only: `AlwaysRain.lua`, `AlwaysRain.toc`, two `.tga`, six `.ogg`. Nothing from Blizzard.

### Time-of-day grading, the differentiating feature

The author's own framing: *"I want it to always rain, and I want to be able to make my game's day and night run on a different clock to the realm's, because I want my game cosy."* The use case he gave was an Australian player on a US realm who wants the game to be night when it is night for him.

Implemented as a second MOD-blend quad over `WorldFrame`, independent of whether rain is on. A twelve-point `LIGHT` curve maps hour of day to an RGB triple, where `{1,1,1}` is full daylight and midnight is roughly `{0.30, 0.36, 0.62}`. Crucially the grade is computed as the **ratio** of the wanted hour's colour to the realm's actual hour colour, so when the two agree the multiplier is exactly 1 and the filter is a no-op rather than a permanent tint. Brightening beyond 1 is handled by a small ADD-blend lift quad capped at 0.13 alpha, because MOD can only darken. Modes: `off`, `local` (match the player's own wall clock), `offset +N/-N` hours, `fixed <hour>`, plus a `strength` scalar from 0 to 1.

### Protocol research already done

The author wanted to understand how Blizzard keeps every client aligned so as to deliberately **not** break that alignment. Researched from CMaNGOS / mangos-classic source, read in `/tmp` and never copied into the repo, with the explicit caveat that it is a reverse-engineered reimplementation and not Blizzard's code:

- `SMSG_LOGIN_SETTIMESPEED` carries the packed game time plus a speed of `0.01666667f`, which is 1/60 game-minutes per real second, i.e. **exactly 1:1 with real time**. `SMSG_GAMETIME_UPDATE` re-syncs drift.
- `SMSG_WEATHER` carries `uint32 type`, `float grade`, `uint32 sound id` and a `uint8` smooth/instant flag, broadcast **per zone**.
- Weather is re-rolled every 10 minutes: 30% no change, 30% better, 30% worse, 10% radical, from per-zone **per-season** chance tables, with the season derived from the real calendar date. Grade bands sit at 0.33 and 0.67, which is exactly why Blizzard ships three rain loops.
- `m_isPermanentWeather` exists as a concept server-side.

### The survey of every rival addon

Each was downloaded and its Lua read. Nothing was copied.

| Addon | Provenance | Size | What it does |
|---|---|---|---|
| Dynamic Weather (Scroll_Keeper) | CurseForge, Public Domain, ~20.7k downloads, last updated Jul 2021, `## Interface: 40300` | 1,895 Lua lines, 46 MB of uncompressed TGA | 18 weather states; ~200 zones mapped to biomes; four seasonal biome tables keyed off the real calendar; a Mersenne Twister implemented in Lua, seeded from `GetServerTime()`, so every installed copy agrees without any addon comms; hourly forecast bar; flavour text on each transition; Blizzard soundkit IDs per state; 14 lens droplet frames; continent-level overrides so friends can agree on weather |
| Dynamic Azeroth Weather (ForgeDMC) | CurseForge, 2026, 358 downloads | 1,061 Lua lines over 7 files | FNV-1a hash of `zone .. "::" .. serverHourBucket` feeding a weighted choice; 4-hour forecast; per-zone climate weight tables; minimap button; options panel; thunder flash with a fake screen shake |
| RainingBlood | CurseForge, MIT, 2019 | **2 lines** | `SetCVar("weatherDensity", 3)` and `SetCVar("violencelevel", 5)` |
| ImmersiveWeather | CurseForge, 2025, ~135 downloads | ~40 lines | A text label beside the minimap. No visuals |
| DayNight | CurseForge, MIT, 2015, 136 downloads | tiny | Drives the `gamma` CVar down at night. Darkens the UI along with the world |

**What the rivals have that AlwaysRain does not:** deterministic seeding from zone plus server-hour so everyone sees the same sky with zero network traffic; per-zone climate weights; seasons; a forecast; flavour text on transitions; Blizzard's full weather soundkit library (overcast 18414, light rain 111995, heavy rain 112759, thunder 111998, blizzard 39789, high wind 39821, sandstorm 21436, snow flurry 4197); lens droplets; an options GUI.

**What AlwaysRain has that none of them do:** **not one rival calls `SetBlendMode` at all**, so nothing else in the survey can darken the sky. Dynamic Azeroth Weather parents its particles to `UIParent`, so its rain draws over the action bars; AlwaysRain parents to `WorldFrame`. Its "rain" is 200 white 2x20 rectangles moved in `OnUpdate`; AlwaysRain uses tiling sheets. Dynamic Weather ships 46 MB of uncompressed TGA. Nobody shifts time of day.

### One finding that undercuts everything

On the author's machine `weatherDensity` is `0` and `graphicsEnvironmentDetail` is `1`. At those values the client never draws Blizzard's real weather at all. He has therefore **never seen this client render real rain**, and the entire addon was built against an unrepresentative baseline. A `/rain density` command now reports and can raise both CVars. This matters to the research: a meaningful share of the addressable audience may simply have weather turned off, and the honest comparison between "our illusion" and "their real rain" has not yet been made side by side.

---

## What to research and answer

### 1. Legality and Terms of Service

- Locate and quote the **current** text of Blizzard's addon policy and the relevant clauses of the WoW Terms of Use and EULA. Note the policy's history and any revisions, since much of the community commentary online cites superseded versions.
- Assess each of these separately, because they are different legal questions: (a) shipping original synthesised art and audio; (b) referencing Blizzard's own assets by **FileDataID** at runtime so nothing is redistributed; (c) reading `C_Weather`; (d) an addon calling `SetCVar` on graphics settings on the user's behalf; (e) overlaying `WorldFrame` to alter the apparent look of the game world; (f) presenting a different time of day than the server reports.
- Is there any precedent of Blizzard acting against a purely visual overlay addon? Dynamic Weather has existed since 2020 with 20.7k downloads and advertises itself as ToS compliant; has that ever been challenged?
- Does the time-of-day feature cross any line that the rain feature does not? Consider whether presenting a false in-game time could be construed as obscuring information, in the way that combat-information addons have historically been restricted.
- Addons must be **free** under Blizzard's policy. Confirm the current state of that rule, what it permits regarding donations, Patreon, and the CurseForge reward programme, and whether any of that changes the analysis.
- Does the CMaNGOS research create any exposure? No code was copied, no server was run, and CMaNGOS is GPL-2.0, but the author wants this checked rather than assumed.
- Flag clearly anything that is genuinely uncertain rather than smoothing it over. Where you are reasoning rather than quoting a source, say so.

### 2. Whether and how to publish

- Size the actual demand. Is there a real audience for a permanent-weather addon, or is the audience for a **dynamic** weather addon that happens to include permanent as an option? Find evidence: forum threads, Reddit demand, download curves on the rivals, what people actually ask for.
- Dynamic Weather has 20.7k downloads and has been unmaintained since 2021 with a Cataclysm-era `.toc`. Is its audience stranded and reachable? Is "the maintained successor to Dynamic Weather" a stronger positioning than "a new rain addon"?
- Which client flavours matter most for this specific feature: retail, Classic Era, Classic Anniversary, Hardcore, Season of Discovery? Where is the weather-and-immersion audience actually concentrated? Note that the author develops against a Classic **beta** build, which has implications for which TOC interface numbers to ship and how to support multiple flavours from one package.
- CurseForge versus WoWInterface versus Wago versus GitHub releases: what does each cost in effort and give in reach in 2026? What is the current state of the CurseForge reward programme and does accepting it conflict with the free-addon rule?
- What does a WoW addon need to not look amateur on day one: packaging layout, TOC metadata and interface versions, a changelog, a licence file, localisation stubs, a CI pipeline that packages releases, screenshots and video. Identify the specific conventions and tooling the community expects, by name.
- Name the realistic failure modes. Addons that overlay the whole screen have a reputation problem around performance and around interfering with other UI. What would reviewers and commenters attack first?

### 3. Making it world class

This is the largest part of the answer. Be concrete and technical. Prefer specific API calls, specific numbers and specific implementation sketches over general advice. **Verify every WoW API you name actually exists**; two earlier LLM consultations on this project invented `GetCameraPitch()` and `C_Weather.GetWeatherInfo()`, both of which returned zero hits against the client binary while a control API returned hits. If you are not certain an API exists, say so explicitly and say how to check.

Cover at least:

- **Architecture.** The addon is one 694-line Lua file with hardcoded presets. What is the right shape for an engine where a weather type is data rather than code, so that snow, fog, sandstorm, ash and a blood moon are all table entries? What should the schema look like? Two prior consultations both named this as the single highest-value change; stress-test that.
- **Visual fidelity.** What screen-space techniques are actually reachable from the WoW addon API, as opposed to theoretically desirable? Blend modes, masks via `SetMask`, `SetRotation`, gradients, texture atlases, animation groups, `SetTexCoord` tricks, the `Model` widget and whether a model frame can be used as a particle source in a way a flat texture cannot. Be explicit about what is impossible: the addon cannot sample the rendered scene, so anything requiring the framebuffer as an input is out.
- **The depth problem.** The rain is a flat sheet. Occlusion by terrain and buildings is unreachable. How close can layering, parallax, per-layer blur and scale-with-distance get before diminishing returns? Is a fourth layer worth it? Is a model-frame layer worth it?
- **Lens droplets.** Dynamic Weather has 14. What is the right implementation: individual textures, an atlas with `SetTexCoord`, an animation group per droplet, or a single sheet with a shifting mask? How do you keep them from reading as dirt on the monitor?
- **Audio.** The addon currently plays a single looping bed plus thunder. What would a convincing soundscape need: layered beds crossfading on intensity, indoor muffling, a separate near-surface layer, thunder distance correlated with the flash, stereo movement. What are the hard limits of `PlaySoundFile` and `PlaySound` — no volume argument, no pan, no pitch — and what are the known workarounds?
- **Determinism and shared experience.** Evaluate the hash-the-zone-and-hour approach both rivals converged on. What is the right hash, the right bucket size, and how do you handle the transition between buckets so weather does not snap? Is there any value in `C_ChatInfo.SendAddonMessage` for a group to agree on weather, or does determinism make that unnecessary?
- **Interaction with real weather.** Now that `C_Weather.GetCurrentWeather()` is known to exist, what is the right behaviour when the server really is raining? Suppress ours entirely, blend, or use the real intensity to drive ours? What happens in the zones where Blizzard scripts weather for story reasons?
- **Performance.** What is the actual cost of a fullscreen MOD-blend quad plus three scrolling layers plus droplets, in terms the author can measure? How should he measure it — `GetFramerate`, the addon CPU profiler, `C_AddOnProfiler`? What is an acceptable budget, and what do the known-heavy addons do wrong?
- **The options GUI.** The lack of one was flagged as the biggest adoption blocker. What is the right framework in 2026: the Settings API, AceConfig, something else? What does the configuration surface need to contain, and what should be hidden behind an advanced section?
- **Accessibility and safety.** Screen-darkening and flashing effects. What are the real considerations around photosensitivity for the lightning flash, and what should the defaults and the opt-outs be?
- **The feature nobody else has.** Time-of-day shifting is unique to this addon in the survey. Is that the headline feature rather than the rain? What would a complete version of it look like: smooth interpolation, a sunrise and sunset ramp with warm colour, a moon-phase tint, per-zone overrides, a "golden hour forever" mode?
- **Ideas not on this list.** What is missing entirely from the author's thinking? What would an experienced addon author or a graphics programmer immediately say is the wrong approach or the obvious unexplored direction?

### Output

Structure the report as:

1. A one-paragraph verdict on each of the three questions.
2. Legality, with quoted policy text and per-concern assessment.
3. Publish-or-not, with the evidence for demand and a recommended platform and positioning.
4. A ranked improvement roadmap, each item carrying an effort estimate, the specific APIs involved, and the reason it earns its place in the ranking.
5. An explicit list of everything you could not verify, and how the author could verify it himself.

Cite sources with URLs throughout. Where community opinion conflicts with documentation, say which you are weighting and why.

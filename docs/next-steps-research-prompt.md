You are advising the developer of a free, open-source World of Warcraft addon, Comfy Rain, nine days before the launch it was built for. The goal is to make it the best addon in its niche: the one a player who wants a cozy, atmospheric WoW installs first and keeps. We need two things: a concrete plan for the days before and just after launch, and a researched roadmap for the audio and for new features that fit the same mood, the same look and the same settings window. Evidence over opinion, and a plan we can act on.

Everything under "What is true today" was checked by us on the date given. Treat it as fact unless you find a source that contradicts it, and if you do, say so explicitly and cite it. Everything under "What we want answered" is an open question, including anything we list as an idea.

## What is true today

### The product

- Name: Comfy Rain. Addon folder `ComfyRain`. CurseForge project 1756622, https://www.curseforge.com/wow/addons/comfy-rain. MIT licence, source on GitHub (LibruaryNFT/comfyrain). Published on CurseForge only.
- Runs on WoW Forever (launches 4 November 2026, client version 1.60.1) and on Retail (12.1.5). Not on the Classic Era, Mists of Pandaria Classic or Anniversary clients.
- What it does:
  - Rain or snow anywhere, four intensities each, drawn as a screen-space overlay: scrolling texture layers in front of the camera, with the frame dimmed behind them.
  - Lightning flashes with thunder in rain. Wind gusts that move the rain, the sound and the light together.
  - Fades down indoors. By default it hides its own overlay while the game's own rain or snow is falling, because Blizzard's weather is 3D and stops under roofs, so where it exists it is better.
  - Time of Day: a colour grade over the world. Modes are Off, My PC clock, Shift by hours and Fixed hour, plus a Strength slider. It is drawn on the world layer, beneath the interface.
  - A settings window with a minimap button, in three sections: Weather, Time of Day, Sound. Settings can be shared as one line of text. Six scene presets exist as slash commands. `/comfy bug` writes a one-line bug report.
- Art: every texture and the icon are drawn by Python scripts in the repository, from geometry and noise, not by AI image generators. The developer cares that it looks hand-made and native to WoW.
- Published state on 2026-10-24: one file, a 0.9.2-alpha preview tagged Forever only, 15 downloads. The first real release, v1.0.0, is planned for 4 November, when almost every install will happen.

### The audio as built

- Every sound is Blizzard's own, played by FileDataID from the player's installed game files, which redistributes nothing. The only bundled audio is a generated rain loop and thunder clip, used only if the game refuses a FileDataID.
- Rain: Blizzard's `Sound/ambience/Weather` loops RainLightLoop (538983, 20.000 s), RainMediumLoop (538981, 30.000 s) and RainHeavyLoop (538982, 25.000 s), two layered per intensity with timing and volume jitter. Snow uses SnowLight, SnowMedium and SnowHeavy. Thunder is ten recorded rumbles (`FX_TKIsle_MWThunderRumble`). Snow gets seven wind-gust one-shots instead of thunder.
- What our in-game probes established about the sound API:
  - `PlaySoundFile` has no loop flag and no volume argument. A loop is the clip relaunched shortly before it ends, using lengths measured from the files.
  - `C_Sound.PlaySoundWithOptions` with `volumeOverride` is the only gain control, and it is fixed at the moment a clip starts. The Classic clients lack it.
  - The sound-finished callback fires for SoundKits, not for FileDataIDs, so any sequencing runs on timers.
  - `MuteSoundFile` is keyed on the file, not the caller: muting a file also mutes our own playback of it.
  - Ambience-channel sound plays when the player has the game's music turned off.
  - The addon sandbox has no HTTP or other network access.

### What the screen can and cannot do

- Addons cannot set the sky, world fog, world lighting or weather. There is no skybox API, `C_Weather.GetCurrentWeather()` is read-only, and there is no depth test, so nothing an addon draws can sit behind terrain or buildings. We checked the Forever client binary on 2026-10-19.
- The `Gamma` CVar can be written by addon code. Tested in game on 2026-10-24 on Retail 12.1.5; not yet tested on Forever, whose binary carries the same CVar (range 0.3 to 2.8). Mean brightness of the street in a night scene in Stormwind, on a 0 to 255 scale: 51 at gamma 1.0, 6 at 0.4, 131 at 2.4. At 2.4 night reads as overcast day. It brightens the interface too, and it is the player's own graphics setting. We do not know whether a value written by an addon persists to the player's config file.
- The `weatherDensity` CVar scales how much of the server's weather is drawn. It cannot create weather.

### Sound assets we found but have not tested

These appear in the community listfile, by FileDataID and path. None has yet been confirmed to exist or play on the Forever or Retail clients.

- 539075 `AMB_CoastalRainy_Day01`, 539116 `AMB_CoastalRainy_Night01`
- 539064 `AMB_PlainsRainy_Day01`, 539026 `AMB_PlainsRainy_Night01`
- 539134 `AMB_ForestStormy_Night01`, 539106 `AMB_ForestStormyHeavy_Night01`, 539051 `AMB_ForestStormyEerie_Night01`, 539101 `AMB_CoastalStormy_Night01`
- 596024 and 1402221 `Worgen_Rain_Drips_01` and `_02`; 614975 `FX_Water_Drip_1` (one of ten); 645853 `FX_Cave_Water_Dripping_Loop_01`
- 1575952 to 1575954 `AMB_WALLA_*_TAVERN_MEDIUM` (tavern chatter: Alliance, Horde, mixed)
- 4883319 onward: sixteen `10.0_AMB_Lightning_Thunder_Strike` files
- 538986 to 538988 `SandStorm` Heavy, Medium and Light

### The field, observed on CurseForge on 2026-10-24

- **Weather** (keyboardturner), 2.9K downloads, Forever and Retail: muffled indoor weather sounds, umbrella and parasol reminders, freefall wind, a rain, snow and sandstorm screen tint, a weather almanac.
- **Cinematic** (SapoAC), 8.6K downloads, Forever and other clients: screen tints with a vignette, a time-of-day tint "from moonlit blue to dawn pink to golden hour", a warm glow in inns.
- **Weather Forever Seasons** (Allenrg13), 102 downloads, Forever: rain, storms, lightning, snow, falling leaves, weather sounds, wet and frosty screen effects, splashes.
- **Azeroth Alive** (ignazdesantis), 19 downloads, Retail only: weather, adaptive lighting, biome soundscapes, shelter acoustics.
- **Forever Ambient Music Extended** (kirillburton), 133 downloads when seen on 2026-10-13, Forever: 408 extra Blizzard music tracks chosen by zone, music channel only, no settings window, no ambience.
- Blizzard announced "Increased Weather Effects" for Forever on 2026-09-23: https://us.forums.blizzard.com/en/wow/t/increased-weather-effects/2359491
- CurseForge's website search matches words in a project's summary but not in its description. Our positive controls: "weather sounds" returns Comfy Rain, and "accessory reminders" returns Weather, in both cases words that appear only in the summary.

### Our plans so far

- Before launch: tag v1.0.0 on 4 November. Push a beta tag now, so the page lists Retail as well as Forever. Re-shoot the gallery, because the three images on the page show art from before 22 October.
- After launch, in this order: micro-sequence the sound beds instead of looping single files; music as an opt-in mode that never reaches a player who has music off; fog, then ash and embers; a fade when underwater.

## What we want answered

1. **Launch: the next nine days and the first two weeks.** What actually drives installs for a new addon in a new game mode's launch week? Where do Forever players find addons (the CurseForge app, Wago, WoWInterface, r/wowforever, Discord servers, YouTube), what are each venue's rules on self-promotion, and when should each post go out relative to launch? What should the gallery, the summary and a player's first minute in game be, given that search reads only the summary? Give a dated checklist from 26 October to 18 November.
2. **Rain soundtracks.** Do players want a choice of rain soundscapes (coastal, plains, forest storm), and how do the best ambient products (myNoise, A Soft Murmur, Rainy Mood, Noisli, Tide and similar) design that choice? Blizzard's zone-ambience loops also carry birds, waves or wind: how should they be layered with the plain weather loops without doubling up? How should loudness be matched across files when gain is fixed at play time?
3. **The audio engine.** What does a world-class ambient sequencer look like within the API limits above: micro-sequencing, crossfades, hiding the loop, randomised one-shots (drips, distant thunder, gusts), different treatment under a roof, a cozy inn scene? Cite how commercial ambient products and game-audio middleware handle each, then turn it into a design we can build with timers and FileDataIDs.
4. **Higher fidelity.** Can bundled recordings sound audibly better than Blizzard's files? What do CurseForge's rules say about bundled audio, which licences are safe (CC0, CC BY), where are good sources, and how large an addon download will players accept?
5. **New features that fit.** Rank candidates that share the cozy, atmospheric mood, the same window and the same hand-drawn look, and that can be built from screen-space overlays and Blizzard's sounds. For example: fog, ash and embers, falling leaves, sandstorm, droplets on the lens, fireflies, gamma-based daylight, scene schedules, an opt-in music mode from Blizzard's library. Add any we have missed. For each give the evidence of demand, which competitor already does it and how well, the effort, and whether it still matters once Blizzard ships more weather.
6. **Gamma, done safely.** If Time of Day uses gamma to brighten night, how should an addon put the player's own value back on logout, on disable, on an error and on uninstall? How have players reacted to gamma addons before (DayNight, Nightlight, any others)? Has Blizzard ever restricted gamma for addons?
7. **Where we lose.** Against Weather and Cinematic specifically: what would make a player choose one of them over us, and what would make one of their users switch?

## How to answer

- Lead with a verdict of at most five sentences: the three things to do before 4 November, and the one feature to build first after launch.
- Then one roadmap table: item, phase (before launch, launch week, first month, later), effort, evidence, risk.
- Then the audio design as a short spec: layers, timing and mixing, using the FileDataIDs above where they fit, each marked untested.
- Then a ranking table for question 5.
- Cite every factual claim with a link and the date you saw it. Download counts are installs; upvotes and comments are wants. Say which one you are reporting.
- If a search finds nothing, say what positive control you ran first.
- Do not recommend anything that needs the skybox, world lighting, 3D rendering, network access, a server change, or bundling copyrighted audio.
- End with a list of what you could not verify.

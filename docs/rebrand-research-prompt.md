You are advising the developer of a free, open-source World of Warcraft addon that is already published under one name and is now being second-guessed. The question is whether to rename, rebrand or reorganise it so it is not boxed in as "a rain addon", given that players seem to be asking loudest for something next to it: control over day and night. Whatever we choose has to stay worth installing after Blizzard fixes the things players are complaining about, so a name or structure built on a gap Blizzard could close in one patch is the wrong answer. We need a decision we can act on before 4 November 2026, backed by evidence, not a branding essay.

Everything under "What is true today" was checked by us on the date given. Treat it as fact unless you find a source that contradicts it, and if you do, say so explicitly and cite it. Everything under "What we want answered" is an open question, not a premise.

## What is true today

### The product

- Name: Comfy Rain. Addon folder `ComfyRain`, saved variables `ComfyRainDB`. Slash commands `/comfy` and `/rain` (kept permanently); `/comfyrain` and `/comfyui` open the settings window.
- Runs on WoW Forever (launches 4 November 2026, client version 1.60.1) and on Retail (12.1.5). Not on the Classic Era, Mists of Pandaria Classic or Anniversary clients.
- What it does:
  - Rain or snow anywhere, four intensities each, drawn as a screen-space overlay: scrolling texture layers in front of the camera, with the frame dimmed behind them.
  - Weather audio built from the game's own sound files, with wind gusts and distant thunder.
  - Fades down indoors. By default it hides its own overlay while the game's own rain or snow is falling, because Blizzard's rain is 3D and stops under roofs and bridges, so where the real thing exists it is better. The design already assumes Blizzard's version wins wherever Blizzard provides one.
  - Time of Day: a colour grade over the whole screen. Modes are Off, My PC clock, Shift by hours and Fixed hour, plus a Strength slider. It is its own layer and works with the rain switched off.
  - A settings window (with a minimap button) whose sections are, in order: Weather, Time of Day, Sound. Settings can be shared as one line of text; six scene presets exist as slash commands.
- First-install defaults: rain on at normal intensity, sound on, Time of Day off.
- How it is positioned today: the CurseForge summary and the in-game addon-list description mention rain, snow, sound, wind and thunder, and do not mention Time of Day. The CurseForge description lists Time of Day as the fourth of seven feature bullets. The planned gallery gives it one image of seven.

### What the renderer can and cannot do

This is the constraint that matters most. Please do not recommend anything that depends on crossing it.

- Addons cannot set the sky. We searched the Forever client binary (build 1.60.1.70425) for a skybox setter (`SetSkyboxModel`, `C_Skybox`) and for world fog, world light and gamma setters: none exist. Skybox data exists only as client database records, not as an API. There is no depth test, so nothing an addon draws can sit behind terrain or buildings.
- Weather has no setter either. `C_Weather.GetCurrentWeather()` is read-only. Functions such as `ApplyTimeOfDay` and `ApplyWeather` exist in the binary, but they sit in the server-driven scene-script binding table, not the addon API.
- So Time of Day does not change the in-game time, the sun, the moon, the stars, the clouds or the world lighting. It multiplies the finished frame by a colour, graded by the ratio between the hour the player wants and the hour the realm is showing.
- **Darkening works; brightening barely does.** Day to dusk or night is a multiply and looks right. Night to day can only add a lift, capped at 0.13 on a 0 to 1 scale, which raises the black level without restoring contrast, and the sky keeps its stars and has no sun. We treat night to day as a hard limit of the method, not a tuning problem.
- In Classic-era clients the day/night cycle runs 1:1 with real time on the realm's clock. Our source for that is the CMaNGOS server reimplementation, which is reverse-engineered, not Blizzard's code.

### Published state, observed 2026-10-24

- CurseForge project 1756622, approved 20 October 2026: https://www.curseforge.com/wow/addons/comfy-rain
- Title "Comfy Rain". Main category Audio & Video; additional categories Roleplay and Artwork.
- Summary: "Makes it rain or snow anywhere in the game, with weather sounds, wind and thunder, all set from a settings panel or the minimap button."
- One file, a 0.9.2-alpha preview tagged Forever only. 15 downloads in total.
- Source on GitHub (LibruaryNFT/comfyrain), MIT licence.
- The first real release, v1.0.0, is planned for 4 November, the day Forever launches. That is when almost every install will happen.

### Name history

The addon has been renamed twice, both times before any public release.

1. **AlwaysRain.** Dropped because it names one weather type and fought a roadmap that already had snow and time of day.
2. **Duskfall**, chosen 2026-10-14. Our reasoning then: the brand name carries no search load, the subtitle does, so the brand only has to be easy to say, hear, spell and remember. Rejected on the way: Gloaming (nobody knows the word), Cozy Azeroth, and bare Dusk (collides with the 2018 game DUSK).
3. **Comfy Rain**, chosen 2026-10-19. Our reasoning then: CurseForge search indexes the title, nobody searches "duskfall", and "rain" is the word a player actually types. "Comfy" signals the category: cozy ambience, not a combat tool.

Those two reasonings contradict each other on whether the title carries search. We never settled it with evidence.

Each rename moved the folder, the saved variables and the slash commands. The addon still migrates settings from `DuskfallDB` and `AlwaysRainDB`, and keeps `/rain`, so another rename is routine work on our side. Our own naming rule: no name containing the substring "ever".

### The demand we have seen, and what each source actually asks for

- **r/wowforever**, "The biggest easy-win Blizzard is currently NOT leveraging for WoW Forever is..... Skyboxes" (u/zambabamba). About 516 upvotes when we saw it on 2026-10-18; top comment 184. This asks for better sky art: Retail's painted skyboxes and volumetric moving clouds. It is not about the clock, and an addon cannot touch the skybox.
  https://www.reddit.com/r/wowforever/comments/1x8tnda/the_biggest_easywin_blizzard_is_currently_not/
- **Blizzard forums, Forever General Discussion**, "WoW Forever adds dynamic lighting, but OCE is stuck in perpetual midnight. Fix the day/night cycle!", posted 2026-09-28. 71 likes on the opening post, at least 19 replies. Top reply (13 likes): "Day/night cycle attached to your local time would be great." Several replies ask for a client-side toggle.
  https://us.forums.blizzard.com/en/wow/t/wow-forever-adds-dynamic-lighting-but-oce-is-stuck-in-perpetual-midnight-fix-the-daynight-cycle/2365303
- **GitHub, ClassicWoWCommunity/forever-bugs #424**, "Oceanic layers run on North American world time: OCE players see night for almost their entire play session". Opened 2026-10-22, open, 10 thumbs-up, 11 comments. Reports that during the 21 October stress test Oceanic layers ran on US Pacific time, so an Australian playing 19:00 to 23:00 local sees roughly 01:00 to 05:00 in game. Asks for a per-region clock, a shorter cycle, or a client-side offset. It also claims, and we have not verified, that the forum thread above is one of the most-liked in Forever General Discussion and that the same complaint has been open on the Retail Oceanic forum since 2016.
  https://github.com/ClassicWoWCommunity/forever-bugs/issues/424

**The uncomfortable part.** The loudest clock complaint comes from Australians who want daylight in their evening. That is the brightening direction, the one our renderer cannot really deliver. What the addon does well is the other direction: holding dusk or night, or matching a clock that is darker than the realm's. The developer's instinct is that day/night is "the big ask". We want that tested, not confirmed.

## What we want answered

1. **How big is the day/night demand, split by what is being asked?** Separate at least: (a) better sky art; (b) the clock not matching the player's time zone, mostly Oceania; (c) wanting a mood, such as permanent dusk or night, cozy evenings, or roleplay lighting. Find every thread you can on r/wowforever, r/classicwow, r/wow, the Blizzard forums (Oceanic included), forever-bugs and addon comment sections, and report each with its score and date. Measure demand for on-demand rain and snow the same way, so the two can be compared.
2. **Which of those can a screen-space colour grade honestly satisfy?** Check whether anyone has ever changed the in-game time of day or the skybox client-side, on Classic or Retail, by any allowed route we missed: a CVar, a console command, an addon API. If you think our "cannot" is wrong, show the API or the addon that does it. Find any existing addon marketed for day/night or time-of-day lighting on CurseForge, Wago or WoWInterface, with its downloads and how users reacted to a filter-style fake. Also say whether tools outside the game (ReShade presets and similar) already serve this audience, and what Blizzard's stated position on them is.
3. **Does the name even matter for being found?** Establish what CurseForge's site search, the CurseForge app and WowUp or Wago actually index: the title only, or the summary, description and tags too. Prove the method works with a positive control: search a word that appears only in a known addon's summary and check whether that addon is returned. This decides whether "Comfy Rain" hides a time-of-day feature or not.
4. **What does a rename cost after publication?** Can a CurseForge project's display name and slug be changed, and what happens to the old URL, the project ID and existing installs in the CurseForge app and WowUp? If the addon folder name changes, do those clients update in place, or leave the old folder behind as a second addon? Find real WoW addons that were renamed after publishing and what happened to them. Compare the cost now (15 downloads, 11 days before launch) with the cost after launch.
5. **Which structure fits, if any?** Evaluate at least these:
   - (A) Keep the name; rebalance the page, the gallery and the settings window so Time of Day stands as an equal feature.
   - (B) Rename to an umbrella that covers weather, light and sound.
   - (C) Keep Comfy Rain and publish a second, small time-of-day addon that shares code.
   - (D) Something we have not thought of.

   For each, give the effect on discovery, the cost, how reversible it is, and the evidence. An earlier round of research concluded "one addon, not two", but that question was weather visuals against audio, not weather against light.
6. **If a new name wins, propose a shortlist of at most five.** Each must be understood and spelled correctly after hearing it once. It must not name a single weather type, and must not promise something we cannot deliver (no "day" or "sun"). It must not contain "ever", and must not collide with an existing WoW addon. Check each against CurseForge search and say which control you ran.
7. **How do we describe Time of Day without overpromising?** Players asked for real skyboxes and real daylight. Give wording that sells what it actually does (a dusk or night hold, a local-clock grade) and heads off the "it is just a filter" comment. Say whether leading with it is a reputational risk.
8. **Is the addon still worth installing after Blizzard fixes things?** Assume Blizzard keeps improving Forever after launch. For each fix below, say how likely it is, what signals would show it is coming, and what of our addon is still useful once it ships:
   - a per-region clock for Oceania, a shorter day/night cycle, or a client-side time-of-day option (forever-bugs #424 is open);
   - updated skyboxes or volumetric clouds;
   - more weather, more often, in more zones, or any player-facing weather option.

   Then name the part of the addon that survives all three, if any part does. Tell us whether the name and structure you recommend rest on that part, or on a gap Blizzard could close.

## How to answer

- Lead with a verdict of at most five sentences: rename or not, restructure or not, and what to do before 4 November.
- Then one table of the options from question 5, with cost, reversibility, evidence, and what is left of each option after the fixes in question 8.
- Every name in question 6 must also say what it still means after those fixes. Do not recommend a name or structure whose main selling point is a gap Blizzard could close in a patch.
- Then a demand table: source, link, date, score, what is asked (a, b or c), and whether a screen colour grade can deliver it.
- Cite every factual claim with a link and the date you saw it. Upvotes on a request are evidence of a want, not of installs; say which one you are reporting.
- If a search finds nothing, say what positive control you ran first. "I found no addon that does X" is only useful if the same method finds addons that do Y.
- Do not recommend anything that needs the skybox, world lighting, 3D rendering or a server change, and do not tell us to rewrite the renderer.
- End with a list of what you could not verify.

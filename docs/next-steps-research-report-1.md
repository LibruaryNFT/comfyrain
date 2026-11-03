# Comfy Rain — nine-day launch plan and post-launch roadmap

Deep research report 1, received 2026-10-26, in answer to `docs/next-steps-research-prompt.md`. Verbatim. What was checked against it is in RESUME.md, under "2026-10-26: the next-steps reports, checked".

## Verdict

Do three things before 4 November, and none of them are code: (1) rewrite the summary so it carries the words players actually type — "cozy", "ambience", "rain sounds", "time of day", "roleplay" — because CurseForge search matches the summary and nothing else (confirmed below); (2) re-shoot the gallery as five in-game screenshots plus one 20–30 s video with sound, because the three images on the page are pre-22-October and the page currently has no proof of the audio, which is your only real differentiator; (3) ship the beta tag this week, not to "list Retail" but because Forever players are actively hunting the Forever flavour filter right now and the Kaivax weather thread has 9.6k views and 807 likes with unanswered asks for fog and storm wind. Then, after launch, build **music mode** first — HousingMusic has 82.5K installs and Forever Ambient Music Extended grew from 133 to 364 downloads in thirteen days, and FAME has no settings window at all, which is exactly the gap your window fills. Your competitive wedge is one sentence: Weather muffles you indoors and Cinematic tints the screen, but neither makes it actually rain in a zone that never rains, and both of them are one `/comfy` away from being complemented rather than replaced.

---

## One correction to "what is true today"

**`C_Sound.PlaySoundWithOptions` is present on Forever 1.60.1**, not just Retail. Warcraft Wiki tags the page with the Forever client (1.60.1, build 69913) alongside standard 12.1.5, and links Blizzard's own `SoundDocumentation.lua` in the Forever UI source. Your note that "the Classic clients lack it" is consistent — but Forever is not Classic, and this means `volumeOverride` (added 12.1.0) is available on both of your target clients. Source: https://warcraft.wiki.gg/wiki/API:C_Sound.PlaySoundWithOptions (seen 2026-10-26).

Also worth knowing, from the same page: the argument is `soundKitID`, **not** a FileDataID. See the audio spec below — this changes how you get per-file gain.

Two minor state updates: the CurseForge member card now reads **16** downloads (was 15 on 2026-10-24), and the project page lists the gallery as four items but renders three images. Source: https://www.curseforge.com/wow/addons/comfy-rain (seen 2026-10-26).

---

## Roadmap

| # | Item | Phase | Effort | Evidence | Risk |
|---|---|---|---|---|---|
| 1 | Rewrite summary to carry searched words; keep it one sentence per CF's own guide ("Share what your project does, not who created it") | 26–28 Oct | 30 min | CF search reads summary only — positive control below. CF guide: https://support.curseforge.com/support/solutions/articles/9000199552 (seen 2026-10-26) | Keyword stuffing trips the "avoid generic terms" rule |
| 2 | Re-shoot gallery: 5 screenshots + 1 video with audio, UI hidden, night rain in a town, snow in Dun Morogh, the settings window, indoor fade | 26–29 Oct | 1 day | CF guide says "in-game screenshots with the mod enabled"; Cinematic's page leads with a YouTube embed — https://www.curseforge.com/wow/addons/cinematic (seen 2026-10-26) | Video needs audio to sell audio; a silent one sells nothing |
| 3 | Push beta tag with `ComfyRain_Forever.toc` | 27 Oct | 1 h | `forever` is now a valid TOC game type, alias for `camelot`, added 1.60.1 (70291) 7 Oct 2026 — https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes (seen 2026-10-26) | CF "Fair Play" bans re-uploads without changes; a beta→release pair is legitimate |
| 4 | Post in the Kaivax weather thread, replying to the unanswered fog/wind asks | 28 Oct | 45 min | Thread has 9.6k views, 807 likes, 214 posts; Liger asks "is there going to be morning fog? Or wind effects for strong storms?" — https://us.forums.blizzard.com/en/wow/t/increased-weather-effects/2359491 (seen 2026-10-26) | Forum self-promo rules not verified; keep it a reply, not an ad |
| 5 | List on addons.wago.io as a second channel | 29–30 Oct | 2 h | Wago hosts addons with an Audio & Video category and its own app — https://addons.wago.io/ (seen 2026-10-26) | Wago's front page is dominated by million-download addons; expect near-zero discovery |
| 6 | List on WoWInterface in RolePlay/Music Mods | 30–31 Oct | 2 h | That category holds 267 files and WoWInterface already carries Forever compilations — https://www.wowinterface.com/downloads/cat114.html (seen 2026-10-26) | No auto-installer; manual downloads only |
| 7 | Add a "plays alongside Cinematic and Weather" note to the description | 31 Oct | 20 min | Azeroth Alive warns "Running another full-screen weather renderer at the same time is not recommended" — https://www.curseforge.com/wow/addons/azeroth-alive (seen 2026-10-26) | You must actually make it true; add a one-key kill switch |
| 8 | Tag v1.0.0, post release note in description, log in to reply to every comment for 48 h | 4–6 Nov | 1 day | Nearly every install happens on launch day; Weather's author has 9.7M downloads across 37 projects, i.e. a comment reply is a retention lever | Release-day CF moderation delays are documented as current — support portal banner, 15 Sep 2026 |
| 9 | Ship the Shelter update: muffled bed, tavern walla, cave drip | 4–10 Nov | 3 days | Weather already ships "muffled, ambient weather sounds while you're indoors" — https://www.curseforge.com/wow/addons/weather (seen 2026-10-26) | Doubling with Blizzard's own zone ambience; see mixing rules |
| 10 | Ship music mode, opt-in, never on the Music channel | 11 Nov–4 Dec | 1–2 weeks | HousingMusic 82.5K installs (25 Oct 2026); FAME 133→364 downloads, 13 Oct→26 Oct | Conflicts with music addons; Cinematic already fades music |
| 11 | Fog band, then ash and embers | Dec | 3 days | Liger's fog ask in the Blizzard thread; Azeroth Alive ships "fog, wind, dust, ash, embers" | Blizzard ships fog; yours is a screen band, theirs is world fog |
| 12 | Gamma-based Time of Day using a temp CVar | Dec | 2 days | `C_CVar.SetTempCVar` added in 1.60.1, 2 Oct 2026 — Patch 1.60.1/API_changes | Highest-risk item; see the gamma section |

**What not to do:** don't spend launch week on micro-sequencing. It is the least visible improvement. Ship it after music.

---

## Where Forever players actually are

You asked where they find addons and when to post. What I could establish:

- **CurseForge app — the only channel that matters.** Every competitor in the niche is there and nowhere else that auto-installs. Weather 2.9K installs, Cinematic 8.6K→9.0K, Dynamic Weather 20.8K, Weather Forever Seasons 106, Azeroth Alive 27 (all https://www.curseforge.com/wow/search?class=addons&search=weather, seen 2026-10-26). Forever is a **flavour filter** on CurseForge search, so a Forever-tagged addon competes in a small, high-intent pool. Positive control: searching "ambient" returned exactly 9 projects, all of which contain "ambient" in the summary — confirming search reads the summary and not the description, and confirming that "weather sounds" and "accessory reminders" match as you found.
- **Wago Addons** (addons.wago.io) — exists, has an Audio & Video category and its own app. Low expected yield.
- **WoWInterface** — has a live RolePlay/Music Mods category and Forever compilations. No auto-installer.
- **Blizzard Forever forums** — the weather thread is your single best pre-launch venue: 9.6k views, 807 likes, and the top reply asks for exactly the two features you have not built (fog, storm wind).
- **Discord** — WoWUIDev (https://discord.gg/txUg39Vhc6, linked from the wiki nav), the CurseForge Authors server (https://discord.gg/jeK7YFPVPA, from the support portal), Cinematic's server (https://discord.gg/vSW5VGbxV), and the HousingMusic author's server (https://discord.gg/tA4rrmjPp8).
- **YouTube** — Cinematic leads its page with an embed. A 25-second video of rain with sound, in a zone that never rains, is your highest-conversion asset and it costs one afternoon.
- **Reddit r/wowforever** — I could not verify it. Both `www.reddit.com/r/wowforever/` and `old.reddit.com/r/wowforever/about/rules` returned HTTP 403 from the scraper. **Treat Reddit rules as unverified.**

Post order: summary and gallery first (26–28 Oct), beta tag (27 Oct), forum reply (28 Oct), Wago and WoWInterface (29–31 Oct), v1.0.0 and a comments sweep (4–6 Nov), then a quiet re-post in the forum thread when Blizzard actually ships increased weather to live — that is the moment a weather addon is searched for by name.

**Player's first minute:** minimap button appears; `/comfy` toggles; the window previews live with no Apply. Add one first-run toast the first time weather turns on that says the three commands worth knowing and nothing else.

---

## Audio design spec

Every FileDataID below is marked **[untested]** unless I verified it. Verified against the community listfile via https://wago.tools/files (seen 2026-10-26): 538983, 1575952, 4883319.

### The one API fact that changes the design

`C_Sound.PlaySoundWithOptions` takes a **soundKitID**, not a FileDataID. To get gain control on a FileDataID you must bake a `fdid → soundKitID` map from `SoundKitEntry.db2` (https://wago.tools/db2/soundkitentry) into the addon, and play by kit with `volumeOverride`. Fall back to `PlaySoundFile` (no gain) when a kit is unknown. Bonus from the same signature: `runFinishCallback` plus the returned `soundHandle` gives you a **real finish callback for kits** — which is exactly the sequencing hook you found missing for FileDataIDs. Use kits where you need either gain or a finish callback; use `PlaySoundFile` where you need neither.

Also: `MuteSoundFile` is file-keyed, so muting Blizzard's weather loop mutes your copy too. Don't mute — pick files and bands that complement.

### Layers

One file per spectral band, never two broadband beds at once.

**Layer A — rain bed.** RainLightLoop 538983 (20.000 s), RainMediumLoop 538981 (30.000 s), RainHeavyLoop 538982 (25.000 s), on the `Ambience` channel (ambience plays with music off; ambience volume defaults to 0.6).

**Layer B — texture.** AMB_CoastalRainy_Day01 539075 / _Night01 539116; AMB_PlainsRainy_Day01 539064 / _Night01 539026; AMB_ForestStormy_Night01 539134, _Heavy 539106, _Eerie 539051; AMB_CoastalStormy_Night01 539101. All **[untested]**. These carry birds, waves and wind, so run them **under** the plain bed at low gain, and where you use one, drop the plain bed one intensity step so the top end doesn't double.

**Layer C — one-shots.** Thunder: the ten `FX_TKIsle_MWThunderRumble` for distant, and 4883319 onward (sixteen `10.0_AMB_Lightning_Thunder_Strike` files, path `sound/emitters/nature/storm/`) for close strikes — 4883319 **verified**. Snow gusts: the seven existing gust one-shots. Drips, for shelter: FX_Water_Drip_1 614975 (one of ten), Worgen_Rain_Drips_01/02 596024 and 1402221, and FX_Cave_Water_Dripping_Loop_01 645853 for caves — all **[untested]**.

**Layer D — shelter.** AMB_WALLA_ALLIANCE_TAVERN_MEDIUM 1575952 **verified**, with 1575953/1575954 (Horde, mixed) **[untested]**.

**Sandstorm.** SandStorm Heavy/Medium/Light 538986–538988 **[untested]**.

### Timing

- Bed relaunch at `length − 0.9 s`, with ±0.4 s jitter, so the two beds de-sync and the seam lands somewhere different each cycle.
- Crossfade over 2.1 s as a three-step stair, because gain is fixed at launch: outgoing 1.0 → 0.45 → 0.0 and incoming 0.15 → 0.55 → 1.0, 0.7 s per step, each step a fresh launch at that `volumeOverride`.
- Thunder 3–8 s after the flash. Gusts every 12–35 s. Indoor drips every 4–15 s.
- Suspend all relaunches while `PLAYER_REGEN_DISABLED` is up. No combat log parsing needed.

### Mixing and loudness

Measure every file **once, offline**, as LUFS or RMS, store the table in the addon, and apply `volumeOverride = clamp(bakedGain[fdid] × userSlider)` at launch. You cannot measure at runtime and you have no network, so the table is the whole answer. Target −18 LUFS for beds, −24 for one-shots.

### Shelter and inn

Under a roof: bed drops one intensity step, high-frequency layer drops out, cave drip 645853 fades in, and in an inn the walla comes up. That is a four-line state machine and it is what Weather is currently beating you on.

### Rain "soundscapes", designed the way the industry does it

Important finding: **no ambient product sells "coastal rain" versus "forest rain" as rain variants.** Rainy Mood is one rain plus thunder (https://rainymood.com/, seen 2026-10-26). A Soft Murmur offers ten fixed layers — Rain, Thunder, Waves, Wind, Fire, Birds, Crickets, Coffee shop, Singing Bowl, White noise — each with its own slider, plus a "Meander" mode that gently and randomly drifts every non-silent layer's volume (https://asoftmurmur.com/, seen 2026-10-26). Noisli offers sixteen sounds and five curated playlists including one literally named "Random" (https://noisli.com/, seen 2026-10-26). myNoise organises by *use case* — Focus, Sleep, Tinnitus, ADHD, "Background Sounds for Game Masters" — with per-track sliders and spectral shaping (https://mynoise.net/, seen 2026-10-26).

So: **don't ship three rain variants. Ship three textures plus a Meander.** Rain is one slider; Coastal, Plains and Forest are the *other* slider. That is four controls, it matches how every successful product in the category is built, and it sidesteps the doubling problem entirely because the player chooses the band. Steal "Meander" from A Soft Murmur by name and in spirit — it is your anti-loop feature and it is three lines of timer code.

---

## Feature ranking

Ranked by demand evidence, then by whether it still matters after Blizzard ships more weather.

| Rank | Feature | Demand evidence | Who does it, and how well | Effort | Survives Blizzard's weather? |
|---|---|---|---|---|---|
| 1 | **Opt-in music mode** from Blizzard's library | HousingMusic 82.5K installs, 21 comments (25 Oct 2026); FAME 133→364 downloads in 13 days (13→26 Oct 2026); Housing Room Ambience 178 (11 Oct 2026) | FAME: huge library, **no settings window, no ambience** — the gap is yours | 1–2 wks | Yes, independent of weather |
| 2 | **Fog / horizon mist** | Top reply in the Blizzard weather thread asks for "morning fog" | Azeroth Alive ships "fog… mist"; Cinematic does not | 3 days | Yes — yours is a screen band, theirs is world fog |
| 3 | **Gamma daylight** | DayNight and Nightlight both exist and both use gamma; neither does time-of-day colour grading | Nobody in the niche combines gamma with a grade | 2 days | Yes |
| 4 | **Scene schedules** | Cinematic ships time-of-day; Weather ships a day/night minimap icon | Cinematic, well, but as a camera side-effect | 1 day | Yes |
| 5 | **Ash and embers** | Azeroth Alive lists ash, embers, motes as core | Azeroth Alive, Retail only, 27 installs | 2 days | Yes |
| 6 | **Falling leaves** | Weather Forever Seasons ships "seasonal falling leaves" | Weather Forever Seasons, 106 installs | 1 day | Yes |
| 7 | **Underwater fade** | Azeroth Alive ships "underwater" acoustics and shelter fade | Azeroth Alive, Retail only | 1 day | Yes |
| 8 | **Sandstorm** | Weather ships sandstorm tint + sounds; SandStorm files already exist | Weather, well | 1 day | Yes |
| 9 | **Droplets on the lens** | Weakest direct evidence; Weather Forever Seasons ships "water splashes" | Nobody does a lens overlay | 3 days | Yes |
| 10 | **Footsteps in rain and snow** | Liger asks it verbatim in the Blizzard thread | Nobody in the niche | 1 wk | Yes |
| 11 | **Fireflies** | Weakest of all | Azeroth Alive has "motes" | 2 days | Yes |

Build 1, then 2. Items 5–8 are one shared particle system wearing four textures — do them together or not at all.

---

## Gamma, done safely

The clean primitive landed on 2 October 2026: **`C_CVar.SetTempCVar` and `C_CVar.RemoveTempCVar`** were added in 1.60.1 (source: https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes, seen 2026-10-26). A temp CVar is the client's own to restore, which means you do not have to put the player's value back on logout at all.

- **Normal exit / logout / reload:** the temp CVar dies with the session. Nothing to do.
- **Disable or error:** wrap the write in `pcall` and call `C_CVar.RemoveTempCVar("gamma")` in a `PLAYER_LOGOUT` handler and in your own disable path.
- **Uninstall:** the temp CVar is gone before the next session loads, so a deleted addon cannot strand the value.
- **Before you write, store the player's value once** and re-apply it through `SetTempCVar` rather than writing the real CVar, so `/console` shows their value and not yours.
- **Range:** the Forever binary carries gamma 0.3–2.8, same as Retail. Your measured curve (51 → 6 → 131 on a 0–255 street at 1.0 / 0.4 / 2.4) says 2.4 is unusable as "night" — cap the brightening direction near 1.6 and the darkening near 0.55.
- **Prior art, and how it went:** DayNight "dynamically adjusts in-game gamma to darken the game during night cycles", adjusted once per minute, and its description carries the scars — it requires fullscreen mode, requires desktop-gamma disabled, and originally told users to type `/run SetGamma(0)` on uninstall (https://www.curseforge.com/wow/addons/daynight, seen 2026-10-26). Nightlight is a manual slider and explicitly "works in both classic and retail" (https://www.curseforge.com/wow/addons/nightlight, seen 2026-10-26). Neither shows any sign Blizzard ever restricted it.
- **Do not write gamma more than once a minute**, matching DayNight. A per-frame gamma write will flicker.

---

## Where you lose, and how you win

**Against Weather (2.9K installs, 37 projects, 9.7M downloads, updated 20 Oct 2026, 2 comments).** A player picks Weather because it owns indoors, owns the RP props — umbrella and parasol reminders, TRP3 "in character" gating — and owns the almanac, which is a collection mechanic and therefore retention. You lose on every one of those today. Their users switch to you for one reason: **you make weather exist where the server won't give it.** Say that in the first line of the summary and nowhere else. Their weakness: 2 comments on 2.9K installs means the author is not talking to users. Yours will.

**Against Cinematic (8.6K→9.0K installs, 85 comments, a Discord, 10 languages, a YouTube trailer, profiles).** A player picks Cinematic for the camera and stays for the tint. It ships time-of-day and weather tint but **not one drop of actual rain** — weather in Cinematic greys the scene. Their users switch the moment they see your rain falling in a zone that has none. Their weakness is scope: 20 settings pages is a lot of surface for a player who just wants it to rain. Yours is one window and three sections. Say so.

**The switching sentence:** "Cinematic and Weather change how the world looks. Comfy Rain makes it rain." Then name them both in your description as complements, because Azeroth Alive is out there telling people not to run two weather renderers, and you want to be the one they keep.

---

## What I could not verify

1. **Reddit, entirely.** `www.reddit.com/r/wowforever/`, `.../about/rules` and `.../wowforever.json` all returned 403 from the scraper on 2026-10-26. Subscriber count, rules and self-promotion policy are unknown. Positive control: I tried three different URL forms, all failed, so it is the scraper and not the URL.
2. **The Forever launch date of 4 November 2026.** Not confirmed from a Blizzard page. Circumstantial: wago.tools lists a `wowf` / `_forever_` branch at 1.60.1.70532 found 2026-10-21, and a `wow_classic_beta` branch at the identical build — consistent with a pre-launch beta (https://wago.tools/, seen 2026-10-26).
3. **FileDataIDs 539075, 539116, 539064, 539026, 539134, 539106, 539051, 539101, 596024, 1402221, 614975, 645853, 538986–538988, 4883320–4883334.** Not individually queried. Only 538983, 1575952 and 4883319 are confirmed present in the listfile.
4. **Whether a gamma value written by an addon persists to the player's config file.** Not tested, and now partly moot given temp CVars.
5. **CurseForge file size limits.** The Project Submission Guide and the Moderation Policies do not state a number. What they do state, verbatim: "Projects may include music only if the author owns it or has redistribution rights. Attribution must be provided when submitting the project. Unlicensed third-party or any Intellectual Property music is not allowed." (https://support.curseforge.com/support/solutions/articles/9000197279-moderation-policies, modified 22 Oct 2026). That covers CC0 and CC BY as long as you credit — but it does **not** authorise bundling Blizzard's own files, which is why your FileDataID approach is the right one.
6. **Two policy items you should read before shipping art or a gallery:** the same page's "AI Misleading Content Disclosure" rule only bites if an AI image misrepresents the addon — your Python-generated art is a genuine selling point and needs no disclaimer — and "Fair Play" bans file updates made purely to farm visibility, so your beta→v1.0.0 pair should carry a real changelog.
7. **Whether Wago and WoWInterface carry a Forever flavour filter.** Wago's homepage lists a Retail filter; WoWInterface's category tree shows no Forever category, only Forever compilations.
8. **A Soft Murmur's Meander is described as a documented feature**; whether it is patented or trademarked is unknown, so naming your version "Meander" is a coin toss worth checking.

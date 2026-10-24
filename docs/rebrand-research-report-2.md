# Rebrand research, report 2: progress note

Deep research report 2, received 2026-10-24, in answer to
`docs/rebrand-research-prompt.md`. Verbatim. It is a progress note, not the finished
report, and its lead Reddit number could not be found; see RESUME.md, under "Should it be
Comfy Rain at all?", before using it.

---

## Where the research got to

Roughly two thirds done. I have enough to write most of the answer, but four evidence gaps remain that would each change a line of the verdict.

### Confirmed, with sources

**The demand is real but it is three different asks, and the loudest one is the one your renderer is worst at.**
- r/classicwow, "Blizzard, Please Fix WoW's Day/Night Cycle" — **1,024 votes, 1,173 comments** (https://www.reddit.com/r/classicwow/comments/1x466os/). Region/clock (b), not sky art.
- r/wow, "In the wow forever beta I play at nighttime all the time" — 73 votes, 67 comments, from East Asia (https://www.reddit.com/r/wow/comments/1wqkvs3/). Asks for a **shorter cycle** (b).
- r/classicwow, "Time zones and the in game day/night cycle in Forever" — 17 votes (https://www.reddit.com/r/classicwow/comments/1x1q9zf/). East coast, wants *darker* nights — that is your good direction.
- Blizzard forums thread you cited is confirmed, plus EU "Thoughts on a faster day and night cycle" (https://eu.forums.blizzard.com/en/wow/t/thoughts-on-a-faster-day-and-night-cycle-in-forever/630910) and US "Make Day/Night cycle shorter, more frequent" (https://us.forums.blizzard.com/en/wow/t/make-daynight-cycle-shorter-more-frequent/2356061).
- Sky art (a) is a **separate** and larger-traffic ask: r/wow "a mere skybox update would go a long way" — 11,132 votes (2019, https://www.reddit.com/r/wow/comments/cg282g/); a new Forever forum thread "Updated Sky Boxes for Forever" exists (https://us.forums.blizzard.com/en/wow/t/feedback-suggestion-updated-sky-boxes-for-forever/2386413).
- Weather demand is **at least as big as day/night**: r/wow "Snowy Weather in WoW Forever" — **1.1K votes, 165 comments**; "Rain in WoW Forever" — 114 votes; r/classicwow "Day 1 of asking for weather effects" — 100+ votes; Blizzard has already shipped *increased weather density in beta zones* (mmoexp/Blizzard patch coverage).

**Two things that contradict your "cannot" premise — this is the most important finding so far.**
1. A **`gamma` CVar exists** and addons set it via `SetCVar`. Two published addons do exactly the night-darkening you claim is impossible: **DayNight** ("Dynamically adjusts in-game gamma to darken the game during night cycles", https://www.curseforge.com/wow/addons/daynight) and **Nightlight** ("movable slider… control of gamma", https://www.curseforge.com/wow/addons/nightlight). Gamma is not a world-light setter, so your binary search may be right about *setters* while missing the CVar route. Gamma **brightens** as well as darkens, which is the night→day direction you wrote off.
2. A **`weatherDensity` CVar exists**, 0–3, live-applied (https://addonstudio.org/wiki/WoW:CVar_weatherDensity; https://pro-gamer.gg/world-of-warcraft-forever-graphic-settings-hidden-cvars-commands-guide/). Also `weatherDensity`/`RAIDweatherDensity`. So "weather has no setter" is true only of the *type* of weather, not the amount.

**Filter-style fakes are already a crowded, accepted niche, with a known backlash to write around.**
- NightIllusion — 11.3K downloads, "Illusion of a darker night", CurseForge project 70309 (https://www.curseforge.com/wow/addons/niill). User reaction is mixed and quotable: "just looks like someone put a black filter over the screen" (https://www.reddit.com/r/wow/comments/3w5h5c/); "all the lights, torches and fires are dimmed too" (https://us.forums.blizzard.com/en/wow/t/night-time-addon/186431).
- **Weather** (CurseForge, 2.9K dl) already applies a screen colour overlay for rain/snow/sandstorm — direct competitor (https://www.curseforge.com/wow/addons/weather).
- **Cinematic** already does "a colour tint that shifts with the time of day" (https://www.curseforge.com/wow/addons/cinematic).

**Name/search mechanics.**
- CurseForge's own author-facing idea thread: "it's hard to find an addon for something you want **unless you know its name exactly**", with a request for tags because functionality is not searchable (https://curseforge-ideas.overwolf.com/ideas/CF-I-6033).
- A mod renamed to "The Factory Must Grow" kept its old `create-industry` URL slug, and the author had to use an external search engine to find it (https://www.reddit.com/r/ModdedMinecraft/comments/1fkk20b/).
- Renames do change the slug and require a moderator (https://authors.curseforge.com/forums/world-of-warcraft/general-chat/need-help/215787-need-moderator-assistance-to-rename-an-addon).
- WowUp has an open issue to delete old folders after a rename, i.e. **clients currently leave the old folder behind as a second addon** (https://github.com/WowUp/WowUp/issues/577).

**ReShade** is widely used with no ban precedent found, but I did **not** find an official Blizzard blue statement either way — only forum threads (https://us.forums.blizzard.com/en/wow/t/is-reshade-allowed-or-no/2122463).

### Still missing

1. **CurseForge search positive control.** Could not scrape (the page-scraper tool is out of quota this turn), so I have not yet run the "search a summary-only word, see if the addon comes back" test. Proposed controls: `accessory reminders` (only in the *Weather* addon's summary) and `violence level` (only in *RainingBlood*'s).
2. **Whether `gamma` and `weatherDensity` actually exist in the Forever client 1.60.1**, versus Retail only. Your binary search was for functions; CVars need a different check. If they are absent on Forever, my contradiction weakens.
3. **Scores still uncollected:** the r/wowforever 516-upvote skybox thread, the EU "faster cycle" and US "shorter, more frequent" forum threads, and the true score/date on forever-bugs #424 (reported as 10 👍, opened 2026-10-22, unverified).
4. **A real, documented WoW addon renamed after publication** — I have Minecraft-mod analogues and a WowUp issue, not a WoW addon with a download curve.

Everything else — options table, name shortlist with post-fix survival, Time-of-Day wording, and the "worth installing after Blizzard fixes it" section — can be written now. The verdict is likely **restructure (A), do not rename before 4 Nov**, because the surviving core after all three Blizzard fixes is the *on-demand* weather plus the local-clock *grade*, and neither depends on a gap that a patch closes — but the gamma-CVar finding and the positive control are the two things that could flip the "cannot brighten" half of that.

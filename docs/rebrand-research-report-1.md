# Comfy Rain before WoW: Forever launch: keep the name, sharpen the title line, and do not build the brand on day/night

Deep research report 1, received 2026-10-24, in answer to
`docs/rebrand-research-prompt.md`. Verbatim. What was checked against it is in RESUME.md,
under "Should it be Comfy Rain at all?".

---

**Verdict:** Do not rename and do not split into two addons. Keep "Comfy Rain" as the brand and the `ComfyRain` folder, and before 4 November make small reversible changes to the page and the settings, with no structural change. Most of the measurable day/night demand asks for daylight in the Oceanic evening, which the colour grade cannot deliver. Blizzard has already started closing the weather gap: community manager Kaivax posted "Increased Weather Effects" ("Coming soon to the Beta") in the Forever forum on 2026-09-23, and PC Gamer reported the same day that Blizzard "will be cranking the weather effects up to 10 in 'certain' WoW: Forever beta zones". The part of the addon that survives every likely Blizzard fix is player-chosen mood on demand (rain, snow, dusk or night, plus sound), so the name and page should rest on that, not on "the game is too dark" or "the game never rains". Before launch, change the CurseForge display title to "Comfy Rain: Rain, Snow & Dusk", rewrite the summary to name the dusk/night hold honestly, give Time of Day two of seven gallery images, tag the file for Retail as well as Forever, and leave the folder, saved variables and slash commands alone.

## TL;DR

- **Day/night demand is real but points the wrong way for you.** The biggest measurable signal is a 70-like Oceanic thread (seen 2026-10-24). It and its sibling threads mostly ask for daylight in the evening, which is the direction a multiply-based grade cannot deliver. Requests you *can* serve (hold night or dusk, mood lighting) exist but are scattered single posts with 0–2 likes each.
- **The name matters for the CurseForge app, thinly evidenced.** CurseForge's own API documents search as matching "the mod name and author". A user request on CurseForge's ideas portal says the website also searches descriptions but the app does not. So a keyword in the display title helps; a full rename does not.
- **Do not rename.** Renaming costs little now (15 downloads), but nothing in the evidence says a new name would win more installs. An umbrella name would drop the one search word players type ("rain") and would invite the daylight crowd the renderer cannot serve. Make the cheap title, summary, gallery and flavour-tag changes before 4 November, and reconsider after launch with real comment and install data.

## Key Findings

### 1. How big is the day/night demand, and what does it actually ask for?

Every score below is a count of *wants* (likes, upvotes, reactions), not installs. Download counts appear only where they are labelled as downloads.

- **(b) Clock vs time zone, mostly Oceania, is the largest and best-documented category.** The Blizzard Forever General Discussion thread "WoW Forever adds dynamic lighting, but OCE is stuck in perpetual midnight" (posted 2026-09-28) showed **70 likes** on the opening post when I checked on 2026-10-24. Your brief records 71 on an earlier visit. The difference is one like and may be an unlike or a counting difference, so treat the figure as about 70. The top reply ("Day/night cycle attached to your local time would be great.") has 13 likes, which matches your brief. At least four replies ask for a toggle or client-side option: Tumble 8 likes, Kitsune 2, Jkitz 1, and Alex 2, who wants night on demand.
- **forever-bugs #424 is open but was locked on 2026-10-22.** The repository "locked as off topic and limited conversation to collaborators" on 2026-10-22, the day it was opened. A collaborator added that "this is for bug reporting only and not feedback". It still carries the Bug type and the Art/Visual and Other labels. I could not see the 10 thumbs-up you recorded: the page showed "Reactions are currently unavailable" for the issue body. I counted 10 user comments plus the collaborator's note. Several commenters say it is **not just Oceania**: "OCE will only ever see night time, east coast US will only ever see the sun", and an evening player threatens not to subscribe unless they can "experience Azeroth in daylight".
- **The issue's claim that the thread is "one of the most-liked in Forever General Discussion" is unverified.** I did not rank the forum. At 70 likes it is large for a Blizzard forum thread, but I have no comparison set.
- **The 2016 Oceanic claim is partly verified.** The Oceanic General Discussion thread "Day Night Cycle" (2022-11-26) links a Blizzard ANZ tweet from 2016 acknowledging the issue, and posters say nothing changed. I did not open the tweet itself.
- **There are more (b) and fixed-schedule threads.** Each confirms the want; none had a visible like count in what I could load:
  - Forever Beta Discussion, "Australians have to play Forever in night time… can we toggle day and night?" (2026-10-06)
  - "Day/Night Cycle on the Mega Server – Local Time or Server Time?" (2026-09-25 per #424)
  - "Day/Night Cycles" (2026-09-26): a North American evening player says the game is "completely orange from sunset" for 3–4 hours
  - EU Forever General Discussion, "Pleas remove the day night cycle" (2026-10-17): 1 like on the opening post
- **There is counter-demand.** In the EU thread, replies of 6 likes (Corblane) and 1 like each (Gamer, Puny, anakin) defend 1:1 real-time or note that EU will get its own clock at launch. That last point is a player claim, not a Blizzard statement.
- **(a) Better sky art.** The r/wowforever skybox thread (about 516 upvotes on 2026-10-18 per your brief) was blocked to my fetcher, so I could not re-verify the score. Separately, the Oceanic thread's opening post asserts that Forever *already* brings "complete dynamic lighting and overhauled skyboxes". That is a player's claim. If true, Blizzard is already working on skies.
- **(c) Mood: permanent dusk or night, cozy evenings, roleplay.** This is the category you can actually serve, and it is thin and scattered:
  - Alex (2 likes) in the Oceanic thread: "I only see the game in daytime… I'd like to be able to see nighttime."
  - The "Faster Day Night Cycle" opening post (2026-09-20) wants to see night more often.
  - In "Night time forever?", a US East Coast poster says "If it were up to me, it would always be night".
  - The opening Oceanic post itself calls night "gorgeous, moody, and completely nostalgic".
  - **Revealed demand (downloads, not wants):** NightIllusion, a darker-night overlay, has **11,380 downloads** over 10+ years (last updated 2013-12-08, Retail only, seen 2026-10-24). DayNight, a gamma-based night darkener, has **136 downloads** (last updated 2015-10-14, seen 2026-10-24).
- **On-demand rain and snow, measured the same way:**
  - "Rain more often = immersion" (Forever Beta Discussion, 2026-09-23): like count not visible to me.
  - MMO-Champion "Request to add Weather Tracker and also Enhance Weather Effects in WoW:Forever" (2026-09-26): score not visible.
  - PC Gamer reported that a Reddit user (Darthbobz) asked for heavier weather, and **Blizzard answered**. Community manager Kaivax opened "Increased Weather Effects" on 2026-09-23 with a video of an Elwynn rainstorm, "Coming soon to the Beta" (reported by wowclassicforever.info and PC Gamer).
  - So weather demand is less *measurable* than day/night demand in likes. It is also the one gap Blizzard has visibly started to close.

**What this means:** the developer's instinct that day/night is "the big ask" is right about volume and wrong about what you can sell. Roughly all the liked posts in (b) want *brighter* evenings. The darkening direction the addon does well has real but small, mostly historical evidence: about 11k lifetime downloads for a similar overlay.

### 2. What a screen-space colour grade can honestly satisfy

- **(a) Sky art:** no. The sky is out of reach, by your binary search and by every addon I found.
- **(b) Oceanic daylight in the evening:** no. A lift capped at 0.13 cannot add a sun or restore contrast. Presenting it as a fix would generate exactly the "it's just a filter" comment.
- **(b) North American and EU evening players who see perpetual sunset and want night:** yes. That is a multiply.
- **(c) Dusk or night hold, cozy evening, roleplay lighting:** yes. This is the honest product.
- **A route you did not mention: the gamma CVar.** The 2015 addon **DayNight** "dynamically adjusts in-game gamma to darken the game during night cycles" (CurseForge page, seen 2026-10-24). Your binary search covered gamma *setter functions*, but a CVar written through `SetCVar` is a different route. Test whether `Gamma` (and `Brightness`/`Contrast`, if present) exist and are writable from an addon on Forever 1.60.1. This would not create a sun or change the sky, and historically gamma also affects the UI, so it does not cross your renderer constraint or overturn the night-to-day verdict. It might give a stronger brighten than 0.13. Unverified on Forever.
- **Has anyone changed the time of day client-side by an allowed addon route?** I found none. Positive control: the same CurseForge searches did return day/night addons (NightIllusion, DayNight, the Day 'N' Nite indicator, the Kela Day/Night Indicator, ScreenEffects). Every one is an overlay, a gamma change or a clock indicator; none sets the sky or the world time.
  - The only client-side time overrides I found are **Blizzard's own Retail toys**. Jar of Sunwarmed Sand lets you "perceive the world as if it were midday" with a 1-day cooldown; per Warcraft Wiki the buff lasts two hours, is removed on death, and the toy is sold by Otela in the Caverns of Time for 1000 Timewarped Badges (added in patch 8.2.0, 2019-06-25). Shadescale, a Nazjatar drop, "makes it nighttime instead, and it lasts for two hours with a one hour cooldown" (Blizzard forum, "Reduce the cooldown time of Jar of Sunwarmed Sand"). A consumable Sunwarmed Sand also exists: the Blizzard forum thread "Daytime toy added [Attn: Oceanic players]" says it "can be bought for 10 timewarped badges each". The 10-second cooldown claimed in another forum thread is unconfirmed.
  - It is an item, not an addon API, and Forever players cite it as the model for a fix.
- **Existing day/night addons and how users reacted:**
  - NightIllusion: 11,380 downloads, Retail, last updated 2013. A 2016 MMO-Champion post praised it as "a very natural look" because it does not cover the UI, and called the author's screenshots "awful". The takeaway: a good-looking gallery decides whether a filter reads as a fake.
  - DayNight: 136 downloads.
  - Kela Day/Night Indicator: 0 downloads, Forever. It is an indicator, not lighting.
  - ScreenEffects: 582 downloads, last updated 2024-08-24, Classic. It offers a "night" filter.
  - I found no user thread attacking a filter-style fake specifically. That absence is weak evidence, because the comment sections were not fully loaded.
- **ReShade and similar tools:** they serve this audience in principle, but they are also post-process only, so they cannot add a sun either. **Blizzard has no explicit public position that I could find.** Forum answers range from "grey area / no stance" to a support quote that changing game files "runs contrary to our EULA". A ReShade forum report says WoW 11.1.7 blocked ReShade's dxgi.dll on 2025-07-14 and a follow-up build an hour later loaded it again. Claims of bans are unverified.

### 3. Does the name matter for being found?

- **CurseForge API: name and author only.** The official REST API documents `searchFilter` as "Filter by free text search in the mod name and author" (docs.curseforge.com, seen 2026-10-24). Third-party managers that use this API would, on that wording, not match on the summary.
- **Website vs app: contested and thin.** A CurseForge ideas-portal request (CF-I-6766, 2024-11-15, status "Future consideration") states: "The CurseForge website has a generally better and more flexible search system, showing results based not just on the project's name, but also its description." It asks for the app to match that. This is a user claim, not a staff statement.
  - Another user thread (CF-I-3582, 2024-12-14 comment) says the new website search returns fuzzy partial-letter matches.
  - CurseForge's moderation guide says the summary "appears in search results". That governs display, not matching.
- **Positive control: not completed.** I could not run "darker night" on CurseForge's live search. The search URL was blocked to my fetcher, so I cannot say whether NightIllusion appears for a summary-only word. **You should run it yourself in five minutes:**
  - Search "darker night" on the website and in the app.
  - NightIllusion's summary contains it and its title does not.
  - If the app returns it, summaries are indexed there; if not, only titles matter in the app.
- **Decision impact:** under the documented API behaviour and the user report, "Comfy Rain" does hide Time of Day from app search. A keyword in the *display title* fixes that without moving any folder.

### 4. What a rename costs after publication

- **Display name: changeable.** CurseForge's Project Submission Guide says the project tab in the author dashboard "will allow you to edit it after creation".
- **Slug: changeable, weakly evidenced.** Other authors' October 2026 pull requests report CurseForge moderation forcing a name change, after which "its slug changed with it". Those PRs are AI-co-authored, so weak evidence. I found no CurseForge support article on changing a slug after approval.
- **Old URL and project ID: probably preserved (strong circumstantial evidence).** GridStatusRaidDebuff was renamed PlexusStatusRaidDebuff:
  - The project kept **ID 42578**, a decade-old creation date and **954,230 downloads**, and its file history includes `GridStatusRaidDebuff-r33.zip` from 2015.
  - The old slug `gridstatusraiddebuff-mop` still returns the renamed page in search results. I did not directly confirm that it redirects.
  - The Archiveteam wiki says `curseforge.com/projects/<id>` redirects to the current slug.
- **Existing installs, WowUp:** issue #577 (opened 2020-12-05) reported that renamed addons left **two folders** after an update. The maintainers fixed it by recording each addon's installed folders and removing them all on update, keyed by project ID. Only installs made before that fix keep a stale folder.
- **Existing installs, CurseForge app and Wago:** not verified.
- **Cost now vs after launch:**
  - **Now:** 15 downloads, migration code already written, about 1 hour of page work, but a fourth name in three weeks.
  - **After launch:** most installs happen on 4 November, so every saved-variables migration, every stale folder in non-WowUp managers, and every Reddit link that names the addon multiplies by the install base.
  - If you will ever rename, the cheapest moment is before 4 November. The evidence does not show you need to.

## Options compared (question 5)

| Option | Discovery effect | Cost | Reversibility | Evidence | What is left after the three Blizzard fixes |
|---|---|---|---|---|---|
| **A. Keep name; rebalance page, gallery, settings** | Neutral in the app, since the title still says only "Rain". Small gain on the website if descriptions are indexed (user claim) | About 2 hours, zero install risk | Fully reversible | Search documentation; ToD is the 4th of 7 bullets on the live page (seen 2026-10-24) | Rain/snow on demand plus a dusk hold plus audio: all survive, because none are Blizzard's planned fixes |
| **B. Rename to an umbrella (weather + light + sound)** | Loses "rain", the word players type, from the title-indexed app search; gains nothing measurable | Low now (15 downloads), high after launch; 4th rename | Display name reversible; folder rename leaves stale folders in some managers | No evidence an umbrella word is searched; WowUp #577 | The same features survive, but the name would advertise "light", which invites the daylight request you cannot meet |
| **C. Keep Comfy Rain plus a second small Time of Day addon** | Adds a title-indexed "time of day / dusk" entry, but the people who search that mostly want daylight (category b) | Two pages, two release pipelines, split ratings | Easy to retire the second addon | NightIllusion 11,380 lifetime downloads; DayNight 136; Kela 0 | Weakest: a Blizzard per-region clock or client toggle removes most of its reason to exist; a dusk hold remains |
| **D (recommended). A plus a title subtitle and flavour fix: "Comfy Rain: Rain, Snow & Dusk"; folder unchanged; tag Retail 12.1.5 as well as Forever** | Puts "snow" and "dusk" into the title field the app searches; the Retail tag makes it visible to Retail filters (today the file is tagged Forever only, although the page says it works on Retail) | About 2 hours; no folder, saved-variables or slash change | Fully reversible in the dashboard | API name-only matching; the live page shows only the Forever flavour | "Rain, Snow & Dusk" still means something after every fix: player-chosen mood, not a patch for a missing feature |

**Why D over A:** in the app, the title is the only searchable surface under documented behaviour, and D is the only option that puts the second feature into the title without a rename. "Dusk" promises only what the multiply does well. Keep the subtitle short, because CurseForge's guide warns against "excessively long names".

**Why not C now:** the earlier "one addon, not two" finding was about visuals against audio, and I found no new evidence that overturns it for weather against light. A standalone Time of Day addon would be found mainly by Oceanic players hunting for daylight, and would earn the reviews a dimmer deserves from people who wanted a sun.

## If a new name wins anyway (question 6)

I do not recommend renaming. If you overrule that, here are fallbacks. **I could not run the CurseForge collision check**: the search page was blocked to my fetcher, and the positive control in section 3 is also yours to run. Search each on the website and in the app before using it.

1. **Comfy Weather.** Easy to hear and spell, names no single weather type, no "day" or "sun", no "ever". After Blizzard's fixes it still means "weather you choose".
2. **Comfy Evenings.** Promises only the dusk/night direction you can deliver. It still means a mood after a per-region clock ships. The risk is that it under-sells snow.
3. **Comfy Hours.** Neutral on time, no "day" or "sun". It survives all fixes as "your cozy hours", but it is vaguer for search.

All three keep "Comfy", so `/comfy` stays meaningful, and none contains the substring "ever".

## How to describe Time of Day without overpromising (question 7)

- **Suggested summary (≤150 characters):** "Rain or snow anywhere, with wind and thunder. Hold the world at dusk or night, or follow your own clock. A cozy screen grade, not a new sky."
- **Suggested feature bullet:** "**Dusk & night hold**: a colour grade over the whole screen that holds the evening mood or follows your PC clock. It darkens beautifully; it cannot turn night into day, change the sun or change the sky. If you're in Oceania hoping for daylight, this won't give you that, and we'd rather tell you now."
- **Leading with it is a reputational risk only if it is framed as a day/night fix.** The 70-like thread and #424 set the expectation as "make it daytime". Lead with mood (dusk, night, roleplay evenings) and the admission is a feature, which matches your existing "What it is, honestly" section.
- **Default:** keep Time of Day off on first install, but add a "Rainy dusk" preset to the minimap menu so first-time users see it in one click.

## Will it still be worth installing after Blizzard's fixes? (question 8)

| Fix | Likelihood (my judgement) | Signals to watch | What of the addon is still useful |
|---|---|---|---|
| Per-region Oceanic clock, shorter cycle, or client-side time option | **Low to moderate within 6 months.** Retail Oceania has waited since at least 2016 (the 2022 Oceanic "Day Night Cycle" thread's opening post: "Players have been requesting this for years."); #424 was locked within a day; no Blizzard reply found. The Retail Jar of Sunwarmed Sand shows the client *can* override time per player, so a Forever toy or item is plausible | A Blizzard blue post in the Oceanic thread; a Forever patch note on "day/night"; the Jar appearing in Forever data-mines | The dusk/night hold for daytime players, roleplay lighting, and all weather and audio. The "follow my PC clock" mode loses most of its Oceanic value |
| Updated skyboxes or volumetric clouds | **Moderate.** The Oceanic opening post already claims "overhauled skyboxes" in Forever (player claim) | Patch notes or Wowhead data-mines mentioning sky or cloud assets | Everything. You never touched the sky, so better skies make your darkened frames look better |
| More weather, more often, more zones; player-facing weather option | **More weather: high** (Blizzard announced "Increased Weather Effects" 2026-09-23). **Player weather toggle: low** (no precedent found; weather is server-driven per zone) | Beta patch notes listing zones; any "weather" option in Forever settings | On-demand choice: rain where and when *you* want it, snow anywhere, persistence, presets, audio, and the indoor fade. Your design already defers to Blizzard's rain wherever it falls |

**What survives all three:** player-chosen ambience on demand: picking rain, snow, dusk or night and its sound, wherever and whenever, and sharing it as one line. Blizzard's planned fixes make the world more varied; none of them hand the player the dial. **The recommended name and structure (D) rest on that part.** "Comfy" sells the mood, "Rain, Snow & Dusk" lists choices rather than complaints, and nothing in the title depends on the Oceanic clock bug or the scarcity of rain.

## Demand table

| Source | Link | Date posted / seen | Score (wants, not installs) | Asks | Can a screen grade deliver? |
|---|---|---|---|---|---|
| r/wowforever, Skyboxes (u/zambabamba) | https://www.reddit.com/r/wowforever/comments/1x8tnda/the_biggest_easywin_blizzard_is_currently_not/ | Seen 2026-10-18 by you; blocked to me | ~516 upvotes, top comment 184 (yours, unverified by me) | a | No |
| Blizzard US Forever GD, OCE perpetual midnight | https://us.forums.blizzard.com/en/wow/t/wow-forever-adds-dynamic-lighting-but-oce-is-stuck-in-perpetual-midnight-fix-the-daynight-cycle/2365303 | 2026-09-28 / 2026-10-24 | 70 likes on opening post; top reply 13; 2 pages | b (plus a toggle request) | No (brightening) |
| forever-bugs #424 | https://github.com/ClassicWoWCommunity/forever-bugs/issues/424 | 2026-10-22 / 2026-10-24 | Body reactions not visible; comment reactions 5, 3, 2, 2, 2, 1, 1, 1; locked 2026-10-22 | b, plus all-region fixed-schedule | No (brightening); partly yes for evening players wanting night |
| Forever Beta Discussion, "Australians… toggle day and night?" | https://us.forums.blizzard.com/en/wow/t/australians-have-to-play-forever-in-night-time-its-so-dark-can-we-toggle-day-and-night/2373884 | 2026-10-06 / 2026-10-24 | Not visible | b | No |
| Forever GD, "Day/Night Cycle on the Mega Server" | https://us.forums.blizzard.com/en/wow/t/daynight-cycle-on-the-mega-server-%E2%80%93-local-time-or-server-time/2361585 | 2026-09-25 / 2026-10-24 | Not visible | b | No |
| Forever Beta, "Day/Night Cycles" (perpetual sunset) | https://us.forums.blizzard.com/en/wow/t/daynight-cycles/2362731 | 2026-09-26 / 2026-10-24 | Not visible | b / variety | Partly (can push sunset to night, not to day) |
| Forever GD, "Faster Day Night Cycle" | https://us.forums.blizzard.com/en/wow/t/faster-day-night-cycle/2356038 | 2026-09-20 / 2026-10-24 | Not visible | c (wants to see night) / variety | Yes for night |
| Forever GD, "Night time forever?" | https://us.forums.blizzard.com/en/wow/t/night-time-forever/2354625 | Date not seen / 2026-10-24 | Not visible | b, plus one c ("would always be night") | Yes for the c post |
| EU Forever GD, "Pleas remove the day night cycle" | https://eu.forums.blizzard.com/en/wow/t/pleas-remove-the-day-night-cycle/636190 | 2026-10-17 / 2026-10-24 | Opening post 1 like; pro-1:1 replies 6, 1, 1, 1 | b (contested) | No |
| EU Forever GD, "Thoughts on a faster day and night cycle" | https://eu.forums.blizzard.com/en/wow/t/thoughts-on-a-faster-day-and-night-cycle-in-forever/630910 | Date not seen / 2026-10-24 | Not visible; mixed opinions | b / variety | Partly |
| Retail Oceanic GD, "Day Night Cycle" | https://us.forums.blizzard.com/en/wow/t/day-night-cycle/1415853 | 2022-11-26 / 2026-10-24 | Not visible | b | No |
| Forever Beta, "Rain more often = immersion" | https://us.forums.blizzard.com/en/wow/t/rain-more-often-immersion/2358952 | 2026-09-23 / 2026-10-24 | Not visible | Weather | Yes (on-demand overlay) |
| MMO-Champion, weather tracker / enhance weather | https://www.mmo-champion.com/threads/2670247-Request-to-add-Weather-Tracker-and-also-Enhance-Weather-Effects-in-WoW-Forever | 2026-09-26 / 2026-10-24 | Not visible | Weather | Partly (intensity yes; zone tracker no) |
| Blizzard response: "Increased Weather Effects" (via PC Gamer and wowclassicforever.info) | https://www.pcgamer.com/games/world-of-warcraft/world-of-warcraft-forevers-first-patch-will-bring-back-the-number-one-thing-seasoned-players-missed-from-the-mmos-past-storms/ | 2026-09-23 / 2026-10-24 | n/a (developer action) | Weather | n/a: the gap is closing |
| NightIllusion addon (installs, not wants) | https://www.curseforge.com/wow/addons/niill | Last updated 2013-12-08 / 2026-10-24 | 11,380 downloads | c | Yes (same method) |
| DayNight addon (installs, not wants) | https://www.curseforge.com/wow/addons/daynight | Last updated 2015-10-14 / 2026-10-24 | 136 downloads | c | Yes |

I searched for r/classicwow and r/wow threads on Forever day/night and found none. The positive control was that the same search engine returned the Blizzard forum threads above. Reddit itself was blocked to my fetcher, so Reddit coverage is the weakest part of this table.

## Recommendations before 4 November

1. Change the CurseForge display title to **"Comfy Rain: Rain, Snow & Dusk"**. Leave the slug, folder, saved variables and slash commands unchanged.
2. Replace the summary with the honest version in section 7. The live summary (seen 2026-10-24) reads "…Set it from the settings panel or the minimap button.", which differs slightly from your brief's wording. Either way it omits Time of Day.
3. Move "Dusk & night hold" to the second feature bullet with the "cannot turn night into day" line, and give it 2 of 7 gallery images: one dusk hold and one rainy night.
4. Tag the v1.0.0 file for Retail 12.1.5 as well as Forever 1.60.1. The page says it works on Retail, but the only flavour listed is Forever.
5. Run the "darker night" positive control in the CurseForge app and on the website, and write down the result. If the app indexes summaries, the subtitle matters less, but it costs nothing to keep.
6. Test `SetCVar("Gamma", …)` on Forever 1.60.1 as a possibly stronger, allowed brighten route. Ship nothing based on it until it is tested.
7. After launch, revisit naming only if comments show users missing Time of Day or expecting daylight, and only before installs reach the thousands.

## Caveats and what I could not verify

- The Reddit skybox thread score (516) and any Reddit day/night threads: Reddit was blocked to my fetcher. #424 links a "big thread" titled "anyone else bothered by always playing at night" (2026-10-22) whose score I could not see.
- #424's thumbs-up count (your 10) is not visible to me, and its claim that the Oceanic thread is "one of the most-liked" in Forever General Discussion is unranked.
- Like counts on most secondary threads loaded only as metadata.
- CurseForge site and app search matching: no live positive control was run. The app-vs-website difference rests on one user's ideas-portal claim.
- Whether the CurseForge app and Wago clean up an old folder after a folder rename; whether old slugs formally 301-redirect.
- Whether `Gamma` or related CVars exist and are addon-writable on Forever 1.60.1.
- Whether EU and Oceanic Forever layers will run on local clocks at launch. That is player speculation in the threads, not a Blizzard statement.
- Name collisions for the fallback shortlist: not checked.
- Blizzard's position on ReShade: no official statement found; the 2025 block-and-unblock is a single user report.
- Whether Forever already ships "overhauled skyboxes": a player's claim.

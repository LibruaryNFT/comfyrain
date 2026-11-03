# Comfy Rain: Launch Plan and Audio/Feature Roadmap for WoW: Forever (as of 26 October 2026)

Deep research report 2, received 2026-10-26, in answer to `docs/next-steps-research-prompt.md`. Verbatim. What was checked against it is in RESUME.md, under "2026-10-26: the next-steps reports, checked".

Before 4 November, do three things: rewrite the CurseForge summary and gallery so that "rain", "snow", "weather sounds", "ambience" and "cozy" are in the searchable summary and a short clip with sound is the first gallery item; upload v1.0.0 tagged for both Forever and Retail by 3 November so it has cleared moderation before players log in; and spend this week testing every untested FileDataID and the Gamma CVar on Retail, so launch night only needs a short Forever smoke test. After launch, build one thing first: a micro-sequenced sound engine with a choice of rain soundscapes. Audio is the one area where neither Weather nor Cinematic competes seriously, and it stays useful after Blizzard's own weather improves, because Comfy Rain plays rain wherever and whenever the player wants it. Leave gamma-based daylight as an opt-in for later in the first month, and only after it has been tested on Forever.

## TL;DR

- **Launch:** On Forever, discovery happens on CurseForge. The game launches 4 November at 3:00 p.m. PST (23:00 UTC). Lead with the summary and the gallery, then make one r/wowforever post with a video 2–3 days after launch. When seen on 26 October 2026 that subreddit had 147,854 members and no stated self-promotion allowance.
- **Audio:** The best ambient products (myNoise, A Soft Murmur, Rainy Mood) offer a handful of named scenes, mix in slow random gain changes, and scatter one-shots so nothing repeats. Timers, a per-file loudness table and staggered relaunches can do all of that inside WoW's API limits.
- **Risk:** Gamma has never been restricted for addons, as far as anything found shows. The danger is leaving a player's own setting changed: CVars written by addons persist after logout and can sync from the server. Gamma needs to be opt-in and restored on every logout, and it has not yet been tested on Forever.

## Key Findings

**Verified facts (seen 26 October 2026 unless stated)**

- **Launch timing.** Blizzard's Forever page and its pre-purchase article put launch at 4 November 2026, 3:00 p.m. PST. Invite-A-Friend launch codes work from 4 to 11 November. Guide sites (wowguide.net, wowhandbook.com) list Early Name Reservation as 27 October to 3 November and first raids on 9 December. Sources disagree on when the beta ended: Blizzard's pre-purchase article says 21 October, while wowforever.co and wowhandbook.com say 23 October. Neither date changes the plan.
- **Forever addons use the modern API.** Guide sites (zockify.com, wowguide.net) relay the 17 September developer Q&A: Forever runs Midnight's combat-data restrictions on the modern addon API, and Classic Era addons need Forever-specific releases. This is secondhand. No Blizzard primary source was fetched.
- **Comfy Rain today.** The CurseForge page showed 16 downloads (installs), the Forever flavour only, a last update of 20 October, and this summary: "Makes it rain or snow anywhere in the game, with weather sounds, wind and thunder. Set it from the settings panel or the minimap button." The download count matches your 24 October figure of 15. Retail is still not listed.
- **Cinematic (SapoAC)** had 8,992 downloads (installs), 85 comments, 5 gallery items with a YouTube video first, a Discord link, and five flavours: Retail, Forever, MoP Classic, Titan Reforged and Classic. It was created 18 days earlier and last updated 25 October, and is All Rights Reserved. Releases are very frequent: v1.5.20 came out on 10 October and v1.8.60 on 25 October. The description is broad. It fades the UI between fights, adds letterbox bars and "a colour tint that shifts with the time of day", and handles cameras, campfires and chat bubbles. It grew from 8.6K on 24 October to 8,992 on 26 October, about 165 installs a day before launch.
- **Weather (keyboardturner)** had 2,909 downloads (installs) across Retail and Forever. Its last update was 20 October and it is All Rights Reserved. Its GitHub README says its screen tint is "a subtle screen color overlay for rain, snow, and sandstorms" whose "opacity… dynamically scales with the current intensity of the in-game weather". In other words, it reacts to Blizzard's weather and does not create weather. Its 0.1.0 release notes list a Forever-specific known issue: "Indoor ambience can't play due to a lack of Encounter data… waiting to see if this will be the case at release." The current main file on CurseForge is 0.1.1 (Retail 12.1.5 and Forever, 20 October 2026, project ID 1537521). Whether the 0.1.1 notes still list that issue has not been checked.
- **Scale of the Forever addon market.** ForeverAuras showed 290,259 downloads and ForeverPlus 54,416, both created about a month earlier. Those are the ceilings for this audience. Atmosphere addons are a niche well below them.
- **r/wowforever** was created on 3 September 2026. On 26 October it had 147,854 members and was growing 13.1% a week, according to the third-party tracker Subriff. Its rules: Forever only, post flair required (News, Discussion, Guide, Question, Art, Video, Meme), link the source, and memes and low-effort posts on Mondays only. Subriff's classification "Self-promotion not allowed" is the tracker's inference: the rules neither permit nor ban it.
- **Where Forever players get addons.** Install guides (Mobalytics, Kami-labs, ForeverDB) all point to the CurseForge app first. Kami-labs states: "For Forever, CurseForge first: that's where the 'WoW Forever' filter exists and where almost every author publishes their -forever files." ForeverDB also lists Wago as a trusted source. No Forever-specific evidence was found for WoWInterface.
- **Blizzard's weather.** Kaivax posted "Increased Weather Effects" on 23 September with a 38-second video. According to wowclassicforever.info (a secondary source), there was "no other Blizzard reply among the thread's 93 posts", and players "asked for more snow and blizzards, and for a setting in case heavy weather blocks the view". The same site reports that the beta client "already has 41 weather definitions that no other WoW client we compared has." PC Gamer, Kotaku, Shacknews, Icy Veins and Wowhead covered it. Kotaku's headline: "WoW: Forever Is Cranking Up The Weather And Players Are Losing Their Minds." According to lfcarry.com (secondary), the 1 October beta build improved rain visibility. Blizzard has said "certain zones" without listing them, but Shacknews (24 September 2026) reports that "Elwynn Forest was used as the example… showing a few different locations in the zone with heavy rain, fog effects".
- **CurseForge rules on audio.** The moderation policy says: "Unlicensed third-party or any Intellectual Property music is not allowed." It also says: "If you upload a project that is using copyrighted content… you must either be allowed to do so under their respective license or have explicit permission." And: "Attribution must be provided when submitting the project." CurseForge's own blog says the summary "appears in search results" and should "highlight something unique".
- **Gamma history.** The subagent found no Blizzard restriction, protection or removal of addon access to Gamma or SetGamma. The CVar that was removed is the separate `DesktopGamma`. Gamma complaints in 2023 came from a 10.0.7 bug in which addons writing long values to Config.wtf corrupted other lines, gamma among them. The wiki says this was fixed in build 10.0.7.48838.

**Folklore, anecdote and inference (labelled as such)**

- Player demand for heavier weather and seasons is anecdotal. Examples are a post by the Reddit user Darthbobz, quoted by PC Gamer ("I miss running through Dun Morogh… with a massive snowstorm lowering my view distance") and by Shacknews (asking for "snowstorms, sandstorms, and gentle drizzles that turn into intense downpours before calming"), and a Blizzard forum thread asking for "four actual seasons". These are wants, not installs.
- Nothing found tells you when in launch week an addon post works best on Reddit. The timing below is reasoned, not measured.

## Roadmap

| Item | Phase | Effort | Evidence | Risk |
|---|---|---|---|---|
| Rewrite summary with search words (rain, snow, weather sounds, ambience, cozy, thunder) | Before launch | XS | CurseForge says the summary is what search shows; your positive controls | Low |
| Gallery: 30–45 s clip with sound first, then 4 stills of the current art | Before launch | S | Cinematic leads with a YouTube video (8,992 installs) | Low |
| Upload v1.0.0 for Forever + Retail by 3 Nov | Before launch | S | CurseForge's blog post "How to Pass Moderation Review" says the team "reviews around 2,000 new projects a week, not counting updates on existing ones" and names the description as "by far the most common reason for requesting changes"; file review time unknown | Medium if left to 4 Nov |
| Test all untested FileDataIDs and Gamma on Retail now | Before launch | S | Retail 12.1.5 is playable today; Forever is not until 4 Nov | Low |
| Co-install test with Cinematic and Weather (double tints) | Before launch | S | Both tint the screen | Medium: stacked tints look muddy |
| First-minute experience: gentle rain on first login plus one chat line | Before launch | S | Reasoned, no external data | Low |
| Forever smoke test and 1.0.1 hotfix | Launch week | S | Forever client untested for audio IDs and Gamma | Medium |
| One r/wowforever Video-flair post | Launch week (6–8 Nov) | XS | 147,854 members; flair rules | Medium: removal possible |
| Sound engine v2: sequencer, loudness table, scene picker | First month | M–L | myNoise / Soft Murmur / Rainy Mood patterns; FMOD/Wwise conventions | Medium: untested IDs |
| Shelter treatment (drips and muffled bed under roofs) | First month | M | Weather's indoor ambience flagged as not working on Forever | Low |
| Inn scene (walla plus rain on the roof) | First month | M | Cozy niche; untested walla IDs | Medium: may double Blizzard's inn ambience |
| Gamma "brighter nights", opt-in, restore on logout | First month (after Forever test) | M | No restriction found; persistence hazard documented | High if mishandled |
| Fog overlay | First month | M | Blizzard's teaser showed fog; Cinematic has vignette only | Medium: overlaps Blizzard |
| Falling leaves / fireflies | Later | M | Seasons thread on Blizzard forums (wants) | Low |
| Opt-in music mode | Later | M | Forever Ambient Music Extended already exists (133 installs, 13 Oct) | Medium: player annoyance |
| Optional CC0 "HQ sounds" companion addon | Later | M | Licence path clear; fidelity gain unproven | Medium |

## Launch: the next nine days and the first two weeks

**What drives installs.** Search is all you control. In-game discovery does not exist, and Forever players are being steered to the CurseForge app's Forever filter. A browser shows the project in this order: name, summary, image, download count. So for v1.0.0 the summary has to work like an advert and a keyword list at once. Suggested summary (under 160 characters, every word searchable): *"Cozy rain and snow anywhere, with Blizzard's own weather sounds, thunder, wind and a time-of-day colour grade. Rain ambience for questing, reading or AFK."* After you change it, run your positive control again ("weather sounds" should still return Comfy Rain), and add "rain ambience" and "cozy".

**Gallery.** Put a 30–45 second clip with audible thunder first. Cinematic's first gallery item is a video. Follow it with four stills: rain at night in a town, snow in Dun Morogh, the settings window, and a before/after of Time of Day. Replace all three images from before 22 October.

**First minute.** On first install, start light rain at low volume, print one chat line ("Comfy Rain: it's raining. /comfy or the minimap button for settings"), and make the minimap icon pulse once. Do not run a tutorial. If Blizzard weather is active, say so in that chat line, so a player who sees nothing does not assume the addon is broken.

**Venues and self-promotion rules**

| Venue | What was verified | Rule on self-promotion | When |
|---|---|---|---|
| CurseForge app/site | Primary route in every install guide found | Normal project listing; summary is what search shows | v1.0.0 live by 3 Nov |
| r/wowforever | 147,854 members (26 Oct, Subriff) | No explicit allowance; Video or Discussion flair, link source, memes Monday only | 6–8 Nov, once |
| Wago | Listed as a trusted source by ForeverDB | Not verified | Optional, after 1.0.1 |
| WoWInterface | No Forever evidence found | Not verified | Skip for now |
| Discord servers | Cinematic links its own Discord | Not verified per server | Answer questions only; don't cold-post |
| YouTube | Cinematic embeds a YouTube video in its gallery | n/a (your own channel) | Upload the clip before 3 Nov |

**Dated checklist**

- **Mon 26 Oct:** Rewrite the summary. Push the beta tagged Forever + Retail. Re-run the search controls.
- **Tue 27 Oct:** On Retail, test every untested FileDataID: 539075, 539116, 539064, 539026, 539134, 539106, 539051, 539101, 596024, 1402221, 614975, 645853, 1575952–1575954, 4883319+, 538986–538988. Measure each length and loudness.
- **Wed 28 Oct:** Test the Gamma restore logic on Retail: logout, /reload, disable, a forced Lua error, Alt-F4.
- **Thu 29 Oct:** Shoot the clip and stills. Upload the clip to YouTube.
- **Fri 30 Oct:** Co-install tests with Cinematic and Weather. Add detection: if Cinematic's tint is on, offer to turn ours off.
- **Sat 31 Oct – Sun 1 Nov:** Write the README and the in-game credits. Draft the Reddit post as a title, the clip, three lines of text and the GitHub link.
- **Mon 2 Nov:** Code freeze, then cut an RC.
- **Tue 3 Nov:** Upload v1.0.0 (Forever 1.60.1 and Retail 12.1.5).
- **Wed 4 Nov (23:00 UTC):** Log in on Forever. Smoke-test audio IDs, the indoor fade, Blizzard-weather detection and gamma. Keep `/comfy bug` reports flowing.
- **Thu 5 Nov:** 1.0.1 hotfix if needed.
- **Fri 6 – Sun 8 Nov:** One r/wowforever post (Video flair). Reply to every comment.
- **Mon 9 – Wed 11 Nov:** Triage feedback. Invite-A-Friend week ends on 11 November.
- **Thu 12 – Wed 18 Nov:** Build sound engine v2 and the scene picker. Ship 1.1.0 on 18 November and record downloads and comments as a baseline.

## Audio design spec

Every FileDataID below other than the ones already in use is **untested**.

**Layers**

1. **Weather bed (as built).** RainLight 538983 (20.000 s), RainMedium 538981 (30.000 s), RainHeavy 538982 (25.000 s), and the SnowLight, SnowMedium and SnowHeavy loops. Use two voices per intensity, relaunched 0.4–1.2 s before the clip ends. The relaunch offset is random, and the two voices sit out of phase by half a clip length so their seams never line up.
2. **Scene bed (new; the player picks Plain / Coastal / Plains / Forest storm).** Coastal 539075 (day) and 539116 (night), Plains 539064 (day) and 539026 (night), Forest storm 539134, 539106 (heavy) and 539051 (eerie), Coastal storm 539101. These files already contain rain, so when a scene is on, **drop one of the two plain weather voices** and run the scene bed in its place. That stops rain doubling while keeping a plain rain layer for density. Day or night follows the Time of Day clock. This copies Rainy Mood's four named scenes (Classic, Ocean, Countryside, Café) and myNoise's named presets ("Under the Porch", "Distant Storm", "Under the Leaves").
3. **Scatter one-shots (FMOD "scatterer" model).** Thunder: the 10 existing rumbles plus the 16 `10.0_AMB_Lightning_Thunder_Strike` files (4883319+). Use a random interval between a minimum and maximum, ±2 dB volume jitter, and Wwise-style "avoid repeating the last N": N = 4 for rumbles, 6 for strikes. Pair a strike with a lightning flash only at Heavy intensity, and use rumbles alone for "distant". Snow: the 7 gusts, interval 12–40 s.
4. **Shelter layer.** When the indoor fade triggers, stop relaunching the open-air bed and switch to drips: 596024 and 1402221, and 614975 with its nine siblings, every 3–9 s at low gain. Add 645853 (cave dripping loop) only in caves and tunnels. The API cannot filter sound, so "muffled" here means a bed at lower gain plus drips, not a low-pass filter.
5. **Inn scene (opt-in).** Tavern walla 1575952 (Alliance), 1575953 (Horde) or 1575954 (mixed), whichever matches the player's faction, plus the rain bed 8–10 dB lower and distant rumbles only. It triggers while resting in an inn. Default it off until you have confirmed it doesn't double Blizzard's own inn ambience.
6. **Sandstorm (later).** 538986, 538987 and 538988, mapped to three intensities.

**Timing and mixing**

- **Loudness table.** Measure every file once, offline, from your own client: integrated loudness and peak. Store a gain per file so that `volumeOverride = target − measured`, which brings all beds to one target. This replaces myNoise's equal-loudness calibration, the only way to match files when gain is fixed at play time.
- **Meander.** A Soft Murmur's Meander "gently increases or decreases the volume of each active sound". You can't change gain mid-clip, so give each relaunch a new gain within ±1.5 dB of target. With clips of 20–30 s, that produces slow, never-repeating swells.
- **Overlap bump.** Two uncorrelated rain beds overlapping for about 1 s add roughly 3 dB. Start the incoming voice 1.5 dB under target and alternate which voice relaunches. Listen for it on Retail before shipping.
- **Hide the loop.** Random relaunch offsets, out-of-phase voices and gain jitter together stop any 20/25/30 s period from being audible. Rainy Mood's App Store listing (Plain Theory, Inc.) does the same with an "Algorithmic randomizer and massive sound library for always-fresh sound that never repeats", including "400+ unique thunder claps".
- **No mute tricks.** `MuteSoundFile` would also mute your own copy, so never mute Blizzard's weather files. Keep standing down when Blizzard weather is active.
- **Music off.** Ambience-channel playback reaches players who have music turned off. The music mode must check the music CVar and refuse to play.

## Higher fidelity (question 4)

- **Better than Blizzard?** Unproven. myNoise's point that "it's not the rain itself that makes a noise, it's the sound of it striking a surface" suggests surface-specific recordings (tin roof, tent, leaves) could add textures Blizzard's files lack, but nobody has done a blind comparison. Treat this as a hypothesis.
- **Licences.** Freesound offers CC0, CC BY and CC BY-NC. Use **CC0** first. CC BY works if you keep credits in the README and an in-game credits panel, but some uploaders add their own demands: qubodup's CC BY rain loop asks that software "include a credits screen with working weblinks". **Avoid CC BY-NC.** CurseForge's policy requires licensed content and attribution.
- **Size.** No evidence was found on how large a download players will accept. For reference, Cinematic's whole file was 510.7 KB (v1.5.20). Keep the core addon small and put any bundled recordings in a separate optional companion project. The core then never grows, and the fidelity question can be tested by comparing the two install counts.

## New features ranked (question 5)

| Rank | Feature | Evidence of demand | Competitor coverage | Effort | Still matters after Blizzard weather? |
|---|---|---|---|---|---|
| 1 | Rain soundscape picker and sequencer | Rainy Mood/myNoise scene model; weather teaser coverage | Weather: indoor ambience only, flagged broken on Forever; Weather Forever Seasons claims weather sounds (unverified) | M–L | Yes: works anywhere, on demand |
| 2 | Inn and shelter scenes | Cozy niche; NightIllusion users praised indoor behaviour ("makes indoors cozy", MMO-Champion 2016, anecdote) | Cinematic: "warm glow in inns" (visual only) | M | Yes |
| 3 | Scene schedules (e.g. rain at night, snow in December) | Seasons thread (wants) | None found | S | Yes |
| 4 | Gamma "brighter nights" (opt-in) | No direct demand found; darker-night overlays did draw installs (NightIllusion 11.3K installs, project last updated 2013) | Cinematic tints, no gamma | M | Yes, but risky |
| 5 | Fog overlay | Blizzard's teaser itself showed fog | Cinematic vignette; Blizzard fog | M | Partly: overlaps Blizzard |
| 6 | Falling leaves | Seasons thread (wants) | Weather Forever Seasons (102 installs, 24 Oct) | M | Yes, unless Blizzard adds seasons |
| 7 | Droplets on the lens | None found | Weather Forever Seasons "wet screen" (claimed) | M | Yes |
| 8 | Fireflies | None found | None found | S–M | Yes |
| 9 | Sandstorm | Blizzard files exist (538986–538988) | Weather tints for sandstorm | S | Partly |
| 10 | Ash and embers | None found | None found | M | Yes, niche |
| 11 | Opt-in music mode | Forever Ambient Music Extended, 133 installs (13 Oct) | That addon | M | Yes, low demand |
| 12 | Underwater fade | None found | None found | S | Yes, small |
| new | Campfire crackle near Forever campsites | Forever's Camping system (guide sites); Cinematic has a campfire button | Cinematic (visual/camera only) | M (needs fire IDs, untested) | Yes |

## Gamma, done safely (question 6)

- **Persistence.** Per warcraft.wiki.gg, CVars "are not saved to Config.wtf until properly logging out or reloading the game", and character- and account-scoped CVars "are stored server-side depending on CVar synchronizeConfig". Wowpedia warns that such changes "cannot be undone… by uninstalling… or deleting the WTF folder". Whether Gamma itself is a local or a synced CVar is **unverified**. Posts in the 2023 thread blamed lines going missing from Config.wtf, which hints that it is stored locally.
- **Restore pattern.** This is the wiki's own recommendation. On enable, read and save the player's value in SavedVariables. Restore it on `PLAYER_LOGOUT`, which fires on a clean logout and on /reload. If the player changes gamma in the System menu while the effect is active, adopt their new value as the one to restore. Set a "dirty" flag on login and clear it on logout. If the flag is still set at the next login, the session crashed, so restore immediately.
- **Disable, error, uninstall.** Disabling in the addon list takes effect only at the next login, so the logout restore covers it. Wrap every SetCVar in pcall and restore on any error. Code cannot run after an uninstall, so the real protection is never letting the changed value reach disk: restore on every logout. Add `/comfy gamma reset` and print the player's original value in chat the first time the effect is turned on. DayNight (136 installs, 2015) told users to type `/run SetGamma(0)` after uninstalling. That is the failure mode to avoid.
- **Player reaction.** Little evidence. DayNight had 136 installs and needed exclusive fullscreen. A 2013 WoWInterface request rejected gamma outright: "It's not a question of turning down gamma… that dims everything." The 2023 complaints were about gamma resetting, caused by other addons, and none named a gamma addon. Interpretation: players accept screen effects but resent changes to their own settings, so keep this opt-in and say plainly that it changes your gamma.

## Where we lose (question 7)

- **To Weather:** players who want the addon to *react* to Blizzard's actual weather (its tint scales with real intensity), who like collecting (the almanac), or who want accessory reminders and freefall wind. keyboardturner is also an established author. **What makes them switch:** rain whenever they want it, and audio that works on Forever, since Weather's own notes flag indoor ambience as not playing there.
- **To Cinematic:** players who want one all-in-one immersion addon: UI fade, letterbox, cameras, a time-of-day tint, a Discord, near-daily updates and 8,992 installs of social proof. **What makes them switch:** mostly they won't. They will *co-install*. Make Comfy Rain an obvious companion: detect Cinematic, offer to hand over the tint, and say "works with Cinematic" in the description.

## Caveats

- Forever cannot be played before 4 November, so all Forever audio and gamma behaviour stays unverified until launch night.
- Most launch-timing advice here is reasoning, not measured evidence.
- Download figures are CurseForge totals across all flavours. CurseForge does not split them by Forever and Retail.

## What could not be verified

- Wago's and WoWInterface's Forever support and self-promotion rules; the rules of specific Discord servers.
- How long CurseForge takes to review a new file.
- Weather Forever Seasons, Azeroth Alive and Forever Ambient Music Extended. My search for Weather Forever Seasons returned nothing relevant, although a similar query did return Weather by keyboardturner as a positive control.
- Whether any of the untested FileDataIDs exist on Forever or Retail.
- Whether Gamma is a local or a server-synced CVar, and whether it works on Forever.
- How large a download players will accept, and whether bundled recordings sound better.
- The warcraft.wiki.gg pages for API_SetGamma and CVar_Gamma could not be retrieved.

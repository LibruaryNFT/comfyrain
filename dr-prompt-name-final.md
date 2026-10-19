# Settle the name of a WoW addon shipping 4 November 2026, in one pass

I have a finished World of Warcraft addon. It has been renamed twice in six days and is
currently called **Comfy Rain**. I want the name settled permanently before 27 October,
when CurseForge name reservation opens, and I want it settled by evidence rather than by
another round of taste.

Read **Verified facts** as established ground truth. It was obtained by extracting strings
from the client binary with a positive control, by downloading and reading competitors'
source, by running CurseForge's own search page, and by checking primary sources on the
dates stated. **Do not re-derive it, do not contradict it without evidence stronger than a
page I can load myself, and do not spend a paragraph restating it back to me.** Four prior
research rounds burned most of their budget re-answering settled questions.

The work I want is in **What to actually research**. Weight your effort by the percentages.

Today is 19 October 2026.

---

## Verified facts, do not re-research these

### The three fixed dates

| Date | Event |
|---|---|
| 21 October 2026 | Beta client withdrawn. 2 days of client access left from today |
| 27 October 2026 | CurseForge name reservation opens |
| 4 November 2026, 3pm PST | WoW: Forever launches |

It is a **WoW: Forever** client, build `1.60.1.70425`, TOC `16001`. It installs to
`_classic_beta_` but it is the **Mainline API family**, not Classic Era. No reliable
population figure for Forever exists; the "600,000" in circulation is a peak Twitch
*viewer* count. Do not try to reconcile the numbers.

### What the product actually is

A pure-Lua addon, zero dependencies. It draws rain or snow on demand, anywhere, for as
long as the player wants, on top of whatever weather the server is running.

- Three parallax rain or snow sheets drawn on a `WorldFrame` child, scrolling, with yaw
  parallax and a speed-reactive shear.
- A MOD-blend fullscreen quad that darkens the world, plus time-of-day colour grading.
- Lightning and thunder.
- An audio bed that plays **Blizzard's own weather loops by FileDataID**, two beds of
  unequal length under each other, with wind gusts. Nothing is redistributed.
- Fades down indoors instead of raining on the ceiling.
- A settings window, and slash commands that the window echoes back so players learn them.
- 159 specs running the addon under stock Lua 5.1 against a mock of the WoW API.

**The visual half is finished and the audio half is barely started.** Scope is frozen: it
ships as a weather and ambience overlay, not as the "mood engine" earlier rounds discussed.
Do not propose scope changes. The name has to fit *this*, not a roadmap.

### The visual ceiling is hard, low and settled. Do not research it.

An addon cannot touch world lighting, world fog, the framebuffer, the camera, or the
skybox. There is no weather setter. MOD blend over a 2D sheet is the only way to change
the world's brightness and it can only darken. **Skyboxes were put to three independent
research rounds and came back impossible three times for three.** Blizzard's own rain is
3D particles in world space with depth, occlusion and splashes, and this will never be in
that category. None of this is in scope for your answer; it is here only so you understand
that the name must not promise depth, 3D, lighting or sky.

### The name history, and the rule each dead candidate produced

Every check below used **`https://www.curseforge.com/wow/search?search=<term>`**, which is
CurseForge's own fuzzy matcher and therefore shows what a user's search would actually
surface. The API returns 403 behind Cloudflare. A `site:` query is not a substitute: one
was silently ignored by a search backend and produced a meaningless negative.

| Name | Status | Why it died |
|---|---|---|
| `AlwaysRain` | dead 2026-10-14 | promises permanence, caps the product at rain, no brand |
| `Cozy Azeroth` | dead 2026-10-13 | **existing creator brand**: YouTube channel "Zachary Fruhling (Fruhling Designs / CozyAzeroth)", same game, same cozy and housing niche, identical string |
| `Evermood` | dead 2026-10-14 | **no name may contain `ever`.** Searching *reverie* returned 1,207 projects, almost all Forever addons, because the fuzzy match catches `ever` inside `Forever` |
| `Overcast` | dead 2026-10-14 | **no name may contain a WoW mechanic word.** Free as a name, but the search returns 32 castbar addons. To a WoW player *cast* means spellcasting |
| `Cozy Echoes` | dead 2026-10-14 | keeps a prefix that is not doing distribution work, and caps the product at audio |
| `Hearthlight` | dead 2026-10-13 | grazes the Hearthstone trademark, in an addon whose legal position rests entirely on Blizzard's goodwill |
| `CozyWeather`, `AzerothAmbience`, `Azeroth Mist` | dead 2026-10-13 | each re-caps the product at one of its halves |
| `ComfyVibes` | dead 2026-10-13 | see the comfy/cozy finding below |
| `Gloaming` | chosen 2026-10-14, **killed the next day on comprehension** | clean on collisions (1 unrelated project) and native WoW vocabulary, but literary British English that a mid-twenties American player may not parse or spell |
| `Duskfall` | shipped 2026-10-14, **replaced 2026-10-19** | clean on collisions in the channel that matters, but carries no search weight: nobody types "duskfall", and it does not say what the addon does |
| `Comfy Rain` | **current, and the thing you are attacking** | 0 projects returned, control `CozyFire` = 1. Chosen for searchability on "rain" plus a memorable modifier |

### The one finding that directly contradicts the current name

This is the crux and I want it resolved, not repeated.

On 2026-10-13, **two of three research reports found with evidence that *cozy* is native to
this audience and *comfy* is not.** The stated evidence was the in-game item **Cozy Sleeping
Bag** and WoW's housing content using "cozy", against "comfy" reading as imageboard and
Twitch slang. One of the seven points all three reports agreed on was literally
**"'Cozy', not 'comfy'"**.

**Comfy Rain was then chosen on 2026-10-19 without that finding being re-read.** It may
still be the right name, because the 2026-10-13 finding was about *`Comfy` as a brand
prefix competing in a crowded `Cozy*` category*, and "Comfy Rain" is a different shape: a
descriptive noun carrying the search weight with the modifier doing the memorability. Or
the finding may simply kill it. I do not know which, and guessing again is how I got here.

Also relevant and verified: all three `Cozy*` addons on CurseForge sit in the hundreds of
downloads (Cozy Companion ~571-990, CozyCamps ~471, **CozyFire 732, flavour Forever,
updated 13 Oct 2026**), while the Forever-native addons that actually move carry no such
prefix. **Spoken Player did 97,856 downloads in 24 days on this client.** The `Cozy*`
prefix is not doing distribution work.

### What the competitive field looks like, read directly

| Addon | Downloads | Note |
|---|---|---|
| Dynamic Weather | 20,860 lifetime | abandoned 2021, the best ever in this category |
| keyboardturner's Weather | ~2,300 lifetime | reacts to server weather, does not fake it |
| Dynamic Azeroth Weather | 359 in 6 months | near-identical feature list to ours |
| Spoken Player | 97,856 in 24 days | Forever-native, not a weather addon |

Honest download ceiling for this product, from two of three reports: **low hundreds in 90
days.** The third said 3,000-8,000 and was internally inconsistent. The name cannot fix
that and I am not asking it to. I am asking it not to make it worse.

### Constraints on any name you propose

1. **No substring `ever`.** The client is called Forever and that substring is the most
   polluted in the namespace.
2. **No WoW mechanic word** (cast, proc, pull, tank, aggro, crit, dot, rez...).
3. **Must not graze a Blizzard trademark.** Hearthstone, Warcraft, Azeroth-as-a-brand.
4. **Must not cap the product at one half.** It is weather *and* ambience, rain *and* snow.
5. **Must survive being heard once in a Discord voice call and typed correctly afterwards.**
6. **Must not promise 3D, depth, lighting, sky or anything the engine ceiling forbids.**
7. The folder name is the only expensive field. **No public release exists yet**, so even
   the folder is still free to change today and will not be after 4 November, because the
   SavedVariables file is named after the folder and renaming it orphans every user's
   settings.
8. Folder, TOC `## Title` and CurseForge store title are allowed to differ. Only the folder
   is irreversible.

### Two method notes, so they are not repeated

- **`curl` against a Twitch or YouTube channel URL is not an existence check.** It returns
  HTTP 200 for a channel that cannot exist; a nonsense control handle also returned 200.
- **A prior consult produced fabrications**: that addon managers "list alphabetically then
  rank by download count", a "Nihilum UI was also a popular forum user" precedent, and a
  "62% of forum threads" statistic. All discarded. Any claim of that shape in your output
  needs a loadable source or it will be thrown out.

---

## What to actually research

### A. Resolve comfy versus cozy, with evidence (30%)

This is the highest-value question because it decides the current name and no one has
actually tested it.

- **Is "comfy" read as imageboard or Twitch slang by WoW players specifically, in 2026?**
  The 2026-10-13 claim was asserted by two language models and never checked against real
  usage. Go and look: Reddit (r/wow, r/classicwow, r/woweconomy), the official forums,
  Wowhead comments, Discord servers you can read, YouTube titles and comments. Count
  occurrences of each word in WoW contexts and report the counts with the date and the
  query. **A negative result needs a positive control: show the same method returning hits
  for a word you know this audience uses.**
- **Does WoW itself use either word?** The Cozy Sleeping Bag item is the cited evidence for
  "cozy". Find every in-game item, spell, achievement, housing object or quest text using
  "cozy" or "comfy", with Wowhead IDs. If "comfy" appears in-game at all, the 2026-10-13
  finding is wrong and I need to know.
- **Which word do the actual cozy-gaming and cozy-WoW communities use to describe
  themselves?** Subreddit names, Discord server names, YouTube channel names, stream
  categories. Names people chose for themselves are better evidence than usage in sentences.
- **Verdict in one word: comfy or cozy.** Then say whether that verdict alone is enough to
  change the addon's name, or whether "Comfy Rain" survives it because the noun is carrying
  the search weight.

### B. Attack "Comfy Rain" on everything except that word (25%)

Adversarial. I want the case against, found rather than reasoned.

- **Run every collision check on the exact strings `Comfy Rain` and `ComfyRain`**:
  CurseForge, WoWInterface, Wago.io, GitHub, Twitch, YouTube, Reddit, the trademark
  registers, the iOS and Android stores, and plain web search. Report each as "checked X on
  date Y, found Z", never as a conclusion. Show a positive control alongside every zero.
- **Is there a non-WoW "Comfy Rain" product?** Rain-sound apps, lo-fi channels, sleep and
  white-noise apps and Spotify playlists are the obvious risk, and they are exactly the
  category a search engine would blend us into. Quantify how crowded that is.
- **What does a player actually type when they want this?** Work out the real query set:
  "rain", "weather", "dynamic weather", "ambience", "atmosphere", "cozy"? If the brand word
  carries no search load and the noun carries all of it, say so, because that changes
  whether the modifier matters at all.
- **Does "Rain" in the title cost us the snow half?** The addon does snow equally well.
  Determine whether a CurseForge title of the form `Comfy Rain: Rain, Snow and Cozy
  Ambience` recovers the snow keyword, or whether the folder word poisons it.
- **Would a two-word name with a space hurt anywhere mechanical** — addon manager sorting,
  CurseForge slug, folder naming conventions, Wago imports?

### C. Give me the replacement, or confirm there is none (25%)

- **One name. Not a shortlist.** If "Comfy Rain" survives A and B, say "keep" in one word
  and skip to D.
- If it does not survive, propose exactly one replacement and **run it through all eight
  constraints above and every collision check in B**, showing the results in the same
  table format. A proposal without its collision table is unusable to me.
- **Say explicitly which field each part of your recommendation applies to**: folder, TOC
  title, CurseForge store title, slash command, SavedVariables global. These are allowed to
  differ and I would rather have a plain folder name and a rich store title than one
  compromise string in all five.
- **Weigh renaming cost honestly.** This would be the third rename in a week. There is no
  public release yet, so the mechanical cost is one afternoon and no user is orphaned. The
  cost I cannot measure is my own confidence. Tell me whether the evidence is strong enough
  to justify moving again, or whether the right call is to stop and ship a merely adequate
  name. **"Keep the current name because changing again looks indecisive" is a legitimate
  answer if you believe it; say so plainly rather than inventing a reason it is optimal.**

### D. The CurseForge title and summary, which carry the real search load (15%)

Separate from the name, and possibly more important than it.

- **What is the maximum useful length** of a CurseForge project title and summary, and what
  is actually indexed by their search?
- **Write the title and the one-line summary**, optimised for the query set you found in B.
  Give me the literal strings, ready to paste.
- **Which CurseForge category and tags** should this ship under, and does category choice
  measurably affect discovery in the first two weeks?
- **Does the project's first 14 days determine its ceiling**, and does launching on 4
  November with the client rather than a week later matter? Evidence, not folklore.

### E. The thing I have not thought of (5%)

Briefly, and only things that survive every constraint above. Not a restatement.

---

## Output format

Five sections matching A to E, plus:

1. **Corrections** at the top: anything in Verified facts that is wrong, with the evidence.
   If nothing is wrong, say "none" in one line and move on.
2. **Unverified** at the end: every claim you could not establish, each with the specific
   check that would settle it.

Rules:

- Lead each section with the verdict, then the evidence. No preamble.
- Numbers go in tables, with the source and the date observed.
- Download counts, dates and licences are stated as observed on a given date, never as
  general knowledge.
- **A negative result needs a positive control shown alongside it.** "I found no X" is only
  publishable as "the method finds X when X exists, and here it found none".
- Where sources conflict, say so and say which you believe and why. Do not average them.
- One recommendation per question, not a menu. I will act on it.
- No em-dashes.

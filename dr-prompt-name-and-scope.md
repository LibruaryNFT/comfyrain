# Kill the name, or confirm it: a WoW addon shipping 4 November 2026

I have a working World of Warcraft addon that makes the world permanently rainy, dark and
cosy. I am reframing it from a weather addon into a **mood engine**, where scheduled audio
is the primary product and the visuals are one of its outputs. I have chosen the name
**Gloaming**. The folder name is irreversible after launch, so I want it attacked before I
commit, and I want the product scope around it pressure-tested at the same time.

Read **Verified facts** as established ground truth. It was obtained by extracting strings
from the client binary with a positive control, by downloading and reading competitors'
source, by running CurseForge's own search, and by checking primary sources on the dates
stated. **Do not re-derive it, do not contradict it without evidence stronger than a string
in the executable or a page I can load myself, and do not spend a paragraph restating it
back to me.** Two prior research rounds burned most of their budget re-answering settled
questions.

The work I want is in **What to actually research**. Weight your effort by the percentages.

Today is 14 October 2026.

---

## Verified facts, do not re-research these

### The client and the three fixed dates

It is a **WoW: Forever** client, build `1.60.1.70338`, TOC `16001`. The binary identifies
itself as `wow-forever-client`. It installs to `_classic_beta_` but it is the **Mainline API
family**, not Classic Era. Do not reason about it as a Classic addon environment.

| Date | Event |
|---|---|
| 21 October 2026 | Beta client withdrawn. 7 days of client access left from today |
| 27 October 2026 | Name reservation opens |
| 4 November 2026, 3pm PST | Launch |

No reliable population figure exists for Forever. The "600,000" in circulation is a peak
Twitch *viewer* count and the "37,470" is a third-party algorithm's output. Do not try to
reconcile them.

### What is built and working today

- Three parallax rain sheet layers over `WorldFrame`, scrolling, with yaw parallax from
  `GetPlayerFacing` and a speed-reactive shear.
- A **MOD-blend** fullscreen gloom quad. MOD multiplies the finished frame.
- Time-of-day colour grading: a MOD quad plus an ADD lift capped at 0.13 alpha, driven by an
  apparent-hour clock that can be the realm's, the player's local time, a fixed offset, or a
  fixed hour.
- Lightning with ADD flashes and thunder.
- An audio bed preferring Blizzard's own weather audio by FileDataID, with indoor and
  outdoor switching.
- Slash commands only. No GUI.
- Zero dependencies, zero libraries, two generated 512px TGAs.
- A 50-spec test suite running the addon under stock Lua 5.1 against a mock of the WoW API,
  all green as of 13 October 2026. It asserts the addon's own logic. It cannot tell me
  whether anything looks or sounds right.

### The visual ceiling is hard and low. This is settled.

An addon cannot touch world lighting, world fog, the framebuffer, or the camera. There is no
weather setter. `SetFogColor`, `SetLight`, `SetFogNear` and `SetFogFar` exist but are
**Model widget** methods, not world setters. `GetCameraPitch` is absent from the binary, so
vertical parallax is impossible.

**MOD blend over a 2D sheet is the only way an addon can change the world's brightness, and
it can only ever darken, never brighten.** Blizzard's own rain is 3D particles in world
space with correct depth, occlusion and splashes. I will never be in that category and it is
not worth researching further.

### The audio ceiling is much higher, and that is the reason for the question

Probed in the 1.60.1.70338 binary on 2026-10-12, `GetUnitSpeed` = 2 hits as the positive
control:

| Symbol | Hits | Significance |
|---|---|---|
| `C_Sound.PlaySoundWithOptions` | 1 | Takes a params table, not a bare call |
| `volumeOverride` | 1 | **Per-sound volume** |
| `runFinishCallback` | 1 | Fires when a sound ends. The sequencing primitive |
| `C_Sound.IsPlaying` / `GetSoundScaledVolume` | 1 / 2 | Query a live handle |
| `MuteSoundFile` / `UnmuteSoundFile` | 3 / 3 | Silence specific Blizzard files by FileDataID |
| `PlayMusic` / `StopMusic` | 2 / 1 | The music channel, separate from SFX and Ambience |
| `Sound_EnableMusic` / `_EnableAmbience` / `_EnableSFX` | 1 each | Per-channel suppression |

`volumeOverride` and `runFinishCallback` are **adjacency in the C_Sound string region, not a
declared struct.** They need `/dump C_Sound` on a live client before anything is built on
them. Everything else above is a named global.

### The hard constraints on the audio product

- **No HTTP in the addon sandbox, ever.** "Radio station" cannot mean internet radio.
- **No bundled music.** Shipping audio is redistribution and the most reliable way to get an
  addon pulled.
- What is left is a **programme director over the player's own installed Blizzard library**,
  addressed by FileDataID. That redistributes nothing and is the same mechanism the rain bed
  already uses. Add `MuteSoundFile` to suppress what the engine would have played,
  `runFinishCallback` to sequence, `volumeOverride` to mix.
- **Ambience, not music, is the default channel**, because `Sound_EnableMusic = 0` is common
  among this audience and a music station cannot reach those players at all.

### The development asymmetry, which is the core product thesis

| Half | State | Work remaining, ever |
|---|---|---|
| Visual | Essentially finished | ~2 weeks |
| Audio | Barely started | Months: sequencing engine, zone and biome and time map over Blizzard's library, bed mixing, crossfades, `MuteSoundFile` suppression |

Defensibility is **context, not fidelity**. The real competitor is a second browser tab
playing lo-fi, which has unlimited content and zero setup, and which cannot know the player
just walked into an inn at 2am in the rain. Honest download ceiling: low tens of thousands.

### The competitive field, read directly

- Dynamic Weather (20.7k downloads, 2021), Dynamic Azeroth Weather (358), Weather by
  keyboardturner (2.3k, all rights reserved), RainingBlood, ImmersiveWeather, DayNight.
  **Not one of them calls `SetBlendMode`.**
- **FAME**, Forever Ambient Music Extended (project 1728351, kirillburton, Forever-only).
  All 2,731 Lua lines downloaded and read on 2026-10-13. It is a zone-music track-pool
  expander: 408 extra Blizzard tracks tagged by biome, culture and mood, chosen by location,
  deliberately preserving Blizzard's own schedule and silences. Verified by grep:
  **`PlayMusic` only, 16 calls. Zero occurrences of `C_Sound.*`, `volumeOverride`,
  `runFinishCallback`, `MuteSoundFile`, `StopSound`, "ambience", "weather", "rain",
  `SetBlendMode` or `CreateTexture`.** Time of day is a binary night check.
  It is a positive control proving FileDataID scheduling works on a live Forever client
  today, and it is not this product.
- **Forever-native addons move fast.** Spoken Player did 97,856 downloads in 24 days. A
  `MuteSoundFile`-based addon is at 283,116. Resonance at 9,612.

### The name work already done, 2026-10-13

**The instrument:** `https://www.curseforge.com/wow/search?search=<term>`. The CurseForge
API returns 403 behind Cloudflare, but the search page loads and is CurseForge's own fuzzy
matcher, so it shows what a user's search would actually surface. Use this, not a `site:`
query, which was silently ignored by a search backend and produced a meaningless negative.

**`Cozy Azeroth` was the previous choice and is dead:**

| Check | Result |
|---|---|
| Is `CozyAzeroth` a creator brand? | **Yes.** YouTube channel "Zachary Fruhling (Fruhling Designs / CozyAzeroth)", videos "CozyAzeroth: Casual WoW & Housing Decor Hunt" and "CozyAzeroth: Casual Sunday WoW". Same game, same cosy and housing niche, identical string |
| Is `Cozy*` crowded on CurseForge? | **Yes.** Cozy Companion (~571 to 990 downloads), CozyCamps (~471), **CozyFire (732 downloads, flavour Forever, author Synse, game version 1.60.1, updated 13 Oct 2026)** |
| Is any addon named Cozy Azeroth? | No. The collision is a brand and a prefix, not an addon |

**Three further candidates died, each producing a reusable rule:**

1. **Evermood** → **no name may contain the substring `ever` on this client.** Searching
   *reverie* returned **1,207 projects**, almost all Forever addons, because the fuzzy match
   catches `ever` inside `Forever`. `Evermore UI` and `Forevermore Classic UI` also exist.
2. **Overcast** → **no name may contain a WoW mechanic word.** Free as a name, but the
   search returns 32 castbar addons. To a WoW player *cast* means spellcasting.
3. **Cozy Echoes** keeps the dead prefix and caps the product at audio.

**Also previously rejected:** Hearthlight (grazes the Hearthstone trademark, in an addon
whose legal position rests entirely on Blizzard's goodwill), CozyWeather (re-caps at
weather), AzerothAmbience (caps at audio), ComfyVibes ("comfy" reads as imageboard and
Twitch slang where "cozy" is WoW-native per the Cozy Sleeping Bag item; "vibes" carries no
search weight), Azeroth Mist (re-caps at one weather type).

**The current choice:**

| Field | Value |
|---|---|
| Folder, **irreversible** | `Gloaming` |
| TOC `## Title` | `Gloaming` |
| CurseForge title | `Gloaming: Weather, Ambience and Time of Day` |
| Slash | `/gloam`, with `/rain` kept as a permanent alias |
| SavedVariables | `GloamingDB`, migrating from `AlwaysRainDB` on first load |

Why: MOD blend can only darken, so the product is structurally the dim one and *gloaming* is
the quality of dim light itself. It caps nothing, being neither a weather type nor an audio
word. It is native WoW vocabulary: Gloaming Reef (zone 8017), Gloaming Powder (spell
290031), Gloaming Veil (spell 1254722), The Gloaming Blade (item 88149), Greatshield of the
Gloaming (item 94945), Shield of the Gloaming (item 216586), Gloaming Alloy (item 238202).
By the CurseForge instrument, *gloaming* returns **1 project, unrelated** (a herb and mining
tracker). No creator brand found.

**Stated residual risk:** Gloaming Alloy is a **Midnight-expansion crafting reagent**. If
*Gloaming* becomes a prominent retail-expansion term, general web search for the word could
crowd later. Accepted on the grounds that it does not affect CurseForge addon search.

**Only the folder name is expensive to change.** Renaming it orphans every user's
SavedVariables, because the file is named after the folder. The displayed title, CurseForge
title and description are all free to revise later. Folder, TOC title and store title are
allowed to differ.

### Two method notes, so they are not repeated

- **`curl` against a Twitch channel URL is not an existence check.** It returns HTTP 200 for
  a channel that cannot exist. A nonsense control handle also returned 200. The CozyAzeroth
  brand finding rests on the YouTube channel name and video titles, not on a status code.
- **A prior consult produced fabrications**, specifically that addon managers "list
  alphabetically then rank by download count", a "Nihilum UI was also a popular forum user"
  precedent, and a "62% of forum threads" statistic. All discarded. Any claim of that shape
  in your output needs a loadable source or it will be thrown out.

### What all three prior research reports agreed on, treat as settled

1. Ambience is the default and music is opt-in. Music-off is common and the stated cause is
   repetition, not dislike.
2. One addon, not two. The same inputs drive all outputs, so splitting risks the visual and
   audio rain desynchronising.
3. The second browser tab is the real competitor and context is the only edge.
4. Brand plus descriptive subtitle. CurseForge has ~31k WoW projects and search is the
   primary vector.
5. "Cozy", not "comfy".
6. User-supplied OGGs are a power-user tail. Support a folder, never depend on it.
7. **Micro-sequencing is the world-class feature**, proposed independently by all three:
   chain and vary beds via `runFinishCallback` instead of looping one file, which is what
   myNoise's Animate and Noisli's oscillation do.

---

## What to actually research

### A. Kill Gloaming, or confirm it (35%)

Your job here is adversarial. I want the case against, found rather than reasoned.

- **Run the collision checks I ran, plus the ones I did not.** CurseForge, WoWInterface,
  Wago.io, GitHub, Twitch, YouTube, Reddit, trademark registers, and the generic app stores.
  Report each as "checked X on date Y, found Z", not as a conclusion. **A negative result is
  only publishable if you show the same method returning hits for a term you know exists.**
- **Does *gloaming* read as a word to this audience, or as an obscure one?** It is literary
  British English. I need to know whether a mid-twenties American WoW player parses it, and
  whether they can spell it after hearing it once in a Discord voice call. Evidence, not
  intuition.
- **How much does the Midnight reagent actually threaten it?** Find the current search
  volume and the Wowhead and Icy Veins coverage of Gloaming Alloy, and predict what the term
  looks like six and twelve months after Midnight ships. Say whether this moves the
  recommendation.
- **Is "Gloaming" a liability in the one place that matters, which is addon-manager
  search?** Work out what strings a user actually types when they want this product. If the
  answer is "rain", "weather", "dark" and "ambience", then the brand carries no search load
  at all and the subtitle carries all of it, which changes how the subtitle should be
  written.
- **Give me a verdict in one word: keep or change.** If change, give exactly one
  replacement, run it through every rule above including the `ever` and mechanic-word rules,
  and show the collision checks for it. Do not give me a shortlist.

### B. How an addon is actually discovered on Forever in November 2026 (25%)

This decides the entire launch plan and I have no reliable data on it.

- **What is the real discovery mix** for a new WoW addon in 2026: CurseForge keyword search,
  category browse, addon-manager search, Reddit, YouTube, Twitch, Discord, word of mouth.
  Weight them with evidence.
- **Is a fresh-client launch different?** Forever launches 4 November with no installed base
  of addons and presumably a surge of players looking for the ones they are used to. Find
  precedent: TBC Classic, Wrath Classic, Season of Discovery, Cataclysm Classic. What
  happened to addon downloads in the first 14 days of each, and which addons won?
- **Spoken Player did 97,856 downloads in 24 days on this client.** Find out how. That is
  the single most useful data point available and I only have the number.
- **What does the CurseForge ranking algorithm actually reward** in a project's first two
  weeks: upload date, update frequency, download velocity, description completeness, images,
  category choice. Anything documented or empirically established, not folklore.
- **Does the launch-day window matter as much as I think?** I am planning to ship on 4
  November. Tell me whether day one, day seven or day thirty is the slot that actually
  determines the ceiling, and what the cost of shipping a week late is.

### C. What the first release must contain, given the asymmetry (25%)

The visual half is done and the audio half is months away. All three prior reports said
"ship visuals on 4 November, add audio later", which ships the weak half first. My current
call is **visuals plus one ambience bed**, which is close to what exists today.

- **Attack that call.** Is a visual-only or visual-plus-bed release on launch day better or
  worse than waiting until the sequencer exists? Argue both, pick one.
- **What is the minimum audio feature that is recognisably not FAME and not a looped file?**
  I need the smallest thing that demonstrates the thesis, not the full station.
- **What does the sequencer have to do to beat loop fatigue?** myNoise's Animate and
  Noisli's oscillation are the converged commercial answer after fifteen years. Specify the
  behaviour concretely enough to implement: how often beds change, how long a crossfade is,
  how much variation is enough before a listener notices repetition, whether silence is part
  of it.
- **How much of Blizzard's own library is actually beloved rather than tolerated?** Which
  ambience and tavern and zone audio do players seek out, make YouTube playlists of, or ask
  addons to replay? Name specific files or tracks if you can.
- **What does the existing user of a rain addon lose** when it becomes a mood engine, and
  what is the migration that does not annoy them? The post-rename default must behave exactly
  as today.
- **Is there a sentence this product is for?** If it cannot be said in one, it is two
  products and I want to know that now.

### D. The things that would embarrass me, found before they happen (10%)

- **Licensing and policy.** Playing Blizzard's shipped audio by FileDataID redistributes
  nothing, but confirm that against Blizzard's current addon policy as published, not as
  remembered. Find any case of an addon pulled for audio.
- **Is a mood engine the sort of addon that gets broken by a patch?** Which of the APIs I
  depend on have changed or been restricted in the last three years, and what is the blast
  radius of each.
- **Anything in Verified facts that is actually wrong.** Name it with the evidence.

### E. The thing I have not thought of (5%)

Briefly, and only ideas that survive every constraint above. Not a restatement of the
feature list.

---

## Output format

Five numbered sections matching A to E, plus:

1. **Corrections** at the top: anything in Verified facts that is wrong, with the evidence.
   If nothing is wrong, say "none" in one line and move on.
2. **Unverified** at the end: every claim you could not establish, each with the specific
   check that would settle it.

Rules:

- Lead each section with the verdict, then the evidence. No preamble.
- Numbers go in tables with their source and the date observed.
- Download counts, dates and licences must be stated as observed on a given date, never as
  general knowledge.
- A negative result needs a positive control shown alongside it. "I found no X" is only
  publishable as "the method finds X when X exists, and here it found none".
- Where sources conflict, say so and say which you believe and why. Do not average them.
- One recommendation per question, not a menu. I will act on it.
- No em-dashes.
- Any currency figure in CAD as well.

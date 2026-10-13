# Is there a product here, and what already serves it?

I have a working World of Warcraft addon that makes it rain permanently and grades the
sky by time of day. I am considering reframing it from a weather addon into something
broader: a **mood engine** where audio is the primary product and the visuals are one of
its outputs. I want to know whether that is a real product, who already serves the demand
it would serve, and what it should be called.

Read the **Verified facts** section as established ground truth. It was obtained by
extracting strings from the client binary with a positive control, by reading competitors'
source directly, and by checking primary sources. **Do not re-derive it, do not contradict
it without new evidence stronger than a string in the executable, and do not spend a
single paragraph restating it back to me.** A prior round of research wasted most of its
budget re-answering things that were already settled.

The research I want is in **What to actually research**. Weight your effort by the
percentages given there.

---

## Verified facts — do not re-research these

### The client

It is a **WoW: Forever** client, build `1.60.1.70338`, TOC `16001`. The binary identifies
itself as `wow-forever-client`. It installs to `_classic_beta_` but it is the **Mainline
API family**, not Classic Era — do not reason about it as a Classic addon environment.

Beta ran 17 September to **21 October 2026**. Launch is **4 November 2026**, 3pm PST. Name
reservation opens 27 October. Today is 12 October 2026, so beta client access ends in nine
days. No reliable population figure exists; the "600,000" number in circulation is a peak
Twitch *viewer* count and the "37,470" is a third-party algorithm's output. Do not try to
reconcile them.

### What is built and working

- Three parallax rain sheet layers over `WorldFrame`, scrolling, with yaw parallax from
  `GetPlayerFacing` and a speed-reactive shear.
- A **MOD-blend** fullscreen gloom quad. MOD multiplies the finished frame.
- Time-of-day colour grading: a MOD quad plus an ADD lift capped at 0.13 alpha, driven by
  an apparent-hour clock that can be the realm's, the player's local time, a fixed offset,
  or a fixed hour.
- Lightning with ADD flashes and thunder.
- An audio bed of five pre-baked gain variants, indoor/outdoor switching, and preference
  for Blizzard's own weather audio by FileDataID.
- Slash commands only. No GUI.
- Zero dependencies, zero libraries, two generated 512px TGAs.

### The visual ceiling is hard and low. This is settled.

An addon cannot touch world lighting, world fog, the framebuffer, or the camera. There is
no weather setter. `SetFogColor`, `SetLight`, `SetFogNear` and `SetFogFar` exist but are
**Model widget** methods, not world setters. `GetCameraPitch` does not exist in the binary,
so vertical parallax is impossible. MOD blend over a 2D sheet is the *only* way an addon
can darken the world.

Blizzard's own rain is 3D particles in world space with correct depth, occlusion and
splashes. **We will never be in that category and this is not worth researching further.**

### The audio ceiling is much higher. This is the reason for the question.

Probed in the 1.60.1.70338 binary, `GetUnitSpeed` = 2 hits as the positive control:

| Symbol | Hits | Significance |
|---|---|---|
| `C_Sound.PlaySoundWithOptions` | 1 | Takes a params table, not a bare call |
| `C_Sound.PlaySound` | 1 | Same |
| `volumeOverride` | 1 | **Per-sound volume** |
| `runFinishCallback` | 1 | Fires when a sound ends — a sequencing primitive |
| `C_Sound.IsPlaying` | 1 | Query a live handle |
| `C_Sound.GetSoundScaledVolume` | 2 | Read a handle's volume |
| `MuteSoundFile` / `UnmuteSoundFile` | 3 / 3 | Silence specific Blizzard files by FileDataID |
| `PlayMusic` / `StopMusic` | 2 / 1 | The music channel, separate from SFX and Ambience |
| `Sound_EnableMusic` / `_EnableAmbience` / `_EnableSFX` | 1 each | Per-channel suppression |
| `PlaySoundFile` / `StopSound` | 3 / 6 | The old API; `StopSound(handle, fadeMs)` fades out only |

`volumeOverride` and `runFinishCallback` sit in the `C_Sound` string region between
`uiSoundSubType` and the `GetSoundScaledVolume` usage line. That is strong evidence they
are fields of the params table but it is **adjacency, not a declared struct** — treat the
field list as probable, not certain.

### Hard constraints on anything audio

- **No network access.** There is no HTTP in the addon sandbox. "Internet radio" is
  impossible. Do not propose streaming, APIs, or fetching anything.
- **No bundled music.** Shipping audio files we do not own is redistribution and is the
  most reliable way to get an addon removed. Our own rain OGGs are synthesised from
  scratch and are the only audio we may ship.
- **Blizzard's library is free to us by FileDataID.** Referencing a numeric ID plays the
  file already on the user's disk. Nothing is redistributed and this is explicitly how
  other addons use Blizzard audio.
- Users *can* drop their own OGG files into the addon folder, but a CurseForge user
  overwhelmingly will not.

So the only content the station can play by default is **Blizzard's own sound library**:
every ambient loop, zone theme, tavern track, weather bed and one-shot in the game.

### Legality is settled. Do not re-answer it.

The addon is original work. No forked code, no decompiled assets, no protocol manipulation,
no C++. It reads public API only, writes no packets, and references Blizzard assets by
FileDataID rather than redistributing them. Blizzard's April 2025 position preserved
cosmetic and display modifications. The only live legal questions are the two already
flagged above (bundled audio, user-supplied files) and they have known answers.

### The competitive survey already done, inside WoW

Each was downloaded and its Lua read on 2026-10-12. **Do not redo this.**

| Addon | What it does |
|---|---|
| Dynamic Weather (Scroll_Keeper, 20.7k dl, last touched 2021) | 18 weather states, ~200 zones to biomes, seasons from the real calendar, Mersenne Twister seeded from `GetServerTime()`, hourly forecast, Blizzard soundkit IDs per state, 14 lens droplets |
| Dynamic Azeroth Weather (ForgeDMC, 2026, 358 dl) | FNV-1a hash of zone+hour, 4-hour forecast, per-zone climate weights, options panel, thunder flash |
| Weather (keyboardturner, 2.3k dl, All Rights Reserved) | Indoor audio muffling, free-fall wind, skyriding wind by speed, a forecast icon, a "Collector Almanac", and a fullscreen `SetColorTexture` tint at max alpha 0.30. Its `LibForecast` parses the engine's own `CONSOLE_MESSAGE` line for weather type, intensity and record ID |
| RainingBlood | Two lines: `SetCVar("weatherDensity", 3)` |
| ImmersiveWeather | A text label by the minimap |
| DayNight (2015) | Drives the `gamma` CVar down at night |

**Not one of the six calls `SetBlendMode`**, verified by grep across every Lua file. Ours
is the only multiplicative darkening in the field. Nobody in the field sequences audio;
nobody shifts time of day.

---

## What to actually research

### A. Who already serves "comfy vibes", and are they competitors? (40%)

This is the main question. The competitive set is no longer just WoW addons. Map it across
three rings and tell me which ring actually matters.

**Ring 1 — inside WoW.** Beyond the six above: are there addons whose primary product is
*audio*? Music replacers, ambience managers, soundtrack addons, "mute the annoying sound"
addons, tavern-music addons, immersion suites with an audio component. Find them on
CurseForge, WoWInterface and GitHub. For each: downloads, last update, flavours, licence,
and what it actually does. I especially want to know whether anyone has built a
**scheduler** over Blizzard's sound library, and whether any addon uses `MuteSoundFile`
at scale.

**Ring 2 — the same idea in other games.** In-game radio and ambience mods with real
adoption: Fallout and Skyrim radio/ambience mods, GTA radio replacers, Minecraft ambient
sound mods, Stardew/cozy-game soundscape mods. I want the *patterns that made them work* —
how they handled content licensing, whether they shipped audio or referenced the game's
own, how they were discovered, and what their users actually praised. Nexus Mods download
counts and top-rated user comments are the evidence I want here.

**Ring 3 — outside games entirely.** Rainy Mood, myNoise, Noisli, Endel, Calm, Spotify and
YouTube lo-fi/rain channels, A Soft Murmur. How large is this demand, what do people pay,
and what features recur across all of them? I am not competing with these, but the feature
set they have converged on after fifteen years is the best available specification for what
people want from an ambient audio product. Tell me what that converged feature set is.

Then the judgement: **is "comfy vibes inside WoW" a real unmet demand, or is it a thing
people already satisfy with a second browser tab playing lo-fi?** That second tab is the
real competitor and I want it treated seriously, not dismissed.

### B. The content problem, which may kill the idea (20%)

A radio station needs a playlist and we can only play Blizzard's own library by default.

- **Many WoW players turn the in-game music off.** Find out how prevalent that actually is
  — forum threads, Reddit polls, addon downloads for music-related addons, anything
  quantitative. If the default audience has already muted the content our station plays,
  the product is re-DJing something people chose to silence. Is that true?
- What *is* in the library that is actually beloved rather than tolerated? Tavern music,
  specific zone themes, ambience beds. Which Blizzard audio do players seek out, make
  YouTube playlists of, or ask for addons to replay?
- Is ambience (rain, wind, surf, forest, tavern crowd, fire) a better default than music?
  Ambience does not fatigue the way melody does and is not something players mute.
- How much friction is "drop your own OGGs in this folder" really, and is there any
  precedent of a WoW addon succeeding with user-supplied content?

Give me a verdict: **music station, ambience station, or both with ambience as the
default.**

### C. Does the reframe hold up, and should it be one addon or two? (20%)

The proposal is one addon where audio, rain and time-of-day grading are three outputs of
one engine, selected by a "vibe" rather than configured separately. All three are already
functions of the same inputs — apparent hour, zone, real weather.

- Is that coherent as a product, or is it two products sharing a repo? Argue both sides and
  pick one.
- What do the users of the existing addon lose? Someone who installed a rain addon and gets
  a mood engine may not want it.
- Is there precedent either way — successful "suite" addons versus successful single-purpose
  ones? WeakAuras and ElvUI are suites; most of the top 100 are not. What predicts which
  works?
- If it is one addon, what is the *one sentence* it is for? If I cannot say it in a
  sentence, it is two products.
- Should the rain addon ship first as its own thing and the mood engine come later, given
  the 4 November launch window?

### D. The name (15%)

I am considering something like "ComfyVibes". "AlwaysRain" is a feature name that caps the
product at one weather type and fights a roadmap that already includes snow, fog and ash.

- **How is an addon actually discovered on CurseForge in 2026?** Keyword search, category
  browse, addon-manager search, Reddit, YouTube, word of mouth — with evidence on the
  relative weight, not assumptions. This decides whether a searchable name matters at all.
- If search matters, a name containing no word anyone types is a real cost. What do the
  successful addons in adjacent categories do about this — is the pattern a descriptive
  name, an invented brand, or a brand plus a descriptive subtitle?
- Is "comfy" / "cozy" a term this audience actually uses, or is it borrowed from a
  different gaming subculture? Check how it reads to a WoW player specifically.
- Give me **three candidate names** with the reasoning, and your single recommendation.
  Include whether the folder name, the CurseForge title and the displayed title can differ,
  and what the SEO consequence of each is.

### E. What would make it genuinely world-class (5%)

Briefly, and only ideas that survive the constraints above. I am looking for the thing I
have not thought of — not a restatement of the feature list.

---

## Output format

Five numbered sections matching A to E, plus:

1. **Corrections** at the top: anything in Verified facts that is actually wrong, with the
   evidence. If nothing is wrong, say "none" in one line and move on.
2. **Unverified** at the end: every claim you could not establish, each with the specific
   check that would settle it.

Rules:
- Lead each section with the verdict, then the evidence. No preamble.
- Numbers go in tables with their source and the date observed.
- Download counts, dates and licences must be stated as observed on a given date, not as
  general knowledge.
- Where sources conflict, say so and say which you believe and why. Do not average them.
- Give one recommendation per question, not a menu. I will act on it.
- No em-dashes.
- Any currency figure in CAD as well.

# How WoW levelling guide addons are distributed, gated and licensed

Research notes, 2026-10-19. Written for a future session of this repo, or anyone
asking "why can you sell a WoW addon when the source is plaintext?"

Not about Comfy Rain. It lives here because this is the WoW-addon repo and the
findings are general addon-platform knowledge, like `docs/api-surface.md`.

## The question that started it

Addons ship as readable Lua. So why can RestedXP charge €50/$30, and could you
just republish it for free?

## Platform facts (these constrain everything else)

| Fact | Consequence |
| --- | --- |
| Addons load plaintext Lua from `Interface/AddOns` | No compiled distribution |
| `loadstring` exists but **refuses precompiled bytecode** | Cannot ship Lua bytecode |
| `os`, `io`, `debug`, `dofile`, `require` removed from the sandbox | No filesystem access |
| **Zero network access** — no HTTP, no sockets | No server-side DRM is possible, at all |

That last row is the important one. An addon cannot phone home, so any paid
content must arrive by some out-of-band channel and must validate locally.

## Blizzard's policy vs. what actually happens

Blizzard's [UI Add-On Development Policy](https://us.forums.blizzard.com/en/wow/t/ui-add-on-development-policy/24534)
still says, unchanged since the 2010 revision:

- "Add-ons must be free of charge" — no premium versions, no paid features.
- "Add-on code must be completely visible" — not hidden or obfuscated.

Both are violated by every paid guide addon. Unenforced since Zygor, ~2008.
Blizzard is not the referee here; the vendors enforce against each other and
against users via copyright.

## RestedXP's actual architecture

Repo: [RestedXP/RXPGuides](https://github.com/RestedXP/RXPGuides).

### What ships free, in plaintext

Verified by cloning the repo on 2026-10-19 (121 MB working tree):

| Guides in the free download | Levels covered |
| --- | --- |
| WoW Forever (`Guides/forever/`, `Guides/Forever/`) | 1-22 |
| Classic / TBC (`Guides/`, `Guides/tbc/`) | up to 30-32 |
| Deathknight | 55-58 |
| Above those | **no files present** |

Note the repo has **both** `Guides/forever/` and `Guides/Forever/` — case matters.
A GitHub API listing of one will miss the other. `Guides/Forever/` holds only
`RestedXP-Skyborne.lua` (332 KB, 7384 lines, 761 steps, 3 `RegisterGuide` calls,
covering 1-9 and 9-13); the lowercase folder holds 12 more files.

The free guides are ordinary readable step text:

```
step
    .goto 2521,42.82,23.41
    .accept 92460 >>Accept Coming of Age
    .target Ailee Farheart::251362
```

No encrypted blob is hidden anywhere in the repo. The higher-level guides are
absent, not locked.

### What you buy

Not a licence key. You buy an **import string**: the guide text itself, as
characters, which you paste into the addon. Pipeline, read from
[`GuideLoader.lua:274-356`](https://github.com/RestedXP/RXPGuides/blob/main/GuideLoader.lua#L274-L356):

1. guide text → zlib deflate
2. → RC4 stream cipher (the classic S-box / `i,j` swap / XOR keystream loop)
3. → base64
4. the result is what the customer receives and pastes

On import the addon reverses it, then validates `h1` against both the zlib
Adler-32 trailer and `addon.A32()` of the decompressed text. Failure message:
`"Account mismatch, import string does not apply to current account"`.

`importChunkSize = 4096` with a `yieldImport()` coroutine, because the strings
are enormous — see measurements below.

### Account binding

[`GuideLoader.lua:484-530`](https://github.com/RestedXP/RXPGuides/blob/main/GuideLoader.lua#L484)
builds the RC4 key schedule from `addon.ReadCacheData("buffer")`, which seeds
from:

```lua
local base = select(2, _G[addon.DeserializeTable(addon.base)]())
```

— the *name* of the WoW API function is itself hidden in a serialized blob, and
the second return value is lowercased, truncated to the last 16 chars, and
folded into a 16-byte buffer. The value is account-specific, per the error
string. **Deliberately not resolved further** — that is the bypass, not the
architecture, and it was out of scope.

Consequence: the same guide becomes a **different** blob for every buyer. A
shared string decodes to garbage on another account and the checksum rejects it.

### Measurements

Taken from the free 1-22 Forever set as a yardstick for how large a paid string is:

| Stage | Size |
| --- | --- |
| Plaintext guide text (12 files) | 1,951,176 chars (1.95 MB) |
| zlib -9 | 333,243 bytes |
| base64 | **444,324 characters** |
| Net vs. source text | 4.4x smaller |

So a paid 23-60 string is plausibly 400k+ characters. That is why RestedXP
distributes via its own app rather than a copy-paste box, and why the importer
chunks.

## The licensing situation, which is the surprising part

- `RXPGuides/LICENSE` is **CC BY-NC-SA 4.0** (verified from
  `raw.githubusercontent.com`, both `main` and `master`). That licence
  *expressly grants* non-commercial redistribution of derivatives with
  attribution and sharealike.
- CurseForge labels the addon "All Rights Reserved" — inconsistent with its own
  LICENSE file.
- [Ez XP](https://www.curseforge.com/wow/addons/ez-xp) is a live declared fork:
  "A faithful fork of RestedXP Guides (CC BY-NC-SA 4.0)… the engine, the guides
  and every feature are RestedXP's", free, French translation added. Release
  0.5.4 dated 2026-10-19. Not taken down as of that date.
- Creative Commons itself advises against CC for software. NC also fails the
  OSI/free-software definition.

**Where the line is:** the paid import string never appears in the CC-licensed
repo, so CC never attached to it. You receive it under purchase terms.
Redistributing *it* is infringement regardless of the repo's licence.

## Legal boundaries worth remembering

- *Davidson & Associates v. Jung*, 422 F.3d 630 (8th Cir. 2005) — the bnetd
  case, **Blizzard won**. Two holdings that matter: a EULA can contractually
  waive your reverse-engineering/fair-use defence, and the DMCA §1201(f)
  interoperability exception fails where the circumvention itself enables
  infringement.
- Canada, Copyright Act **s. 41.12** (as amended by C-294, royal assent
  2024-11-07) permits TPM circumvention only *for interoperability*. Accessing
  gated content is not interoperability, so it does not cover this.
- RestedXP demonstrably enforces: `mkccl/restedxp-reencrypt` and its
  `restedxp.cheswick.dev` mirror both received DMCA notices (see that repo's
  issue #3).
- Practical asymmetry: an individual using a shared string is effectively
  unenforceable; whoever *publishes* one is the target.

## The free alternative: Factoruide

[brouznouf/factoruide](https://github.com/brouznouf/factoruide) — a route
*optimizer*, not a hand-written guide. Simulates the whole playthrough (travel,
fights, drops, quest/mob XP, trainers, professions, gear) and searches for the
fastest path, then an in-game addon walks you through it.

| Attribute | Value, as of 2026-10-19 |
| --- | --- |
| Created | 2026-10-08 (11 days old) |
| Commits | 263, ~24/day; latest 2026-10-19 17:31 UTC |
| Releases | 14, v0.2.0 → v0.13.0 (10-18 Oct) |
| Stars / forks | 61 / 8 |
| Open issues | 5 |
| Contributors | joelwurtz 258, csselement 3, OMSmolina 1, jdille 1 |
| Licence | **MIT** (code) + GPL-2.0-or-later (quest DBs) |
| Stack | Rust 1.77 MB, Lua 1.27 MB, TypeScript 1.00 MB |

- Repo sits under the `brouznouf` handle; the work is Joel Wurtz (Paris,
  JoliCode / Redirection.io, 136 public repos, GitHub since 2009). Bus factor 1,
  but a career open-source developer.
- GitHub's API reports the licence as `NOASSERTION` because of the code/data
  split documented in `NOTICE.md`. It is **not** unlicensed — there is an MIT
  LICENSE file.
- `NOTICE.md` tracks data provenance row by row (Questie/QuestieDB, VMaNGOS,
  AllTheThings, Wowhead, client files, plus crowd-sourced player observations
  accepted only on multi-player agreement). Unusually careful for a 11-day-old
  project.
- Self-described as experimental; the author says it will not replace
  hand-written guides.

### If contributing

Open issues are concrete route/data bugs, good entry points — e.g. "Timed quest
Grace of An'she and Mu'sha (95805, 10 min) planned over 16 min", "Tauren Shaman:
Call of Earth (1519→1520→1521) never planned".

At ~24 commits/day the maintainer may fix things before a PR lands, so **issues
with reproduction are worth more than code** right now. No revenue path exists
either way: Blizzard's policy bans charging *and* soliciting donations.

## Open questions, not checked

- Whether RestedXP watermarks strings beyond the account binding (e.g. to
  identify a leaker), and what the `h1` delivery channel is.
- Which WoW API `addon.base` deserializes to. Deliberately left alone.
- Whether Ez XP's inclusion of purchased guide content is actually covered by
  CC BY-NC-SA. Untested, and it may yet be pulled.
- Whether Factoruide's simulated routes are competitive with RestedXP's
  hand-written ones in practice. Nobody has measured this.

## Method note

Everything above was read from source or measured, not inferred. The one claim
originally taken second-hand — that RestedXP's gate is "a local key comparison"
you could flip — turned out to be wrong: it is content encryption, so the data
is genuinely absent rather than locked. Treat any summary of this file that says
"local key check" as stale.

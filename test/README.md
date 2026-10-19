# Running the addon without a client

```
lua test/run.lua
```

Needs **Lua 5.1**, which is WoW's own interpreter version. If `lua -v` says
anything else, the suite still runs but proves less: a 5.2+ construct that
would fail in the client would pass here. To get 5.1 without touching the
system:

```
curl -sSfLO https://www.lua.org/ftp/lua-5.1.5.tar.gz
tar xzf lua-5.1.5.tar.gz && make -C lua-5.1.5 generic
make -C lua-5.1.5 install INSTALL_TOP=$HOME/.local
```

## Why this exists

The beta client is withdrawn on **2026-10-21** and the game does not exist
again until **4 November**. That is fourteen days in which code can be written
and never once executed, and shipping unexecuted code to strangers on a launch
day it cannot be hotfixed is the project's biggest risk.

`wowmock.lua` is enough of the WoW API to run `ComfyRain.lua` under a bare
interpreter. It does not render anything and cannot tell you whether the rain
looks right. It records what the addon asked the renderer and the sound engine
for, which is the class of bug a human watching the screen will not catch: a
MOD quad left at a colour that makes it a no-op, a night graded twice, a bed
that reloops before the last one finished.

## What it deliberately gets wrong on purpose

The mock reproduces client misbehaviour rather than an idealised API:

| Behaviour | Why |
|---|---|
| `RegisterEvent` on an unknown event raises | It does on Forever, and the addon is one file, so an unguarded call aborts everything after it |
| Restricted getters can return a secret value | Non-nil, and raises on arithmetic. `if x then` is not a sufficient guard |
| `PlaySoundFile` can refuse | Playing Blizzard's library by FileDataID assumes the file is on the user's disk |
| `GetBuildInfo` returns interface `16001` | Not a retail five-digit number, so any `>= 100000` branch mis-fires |
| Hidden frames get no `OnUpdate` | This is what found the indoor-poll bug |
| Sound handles stay live until the file ends | Lengths are supplied per spec; the mock will not invent a duration it cannot measure |

## Structure

- `wowmock.lua` — the API. `reset(opts)` then `install(env)`.
- `harness.lua` — `H.world(opts)` builds an isolated world and loads the addon
  into it. Each spec gets a fresh environment and a fresh load of the chunk,
  because the addon keeps its state in upvalues and a reused chunk would carry
  it across.
- `spec_*.lua` — one file per area. Add new files to `SPECS` in `run.lua`.
- `golden_*.txt` — see below.

## The golden files

```
lua test/run.lua --update
```

`golden_draw.txt` is every number the addon hands the renderer, one block per
setting, across the whole matrix. `golden_motion.txt` is the same after ten
seconds of running, so the rates show up. Neither file is hand-written and
nobody can tell by reading them whether the numbers are right.

That is not what they are for. **They turn a change to anything visual into a
diff in the commit that caused it.** A per-feature spec says one number should
be one value and why; a golden file says nothing else moved. The usual failure
of this suite is not a wrong assertion, it is a correct assertion about a point
nobody thought to pick — the Darkness slider could not reach full dark at three
of its four intensities while 234 specs were green, and it was found by playing
the game.

Rules for them:

- `--update` rewrites them. **Read the diff before committing it.** An updated
  golden with an unread diff is worse than no golden, because it launders a
  regression into the record as intentional.
- Two matrix rows that produce an identical block fail the suite. A row that
  draws the same thing as another row is testing nothing, and the first draft
  of the matrix had four of them.
- `golden_draw.txt` is base state with no time passed, deliberately: no gust
  phase and no lightning, so a change to the jitter does not rewrite the whole
  file. Anything that is a rate belongs in `golden_motion.txt`.

## The sweeps

`spec_sweep.lua` also walks the space rather than sampling it:

| Sweep | What it is for |
|---|---|
| Every slider, both ends, every intensity | The bottom is off, and the top of an *absolute* slider means the same thing everywhere. Each slider declares which kind it is, and a new one that declares neither fails the suite |
| Invariants over the matrix | No colour channel, alpha or saved setting ever leaves its range, checked after time has passed |
| Every command × every bad argument | Nothing raises, and the addon is still usable afterwards — the second half is the positive control, since an addon that had quietly switched itself off would pass the first |
| A seeded 400-step random walk | Order-dependent bugs. This is what found `/comfy time 1e400` putting a nan in `timeFixed`, via `inf % 24` |
| Help coverage | Every command the dispatcher accepts is named in the help, or listed as deliberately unadvertised with a reason |

## What it cannot answer

Everything in `## Open / unverified` in `RESUME.md`. The mock asserts the
addon's own logic; it cannot tell you whether SavedVariables reads back on
build 70338, whether ambience survives `Sound_EnableMusic = 0`, or whether
`volumeOverride` is a real field. Those need the live client before 21 October
and nothing here substitutes for them.

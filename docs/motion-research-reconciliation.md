# Motion research: which report we followed, and what we changed

Two deep research reports came back against `motion-realism-research-prompt.md`. They are
saved verbatim as `motion-research-report-1.md` and `motion-research-report-2.md`. They
disagree in places. This file records which one won each disputed point and why, and what
actually shipped.

**Short version: report 1 is the one we implemented.** Report 2 agrees with it on the
headline findings and is wrong on four checkable details.

---

## One correction that belongs to us, not to either report

The prompt said:

> Turning the camera is measured but currently unused.

That was false when it was written. `ComfyRain.lua` computes `swing = turnDelta / FOV_H`
from `GetPlayerFacing()` and applies it in the scroll:

```lua
o.x = (o.x - dy * slant + swing * PARALLAX[l.key] * tilesX) % 1
```

Report 1 therefore ranked "camera yaw coupling, missing entirely" as its single most
damaging failure, and it was already wired. Report 2 inherited the same premise and echoed
it back as its top cue, which is the clearest illustration in these two documents of why a
research prompt must not assert anything the source can be read for.

**The finding that survives is narrower and is real.** Report 1 derives that rotational
optic flow is depth-independent: a yaw of omega displaces every ray by omega, so a drop at
1 m and a drop at 30 m sweep across the screen by the same angle. Translation falls off as
1/depth; rotation does not. We were scaling the yaw term by `PARALLAX = { mist 0.25, far
0.9, near 1.0 }`, which sheared the three layers against each other on every turn. That is
fixed: the yaw term is now depth-independent and `PARALLAX` is gone.

---

## Where the two reports agree (acted on)

| Finding | Status |
|---|---|
| Rain speed should span about 2x light to heaviest, not our 4.7x | shipped |
| Blizzard apparent speed is horizontal transport, not faster falling | shipped |
| A fixed 7.5 degree rain slant is far too small and wrongly constant | deferred, art-coupled |
| Running must tilt the field, not just speed it up | deferred, art-coupled |
| The speed-to-length invariant (`speed / length = 1 / T` at every depth) is correct | confirmed, no change |

The invariant is worth stating plainly because it is the thing we got right: a streak's
on-screen length is `v*T/z` and its speed is `v/z`, so the ratio is `1/T` for every drop in
the frame regardless of depth. Both reports confirm it independently. It is what drove the
near layer from 2.30 to 1.07 earlier in the same session.

## Where report 2 is wrong

1. **Particle lag by Stokes drag.** Report 2 gives a horizontal relaxation time of 10 to 12
   seconds for a 2 mm raindrop, from `tau = rho*d^2 / (18*mu)` = 12.3 s. Stokes drag
   requires Re << 1. A 2 mm drop at its terminal 6.55 m/s has Re = 873. A 12.3 s
   relaxation would also mean the drop falls about 81 m before reaching terminal velocity,
   which is not what drops do. Report 1's `tau_h = v_t / g` is the correct form: **0.67 s
   for a 2 mm drop, 0.09 s for a 3 mm unrimed aggregate.** Our invented `GUST_FOLLOW` of
   `near 6.0, far 2.2, mist 1.0` is 10 to 60x too long and ordered backwards (the slower
   faller should respond faster, not slower).

2. **Frame rate.** Report 2 says streak length must shorten at 144 Hz. That is velocity
   stretching in a particle system, where the streak is drawn per frame from the
   per-frame displacement. Our streaks are baked into the art and do not know the frame
   rate. Report 1's rule is the self-consistent one: fix the effective exposure `T` in
   seconds, keep `T >= 1/f_min` (about 16.7 ms), and nothing changes between 60 and 144 Hz.

3. **Vertical field of view.** Report 2 gives about 74 degrees for a 90 degree horizontal
   FOV on 16:9. The correct value is `2*atan(0.5625)` = **58.7 degrees**.

4. **Its "top cue" for what reads as fake** is our own candidate, handed to it in the
   prompt and returned unchanged. No independent weight.

Report 2 is kept for its drop-size-distribution sourcing, which is sound, and because the
two agreeing on the ~2x rain span from different starting points is what made that change
safe to ship.

---

## What shipped

Everything below is screen heights per second, standing still, slider at 1.0.

| intensity | old near H/s | new near H/s | change |
|---|---|---|---|
| rain light | 0.421 | 0.390 | -7% |
| rain normal | 0.713 | 0.713 | anchor, unchanged |
| rain heavy | 1.141 | 0.859 | -25% |
| rain monsoon | 1.969 | 0.924 | -53% |
| snow light | 0.157 | 0.138 | -12% |
| snow normal | 0.257 | 0.162 | -37% |
| snow heavy | 0.449 | 0.186 | -59% |
| snow blizzard | 0.820 vertical | 0.162 vertical | -80% |

- **Rain now spans 2.37x, not 4.7x.** Terminal velocity goes as roughly the square root of
  diameter, and the median-volume diameter only grows from about 0.8 mm at drizzle to
  2.5 mm in a tropical downpour. 3.4 to 8.1 m/s is the whole range. Density, streak
  thickness, gloom and slant are what carry "heavier", and we already scale all four harder
  than speed.
- **Snow now spans 1.35x.** A dendrite and a 3 mm unrimed aggregate settle at nearly the
  same speed; the aggregate gains drag as fast as it gains mass. 0.85 to 1.15 m/s covers
  everything short of graupel.
- **Blizzard falls at exactly the same vertical rate as light snow**, which is the physical
  truth. Its speed is all sideways: the slant went 78 to 85 degrees (`tan` 4.7046 to
  11.4301), so travel along the streak is 1.86 H/s. `make_snow_tga.py` bakes the gale
  streaks at 85 to match, because the sheet and its travel have to point the same way.
  Sway went 2.0 to 4.6 for the same reason the slant did: sway adds to `tan`, and
  `d(angle)/d(tan)` is `1/(1+tan^2)`, so 4.6 up here is a wobble of +-2 degrees. Blowing
  snow varies in direction LESS than a calm flurry, not more, because the wind pinning it
  is an order of magnitude stronger than the settling speed.
- **Scene preset speed multipliers are all 1.0** (Cozy and Storm were 0.9, Snow 0.8). Those
  were taste corrections stacked on top of numbers that were themselves wrong by a factor;
  a preset that scales a derived table un-derives it. Cozy is within 3% of where it was, so
  the preset most people will sit in is unchanged.
- **The yaw term is depth-independent**, as above.

## Deferred, and why

Both of these are correct and both need the art regenerated at a new angle, so they are
their own pass and their own judgement call:

- **Rain slant.** `tan(theta) = wind / fall speed` puts real rain at 22 degrees in a light
  shower with a breeze and 56 in a thunderstorm. We are fixed at 7.5 for all four. Raising
  it means re-baking `make_rain_tga.py` at the new angle, or shearing the UVs with the
  8-argument form of `SetTexCoord`, because a sheet whose streaks point one way and whose
  travel points another reads as a filter over the screen. That is exactly the bug the
  blizzard sheet had at 62 degrees.
- **Running.** `(1 + runSpeed * 0.3)` on the fall rate is the wrong vector treatment. The
  apparent motion is the difference of the two velocities, so running at 7 m/s through rain
  falling at 9 m/s tilts the field by `atan(7/9)` = 38 degrees and raises the speed by only
  26%. It should be mostly tilt and radial expansion about the focus of expansion, and
  almost none of it speed. Same art dependency as the slant.

Also outstanding from report 1, lower priority and no art dependency:

- `GUST_FOLLOW` should collapse to a single short lag of about 0.7 s for rain and 0.1 s for
  snow, not 6.0 / 2.2 / 1.0 per layer.
- Near and far loop at 1.954 and 1.925, which is a repeat period of about 0.51 s for both.
  Two layers finding the loop at the same instant is the periodicity tell. Detune one.
- First person adds up to 20% fall rate (`ZOOM_RATE`). There is no physical reason for it.

## Addendum 2026-10-23: the layer depth

Report 1 (lines 263-270) says the motion the eye reads is the nearest long streaks, 1 to 5
m away, which move 2 to 5 times faster on screen than anything past 10 m. The pass above
fixed every ratio and left the **level** where it was: far 1.05 / near 1.07 put the near
layer at about 5.5 m (`H/s = v / (1.125 z)` on the 58.7 degree vertical field of view).

A capture of the shipped pass measured near 0.89 H/s against 0.92 designed and far 0.46
against 0.45, so the implementation was faithful and the complaint "too slow" was about
depth. `LAYERS` now puts the layers at 3 m and 6 m: far 1.925, near 1.954, a uniform x1.833
that leaves the 2.03x streak ratio and every per-intensity ratio above untouched.

| Near layer, slider 1.0 | Before (5.5 m) | Now (3 m) |
|---|---|---|
| Cozy (light rain) | 0.39 | 0.71 |
| Normal rain | 0.71 | 1.30 |
| Storm (monsoon) | 0.92 | 1.69 |
| Normal snow | 0.16 | 0.30 |
| Blizzard, along the slant | 1.86 | 3.4 |

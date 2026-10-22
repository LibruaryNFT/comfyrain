You are advising on the motion of a 2D screen-space precipitation overlay for a first-person
/ third-person 3D game (World of Warcraft, Classic client). The art is finished and is not in
scope. What is in scope is how fast everything moves, in what direction, and how that should
change with rain rate, wind, and the player's own movement.

Everything below is our current implementation, stated in real units so you can check it. We
believe several of these numbers are wrong. Tell us which, by how much, and what they should
be. We want derivations and sources, not adjectives.

---

## How the overlay works, exactly

Three full-screen quads, each a 512x512 tiling texture scrolled by moving its texture
coordinates. No particles, no 3D, no depth buffer.

- **mist** - a haze sheet, 1.1 copies span the screen height.
- **far** - 3.0 copies span the screen height.
- **near** - 1.5 copies span the screen height.

Per frame, for each layer:

```
rate  = intensitySpeed * userSpeedSlider * (1 + runSpeed * 0.3)
dy    = layerSpeed * rate * tiling * (1 + gust * 0.18) * dt
o.y   = (o.y - dy) % 1
o.x   = (o.x - dy * slant + sway * parallax * tilesX) % 1
```

`slant` is tan(angle off vertical) and is exact on screen: the quad's aspect correction
cancels, so slant 0.1317 is 7.5 degrees off vertical and the on-screen speed ALONG the
streak is the vertical speed times sqrt(1 + slant^2).

`tiling` is a per-weather scale on the sheet size: 1.35 for rain, 1.20 for snow. Smaller
sheet, so more sheet-units per screen-unit; it is in `dy` precisely to keep physical speed
constant when the sheet is rescaled.

Layer speeds are `far 1.05` and `near 1.07` with `tilesY` 3.0 and 1.5, so **near moves at
exactly 2.03x far on screen**. That ratio was derived this way, and we would like it checked:
a streak's on-screen LENGTH is `v * T / z` and its on-screen SPEED is `v / z`, so
`speed / length = 1 / T` for every drop in a frame regardless of depth. Our generated sheets
have a median near streak 2.03x the median far streak on screen, so near must travel 2.03x as
fast and no more. **Is that invariant right, and is an effective exposure T the correct way to
think about a game that renders instantaneous samples at 60-144 Hz with no motion blur?**

## Our current speeds, on screen

Screen heights per second, standing still, user slider at 1.0. "Along slant" is the actual
travel speed of a streak; "cross" is how long one takes to traverse the frame top to bottom.

| intensity | far H/s | near H/s | near along slant | near crosses screen in |
|---|---|---|---|---|
| rain light | 0.206 | 0.421 | 0.425 | 2.36 s |
| rain normal | 0.350 | 0.713 | 0.719 | 1.39 s |
| rain heavy | 0.560 | 1.141 | 1.151 | 0.87 s |
| rain monsoon | 0.966 | 1.969 | 1.986 | 0.50 s |
| snow light | 0.077 | 0.157 | 0.157 | 6.36 s |
| snow normal | 0.126 | 0.257 | 0.257 | 3.89 s |
| snow heavy | 0.221 | 0.449 | 0.450 | 2.22 s |
| snow blizzard | 0.403 | 0.820 | 3.946 | 0.25 s |

## Our current directions

| | slant (tan) | degrees off vertical | sway amplitude | sway rate |
|---|---|---|---|---|
| rain, all intensities | 0.1317 | 7.5 | 0 | - |
| snow, light to heavy | 0.06 | 3.4 | 0.22 | 0.055 Hz (~18 s period) |
| blizzard | 4.7046 | 78 | 2.0 | 0.12 Hz |

Sway is added to slant, so it wobbles the direction rather than translating the field.

## Our current gust model

An Ornstein-Uhlenbeck process: `g += (-g / 7.0) * dt + 0.35 * sqrt(dt) * N(0,1)`, clamped to
+/-1.6, stationary spread about 0.65. One shared gust signal, lagged per layer with time
constants `near 6.0, far 2.2, mist 1.0`. It modulates fall rate by +/-18%, alpha by +/-10%,
slant by +/-14%, and scene darkening by +/-12%. Scaled per intensity:
`light 0.45, normal 1.0, heavy 1.5, monsoon 2.0, blizzard 2.0`.

## Player motion coupling

- Running adds `(1 + runSpeed * 0.3)` to the fall rate, where runSpeed saturates at 2.2 for a
  7 m/s character. Nothing changes the slant when the player runs.
- Camera pulled in to first person adds up to 20% fall rate.
- Turning the camera is measured but currently unused.

---

## What we need, specifically

Answer each of these with numbers, the physics they come from, and citations. Where a number
depends on a parameter we have not given you, state the dependence as a formula.

**1. Rain fall speed versus rain rate.** Terminal velocity as a function of drop diameter, and
the drop-size distribution as a function of rain rate in mm/h (Marshall-Palmer and anything
that has superseded it). From those: what is the *visually dominant* fall speed - weighted by
what the eye actually sees, which is probably projected area or streak luminance, not number
count - at drizzle, moderate rain, heavy rain, and a tropical downpour? **We currently span
4.7x from our lightest rain to our heaviest. Our own reading of the drop-size literature says
the true span is nearer 2.2x. Which is right?** If a heavy downpour does not fall much faster
than moderate rain, say so plainly and tell us what the eye is actually reading as "heavier"
instead.

**2. The same for snow.** Fall speed by crystal habit and by degree of riming, the span from
light snow to blizzard, and how much of a blizzard's apparent speed is fall versus horizontal
transport. We span 5.2x from light snow to blizzard. Is that defensible?

**3. Slant, properly.** The relationship between horizontal wind speed, fall speed, and
apparent angle, including that wind varies with height and the observer is at 1.7 m. What
angle distribution does an observer actually see in (a) a light shower with a breeze, (b) a
thunderstorm, (c) a blizzard? Give the mean and the spread, not just the mean. Our rain is
fixed at 7.5 degrees for every intensity, which we suspect is both too small and wrongly
constant.

**4. Gusts.** Is Ornstein-Uhlenbeck the right model for the wind an observer perceives? What
are the real timescales - the integral timescale of atmospheric turbulence near the ground,
typical gust factors, and the ratio of gust to mean. Should gusts change the angle more than
the speed, or the other way round? Our tau is 7 s and our gust changes speed by +/-18% and
angle by +/-14%. Critique both.

**5. Whether precipitation should lag the wind.** We lag the near layer behind the far layer
by a 6.0 s time constant against 2.2 s, invented. What is the actual response time of a
falling drop or flake to a change in horizontal air velocity? This should be derivable from
the particle's relaxation time; give it for a 2 mm drop and for a 3 mm unrimed aggregate.

**6. The observer's own motion.** The precipitation field has a velocity in world space and
the player has another; the apparent motion is the difference. Derive, for a character running
at 7 m/s through rain falling at 9 m/s with no wind: the apparent angle, the apparent speed,
and how both change when the player turns. We currently apply a 30% speed increase and no
angle change, which we are fairly sure is simply wrong. Give us the correct vector treatment
and the resulting screen-space transformation for a camera with a 90 degree horizontal field
of view.

**7. Apparent angular velocity versus depth.** For an observer with a 90 degree horizontal FOV
on a 16:9 screen, what is the angular velocity of a drop at 1 m, 3 m, 10 m, 30 m? What depth
range dominates the perceived field - i.e. which of our layers should carry the motion the eye
locks onto? Is a two-layer parallax enough, or does the falloff demand more?

**8. Vertical motion that is not falling.** Updrafts, recirculation, snow lifted off the
ground, drops blown upward past a window. How common, how strong, and is any of it worth
representing in a 2D field?

**9. What makes precipitation read as fake.** Prior work on this specifically - perceptual
studies, film and VFX practice, published game-rendering talks. We want the failure modes
named: which single motion cue, when wrong, most reliably makes an observer say "that is a
texture scrolling" rather than "that is rain". Our own candidate is a speed-to-length ratio
that differs between depth layers. Confirm or replace it.

**10. Frame rate and sampling.** The game draws instantaneous samples at 60 to 144 Hz with no
motion blur, but our art has motion blur baked in as streak length. Is there a correct joint
choice of streak length and scroll speed for a given frame rate, and does it change between 60
and 144 Hz? What do games that render rain as streaked sprites actually do about this?

---

## Form of the answer

- A table of recommended numbers in the same shape as the tables above, so we can diff it
  against what we ship. Screen heights per second, and degrees off vertical.
- The derivation for each, short, with the source.
- Where our number is defensible, say so and move on. We are not looking for a rewrite, we
  are looking for the places where we are wrong by a factor rather than a few percent.
- Flag anything that is wrong but invisible, separately from what is wrong and visible. We
  have a fixed ship date and will take the visible ones first.
- Prefer measurements over models where both exist. Where you give a model, give the range it
  was fitted over and say when it stops applying.

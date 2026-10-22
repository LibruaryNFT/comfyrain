# Research task: physically grounded rain, snow and blizzard for a 2D screen-space overlay

You are researching how to make a 2D weather overlay read as **naturally realistic**
precipitation. I need published models, film/VFX practice, and concrete numbers I can
turn into generator parameters. Not style advice.

The overlay already exists and works. One of its four looks is good and three are not.
I want to understand *why* in physical terms, and what to change.

---

## 1. The hard constraints

This is a World of Warcraft addon (Classic client, Lua 5.1). Everything below is fixed
and cannot be worked around, so please do not propose solutions that need any of it:

- **No shaders.** No pixel shaders, no vertex shaders, no compute, no render-to-texture.
- **No framebuffer read.** The overlay cannot see the scene behind it. No depth buffer,
  no screen-space refraction, no per-pixel anything.
- **No particles.** There is no particle system available. The only primitive is a
  textured quad.
- **The whole effect is a handful of full-screen quads**, each showing one 512x512
  tiling texture, scrolled by animating texture coordinates.
- Per frame I can change, per quad: the texture coordinates (scroll and tile count),
  the alpha, and a flat vertex colour. That is all.
- Blend modes available: `ADD`, `BLEND` (normal alpha), `MOD` (multiply), `ALPHAKEY`.
- Textures must be 512x512, 32-bit uncompressed TGA, and must tile seamlessly in both
  axes. I generate them offline with Python/numpy, so **any closed-form or stochastic
  model that can be rasterised into a tiling sheet is fair game**.
- I may add more quads (layers), at a modest performance cost. Currently there are three.
- I cannot ship the game's own art. Everything must be derived or generated from scratch.

Reference screen for all numbers below: **1920x1080**.

---

## 2. How the overlay works right now

Draw order, back to front, composited over the finished game frame:

| Layer | Blend | tilesY | Scroll speed | What it is |
|---|---|---|---|---|
| gloom | `MOD` | n/a | n/a | one flat colour multiplying the whole frame |
| mist | `BLEND` | 1.1 | 0.09 | a soft low-contrast wash |
| far | `BLEND` | 3.0 x density | 1.05 | the distant depth of the fall |
| near | `ADD` | 1.5 x density | 2.30 | elements passing close to the camera |

`tilesY` is how many copies of the 512px sheet span the screen height.
`tilesX = tilesY * aspect`, so elements keep their shape.
**One sheet pixel therefore covers `H / (tilesY * 512)` screen pixels.**

`density` is a per-intensity multiplier that is **inverted** - heavier weather has a
*smaller* density, which magnifies the sheet:

| | light | normal | heavy | monsoon / blizzard |
|---|---|---|---|---|
| rain density | 1.35 | 1.00 | 0.78 | 0.58 |
| snow density | 1.20 | 1.00 | 0.82 | 0.66 |

Per-intensity alpha and gloom, as shipped:

| Preset | mist | far | near | gloom | fall speed |
|---|---|---|---|---|---|
| rain light | 0.05 | 0.40 | 0.35 | 0.18 | 0.59 |
| rain normal | 0.10 | 0.70 | 0.65 | 0.38 | 1.00 |
| rain heavy | 0.17 | 0.95 | 0.90 | 0.75 | 1.60 |
| rain monsoon | 0.26 | 1.00 | 1.00 | 0.95 | 2.76 |
| snow light | 0.06 | 0.34 | 0.30 | 0.26 | 0.22 |
| snow normal | 0.12 | 0.62 | 0.58 | 0.54 | 0.36 |
| snow heavy | 0.20 | 0.88 | 0.84 | 0.78 | 0.63 |
| snow blizzard | 0.30 | 1.00 | 1.00 | 0.55 | 2.58 |

Other current choices:
- Rain slant 7.5 degrees off vertical. Snow slant ~3.4 degrees, plus a sway term that
  drifts the whole field side to side at 0.055 Hz.
- Blizzard swaps the near sheet for a separate near-horizontal "gale" sheet at 62
  degrees off vertical, and adds a flat white `ADD` quad at 0.05 alpha for the whiteout.
- A gust signal modulates scroll rate, slant and gloom together.

### The sheets, exactly as generated

Rain, drawn as motion-blurred streaks. Each streak is a Gaussian across its width, an
exponential brightness falloff from the bright leading head up the tail
(`exp(-taper * (1 - t))`, taper 1.4 to 3.2), both ends windowed to zero, the slant
sheared in during rasterisation, and a slight per-drop curvature. 8% of drops are
multiplied 1.9x as a specular glint.

| Sheet | Count | Length (sheet px) | Width (sheet px) | Alpha |
|---|---|---|---|---|
| rain-far | 700 | 14 - 34 | 0.8 - 1.2 | 0.08 - 0.22 |
| rain-near | 380 | 16 - 40 | 0.6 - 1.1 | 0.14 - 0.34 |

Snow, drawn as soft blobs. Each flake is a Gaussian with a brighter core, optionally
with a weak 6-fold angular modulation. Visible diameter is about `3 * sigma`. Placement
is a jittered grid rather than uniform random. 10% of flakes are multiplied 1.8x.

| Sheet | Count | sigma (sheet px) | Alpha | Elongation | Angle |
|---|---|---|---|---|---|
| snow-far | 1500 | 0.9 - 1.9 | 0.05 - 0.15 | 1.15 +/- 0.2 | 0 +/- 0.35 rad |
| snow-near | 800 | 1.3 - 3.0 | 0.12 - 0.32 | 1.3 +/- 0.35 | 0 +/- 0.45 rad |
| snow-gale | 900 | 0.9 - 1.9 | 0.07 - 0.24 | 5.0 +/- 2.0 | 78 deg +/- 0.12 |

Largest element each sheet puts on a 1920x1080 screen, at its worst preset:

| Sheet | On screen | Share of frame |
|---|---|---|
| rain-far | 45 px tall | 4.2% |
| rain-near | 75 px tall | 7.0% |
| snow-far | 17 px tall | 1.6% |
| snow-near | 62 px tall | 5.7% |
| snow-gale | 170 px wide | 8.9% |

---

## 3. What was already fixed, and how

Light rain was the only convincing preset, and the reason turned out to be measurable.

A before/after capture pair was taken in the real client at the heaviest rain preset,
same scene, same camera, weather off then on. Measured off that pair, the longest near
streak was **546 px, or 51% of the frame height**, with only **53 streaks crossing the
middle** of a 1920 px-wide screen. The scroll rate implied an **80 ms camera exposure**
against a film-standard 21 ms.

The near sheet went from 70 drops at 80-190 px to 380 drops at 16-40 px, and the far
sheet from 260 at 20-46 px to 700 at 14-34 px. That preset now reads correctly.

**The structural defect behind it is still unfixed.** Because the number of sheet
copies on screen is `tilesY^2 * aspect` and `density` is inverted, element count scales
as `density^2`:

| Rain preset | Copies on screen | Near streaks visible |
|---|---|---|
| light | 7.29 | 2770 |
| monsoon | 1.35 | 511 |

So **heavier rain draws 5.4x fewer streaks, each magnified 2.4x**. Snow has the same
inversion at 2.9x. Heavier weather currently means bigger, sparser elements, which is
backwards.

---

## 4. The three problems to solve

Judged at 1:1 on a real captured frame:

1. **Heavy rain (monsoon).** The streaks still read as too long and too few - as discrete
   bars rather than as a downpour. Shortening them once already helped; I need to know
   what length and count the physics actually calls for rather than guessing again.

2. **Snow (normal).** Reads as a starfield: a field of near-identical soft white discs,
   evenly spaced, all about the same brightness. Real snow does not look like this and I
   want to know precisely which statistical property is missing.

3. **Blizzard.** Reads as a motion-blur filter applied in Photoshop. The streaks are all
   the same length, the same angle and the same brightness, and the flat white quad
   washes the scene out without reading as distance.

4. **The field must not read as a repeating pattern.** This is the one I care about most,
   because it is the giveaway that survives every other fix. Two separate repeats exist:

   - **Spatial.** A single 512x512 sheet is tiled 1.3 to 7.3 times across the screen at
     once, so the identical arrangement of drops is visible several times in one frame.
   - **Temporal.** The sheet scrolls and wraps, so the whole field recurs every 512 sheet
     pixels of travel - a few seconds at the faster presets.

   Real precipitation has no period at either scale. Any solution has to beat both, using
   only tiling quads with animated texture coordinates and flat alpha.

   There is a precedent in this same addon worth reasoning from: the ambience audio runs
   two loops of **deliberately unequal and incommensurate length** under each other, so
   the combined bed does not settle into an audible cycle for far longer than either loop.
   I want to know whether the visual equivalent works and what the right ratios are.

---

## 5. What I want from you

Please research and report on all of the following. Prefer primary sources, give
equations with their variables defined, and give numbers.

### Precipitation physics

- **Drop size distribution in rain.** Marshall-Palmer and its successors (Best, Ulbrich,
  gamma distributions). Give `N(D)` for several rain rates in mm/h, and the implied
  number of drops per cubic metre and their diameter spread. How heavy-tailed is it?
- **Terminal velocity vs drop diameter.** Gunn and Kinzer, and later fits. I need
  v(D) so that streak length and drop size stop being independent knobs.
- **Snow.** Fall speeds of solid precipitation (Locatelli and Hobbs and later work),
  aggregate vs single-crystal size distributions, and how much size and fall speed
  actually vary within one snowfall. The Nakaya diagram and Magono-Lee classification
  for crystal habit vs temperature, only as far as it affects silhouette at a distance.
- **How precipitation changes visibility.** Extinction coefficient as a function of rain
  rate and of snowfall rate; Koschmieder's relation; why a whiteout is a *contrast*
  phenomenon rather than a brightness one, and what that implies for an overlay that can
  only multiply or add a flat colour.

### Appearance models

- **Garg and Nayar's rain work** (the Columbia rain streak appearance database and the
  photometric model of a raindrop). What does a streak actually look like as a function
  of lighting direction, view angle and oscillation, and what of that survives into a
  low-resolution 2D sheet?
- The optics of a falling drop as a lens: what fraction of a streak's brightness is
  specular highlight versus refracted background, and does that change with drop size?
- **Motion blur.** The relation between exposure time, fall speed and streak length on
  screen, and what exposure film and games conventionally imply. Given a fixed virtual
  focal length and a drop at a given distance, what streak length in screen pixels
  should a 25 mm/h downpour produce?
- **Depth of field.** How out of focus are near drops and flakes in real footage, and how
  much of the "it looks fake" problem is actually missing defocus rather than wrong size?

### Film and games practice

- How do VFX houses actually produce rain, snow and blizzards? Specifically: **practical
  rain elements** shot against black and composited with an additive blend, which is
  structurally the same thing this addon does. What are the conventions - how many
  element layers, at what relative scales and speeds, and how is depth sold?
- What do the standard element libraries contain, and what parallax and scale
  relationships hold between their near, mid and far passes?
- Houdini / Maya particle setups for precipitation: what distributions are used for
  size, speed and opacity, and what is the usual count per layer?
- How is a whiteout done in film, given that simply brightening the frame does not work?
- Are there published game techniques for 2D scrolling precipitation overlays worth
  copying, and what do they do about the magnification problem in section 3?

### Statistics of placement

- Real precipitation is a Poisson process in space, but a 2D projection of a 3D Poisson
  field is not the same as a 2D Poisson field. What is the correct projected
  distribution, and does it explain the "starfield" complaint?
- **Blue noise / Poisson disk vs jittered grid vs uniform random** for placement: which
  matches projected precipitation, and what spatial statistic (pair correlation
  function, Ripley's K) should I be matching?
- How much should element brightness, size and opacity vary within one layer? Give a
  distribution shape, not just a range. This is the heart of problem 2.

### Breaking the repeat (problem 4)

- **Making a single tile hard to read as a tile.** What property of the sheet makes the
  repeat visible - is it the autocorrelation at the tile period, a few outlier bright
  elements acting as landmarks, or low-frequency density variation? How do I measure
  "this tile looks periodic when repeated" numerically so I can optimise against it?
- **Incommensurate layering.** If several sheets are overlaid at scales and scroll speeds
  whose ratios are irrational or at least coprime, what is the perceptual period of the
  combination? Give the arithmetic, and the ratios that work best. How many layers before
  the gain stops being worth the cost?
- Does **counter-scrolling** or crossing layers at slightly different slants help, or does
  it read as wrong because real precipitation all falls the same way?
- **Aperiodic tiling.** Wang tiles, corner tiles, and blue-noise tile sets: can any of
  them be used when the only control is one texture and its texture coordinates, with no
  shader to choose a tile per cell? If not, say so plainly.
- **Texture bombing / sparse convolution noise** and Heitz and Neyret's
  histogram-preserving blending: are these reachable without a fragment shader, or are
  they off the table here?
- How large an element budget does a tile need before the eye stops finding landmarks in
  it? Is there a known threshold, in elements per tile or in tile pixels per element?
- What do film element libraries do about this, given that a 4-second rain plate also
  loops? Is there a standard trick, and does anyone just shoot long enough to avoid it?

### Wind

- Wind-driven snow: the actual distribution of streak angle and length under a gale,
  and how much they vary. Is a near-constant angle correct, or is the spread the thing
  I am missing in problem 3?
- Turbulence structure in a blizzard at human scale, and the cheapest way to approximate
  it in a scrolling tiling sheet.

---

## 6. Deliverable

First, for problem 4, give me a concrete scheme for killing both repeats: how many
layers, at what scale ratios and what scroll-speed ratios, what the resulting perceptual
period is, and how I should measure a candidate sheet for periodicity before shipping it.

Then, for each of rain-heavy, snow-normal and blizzard, give me:

1. The physical scenario in real units: rain rate or snowfall rate, drop or flake size
   distribution, fall speed, visibility.
2. The projection to a 1920x1080 screen: how many elements should be visible, how long
   and how wide in screen pixels, what brightness distribution, and what spread around
   each of those.
3. The implied sheet parameters, given the magnification table in section 2, in the same
   form as the generator tables there (count, size range, alpha range, elongation).
4. Whether the effect needs a structural change rather than a parameter change - another
   layer, a different blend mode, a different number of sheets, a change to how density
   scales - and if so, exactly what.

State your confidence for each number and say which are derived from a cited model and
which are your own judgement. Where the physics and the film convention disagree, say so
and say which one looks better and why, because the goal is for it to **look** real to a
player, not to be a correct simulation.

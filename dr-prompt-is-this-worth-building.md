# Is a 2D weather-overlay addon still worth shipping for WoW Forever?

Today is 18 October 2026. World of Warcraft: Forever launches 4 November 2026. It is
Blizzard's relaunch of Classic-era Azeroth with a substantially upgraded renderer. I have
spent several weeks building a CurseForge addon called ComfyRain and I need an evidence-based
answer on whether to ship it, change it, or stop.

Answer with citations. Where you cannot find evidence, say "no evidence found" rather than
reasoning from plausibility. If any premise below is wrong, correct it first and say how you
know.

---

## What the addon is

ComfyRain is a pure-Lua addon with no client modification. It draws rain or snow on demand,
anywhere in the world, for as long as the player wants, independently of whatever weather
the server has scheduled. It is screen-space only:

- three full-screen scrolling texture sheets (mist, far, near) with blend modes BLEND and
  ADD, tiled and scrolled by moving texture coordinates
- a MOD quad that darkens the world, plus a separate time-of-day grade toward dusk and night
- a gust process driving scroll rate, layer alpha, slant and gloom
- a lightning flash with thunder from the game's own sound files
- an ambience bed of the game's rain loops
- it fades out indoors

It cannot touch world lighting, fog, the depth buffer, the particle system, shaders, or the
camera. Everything it draws is composited on top of the finished 3D frame.

## What Blizzard shipped in the same client

Reading the client binary turned up `CWeatherLightningManager`, `DayNight::CLightningGenerator`
and a `LightningRec_C` DB2 record, plus strings including "Start Weather Lightning ID %d."
and "Only one lightning storm at a time is supported (including storms from weather)." So
the engine now does real lightning bolts in the sky that light the environment, scheduled by
the server. There is no Lua API for it: `C_Weather` exposes exactly one function,
`GetCurrentWeather`, which is read-only. Forever has also shipped new volumetric fog, new
lighting and new water.

---

## What I need answered

### 1. Is the product thesis still alive?

My thesis is that Blizzard's weather is *server-scheduled, zone-gated and rare*, while mine
is *on demand, anywhere, permanent*. That difference is the entire product.

- How often does the server actually send rain or a storm in Classic-era zones? Give real
  numbers if any exist: datamined weather tables, zone weather chances, player measurements,
  anything from the Forever beta.
- Which Classic zones have weather at all, and which never do?
- Has Blizzard said anything about player-facing weather control, a weather toggle, or
  expanded dynamic weather for Forever? Quote them.
- Is there any sign Blizzard intends to let players influence weather, which would make this
  addon redundant on a patch?

### 2. Does the demand exist, and has someone already served it?

- Find every existing WoW addon that fakes, forces or overrides weather, on CurseForge,
  WoWInterface, Wago and GitHub. For each: name, download count, last update, supported
  flavour, and what it actually does.
- Specifically check whether anything already does screen-space rain overlays, and whether
  any of them work on Classic-era or Forever clients.
- Find evidence of player demand or its absence: forum threads, Reddit posts, addon
  requests, comments under existing weather addons. Quantify where you can (upvotes,
  comment counts, recurrence over time).
- Separately, how have players reacted to Forever's new fog, lighting, water and lightning?
  Is the reaction "finally, atmosphere" or "too much, let me turn it off"? That reaction
  tells me whether more atmosphere is wanted or resented.

### 3. Verify my API ceiling, because I may be wrong about it

I have told myself the following. Check each one against the actual documented API and
against what shipped addons demonstrably do. Say which are right, which are wrong, and which
are unproven.

- **An addon cannot render anything behind the 3D world.** Every UI draw layer
  (BACKGROUND, BORDER, ARTWORK, OVERLAY) and every frame strata including WORLD composites
  on top of the finished 3D scene, with no depth test against world geometry. Therefore an
  addon can never replace or augment a skybox, because anything it draws also covers
  terrain, buildings and the player. **Is this correct?** Is there any strata, parent frame,
  `WorldFrame` trick, or Model-frame technique that puts addon-drawn content behind world
  geometry? Cite a shipped addon if one exists.
- **`C_Weather` has no setter and never has.** Correct?
- **`weatherDensity` is an ordinary graphics CVar (0-3) and at 0 the client draws no
  weather.** Can an addon write it, or is it protected? Does setting it to 0 also suppress
  the new engine lightning, or only the precipitation?
- **A `Model` frame can load a game `.m2`, but its particles are clipped to the frame's own
  rectangle and cannot be made to fill the screen over the world.** I have proven only that
  the model *loads*. Is the clipping claim true? Has any addon ever rendered game particle
  effects usefully over the world?
- **`SetGradientAlpha` was removed and `SetGradient` replaced it; `SetMask` takes a file
  path, not a frame; there is no camera-pitch API.** Correct for a 1.60.x Classic-era
  client?

### 4. Skyboxes specifically

On 17 October a thread on r/wowforever titled "The biggest easy-win Blizzard is currently
NOT leveraging for WoW Forever is..... Skyboxes" reached roughly 516 upvotes and 61
comments. The argument was that retail already has better skyboxes that could be reused,
and the main counter-argument in the comments was that retail's are static painted clouds
that look like a still image, and that what players actually want is movement: volumetric
or drifting clouds, cloud shadows on the ground, a darker night, more stars.

- How often does this request recur, and over what period? Is this one viral thread or a
  standing demand? Quantify across r/wowforever, r/classicwow and the official forums.
- Has Blizzard responded to it, or said anything about skyboxes, clouds or night sky for
  Forever? Quote them.
- **Is there any legitimate path for a third party to change or augment the sky in this
  client?** Separate these clearly: an addon; a client setting or CVar the player already
  has; the existing SD/HD graphics toggle; replacing art in the game's data archives. For
  each, say whether it works and whether it breaks Blizzard's terms of service. I believe
  only the last one can touch the sky and that it is bannable. Confirm or correct.
- If the sky itself is off limits to an addon, is there a screen-space effect that
  plausibly scratches the same itch, such as slow drifting cloud-shadow dimming or a
  heavier overcast? Or would that read as a cheap substitute and damage the product?
- Is "better sky" a bigger or smaller want than "weather on demand"? If skybox demand is
  far larger and we cannot serve it, say so plainly.

### 5. The honest verdict

Given all of the above:

- Is this addon worth shipping on 4 November, worth reshaping, or worth abandoning?
- If worth shipping, what is the single sharpest way to describe it so a player understands
  in five seconds why they want it alongside Blizzard's own weather?
- What is the realistic ceiling on downloads for an addon in this category on CurseForge in
  the first 90 days? Use comparable addons' actual numbers, not estimates.
- What would have to be true for this to be a mistake? Give me the concrete, measurable
  thing that, if I observed it, should make me stop.

Do not be encouraging. I would rather find out now than on 5 November.

# Four requests from the first r/WowUI comment, designed properly

Source: a reply on the r/WowUI launch post, 2026-11-18. They found us because they were
standing in real rain in Thunder Bluff and wanted it on demand. They liked the camera-locked
layers, the game's own sounds and the fade at doorways. Four asks: #46, #43, #45, #44.

Everything below was checked against `ComfyRain/*.lua` and `docs/api-surface.tsv` on
2026-11-18. Anything marked **untested** has not been run on the Forever client.

## Recommended order

| # | Issue | Effort | Ship in |
|---|---|---|---|
| 1 | #46 Stop the rain underwater | half a day | 1.1 |
| 2 | #45 Change intensity without opening the window | half a day | 1.1 |
| 3 | #43 A shade that stays on indoors | one day | 1.1 |
| 4 | #44 Rain that builds, peaks and eases | two to three days | 1.2 |

1.1 is three small fixes that each remove something that currently looks broken. 1.2 is the
feature that nobody else in the niche has. Reply to the commenter when 1.1 is on CurseForge.

---

## 1. Underwater (#46)

**What they hit.** Rain keeps falling in front of the camera when you dive.

**What is true now.** Nothing checks water. `ShouldRain()` (ComfyRain.lua:1330) knows about
`enabled`, cinematics, real weather and shelter, and that is all.

**World-class version.**
- **Submerged hides it, swimming does not.** Rain hitting a lake while you swim at the surface
  is one of the best things the addon can show, so only `IsSubmerged()` turns it off.
  `IsSwimming()` alone must not. Both are in the Forever client binary (`api-surface.tsv`).
- **Going under is instant, coming up is not.** Enter with no debounce and a 0.25 s fade,
  because a head going under the water is instant. Exit after ~0.8 s, because bobbing at the
  surface toggles the flag and a flickering sheet is worse than a late one. This mirrors the
  asymmetric `ENTER_IN / ENTER_OUT` debounce the shelter test already uses.
- **The sound goes too.** Today a bed clip's volume is fixed at launch (`BedVolume`,
  ComfyRain.lua:1928), so it cannot be turned down mid-clip. Stop the bed slots with
  `StopSound(handle, fadeMs)` (in the client; fade behaviour **untested**) and let Blizzard's
  own underwater ambience take over. Skip thunder strikes while submerged.
- **Gloom off underwater.** Water has its own fog; our blue-grey on top of it doubles it.

**Build.** Poll `IsSubmerged()` on the existing 0.3 s `indoorTicker` (ComfyRain.lua:1788);
add `underwaterNow` beside `indoorsNow`; one more clause in `ShouldRain()`; stop and restart
the bed on the transition. Stub `IsSubmerged` in `test/harness.lua` and add a spec.

**Proof.** Dive in a lake while it rains: drops and hiss gone within a quarter second, back
within a second of surfacing, rain stays on while swimming at the surface.

---

## 2. Quick intensity control (#45)

**What they hit.** Changing intensity means opening the whole settings window.

**What is true now.** `/comfy light|normal|heavy|monsoon` already works (ComfyRain.lua:2356),
so a macro on a bar works today. `Bindings.xml` has toggle, panel and strike, but no
intensity. The minimap button takes left and right clicks only (UI.lua, BuildMinimap).

**World-class version.** No new frame on screen. The control should be where the hand
already is:
- **Mouse wheel over the minimap button steps intensity**, and the tooltip updates live
  ("Heavy rain"). Zero clutter, discoverable from the tooltip, and it is the thing an
  on-screen widget would have been for. Shift + wheel steps volume.
- **Two keybinds, Heavier and Lighter**, with no default key, matching the policy already
  written in `Bindings.xml`.
- **A one-line toast** on each step ("Heavy rain"), fading after ~1.5 s, so a keybind press
  gives feedback without the window.
- A floating widget only if people still ask after this ships. Most players hide every frame
  they can, so it would be a setting nobody turns on.

**Build.** `OnMouseWheel` on the minimap button, two `<Binding>` rows plus their
`BINDING_NAME_*` globals in UI.lua, and a step function shared with the panel's Intensity
selector so all three paths run the same `/comfy` command.

**Proof.** Wheel over the button walks light to monsoon and back; both keybinds appear under
AddOns in Key Bindings; the panel's Intensity row agrees afterwards.

---

## 3. A shade that stays on indoors (#43)

**What they hit.** With Indoors set to Dim, they saw no change in the lighting inside, and
asked for the slight shade to stay on.

**What is true now.** They are right, and the docs are wrong. `INDOOR_SEE = 0.0`
(ComfyRain.lua:1311), so under a roof "dim" removes the drops AND the darkening. Only the
sound stays, at 0.55. The README (line 86) still says indoors "fades to a faint wash", which
stopped being true when that number went to 0. Two causes, and only one is real:
- Real: the gloom is multiplied by `IndoorFactor()` in `ApplyAlphas`.
- Structural: the gloom texture lives on the same `overlay` frame as the drops, and that
  frame's alpha fades to 0 when `ShouldDraw()` goes false. So even a non-zero gloom factor
  would be faded out with the drops.

The earlier barbershop report was about a 25% wash of *drops* under a solid roof reading as
the addon failing. A room that is a little darker on a stormy day is a different thing, and it
is what being indoors in a storm actually looks like.

**World-class version.**
- **"Dim" means dim.** Drops off, the gloom kept at about 40% of outdoor strength, sound at
  0.55. That makes the default do what its name says.
- **A new "Sound only" level** for anyone who wants today's behaviour. The selector becomes
  Off / Sound only / Dim / On. Saved `"dim"` keeps meaning Dim, so nobody's file needs a
  migration; most players never changed it from the default anyway.
- **The fade stays smooth.** The gloom eases from 100% to 40% over the same 0.7 s walk fade
  the drops use, so the doorway build-up the commenter liked carries over to the light.
- **What they called patter** is the drip layer already planned in #34 (Worgen rain drips
  596024 and 1402221 are in the verified listfile). The verified listfile has no
  rain-on-roof loop, so a true roof patter needs a listfile search before it can be promised.

**Build.** Give the gloom its own alpha path: either move it to its own child frame or keep
the overlay shown while the shade is non-zero and fade the drop textures by their own alpha.
Add `IndoorFactor("shade")` returning 0.4 under Dim. Fix README line 86 in the same PR.

**Proof.** `tools/perceive.py` on two frames in the Stormwind inn, outdoors vs indoors, Dim
on: indoor frame measurably darker than with Sound only, and no visible drops. Then the
barbershop, the case that went wrong before, judged by eye.

---

## 4. Rain that builds, peaks and eases (#44)

**What they asked.** Cycles with intensities and timing they can set, so the rain varies
instead of sitting at one level.

**What is true now.** Intensity is four discrete presets (ComfyRain.lua:145). Each sets five
numbers (mist, far, near, speed, gloom), a thunder rate, a sound bed and sometimes a denser
near texture. Nothing changes them over time except gusts, which wobble the motion. #33 drifts
only the sound volume and is a different thing.

**World-class version.** Real rain does not cycle like a sine wave. It arrives as showers:
it builds, holds with small swells, eases, and leaves a lull. A storm front is one long arc.
That is what to model, and it is what no WoW weather addon does today.

- **Continuous intensity.** One number from light (0) to monsoon (3). The five numeric
  parameters lerp between the two nearest presets, so 1.5 is half normal and half heavy. The
  thunder rate lerps too, and strikes only schedule above heavy, so lightning arrives with
  the peak and leaves with it.
- **Showers, not a waveform.** A small state machine: lull, build (1 to 3 min, eased), peak
  (2 to 8 min, with the existing gust wobble on top), ease (2 to 4 min), lull again (3 to
  10 min). Each shower draws its peak from the player's range, so no two are the same.
- **Three patterns plus custom**, so nobody has to set timings to get a good result:

  | Pattern | What it does |
  |---|---|
  | Passing showers | Rain comes and goes, including a dry break now and then |
  | Steady soak | Stays within a narrow band and swells slowly. The closest to today |
  | Storm front | One arc over ~40 min: drizzle, downpour with thunder, clearing, then light rain |
  | Custom | `/comfy cycle light-heavy slow`: a range and a pace |

- **Sound follows without a seam.** The bed already runs two overlapping slots that relaunch
  every clip. Each relaunch picks the bed nearest the current intensity, at a gain lerped
  between presets, so the audio crossfades by itself. Lag is at most one clip (20 to 30 s),
  far shorter than a build phase.
- **The player stays in charge.** Stepping intensity by hand (wheel, keybind, panel) pauses
  the cycle; a "Changing" toggle in the panel turns it back on. The panel shows one live line:
  "Now: heavy, easing".

**The hard part.** Heavy and monsoon use denser near textures. Crossing light to heavy
smoothly needs a second near-texture slot so the two sheets crossfade by alpha across the
band, instead of popping at the threshold. Everything else is arithmetic on values that
already exist.

**Build.** A pure-Lua generator with a seedable RNG (testable offline in `test/`), a lerp in
`Preset()`, the second near slot, the bed picker reading the live intensity, the pattern
setting and slash command, and the panel line.

**Proof.** A spec that runs the generator for six simulated hours and asserts the value stays
in range, never jumps more than a small step per second, and actually varies. Then
`tools/perceive.py` frames across one storm-front arc, and an hour of play by ear.

---

## Reply to the commenter

The draft is in the chat from 2026-11-18. It promises #43, #45 and #46 and calls #44 "on the
list"; nothing above changes that. Post it now. When 1.1 is out, reply again to say what
shipped.

# Motion audit of a 2D screen-space rain and snow overlay (WoW: Forever)

Deep research report 1 of 2, received 2026-10-22, in answer to
`docs/motion-realism-research-prompt.md`. Verbatim. See
`docs/motion-research-reconciliation.md` for which of the two we are following and why.

---

Your speed-to-length invariant is correct. Several other numbers are wrong by a factor, and the errors show on screen. Heavy and monsoon rain fall 1.3-2.1x too fast. Snow above "light" falls 1.6-5x too fast. Rain and snow slants are 3-10x too small whenever there is any wind. Running is applied as a 66% vertical speed-up when it should be a heading-dependent tilt plus radial expansion. Camera rotation is ignored, and that is the most likely reason the overlay reads as a scrolling texture.

## TL;DR
- **Speeds:** the measured physics gives a light-to-monsoon rain span of about 1.7x (2.4x if "light" means drizzle), not 4.7x. Your 2.2x reading is right. Snow fall speed barely changes with intensity (about 0.85-1.15 m/s). A blizzard's apparent speed is about 90% horizontal transport and almost none of it is faster falling.
- **Directions and coupling:** slant follows tan th = u(1.7 m)/v. Even a 4 m/s breeze tilts moderate rain about 32 deg and snow about 60 deg. Your 7.5 deg and 3.4 deg imply a near-dead calm (10 m wind about 0.8 m/s and 0.09 m/s). Running and camera turning must enter as vectors, not as a fall-rate multiplier.
- **Ship-date priority:** fix these first, all visible and all cheap in 2D:
  - camera-yaw coupling, which is depth-independent;
  - running as tilt plus UV zoom about the focus of expansion;
  - the monsoon, heavy-snow and blizzard speeds;
  - wind-scaled slant with sheared (not just diagonally scrolled) streaks;
  - your two layers' near-identical ~0.94 s loop period.

  Layer lags, the first-person boost, the gust timescale and the gust clamp are wrong but nearly invisible.

## Assumptions about the client
- **FOV:** I assume the brief's 90 deg horizontal FOV on 16:9. The WoW `cameraFov` CVar defaults to 90 and appeared in retail patch 9.2.5. That it behaves the same way, and is horizontal, in the WoW: Forever / Classic-lineage client is an assumption, not something I verified. With 90 deg horizontal, tan(45 deg) = 1, so the vertical half-extent is 9/16 = 0.5625 focal lengths and the vertical FOV is 58.7 deg. One screen height (H) equals 1.125 focal lengths.
- **Frame rate:** 60-144 Hz with no motion blur, as stated.
- **Addon limits:** I assume addon textures can be scrolled, sheared and scaled through 8-value texture coordinates but get no custom shaders. Everything recommended below fits inside that.
- **Units:** H/s means screen heights per second for motion near screen centre. A drop at depth z moving at speed v perpendicular to the view axis has angular speed v/z rad/s, which is v/(1.125*z) H/s.

## Key Findings

| Item | Yours | Should be | Factor | Visible? |
|---|---|---|---|---|
| Camera yaw coupling | none | all layers shift by the same angular rate | infinite (missing) | **Yes, most damaging** |
| Running | x1.66 vertical rate | heading-dependent tilt + radial expansion; centre speed unchanged | wrong in kind | **Yes** |
| Rain monsoon near speed | 1.969 H/s | ~0.92 H/s | 2.1x too fast | **Yes** |
| Rain heavy near speed | 1.141 | ~0.86 | 1.33x too fast | Yes |
| Snow normal / heavy near speed | 0.257 / 0.449 | ~0.16 / ~0.19 | 1.6x / 2.4x too fast | **Yes** |
| Blizzard vertical speed | 0.820 | ~0.16 (+/- turbulent jitter) | 5x too fast | **Yes** |
| Rain slant | 7.5 deg fixed | ~22-56 deg, scaling with wind/v | 3-7x too small (tan) | **Yes** |
| Snow slant | 3.4 deg | ~22-50 deg unless dead calm | 7-20x too small (tan) | **Yes** |
| Blizzard slant | 78 deg | ~85 deg | tan 4.7 -> ~11 | Mild |
| Tiling loop | both layers repeat every ~0.94 s (normal) | incommensurate periods | n/a | **Yes** |
| Gust angle modulation | +/-14% per unit g | ~+/-38% per unit g (25% std) | 2.7x too small | Yes, in wind |
| Layer lags | 6.0 / 2.2 / 1.0 s | ~0 between layers; particle lag 0.1-0.9 s | 10-60x too long | Low |
| First-person +20% fall rate | +20% | 0% | n/a | Low |
| Gust tau | 7 s | ~3.5-5 s | <2x | Low |
| Gust clamp | +/-1.6 (2.4 sigma) | >= +/-2.3 (3.5 sigma) | n/a | Low |
| Speed/length invariant | 1/T for all depths | correct | - | - |
| Near/far ratio 2.03x | - | consistent with invariant | - | - |
| Rain light near speed | 0.421 | ~0.55 (light rain), ~0.39 (drizzle) | within +/-30% | Defensible |
| Snow light near speed | 0.157 | ~0.14 | 1.14x | Defensible |

## Recommended numbers (diff against what ships)

These are the same shape as your tables. They assume a crosswind (wind perpendicular to the view). The near layer stays at the depth your "rain normal" speed implies (about 5.5 m for a visual-mean fall speed of 4.4 m/s), and far = near/2.03 as now. Snow uses the same layer depths as rain, so rain and snow stay mutually consistent. If your snow art depicts flakes at a different depth, scale all snow rows by one common factor; the ratios are what matter.

| intensity | assumed conditions | far H/s | near H/s | slant (deg off vertical) | near along slant | near crosses screen in |
|---|---|---|---|---|---|---|
| rain light | ~1-2 mm/h, Dm~1.0 mm, v_vis 3.4 m/s, U10 2 m/s | 0.271 | 0.551 | 22 | 0.595 | 1.81 s |
| rain normal | ~5 mm/h, Dm~1.4 mm, v_vis 4.4 m/s, U10 4 m/s | 0.351 | 0.713 | 32 | 0.843 | 1.40 s |
| rain heavy | ~25 mm/h, Dm~1.8 mm, v_vis 5.3 m/s, U10 7 m/s | 0.423 | 0.859 | 43 | 1.166 | 1.16 s |
| rain monsoon | ~100 mm/h, Dm~2.0 mm, v_vis 5.7 m/s, U10 12 m/s | 0.455 | 0.924 | 56 | 1.64 | 1.08 s |
| snow light | v 0.85 m/s, U10 0.5 m/s | 0.068 | 0.138 | 22 | 0.149 | 7.25 s |
| snow normal | v 1.0 m/s, U10 1.0 m/s | 0.080 | 0.162 | 35 | 0.197 | 6.17 s |
| snow heavy | v 1.15 m/s, U10 2.0 m/s | 0.092 | 0.186 | 50 | 0.292 | 5.38 s |
| snow blizzard | v 1.0 m/s vertical, U10 16 m/s | 0.080 | 0.162 (+/- ~0.2 jitter) | 85 | 1.81 | 6.17 s vertical; ~1.0 s to cross screen width |

**Slant rule (replaces the constant):**

tan th = 0.695 * U10 / v_vis

The 0.695 is the log-profile ratio u(1.7 m)/u(10 m) for open terrain with roughness length z0 = 0.03 m. In calm weather use 0-5 deg for everything. Your 7.5 deg is exactly the calm-weather value for normal rain. Because wind and intensity are independent weather variables, add a wind parameter rather than tying slant to intensity. The U10 values in the table are my illustrative pairings, not data.

**Shear the streaks:** if you raise the slant, shear the texture coordinates (u += tan th * v across the quad) so the streak axis matches the motion direction. At 30-56 deg, scrolling vertical streaks diagonally reads as a sheet sliding sideways.

## Details

### 1. Rain fall speed versus rain rate

**Terminal velocity (measured, then fitted).**
- **Gunn & Kinzer (1949)** is the laboratory measurement everything else is fitted to. Speeds rise to an asymptote near 9 m/s for the largest drops.
- **Atlas, Srivastava & Sekhon (1973)** fitted it as v(D) = 9.65 - 10.3*e^(-0.6D), with v in m/s and D in mm.
  - Spot values: 1 mm -> 4.0 m/s; 2 mm -> 6.55 m/s; 4 mm -> 8.7 m/s.
  - Where it fails: it reaches zero at D = ln(10.3/9.65)/0.6 = 0.109 mm and runs low below about 0.5 mm. An immersed-boundary simulation (Ong, Miura & Koike, J. Atmos. Sci. 2021) of 0.025-0.5 mm drops matched Gunn & Kinzer's laboratory data within 4.5% only over 0.3-0.5 mm, and the Atlas fit departs strongly from the simulation below 0.5 mm.
  - It describes still air at sea level. Foote & du Toit (1969) give the aloft correction.
- Garg & Nayar's rendering papers use the cruder v = 200*sqrt(a) (a = radius in metres).
- Your 9 m/s is the speed of the very largest drops. It is not what the eye averages over.

**Drop-size distribution.**
- **Marshall-Palmer:** N0 = 8000 m^-3 mm^-1 and Lambda = 4.1*R^(-0.21) mm^-1. For an exponential DSD, Dm = 4/Lambda, so Dm grows as R^0.21 without limit.
- **Joss & Waldvogel:** one year of measurements at Locarno, Switzerland. N0 is 30 000 for drizzle, 7 000 for widespread rain and 1 400 for thunderstorm rain (m^-3 mm^-1). The JPL DESCANSO Propagation Handbook (Pub. 1082, section 2.3) notes that "the climatic regions where the Joss statistics apply have not been determined."
- **Disdrometer measurements show Dm stops growing at high rain rates, unlike Marshall-Palmer:**
  - *Bringi et al. (2003).* 2-min DSDs from 2D-video and RD-69 disdrometers at about eight sites, for example Darwin with 1 074 convective and 1 528 stratiform samples, and Graz with 94 and 1 952. They found "only weak correlation between Do and R." At high convective rain rates "the radar and disdrometer Do values tend to a stable value around 1.7-2.0 mm," and further increases in rain rate come from higher concentration (Nw), not bigger drops. Their maritime convective cluster has <Dm> ~ 1.5-1.75 mm; their continental cluster has <Dm> ~ 2-2.75 mm.
  - *Chang et al. (2009).* 2DVD in western-Pacific typhoons: Dm "remained about 2.2 mm when rainfall rate greater 50 mm/hr."
  - *Liao et al. (2020).* 213 465 one-minute Parsivel2 spectra from Oklahoma, Iowa and Virginia. They give mean R 2.12 mm/h and mean Dm 1.13 mm, and the R-Dm correlation is only r = 0.44. This dataset is mostly light rain.
  - A 2026 PNAS study combining 1,031 disdrometer sites with 10 years of GPM dual-frequency radar data puts the modal state at Dm ~ 1.5-1.8 mm, log10Nw 3.8-4.2 and R ~ 10-20 mm/h.
- **Model limits:** Marshall-Palmer is a model fitted to moderate midlatitude rain. Extrapolated to 100 mm/h it gives Dm ~ 2.6 mm, which overshoots the measured maritime and typhoon plateau of about 1.7-2.2 mm. The measurement should win there.

**What the eye weights.** Garg & Nayar show a drop's visibility rises with the square of its size. So I weight speed by projected area (D^2*N(D)) and use mass weighting (D^3) as an upper bound. For a gamma DSD with shape mu and Lambda = (4+mu)/Dm, the Atlas fit integrates in closed form:

v_bar = 9.65 - 10.3*[Lambda/(Lambda+0.6)]^(n+mu+1)

Here n = 2 for area weighting and n = 3 for mass weighting. The choice mu = 3 is my assumption; it is typical but varies event to event. Results:

| regime | Dm (measured basis) | area-weighted v_bar | mass-weighted v_bar |
|---|---|---|---|
| drizzle | ~0.7 mm | 2.4 m/s | 2.8 m/s |
| light rain (1-2 mm/h) | ~1.0 mm (Liao mean 1.13) | 3.4 m/s | ~3.9 m/s |
| moderate (~5 mm/h) | ~1.4 mm | 4.4 m/s | ~5.0 m/s |
| heavy (~25 mm/h) | ~1.8 mm | 5.3 m/s | ~5.9 m/s |
| tropical downpour (>=50 mm/h) | 2.0 mm (maritime/typhoon plateau) - 2.5 mm (continental) | 5.7-6.4 m/s | 6.25-6.9 m/s |

**Verdict.**
- Drizzle to downpour is 2.4x. Light rain to downpour is 1.7x. Your 4.7x is wrong by about a factor of 2-3. Your 2.2x reading is right.
- **Heavy and monsoon rain do not fall much faster than moderate rain**, because measured Dm saturates.
- What reads as "heavier" is how much projected area there is. Under Marshall-Palmer, total projected area per volume (proportional to 2N0/Lambda^3) rises about 18x from 1 to 100 mm/h, while total drop count rises only about 2.6x.
- That projected area sets streak coverage and extinction. With geometric extinction (Q_ext ~ 2) and Koschmieder's 3.912/beta, it implies visibility falling from about 11 km at 1 mm/h to about 0.6 km at 100 mm/h. This is a model; Marshall-Palmer is extrapolated above about 25 mm/h, and in the measured equilibrium regime area grows roughly linearly with R instead.
- **Map intensity to streak density, alpha, streak width and brightness, mist opacity (optical depth proportional to R^0.6-1.0), splashes and sheeting. Do not map it to speed.**

### 2. Snow fall speed

**Measured.**
- **Locatelli & Hobbs (1974):** hand-measured single particles in the Cascades, a modest sample. Aggregates of unrimed to lightly rimed dendrites at typical sizes fall at about 1.0-1.2 m/s. Graupel and densely rimed particles fall faster.
- **Brandes et al. (2007):** Colorado, 2D video disdrometer. V = 0.768*D^0.142 (D = equivolume diameter in mm), giving 0.90 m/s at 3 mm and 1.07 m/s at 10 mm. Mass-weighted mean fall speed rose from about 0.9 to 1.3 m/s as surface temperature warmed from -5 to 0 C. At -10 C, even 10 mm aggregates averaged under 1 m/s.
- **Garrett & Yuter (2014), MASC at Alta, Utah** (88 351 hydrometeors in the companion 2015 paper):
  - "On average, the fall speed of rimed particles was not notably different from aggregates."
  - "In high turbulence and at low temperatures, any sensitivity of fallspeed to particle size disappears."
  - The fall-speed mode was about 1 m/s, spread wider by turbulence.

**Span.**
- Light to heavy snow is about 0.85 -> 1.15 m/s (1.35x). Wet or rimed heavy snow near 0 C can reach about 1.5 m/s (1.8x).
- Your light-to-heavy span of 2.9x is not defensible.

**Blizzard.**
- Vertical fall stays about 1 m/s. Suspended blowing-snow grains are small; Mellor cites a mean radius of 44 um at 2 m, and a visibility model uses a 0.35 m/s settling speed.
- Their "horizontal particle velocity u is equal to the wind velocity" (Mellor, CRREL).
- At U10 = 16 m/s, about 11 m/s at 1.7 m, the along-path speed is sqrt(11^2 + 1^2) ~ 11 m/s. Over 99% of that is horizontal by velocity component, and the slant is about 85 deg.
- **So your 5.2x (light vertical to blizzard vertical) is wrong.** Vertical speed should stay roughly the same. The physically right total-speed ratio at fixed depth is about 13x (11/0.85), and nearly all of it belongs in the horizontal component.

### 3. Slant

**Derivation.**
- A particle at terminal velocity in a horizontal wind u moves with the wind horizontally, so tan th = u/v_t.
- Neutral log profile: u(z) = (u*/k)*ln(z/z0). With z0 = 0.03 m (open terrain; WMO and ESDU use it as standard), u(1.7)/u(10) = ln(56.7)/ln(333) = 0.695.
- **Where the log profile stops applying:** it assumes near-neutral stability, uniform fetch, and z well above z0. It fails near buildings, forest edges, hills and in strongly stable or convective air.

**Sources of angle spread within one frame (model):**
1. **Height.** The frame spans roughly 0.5-4 m above ground in the near field, where u ranges 0.48-0.84 x U10, so tan th varies about +/-25%.
2. **Drop size.** At one wind, a 0.5 mm drop at 2 m/s and a 2 mm drop at 6.5 m/s differ about 3x in tan th. This is the largest source.
3. **Turbulence.** sigma_tan = sigma_u/v_t, with turbulence intensity at 1.7 m about 1/ln(z/z0) ~ 0.25 in open country. ESDU 85020 gives 21% at 10 m over z0 = 0.03 m.

**Scenarios:**

| scenario | assumed wind | mean angle | spread |
|---|---|---|---|
| (a) light shower with a breeze | U10 3 m/s -> 2.1 m/s at 1.7 m; v_vis 3.4 m/s | ~32 deg | big drops ~18 deg, small drops ~45 deg; +/-~8 deg (1 sigma) from turbulence |
| (b) thunderstorm | U10 10 m/s -> 7 m/s at 1.7 m; v_vis 5.7, big drops ~8.5 m/s | ~50 deg (big drops ~40 deg) | sigma ~ +/-8 deg; 3-s gusts at in-land factor 1.66 push past 60 deg |
| (c) blizzard | U10 16 m/s; snow 1 m/s | ~85 deg | +/-~2 deg (82-86 deg), i.e. effectively horizontal; vertical motion is dominated by turbulence (see section 4) |

**Verdict.** 7.5 deg is both too small and wrongly constant, as you suspected. Slant should scale with wind divided by fall speed. At the same wind, heavier rain (bigger, faster drops) is slightly *steeper*, not shallower.

### 4. Gusts

**Is OU right?** OU has an exponential autocorrelation, which is how an integral timescale is defined. That makes it a defensible first-order model.
- Its spectrum rolls off as f^-2 against turbulence's f^(-5/3), so it is a little too smooth at short timescales.
- Real gusts are also intermittent and skewed.

**Timescale.**
- Near-surface measurements over flat Utah desert (SLTEST) found the longitudinal integral length scale grows with height at roughly constant integral timescale.
- An ESDU 83045 approximation quoted by Kwon & Kareem gives T_u ~ 3.1*z^0.2 s, about 3.5 s at 1.7 m and about 5 s at 10 m. I read that formula from a garbled snippet, so treat it as approximate.
- Your tau = 7 s is within 2x: defensible, low priority.

**Amplitude.**
- WMO guidance (Harper, Kepert & Ginger 2010, Table 1.1) gives 3-s gust factors relative to the 10-min mean of 1.66 in-land, 1.52 off-land, 1.38 off-sea and 1.23 at sea.
- Peak factors are about 3.0-3.7 standard deviations.
- Your clamp at +/-1.6, which is 2.44 sigma of your 0.655 stationary spread, removes exactly the 3-3.7 sigma events that make a gust read as a gust. Raise it to >= +/-2.3.

**Angle versus speed: angle should get the larger share.**
- In neutral surface-layer turbulence sigma_u ~ 2.5u* and sigma_w ~ 1.25u*, so vertical fluctuations are about half the horizontal ones. (These ratios are textbook surface-layer values, not from the sources above.)
- Slant changes as sigma_u/v_t. Fall rate changes as sigma_w/v_t, which is about half of that.
- **Angle modulation should be a constant fraction of slant**, set by turbulence intensity: about 25% std at 1.7 m, or +/-0.38 per unit of your g. Your +/-14% is about 2.7x too small.
- **Fall-rate modulation should scale with wind over fall speed:** 0.5*Iu*U(1.7)/v_t. That is about 8% std for normal rain at U10 = 4 m/s, about 18% for a 12 m/s storm, about 37% for snow at U10 = 4 m/s, and over 100% in a blizzard, where flakes rise and fall.
- Your +/-18% is fine for rain but too small for snow. Scaling by intensity (0.45/1.0/1.5/2.0) is the wrong driver; it should scale by wind.

### 5. Should precipitation lag the wind?

**Derivation.**
- Take drag F = m*g*(|v_rel|/v_t)^n, with n = 1 for Stokes drag and n = 2 for quadratic drag.
- Linearise around steady fall with a small horizontal perturbation u'. The horizontal drag component is m*g*u'/v_t whatever n is.
- So the horizontal relaxation time is tau_h = v_t/g in both regimes. The vertical one is tau_v = v_t/(n*g).

**Values:**

| particle | v_t | tau_h | notes |
|---|---|---|---|
| 1 mm raindrop | 4.0 m/s (Atlas fit) | 0.41 s | |
| **2 mm raindrop** | 6.55 m/s | **0.67 s** | falls ~4.4 m while adjusting |
| 4 mm raindrop | 8.7 m/s | 0.89 s | |
| **3 mm unrimed aggregate** | 0.90 m/s (Brandes 2007) | **0.092 s** | |

**Between layers.** Gust eddies near the surface are tens to hundreds of metres long (integral length = T_u*U). Your visible depth range of 1-30 m is far smaller, so all layers feel the same gust at essentially the same moment.

**Verdict.**
- Lag should depend on particle type: about 0.4-0.9 s for rain, about 0.1 s for snow, and about 0 for mist and blowing-snow dust. It should not depend on layer.
- Your 6.0 / 2.2 / 1.0 s are 10-60x too long and ordered the wrong way. This is wrong but low-visibility. Set all three to one value per weather type.

### 6. Observer motion

**Relative velocity.** V_rel = V_precip - V_player.

**Worked case: 7 m/s run, 9 m/s rain, no wind.**
- Apparent angle: atan(7/9) = 37.9 deg off vertical.
- Apparent speed: sqrt(130) = 11.4 m/s, +27%.
- At the visually dominant 4.4 m/s for moderate rain: 57.8 deg and 8.27 m/s, +88%.

**What you apply now.** Your rate factor is (1 + 2.2*0.3) = 1.66 on vertical screen speed. That is the wrong component: the vertical relative speed does not change when you run.

**Screen-space form.** Use normalised image coordinates (x, y) in focal units, y up and z forward. A drop at depth z with relative velocity (Vx, Vy, Vz) moves on screen at:

xdot = (Vx - x*Vz)/z,  ydot = (Vy - y*Vz)/z

Camera rotation adds a further term that does not depend on depth (see the camera-turning bullet below).

**Running straight ahead (psi = 0).** Vz = -7 and Vy = -9.
- The flow radiates from the focus of expansion at (0, Vy/Vz) = (0, +1.29) focal units. That is 1.14 H above screen centre, or 0.64 H above the top edge. With 4.4 m/s rain it sits just above the top edge.
- The centre column keeps exactly the standing-still speed.
- Bottom-centre speed is 1.44x and top-centre is 0.56x.
- Streaks splay outward: about 28 deg at the bottom corners and about 54 deg at the top corners.
- **The correct effect of running forward is a fan, not faster rain.**

**Turning: heading psi relative to camera forward.**
- Vx = -s*sin psi and Vz = -s*cos psi.
- Centre slant: tan th = s*sin psi / v_t, plus the wind term.
- Expansion rate of a layer at depth z_L: s*cos psi / z_L per second.
- At psi = 90 deg (camera swung to the side while running) you get a uniform 37.9 deg slant leaning against the motion and no expansion.
- Running toward the camera (psi = 180 deg) gives contraction.

**Camera turning.** Yaw rate omega shifts every depth equally, by about f*omega. For 90 deg horizontal FOV that is omega/2 screen widths per second (omega in rad/s), which is 1.57 screen widths per second at 180 deg/s. In UV terms, add (omega/2)*tilesX*dt to each layer's o.x with the correct sign.

**Camera pitch.**
- Pitch moves the vanishing point of vertical lines to y_vp = -cot(pitch) focal units.
  - At 20 deg down that is 2.75 focal units below centre. Streaks then converge downward, tilted about 17 deg at the top corners and about 25 deg at the bottom corners.
  - At 45 deg down the vanishing point sits just below the bottom edge, and bottom-corner streaks tilt about 66 deg.
- Lateral fall speed also scales by cos(pitch).

**Implementing it in 2D.**
- Expansion: zoom each layer's UVs about the FOE at rate s*cos psi / z_L. Run two copies per layer on a zoom-and-crossfade cycle so the streaks don't grow without limit.
- Pitch convergence needs a projective warp. Approximate it with 4-8 vertical strips, each sheared differently.

**First-person +20%.** The depth distribution of rain starts at the camera whether or not it is pulled in, so zoom distance should not change rain speed. Remove it. Low priority.

### 7. Angular velocity versus depth

Drops near screen centre, moving perpendicular to the view, at 90 deg horizontal FOV on 16:9:

| depth | 4.4 m/s (moderate-rain visual mean) | 9 m/s (largest drops) | 1 m/s (snow) |
|---|---|---|---|
| 1 m | 252 deg/s, 3.91 H/s | 516 deg/s, 8.0 H/s | 57 deg/s, 0.89 H/s |
| 3 m | 84 deg/s, 1.30 H/s | 172 deg/s, 2.67 H/s | 19 deg/s, 0.30 H/s |
| 10 m | 25 deg/s, 0.39 H/s | 52 deg/s, 0.80 H/s | 5.7 deg/s, 0.089 H/s |
| 30 m | 8.4 deg/s, 0.13 H/s | 17 deg/s, 0.27 H/s | 1.9 deg/s, 0.030 H/s |

**Which depths dominate (my derivation; I found no perceptual measurement).**
- At 1080p one pixel is about 1.0 mrad, so a 2 mm drop is narrower than a pixel beyond about 2 m.
- Up to that point, the number of drops in a depth shell grows as z^2, while each streak's screen area falls as 1/z^2. So each metre of depth contributes equal streak coverage.
- Beyond it, contrast per drop falls as 1/z as well. Each octave of depth (1-3, 3-10, 10-30 m) then contributes about equally until attenuation turns rain into haze.
- The motion the eye locks onto is that of the nearest resolvable, long, high-contrast streaks: about 1-5 m. At 10-30 m streaks are only a few pixels long and read as texture or haze.

**Is two-layer parallax enough?**
- Your near and far layers sit at about 5.5 m and 11 m (inferred from your normal-rain speeds). That spans one octave of a roughly 30x speed range and misses the 1-3 m band, which moves 2-5x faster than your near layer.
- Two layers are adequate for the far field. A sparse third "very near" layer at about 2 m (about 2.75x your near speed, low density, bright streaks) is the cheapest way to add the depth cue.
- This is optional, and the evidence behind it is model-based only.

### 8. Vertical motion that is not falling

**Rain.**
- Near-ground sigma_w ~ 1.25u*, about 0.5-1 m/s even in strong wind, against fall speeds of 4-6 m/s. Rain essentially never reverses in open terrain.
- Drops blown upward past a window come from flow around buildings. Not worth representing.

**Snow: yes, worth representing.**
- sigma_w is comparable to v_t (about 1 m/s), so flakes routinely pause and rise in any breeze. Garrett & Yuter's turbulence-broadened fall-speed distributions are the measured signature.
- Add a zero-mean vertical jitter with std ~ 0.5*Iu*U(1.7)/v_t of the fall rate, using a timescale of about T_u.

**Blowing snow: represent it as a separate low sheet.**
- Continuous blowing snow typically starts around 11 m/s (Takeuchi et al.). The threshold ranges from 1.9 m/s for very light dry snow to 10.5 m/s for wind-hardened snow (Male 1980).
- Particles move horizontally at wind speed and settle at about 0.35 m/s.
- ICESat-2 measured blowing-snow layers over Arctic sea ice (Robinson et al., The Cryosphere 2026, November-April 2018-2023) with a median depth of 30 m at about 4 m/s (MERRA-2 10 m) wind, rising to over 150 m above 14 m/s; the retrieval cannot detect layers thinner than 20-30 m.
- For a blizzard, add a dense, nearly horizontal, low-alpha layer weighted toward the bottom of the screen. It carries most of the horizontal motion and visibility loss, while the falling-snow layers keep about 1 m/s vertical speed.

### 9. What makes precipitation read as fake

**Evidence base.** There is little: I found no controlled perceptual study ranking motion cues for rain realism. What exists is rendering practice and stated failure cases.
- **ATI ToyShop** (Tatarchuk 2006) used a single screen quad with several rain layers in one pass and artist-set direction and speed. Lagarde (Dontnod, *Remember Me*) names its weakness: "when the camera is moving around... looking downward make raindrops falling parallel to the ground."
- **Flight Simulator 2004** mapped four textures onto a double cone and tilted it "to adjust for camera movement" so precipitation falls toward the camera. It scaled down and slowed each successive texture for parallax.
- **Remember Me** used four layers of a pre-motion-blurred streak texture on a camera-attached half-cylinder, half-cone, translated and scaled per layer at different speeds.
- **Garg & Nayar's model** treats rain as a wide-sense-stationary random field. Its temporal correlation is high only along the rain direction, so streak orientation and motion direction must agree.

**My ranking** (inference from the above plus the geometry in section 6; not a measured result):
1. **Screen-locked under camera rotation and pitch.** Real near rain is world-fixed, so it must sweep across the screen at the camera's angular rate and converge toward the vertical vanishing point when you look down. That rotational flow is depth-independent, so a 2D overlay can implement it exactly. This replaces your candidate as the top tell.
2. **Global loop periodicity.** A layer's temporal period in sheet units is 1/(layerSpeed*rate*tiling), and your two layer speeds are nearly equal (1.07 and 1.05). So both layers repeat at almost the same period: 0.935 s near and 0.952 s far for normal rain, about 0.34 s for monsoon. Several copies of each sheet are also visible at once. Make the periods incommensurate (for example a 1.618 ratio), add random UV jumps or a rotation per cycle, or crossfade between differently seeded sheets.
3. **Streak orientation not matching motion.** This becomes severe at the 30-56 deg slants recommended here unless you shear the UVs.
4. **Running and turning with no change in shape** (section 6).
5. **Your candidate, a speed/length ratio that differs between layers.** It is real but second-order, and your current layers do not have it.

### 10. Frame rate and sampling

**Exposure.**
- A streak of length L moving at image speed v_img encodes an exposure T = L/v_img. Your invariant (speed/length = 1/T at every depth) is correct, and an effective exposure is the right way to think about baked streaks. Fix T in seconds, not frames.
- Reference points: a 180 deg shutter at 24 fps gives T = 20.8 ms. Garg & Nayar treat about 30 ms as typical for video. At 1 ms rain freezes into bright points.
- Human temporal integration for motion streaks was measured at 77 ms at high luminance (Apthorp et al. 2011, PLOS ONE). Geisler (1999) assumed about 100 ms.

**Rule for no gaps.** Choose T >= 1/f_min, i.e. >= 16.7 ms for 60 Hz. Then per-frame displacement v_img/f never exceeds streak length, and you avoid the phantom-array "dotted" look.
- Example: your monsoon near layer moves 0.033 H/frame (36 px at 1080p) at 60 Hz, against a 44 px streak at T = 20.8 ms. That is just continuous.
- At my recommended 0.92 H/s it is 15 px/frame.

**Aliasing.** Stroboscopic reversal needs per-frame displacement to approach the spacing between similar streaks along the motion direction. That is far off at these speeds, unless the texture period itself becomes visible (see section 9, item 2).

**60 vs 144 Hz.** With T >= 16.7 ms in seconds, nothing needs to change between 60 and 144 Hz. At 144 Hz the eye integrates about 11 frames and adds its own smear. Stretching streaks by velocity x frame time is the particle-system convention; it does not apply to baked art. I could not verify what the NVIDIA rain SDK sample does here.

## Caveats
- **Measured versus model.** Measured: terminal velocities, disdrometer Dm plateaus, snow fall speeds, gust factors, the turbulence-intensity anchors and visual integration time. The rest is model or derivation: log-profile slants, the mu = 3 visual weighting, extinction-based visibility, depth dominance and the cue ranking.
- **Visual weighting is my modelling choice.** If the eye weights the fastest, brightest large drops more than D^2, all rain speeds shift up 10-15% together. The spans stay about the same.
- **Wind-intensity pairings in the table are illustrative.** Real downpours can be calm, and drizzle can be windy.
- **Thin sources.** The ESDU T_u formula and the typhoon Dm figure came from snippets. Locatelli & Hobbs and Gunn & Kinzer are older, small-sample lab or field measurements, still the standard references.
- **Client behaviour.** WoW FOV semantics and what addons can do in the WoW: Forever client are assumptions to check in-game.

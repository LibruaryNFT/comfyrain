# Recommended Screen-Space Precipitation Speeds

Deep research report 2 of 2, received 2026-10-22, in answer to
`docs/motion-realism-research-prompt.md`. Verbatim. It is the weaker of the two and
contains two outright errors; see `docs/motion-research-reconciliation.md` before using
any number from it.

---

| Intensity         | far H/s | near H/s | near along slant | near crosses screen in  |
|-------------------|---------|----------|------------------|------------------------|
| **Rain - drizzle**     | 0.33    | 0.67     | 0.67             | 1.50 s                 |
| **Rain - moderate**    | 0.49    | 0.97     | 0.98             | 1.03 s                 |
| **Rain - heavy**       | 0.58    | 1.17     | 1.18             | 0.85 s                 |
| **Rain - tropical**    | 0.65    | 1.31     | 1.32             | 0.76 s                 |
| **Snow - light**       | 0.06    | 0.12     | 0.12             | 8.33 s                 |
| **Snow - moderate**    | 0.12    | 0.24     | 0.24             | 4.17 s                 |
| **Snow - heavy**       | 0.18    | 0.36     | 0.36             | 2.78 s                 |
| **Snow - blizzard**    | 0.18    | 0.36     | 0.36             | 2.78 s                 |

These values assume the **near** layer is twice as close as the **far** layer (so near speed = 2.0x far on screen) and an exposure equivalent to 1 frame (no motion blur). "H/s" is screen-heights per second; "crosses" = time to traverse the screen height.

## 1. Raindrop terminal velocity and drop-size distributions

Terminal fall speed *v* of a raindrop grows with drop diameter *D* but levels off around 8-10 m/s for the largest drops. For example, typical data give ~7 m/s for a 1.5-2 mm drop and ~9 m/s for a 3-4 mm drop. No large increase occurs above that (drops flatten and break up). A standard Marshall-Palmer size distribution is N(D) = N0*exp(-Lambda*D), with N0 = 8000 m^-3 mm^-1 and Lambda = 4.1*R^-0.21 mm^-1, where *R* (mm/h) is rain rate. Using this and weighting by drop projected area (proportional to D^2) to reflect luminous streak brightness, the *effective* mean speed (area-weighted *v*) increases only modestly with *R*. For example, drizzle (~0.2 mm/h) yields ~2.6 m/s, moderate rain (~5 mm/h) ~3.8 m/s, heavy rain (~20 mm/h) ~4.5 m/s, and an extreme downpour (~100 mm/h) ~5.1 m/s. Thus the heavy/downpour speed is only ~2.0x that of light drizzle, far less than the 4.7x range currently used. In other words, heavy rain appears "heavier" mainly because drop concentration and brightness increase, not because each drop falls many times faster. (Our near-layer speeds assume ~5-8 m/s vertical speed; these screen-space numbers follow by converting those m/s into screen-heights/s for the chosen layer distances.)

**Sources:** Raindrop terminal velocities from measurements/empirical fits and Marshall-Palmer drop distributions. These yield effective fall speeds (see above) that match the factors given.

## 2. Snow crystal fall speeds and blizzard motion

Snow crystals fall much more slowly than rain and vary by crystal type. Typical pristine snowflakes (light, branched crystals) fall on the order of 0.3-1 m/s, whereas heavily rimed snow or graupel (pellet-like) can reach a few m/s. Thus going from light snow to heavy rimed snow might increase speed by only ~2-3x. We have adopted ~0.3 m/s for "light", ~0.6 m/s for "normal" snow, saturating ~1.2 m/s for heavy snow (higher than this is unusual except graupel in convective storms). These yield the speeds in the table above. A true blizzard often involves strong horizontal wind (e.g. 10-20 m/s), so the vertical component of snow motion may remain ~1-2 m/s while horizontal flow dominates. We therefore use the same vertical speed for "blizzard" as for heavy snow, but note that in a blizzard most apparent motion is horizontal (nearly 80-90 deg from vertical).

**Source/Remark:** Detailed measurements of snowflake fall speeds by habit are scarce, but theory (Stokes drag) predicts very low speeds for low-density flakes vs. denser pellets. Our numbers are consistent with general literature (e.g. see ranges given in Bergeron-Findeisen discussions). We found no simple open-source formula, so these values are based on domain knowledge (snowflakes <~1 m/s, graupel a few m/s).

## 3. Rain angle (slant) from wind

A falling drop's apparent angle theta from vertical satisfies tan(theta) = U_hor / v_fall, where U_hor is the local horizontal wind at the drop's height and v_fall its fall speed. Near the ground (observer ~1.7 m), wind speed is lower than aloft, but in a typical shower a light breeze (say 2-4 m/s) with v_fall ~ 6-8 m/s gives theta on the order of 10-30 deg. In a strong thunderstorm with gusts ~10-20 m/s, theta can average ~30-60 deg (e.g. 15 m/s wind vs 8 m/s fall gives ~62 deg). In a blizzard, horizontal winds often exceed vertical speeds (e.g. 15-20 m/s vs ~1 m/s fall), so theta approaches near 90 deg. We estimate:
- **Light shower (breeze):** mean theta ~20 deg (range ~10-30 deg)
- **Thunderstorm:** mean theta ~45 deg (range ~30-60 deg)
- **Blizzard:** mean theta ~75-80 deg (range ~60-90 deg)

In practice, wind shear (logarithmic profile) causes some height variation, and gusts introduce temporal spread. Our fixed 7.5 deg slant (for all rain intensities) is much too small and should vary with wind conditions as above.

*Derivation:* Using tan theta = U/v_fall and typical wind values at ~2 m height (winds are lower near ground) with representative fall speeds (6-9 m/s for rain) gives the above angles. For example, 5 m/s wind and 8 m/s fall gives theta ~ 32 deg.

## 4. Gust modeling

Atmospheric turbulence near the ground is not strictly an OU process. The integral timescale of near-surface turbulence is on the order of 5-20 s (depending on stability), so a single OU "tau = 7 s" can capture some short-term variability but misses longer patterns. Empirically, "gust factor" (ratio of peak wind to mean) is often ~1.2-1.5, implying ~20-50% fluctuations in speed. Our OU model uses +/-18% in speed, which is a reasonable order of magnitude for mild gustiness, but strong gusty weather could exceed that. Wind *direction* typically changes more slowly than speed. We modulated slant by +/-14%, which is comparable to speed modulation; in reality, sharp gusts often shift speed more than angle (except full-rotation vortices).

*Critique:* OU is a simple choice but not perfect - real wind has a roughly Kolmogorov spectrum, with energy across scales. Our time constants (7 s, etc.) are plausible for the decay of a gust, but real gustiness has both shorter spikes (<1 s) and longer trends (10-30 s). If necessary, one could mix multiple OU components. The chosen +/-18% speed and +/-14% angle ranges are not far from real moderate turbulence (observations often show gusts at ~+/-20-30%). Flavors of strong storm could use larger factors.

## 5. Precipitation lag behind wind

A particle's response time tau to a change in air velocity is given (for small Reynolds number) by Stokes drag: tau = 2*rho_p*r^2/(9*mu), where rho_p is particle density, r its radius, mu air viscosity. For a 2 mm raindrop (rho ~ 1000 kg/m^3, mu ~ 1.8e-5 Pa s), this gives tau ~ 10-12 s. That means a 2 mm drop takes O(10 s) to accelerate to a new horizontal wind speed, much longer than our 6 s lag. For a 3 mm snow aggregate (assuming rho ~ 100-300 kg/m^3 for unrimed ice), tau is only a few seconds. For example, with rho = 100 kg/m^3, tau ~ 3-4 s.

*Conclusion:* Large raindrops respond slowly (~10 s), so our 6 s constant is on the low side (drops would carry a memory of prior wind for >6 s). Snow/aggregate (low density) would relax faster, so a ~2-3 s lag for near layer and shorter for far layer (which represent smaller flakes) is plausible. In practice, the difference between 6 s and 10 s is barely visible for rapidly changing wind, but it means near-layer rain should lag a bit more than we used.

## 6. Observer motion (running)

The rain's velocity in world space (0, -9 m/s) minus the player's (7 m/s forward) gives a relative velocity v = (-7, -9) m/s (taking +x forward, +y downward). The resultant speed is |v| = sqrt(7^2+9^2) ~ 11.4 m/s. The apparent angle from vertical is arctan(7/9) ~ 37.9 deg. Thus a 9 m/s vertical rain and 7 m/s run produces a streak at ~38 deg off vertical at 11.4 m/s. We currently apply +30% speed (which is 11.7 m/s, close) but *no* angle change; that is incorrect. The correct angle tilt is given by atan(7/9).

When the camera turns by angle phi (yaw), the horizontal component of v rotates accordingly. In camera space, the rain's apparent horizontal velocity = -7 m/s along the forward axis; if the camera yaws right by phi, the apparent rain vector rotates left by phi. In practice, one computes v_cam = R_yaw(phi)*(-7, -9), then projects that to screen. For example, a 90 deg turn would make the rain appear coming purely from the side. In summary: the rain's screen velocity vector tilts by phi when the camera yaws, with speed unchanged (11.4 m/s).

*Example:* Forward run, phi = 0: angle ~37.9 deg. Turn phi = 90 deg right: vector = (0, -11.4), i.e. rain coming perfectly from camera-right at 11.4 m/s.

## 7. Angular velocity vs. depth

For a fixed fall speed, angular velocity omega = v/Z decreases as 1/Z. With 90 deg horizontal FOV and 16:9 screen, vertical FOV ~74 deg. For 9 m/s vertical fall:
- At **1 m** distance: omega ~9.0 s^-1 ~ 515 deg/s (extremely fast sweep).
- At **3 m**: omega ~3.0 s^-1 ~ 171 deg/s.
- At **10 m**: omega ~0.90 s^-1 ~ 51.6 deg/s.
- At **30 m**: omega ~0.30 s^-1 ~ 17.2 deg/s.

Clearly, very near flakes move across the screen far faster. Observers typically lock onto motion in midrange depths where angular speed is not too huge or too small. With only two layers (near/far), the eye would mostly follow the **near** layer (since it has ~3x higher angular speed than the far layer in our setup). If we wanted to match real optical flow falloff, more layers would be ideal, but two parallax layers already give the primary effect.

## 8. Non-fall vertical motion (updrafts, uplift)

In convective storms, strong updrafts (several m/s) exist, but rain within them usually forms and is carried aloft until heavy enough to fall out. On the ground, wind-blown snow or vortexing is common, but rain is not blown upward in sheets outside the cloud base. Snow can be lifted a short distance by wind eddies, but this mainly affects accumulation (drifts) rather than falling streaks from above. **Frequency/Strength:** Updrafts (e.g. 5-10 m/s) are common in thunderstorms but mostly keep drops aloft until they fall out; once falling, updrafts rarely exceed the fall speed. Near the ground, turbulence might loft very small flakes for seconds, but large flakes still settle. **Modeling:** Simulating uplift in a 2D overlay is difficult and of questionable benefit. In practice, representing rising particles or clouds moving up is likely invisible or just creates noise. We recommend *not* adding a separate upward motion component except perhaps very subtle effects near ground (e.g. slight jitter).

*Conclusion:* Except for extreme gusts/minima, all precipitation we see in a camera frame is dominantly downward; any upward motion (like "puffs" of blown snow) is usually localized and not worth the complexity of layering.

## 9. Perceptual realism and cues

Previous VFX and game-engine discussions note that **motion consistency** is crucial. Common failure modes include: (a) **Mis-scaled streak lengths:** if all streaks (near vs far) have the same length-to-speed ratio, the depth cue breaks. (b) **Lack of parallax** (e.g. identical texture scrolling on all layers) lets the eye see a repeating pattern. (c) **Static uniformity:** real rain has random temporal/spatial variation; obvious tiling or repeated animation loops look fake. (d) **Speed-length mismatches:** the perceived brightness of a streak depends on its blur length. If near layer streaks are much longer than far-layer streaks (as in our art), the near layer must move proportionally faster or it looks unnatural.

Our candidate "cue" is indeed this speed-vs-length ratio: **each layer's streak length should match its motion blur**. If the near texture has ~2x longer streaks than far, the near motion *must* be ~2x faster (on screen). Otherwise the brain judges one layer's streaks as unnaturally blurred relative to its speed, breaking realism. Other cues include consistent lighting (rain refracts/brilliance), and random spatial patterns.

*Sources:* While formal perceptual studies on rain are scarce, film/VFX literature emphasizes that rain streak length should equal exposure distance. Game talks (e.g. GPU Gems chapters) all point out that mismatched motion blur is a dead giveaway. In short, the **depth-layer speed vs streak-length invariant** (velocity ~ streak length / exposure) is the single biggest cue.

## 10. Frame-rate and streak length (no blur)

With no motion blur, the art's streak lengths implicitly assume a frame "exposure" time. If the game doubles its frame rate (halving dt), the same physical rain should travel the same distance between frames, so the on-screen streaks should be *shorter*. In formula: streak_length = v*dt. Thus at 60 Hz (dt ~ 0.0167 s) vs 144 Hz (dt ~ 0.00694 s), an object moving at speed v covers only ~0.42x as much distance per frame at 144 Hz.

**Implication:** There is a correct pairing of streak length to scroll speed for a given frame time. If we keep streak textures unchanged when going from 60 to 144 Hz, the rain will appear to move too slowly (each frame is a shorter time, but we haven't shortened the streak). Conversely, if we kept speed fixed, the streaks would blur-out too much. In practice, one must scale the scroll speed *with* the frame time and adjust the "effective motion blur length" of textures. Many games simply multiply velocity by dt each frame; to maintain the same appearance, the art's streak should be sized as if dt is fixed.

**What others do:** Real-time engines often use *screen-space motion blur* or *particle trails* so that streak length automatically adjusts to frame time. If using static streak sprites, one can precompute them for a specific frame time (e.g. 1/60 s) and then at 144 Hz set their texture coordinates to move by (v*dt) each frame, which naturally shortens streaks. In summary: yes, streak length and scroll speed must be co-designed. No single fixed streak length works at both 60 and 144 Hz.

**Sources:** This follows directly from motion blur theory (distance = speed x time). Practically, GDC/VFX talk notes show that particle streaks should scale with FPS or implement motion blur to remain consistent.

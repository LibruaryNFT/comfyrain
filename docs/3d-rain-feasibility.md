# Can an addon draw rain in the world? An exhaustive answer

**Asked 2026-10-19.** "Are we absolutely sure we cannot do anything for 3D rain
outside? Can we truly exhaust all options?"

**Answer: no, and the reason is structural rather than a missing function.** The
block is not one absent API that Blizzard might add. It is that the addon layer
has no read or write access to the 3D scene at all: not to its geometry, not to
its depth, not even to where a world point lands on the screen.

Every claim below was checked against the strings of the shipping client,
`WowB.exe` build 1.60.1.70425, 86.5 MB, on 2026-10-19. The method is the one
`tools/api_audit.py` uses. **Positive control first**, because a zero is
worthless from a search that cannot find anything: `GetPlayerMapPosition`,
`weatherDensity`, `PlaySoundFile` and `GetPlayerFacing` all hit, so the search
works and a zero below means absent.

## The four things that would each be enough, and are each missing

| What you would need | Searched for | Hits |
|---|---|---|
| Put a sprite at a world coordinate | `WorldToScreen`, `ProjectWorldPoint`, `GetScreenPositionFromWorld`, `ScreenPositionForWorld` | **0** |
| Know where the camera is looking | `GetCameraPitch`, `GetCameraYaw` | **0** |
| Know what is in front of what | `DepthBuffer`, `GetDepth`, `ZBuffer`, `SetDepthTest` | **0** |
| Make the engine's own rain fall | `SetWeather`, `SetWeatherType`, `WeatherOverride`, `RequestWeather` | **0** |

Any one of those would open a door. All four are shut.

## The near misses, and why each one is not a door

**`C_Weather` exists, and is read-only.** The namespace is in the binary. It
contains exactly one function, `GetCurrentWeather`. There is no setter anywhere
in the executable. Weather type is chosen by the server and sent down; the
client CVar `weatherDensity` only scales how much of what the server already
sent gets drawn. Turning it up in clear weather draws nothing, which is why
`/comfy watch on` has to sit and wait for real rain rather than summon it.

**`GetCameraPosition` and `SetCameraOrientationByYawPitchRoll` are in the
binary, and they are not the game camera.** Both appear only as usage strings in
the form `self:GetCameraPosition()`, which makes them methods on a frame, not
globals. They belong to the model-display frames and drive that frame's own
little internal camera. The world camera's pitch is still not readable, which
alone kills every hand-rolled projection: you can get the player's facing from
`GetPlayerFacing`, and without pitch you cannot turn a world point into a screen
point.

**`SetParticlesEnabled` and `SetParticleOverrideScale` are in the binary, and
they are not a particle system.** Same shape, `self:`-prefixed, same model
frames. They toggle and scale the emitters baked into a `.m2` that a model frame
is already displaying. There is no `CreateParticle`, no `AddParticle`, no
`ParticleEmitter`, no `SpawnEffect`, no `C_VisualEffect`. **0 hits each.**

**`ModelSceneFrame` does not exist on this build.** The probe tried it live and
got `CreateFrame(): Unknown frame type 'ModelSceneFrame'`. The strings agree: 0
hits, where `ModelScene`, `PlayerModel`, `CinematicModel` and `DressUpModel` all
hit. Even where these frames do exist they are UI rectangles with a model
rendered inside them, composited over the world with no depth test. A model
frame cannot be occluded by a wall, because the wall is not in its scene.

**`SetModel(asset)` exists and cannot load anything of ours.** Addons may ship
textures and sounds. They may not ship a `.m2`, so the only models available are
ones already in the game, displayed inside that same flat rectangle.

**Nameplates are the one place the engine does project world to screen for
us.** `C_NamePlate.GetNamePlateForUnit` returns a frame the engine keeps pinned
over a unit, correctly projected and correctly faded when occluded
(`nameplateOccludedAlphaMult` is a real CVar, so the engine is doing the
occlusion test internally). This is a genuine hole in the wall and it is still
not a door: a nameplate requires a unit, addons cannot create units, the count
is capped at the few dozen units in range, and the frame sits at the unit rather
than at an arbitrary point. Thousands of raindrops need thousands of arbitrary
points. It is also worth naming because it proves the capability exists inside
the engine and is simply not exposed.

**`C_PingSecure` places a marker in the world and is secure, rate-limited and
mouse-anchored.** Its own error enum contains `FailedSpamming` and
`FailedOutOfPingArea`. It needs a hardware event, it is visible to the group,
and it puts the ping where the cursor is. Not a rendering primitive.

## What this means for the product

The overlay is paint on the glass of the monitor. It is composited over the
entire frame with no knowledge of what is behind any pixel, which is why going
indoors can only mean "stop drawing everywhere" and never "keep drawing in the
doorway". **Rain visible through a window while the room stays dry is not
achievable by any addon, by anyone, on this client.** No competitor in the
survey does it either, and now there is a reason on file rather than an
assumption.

## The game-files route, for completeness

Not being pursued. Recorded so the question is closed rather than open:

- Classic ships on **CASC**, not the old MPQ. Archives are content-addressed and
  the manifest is signed, so the loose-file patching that made 2008-era model
  edits possible does not apply.
- It would be a ToS breach and detectable, and it could not be distributed on
  CurseForge, which is the entire distribution plan.
- It would have to be re-applied after every client patch.

## Where the ceiling is actually high

The audio layer. `PlaySoundFile` takes a FileDataID and a channel, addons may
ship `.ogg`, and `volumeOverride` gives per-sound level. **Nothing about sound
is screen-space**, so the thing that is impossible for pixels indoors is free
for audio: a muffled rain-on-the-roof bed while the room is visually dry is both
achievable and the correct answer to the same wish.

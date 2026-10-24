-- The audio bed. This is the half of the product with runway left in it, so
-- it gets the tests that will still be here when it is a sequencer.

local H = require("harness")
local it, eq, ok, near, gt, lt = H.it, H.eq, H.ok, H.near, H.gt, H.lt

local RAIN_MEDIUM = 538981   -- Sound/ambience/Weather/RainMediumLoop.ogg
local RAIN_HEAVY  = 538982

local function playsOf(mock, from, only)
	local out = {}
	for i = (from or 0) + 1, #mock.sounds do
		local s = mock.sounds[i]
		if s.file and (not only or s.file == only) then out[#out + 1] = s end
	end
	return out
end

it("plays Blizzard's own rain loop, on the ambience channel", function()
	-- By FileDataID, so nothing is redistributed: the file is already on the
	-- player's disk. Ambience and not Music, because a large share of players
	-- turn the music off and would never hear it.
	local w = H.world()
	local played = playsOf(w.mock)
	ok(#played > 0, "something played on login")
	eq(played[1].file, RAIN_MEDIUM, "the medium rain loop at the default intensity")
	eq(played[1].channel, "Ambience", "channel")
end)

it("reloops the bed just before it ends, so the loop never gaps", function()
	-- The durations are measured from the shipped files. A ticker that is even
	-- slightly long leaves a hole in the rain once every half minute, which is
	-- far more noticeable than a slight overlap.
	-- Filtered to the primary bed file: since 2026-10-15 a second, quieter bed
	-- of a different length runs underneath, and counting both would measure
	-- the layering rather than the reloop.
	local w = H.world()
	local before = #w.mock.sounds
	w:advance(31, 0.05)
	local played = playsOf(w.mock, before, RAIN_MEDIUM)
	eq(#played, 1, "one reloop within the first 31 seconds")
	-- 30.0 second file, 0.12 of overlap and up to 0.8 of jitter, so the seam
	-- lands somewhere in 29.08..29.88 and never after the clip has ended.
	local gap = played[1].at - w.mock.sounds[1].at
	gt(gap, 29.0, "the reloop is not so early that it doubles the bed")
	lt(gap, 29.89, "the reloop always lands before the clip ends")
end)

it("switches the bed when the intensity changes", function()
	local w = H.world()
	local before = #w.mock.sounds
	w:slash("heavy")
	local played = playsOf(w.mock, before)
	ok(#played > 0, "a new bed started")
	eq(played[#played].file, RAIN_HEAVY, "the heavy loop")

	-- And the old handle is stopped rather than left layered underneath.
	local stopped = false
	for i = before + 1, #w.mock.sounds do
		if w.mock.sounds[i].stop then stopped = true end
	end
	ok(stopped, "the previous bed was stopped")
end)

it("does not restart the bed when something unrelated changes", function()
	-- Refresh runs on every zone change and every slash command. Restarting
	-- audio on each one would make the rain stutter every time the player
	-- crosses a subzone line.
	local w = H.world()
	w:advance(2)
	local before = #w.mock.sounds
	w:slash("alpha 0.8")
	w.mock.fire("ZONE_CHANGED")
	w.mock.fire("ZONE_CHANGED_NEW_AREA")
	eq(#playsOf(w.mock, before), 0, "no new bed for a cosmetic change")
end)

it("falls back to the bundled loop if the client will not play Blizzard's", function()
	-- The one real risk with playing the library by ID: an install that lacks
	-- the file. Numbers fail here, paths succeed, which is exactly that case.
	local w = H.world({
		canPlaySound = function(file) return type(file) ~= "number" end,
	})
	local played = playsOf(w.mock)
	ok(#played >= 2, "it tried the ID and then the fallback")
	eq(played[1].ok, false, "the FileDataID was refused")
	H.contains(tostring(played[#played].file), "rain.ogg", "fell back to the bundled file")
	ok(#w.mock.printedMatching("bundled") > 0, "and said so once")
end)

it("waits out a muted game instead of switching to the bundled loop", function()
	-- A live retail client, 2026-10-23: Sound_EnableAllSound was 0, every clip
	-- was refused, and the status said "(bundled audio)". The refusal was the
	-- mute, not a missing file, and the bundled switch lasted until /reload,
	-- taking the under-layer with it. The spec above is the control: there only
	-- the FileDataIDs fail, and the switch is right.
	local w = H.world({ loaded = false })
	w.mock.cvars.Sound_EnableAllSound = "0"
	w.mock.canPlaySound = function() return w.mock.cvars.Sound_EnableAllSound ~= "0" end
	w:load()
	w:advance(2)
	ok(#playsOf(w.mock) > 0, "it did try to play")
	eq(#w.mock.printedMatching("bundled"), 0, "no switch to the bundled loop")
	w:slash("status")
	ok(#w.mock.printedMatching("sound is switched off") > 0, "status names the mute")

	-- Ctrl-S again. The bed comes back by itself, as Blizzard's loop.
	w.mock.cvars.Sound_EnableAllSound = "1"
	local before = #w.mock.sounds
	w:advance(70, 0.25)
	local back = false
	for _, s in ipairs(playsOf(w.mock, before)) do
		if s.ok ~= false and type(s.file) == "number" then back = true end
	end
	ok(back, "Blizzard's loop plays once the sound is back on")
	eq(#w.mock.printedMatching("bundled"), 0, "and it never switched")
end)

it("stops everything when sound is turned off, and resumes on", function()
	local w = H.world()
	w:advance(1)
	w:slash("sound off")
	local live = 0
	for h in pairs(w.mock.handles) do live = live + 1 end
	eq(live, 0, "live sound handles after sound off")

	local before = #w.mock.sounds
	w:advance(35, 0.05)
	eq(#playsOf(w.mock, before), 0, "the ticker is cancelled, not just muted")

	w:slash("sound on")
	ok(#playsOf(w.mock, before) > 0, "resumes on request")
end)

it("muffles the bed indoors instead of killing it, and restores it outside", function()
	-- Changed 2026-10-15. Stopping the bed dead on the doorstep was the single
	-- most unrealistic thing the addon did: you can hear rain from inside. The
	-- client exposes no filters, so "muffled" is volume and nothing else, but
	-- a quiet bed is far closer to right than silence.
	local w = H.world()
	w:advance(0.5)
	w.mock.state.indoors = true
	w:advance(3.0)
	local live = 0
	for _ in pairs(w.mock.handles) do live = live + 1 end
	gt(live, 0, "the bed is still running indoors")

	local from = #w.mock.sounds
	w:slash("heavy")    -- forces a relaunch so a new gain is computed
	local quiet = nil
	for i = from + 1, #w.mock.sounds do
		local v = w.mock.sounds[i].volumeOverride
		if v and (not quiet or v > quiet) then quiet = v end
	end
	ok(quiet, "something played indoors")
	-- A band, not a ceiling. The ceiling alone was satisfied by 0.12, which is
	-- what the duck used to produce and is inaudible under an inn's own
	-- ambience: "if we go indoors shouldnt we still hear the rain though - its
	-- not doing that now", 2026-10-19. Quiet has a floor, or quiet is off with
	-- extra steps.
	gt(quiet, 0.35, "loudly enough to actually be heard through the wall")
	lt(quiet, 0.8, "but clearly quieter than standing in it")

	local before = #w.mock.sounds
	w.mock.state.indoors = false
	w:advance(2.0)
	w:slash("normal")
	local loud = 0
	for i = before + 1, #w.mock.sounds do
		local v = w.mock.sounds[i].volumeOverride
		if v and v > loud then loud = v end
	end
	gt(loud, 0.8, "and comes back up outdoors")
end)

it("ducks the bed on the doorstep, not at the next relaunch", function()
	-- Reported from live play: hearthed to Stormwind, walked into the inn, and
	-- the rain stayed at full volume. The spec above hid this, because it ran
	-- `/comfy heavy` to "force a relaunch so a new gain is computed" - and the
	-- relaunch is the entire thing under test. A player walking through a door
	-- types nothing. Without one, the indoor gain was not applied until the bed
	-- looped on its own, which is up to 30 seconds for rain and 50 for snow.
	local w = H.world()
	w:advance(0.5)

	local from = #w.mock.sounds
	w.mock.state.indoors = true
	w:advance(3.0)                 -- past ENTER_IN, no slash command at all

	local played = playsOf(w.mock, from)
	gt(#played, 0, "stepping indoors relaunched the bed by itself")
	for _, s in ipairs(played) do
		if s.volumeOverride then
			lt(s.volumeOverride, 0.8, "and the new clip is quieter straight away")
		end
	end
end)

it("rebuilds the bed after a loading screen", function()
	-- A loading screen stops every sound the client is playing, underneath the
	-- addon: no event, no error, the handles simply go quiet. The Lua side
	-- survives it intact, so bedSlot.ticker is still there and Refresh used to
	-- conclude the bed was running and leave it alone. Hearth into a city
	-- during rain and the rain was silent until the next natural relaunch.
	local w = H.world()
	w:advance(2.0)

	local from = #w.mock.sounds
	w.mock.fire("PLAYER_ENTERING_WORLD")
	gt(#playsOf(w.mock, from), 0, "the bed starts again on the far side")
	eq(#w.mock.errors, 0, "errors")
end)

it("indoors off still silences the bed completely", function()
	local w = H.world()
	w:slash("indoors off")
	w:advance(0.5)
	w.mock.state.indoors = true
	w:advance(3.0)
	local live = 0
	for _ in pairs(w.mock.handles) do live = live + 1 end
	eq(live, 0, "no live handles with indoors off")
end)

it("moves the bed to whichever channel the player names", function()
	-- Which channel owns the audio is the whole reason this is an ambience
	-- product rather than a music one, so it is configurable and tested.
	local w = H.world()
	local before = #w.mock.sounds
	w:slash("channel sfx")
	local played = playsOf(w.mock, before)
	ok(#played > 0, "the bed restarted on the new channel")
	eq(played[#played].channel, "SFX", "channel")

	w:slash("channel nonsense")
	eq(w:db().channel, "SFX", "an invalid channel is refused, not applied")
end)

it("brings the second bed layer in within a few seconds, not half a minute", function()
	-- Reported from live play: "audio doesn't start quickly". The first bed
	-- layer always started at once; the SECOND waited `random() * len * 0.6`,
	-- and len is 30s for rain and 50s for snow, so the bed could stay a single
	-- thin loop for up to 18 or 30 seconds after the player turned rain on.
	-- The initial offset was never what decorrelates the layers anyway - the
	-- per-relaunch jitter is - so it is capped and the phase spread survives.
	local RAIN_LIGHT = 538983   -- the under-bed at the default intensity
	local w = H.world()
	w:advance(3.0, 0.1)
	gt(#playsOf(w.mock, 0, RAIN_LIGHT), 0, "under-bed joined within 3s")
	eq(#w.mock.errors, 0, "errors")
end)

it("thunders, with the sound trailing the flash", function()
	local w = H.world()
	local before = #w.mock.sounds
	w:advance(200, 0.05)

	local thunder = 0
	for _, s in ipairs(playsOf(w.mock, before)) do
		-- Sound/DOODAD/FX_TKIsle_MWThunderRumble01-10.ogg
		if type(s.file) == "number" and s.file >= 838830 and s.file <= 839737 then
			thunder = thunder + 1
		end
	end
	gt(thunder, 0, "strikes within 200 seconds")
	eq(#w.mock.errors, 0, "errors during the lightning loop")
end)

it("does not thunder with thunder off", function()
	local w = H.world()
	w:slash("thunder off")
	local before = #w.mock.sounds
	w:advance(200, 0.05)
	for _, s in ipairs(playsOf(w.mock, before)) do
		ok(not (type(s.file) == "number" and s.file >= 838830 and s.file <= 839737),
			"no thunder played")
	end
end)

it("never stacks more than two beds on top of each other", function()
	-- The bed keeps at most two handles so one can overlap the next, and the
	-- reloop interval is the file's own length. Halve that interval by mistake
	-- and the rain gets steadily louder for ten minutes, which is the failure
	-- this pins. Lengths are the real measured durations of the shipped files.
	local w = H.world({ soundLengths = {
		[538983] = 20.0, [538981] = 30.0, [538982] = 25.0, [16] = 2.0,
	}, defaultSoundLength = 3.0 })
	w:advance(600, 0.1)
	local live = 0
	for h in pairs(w.mock.handles) do live = live + 1 end
	lt(live, 3, "beds audible at once after ten minutes")
end)

it("arms SOUNDKIT_FINISHED for a SoundKit, which is the positive control", function()
	-- runFinishCallback is a boolean field in the C_Sound params struct, not a
	-- Lua function. It arms the SOUNDKIT_FINISHED event, which is present in
	-- WowB.exe 1.60.1.70338. This spec exists to prove the instrument works at
	-- all, so that the next one's negative result means something.
	local w = H.world({ soundKits = { 567 } })
	local heard = {}
	local f = w.env.CreateFrame("Frame")
	f:RegisterEvent("SOUNDKIT_FINISHED")
	f:SetScript("OnEvent", function(_, _, h) heard[#heard + 1] = h end)

	local ok_, handle = w.env.C_Sound.PlaySoundWithOptions({
		soundKitID = 567, channel = "Master", length = 5.0, runFinishCallback = true,
	})
	eq(ok_, true, "played")
	eq(w.env.C_Sound.IsPlaying(handle), true, "handle is live")
	w:advance(6)
	eq(#heard, 1, "the event fired once for a SoundKit")
	eq(heard[1], handle, "with the handle that ended")
end)

it("cannot assume SOUNDKIT_FINISHED fires for a FileDataID", function()
	-- Every sound this addon owns is a FileDataID, not a SoundKit. Whether the
	-- event fires for those is unknown until /comfy probe answers it on a live
	-- client, so the mock defaults to the hostile answer and the sequencer in
	-- Phase 4 is driven by a timer. If this spec ever starts failing because
	-- the default flipped, the sequencer design has to be revisited, not the test.
	local w = H.world()
	local heard = 0
	local f = w.env.CreateFrame("Frame")
	f:RegisterEvent("SOUNDKIT_FINISHED")
	f:SetScript("OnEvent", function() heard = heard + 1 end)

	local ok_ = w.env.C_Sound.PlaySoundWithOptions({
		soundKitID = 538981, channel = "Ambience", volumeOverride = 0.4,
		length = 5.0, runFinishCallback = true,
	})
	eq(ok_, true, "played")
	w:advance(6)
	eq(heard, 0, "no finish event for a file, under the assumption we ship on")
end)

it("records volumeOverride and runFinishCallback as the params struct fields they are", function()
	local w = H.world()
	local before = #w.mock.sounds
	w.env.C_Sound.PlaySoundWithOptions({
		soundKitID = 538981, channel = "Ambience", volumeOverride = 0.4,
		runFinishCallback = true,
	})
	local s = w.mock.sounds[before + 1]
	eq(s.channel, "Ambience", "channel")
	near(s.volumeOverride, 0.4, 1e-9, "volumeOverride")
	eq(s.runFinishCallback, true, "runFinishCallback is a flag")
end)

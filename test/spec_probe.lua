-- The probe. Run once on a live client before 21 October, then never again.
--
-- These specs cannot prove what the client answers. They prove the probe asks
-- correctly: that a negative result is only ever recorded when its positive
-- control passed first, that a check which blows up cannot take the addon or
-- the other checks with it, and that the answers land somewhere a human can
-- read off disk. A probe that silently records "no" because the instrument was
-- broken is worse than no probe, and that is the exact failure mode these pin.

local H = require("harness")
local it, eq, ok, contains = H.it, H.eq, H.ok, H.contains

local RAIN = 538981
local THUNDER = 838830

local function results(w) return w:db().probe.results end

-- One /reload: the saved table survives, everything else is new.
local function reload(w, opts)
	opts = opts or {}
	local carried = w:db()
	local w2 = H.world({ loaded = false, soundKits = opts.soundKits,
	                     muteAffectsOwnPlayback = opts.muteAffectsOwnPlayback })
	w2.env.DuskfallDB = carried
	w2:load()
	return w2
end

it("answers nothing until it is asked", function()
	local w = H.world()
	eq(w:db().probe, nil, "a fresh install must not carry a probe table")
	eq(#w.mock.errors, 0, "errors during boot")
end)

it("records every check it ran, in order, with a build stamp", function()
	local w = H.world()
	w:slash("probe")
	w:advance(20)
	local P = w:db().probe
	ok(#P.order >= 7, "checks recorded: " .. #P.order)
	for _, id in ipairs(P.order) do
		local r = P.results[id]
		ok(r.verdict == "yes" or r.verdict == "no"
			or r.verdict == "unknown" or r.verdict == "ask",
			id .. " has a legal verdict, got " .. tostring(r.verdict))
		eq(r.build, "70338", id .. " stamped with the build it was observed on")
	end
	eq(#w.mock.errors, 0, "a probe run must not raise")
end)

it("refuses to conclude about muting when the control file will not play", function()
	-- The control is an UNMUTED file. If the client refuses that, a refusal of
	-- the muted file says nothing about muting, and "no" would be a fabrication.
	local w = H.world({ canPlaySound = function() return false end })
	w:slash("probe")
	w:advance(20)
	eq(results(w).mute_self.verdict, "unknown", "verdict with a dead control")
	contains(results(w).mute_self.detail, "control failed", "and says why")
end)

it("concludes the mute reaches our own playback only when it actually did", function()
	local w = H.world({ muteAffectsOwnPlayback = true })
	w:slash("probe")
	w:advance(20)
	eq(results(w).mute_self.verdict, "yes", "the mute silenced us")

	local w2 = H.world({ muteAffectsOwnPlayback = false })
	w2:slash("probe")
	w2:advance(20)
	eq(results(w2).mute_self.verdict, "no", "our own playback survived the mute")
end)

it("leaves no mute behind after the self-mute check", function()
	-- MuteSoundFile has no IsMuted and persists per the wiki. A probe that
	-- silences the addon's own rain file and walks away has broken the thing it
	-- was measuring, for the rest of the session at least.
	local w = H.world({ muteAffectsOwnPlayback = true })
	w:slash("probe")
	w:advance(20)
	-- mute_reload arms a mute deliberately and clears it on the next load.
	local w2 = reload(w, { muteAffectsOwnPlayback = true })
	w2:advance(2)
	eq(w2.mock.muted[RAIN], nil, "rain is unmuted once the reload check answers")
end)

it("will not call a missing finish event 'no' unless the SoundKit control fired", function()
	-- The whole Phase 4 sequencer design turns on this answer, so a false "no"
	-- is cheap to record and expensive to believe.
	local w = H.world({ soundKits = {}, finishEventForKits = true })
	w:slash("probe")
	w:advance(20)
	eq(results(w).finish_event.verdict, "unknown", "no control, no conclusion")
	contains(results(w).finish_event.detail, "unproven", "and says the method is unproven")
end)

it("reports no when the control fires and the FileDataID does not", function()
	local w = H.world({ soundKits = { 567 },
	                    finishEventForKits = true, finishEventForFiles = false })
	w:slash("probe")
	w:advance(20)
	eq(results(w).finish_event.verdict, "no", "verdict")
	contains(results(w).finish_event.detail, "did NOT fire", "detail names what failed")
end)

it("reports yes when the FileDataID fires too", function()
	local w = H.world({ soundKits = { 567 },
	                    finishEventForKits = true, finishEventForFiles = true })
	w:slash("probe")
	w:advance(20)
	eq(results(w).finish_event.verdict, "yes", "verdict")
end)

it("asks the player's ears rather than claiming the ambience was audible", function()
	-- The client can only report that it agreed to play. Whether sound came out
	-- of the speakers is not observable from Lua, and recording "yes" here would
	-- be reporting a proxy as the thing.
	local w = H.world()
	w:slash("probe")
	w:advance(20)
	eq(results(w).ambience_musicoff.verdict, "ask", "verdict before the player answers")
	eq(w:db().probe.pendingEars, "ambience_musicoff", "and it knows what it is waiting on")

	w:slash("probe heard yes")
	eq(results(w).ambience_musicoff.verdict, "yes", "verdict after the player answers")
	contains(results(w).ambience_musicoff.detail, "player heard it: true", "recorded as a human answer")
	eq(w:db().probe.pendingEars, nil, "nothing left waiting")
end)

it("restores the music cvar it changed", function()
	-- Leaving Sound_EnableMusic at 0 would silence the player's music for the
	-- rest of the session, from a diagnostic they ran once.
	local w = H.world({ cvars = { Sound_EnableMusic = "1" } })
	w:slash("probe")
	eq(w.env.GetCVar("Sound_EnableMusic"), "0", "turned off for the test")
	w:advance(20)
	eq(w.env.GetCVar("Sound_EnableMusic"), "1", "put back afterwards")
end)

it("answers the savedvars question by itself on the way back up", function()
	local w = H.world()
	w:slash("probe")
	w:advance(20)
	eq(results(w).savedvars, nil, "unanswerable before a reload")
	ok(w:db().probe.svToken ~= nil, "a token was written")

	local w2 = reload(w)
	eq(results(w2).savedvars.verdict, "yes", "the token survived")
	eq(w2:db().probe.svToken, nil, "and the token is cleaned up")
end)

it("records savedvars as no when the table comes back wrong", function()
	local w = H.world()
	w:slash("probe")
	w:advance(20)
	w:db().probe.svToken = "something else entirely"
	local w2 = reload(w)
	eq(results(w2).savedvars.verdict, "no", "a mismatch is a failure, not a pass")
	contains(results(w2).savedvars.detail, "read back", "and shows both values")
end)

it("will not read the mute-persistence result when the mute is invisible anyway", function()
	-- willPlay is the only instrument for "is this muted". If check 4 proved the
	-- mute does not reach our own playback, that instrument reads nothing here,
	-- and whatever it returns is not evidence either way.
	local w = H.world({ muteAffectsOwnPlayback = false })
	w:slash("probe")
	w:advance(20)
	eq(results(w).mute_self.verdict, "no", "precondition")
	local w2 = reload(w, { muteAffectsOwnPlayback = false })
	eq(results(w2).mute_reload.verdict, "unknown", "no instrument, no verdict")
end)

it("survives a check that raises, and keeps running the rest", function()
	-- Each check is pcall'd individually. A client that explodes on C_Sound must
	-- still produce the other six answers, because there is no second beta.
	local w = H.world()
	w.env.C_Sound = setmetatable({}, { __index = function() error("boom", 2) end })
	w:slash("probe")
	w:advance(20)
	ok(#w:db().probe.order >= 5, "the other checks still ran")
	eq(#w.mock.errors, 0, "and nothing escaped to the client")
end)

it("cannot take the addon down with it", function()
	local w = H.world()
	w.env.CreateFrame = function() error("no frames for you", 2) end
	w:slash("probe")
	w:advance(20)
	w.env.CreateFrame = nil
	w:slash("heavy")
	eq(w:db().intensity, "heavy", "the addon still answers afterwards")
end)

it("prints a readable report and can be wiped", function()
	local w = H.world()
	w:slash("probe")
	w:advance(20)
	local before = #w.mock.printed
	w:slash("probe report")
	ok(#w.mock.printed - before >= 7, "one line per recorded check")

	w:slash("probe wipe")
	eq(w:db().probe, nil, "wiped")
	w:slash("probe report")
	ok(#w.mock.printedMatching("nothing recorded") > 0, "and says so next time")
end)

it("is optional, and the addon says so when it is absent", function()
	-- Probe.lua is dropped from the TOC before release. A stranger typing the
	-- command they saw in a changelog must get a sentence, not a Lua error.
	local w = H.world({ probe = false })
	w:slash("probe")
	ok(#w.mock.printedMatching("not installed") > 0, "told the player")
	eq(#w.mock.errors, 0, "and did not raise")
end)

it("stops every sound it started itself", function()
	-- Counting live handles absolutely would just count the addon's own rain
	-- bed, which is supposed to be running, and the bed's thunder is random.
	-- So this tracks the handles the probe opened, specifically, and no others.
	local w = H.world()
	local before = #w.mock.sounds
	w:slash("probe")

	local mine = {}
	for i = before + 1, #w.mock.sounds do
		local h = w.mock.sounds[i].handle
		if h then mine[#mine + 1] = h end
	end
	ok(#mine >= 3, "the probe opened handles to track: " .. #mine)

	w:advance(60)
	for _, h in ipairs(mine) do
		eq(w.mock.handles[h], nil, "probe handle " .. h .. " was stopped")
	end
end)

it("warns that it leaves the rain muted on purpose", function()
	-- The mute-persistence check cannot work any other way: the mute has to
	-- outlive the session to be measured after a /reload. That is a sound the
	-- player stops hearing, so it has to be said out loud rather than noticed.
	local w = H.world({ muteAffectsOwnPlayback = true })
	w:slash("probe")
	eq(w.mock.muted[RAIN], true, "left muted deliberately")
	ok(#w.mock.printedMatching("rain muted") > 0, "and said so")
	ok(#w.mock.printedMatching("reload") > 0, "with the way to clear it")
end)

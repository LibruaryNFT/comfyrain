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

--------------------------------------------------------------------------------
-- Unattended mode. The point of these is that nobody is watching: a probe that
-- loops, reloads in combat, or leaves the music off has done real damage to a
-- session nobody was looking at.
--------------------------------------------------------------------------------

-- The autorun flag is written into SavedVariables on disk before the client
-- starts, so a world that models it starts with the flag already present.
local function armed(opts)
	opts = opts or {}
	local w = H.world({ loaded = false, inCombat = opts.inCombat,
	                    cvars = opts.cvars, muteAffectsOwnPlayback = true })
	w.env.DuskfallDB = opts.db or { probe = { autorun = true, results = {}, order = {} } }
	w:load()
	return w
end

-- Carry the saved table into a new world, the way a real reload does.
local function cycle(w, opts)
	opts = opts or {}
	local carried = w:db()
	local w2 = H.world({ loaded = false, inCombat = opts.inCombat,
	                     cvars = opts.cvars, muteAffectsOwnPlayback = true })
	w2.env.DuskfallDB = carried
	w2:load()
	return w2
end

it("does nothing unattended unless the flag is on disk", function()
	local w = H.world()
	w:advance(60)
	eq(w.mock.reloads, 0, "an ordinary login must never reload itself")
	eq(w:db().probe, nil, "and must not write probe state")
end)

it("runs itself, reloads itself, and stops", function()
	local w = armed()
	w:advance(60)
	eq(w.mock.reloads, 1, "first reload requested")
	eq(w:db().probe.stage, "audio", "stage after the sync checks")
	ok(#w:db().probe.order >= 5, "checks recorded before reloading")

	local w2 = cycle(w)
	w2:advance(60)
	eq(w2:db().probe.stage, "flush", "stage after the audio sequence")

	local w3 = cycle(w2)
	w3:advance(60)
	eq(w3:db().probe.stage, "done", "finished")
	eq(w3:db().probe.autorun, nil, "and disarmed itself")

	local w4 = cycle(w3)
	w4:advance(120)
	eq(w4.mock.reloads, 0, "a finished probe never reloads again")
end)

it("waits for combat to end before reloading", function()
	-- ReloadUI during an encounter is the single most hostile thing an addon
	-- can do unattended.
	local w = armed({ inCombat = true })
	w:advance(60)
	eq(w.mock.reloads, 0, "no reload while in combat")
	w.mock.inCombat = false
	w:advance(10)
	eq(w.mock.reloads, 1, "reloaded once combat ended")
end)

it("gives up rather than reloading forever", function()
	-- A stage that never advances, because a check raised on every login, must
	-- cost one wasted session and not an unbootable account.
	local w = armed({ db = { probe = { autorun = true, results = {}, order = {},
	                                   stage = "audio", reloads = 9 } } })
	w:advance(90)
	eq(w.mock.reloads, 0, "refused to reload again")
	eq(w:db().probe.autorun, nil, "and disarmed itself")
end)

it("times three audio windows and marks which one is the control", function()
	-- Lua cannot hear. These windows exist so the machine recording the speaker
	-- output can be asked instead, and the control window is what makes a quiet
	-- answer window mean anything.
	local w = armed()
	w:advance(60)
	local w2 = cycle(w)
	w2:advance(60)

	local a = w2:db().probe.audio
	ok(a ~= nil, "an audio plan was recorded")
	local byName = {}
	for _, win in ipairs(a.windows) do byName[win.name] = win end

	ok(byName.baseline ~= nil, "a silence baseline")
	eq(byName.baseline.file, nil, "which plays nothing")

	eq(byName.control_master.channel, "Master", "control channel")
	eq(byName.control_master.music, "1", "control runs with music on")

	eq(byName.ambience_nomusic.channel, "Ambience", "the question's channel")
	eq(byName.ambience_nomusic.music, "0", "with music off, which is the whole question")

	for name, win in pairs(byName) do
		ok(type(win.t0) == "number", name .. " has a start timestamp")
		ok(type(win.t1) == "number", name .. " has an end timestamp")
		ok(win.t1 >= win.t0, name .. " ends after it starts")
	end
	ok(byName.control_master.t1 <= byName.ambience_nomusic.t0,
		"the control must finish before the question begins")
end)

it("puts the music setting back even though nobody is watching", function()
	local w = armed({ cvars = { Sound_EnableMusic = "1" } })
	w:advance(60)
	local w2 = cycle(w, { cvars = { Sound_EnableMusic = "1" } })
	w2:advance(60)
	eq(w2.env.GetCVar("Sound_EnableMusic"), "1", "restored after the sequence")
end)

it("leaves no sound playing when it finishes unattended", function()
	local w = armed()
	w:advance(60)
	local w2 = cycle(w)
	w2:advance(90)
	-- Only the sequence's own handles. Counting every live handle would count
	-- the addon's rain bed, which is supposed to still be running.
	local checked = 0
	for _, win in ipairs(w2:db().probe.audio.windows) do
		if win.handle then
			eq(w2.mock.handles[win.handle], nil, win.name .. " was stopped")
			checked = checked + 1
		end
	end
	eq(checked, 2, "both playing windows were checked")
end)

it("finds which params key carries the sound id, instead of guessing once", function()
	-- Build 70374 answered a two-argument call with its own usage string, so
	-- PlaySoundWithOptions takes one table and the id lives inside it under a
	-- name nothing we can read documents. Guessing once and recording "unknown"
	-- wastes the only week the client exists, so the probe tries every
	-- candidate and writes down what the client said to each.
	local w = H.world({ soundParamsKey = "soundFileID", soundKits = { 567 } })
	w:slash("probe")
	local r = w:db().probe.results.sound_params
	ok(r, "the schema is recorded as its own result")
	eq(r.verdict, "yes", "a key was accepted")
	contains(r.detail, "soundFileID", "and it names the one that worked")
	contains(r.detail, "soundKitID", "while keeping what the rejected ones said")
end)

it("refuses to answer the finish question when no key is accepted", function()
	-- The failure that matters: if none of the candidate shapes work, the
	-- sequencing question was never actually asked. Reporting "no finish event"
	-- there would retire a Phase 4 feature on the strength of a call that never
	-- reached the client.
	local w = H.world({ soundParamsKey = "somethingElseEntirely" })
	w:slash("probe")
	eq(w:db().probe.results.sound_params.verdict, "no", "no shape was accepted")
	eq(w:db().probe.results.finish_event.verdict, "unknown",
		"so the finish event is unknown, not no")
end)

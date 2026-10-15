-- Duskfall probe - the eight questions that die with the beta client.
--
-- The beta is withdrawn on 2026-10-21 and the game does not exist again until
-- 4 November. Everything below needs a running client and cannot be answered
-- from a binary string, a wiki page or a test harness. Doing them by hand means
-- remembering eight procedures in the right order; this does them in one
-- command and writes the answers into SavedVariables, so the results can be
-- read off disk afterwards instead of transcribed out of a chat window.
--
-- This is a SEPARATE FILE on purpose. Each .lua in a TOC is its own chunk, so a
-- raise in here cannot abort Duskfall.lua. Every check is additionally pcall'd,
-- because a probe that kills the addon it is probing is worse than no probe.
--
-- Drop this file and its TOC line to ship without it.

local ADDON = "Duskfall"
local RAIN = 538981          -- Sound/ambience/Weather/RainMediumLoop.ogg
local THUNDER = 838830       -- Sound/DOODAD/FX_TKIsle_MWThunderRumble01.ogg
-- SPELLS/Goblin_Weather_Machine_Rain.M2. The first attempt at this check asked
-- for 165487, which the listfile says is GH_GeneralWalk_A_Day04.mp3 - an audio
-- file, so the client was right to call it an invalid model. The control below
-- is a model that is loaded during every login, so a build where IT fails to
-- load is a build where the method is broken rather than the answer being no.
local WEATHER_M2 = 166249
local CONTROL_M2 = 165433    -- Particles/LoginFX.m2

local function msg(text)
	print("|cff7fb8ff" .. ADDON .. " probe|r: " .. text)
end

local P    -- DuskfallDB.probe, filled on first use

local function store()
	DuskfallDB = DuskfallDB or {}
	DuskfallDB.probe = DuskfallDB.probe or { results = {}, order = {} }
	P = DuskfallDB.probe
	return P
end

-- verdict is one of "yes", "no", "unknown", "ask" (needs the player's ears).
local function record(id, verdict, detail)
	store()
	if P.results[id] == nil then P.order[#P.order + 1] = id end
	P.results[id] = {
		verdict = verdict,
		detail  = tostring(detail),
		at      = (date and date("%Y-%m-%d %H:%M:%S")) or tostring(time and time() or 0),
		build   = select(2, GetBuildInfo()),
	}
	local colour = (verdict == "yes" and "|cff66ff66") or (verdict == "no" and "|cffff6666")
		or (verdict == "ask" and "|cffffd100") or "|cff888888"
	msg(string.format("%-16s %s%s|r  %s", id, colour, verdict, tostring(detail)))
end

local function try(id, fn)
	local ok, err = pcall(fn)
	if not ok then record(id, "unknown", "raised: " .. tostring(err)) end
end

--------------------------------------------------------------------------------
-- 1. Does SavedVariables read back on this build?
--
-- Gates both launch blockers: the options panel and the shareable preset
-- strings. Two-stage by necessity - write a token now, compare it after a
-- /reload. The comparison runs on load, so it answers itself.
--------------------------------------------------------------------------------

local function CheckSavedVarsOnLoad()
	store()
	if P.svToken then
		if P.svToken == P.svExpect then
			record("savedvars", "yes", "token survived a reload: " .. tostring(P.svToken))
		else
			record("savedvars", "no",
				string.format("wrote %s, read back %s", tostring(P.svExpect), tostring(P.svToken)))
		end
		P.svToken, P.svExpect = nil, nil
	end
end

local function ArmSavedVars()
	store()
	local token = tostring(time and time() or 0) .. "-" .. tostring(math.random(1000, 9999))
	P.svToken, P.svExpect = token, token
	msg("|cffffd100/reload|r now - savedvars answers itself on the way back up.")
end

--------------------------------------------------------------------------------
-- 2. What is actually in C_Sound?
--
-- Settles whether volumeOverride and runFinishCallback are fields of the params
-- table or just strings that sit near each other in the binary. Enumerating the
-- namespace beats /dump because the answer lands in SavedVariables.
--------------------------------------------------------------------------------

local function CheckCSound()
	if type(C_Sound) ~= "table" then
		record("c_sound", "no", "C_Sound is " .. type(C_Sound))
		return
	end
	local keys = {}
	for k in pairs(C_Sound) do keys[#keys + 1] = tostring(k) end
	table.sort(keys)
	store()
	P.cSoundKeys = keys
	record("c_sound", "yes", table.concat(keys, ", "))
end

--------------------------------------------------------------------------------
-- 3. Does ambience survive Sound_EnableMusic = 0?
--
-- The single assumption the whole ambience-led product rests on. The client can
-- only tell us whether it *agreed* to play; whether a sound came out is the
-- player's ears, so this ends in "ask".
--------------------------------------------------------------------------------

local function CheckAmbienceWithMusicOff()
	local before = GetCVar("Sound_EnableMusic")
	SetCVar("Sound_EnableMusic", "0")
	local willPlay, handle = PlaySoundFile(RAIN, "Ambience")
	record("ambience_musicoff", willPlay and "ask" or "no",
		string.format("willPlay=%s handle=%s, music was %s. |cffffd100Do you hear rain? /dusk probe heard yes|no|r",
			tostring(willPlay), tostring(handle), tostring(before)))
	store()
	P.pendingEars = "ambience_musicoff"
	C_Timer.After(6, function()
		pcall(function()
			if handle then StopSound(handle, 500) end
			SetCVar("Sound_EnableMusic", before or "1")
		end)
	end)
end

--------------------------------------------------------------------------------
-- 4. Does MuteSoundFile silence our OWN playback of the same file?
--
-- If it does, "mute Blizzard's rain and play ours" is dead as written, because
-- both use the same FileDataID. Positive control: the same call on an unmuted
-- file, immediately before, must report willPlay.
--------------------------------------------------------------------------------

local function CheckMuteSelf()
	local controlPlays, controlHandle = PlaySoundFile(THUNDER, "Ambience")
	if controlHandle then StopSound(controlHandle) end
	if not controlPlays then
		record("mute_self", "unknown",
			"control failed: the client refused an UNMUTED file, so a refusal below proves nothing")
		return
	end

	MuteSoundFile(RAIN)
	local mutedPlays, handle = PlaySoundFile(RAIN, "Ambience")
	UnmuteSoundFile(RAIN)

	record("mute_self", mutedPlays and "no" or "yes",
		string.format("control willPlay=true, muted willPlay=%s. %s",
			tostring(mutedPlays),
			mutedPlays and "our own playback survives the mute"
			            or "the mute silences us too - the suppression plan needs a different file"))
	if handle then StopSound(handle) end
end

--------------------------------------------------------------------------------
-- 5. Do mutes survive a reload?
--
-- There is no IsMuted. The only instrument is whether a muted file still
-- reports willPlay after coming back up, so this arms on one run and answers on
-- the next.
--------------------------------------------------------------------------------

local function CheckMutePersistenceOnLoad()
	store()
	if not P.mutedBeforeReload then return end
	P.mutedBeforeReload = nil
	local plays, handle = PlaySoundFile(RAIN, "Ambience")
	if handle then StopSound(handle) end
	-- Only meaningful if check 4 said the mute reaches our own playback.
	local selfMute = P.results and P.results.mute_self and P.results.mute_self.verdict
	if selfMute ~= "yes" then
		record("mute_reload", "unknown",
			"mute_self said " .. tostring(selfMute) .. ", so willPlay cannot see a mute at all")
	else
		record("mute_reload", plays and "no" or "yes",
			plays and "the mute was dropped by the reload, reapply on PLAYER_LOGIN"
			       or "the mute survived the reload")
	end
	UnmuteSoundFile(RAIN)
end

local function ArmMutePersistence()
	store()
	MuteSoundFile(RAIN)
	P.mutedBeforeReload = true
	msg("rain muted. |cffffd100/reload|r and mute_reload answers itself.")
end

--------------------------------------------------------------------------------
-- 6. Does the finish signal fire for a FileDataID, or only for a SoundKit?
--
-- runFinishCallback does not call anything; it arms SOUNDKIT_FINISHED. The wiki
-- documents it for SoundKit IDs. The whole Phase 4 sequencer would be built on
-- it firing for files, so: fire a known SoundKit first as the positive control,
-- then the file. A silent file with a silent control proves nothing.
--------------------------------------------------------------------------------

local function CheckFinishEvent()
	local seen = {}
	local listener = CreateFrame("Frame")
	local ok = pcall(function() listener:RegisterEvent("SOUNDKIT_FINISHED") end)
	if not ok then
		record("finish_event", "no", "SOUNDKIT_FINISHED is not a registerable event here")
		return
	end
	listener:SetScript("OnEvent", function(_, _, handle) seen[handle] = true end)

	local kit = (SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPEN) or 567

	-- The first attempt called this as PlaySoundWithOptions(id, options) and the
	-- client answered with its own usage string:
	--   local success, soundHandle = C_Sound.PlaySoundWithOptions(params)
	-- So it takes ONE table and the sound id lives inside it. Which key holds
	-- the id is not documented anywhere we can read, so rather than guess once
	-- and record another "unknown", every plausible shape is tried and the
	-- client's own error for each is written down. One run returns the schema.
	local shapes = {
		{ name = "soundKitID",   build = function(id) return { soundKitID = id } end },
		{ name = "soundKitId",   build = function(id) return { soundKitId = id } end },
		{ name = "soundkitID",   build = function(id) return { soundkitID = id } end },
		{ name = "soundFileID",  build = function(id) return { soundFileID = id } end },
		{ name = "soundID",      build = function(id) return { soundID = id } end },
		{ name = "id",           build = function(id) return { id = id } end },
	}

	local keyFor, notes = nil, {}
	for _, shape in ipairs(shapes) do
		local params = shape.build(kit)
		params.channel = "SFX"
		local callOk, a, b = pcall(C_Sound.PlaySoundWithOptions, params)
		if callOk and a then
			keyFor = shape.name
			if b then pcall(StopSound, b) end
			notes[#notes + 1] = shape.name .. "=accepted"
			break
		end
		notes[#notes + 1] = shape.name .. "=" ..
			(callOk and ("returned " .. tostring(a)) or tostring(a):gsub("^.*:%d+: ", ""))
	end

	if not keyFor then
		record("sound_params", "no", table.concat(notes, "; "))
		record("finish_event", "unknown",
			"no accepted key for the sound id, so runFinishCallback was never reached")
		return
	end
	record("sound_params", "yes", "the id key is " .. keyFor .. ". " .. table.concat(notes, "; "))

	local function play(id, channel)
		local params = { channel = channel, runFinishCallback = true }
		params[keyFor] = id
		local callOk, a, b = pcall(C_Sound.PlaySoundWithOptions, params)
		if not callOk then return nil, tostring(a) end
		return b, tostring(a)
	end

	local kitHandle, kitOk = play(kit, "SFX")
	local fileHandle, fileOk = play(THUNDER, "Ambience")

	C_Timer.After(15, function()
		pcall(function()
			listener:UnregisterEvent("SOUNDKIT_FINISHED")
			-- Both of these had to run to completion to be measured at all, so
			-- they are only stopped now, once the measurement is taken.
			if kitHandle then StopSound(kitHandle) end
			if fileHandle then StopSound(fileHandle) end
			local control = kitHandle and seen[kitHandle] or false
			local target  = fileHandle and seen[fileHandle] or false
			if not control then
				record("finish_event", "unknown",
					string.format("control SoundKit %s did not fire either (kitOk=%s), so the method is unproven",
						tostring(kit), tostring(kitOk)))
			else
				record("finish_event", target and "yes" or "no",
					string.format("SoundKit fired, FileDataID %s (fileOk=%s)",
						target and "also fired" or "did NOT fire", tostring(fileOk)))
			end
		end)
	end)
end

--------------------------------------------------------------------------------
-- 7. Will Forever host a Settings panel at all?
--
-- AddSearchTags is already known to raise ADDON_ACTION_FORBIDDEN here, which is
-- evidence the registration path is partly broken. This decides whether a GUI
-- is possible before two weeks are spent writing one.
--------------------------------------------------------------------------------

local function CheckSettingsPanel()
	if type(Settings) ~= "table" or type(Settings.RegisterCanvasLayoutCategory) ~= "function" then
		record("settings_panel", "no", "Settings.RegisterCanvasLayoutCategory is missing")
		return
	end
	local panel = CreateFrame("Frame")
	panel.name = "Duskfall probe panel"
	local cat = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
	if not cat then
		record("settings_panel", "no", "RegisterCanvasLayoutCategory returned nil")
		return
	end
	local registered = pcall(Settings.RegisterAddOnCategory, cat)
	local tagged = pcall(function() cat:AddSearchTags("duskfall") end)
	record("settings_panel", registered and "yes" or "no",
		string.format("category ID %s, RegisterAddOnCategory=%s, AddSearchTags=%s",
			tostring(cat.ID or cat.id), tostring(registered),
			tagged and "ok" or "raises, as expected"))
end

--------------------------------------------------------------------------------
-- 8. Can a Model frame host a Blizzard weather M2? Lowest value of the eight.
--------------------------------------------------------------------------------

local function CheckWeatherModel()
	local m = CreateFrame("Model", nil, UIParent)
	if type(m.SetModel) ~= "function" then
		record("weather_model", "no", "Model frames have no SetModel on this build")
		return
	end
	-- Positive control first. SetModel RAISES on a bad file rather than
	-- returning false, so without this a raise is indistinguishable from
	-- "Model frames cannot host anything here".
	local controlOk = pcall(m.SetModel, m, CONTROL_M2)
	if not controlOk then
		record("weather_model", "unknown",
			string.format("control model %d would not load either, so the method is unproven",
				CONTROL_M2))
		m:Hide()
		return
	end

	local ok, err = pcall(m.SetModel, m, WEATHER_M2)
	if not ok then
		record("weather_model", "no",
			string.format("control %d loaded, weather %d raised: %s",
				CONTROL_M2, WEATHER_M2, tostring(err)))
		m:Hide()
		return
	end
	local got = m.GetModelFileID and m:GetModelFileID() or nil
	record("weather_model", got and "yes" or "unknown",
		string.format("asked for %d, GetModelFileID=%s (a loaded model is not a visible one)",
			WEATHER_M2, tostring(got)))
	m:Hide()
end

--------------------------------------------------------------------------------
-- 9. Geometry, which does not expire but costs ten seconds while we are here.
--------------------------------------------------------------------------------

local function CheckGeometry()
	-- Both numbers must come from the SAME source. Mixing a physical width with
	-- a UIParent height produces an aspect ratio that is arithmetic over two
	-- different coordinate systems, which is worse than no answer.
	local w, h
	if type(GetPhysicalScreenSize) == "function" then w, h = GetPhysicalScreenSize() end
	local src = "GetPhysicalScreenSize"
	if type(w) ~= "number" or type(h) ~= "number" then
		w, h = UIParent:GetWidth(), UIParent:GetHeight()
		src = "UIParent"
	end
	record("geometry", "yes", string.format("%dx%d from %s, aspect %.3f, UIParent scale %.3f, interface %d",
		w, h, src, w / h, UIParent:GetScale(), select(4, GetBuildInfo())))
end

--------------------------------------------------------------------------------
-- Driver
--------------------------------------------------------------------------------

local CHECKS = {
	{ "c_sound",            CheckCSound },
	{ "settings_panel",     CheckSettingsPanel },
	{ "weather_model",      CheckWeatherModel },
	{ "geometry",           CheckGeometry },
	{ "mute_self",          CheckMuteSelf },
	{ "finish_event",       CheckFinishEvent },
	{ "ambience_musicoff",  CheckAmbienceWithMusicOff },
}

local function RunAll(skip)
	store()
	msg("running checks. Answers land in DuskfallDB.probe.")
	for _, c in ipairs(CHECKS) do
		if not (skip and skip[c[1]]) then try(c[1], c[2]) end
	end
	ArmMutePersistence()
	ArmSavedVars()
	msg("two checks need a |cffffd100/reload|r to finish. |cffffd100/dusk probe report|r afterwards.")
end

--------------------------------------------------------------------------------
-- Unattended mode
--
-- Set DuskfallDB.probe.autorun on disk before the client starts and the probe
-- drives itself: it runs the checks, reloads itself to answer the two that need
-- a reload, plays a timed audio sequence, and reloads again to flush the file.
-- Nothing is typed and nothing is transcribed.
--
-- The ambience question is the reason this exists. Asked by hand it ends in
-- "ask", because Lua can only observe that the client AGREED to play. Here the
-- probe instead plays known sounds inside windows it timestamps to the second,
-- and the machine recording the speaker output decides what was audible. Same
-- discipline as every other check: window 1 is silence, window 2 is the same
-- file on Master with music ON (the positive control), window 3 is the actual
-- question. A quiet window 3 next to a quiet window 2 proves nothing.
--------------------------------------------------------------------------------

local AUDIO_PLAN = {
	{ name = "baseline",      secs = 5 },
	{ name = "control_master", secs = 7, file = RAIN, channel = "Master", music = "1" },
	{ name = "gap",           secs = 4 },
	{ name = "ambience_nomusic", secs = 7, file = RAIN, channel = "Ambience", music = "0" },
	{ name = "tail",          secs = 5 },
}

local function RunAudioSequence(done)
	store()
	P.audio = { windows = {}, startedAt = time and time() or 0 }
	local restore = GetCVar("Sound_EnableMusic")
	local at = 0

	for _, step in ipairs(AUDIO_PLAN) do
		local offset = at
		C_Timer.After(offset, function()
			pcall(function()
				if step.music then SetCVar("Sound_EnableMusic", step.music) end
				local willPlay, handle
				if step.file then willPlay, handle = PlaySoundFile(step.file, step.channel) end
				local w = {
					name = step.name, t0 = time and time() or 0,
					file = step.file, channel = step.channel,
					music = step.music, willPlay = willPlay and true or false,
					handle = handle,
				}
				P.audio.windows[#P.audio.windows + 1] = w
				C_Timer.After(step.secs - 0.5, function()
					pcall(function()
						if handle then StopSound(handle, 200) end
						w.t1 = time and time() or 0
					end)
				end)
			end)
		end)
		at = at + step.secs
	end

	C_Timer.After(at + 1, function()
		pcall(function()
			SetCVar("Sound_EnableMusic", restore or "1")
			P.audio.endedAt = time and time() or 0
			record("audio_sequence", "ask",
				"played " .. #AUDIO_PLAN .. " timed windows; the recording decides what was audible")
			done()
		end)
	end)
end

-- ReloadUI is refused in combat and the probe must never fight the client for
-- it. Three attempts, then it gives up and leaves the stage where it is, so a
-- later login finishes the job instead of looping forever.
local function SafeReload(stage)
	store()
	P.stage = stage
	P.reloads = (P.reloads or 0) + 1
	if P.reloads > 4 then
		msg("|cffff6666too many reloads, stopping.|r Finish with /dusk probe report.")
		P.autorun = nil
		return
	end
	local tries = 0
	local function go()
		tries = tries + 1
		if InCombatLockdown and InCombatLockdown() and tries < 30 then
			C_Timer.After(2, go)
			return
		end
		msg("reloading, unattended.")
		ReloadUI()
	end
	go()
end

local function Unattended()
	store()
	if not P.autorun then return end

	if P.stage == nil then
		-- The ambience check is skipped here: the timed sequence below answers
		-- the same question with an instrument better than a yes/no prompt.
		RunAll({ ambience_musicoff = true })
		C_Timer.After(20, function() SafeReload("audio") end)

	elseif P.stage == "audio" then
		-- savedvars and mute_reload already answered themselves on the way up.
		RunAudioSequence(function() SafeReload("flush") end)

	elseif P.stage == "flush" then
		P.stage = "done"
		P.autorun = nil
		P.finishedAt = time and time() or 0
		msg("|cff66ff66probe complete.|r Results are in DuskfallDB.probe.")
		-- One more reload, purely to write that last line to disk.
		C_Timer.After(2, function()
			P.reloads = 0
			SafeReload("done")
		end)
	end
end

local function Report()
	store()
	if #P.order == 0 then msg("nothing recorded yet. |cffffd100/dusk probe|r") return end
	msg("results, build " .. tostring(select(2, GetBuildInfo())) .. ":")
	for _, id in ipairs(P.order) do
		local r = P.results[id]
		local colour = (r.verdict == "yes" and "|cff66ff66") or (r.verdict == "no" and "|cffff6666")
			or (r.verdict == "ask" and "|cffffd100") or "|cff888888"
		print(string.format("  %-18s %s%-7s|r %s", id, colour, r.verdict, r.detail))
	end
end

--------------------------------------------------------------------------------
-- Entry point. Duskfall.lua calls this if the file is installed.
--------------------------------------------------------------------------------

function Duskfall_Probe(arg)
	arg = (arg or ""):lower()
	local sub, rest = arg:match("^(%S*)%s*(.-)$")

	if sub == "" then
		RunAll()
	elseif sub == "report" then
		Report()
	elseif sub == "heard" then
		store()
		local id = P.pendingEars
		if not id then msg("nothing is waiting on your ears right now.") return end
		local heard = (rest == "yes" or rest == "y")
		local r = P.results[id]
		record(id, heard and "yes" or "no",
			(r and r.detail or "") .. " |cffffffff[player heard it: " .. tostring(heard) .. "]|r")
		P.pendingEars = nil
	elseif sub == "wipe" then
		DuskfallDB.probe = nil
		P = nil
		msg("probe results wiped.")
	else
		msg("|cffffd100/dusk probe|r, |cffffd100/dusk probe report|r, " ..
		    "|cffffd100/dusk probe heard yes|no|r, |cffffd100/dusk probe wipe|r")
	end
end

--------------------------------------------------------------------------------
-- The two checks that answer themselves on the way back up from a /reload.
--------------------------------------------------------------------------------

local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:SetScript("OnEvent", function(self, _, name)
	if name ~= ADDON then return end
	self:UnregisterEvent("ADDON_LOADED")
	-- Nothing to answer unless a previous run armed something. Checking before
	-- store() matters: store() creates the table, and a player who installed
	-- the addon and never typed /dusk probe must not end up with probe state
	-- in their SavedVariables file.
	if type(DuskfallDB) ~= "table" or type(DuskfallDB.probe) ~= "table" then return end
	try("savedvars", CheckSavedVarsOnLoad)
	try("mute_reload", CheckMutePersistenceOnLoad)
end)

-- Unattended mode waits for the world, because sound needs it.
local auto = CreateFrame("Frame")
auto:RegisterEvent("PLAYER_ENTERING_WORLD")
auto:SetScript("OnEvent", function()
	if type(DuskfallDB) ~= "table" or type(DuskfallDB.probe) ~= "table" then return end
	if not DuskfallDB.probe.autorun then return end
	C_Timer.After(5, function() try("unattended", Unattended) end)
end)

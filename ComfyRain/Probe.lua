-- ComfyRain probe - the eight questions that die with the beta client.
--
-- The beta is withdrawn on 2026-10-21 and the game does not exist again until
-- 4 November. Everything below needs a running client and cannot be answered
-- from a binary string, a wiki page or a test harness. Doing them by hand means
-- remembering eight procedures in the right order; this does them in one
-- command and writes the answers into SavedVariables, so the results can be
-- read off disk afterwards instead of transcribed out of a chat window.
--
-- This is a SEPARATE FILE on purpose. Each .lua in a TOC is its own chunk, so a
-- raise in here cannot abort ComfyRain.lua. Every check is additionally pcall'd,
-- because a probe that kills the addon it is probing is worse than no probe.
--
-- Drop this file and its TOC line to ship without it.

local ADDON = "ComfyRain"
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

local P    -- ComfyRainDB.probe, filled on first use

local function store()
	ComfyRainDB = ComfyRainDB or {}
	ComfyRainDB.probe = ComfyRainDB.probe or { results = {}, order = {} }
	P = ComfyRainDB.probe
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

-- solo = run only this check, with a countdown and nothing else printing.
--
-- The first version played the clip once, for six seconds, in the middle of a
-- twelve-line dump of every other check's output. That asks somebody to listen
-- carefully at the exact moment they are reading, and the first real answer it
-- got back was wrong in the direction that matters: "yes" from someone who had
-- not heard anything. This is the single assumption the ambience-led product
-- rests on, so a wrong yes here is worse than no answer at all.
local function CheckAmbienceWithMusicOff(solo)
	local before = GetCVar("Sound_EnableMusic")
	SetCVar("Sound_EnableMusic", "0")

	local function play()
		local willPlay, handle = PlaySoundFile(RAIN, "Ambience")
		record("ambience_musicoff", willPlay and "ask" or "no",
			string.format("willPlay=%s handle=%s, music was %s.%s",
				tostring(willPlay), tostring(handle), tostring(before),
				solo and "" or
				" |cffffd100Do you hear rain? /comfy probe heard yes||no|r"))
		store()
		P.pendingEars = "ambience_musicoff"
		if solo then
			msg("|cffffd100>>> LISTENING NOW <<<|r rain should be playing, " ..
			    "for about 10 seconds.")
		end
		C_Timer.After(solo and 10 or 6, function()
			pcall(function()
				if handle then StopSound(handle, 500) end
				SetCVar("Sound_EnableMusic", before or "1")
			end)
			if solo then
				msg("Stopped. |cffffd100/comfy probe heard yes|r or " ..
				    "|cffffd100/comfy probe heard no|r - whichever it was. " ..
				    "You can change your mind by typing the other one.")
			end
		end)
	end

	if not solo then return play() end

	-- Three seconds of nothing, so the question lands before the sound does.
	msg("|cff66ff66Listening test.|r Music is off. Turn your speakers up and " ..
	    "stop moving.")
	msg("Rain will play in |cffffd100three seconds|r. The only thing being " ..
	    "asked is whether you hear it at all.")
	C_Timer.After(3, play)
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
-- 6b. Does the bed kit's volumeOverride reach the speakers? (issue #29)
--
-- The fix plays each bed as its single-file SoundKit (8534 is RainMediumLoop)
-- so the gain has somewhere to go. Lua can see that the client accepted each
-- call; only ears can say the second clip was quieter, so this ends in "ask".
--
-- kit_overlap is the Forever question. Forever's copy of 8534 carries flag
-- 0x20 and Retail's does not, and every reloop starts the kit again while the
-- old copy is still running. "no" here means the addon will latch to file
-- playback on the first reloop and the slider goes dead for the session.
--------------------------------------------------------------------------------

local BED_KIT = 8534

local function CheckKitVolume()
	local function play(volume)
		local callOk, a, b = pcall(C_Sound.PlaySoundWithOptions,
			{ soundKitID = BED_KIT, channel = "Ambience", volumeOverride = volume })
		if not callOk then return nil, nil, tostring(a) end
		return a, b
	end

	-- ComfyRain's own bed is very likely kit 8534 itself (medium rain is the
	-- default), and on a client that refuses duplicates it would make the
	-- first call here fail for a reason that has nothing to do with volume.
	-- So the addon's sound goes off for the test and comes back after it.
	local liveDB = ComfyRainAPI and ComfyRainAPI.DB and ComfyRainAPI.DB()
	local hadSound = liveDB and liveDB.sound
	local function say(c)
		pcall(function()
			if ComfyRainAPI and ComfyRainAPI.Command then ComfyRainAPI.Command(c) end
		end)
	end
	if hadSound then say("sound off") end
	local function restore()
		if hadSound then say("sound on") end
	end

	msg("|cff66ff66Volume test.|r Rain plays twice, five seconds each: LOUD, " ..
	    "then the SAME rain at 15%. Starting in three seconds.")
	C_Timer.After(3, function()
		local okLoud, hLoud, errLoud = play(1.0)
		msg("|cffffd100>>> 1 of 2: full volume <<<|r")
		C_Timer.After(5, function()
			pcall(function() if hLoud then StopSound(hLoud, 300) end end)
			C_Timer.After(1.5, function()
				local okQuiet, hQuiet, errQuiet = play(0.15)
				msg("|cffffd100>>> 2 of 2: 15% <<<|r")
				C_Timer.After(5, function()
					pcall(function() if hQuiet then StopSound(hQuiet, 300) end end)

					-- The overlap check, silent enough not to matter: two
					-- copies of the same kit, the second started while the
					-- first still runs, exactly as a reloop does it.
					local okA, hA = play(0.05)
					local okB, hB = play(0.05)
					pcall(function()
						if hA then StopSound(hA) end
						if hB then StopSound(hB) end
					end)
					record("kit_overlap", (okA and okB) and "yes" or (okA and "no" or "unknown"),
						string.format("kit %d twice at once: first=%s second=%s. %s", BED_KIT,
							tostring(okA), tostring(okB),
							(okA and not okB) and "a reloop will be refused; the addon latches to files"
							or (not okA) and "the first copy was refused too, so this says nothing"
							or "reloops are allowed"))

					record("kit_volume", (okLoud and okQuiet) and "ask" or "no",
						string.format("kit %d loud ok=%s handle=%s, quiet ok=%s handle=%s%s",
							BED_KIT, tostring(okLoud), tostring(hLoud), tostring(okQuiet),
							tostring(hQuiet),
							(errLoud or errQuiet) and (" raised: " .. tostring(errLoud or errQuiet)) or ""))
					restore()
					store()
					if okLoud and okQuiet then
						P.pendingEars = "kit_volume"
						msg("Was the SECOND one clearly quieter? " ..
						    "|cffffd100/comfy probe heard yes|r or |cffffd100/comfy probe heard no|r")
					end
				end)
			end)
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
	panel.name = "ComfyRain probe panel"
	local cat = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
	if not cat then
		record("settings_panel", "no", "RegisterCanvasLayoutCategory returned nil")
		return
	end
	local registered = pcall(Settings.RegisterAddOnCategory, cat)
	local tagged = pcall(function() cat:AddSearchTags("comfyrain") end)
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
-- 8b. Can 3D particles be drawn OVER the world? The last open question.
--
-- Check 8 above proves only that a Model frame will load the weather M2. A
-- loaded model is not a visible one and a visible one is not a useful one, and
-- the difference between those three is the whole question. Asked 2026-10-19
-- after the binary ruled out every other route to 3D or a skybox:
--
--   ApplyWeather, RemoveWeather, ApplyScreenEffect, ApplyTimeOfDay and
--   SetDetailDoodadsOverride all sit in ONE contiguous block of the binary
--   alongside ImportTimelineActor, IsTimelineEditing, EvalWorldStateExpression,
--   LoadPath and ScriptPackageLoader::ScriptText. That is the server-driven
--   scene-script binding table, not the addon Lua API. There is no SetSkybox,
--   no C_Skybox, no SetWorldFogColor, no SetGamma. LightSkybox exists only as
--   a DB2 record class. SetFogColor, SetLight, SetFogNear and SetFogFar are
--   all `self:` Model-widget methods, confirmed by their usage strings.
--
-- So a Model frame is the only 3D surface an addon can create at all, and this
-- check answers the three things that decide whether it beats a 2D sheet:
--
--   1. Does it draw TRANSPARENTLY over the world, or does it occlude it? A
--      fullscreen panel that clears to black is the end of the idea.
--   2. Do the M2's particle emitters actually emit in a UI model frame?
--   3. Is ModelSceneFrame (which exists in this binary, and is the richer
--      widget) creatable from an addon, and does it behave any differently?
--
-- It cannot be automated. Nothing in the API reports what was rasterised, so
-- the only instrument is the player's eyes, which is why this ends in a
-- question rather than a verdict.
--
-- Known in advance and NOT what this is testing: there is no world camera
-- pitch or yaw to read. GetCameraZoom is a global and returns distance only;
-- GetCameraPosition, GetCameraFacing and GetCameraRoll are Model-widget
-- methods on the frame's OWN camera, not the world's. So even a perfect result
-- here cannot track the view when the player looks up or down. That is a cost
-- to weigh against the win, not a reason to skip the measurement.
--------------------------------------------------------------------------------

local function Say(text)
	msg("|cffffd100" .. text .. "|r")
end

-- Revised after the first run, 2026-10-19, which reported nothing in either
-- stage and proved nothing by it:
--
--   * ModelSceneFrame is NOT a creatable frame type here. CreateFrame raised
--     "Unknown frame type 'ModelSceneFrame'". The C++ class is in the binary
--     (.?AVModelSceneFrame@@) and C_ModelInfo still takes one as an argument,
--     but no Lua constructor is bound, so that stage was never a measurement.
--     Dropped rather than repeated.
--   * SetCameraDistance raised "Not using a custom camera", and because the
--     whole setup sat inside ONE pcall, SetPosition and SetAnimation never
--     ran. An M2 whose animation was never started has emitters that were
--     never told to emit, so "I saw nothing" is what a correct API and a
--     broken setup both look like. Every call now gets its own pcall.
--   * There was no positive control. "Nothing rendered" is only evidence once
--     something is known to render on the same surface, which is the whole of
--     rule one and was simply missing.
--
-- So three stages, and the first two exist to make the third readable:
--
--   A  PlayerModel + SetUnit("player"), fullscreen. Does ANY 3D draw over the
--      world from an addon, and is the empty part of the panel transparent?
--   B  Model + LoginFX, a model that is nothing but particle emitters. Do
--      emitters run inside a UI model frame at all?
--   C  Model + the weather M2. The actual question.
--
-- Reading it: A nothing kills the route outright. A yes, B nothing means model
-- frames render geometry but not particles, which also kills it. A and B yes,
-- C nothing means this particular M2 is wrong and another is worth trying. Any
-- stage black means the surface is opaque, which kills it hardest of all.
local function Build3DPanel(kind)
	local f = CreateFrame(kind, nil, WorldFrame)
	f:SetFrameStrata("BACKGROUND")
	f:SetAllPoints(WorldFrame)
	return f
end

-- Each call on its own, so one unsupported method costs that method and not
-- the rest of the setup. Returns the name if it raised, nil if it worked.
local function soft(obj, method, ...)
	if not obj or type(obj[method]) ~= "function" then return method .. ":absent" end
	local ok, err = pcall(obj[method], obj, ...)
	if ok then return nil end
	return method .. ":" .. tostring(err):gsub("^.*%.lua:%d+:%s*", "")
end

local function Run3D(done)
	store()
	local notes = {}
	local function note(s) notes[#notes + 1] = s end
	-- select("#"), not ipairs on a packed table. soft() returns nil for a call
	-- that worked, and ipairs stops dead at the first nil - so one successful
	-- call early in the list would hide every failure after it and the stage
	-- would report "clean" while half of it had raised. That is the exact
	-- class of false negative this whole section exists to avoid.
	local function fails(...)
		local n, out = select("#", ...), {}
		for i = 1, n do
			local v = select(i, ...)
			if v then out[#out + 1] = v end
		end
		return #out > 0 and table.concat(out, ", ") or "clean"
	end

	local function finish(f)
		pcall(function() f:Hide() f:SetParent(nil) end)
	end

	-- Stage A: the positive control.
	local a, aerr = nil, nil
	local okA = pcall(function() a = Build3DPanel("PlayerModel") end)
	if okA then
		aerr = fails(
			soft(a, "SetUnit", "player"),
			soft(a, "SetCamDistanceScale", 1.4),
			soft(a, "SetPortraitZoom", 0),
			soft(a, "RefreshUnit"))
	else
		aerr = "PlayerModel not creatable"
	end
	note("A PlayerModel: " .. aerr)

	Say("STAGE A of C, 6 seconds. Watch the WORLD, not this window.")
	Say("Your own character should be drawn huge over everything.")

	C_Timer.After(6, function()
		if a then finish(a) end

		-- Stage B: a model that is nothing but particles.
		local b, berr = nil, nil
		local okB = pcall(function() b = Build3DPanel("Model") end)
		if okB then
			berr = fails(
				soft(b, "SetModel", CONTROL_M2),
				-- Order matters. A custom camera has to exist before any of
				-- the camera setters will accept a value.
				soft(b, "SetCustomCamera", 1),
				soft(b, "SetCameraPosition", -14, 0, 0),
				soft(b, "SetCameraTarget", 0, 0, 0),
				soft(b, "SetParticlesEnabled", true),
				soft(b, "SetModelScale", 3),
				-- Without this the emitters are loaded and idle, which is the
				-- mistake the first run made.
				soft(b, "SetAnimation", 0),
				soft(b, "SetSequence", 0))
		else
			berr = "Model not creatable"
		end
		note("B LoginFX " .. CONTROL_M2 .. ": " .. berr)

		Say("STAGE B of C, 6 seconds. Any particles at all?")

		C_Timer.After(6, function()
			if b then finish(b) end

			-- Stage C: the real question, set up exactly like B.
			local c, cerr = nil, nil
			local okC = pcall(function() c = Build3DPanel("Model") end)
			if okC then
				cerr = fails(
					soft(c, "SetModel", WEATHER_M2),
					soft(c, "SetCustomCamera", 1),
					soft(c, "SetCameraPosition", -14, 0, 0),
					soft(c, "SetCameraTarget", 0, 0, 0),
					soft(c, "SetParticlesEnabled", true),
					soft(c, "SetModelScale", 3),
					soft(c, "SetAnimation", 0),
					soft(c, "SetSequence", 0))
			else
				cerr = "Model not creatable"
			end
			note("C weather " .. WEATHER_M2 .. ": " .. cerr)

			Say("STAGE C of C, 6 seconds. Rain?")

			C_Timer.After(6, function()
				if c then finish(c) end
				record("model_3d", "ask", table.concat(notes, " | "))
				P.pendingEyes = "model_3d"
				Say("Answer with ONE command:")
				Say("/comfy probe saw <A> <B> <C>")
				Say("each word one of:  nothing  black  yes")
				Say("example:  /comfy probe saw yes nothing nothing")
				if done then done() end
			end)
		end)
	end)
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
-- 10. Can an addon turn the realm's own weather off?
--
-- The question the author asked on 2026-10-16, and the only one that decides
-- whether ComfyRain REPLACES the weather or merely draws on top of it. There is
-- no weather setter in Lua and there never was, but `weatherDensity` is an
-- ordinary graphics CVar (0-3) sitting in the binary between `particleDensity`
-- and `volumeFogLevel`, and at 0 the client renders no weather at all. If an
-- addon may write it, our rain is the only rain on screen.
--
-- Why this needs a control: a protected CVar does NOT raise. SetCVar returns
-- as if it worked and the value simply does not move, so "it did not change"
-- is indistinguishable from "SetCVar is blocked for addons on this build"
-- until a write that IS permitted has been seen to land.
--
-- Harmless CVars first, and every one of them is put back.
--------------------------------------------------------------------------------

local CVAR_CONTROLS = { "screenshotQuality", "particleDensity", "nameplateShowAll" }

-- Writes a value, reads it straight back, restores the original. Returns
-- whether the write actually landed.
local function Poke(name, target)
	local before = GetCVar(name)
	if before == nil then return nil end
	pcall(SetCVar, name, target)
	local after = GetCVar(name)
	pcall(SetCVar, name, before)
	return after == target, before
end

local function CheckWeatherCVar()
	if type(SetCVar) ~= "function" or type(GetCVar) ~= "function" then
		record("weather_cvar", "unknown", "no SetCVar/GetCVar on this build")
		return
	end

	local provenBy
	for _, name in ipairs(CVAR_CONTROLS) do
		local before = GetCVar(name)
		if before ~= nil then
			local moved = Poke(name, before == "0" and "1" or "0")
			if moved then provenBy = name break end
		end
	end
	if not provenBy then
		record("weather_cvar", "unknown",
			"not one control CVar would move, so SetCVar itself is unproven here")
		return
	end

	local before = GetCVar("weatherDensity")
	if before == nil then
		record("weather_cvar", "no", "weatherDensity does not exist on this build")
		return
	end
	local target = (before == "0") and "3" or "0"
	local moved = Poke("weatherDensity", target)

	record("weather_cvar", moved and "yes" or "no", string.format(
		"%s moved, so writes land; weatherDensity was %s, wrote %s, read back %s, restored. "
		.. "Whether 0 also stops the engine's new lightning is your eyes, not Lua.",
		provenBy, tostring(before), target, moved and target or "unchanged"))
end

--------------------------------------------------------------------------------
-- Driver
--------------------------------------------------------------------------------

local CHECKS = {
	{ "c_sound",            CheckCSound },
	{ "settings_panel",     CheckSettingsPanel },
	{ "weather_model",      CheckWeatherModel },
	{ "geometry",           CheckGeometry },
	{ "weather_cvar",       CheckWeatherCVar },
	{ "mute_self",          CheckMuteSelf },
	{ "finish_event",       CheckFinishEvent },
	{ "ambience_musicoff",  CheckAmbienceWithMusicOff },
}

local function RunAll(skip)
	store()
	msg("running checks. Answers land in ComfyRainDB.probe.")
	for _, c in ipairs(CHECKS) do
		if not (skip and skip[c[1]]) then try(c[1], c[2]) end
	end
	ArmMutePersistence()
	ArmSavedVars()
	msg("two checks need a |cffffd100/reload|r to finish. |cffffd100/comfy probe report|r afterwards.")
end

--------------------------------------------------------------------------------
-- Unattended mode
--
-- Set ComfyRainDB.probe.autorun on disk before the client starts and the probe
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
		msg("|cffff6666too many reloads, stopping.|r Finish with /comfy probe report.")
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
		msg("|cff66ff66probe complete.|r Results are in ComfyRainDB.probe.")
		-- One more reload, purely to write that last line to disk.
		C_Timer.After(2, function()
			P.reloads = 0
			SafeReload("done")
		end)
	end
end

local function Report()
	store()
	if #P.order == 0 then msg("nothing recorded yet. |cffffd100/comfy probe|r") return end
	msg("results, build " .. tostring(select(2, GetBuildInfo())) .. ":")
	for _, id in ipairs(P.order) do
		local r = P.results[id]
		local colour = (r.verdict == "yes" and "|cff66ff66") or (r.verdict == "no" and "|cffff6666")
			or (r.verdict == "ask" and "|cffffd100") or "|cff888888"
		print(string.format("  %-18s %s%-7s|r %s", id, colour, r.verdict, r.detail))
	end
end

--------------------------------------------------------------------------------
-- Entry point. ComfyRain.lua calls this if the file is installed.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- The screenshot sweep.
--
-- "Go and look at /comfy snow in daylight and at night" is the one Phase 1 item
-- that reads like it needs a human, and it does not. Screenshot() is callable
-- from Lua, the files land in the Screenshots folder with the client's own
-- timestamps, and a manifest written next to them in SavedVariables says which
-- state each one was. Nobody has to describe a picture in words.
--
-- Positive control first, same as everywhere else in this file: one shot is
-- taken with the weather OFF. If that file never appears, Screenshot() is
-- blocked on this build and every later "nothing wrong with the snow" would be
-- an artifact of an empty folder rather than an observation.
--------------------------------------------------------------------------------

-- Every intensity of both weathers, in order, because tools/perceive.py makes
-- a claim about each neighbouring pair and these are the pictures that check
-- it. Light snow and heavy rain each looked like their neighbour in game while
-- the numbers said otherwise.
local SHOTS = {
	{ "control-off",          { "off" } },
	{ "rain-light-day",       { "rain", "light", "time 12" } },
	{ "rain-normal-day",      { "normal" } },
	{ "rain-heavy-day",       { "heavy" } },
	{ "rain-monsoon-day",     { "monsoon" } },
	{ "snow-light-day",       { "snow", "light" } },
	{ "snow-normal-day",      { "normal" } },
	{ "snow-heavy-day",       { "heavy" } },
	{ "snow-blizzard-day",    { "blizzard" } },
	{ "snow-blizzard-dusk",   { "time 19" } },
	{ "snow-blizzard-night",  { "time 23" } },
	{ "rain-monsoon-night",   { "rain", "monsoon" } },
	{ "rain-normal-noon",     { "normal", "time off" } },
}

local function RunShots(done)
	store()
	if type(Screenshot) ~= "function" then
		record("screenshots", "no", "Screenshot() does not exist on this build")
		if done then done() end
		return
	end

	-- Settings are restored at the end. A probe that silently leaves the
	-- player's client reconfigured is a bug with a clipboard.
	local before = {
		format  = GetCVar("screenshotFormat"),
		quality = GetCVar("screenshotQuality"),
		db      = {},
	}
	local liveDB = ComfyRainAPI and ComfyRainAPI.DB and ComfyRainAPI.DB()
	if liveDB then
		for _, k in ipairs({ "enabled", "weather", "intensity", "timeMode", "timeFixed" }) do
			before.db[k] = liveDB[k]
		end
	end
	pcall(SetCVar, "screenshotFormat", "jpeg")
	pcall(SetCVar, "screenshotQuality", "10")

	-- The UI goes away for the whole sweep, which is what Alt-Z does by hand.
	-- A shot of the weather with an action bar across the bottom of it answers
	-- the question it was taken for and cannot be used for anything else, and
	-- these are the same shots the store gallery needs. Restored in the same
	-- block that puts the CVars back, which runs whatever the shots did.
	local hid = type(SetUIVisibility) == "function" and pcall(SetUIVisibility, false)

	P.shots = { startedAt = time and time() or 0, order = {}, taken = {} }
	msg(string.format("taking %d screenshots, about %d seconds. Leave the camera alone." ..
		(hid and " The UI goes away until it is done." or ""),
		#SHOTS, #SHOTS * 5))

	local at = 0
	for i, shot in ipairs(SHOTS) do
		local name, commands = shot[1], shot[2]
		at = at + 1.0
		C_Timer.After(at, function()
			pcall(function()
				for _, c in ipairs(commands) do
					if ComfyRainAPI and ComfyRainAPI.Command then ComfyRainAPI.Command(c) end
				end
			end)
		end)
		-- 3.5s between the command and the shutter: the overlay cross-fades and
		-- the time-of-day grade lerps, so a shot taken immediately photographs
		-- the transition rather than the state being asked about.
		at = at + 3.5
		C_Timer.After(at, function()
			P.shots.order[#P.shots.order + 1] = name
			P.shots.taken[name] = {
				index = i,
				at = (date and date("%Y-%m-%d %H:%M:%S")) or tostring(time and time() or 0),
			}
			pcall(Screenshot)
		end)
		at = at + 0.5
	end

	C_Timer.After(at + 2, function()
		-- Ahead of everything else and outside the pcall below: leaving the
		-- player staring at an empty screen is the one failure here they
		-- cannot undo without knowing the keybind this just replaced.
		if hid then pcall(SetUIVisibility, true) end
		pcall(function()
			-- Only put back what was actually there. Inventing "jpeg" for a
			-- client that had no value set is a change, not a restore.
			if before.format then pcall(SetCVar, "screenshotFormat", before.format) end
			if before.quality then pcall(SetCVar, "screenshotQuality", before.quality) end
			if liveDB then
				for k, v in pairs(before.db) do liveDB[k] = v end
				if ComfyRainAPI and ComfyRainAPI.Command then ComfyRainAPI.Command("") end
			end
			record("screenshots", "ask",
				string.format("%d shots requested, manifest in ComfyRainDB.probe.shots. " ..
					"The control is index 1, weather off - if that file is missing, " ..
					"Screenshot() is blocked and the rest prove nothing.", #SHOTS))
			store()
		end)
		if done then done() end
	end)
end

function ComfyRain_Probe(arg)
	arg = (arg or ""):lower()
	local sub, rest = arg:match("^(%S*)%s*(.-)$")

	if sub == "" then
		RunAll()
	elseif sub == "report" then
		Report()
	-- Replay the listening test on its own. The clip is six seconds long and
	-- the first run buries the question in everything else the probe printed,
	-- so "I answered before I was listening" is the normal case here, not an
	-- edge one.
	elseif sub == "ears" or sub == "listen" then
		try("ambience_musicoff", function() CheckAmbienceWithMusicOff(true) end)
	elseif sub == "heard" then
		store()
		-- An answer can be changed. pendingEars is cleared once answered, and
		-- the first version then refused with "nothing is waiting on your ears"
		-- - which locks in the wrong answer to the one question in this probe
		-- that nothing else can check. The recorded result is the thing that
		-- matters, so a second answer overwrites the first.
		local id = P.pendingEars or
			(P.results["ambience_musicoff"] and "ambience_musicoff")
		if not id then
			msg("nothing has asked your ears yet. |cffffd100/comfy probe ears|r " ..
			    "runs the listening test on its own.")
			return
		end
		if rest ~= "yes" and rest ~= "y" and rest ~= "no" and rest ~= "n" then
			msg("|cffffd100/comfy probe heard yes|r or |cffffd100/comfy probe heard no|r")
			return
		end
		local heard = (rest == "yes" or rest == "y")
		local r = P.results[id]
		local was = r and r.detail and r.detail:match("%[player heard it: (%a+)%]")
		-- Strip any previous answer rather than stacking a second one after it.
		local detail = (r and r.detail or ""):gsub(
			"%s*|cffffffff%[player heard it: %a+%]|r", "")
		record(id, heard and "yes" or "no",
			detail .. " |cffffffff[player heard it: " .. tostring(heard) .. "]|r")
		if was and was ~= tostring(heard) then
			msg("changed from |cffffd100" .. was .. "|r. This one is the answer " ..
			    "that counts; |cffffd100/comfy probe ears|r replays it again.")
		end
		P.pendingEars = nil
	elseif sub == "3d" then
		try("model_3d", function() Run3D() end)
	elseif sub == "volume" then
		try("kit_volume", CheckKitVolume)
	elseif sub == "saw" then
		store()
		local id = P.pendingEyes
		if not id then msg("nothing is waiting on your eyes right now.") return end
		local a, b, c = rest:match("^(%S+)%s+(%S+)%s+(%S+)$")
		local VALID = { nothing = true, black = true, yes = true }
		if not (a and VALID[a] and VALID[b] and VALID[c]) then
			msg("need three words, each one of |cffffd100nothing|r, " ..
			    "|cffffd100black|r, |cffffd100yes|r. Example: " ..
			    "|cffffd100/comfy probe saw yes nothing nothing|r")
			return
		end
		local r = P.results[id]
		-- Stage A is the control and it decides whether the other two words
		-- mean anything. Written here rather than worked out later, because a
		-- result that gets interpreted after it arrives gets interpreted into
		-- whatever was already believed.
		local verdict, why
		if a == "black" or b == "black" or c == "black" then
			verdict, why = "no", "a fullscreen model panel is opaque"
		elseif a ~= "yes" then
			verdict, why = "unknown", "the control did not render, so nothing else is evidence"
		elseif c == "yes" then
			verdict, why = "yes", "the weather M2 emits over the world"
		elseif b == "yes" then
			verdict, why = "partial", "emitters run, but not this M2 - try another"
		else
			verdict, why = "no", "geometry renders, particle emitters do not"
		end
		record(id, verdict, (r and r.detail or "") ..
			string.format(" |cffffffff[A=%s B=%s C=%s: %s]|r", a, b, c, why))
		msg("|cffffd100" .. why .. "|r")
		P.pendingEyes = nil
	elseif sub == "shots" then
		RunShots(function()
			msg("shots done. |cffffd100/reload|r to write the manifest to disk.")
		end)
	elseif sub == "wipe" then
		ComfyRainDB.probe = nil
		P = nil
		msg("probe results wiped.")
	else
		msg("|cffffd100/comfy probe|r, |cffffd100/comfy probe report|r, " ..
		    "|cffffd100/comfy probe shots|r, |cffffd100/comfy probe 3d|r, " ..
		    "|cffffd100/comfy probe volume|r, " ..
		    "|cffffd100/comfy probe heard yes||no|r, |cffffd100/comfy probe ears|r, " ..
		    "|cffffd100/comfy probe wipe|r")
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
	-- the addon and never typed /comfy probe must not end up with probe state
	-- in their SavedVariables file.
	if type(ComfyRainDB) ~= "table" or type(ComfyRainDB.probe) ~= "table" then return end
	try("savedvars", CheckSavedVarsOnLoad)
	try("mute_reload", CheckMutePersistenceOnLoad)
end)

-- Unattended mode waits for the world, because sound needs it.
local auto = CreateFrame("Frame")
auto:RegisterEvent("PLAYER_ENTERING_WORLD")
auto:SetScript("OnEvent", function()
	if type(ComfyRainDB) ~= "table" or type(ComfyRainDB.probe) ~= "table" then return end
	if not ComfyRainDB.probe.autorun then return end
	C_Timer.After(5, function() try("unattended", Unattended) end)
end)

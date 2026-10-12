-- AlwaysRain 2.0
--
-- The client cannot be told to make it rain: C_Weather only reads, ApplyWeather
-- belongs to server-driven scene scripts, and there is no weather console command.
-- So this draws the rain itself, on a frame between the 3D world and the UI.
--
-- Everything audible, and the drop sprite the textures are built from, is
-- Blizzard's own: the weather ambience loops the client already ships, played by
-- FileDataID. Only the tiling of the drops is ours, because the particle system
-- that would normally place them is not reachable from an addon.

local ADDON = "AlwaysRain"
local MEDIA = "Interface\\AddOns\\AlwaysRain\\"

local SLANT = 0.1317          -- tan(7.5 deg); must match SLANT_DEG in make_rain_tga.py
local BED_OVERLAP = 0.12      -- seconds of overlap when relooping the bed

-- Blizzard weather ambience, Sound/ambience/Weather/*. Durations measured from
-- the shipped files; they are exact, so the loop never gaps or doubles.
local BEDS = {
	light   = { id = 538983, len = 20.0 },   -- RainLightLoop.ogg
	normal  = { id = 538981, len = 30.0 },   -- RainMediumLoop.ogg
	heavy   = { id = 538982, len = 25.0 },   -- RainHeavyLoop.ogg
	monsoon = { id = 538982, len = 25.0 },
}
local FALLBACK_BED = { file = MEDIA .. "rain.ogg", len = 24.0 }

-- Sound/DOODAD/FX_TKIsle_MWThunderRumble01-10.ogg - real recorded thunder.
local THUNDER = { 838830, 838832, 838834, 839725, 839727, 839729, 839731, 839733, 839735, 839737 }
local FALLBACK_THUNDER = MEDIA .. "thunder.ogg"

local MIST_TEXTURE = 396498   -- Textures/WEATHER/WeatherMistGrainy01.blp

local PRESETS = {
	light   = { mist = 0.05, far = 0.40, near = 0.35, density = 1.35, speed = 0.80 },
	normal  = { mist = 0.10, far = 0.70, near = 0.65, density = 1.00, speed = 1.00 },
	heavy   = { mist = 0.17, far = 0.95, near = 0.90, density = 0.78, speed = 1.25 },
	monsoon = { mist = 0.26, far = 1.00, near = 1.00, density = 0.58, speed = 1.60 },
}
local PRESET_ORDER = { "light", "normal", "heavy", "monsoon" }

local DEFAULTS = {
	enabled   = true,
	intensity = "normal",
	scale     = 1.0,       -- multiplies every layer's alpha
	speed     = 1.0,       -- multiplies fall speed
	sound     = true,
	thunder   = true,
	indoors   = false,     -- rain indoors too
	channel   = "Ambience",
}

-- tilesY is how many copies of the 512px sheet fit vertically; tilesX is derived
-- from the screen aspect each frame so drops stay the right shape at any size.
local LAYERS = {
	{ key = "mist", tilesY = 1.1, speed = 0.09, blend = "BLEND", layer = "BACKGROUND" },
	{ key = "far",  tilesY = 3.0, speed = 1.05, blend = "BLEND", layer = "ARTWORK"    },
	{ key = "near", tilesY = 1.5, speed = 2.30, blend = "ADD",   layer = "ARTWORK"    },
}

local db
local overlay, flash
local textures, offsets = {}, {}
local soundHandles, rainTicker, bedFallback, loopedIntensity = {}, nil, false, nil
local lightningTimer
local cinematic, indoorsNow, indoorsSince = false, false, nil
local fade, fadeTarget = 1, 1
local indoorPoll = 0

local function msg(text)
	print("|cff7fb8ff" .. ADDON .. "|r: " .. text)
end

local function Preset()
	return PRESETS[db.intensity] or PRESETS.normal
end

--------------------------------------------------------------------------------
-- Visuals
--------------------------------------------------------------------------------

local function ApplyAlphas()
	local p, s = Preset(), db.scale
	textures.mist:SetAlpha(math.min(p.mist * s, 0.6))
	textures.far:SetAlpha(math.min(p.far * s, 1))
	textures.near:SetAlpha(math.min(p.near * s, 1))
end

-- Rain is wanted right now: on, not in a cinematic, and either outdoors or
-- the player has asked for it indoors too.
local function ShouldRain()
	if not db.enabled or cinematic then return false end
	if indoorsNow and not db.indoors then return false end
	return true
end

local function OnUpdate(self, elapsed)
	-- Indoor state has no reliable event on its own, so poll it cheaply.
	indoorPoll = indoorPoll + elapsed
	if indoorPoll > 0.3 then
		indoorPoll = 0
		local inside = IsIndoors() and true or false
		if inside ~= indoorsNow then
			-- Debounce: walking under an arch should not restart the audio.
			indoorsSince = indoorsSince or GetTime()
			if GetTime() - indoorsSince > 0.9 then
				indoorsNow = inside
				indoorsSince = nil
				AlwaysRain_Refresh()
			end
		else
			indoorsSince = nil
		end
	end

	if fade ~= fadeTarget then
		local step = elapsed / 0.7
		fade = (fade < fadeTarget) and math.min(fadeTarget, fade + step)
		                            or math.max(fadeTarget, fade - step)
		self:SetAlpha(fade)
		if fade <= 0 then self:Hide() return end
	end

	local w, h = self:GetWidth(), self:GetHeight()
	if not w or w <= 0 or not h or h <= 0 then return end

	local aspect = w / h
	local rate = Preset().speed * db.speed
	local density = Preset().density

	for _, l in ipairs(LAYERS) do
		local tilesY = l.tilesY * (l.key == "mist" and 1 or density)
		local o = offsets[l.key]
		local dy = l.speed * rate * elapsed
		-- The sampling window moves up the sheet so the image falls down the screen.
		o.y = (o.y - dy) % 1
		o.x = (o.x - dy * SLANT) % 1
		textures[l.key]:SetTexCoord(o.x, o.x + tilesY * aspect, o.y, o.y + tilesY)
	end
end

local function BuildOverlay()
	-- Parented to WorldFrame, not UIParent: the rain sits above the 3D scene but
	-- below every UI frame, and survives Alt+Z so screenshots keep it.
	overlay = CreateFrame("Frame", "AlwaysRainOverlay", WorldFrame)
	overlay:SetAllPoints(WorldFrame)
	overlay:SetFrameStrata("BACKGROUND")
	overlay:EnableMouse(false)

	local sources = {
		mist = MIST_TEXTURE,
		far  = MEDIA .. "rain-far.tga",
		near = MEDIA .. "rain-near.tga",
	}
	for i, l in ipairs(LAYERS) do
		local tex = overlay:CreateTexture(nil, l.layer, nil, i)
		tex:SetAllPoints(overlay)
		tex:SetTexture(sources[l.key], "REPEAT", "REPEAT")
		tex:SetBlendMode(l.blend)
		if l.key == "mist" then tex:SetVertexColor(0.58, 0.64, 0.74) end
		textures[l.key] = tex
		offsets[l.key] = { x = math.random(), y = math.random() }
	end

	flash = overlay:CreateTexture(nil, "OVERLAY")
	flash:SetAllPoints(overlay)
	flash:SetColorTexture(1, 1, 1, 1)
	flash:SetBlendMode("ADD")
	flash:SetAlpha(0)

	overlay:SetScript("OnUpdate", OnUpdate)
	ApplyAlphas()
end

--------------------------------------------------------------------------------
-- Sound
--------------------------------------------------------------------------------

local function CurrentBed()
	if bedFallback then return FALLBACK_BED.file, FALLBACK_BED.len end
	local b = BEDS[db.intensity] or BEDS.normal
	return b.id, b.len
end

local function PlayBedClip()
	if not ShouldRain() or not db.sound then return end
	local file = CurrentBed()
	local ok, handle = PlaySoundFile(file, db.channel)
	if not ok then
		if not bedFallback then
			bedFallback = true
			msg("the client would not play Blizzard's rain loop; using the bundled one.")
			return PlayBedClip()
		end
		return
	end
	soundHandles[#soundHandles + 1] = handle
	while #soundHandles > 2 do table.remove(soundHandles, 1) end
end

local function StopBed()
	for _, h in ipairs(soundHandles) do
		if h then StopSound(h) end
	end
	wipe(soundHandles)
	if rainTicker then rainTicker:Cancel() rainTicker = nil end
	loopedIntensity = nil
end

local function StartBed()
	StopBed()
	if not ShouldRain() or not db.sound then return end
	PlayBedClip()
	local _, len = CurrentBed()
	rainTicker = C_Timer.NewTicker(len - BED_OVERLAP, PlayBedClip)
	loopedIntensity = db.intensity
end

--------------------------------------------------------------------------------
-- Lightning
--------------------------------------------------------------------------------

local function FlashOnce(peak, duration)
	local elapsed = 0
	flash:SetAlpha(0)
	local driver = CreateFrame("Frame")
	driver:SetScript("OnUpdate", function(self, dt)
		elapsed = elapsed + dt
		local t = elapsed / duration
		if t >= 1 then
			flash:SetAlpha(0)
			self:SetScript("OnUpdate", nil)
			return
		end
		local a = (t < 0.18) and (t / 0.18) or (1 - (t - 0.18) / 0.82)
		flash:SetAlpha(peak * a * a)
	end)
end

local function Strike()
	if not ShouldRain() or not db.thunder then return end
	local peak = 0.14 + Preset().mist * 1.4
	FlashOnce(peak, 0.22)
	if math.random() < 0.45 then
		C_Timer.After(0.26, function() FlashOnce(peak * 0.7, 0.18) end)
	end
	-- Thunder trails the flash the way distance makes it.
	C_Timer.After(0.6 + math.random() * 2.6, function()
		if not ShouldRain() or not db.thunder or not db.sound then return end
		local ok = PlaySoundFile(THUNDER[math.random(#THUNDER)], db.channel)
		if not ok then PlaySoundFile(FALLBACK_THUNDER, db.channel) end
	end)
end

local function ScheduleLightning()
	if lightningTimer then lightningTimer:Cancel() lightningTimer = nil end
	if not db.enabled or not db.thunder then return end
	local base = 70 - (Preset().speed - 0.8) * 28
	lightningTimer = C_Timer.NewTimer(base * (0.55 + math.random() * 0.9), function()
		lightningTimer = nil
		Strike()
		ScheduleLightning()
	end)
end

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

function AlwaysRain_Refresh()
	if not overlay then return end
	local want = ShouldRain()

	fadeTarget = want and 1 or 0
	if want then
		overlay:Show()
		overlay:SetAlpha(fade)
	end
	ApplyAlphas()

	if want and db.sound then
		if not rainTicker or loopedIntensity ~= db.intensity then StartBed() end
	else
		StopBed()
	end

	if want and db.thunder then
		if not lightningTimer then ScheduleLightning() end
	elseif lightningTimer then
		lightningTimer:Cancel()
		lightningTimer = nil
	end
end
local Refresh = AlwaysRain_Refresh

--------------------------------------------------------------------------------
-- Slash commands
--------------------------------------------------------------------------------

local function Status()
	msg(string.format(
		"%s - %s, alpha x%.2f, speed x%.2f, sound %s%s, thunder %s, indoors %s (channel %s)%s",
		db.enabled and "|cff66ff66on|r" or "|cffff6666off|r",
		db.intensity, db.scale, db.speed,
		db.sound and "on" or "off",
		bedFallback and " |cffff9900(bundled audio)|r" or "",
		db.thunder and "on" or "off",
		db.indoors and "on" or "off",
		db.channel,
		indoorsNow and " |cff888888[indoors]|r" or ""))
end

local function Help()
	msg("commands:")
	print("  |cffffd100/rain|r - toggle on/off")
	print("  |cffffd100/rain light|normal|heavy|monsoon|r - intensity")
	print("  |cffffd100/rain alpha <0-1.5>|r - how visible it is")
	print("  |cffffd100/rain speed <0.2-3>|r - how fast it falls")
	print("  |cffffd100/rain indoors on|off|r - rain inside buildings too")
	print("  |cffffd100/rain sound on|off|r, |cffffd100/rain thunder on|off|r")
	print("  |cffffd100/rain channel Ambience|SFX|Master|r - which volume slider owns it")
	print("  |cffffd100/rain status|r")
end

local function HandleSlash(input)
	input = (input or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	local cmd, arg = input:match("^(%S*)%s*(.-)$")

	if cmd == "" then
		db.enabled = not db.enabled
	elseif PRESETS[cmd] then
		db.intensity, db.enabled = cmd, true
		ScheduleLightning()
	elseif cmd == "on" or cmd == "off" then
		db.enabled = (cmd == "on")
	elseif cmd == "alpha" then
		local v = tonumber(arg)
		if not v then msg("usage: /rain alpha 0.75") return end
		db.scale = math.max(0, math.min(1.5, v))
	elseif cmd == "speed" then
		local v = tonumber(arg)
		if not v then msg("usage: /rain speed 1.4") return end
		db.speed = math.max(0.2, math.min(3, v))
	elseif cmd == "sound" then
		db.sound = (arg ~= "off")
	elseif cmd == "thunder" then
		db.thunder = (arg ~= "off")
		ScheduleLightning()
	elseif cmd == "indoors" then
		db.indoors = (arg == "on")
	elseif cmd == "channel" then
		local valid = { ambience = "Ambience", sfx = "SFX", master = "Master",
		                music = "Music", dialog = "Dialog" }
		local c = valid[arg]
		if not c then msg("channel must be Ambience, SFX, Master, Music or Dialog") return end
		db.channel = c
		StartBed()
	elseif cmd == "cycle" then
		local i = 1
		for n, name in ipairs(PRESET_ORDER) do
			if name == db.intensity then i = n end
		end
		db.intensity, db.enabled = PRESET_ORDER[(i % #PRESET_ORDER) + 1], true
	elseif cmd == "status" then
		Status()
		return
	else
		Help()
		return
	end

	Refresh()
	Status()
end

--------------------------------------------------------------------------------
-- Boot
--------------------------------------------------------------------------------

local boot = CreateFrame("Frame")
for _, e in ipairs({ "ADDON_LOADED", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED",
                     "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA",
                     "CINEMATIC_START", "CINEMATIC_STOP", "PLAY_MOVIE", "STOP_MOVIE" }) do
	boot:RegisterEvent(e)
end

boot:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 ~= ADDON then return end
		AlwaysRainDB = AlwaysRainDB or {}
		db = AlwaysRainDB
		for k, v in pairs(DEFAULTS) do
			if db[k] == nil then db[k] = v end
		end
		BuildOverlay()

		SLASH_ALWAYSRAIN1 = "/rain"
		SLASH_ALWAYSRAIN2 = "/alwaysrain"
		SlashCmdList.ALWAYSRAIN = HandleSlash
		msg("loaded. |cffffd100/rain|r to toggle, |cffffd100/rain help|r for the rest.")

	elseif event == "CINEMATIC_START" or event == "PLAY_MOVIE" then
		cinematic = true
		Refresh()
	elseif event == "CINEMATIC_STOP" or event == "STOP_MOVIE" then
		cinematic = false
		Refresh()
	else
		if not db then return end
		indoorsNow = IsIndoors() and true or false
		indoorsSince = nil
		Refresh()
	end
end)

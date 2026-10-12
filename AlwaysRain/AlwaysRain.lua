-- AlwaysRain
--
-- The client cannot be told to make it rain: C_Weather only reads, ApplyWeather
-- belongs to server-driven scene scripts, and there is no weather console command.
-- So this draws the rain itself, on a frame between the 3D world and the UI, and
-- loops its own rain bed through the Ambience channel.

local ADDON = "AlwaysRain"
local MEDIA = "Interface\\AddOns\\AlwaysRain\\"

-- Must match make_rain_tga.py (SLANT) and make_rain_audio.sh (DUR, FADE).
local SLANT       = 0.14
local RAIN_LEN    = 24.0
local RAIN_OVERLAP = 0.35

local PRESETS = {
	light   = { mist = 0.04, far = 0.30, near = 0.28, density = 1.35, speed = 0.80 },
	normal  = { mist = 0.08, far = 0.55, near = 0.55, density = 1.00, speed = 1.00 },
	heavy   = { mist = 0.14, far = 0.80, near = 0.85, density = 0.80, speed = 1.25 },
	monsoon = { mist = 0.22, far = 1.00, near = 1.00, density = 0.62, speed = 1.60 },
}
local PRESET_ORDER = { "light", "normal", "heavy", "monsoon" }

local DEFAULTS = {
	enabled   = true,
	intensity = "normal",
	scale     = 1.0,   -- multiplies every layer's alpha, 0-1.5
	speed     = 1.0,   -- multiplies fall speed
	sound     = true,
	thunder   = true,
	channel   = "Ambience",
}

-- Per-layer geometry. tilesY is how many copies of the 256px texture fit
-- vertically; tilesX is derived from the screen aspect so drops stay round.
local LAYERS = {
	{ key = "far",  file = MEDIA .. "rain-far.tga",  tilesY = 3.0, speed = 1.05, blend = "BLEND" },
	{ key = "near", file = MEDIA .. "rain-near.tga", tilesY = 1.5, speed = 2.30, blend = "ADD"   },
}

local db
local overlay, mist, flash
local textures = {}
local offsets  = {}
local soundHandles = {}
local rainTicker
local suppressed = false   -- cinematic / movie playing
local warnedNoSound = false

local function msg(text)
	print("|cff7fb8ff" .. ADDON .. "|r: " .. text)
end

--------------------------------------------------------------------------------
-- Visuals
--------------------------------------------------------------------------------

local function CurrentPreset()
	return PRESETS[db.intensity] or PRESETS.normal
end

local function ApplyAlphas()
	local p = CurrentPreset()
	local s = db.scale
	mist:SetAlpha(math.min(p.mist * s, 0.6))
	textures.far:SetAlpha(math.min(p.far * s, 1))
	textures.near:SetAlpha(math.min(p.near * s, 1))
end

local function OnUpdate(self, elapsed)
	if suppressed then return end
	local w, h = self:GetWidth(), self:GetHeight()
	if not w or w <= 0 or not h or h <= 0 then return end

	local aspect = w / h
	local p = CurrentPreset()
	local rate = p.speed * db.speed

	for _, layer in ipairs(LAYERS) do
		local tilesY = layer.tilesY * p.density
		local tilesX = tilesY * aspect
		local o = offsets[layer.key]
		local dy = layer.speed * rate * elapsed
		-- Sampling window moves up the texture so the image falls down the screen.
		o.y = (o.y - dy) % 1
		o.x = (o.x - dy * SLANT) % 1
		textures[layer.key]:SetTexCoord(o.x, o.x + tilesX, o.y, o.y + tilesY)
	end
end

local function BuildOverlay()
	-- Parented to WorldFrame, not UIParent: the rain then sits above the 3D scene
	-- but below every UI frame, and survives Alt+Z so screenshots still have it.
	overlay = CreateFrame("Frame", "AlwaysRainOverlay", WorldFrame)
	overlay:SetAllPoints(WorldFrame)
	overlay:SetFrameStrata("BACKGROUND")
	overlay:EnableMouse(false)
	overlay:SetToplevel(false)

	mist = overlay:CreateTexture(nil, "BACKGROUND")
	mist:SetAllPoints(overlay)
	mist:SetColorTexture(0.58, 0.63, 0.71, 1)
	mist:SetBlendMode("BLEND")

	for i, layer in ipairs(LAYERS) do
		local tex = overlay:CreateTexture(nil, "ARTWORK", nil, i)
		tex:SetAllPoints(overlay)
		tex:SetTexture(layer.file, "REPEAT", "REPEAT")
		tex:SetBlendMode(layer.blend)
		textures[layer.key] = tex
		offsets[layer.key] = { x = math.random(), y = math.random() }
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

local function PlayRainClip()
	if not db.enabled or not db.sound or suppressed then return end
	local ok, handle = PlaySoundFile(MEDIA .. "rain.ogg", db.channel)
	if ok then
		soundHandles[#soundHandles + 1] = handle
		-- Keep only the clip that is still fading out plus the one just started.
		while #soundHandles > 2 do table.remove(soundHandles, 1) end
	elseif not warnedNoSound then
		warnedNoSound = true
		msg("could not play rain.ogg - check the file is in the addon folder.")
	end
end

local function StopRain()
	for _, handle in ipairs(soundHandles) do
		if handle then StopSound(handle) end
	end
	wipe(soundHandles)
	if rainTicker then rainTicker:Cancel() rainTicker = nil end
end

local function StartRain()
	StopRain()
	if not db.enabled or not db.sound then return end
	PlayRainClip()
	rainTicker = C_Timer.NewTicker(RAIN_LEN - RAIN_OVERLAP, PlayRainClip)
end

--------------------------------------------------------------------------------
-- Lightning
--------------------------------------------------------------------------------

local lightningTimer

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
		-- fast attack, slower decay
		local a = (t < 0.18) and (t / 0.18) or (1 - (t - 0.18) / 0.82)
		flash:SetAlpha(peak * a * a)
	end)
end

local function Strike()
	if not db.enabled or not db.thunder or suppressed then
		return
	end
	local p = CurrentPreset()
	local peak = 0.16 + p.mist * 1.6
	FlashOnce(peak, 0.22)
	if math.random() < 0.45 then
		C_Timer.After(0.26, function() FlashOnce(peak * 0.7, 0.18) end)
	end
	-- Thunder trails the flash the way distance makes it.
	C_Timer.After(0.6 + math.random() * 2.6, function()
		if db.enabled and db.thunder and db.sound and not suppressed then
			PlaySoundFile(MEDIA .. "thunder.ogg", db.channel)
		end
	end)
end

local function ScheduleLightning()
	if lightningTimer then lightningTimer:Cancel() lightningTimer = nil end
	if not db.enabled or not db.thunder then return end
	local p = CurrentPreset()
	-- heavier weather, more frequent strikes
	local base = 70 - (p.speed - 0.8) * 28
	local wait = base * (0.55 + math.random() * 0.9)
	lightningTimer = C_Timer.NewTimer(wait, function()
		Strike()
		ScheduleLightning()
	end)
end

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local function Refresh()
	if not overlay then return end
	local show = db.enabled and not suppressed
	overlay:SetShown(show)
	ApplyAlphas()
	if show and db.sound then
		if not rainTicker then StartRain() end
	else
		StopRain()
	end
	if show and db.thunder then
		if not lightningTimer then ScheduleLightning() end
	elseif lightningTimer then
		lightningTimer:Cancel()
		lightningTimer = nil
	end
end

local function SetSuppressed(state)
	if suppressed == state then return end
	suppressed = state
	Refresh()
end

--------------------------------------------------------------------------------
-- Slash commands
--------------------------------------------------------------------------------

local function Status()
	msg(string.format(
		"%s - %s, alpha x%.2f, speed x%.2f, sound %s, thunder %s (channel %s)",
		db.enabled and "|cff66ff66on|r" or "|cffff6666off|r",
		db.intensity, db.scale, db.speed,
		db.sound and "on" or "off",
		db.thunder and "on" or "off",
		db.channel))
end

local function Help()
	msg("commands:")
	print("  |cffffd100/rain|r - toggle on/off")
	print("  |cffffd100/rain light|normal|heavy|monsoon|r - intensity preset")
	print("  |cffffd100/rain alpha <0-1.5>|r - how visible the rain is")
	print("  |cffffd100/rain speed <0.2-3>|r - how fast it falls")
	print("  |cffffd100/rain sound on|off|r, |cffffd100/rain thunder on|off|r")
	print("  |cffffd100/rain channel Ambience|SFX|Master|r - which volume slider owns it")
	print("  |cffffd100/rain status|r")
end

local function HandleSlash(input)
	input = (input or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	local cmd, arg = input:match("^(%S*)%s*(.-)$")

	if cmd == "" then
		db.enabled = not db.enabled
		Refresh()
		Status()
	elseif PRESETS[cmd] then
		db.intensity = cmd
		db.enabled = true
		Refresh()
		ScheduleLightning()
		Status()
	elseif cmd == "on" or cmd == "off" then
		db.enabled = (cmd == "on")
		Refresh()
		Status()
	elseif cmd == "alpha" then
		local v = tonumber(arg)
		if not v then msg("usage: /rain alpha 0.75") return end
		db.scale = math.max(0, math.min(1.5, v))
		ApplyAlphas()
		Status()
	elseif cmd == "speed" then
		local v = tonumber(arg)
		if not v then msg("usage: /rain speed 1.4") return end
		db.speed = math.max(0.2, math.min(3, v))
		Status()
	elseif cmd == "sound" then
		db.sound = (arg ~= "off")
		Refresh()
		Status()
	elseif cmd == "thunder" then
		db.thunder = (arg ~= "off")
		Refresh()
		ScheduleLightning()
		Status()
	elseif cmd == "channel" then
		local valid = { ambience = "Ambience", sfx = "SFX", master = "Master", music = "Music", dialog = "Dialog" }
		local c = valid[arg]
		if not c then msg("channel must be Ambience, SFX, Master, Music or Dialog") return end
		db.channel = c
		StartRain()
		Status()
	elseif cmd == "cycle" then
		local i = 1
		for n, name in ipairs(PRESET_ORDER) do
			if name == db.intensity then i = n end
		end
		db.intensity = PRESET_ORDER[(i % #PRESET_ORDER) + 1]
		db.enabled = true
		Refresh()
		Status()
	elseif cmd == "status" then
		Status()
	else
		Help()
	end
end

--------------------------------------------------------------------------------
-- Boot
--------------------------------------------------------------------------------

local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:RegisterEvent("PLAYER_ENTERING_WORLD")
boot:RegisterEvent("CINEMATIC_START")
boot:RegisterEvent("CINEMATIC_STOP")
boot:RegisterEvent("PLAY_MOVIE")
boot:RegisterEvent("STOP_MOVIE")

boot:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" and arg1 == ADDON then
		AlwaysRainDB = AlwaysRainDB or {}
		db = AlwaysRainDB
		for k, v in pairs(DEFAULTS) do
			if db[k] == nil then db[k] = v end
		end
		BuildOverlay()
		Refresh()
		ScheduleLightning()

		SLASH_ALWAYSRAIN1 = "/rain"
		SLASH_ALWAYSRAIN2 = "/alwaysrain"
		SlashCmdList.ALWAYSRAIN = HandleSlash

		msg("loaded. |cffffd100/rain|r to toggle, |cffffd100/rain help|r for the rest.")
	elseif event == "PLAYER_ENTERING_WORLD" then
		SetSuppressed(false)
		Refresh()
	elseif event == "CINEMATIC_START" or event == "PLAY_MOVIE" then
		SetSuppressed(true)
	elseif event == "CINEMATIC_STOP" or event == "STOP_MOVIE" then
		SetSuppressed(false)
	end
end)

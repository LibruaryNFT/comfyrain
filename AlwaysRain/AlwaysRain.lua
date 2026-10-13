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
	light   = { mist = 0.05, far = 0.40, near = 0.35, density = 1.35, speed = 0.80, gloom = 0.10 },
	normal  = { mist = 0.10, far = 0.70, near = 0.65, density = 1.00, speed = 1.00, gloom = 0.20 },
	heavy   = { mist = 0.17, far = 0.95, near = 0.90, density = 0.78, speed = 1.25, gloom = 0.32 },
	monsoon = { mist = 0.26, far = 1.00, near = 1.00, density = 0.58, speed = 1.60, gloom = 0.45 },
}

-- Real weather darkens and cools the whole scene, because the client swaps in the
-- weather's own fog and light parameters. An addon cannot touch world lighting -
-- SetFogColor and SetLight belong to the Model widget, not the world - so this
-- multiplies the finished frame by a blue-grey instead. It is the cheat that makes
-- the overlay read as weather rather than as drops stuck to the lens.
local GLOOM_TINT = { 0.55, 0.62, 0.78 }

-- Yaw parallax. Turning the camera should sweep the curtain sideways; without it
-- the sheet slides at one fixed rate no matter what the camera does, which is the
-- single biggest tell that this is a 2D overlay. Approximated from player facing
-- (no camera-yaw API is exposed) over roughly the horizontal field of view.
local FOV_H = math.pi * 0.52
local PARALLAX = { mist = 0.25, far = 0.9, near = 1.0 }
local PRESET_ORDER = { "light", "normal", "heavy", "monsoon" }

-- Time of day. WoW's day/night runs on the realm's clock, so anyone playing far
-- from their realm gets night at lunchtime. This grades the screen towards the
-- hour the player would rather it were. How the world looks at each hour, as a
-- light multiplier where 1 is full daylight; interpolated between keyframes.
local LIGHT = {
	{  0, 0.30, 0.36, 0.62 },   -- deep night, moonlit blue
	{  3, 0.28, 0.34, 0.60 },
	{  5, 0.52, 0.50, 0.62 },   -- first light
	{  6, 0.88, 0.70, 0.58 },   -- dawn, warm
	{  7, 0.98, 0.92, 0.88 },
	{  8, 1.00, 1.00, 1.00 },   -- full day
	{ 17, 1.00, 1.00, 1.00 },
	{ 18, 0.98, 0.88, 0.76 },
	{ 19, 1.00, 0.74, 0.55 },   -- sunset
	{ 20, 0.60, 0.56, 0.70 },   -- dusk
	{ 22, 0.34, 0.40, 0.66 },
	{ 24, 0.30, 0.36, 0.62 },   -- wraps onto the first entry
}
-- Lifting a night scene towards day barely works: ADD can raise the black level
-- but cannot restore contrast, and the skybox keeps its stars and its missing
-- sun either way. Capped low so it never turns the screen into milk.
local LIFT_CAP = 0.13

local DEFAULTS = {
	enabled   = true,
	intensity = "normal",
	scale     = 1.0,       -- multiplies every layer's alpha
	speed     = 1.0,       -- multiplies fall speed
	gloom     = 1.0,       -- multiplies the darkening; 0 disables it
	sound     = true,
	thunder   = true,
	indoors   = false,     -- rain indoors too
	channel   = "Ambience",
	timeMode  = "off",     -- off | local | offset | fixed
	timeOffset = 0,        -- hours from realm time, for "offset"
	timeFixed = 21,        -- the hour to hold at, for "fixed"
	timeStrength = 1.0,
}

-- tilesY is how many copies of the 512px sheet fit vertically; tilesX is derived
-- from the screen aspect each frame so drops stay the right shape at any size.
local LAYERS = {
	{ key = "mist", tilesY = 1.1, speed = 0.09, blend = "BLEND", layer = "BACKGROUND" },
	{ key = "far",  tilesY = 3.0, speed = 1.05, blend = "BLEND", layer = "ARTWORK"    },
	{ key = "near", tilesY = 1.5, speed = 2.30, blend = "ADD",   layer = "ARTWORK"    },
}

local db
local overlay, flash, gloom
local tod, todDim, todLift, todTicker
local textures, offsets = {}, {}
local lastFacing, turnDelta, runSpeed = nil, 0, 0
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

--------------------------------------------------------------------------------
-- Time of day
--------------------------------------------------------------------------------

local function LightAt(hour)
	hour = hour % 24
	for i = 1, #LIGHT - 1 do
		local a, b = LIGHT[i], LIGHT[i + 1]
		if hour >= a[1] and hour <= b[1] then
			local t = (hour - a[1]) / (b[1] - a[1])
			return a[2] + (b[2] - a[2]) * t,
			       a[3] + (b[3] - a[3]) * t,
			       a[4] + (b[4] - a[4]) * t
		end
	end
	return 1, 1, 1
end

-- The realm clock, which is what the world is actually lit by.
local function RealmHour()
	local h, m = GetGameTime()
	if not h then return nil end
	return h + (m or 0) / 60
end

local function ClockHour()
	local t = date("*t")
	return t.hour + t.min / 60
end

-- The hour the player wants it to look like.
local function ApparentHour()
	if db.timeMode == "local" then return ClockHour() end
	if db.timeMode == "fixed" then return db.timeFixed end
	local r = RealmHour()
	return r and (r + db.timeOffset) or nil
end

local function UpdateTimeOfDay()
	if not tod then return end
	if db.timeMode == "off" or cinematic then tod:Hide() return end

	local realm = RealmHour()
	local want = ApparentHour()
	if not realm or not want then tod:Hide() return end

	-- Grade by the ratio between the two, not by the target alone: the world is
	-- already lit for the realm's hour, so at realm 22:00 wanting 22:00 there is
	-- nothing to do. Without this it would double-darken every night.
	local wr, wg, wb = LightAt(want)
	local rr, rg, rb = LightAt(realm)
	local s = db.timeStrength

	local function channel(target, actual)
		local ratio = target / math.max(actual, 0.05)
		return 1 + (ratio - 1) * s
	end
	local mr, mg, mb = channel(wr, rr), channel(wg, rg), channel(wb, rb)

	tod:Show()
	-- Anything below 1 is a darkening and multiplies cleanly.
	todDim:SetColorTexture(math.min(mr, 1), math.min(mg, 1), math.min(mb, 1), 1)
	-- Anything above it has to be added, which is the weak direction.
	local lift = math.max(mr, mg, mb) - 1
	todLift:SetAlpha(math.min(math.max(lift, 0) * 0.09, LIFT_CAP))
end

-- A fullscreen curtain runs right down over the player's feet and the action
-- bars, which is the giveaway that it is pasted on the lens. Fading the bottom
-- of each rain layer out gives the drops somewhere to land.
local function HorizonFade(tex)
	local function colour(r, g, b, a)
		if CreateColor then return CreateColor(r, g, b, a) end
		return { r = r, g = g, b = b, a = a,
		         GetRGBA = function(s) return s.r, s.g, s.b, s.a end }
	end
	-- VERTICAL puts the first colour at the bottom. pcall because the colour
	-- object shape has moved around between clients and a failure here should
	-- cost the fade, not the addon.
	pcall(tex.SetGradient, tex, "VERTICAL", colour(1, 1, 1, 0.12), colour(1, 1, 1, 1))
end

local function ApplyAlphas()
	local p, s = Preset(), db.scale
	textures.mist:SetAlpha(math.min(p.mist * s, 0.6))
	textures.far:SetAlpha(math.min(p.far * s, 1))
	textures.near:SetAlpha(math.min(p.near * s, 1))

	-- MOD multiplies the frame by this colour, so strength lives in the colour
	-- itself: 1 is untouched, and we lerp towards the tint from there.
	local g = math.min(p.gloom * db.gloom, 0.75)
	gloom:SetColorTexture(
		1 - g * (1 - GLOOM_TINT[1]),
		1 - g * (1 - GLOOM_TINT[2]),
		1 - g * (1 - GLOOM_TINT[3]), 1)
end

-- A value this client will let us do arithmetic on, or nil. Secret values are
-- non-nil and look ordinary until you touch them, so every restricted getter has
-- to come through here.
local function Readable(v)
	if v == nil then return nil end
	if canaccessvalue and not canaccessvalue(v) then return nil end
	return v
end

-- What Blizzard's own weather system thinks is happening here. C_Weather is a
-- read-only namespace (Enum.WeatherType is Rain / Snow / Sandstorm plus an
-- intensity), so it cannot make it rain - but it tells us when the client is
-- already drawing real rain, which is worth knowing before we draw ours on top.
local WEATHER_NAME = { [0] = "none", "rain", "snow", "sandstorm" }

local function RealWeather()
	if not C_Weather or not C_Weather.GetCurrentWeather then return nil end
	local ok, info = pcall(C_Weather.GetCurrentWeather)
	if not ok or type(info) ~= "table" then return nil end
	local t = info.weatherType or info.type or 0
	return WEATHER_NAME[t] or tostring(t), info.intensity or 0
end

-- The client will not draw Blizzard's weather at all unless these two are up.
-- weatherDensity 0 means "never", and environment detail 1 culls it as well.
local DENSITY_CVARS = { weatherDensity = 3, graphicsEnvironmentDetail = 2 }

local function DensityReport()
	for cvar in pairs(DENSITY_CVARS) do
		local v = tonumber(GetCVar(cvar) or "")
		if v then
			msg(string.format("%s = %s%d|r", cvar,
				(cvar == "weatherDensity" and v == 0) and "|cffff6666" or "|cff66ff66", v))
		end
	end
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

	-- How far the camera turned this frame, as a fraction of the screen width.
	-- This is a Forever client (the binary identifies itself as wow-forever-client)
	-- and it carries Midnight's secret-value machinery: canaccessvalue,
	-- issecurevariable and a SecretValue type are all present. GetPlayerFacing is
	-- one of the values Blizzard restricts in encounters, and a secret value throws
	-- when you do arithmetic on it, so a plain `if facing then` is not enough - it
	-- is non-nil and still unusable. Freeze the parallax rather than error.
	local facing = Readable(GetPlayerFacing())
	local swing = 0
	if facing then
		if lastFacing then
			local d = facing - lastFacing
			if d > math.pi then d = d - 2 * math.pi
			elseif d < -math.pi then d = d + 2 * math.pi end
			-- Smoothed, or a stutter in facing shows up as a jolt in the rain.
			turnDelta = turnDelta + (d - turnDelta) * math.min(1, elapsed * 12)
			swing = turnDelta / FOV_H
		end
		lastFacing = facing
	end

	-- Running into rain makes it appear to fall faster and harder. Smoothed, so
	-- mounting or dismounting does not snap the whole field to a new speed.
	local spd = Readable(GetUnitSpeed("player")) or 0
	runSpeed = runSpeed + (math.min(spd / 7, 2.2) - runSpeed) * math.min(1, elapsed * 3)

	local aspect = w / h
	local rate = Preset().speed * db.speed * (1 + runSpeed * 0.3)
	local density = Preset().density

	for _, l in ipairs(LAYERS) do
		local tilesY = l.tilesY * (l.key == "mist" and 1 or density)
		local tilesX = tilesY * aspect
		local o = offsets[l.key]
		local dy = l.speed * rate * elapsed
		-- The sampling window moves up the sheet so the image falls down the screen.
		o.y = (o.y - dy) % 1
		-- Slant drift, plus the camera swing scaled into this layer's tiling so
		-- every layer sweeps the same distance across the screen.
		o.x = (o.x - dy * SLANT + swing * PARALLAX[l.key] * tilesX) % 1
		textures[l.key]:SetTexCoord(o.x, o.x + tilesX, o.y, o.y + tilesY)
	end
end

local function BuildOverlay()
	-- Parented to WorldFrame, not UIParent: the rain sits above the 3D scene but
	-- below every UI frame, and survives Alt+Z so screenshots keep it.
	-- The time grade is its own frame, underneath the rain, because it has to be
	-- usable on its own: wanting your realm's night to match your own clock has
	-- nothing to do with wanting rain.
	tod = CreateFrame("Frame", "AlwaysRainTimeOfDay", WorldFrame)
	tod:SetAllPoints(WorldFrame)
	tod:SetFrameStrata("BACKGROUND")
	tod:SetFrameLevel(1)
	tod:EnableMouse(false)
	tod:Hide()

	todDim = tod:CreateTexture(nil, "BACKGROUND", nil, 0)
	todDim:SetAllPoints(tod)
	todDim:SetBlendMode("MOD")

	todLift = tod:CreateTexture(nil, "BACKGROUND", nil, 1)
	todLift:SetAllPoints(tod)
	todLift:SetColorTexture(1, 0.97, 0.90, 1)
	todLift:SetBlendMode("ADD")
	todLift:SetAlpha(0)

	overlay = CreateFrame("Frame", "AlwaysRainOverlay", WorldFrame)
	overlay:SetAllPoints(WorldFrame)
	overlay:SetFrameStrata("BACKGROUND")
	overlay:SetFrameLevel(5)
	overlay:EnableMouse(false)

	-- Drawn first and multiplied, so everything behind it dims; the rain and the
	-- lightning flash are added on top of the already-darkened frame.
	gloom = overlay:CreateTexture(nil, "BACKGROUND", nil, 0)
	gloom:SetAllPoints(overlay)
	gloom:SetBlendMode("MOD")

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
		if l.key == "mist" then
			tex:SetVertexColor(0.58, 0.64, 0.74)
		else
			HorizonFade(tex)
		end
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

	-- Game time moves slowly; a third of a minute is finer than the eye needs.
	UpdateTimeOfDay()
	todTicker = C_Timer.NewTicker(20, UpdateTimeOfDay)
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
	UpdateTimeOfDay()
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
	if db.timeMode ~= "off" then
		local realm, want = RealmHour(), ApparentHour()
		msg(string.format("time: |cff66ff66%s|r - realm reads %s, showing it as %s"
			.. (db.timeStrength < 1 and (", strength %.2f"):format(db.timeStrength) or ""),
			db.timeMode == "offset" and ("offset %+g h"):format(db.timeOffset) or db.timeMode,
			realm and ("%02d:%02d"):format(realm, (realm % 1) * 60) or "?",
			want and ("%02d:%02d"):format(want % 24, (want % 1) * 60) or "?"))
	end
	msg(string.format(
		"%s - %s, alpha x%.2f, speed x%.2f, gloom x%.2f, sound %s%s, thunder %s, indoors %s (channel %s)%s",
		db.enabled and "|cff66ff66on|r" or "|cffff6666off|r",
		db.intensity, db.scale, db.speed, db.gloom,
		db.sound and "on" or "off",
		bedFallback and " |cffff9900(bundled audio)|r" or "",
		db.thunder and "on" or "off",
		db.indoors and "on" or "off",
		db.channel,
		indoorsNow and " |cff888888[indoors]|r" or ""))
	local real, grade = RealWeather()
	if real and real ~= "none" then
		msg(string.format("the realm's own weather here is |cff66ff66%s|r at %.2f", real, grade))
	end
end

local function Help()
	msg("commands:")
	print("  |cffffd100/rain|r - toggle on/off")
	print("  |cffffd100/rain light|normal|heavy|monsoon|r - intensity")
	print("  |cffffd100/rain alpha <0-1.5>|r - how visible it is")
	print("  |cffffd100/rain speed <0.2-3>|r - how fast it falls")
	print("  |cffffd100/rain gloom <0-2>|r - how much it darkens the world (0 = off)")
	print("  |cffffd100/rain time local|r - make it look like YOUR clock, not the realm's")
	print("  |cffffd100/rain time +9|r, |cffffd100/rain time 21|r, |cffffd100/rain time off|r")
	print("  |cffffd100/rain indoors on|off|r - rain inside buildings too")
	print("  |cffffd100/rain sound on|off|r, |cffffd100/rain thunder on|off|r")
	print("  |cffffd100/rain channel Ambience|SFX|Master|r - which volume slider owns it")
	print("  |cffffd100/rain density|r - is the client even allowed to draw real weather?")
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
	elseif cmd == "time" then
		local sub, rest = arg:match("^(%S*)%s*(.-)$")
		if sub == "off" or sub == "" then
			db.timeMode = "off"
		elseif sub == "local" then
			db.timeMode = "local"
		elseif sub == "strength" then
			local v = tonumber(rest)
			if not v then msg("usage: /rain time strength 0.7") return end
			db.timeStrength = math.max(0, math.min(1, v))
		elseif sub:match("^[+-]%d+%.?%d*$") then
			db.timeMode, db.timeOffset = "offset", tonumber(sub)
		elseif tonumber(sub) then
			db.timeMode, db.timeFixed = "fixed", tonumber(sub) % 24
		else
			msg("usage: |cffffd100/rain time local|r (match your own clock), " ..
			    "|cffffd100+9|r / |cffffd100-5|r (shift by hours), " ..
			    "|cffffd10021|r (hold one hour), |cffffd100off|r, " ..
			    "|cffffd100strength 0.7|r")
			return
		end
		UpdateTimeOfDay()
	elseif cmd == "gloom" then
		local v = tonumber(arg)
		if not v then msg("usage: /rain gloom 0.5  (0 turns the darkening off)") return end
		db.gloom = math.max(0, math.min(2, v))
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
	elseif cmd == "density" then
		-- Not touched automatically: these are the player's graphics settings,
		-- and raising them turns on Blizzard's real weather everywhere, not ours.
		if arg == "" then
			DensityReport()
			msg("|cffffd100/rain density on|r raises both so the realm's own weather renders")
			return
		end
		for cvar, want in pairs(DENSITY_CVARS) do
			if arg == "off" then
				SetCVar(cvar, cvar == "weatherDensity" and 0 or 1)
			else
				SetCVar(cvar, want)
			end
		end
		DensityReport()
		return
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

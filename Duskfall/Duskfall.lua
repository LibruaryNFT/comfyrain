-- Duskfall 2.0
--
-- The client cannot be told to make it rain: C_Weather only reads, ApplyWeather
-- belongs to server-driven scene scripts, and there is no weather console command.
-- So this draws the rain itself, on a frame between the 3D world and the UI.
--
-- Everything audible, and the drop sprite the textures are built from, is
-- Blizzard's own: the weather ambience loops the client already ships, played by
-- FileDataID. Only the tiling of the drops is ours, because the particle system
-- that would normally place them is not reachable from an addon.

local ADDON = "Duskfall"
local MEDIA = "Interface\\AddOns\\Duskfall\\"

local BED_OVERLAP = 0.12      -- seconds of overlap when relooping the bed

-- Blizzard weather ambience, Sound/ambience/Weather/*. Durations measured from
-- the shipped files; they are exact, so the loop never gaps or doubles.
-- Snow beds verified the same way as the rain ones, against the same listfile,
-- with a known rain ID pulled first as the control. Note SnowLight is 29.951 s
-- and not 30: rounding it would gap the loop by 49 ms, every 30 seconds.
--
--   538983 RainLightLoop   20.000 s    538985 SnowLight    29.951 s
--   538981 RainMediumLoop  30.000 s    538989 SnowMedium   50.000 s
--   538982 RainHeavyLoop   25.000 s    538984 SnowHeavy    40.000 s
--   918050 AMB_FrostFire_Heavy_Wind_base_loop  110.713 s
--
-- The beds get louder as they get heavier, by 16 dB across the rain set and
-- 10 dB across the snow set. That is Blizzard's own mix and it is left alone:
-- flattening it would make a monsoon sound like drizzle.

-- Sound/DOODAD/FX_TKIsle_MWThunderRumble01-10.ogg - real recorded thunder.
local THUNDER = { 838830, 838832, 838834, 839725, 839727, 839729, 839731, 839733, 839735, 839737 }
-- sound/ambience/zoneambience/FX_WindGust_OneShot_01-07.ogg. Snow's answer to
-- thunder: a snowstorm has no lightning, it has gusts.
local GUSTS = { 982361, 982363, 982365, 982367, 982369, 982371, 982373 }

local MIST_TEXTURE = 396498   -- Textures/WEATHER/WeatherMistGrainy01.blp
local SNOWMIST_TEXTURE = 186229   -- Textures/WEATHER/SNOWMIST01.BLP

-- Everything that differs between falling water and falling ice.
--
-- They are not the same effect with a different sprite. Rain falls at about
-- 9 m/s and smears into streaks; snow falls at about 1, tumbles, and drifts
-- sideways on any breeze at all, so it needs a sway term rain does not have.
-- Rain darkens the scene. Heavy snow does too, but a blizzard does the
-- opposite: it is a whiteout, and the only way a 2D overlay can brighten the
-- world is an ADD quad, so blizzard is the one preset that uses one.
local WEATHER = {
	rain = {
		label   = "rain",
		order   = { "light", "normal", "heavy", "monsoon" },
		mist    = MIST_TEXTURE,
		mistTint = { 0.58, 0.64, 0.74 },
		far     = MEDIA .. "rain-far.tga",
		near    = MEDIA .. "rain-near.tga",
		-- tan(7.5 deg); must match SLANT_DEG in make_rain_tga.py
		slant   = 0.1317,
		sway    = 0,            -- rain is too heavy to be pushed about
		swayRate = 0,
		-- Real weather darkens and cools the whole scene, because the client
		-- swaps in the weather's own fog and light. An addon cannot touch world
		-- lighting, so this multiplies the finished frame by a blue-grey
		-- instead. It is the cheat that makes the overlay read as weather
		-- rather than as drops stuck to the lens.
		tint    = { 0.55, 0.62, 0.78 },
		flash   = true,         -- lightning
		oneShots = THUNDER,
		fallbackOneShot = MEDIA .. "thunder.ogg",
		fallbackBed = { file = MEDIA .. "rain.ogg", len = 24.0 },
		presets = {
			light   = { mist = 0.05, far = 0.40, near = 0.35, density = 1.35, speed = 0.80, gloom = 0.10, bed = { id = 538983, len = 20.0 } },
			normal  = { mist = 0.10, far = 0.70, near = 0.65, density = 1.00, speed = 1.00, gloom = 0.20, bed = { id = 538981, len = 30.0 } },
			heavy   = { mist = 0.17, far = 0.95, near = 0.90, density = 0.78, speed = 1.25, gloom = 0.32, bed = { id = 538982, len = 25.0 } },
			monsoon = { mist = 0.26, far = 1.00, near = 1.00, density = 0.58, speed = 1.60, gloom = 0.45, bed = { id = 538982, len = 25.0 } },
		},
	},
	snow = {
		label   = "snow",
		order   = { "light", "normal", "heavy", "blizzard" },
		mist    = SNOWMIST_TEXTURE,
		mistTint = { 0.80, 0.84, 0.92 },
		far     = MEDIA .. "snow-far.tga",
		near    = MEDIA .. "snow-near.tga",
		slant   = 0.06,
		-- Sway is the whole reason snow reads as snow. Flakes have almost no
		-- terminal velocity to resist a breeze, so the field drifts one way and
		-- then the other over several seconds. Without it this is just slow rain.
		sway    = 0.22,
		swayRate = 0.055,       -- Hz; one full drift every ~18 s
		tint    = { 0.72, 0.78, 0.90 },
		flash   = false,        -- a snowstorm has no lightning
		oneShots = GUSTS,
		fallbackOneShot = nil,  -- nothing bundled; a missing gust costs nothing
		fallbackBed = { file = MEDIA .. "rain.ogg", len = 24.0 },
		presets = {
			light    = { mist = 0.06, far = 0.34, near = 0.30, density = 1.20, speed = 0.26, gloom = 0.06, bed = { id = 538985, len = 29.951 } },
			normal   = { mist = 0.12, far = 0.62, near = 0.58, density = 1.00, speed = 0.36, gloom = 0.14, bed = { id = 538989, len = 50.0 } },
			heavy    = { mist = 0.20, far = 0.88, near = 0.84, density = 0.82, speed = 0.52, gloom = 0.24, bed = { id = 538984, len = 40.0 } },
			blizzard = {
				mist = 0.30, far = 1.00, near = 1.00, density = 0.66, speed = 1.70, gloom = 0.12,
				bed = { id = 538984, len = 40.0 },
				-- The gale sheet replaces the near layer: wind-driven snow is
				-- near-horizontal streaks, which is a different sprite, not a
				-- faster scroll of the same one.
				near_texture = MEDIA .. "snow-gale.tga",
				slant = 1.9, sway = 0.5, swayRate = 0.12,
				-- A whiteout brightens. Capped hard: this is the one effect in
				-- the addon that can make the world harder to play in, and an
				-- addon that hides a mob is an addon that gets uninstalled.
				whiteout = 0.16,
				-- Wind over the snow bed. Two loops at once, which nothing else
				-- in the addon needs, because this is what a blizzard sounds like.
				wind = { id = 918050, len = 110.713 },
				gustEvery = 14,
			},
		},
	},
}

-- Yaw parallax. Turning the camera should sweep the curtain sideways; without it
-- the sheet slides at one fixed rate no matter what the camera does, which is the
-- single biggest tell that this is a 2D overlay. Approximated from player facing
-- (no camera-yaw API is exposed) over roughly the horizontal field of view.
local FOV_H = math.pi * 0.52
local PARALLAX = { mist = 0.25, far = 0.9, near = 1.0 }

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
	weather   = "rain",    -- rain | snow
	intensity = "normal",
	scale     = 1.0,       -- multiplies every layer's alpha
	speed     = 1.0,       -- multiplies fall speed
	gloom     = 1.0,       -- multiplies the darkening; 0 disables it
	sound     = true,
	thunder   = true,
	indoors   = false,     -- draw it indoors too
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
local overlay, flash, gloom, whiteout
local tod, todDim, todLift, todTicker
local textures, offsets = {}, {}
local lastFacing, turnDelta, runSpeed = nil, 0, 0
-- Two loop slots. A blizzard is a snow bed with a wind loop running under it,
-- and one slot would mean choosing between them when the point is the mix.
local bedSlot  = { handles = {} }
local windSlot = { handles = {} }
local bedFallback, loopedKey = false, nil
local lightningTimer
local appliedTextures
local drift = 0
local cinematic, indoorsNow, indoorsSince = false, false, nil
local fade, fadeTarget = 1, 1
local indoorTicker

local function msg(text)
	print("|cff7fb8ff" .. ADDON .. "|r: " .. text)
end

local function W()
	return WEATHER[db.weather] or WEATHER.rain
end

-- The bottom three intensities are shared; the top one is named for its own
-- weather, monsoon or blizzard. Someone at the top of one scale who switches
-- weather means the top of the other, not a silent drop to normal.
local function Preset()
	local w = W()
	local p = w.presets[db.intensity]
	if p then return p end
	if db.intensity == "monsoon" or db.intensity == "blizzard" then
		return w.presets[w.order[#w.order]]
	end
	return w.presets.normal
end

-- Keep db.intensity truthful after a weather change, so /dusk status and the
-- saved settings never name a preset this weather does not have.
local function NormaliseIntensity()
	if W().presets[db.intensity] then return end
	db.intensity = (db.intensity == "monsoon" or db.intensity == "blizzard")
		and W().order[#W().order] or "normal"
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

-- Point each layer at the sheet the current weather wants. Cheap, but not free,
-- so it is keyed and only actually runs when the weather or preset changed.
local function ApplyTextures()
	if not overlay then return end
	local w, p = W(), Preset()
	local key = db.weather .. "/" .. db.intensity
	if appliedTextures == key then return end
	appliedTextures = key

	-- A blizzard swaps the near layer for the gale sheet. Wind-driven snow is
	-- near-horizontal streaks, which is a different sprite and not the same one
	-- scrolled faster.
	local sources = { mist = w.mist, far = w.far, near = p.near_texture or w.near }
	for _, l in ipairs(LAYERS) do
		local tex = textures[l.key]
		if tex then
			tex:SetTexture(sources[l.key], "REPEAT", "REPEAT")
			if l.key == "mist" then
				tex:SetVertexColor(w.mistTint[1], w.mistTint[2], w.mistTint[3])
			end
		end
	end
end

local function ApplyAlphas()
	ApplyTextures()
	local w, p, s = W(), Preset(), db.scale
	textures.mist:SetAlpha(math.min(p.mist * s, 0.6))
	textures.far:SetAlpha(math.min(p.far * s, 1))
	textures.near:SetAlpha(math.min(p.near * s, 1))

	-- MOD multiplies the frame by this colour, so strength lives in the colour
	-- itself: 1 is untouched, and we lerp towards the tint from there.
	local g = math.min(p.gloom * db.gloom, 0.75)
	gloom:SetColorTexture(
		1 - g * (1 - w.tint[1]),
		1 - g * (1 - w.tint[2]),
		1 - g * (1 - w.tint[3]), 1)

	-- The whiteout is the opposite move and only a blizzard uses it: ADD is the
	-- only way a 2D overlay can brighten anything. Capped well below the point
	-- where it could hide a mob, because an addon that does that gets deleted.
	if whiteout then
		whiteout:SetAlpha(math.min((p.whiteout or 0) * s, 0.22))
	end
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

--------------------------------------------------------------------------------
-- Calibration
--------------------------------------------------------------------------------
--
-- Every visual default in this addon is a guess. weatherDensity has been 0 on
-- this machine since before the addon existed, so the client has never once
-- drawn Blizzard's real rain here and nothing below is calibrated against the
-- thing it imitates. The beta client goes away on 2026-10-21, and after that
-- there is nothing left to calibrate against, so this exists to make the one
-- session that matters a single command rather than a protocol.
--
-- Real weather is server-driven and intermittent. You cannot summon it, you can
-- only be ready when it arrives - hence a logger that shouts, rather than a
-- checklist.

local calibFrame
local calibOn = false

-- Blizzard's own weather line, which the engine prints to the console:
--
--   Weather changed to <type> intensity <0.00> recID <id>
--
-- Reading it off CONSOLE_MESSAGE is how keyboardturner's LibForecast sources
-- weather, and it is better than C_Weather for us on two counts: it carries a
-- raw numeric type and a record ID rather than a three-value enum, and it is
-- old engine plumbing, where C_Weather is a 12.1.5 retail addition we have only
-- proven the *strings* of in the Forever binary. Console messages are always
-- English, so the pattern needs no localisation.
local function ParseWeatherLine(line)
	if type(line) ~= "string" or not line:find("Weather changed to", 1, true) then return nil end
	return {
		type      = tonumber(line:match("changed to (%d+)")),
		intensity = tonumber(line:match("intensity ([%d%.]+)")),
		recordID  = tonumber(line:match("recID (%d+)")),
		raw       = line,
	}
end

-- One observation, with everything a screenshot would need to be interpretable
-- later. Written to SavedVariables *and* printed, because early Forever builds
-- wrote SavedVariables and never read them back; that is reportedly fixed, but
-- it is contested and a log that only exists in one of two places is not a log.
local function CalibRecord(source, parsed)
	local real, grade = RealWeather()
	local entry = {
		at       = time(),
		source   = source,
		uiMapID  = Readable(C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")),
		zone     = GetRealZoneText(),
		subzone  = GetSubZoneText(),
		gameTime = { GetGameTime() },
		indoors  = IsIndoors() and true or false,
		cWeather = real,
		cGrade   = grade,
		console  = parsed,
		density  = tonumber(GetCVar("weatherDensity") or ""),
		detail   = tonumber(GetCVar("graphicsEnvironmentDetail") or ""),
	}
	db.calib = db.calib or {}
	table.insert(db.calib, entry)

	local what = parsed and string.format("type %s intensity %s recID %s",
		tostring(parsed.type), tostring(parsed.intensity), tostring(parsed.recordID))
		or string.format("%s at %.2f", tostring(real), grade or 0)

	-- Loud on purpose. The whole session is worthless if he is looking away.
	msg("|cffffd100>>> REAL WEATHER <<<|r " .. what)
	msg(string.format("   %s - screenshot it now, then |cffffd100/dusk off|r and screenshot again",
		entry.subzone ~= "" and entry.subzone or entry.zone))
	return entry
end

local function CalibStart()
	if calibOn then msg("already logging"); return end
	calibFrame = calibFrame or CreateFrame("Frame")

	-- An unregistered-event name throws on this client and aborts the rest of
	-- the file with it, so neither of these may be registered bare.
	local got = {}
	for _, e in ipairs({ "CONSOLE_MESSAGE", "WEATHER_CHANGED" }) do
		if pcall(calibFrame.RegisterEvent, calibFrame, e) then got[#got + 1] = e end
	end
	if #got == 0 then
		msg("|cffff6666neither CONSOLE_MESSAGE nor WEATHER_CHANGED exists on this client|r")
		return
	end

	calibFrame:SetScript("OnEvent", function(_, event, arg1)
		if event == "CONSOLE_MESSAGE" then
			local parsed = ParseWeatherLine(arg1)
			if parsed then CalibRecord("console", parsed) end
		else
			CalibRecord("event", nil)
		end
	end)

	-- Without these two the client will not draw real weather at all, and the
	-- session measures nothing.
	for cvar, want in pairs(DENSITY_CVARS) do SetCVar(cvar, want) end

	calibOn = true
	db.calib = db.calib or {}
	msg("logging via |cff66ff66" .. table.concat(got, " + ") .. "|r, density raised")
	msg("turn on |cffffd100/chatlog|r too, then go stand somewhere wet and play")
	-- Seed one entry so there is a clear-weather baseline to difference against.
	CalibRecord("baseline", nil)
end

local function CalibStop()
	if calibFrame then
		calibFrame:UnregisterAllEvents()
		calibFrame:SetScript("OnEvent", nil)
	end
	calibOn = false
	msg(string.format("stopped. |cff66ff66%d|r observations held in DuskfallDB.calib",
		db.calib and #db.calib or 0))
end

local function CalibReport()
	local n = db.calib and #db.calib or 0
	msg(string.format("calibration: %s, |cff66ff66%d|r observations",
		calibOn and "|cff66ff66logging|r" or "|cffff6666off|r", n))
	for i = math.max(1, n - 4), n do
		local e = db.calib[i]
		msg(string.format("  %s %s%s", date("%H:%M", e.at), e.zone or "?",
			e.console and string.format(" - type %s @ %s", tostring(e.console.type),
				tostring(e.console.intensity)) or ""))
	end
	if n > 0 then
		msg("|cffffd100/dusk calib off|r when done; the table survives a /reload")
	end
end

-- Rain is wanted right now: on, not in a cinematic, and either outdoors or
-- the player has asked for it indoors too.
local function ShouldRain()
	if not db.enabled or cinematic then return false end
	if indoorsNow and not db.indoors then return false end
	return true
end

-- Indoor state has no reliable event of its own, so it is polled.
--
-- The poll cannot live on the overlay's OnUpdate, which is where it started.
-- The overlay hides when it is not raining, a hidden frame stops receiving
-- OnUpdate, and going indoors is exactly what hides it - so the poll would
-- stop running at the precise moment it is needed, and the addon would be
-- blind to the player walking back outside. A ticker runs either way.
local function PollIndoors()
	local inside = IsIndoors() and true or false
	if inside ~= indoorsNow then
		-- Debounce: walking under an arch should not restart the audio.
		indoorsSince = indoorsSince or GetTime()
		if GetTime() - indoorsSince > 0.9 then
			indoorsNow = inside
			indoorsSince = nil
			Duskfall_Refresh()
		end
	else
		indoorsSince = nil
	end
end

local function OnUpdate(self, elapsed)
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
	local weather, p = W(), Preset()
	local rate = p.speed * db.speed * (1 + runSpeed * 0.3)
	local density = p.density
	local slant = p.slant or weather.slant

	-- Snow has almost no terminal velocity to resist a breeze, so the whole
	-- field drifts one way and then back over several seconds. Rain's sway is
	-- zero and this collapses to nothing; without it, snow is just slow rain.
	local sway = p.sway or weather.sway
	if sway ~= 0 then
		local rateHz = p.swayRate or weather.swayRate
		drift = drift + elapsed
		slant = slant + math.sin(drift * rateHz * 2 * math.pi) * sway
	end

	for _, l in ipairs(LAYERS) do
		local tilesY = l.tilesY * (l.key == "mist" and 1 or density)
		local tilesX = tilesY * aspect
		local o = offsets[l.key]
		local dy = l.speed * rate * elapsed
		-- The sampling window moves up the sheet so the image falls down the screen.
		o.y = (o.y - dy) % 1
		-- Slant drift, plus the camera swing scaled into this layer's tiling so
		-- every layer sweeps the same distance across the screen.
		o.x = (o.x - dy * slant + swing * PARALLAX[l.key] * tilesX) % 1
		textures[l.key]:SetTexCoord(o.x, o.x + tilesX, o.y, o.y + tilesY)
	end
end

local function BuildOverlay()
	-- Parented to WorldFrame, not UIParent: the rain sits above the 3D scene but
	-- below every UI frame, and survives Alt+Z so screenshots keep it.
	-- The time grade is its own frame, underneath the rain, because it has to be
	-- usable on its own: wanting your realm's night to match your own clock has
	-- nothing to do with wanting rain.
	tod = CreateFrame("Frame", "DuskfallTimeOfDay", WorldFrame)
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

	overlay = CreateFrame("Frame", "DuskfallOverlay", WorldFrame)
	overlay:SetAllPoints(WorldFrame)
	overlay:SetFrameStrata("BACKGROUND")
	overlay:SetFrameLevel(5)
	overlay:EnableMouse(false)

	-- Drawn first and multiplied, so everything behind it dims; the rain and the
	-- lightning flash are added on top of the already-darkened frame.
	gloom = overlay:CreateTexture(nil, "BACKGROUND", nil, 0)
	gloom:SetAllPoints(overlay)
	gloom:SetBlendMode("MOD")

	-- The sheets themselves are chosen by ApplyTextures, which runs below and
	-- again whenever the weather changes.
	for i, l in ipairs(LAYERS) do
		local tex = overlay:CreateTexture(nil, l.layer, nil, i)
		tex:SetAllPoints(overlay)
		tex:SetBlendMode(l.blend)
		if l.key ~= "mist" then HorizonFade(tex) end
		textures[l.key] = tex
		offsets[l.key] = { x = math.random(), y = math.random() }
	end

	-- Above the curtain, below the lightning: a blizzard washes out what is
	-- behind it, including its own snow.
	whiteout = overlay:CreateTexture(nil, "ARTWORK", nil, #LAYERS + 1)
	whiteout:SetAllPoints(overlay)
	whiteout:SetColorTexture(0.95, 0.97, 1, 1)
	whiteout:SetBlendMode("ADD")
	whiteout:SetAlpha(0)

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
	-- Off the overlay deliberately; see PollIndoors.
	indoorTicker = C_Timer.NewTicker(0.3, PollIndoors)
end

--------------------------------------------------------------------------------
-- Sound
--------------------------------------------------------------------------------

-- There is no looping flag on PlaySoundFile, so a loop is the clip relaunched
-- BED_OVERLAP seconds before it ends. Two handles are kept so the old copy is
-- still running while the new one starts; a third would be a stack, not a loop.
local function SlotStop(slot)
	for _, h in ipairs(slot.handles) do
		if h then StopSound(h) end
	end
	wipe(slot.handles)
	if slot.ticker then slot.ticker:Cancel() slot.ticker = nil end
end

local function SlotPlay(slot, file)
	local ok, handle = PlaySoundFile(file, db.channel)
	if not ok then return false end
	slot.handles[#slot.handles + 1] = handle
	while #slot.handles > 2 do table.remove(slot.handles, 1) end
	return true
end

local function CurrentBed()
	local w = W()
	if bedFallback then return w.fallbackBed.file, w.fallbackBed.len end
	local b = Preset().bed
	return b.id, b.len
end

local function PlayBedClip()
	if not ShouldRain() or not db.sound then return end
	local file = CurrentBed()
	if not SlotPlay(bedSlot, file) then
		if not bedFallback then
			bedFallback = true
			msg("the client would not play Blizzard's " .. W().label ..
			    " loop; using the bundled one.")
			return PlayBedClip()
		end
	end
end

-- The blizzard's second loop. Nothing else in the addon has one, and nothing
-- falls back if it will not play: wind under snow is a bonus, not the bed.
local function PlayWindClip()
	local wind = Preset().wind
	if not wind or not ShouldRain() or not db.sound then return end
	SlotPlay(windSlot, wind.id)
end

local function StopBed()
	SlotStop(bedSlot)
	SlotStop(windSlot)
	loopedKey = nil
end

local function StartBed()
	StopBed()
	if not ShouldRain() or not db.sound then return end
	PlayBedClip()
	local _, len = CurrentBed()
	bedSlot.ticker = C_Timer.NewTicker(len - BED_OVERLAP, PlayBedClip)

	local wind = Preset().wind
	if wind then
		PlayWindClip()
		windSlot.ticker = C_Timer.NewTicker(wind.len - BED_OVERLAP, PlayWindClip)
	end
	loopedKey = db.weather .. "/" .. db.intensity
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

-- Rain's punctuation is a thunderclap with a flash in front of it. Snow's is a
-- gust: same scheduler, no lightning, because a snowstorm has none.
local function Strike()
	if not ShouldRain() or not db.thunder then return end
	local w = W()
	if w.flash then
		local peak = 0.14 + Preset().mist * 1.4
		FlashOnce(peak, 0.22)
		if math.random() < 0.45 then
			C_Timer.After(0.26, function() FlashOnce(peak * 0.7, 0.18) end)
		end
	end
	-- Thunder trails the flash the way distance makes it. A gust has no flash
	-- to trail, so it simply arrives.
	C_Timer.After(w.flash and (0.6 + math.random() * 2.6) or 0, function()
		if not ShouldRain() or not db.thunder or not db.sound then return end
		local list = w.oneShots
		local ok = PlaySoundFile(list[math.random(#list)], db.channel)
		if not ok and w.fallbackOneShot then
			PlaySoundFile(w.fallbackOneShot, db.channel)
		end
	end)
end

local function ScheduleLightning()
	if lightningTimer then lightningTimer:Cancel() lightningTimer = nil end
	if not db.enabled or not db.thunder then return end
	-- A blizzard gusts far more often than a storm thunders.
	local base = Preset().gustEvery or (70 - (Preset().speed - 0.8) * 28)
	lightningTimer = C_Timer.NewTimer(base * (0.55 + math.random() * 0.9), function()
		lightningTimer = nil
		Strike()
		ScheduleLightning()
	end)
end

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

function Duskfall_Refresh()
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
		if not bedSlot.ticker or loopedKey ~= db.weather .. "/" .. db.intensity then
			StartBed()
		end
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
local Refresh = Duskfall_Refresh

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
		"%s - %s %s, alpha x%.2f, speed x%.2f, dim x%.2f, sound %s%s, %s %s, indoors %s (channel %s)%s",
		db.enabled and "|cff66ff66on|r" or "|cffff6666off|r",
		db.intensity, W().label, db.scale, db.speed, db.gloom,
		db.sound and "on" or "off",
		bedFallback and " |cffff9900(bundled audio)|r" or "",
		W().flash and "thunder" or "gusts",
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
	print("  |cffffd100/dusk|r - toggle on/off")
	print("  |cffffd100/dusk rain|snow|r - which weather to draw")
	print("  |cffffd100/dusk light|normal|heavy|r - intensity")
	print("  |cffffd100/dusk monsoon|r, |cffffd100/dusk blizzard|r - the top of each, weather included")
	print("  |cffffd100/dusk auto|r - match whatever the realm says the weather is here")
	print("  |cffffd100/dusk alpha <0-1.5>|r - how visible it is")
	print("  |cffffd100/dusk speed <0.2-3>|r - how fast it falls")
	print("  |cffffd100/dusk dim <0-2>|r - how much it darkens the world (0 = off)")
	print("  |cffffd100/dusk time local|r - make it look like YOUR clock, not the realm's")
	print("  |cffffd100/dusk time +9|r, |cffffd100/dusk time 21|r, |cffffd100/dusk time off|r")
	print("  |cffffd100/dusk indoors on|off|r - draw it inside buildings too")
	print("  |cffffd100/dusk sound on|off|r, |cffffd100/dusk thunder on|off|r (gusts, in snow)")
	print("  |cffffd100/dusk channel Ambience|SFX|Master|r - which volume slider owns it")
	print("  |cffffd100/dusk density|r - is the client even allowed to draw real weather?")
	print("  |cffffd100/dusk calib on|r - log real weather so the defaults stop being guesses")
	print("  |cffffd100/dusk probe|r - answer the client-gated questions before the beta dies")
	print("  |cffffd100/dusk status|r")
end

local function HandleSlash(input)
	input = (input or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	local cmd, arg = input:match("^(%S*)%s*(.-)$")

	if cmd == "" then
		db.enabled = not db.enabled
	elseif WEATHER[cmd] then
		db.weather, db.enabled = cmd, true
		NormaliseIntensity()
		StartBed()
		ScheduleLightning()
	-- "blizzard" and "monsoon" each name a weather as well as an intensity, so
	-- they switch both at once: nobody typing /dusk blizzard wants rain.
	elseif cmd == "blizzard" or cmd == "monsoon" then
		db.weather = (cmd == "blizzard") and "snow" or "rain"
		db.intensity, db.enabled = cmd, true
		StartBed()
		ScheduleLightning()
	elseif W().presets[cmd] then
		db.intensity, db.enabled = cmd, true
		StartBed()
		ScheduleLightning()
	elseif cmd == "auto" then
		-- Follow the realm's own weather if it is telling us anything. This is
		-- a one-shot match, not a mode: C_Weather is a poll with no event, and
		-- a ticker on it would cost more than it is worth.
		local real = RealWeather()
		if not real or real == "none" then
			msg("the realm reports no weather here, so there is nothing to match.")
			return
		end
		if not WEATHER[real] then
			msg("the realm reports |cffffd100" .. real .. "|r, which this addon cannot draw.")
			return
		end
		db.weather, db.enabled = real, true
		NormaliseIntensity()
		StartBed()
		ScheduleLightning()
		msg("matched the realm: |cff66ff66" .. real .. "|r")
	elseif cmd == "on" or cmd == "off" then
		db.enabled = (cmd == "on")
	elseif cmd == "alpha" then
		local v = tonumber(arg)
		if not v then msg("usage: /dusk alpha 0.75") return end
		db.scale = math.max(0, math.min(1.5, v))
	elseif cmd == "speed" then
		local v = tonumber(arg)
		if not v then msg("usage: /dusk speed 1.4") return end
		db.speed = math.max(0.2, math.min(3, v))
	elseif cmd == "time" then
		local sub, rest = arg:match("^(%S*)%s*(.-)$")
		if sub == "off" or sub == "" then
			db.timeMode = "off"
		elseif sub == "local" then
			db.timeMode = "local"
		elseif sub == "strength" then
			local v = tonumber(rest)
			if not v then msg("usage: /dusk time strength 0.7") return end
			db.timeStrength = math.max(0, math.min(1, v))
		elseif sub:match("^[+-]%d+%.?%d*$") then
			db.timeMode, db.timeOffset = "offset", tonumber(sub)
		elseif tonumber(sub) then
			db.timeMode, db.timeFixed = "fixed", tonumber(sub) % 24
		else
			msg("usage: |cffffd100/dusk time local|r (match your own clock), " ..
			    "|cffffd100+9|r / |cffffd100-5|r (shift by hours), " ..
			    "|cffffd10021|r (hold one hour), |cffffd100off|r, " ..
			    "|cffffd100strength 0.7|r")
			return
		end
		UpdateTimeOfDay()
	-- "gloom" was the name until the rename; it still works and is not advertised.
	elseif cmd == "dim" or cmd == "gloom" then
		local v = tonumber(arg)
		if not v then msg("usage: /dusk dim 0.5  (0 turns the darkening off)") return end
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
		local order = W().order
		for n, name in ipairs(order) do
			if name == db.intensity then i = n end
		end
		db.intensity, db.enabled = order[(i % #order) + 1], true
		StartBed()
	elseif cmd == "density" then
		-- Not touched automatically: these are the player's graphics settings,
		-- and raising them turns on Blizzard's real weather everywhere, not ours.
		if arg == "" then
			DensityReport()
			msg("|cffffd100/dusk density on|r raises both so the realm's own weather renders")
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
	-- Probe.lua is a separate chunk and may not be installed; see its header.
	elseif cmd == "probe" then
		if Duskfall_Probe then
			Duskfall_Probe(arg)
		else
			msg("Probe.lua is not installed.")
		end
		return
	elseif cmd == "calib" or cmd == "calibrate" then
		if arg == "off" then
			CalibStop()
		elseif arg == "on" then
			CalibStart()
		elseif arg == "wipe" then
			db.calib = {}
			msg("calibration log cleared")
		else
			CalibReport()
		end
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
		-- The addon was called AlwaysRain until 2026-10-14. Its settings live in a
		-- global named after the old addon, which exists only if the old folder is
		-- still installed and loaded first (## OptionalDeps). Strangers will never
		-- have it, so this is a no-op for them.
		--
		-- Wrapped, because an old table that is malformed must cost the user their
		-- settings and nothing else. Bricking the addon during a rename is the
		-- stupidest available way to lose somebody on day one.
		DuskfallDB = DuskfallDB or {}
		if not DuskfallDB.migrated and type(AlwaysRainDB) == "table" then
			local ok = pcall(function()
				for k, v in pairs(AlwaysRainDB) do
					if DuskfallDB[k] == nil then DuskfallDB[k] = v end
				end
			end)
			DuskfallDB.migrated = true
			msg(ok and "settings carried over from AlwaysRain."
			       or "|cffff9900could not read the old AlwaysRain settings, starting fresh.|r")
		end

		db = DuskfallDB
		for k, v in pairs(DEFAULTS) do
			if db[k] == nil then db[k] = v end
		end
		BuildOverlay()

		SLASH_DUSKFALL1 = "/dusk"
		SLASH_DUSKFALL2 = "/duskfall"
		SLASH_DUSKFALL3 = "/rain"          -- permanent alias, not deprecated
		SlashCmdList.DUSKFALL = HandleSlash
		msg("loaded. |cffffd100/dusk|r to toggle, |cffffd100/dusk help|r for the rest.")

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

-- ComfyRain 2.0
--
-- The client cannot be told to make it rain: C_Weather only reads, ApplyWeather
-- belongs to server-driven scene scripts, and there is no weather console command.
-- So this draws the rain itself, on a frame between the 3D world and the UI.
--
-- Everything audible, and the drop sprite the textures are built from, is
-- Blizzard's own: the weather ambience loops the client already ships, played by
-- FileDataID. Only the tiling of the drops is ours, because the particle system
-- that would normally place them is not reachable from an addon.

local ADDON = "ComfyRain"
-- Kept beside the addon name rather than only in the TOC: /comfy about prints
-- it, and X-Website is not guaranteed to be readable as metadata on every
-- client. The two are checked against each other by a spec.
local HOMEPAGE = "https://github.com/LibruaryNFT/comfyrain"
local MEDIA = "Interface\\AddOns\\ComfyRain\\"

local BED_OVERLAP = 0.12      -- seconds of overlap when relooping the bed
-- The seam is relaunched up to this much EARLIER than the minimum overlap, never
-- later. A fixed interval turns the bed into a metronome: the same seam lands on
-- the same second forever and the ear finds it within two or three passes. Only
-- ever early, because overshooting would open a silent gap, which is worse than
-- a seam. Overlap therefore ranges BED_OVERLAP to BED_OVERLAP + BED_JITTER.
local BED_JITTER  = 0.8
-- Per-launch gain wobble. volumeOverride is the only gain control this client
-- exposes and it only applies at play time, so this is the whole dynamic range
-- available to us. Both consults put a useful wobble at 5-8%.
local BED_VOL_JITTER = 0.07
-- Longest the second bed layer may wait before joining the first. Small on
-- purpose: this is the gap between "the player turned rain on" and "the rain
-- sounds like rain". See StartBed for why it used to be up to 30 seconds.
local UNDER_FIRST_MAX = 2.5

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

-- Every Blizzard ambience loop this addon knows about. Suppression works by
-- muting the ones we are NOT currently using, which is the whole trick: the
-- probe on build 70374 confirmed `MuteSoundFile` is keyed on the FILE and not
-- on the caller, so muting the loop we ourselves play silences us too. Using a
-- different file from the one being suppressed is the only way through, and
-- these loops are close enough in character that swapping one for another
-- costs the player nothing. It also confirmed the mute SURVIVES a reload, so
-- every mute has to be undone explicitly; a crash mid-session is the one case
-- this cannot cover, and `/comfy suppress off` repairs it.
local AMBIENCE_LOOPS = {
	538981, 538982, 538983,            -- rain: medium, heavy, light
	538984, 538985, 538989,            -- snow: heavy, light, medium
	918050,                            -- blizzard wind
}

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
			light   = { mist = 0.05, far = 0.40, near = 0.35, density = 1.35, speed = 0.59, gloom = 0.18, strikeEvery = 70, bed = { id = 538983, len = 20.0 }, under = { id = 538981, len = 30.0, volume = 0.35 } },
			normal  = { mist = 0.10, far = 0.70, near = 0.65, density = 1.00, speed = 1.00, gloom = 0.38, strikeEvery = 64, bed = { id = 538981, len = 30.0 }, under = { id = 538983, len = 20.0, volume = 0.40 } },
			heavy   = { mist = 0.17, far = 0.95, near = 0.90, density = 0.78, speed = 1.60, gloom = 0.75, strikeEvery = 57, bed = { id = 538982, len = 25.0 }, under = { id = 538981, len = 30.0, volume = 0.45 } },
			monsoon = { mist = 0.26, far = 1.00, near = 1.00, density = 0.58, speed = 2.76, gloom = 0.95, strikeEvery = 48, bed = { id = 538982, len = 25.0 }, under = { id = 538983, len = 20.0, volume = 0.55 } },
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
		tint    = { 0.62, 0.69, 0.84 },
		flash   = false,        -- a snowstorm has no lightning
		oneShots = GUSTS,
		fallbackOneShot = nil,  -- nothing bundled; a missing gust costs nothing
		fallbackBed = { file = MEDIA .. "rain.ogg", len = 24.0 },
		presets = {
			light    = { mist = 0.06, far = 0.34, near = 0.30, density = 1.20, speed = 0.22, gloom = 0.26, strikeEvery = 85, bed = { id = 538985, len = 29.951 }, under = { id = 538989, len = 50.0, volume = 0.30 } },
			normal   = { mist = 0.12, far = 0.62, near = 0.58, density = 1.00, speed = 0.36, gloom = 0.54, strikeEvery = 82, bed = { id = 538989, len = 50.0 }, under = { id = 538985, len = 29.951, volume = 0.35 } },
			heavy    = { mist = 0.20, far = 0.88, near = 0.84, density = 0.82, speed = 0.63, gloom = 0.78, strikeEvery = 78, bed = { id = 538984, len = 40.0 }, under = { id = 538989, len = 50.0, volume = 0.40 } },
			blizzard = {
				mist = 0.30, far = 1.00, near = 1.00, density = 0.66, speed = 2.58, gloom = 0.55,
				bed = { id = 538984, len = 40.0 },
				under = { id = 538989, len = 50.0, volume = 0.35 },
				-- The gale sheet replaces the near layer: wind-driven snow is
				-- near-horizontal streaks, which is a different sprite, not a
				-- faster scroll of the same one.
				near_texture = MEDIA .. "snow-gale.tga",
				slant = 1.9, sway = 0.5, swayRate = 0.12,
				-- A whiteout brightens. Capped hard: this is the one effect in
				-- the addon that can make the world harder to play in, and an
				-- addon that hides a mob is an addon that gets uninstalled.
				whiteout = 0.05,
				-- Wind over the snow bed. Two loops at once, which nothing else
				-- in the addon needs, because this is what a blizzard sounds like.
				wind = { id = 918050, len = 110.713 },
				strikeEvery = 14,
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

-- Gusts. A constant scroll rate reads as a conveyor belt inside a minute: the
-- eye finds the loop and the illusion is over. Real weather arrives in gusts,
-- and - this is the part that matters - the whole sky gusts at once. So this is
-- ONE signal shared by every parameter, not independent jitter per layer.
-- Independent noise reads as broken rendering; a shared signal reads as wind.
--
-- The signal is an Ornstein-Uhlenbeck process: a random walk with a spring
-- pulling it back towards zero. Summed sines repeat and a plain random walk can
-- wander off and leave the storm permanently stuck at double speed; this does
-- neither. GUST_TAU is roughly how long it takes to forget where it was, and
-- the stationary spread is GUST_SIGMA * sqrt(GUST_TAU / 2), about 0.65 here.
local GUST_TAU   = 7.0
local GUST_SIGMA = 0.35
local GUST_CLAMP = 1.6

-- The driving noise is the sum of two uniforms, which is triangular and close
-- enough to Gaussian for this, but it has to be scaled to unit variance or
-- GUST_SIGMA does not mean what the line above says it means. u1+u2-1 has
-- variance 2/12, so the scale is sqrt(6), not the sqrt(3) that belongs to a
-- SINGLE uniform. With sqrt(3) the whole gust ran at 71% of its stated
-- amplitude and the stationary spread was 0.46 rather than the documented 0.65.
local NOISE_SCALE = math.sqrt(6)

-- Each layer follows the master with its own one-pole lag. A gust hits the near
-- sheet first and the mist last, because the distant layer stands in for a
-- larger body of air that takes longer to get moving. Units are 1/seconds, so
-- mist is about a second behind. The lag is what sells it as depth rather than
-- as three sheets being scaled by the same number.
local GUST_FOLLOW = { near = 6.0, far = 2.2, mist = 1.0 }

-- How much a gust is allowed to move each parameter, at normal intensity. Two
-- LLM consults independently put the perceptual floor near 2% and said a 20-30%
-- change in scroll rate is what actually reads as "a gust"; below those numbers
-- the work is invisible and therefore wasted.
local GUST_RATE_AMP  = 0.18
local GUST_ALPHA_AMP = 0.10
local GUST_SLANT_AMP = 0.14
local GUST_GLOOM_AMP = 0.12

-- Light drizzle does not gust; a monsoon does little else.
local GUST_BY_INTENSITY = {
	light = 0.45, normal = 1.0, heavy = 1.5, monsoon = 2.0, blizzard = 2.0,
}

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
	-- Multiplies the preset's darkening; 0 disables it, and the slider goes to 2.
	--
	-- Stays at 1.0, and that is a decision rather than an omission. The three
	-- product reports all found a real backlash against screen murk in Forever
	-- (eye strain, headaches, Blizzard pulling `/console volumeFog 0` as
	-- "unintended"), which argued for lowering this. It was lowered to 0.6 and
	-- then put back, because the preset curve underneath it is not a guess: the
	-- screenshot sweep on 2026-10-15 measured normal rain darkening the scene by
	-- 0.7% and the gloom was RAISED to compensate, since the rain sheets are
	-- light-coloured and add back more than the old curve removed. A 0.6
	-- multiplier puts normal rain back under that measured threshold - it
	-- re-opens the exact bug the sweep closed.
	--
	-- The murk the reports describe lives at `heavy` and `monsoon`, which are
	-- presets a player deliberately picks, on an effect they deliberately turned
	-- on, with a Darkness slider in the settings window. That is consent, and it
	-- is a different thing from fog nobody asked for and cannot disable.
	gloom     = 1.0,
	gust      = 1.0,       -- multiplies how hard the wind gusts; 0 is dead calm
	zoom      = true,      -- let camera distance change drop size and fall speed
	sound     = true,
	volume    = 1.0,       -- 0..1 over the weather bed only; 0 is silent
	minimap   = true,      -- show the minimap button
	minimapAngle = 196,    -- degrees around the minimap ring
	suppress  = false,    -- mute the realm's own weather loop; see AMBIENCE_LOOPS
	thunder   = true,
	indoors   = "dim",     -- off | dim | on; see IndoorMode
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

-- Camera distance at which the view counts as fully pulled back. Classic's
-- default ceiling is 15 yards and cameraDistanceMaxZoomFactor can raise it, so
-- this normalises and clamps rather than assuming the player left it alone.
local ZOOM_FULL  = 15
local ZOOM_PIVOT = 0.65   -- the zoom most people play at; left exactly as tuned
local ZOOM_RANGE = 0.55   -- how far sheet density swings across the whole range
local ZOOM_RATE  = 0.20   -- extra fall speed at the first-person end

local db
local overlay, flash, gloom, whiteout
local tod, todDim, todLift, todTicker
local textures, offsets = {}, {}
local lastFacing, turnDelta, runSpeed = nil, 0, 0
local zoomNorm = ZOOM_PIVOT
-- Two loop slots. A blizzard is a snow bed with a wind loop running under it,
-- and one slot would mean choosing between them when the point is the mix.
local bedSlot   = { handles = {} }
local underSlot = { handles = {} }
local windSlot  = { handles = {} }
-- loopedKey is what the running bed is a loop OF; bedIndoor is how loud it was
-- told to be. Both have to be compared before deciding the bed is current,
-- because volumeOverride is fixed at play time - see BedVolume.
local bedFallback, loopedKey, bedIndoor = false, nil, nil
local lightningTimer
local appliedTextures
local drift = 0
local cinematic, indoorsNow, indoorsSince = false, false, nil
-- Forward-declared: ApplyAlphas is defined above where these are, and a
-- function body that names a local declared later resolves to a global.
local IndoorMode, IndoorFactor
-- The master gust and its three lagged followers. baseAlpha and baseGloom are
-- what ApplyAlphas decided; the gust modulates around them every frame without
-- destroying the setting, so changing a slider still lands where it should.
local gust = 0
local layerGust = { near = 0, far = 0, mist = 0 }
local baseAlpha = { near = 0, far = 0, mist = 0 }
local baseGloom = 0
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

-- Keep db.intensity truthful after a weather change, so /comfy status and the
-- saved settings never name a preset this weather does not have.
local function NormaliseIntensity()
	if W().presets[db.intensity] then return end
	db.intensity = (db.intensity == "monsoon" or db.intensity == "blizzard")
		and W().order[#W().order] or "normal"
end

-- Everything the player can set is also something a SavedVariables file can
-- hand back as the wrong type, and filling in the missing keys is not the same
-- as trusting the ones that are there.
--
-- The merge used to be `if db[k] == nil then db[k] = default end`, which is
-- correct for an absent key and does nothing at all for a present but wrong
-- one. A profile carrying `scale = "heavy"` - a half-written file, a hand edit,
-- a bad migration from some future version of this addon - loads without
-- complaint and then throws inside ApplyAlphas on the next frame, which means
-- an error on every frame forever and an addon the player can only fix by
-- deleting a file they do not know exists.
--
-- Clamping to the same ranges the slash parser uses, rather than inventing a
-- second set, so a value typed and a value loaded can never disagree.
local NUMERIC_RANGE = {
	scale        = { 0,   1.5 },
	speed        = { 0.2, 3   },
	gloom        = { 0,   2   },
	gust         = { 0,   2   },
	volume       = { 0,   1   },
	timeStrength = { 0,   1   },
	timeOffset   = { -23, 23  },
	timeFixed    = { 0,   23  },
	minimapAngle = { 0,   360 },
}

local ENUM = {
	weather  = { rain = true, snow = true },
	channel  = { Ambience = true, SFX = true, Master = true,
	             Music = true, Dialog = true },
	timeMode = { off = true, ["local"] = true, offset = true, fixed = true },
	indoors  = { off = true, dim = true, on = true },
}

-- Which settings belong to which part of the window. Used by the per-section
-- Reset buttons and by sharing, and it is the only place the grouping is
-- written down, so a new setting that is in DEFAULTS and in none of these is a
-- setting no Reset button can reach and no shared profile carries. A spec walks
-- a fresh db against this table for exactly that reason, so the omission fails
-- the suite rather than shipping quietly.
local SECTIONS = {
	look  = { "enabled", "weather", "intensity", "scale", "speed",
	          "gloom", "gust", "zoom", "indoors" },
	sound = { "sound", "volume", "channel", "thunder", "suppress" },
	time  = { "timeMode", "timeOffset", "timeFixed", "timeStrength" },
}
local SECTION_ORDER = { "look", "sound", "time" }

-- Everything a shared profile carries. Deliberately NOT where the window was
-- dragged to, which minimap angle it sits at, or whether the first-run notice
-- has been seen: those are this installation's furniture, and importing
-- somebody else's would move things on screen for no reason they asked for.
local PROFILE_KEYS = {}
for _, name in ipairs(SECTION_ORDER) do
	for _, k in ipairs(SECTIONS[name]) do PROFILE_KEYS[#PROFILE_KEYS + 1] = k end
end

local function SanitiseProfile()
	for k, default in pairs(DEFAULTS) do
		local v = db[k]
		local range = NUMERIC_RANGE[k]
		if v == nil then
			db[k] = default
		elseif range then
			-- tonumber, not a type test: a number stored as "0.75" is a value
			-- the player meant, and there is no reason to throw it away.
			local n = tonumber(v)
			db[k] = n and math.max(range[1], math.min(range[2], n)) or default
		elseif ENUM[k] then
			if k == "indoors" and type(v) == "boolean" then
				-- indoors was a two-state toggle before it was three. See
				-- IndoorMode, which still answers to the old booleans.
				db[k] = v and "on" or "dim"
			elseif not (type(v) == "string" and ENUM[k][v]) then
				db[k] = default
			end
		elseif type(v) ~= type(default) then
			db[k] = default
		end
	end
	-- Deliberately last, and deliberately not in ENUM: which intensities exist
	-- depends on the weather, which the loop above may just have corrected.
	NormaliseIntensity()
end

--------------------------------------------------------------------------------
-- Sharing a profile
--
-- Plain text rather than a serialised-and-encoded blob, and that is a choice.
-- There is no base64 or deflate in the client's Lua, so an encoded format means
-- shipping a copy of LibDeflate for a string that holds about twenty numbers;
-- and the plain version has a property the compressed one does not, which is
-- that a player can READ it before pasting it and see that it only contains
-- weather settings. An addon string that nobody can inspect is a thing people
-- are right to be wary of pasting.
--
-- Nothing here can run code. Import never touches the keys it was not given, is
-- restricted to PROFILE_KEYS, coerces every value to the type DEFAULTS declares,
-- and then runs the whole profile through SanitiseProfile, which clamps every
-- number and rejects every unknown enum. The worst a hostile string can do is
-- set rain to heavy.
--------------------------------------------------------------------------------

local PROFILE_TAG = "ComfyRain1"

local function ExportProfile()
	local out = {}
	for _, k in ipairs(PROFILE_KEYS) do
		local v = db[k]
		if type(v) == "boolean" then v = v and "1" or "0"
		elseif type(v) == "number" then v = ("%g"):format(v)
		elseif type(v) ~= "string" then v = nil end
		if v then out[#out + 1] = k .. "=" .. v end
	end
	return PROFILE_TAG .. ":" .. table.concat(out, ";")
end

-- Case is not carried by a profile string. The slash parser lowercases what it
-- is given, forums and Discord mangle case, and "comfyrain1:" arriving from a
-- client that lowercased it is a correct paste that must not be refused over a
-- capital letter. So everything is matched case-insensitively and the CANONICAL
-- spelling is recovered from PROFILE_KEYS and ENUM rather than from the input.
local CANON_KEY, CANON_ENUM = {}, {}
for _, k in ipairs(PROFILE_KEYS) do CANON_KEY[k:lower()] = k end
for k, set in pairs(ENUM) do
	CANON_ENUM[k] = {}
	for v in pairs(set) do CANON_ENUM[k][v:lower()] = v end
end

-- Returns the number of settings applied, or nil and a reason.
local function ImportProfile(text)
	if type(text) ~= "string" then return nil, "nothing to read" end
	text = text:gsub("%s", "")
	local head, body = text:match("^([^:]*):(.*)$")
	if head == nil or head:lower() ~= PROFILE_TAG:lower() then
		-- Naming the tag we DID find is the difference between a user fixing a
		-- truncated paste and giving up. Chat links and addon strings get cut.
		return nil, (head and head ~= "")
			and ("that is a " .. head .. " string, not a ComfyRain one")
			or "that does not look like a ComfyRain profile"
	end

	local pending, unknown = {}, 0
	for rawKey, v in body:gmatch("([%w_]+)=([^;]*)") do
		local k = CANON_KEY[rawKey:lower()]
		if not k then
			unknown = unknown + 1
		else
			local default = DEFAULTS[k]
			if type(default) == "boolean" then
				pending[k] = (v == "1" or v:lower() == "true")
			elseif type(default) == "number" then
				pending[k] = tonumber(v)
			elseif CANON_ENUM[k] then
				pending[k] = CANON_ENUM[k][v:lower()]
			else
				pending[k] = v
			end
		end
	end

	local n = 0
	for k, v in pairs(pending) do
		if v ~= nil then db[k] = v; n = n + 1 end
	end
	if n == 0 then return nil, "no settings in it that this version understands" end
	-- Every value above came from a stranger. This is what makes that safe.
	SanitiseProfile()
	return n, unknown
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
	-- db.enabled first, and it is not a redundant check. The time-of-day
	-- curtain is its own frame, not a child of the overlay, so hiding the
	-- overlay does nothing to it. Without this line /comfy off left a
	-- fullscreen MOD texture over the world holding the light at whatever hour
	-- was set, with no visible cause and nothing in the status line about it -
	-- reported from live play 2026-10-19 as "my screen is too dark and I can't
	-- turn it off". Off has to mean off, including the parts that are not rain.
	if not db.enabled or db.timeMode == "off" or cinematic then tod:Hide() return end

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
	local w, p, s = W(), Preset(), db.scale * IndoorFactor()
	baseAlpha.mist = math.min(p.mist * s, 0.6)
	baseAlpha.far  = math.min(p.far * s, 1)
	baseAlpha.near = math.min(p.near * s, 1)
	textures.mist:SetAlpha(baseAlpha.mist)
	textures.far:SetAlpha(baseAlpha.far)
	textures.near:SetAlpha(baseAlpha.near)

	-- MOD multiplies the frame by this colour, so strength lives in the colour
	-- itself: 1 is untouched, and we lerp towards the tint from there.
	local g = math.min(p.gloom * db.gloom * IndoorFactor(), 1.0)
	baseGloom = g
	gloom:SetColorTexture(
		1 - g * (1 - w.tint[1]),
		1 - g * (1 - w.tint[2]),
		1 - g * (1 - w.tint[3]), 1)

	-- The whiteout is the opposite move and only a blizzard uses it: ADD is the
	-- only way a 2D overlay can brighten anything. Capped well below the point
	-- where it could hide a mob, because an addon that does that gets deleted.
	if whiteout then
		whiteout:SetAlpha(math.min((p.whiteout or 0) * s, 0.10))
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
		-- Both, not one. Neither being true is its own state - under an awning
		-- or a cave mouth - and it is the state the overlay used to get wrong,
		-- so a sample that recorded only IsIndoors() could not show it.
		indoors  = IsIndoors() and true or false,
		outdoors = IsOutdoors() and true or false,
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
	-- The baseline entry is seeded at startup when it is definitely not
	-- raining, so shouting "REAL WEATHER" at it would be a lie and would also
	-- train him to ignore the one that matters.
	if source == "baseline" then
		msg("baseline taken (" ..
			((entry.subzone ~= "" and entry.subzone) or entry.zone or "?") ..
			", clear). Now just play.")
		return entry
	end

	msg("|cffffd100>>> THE GAME'S OWN RAIN JUST STARTED <<<|r")
	msg(string.format("   in %s. Do these three, in order:",
		entry.subzone ~= "" and entry.subzone or entry.zone))
	msg("   1. screenshot now |cff999999(this is Blizzard's rain)|r")
	msg("   2. |cffffd100/comfy on|r, screenshot again |cff999999(ours on top of theirs)|r")
	msg("   3. |cffffd100/comfy off|r, screenshot again |cff999999(theirs alone)|r")
	msg("   |cff999999" .. what .. "|r")
	return entry
end

-- resumed = this is a /reload picking the watch back up, not the player
-- starting one. Same work, far less chat, and no second baseline entry.
local function CalibStart(resumed)
	if calibOn then msg("the weather watch is already on"); return end
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
	-- session measures nothing. They are the player's graphics settings, not
	-- ours, so what they were is kept and `watch off` puts them back. An
	-- earlier version raised them and never restored, which silently left
	-- weatherDensity at 3 on a machine that had deliberately run it at 0.
	--
	-- Kept in db rather than in an upvalue, for the same reason db.watching is:
	-- an upvalue dies with the Lua state, and a /reload is a perfectly normal
	-- thing to do in the middle of a measuring session. The probe asks for one
	-- outright. Restoring to whatever the CVar happens to say afterwards would
	-- restore it to the value WE set.
	if not db.calibRestore then
		db.calibRestore = {}
		for cvar in pairs(DENSITY_CVARS) do
			db.calibRestore[cvar] = GetCVar(cvar)
		end
	end
	for cvar, want in pairs(DENSITY_CVARS) do SetCVar(cvar, want) end

	calibOn = true
	db.watching = true
	db.calib = db.calib or {}
	if resumed then
		msg("|cff66ff66Weather watch is still ON|r after the reload. Carry on.")
		return
	end
	msg("|cff66ff66Weather watch is ON.|r Two things to know:")
	msg("   Blizzard's own rain has been turned back up for this " ..
	    "|cff999999(it was off on this machine)|r.")
	msg("   Nothing about ComfyRain itself changed.")
	msg("Now just |cffffd100play normally|r. When the game's own weather starts, " ..
	    "this shouts in chat - you do not have to watch for it.")
	msg("When you are done: |cffffd100/comfy watch off|r " ..
	    "|cff999999(puts your graphics settings back)|r")
	-- Seed one entry so there is a clear-weather baseline to difference against.
	CalibRecord("baseline", nil)
end

local function CalibStop()
	if calibFrame then
		calibFrame:UnregisterAllEvents()
		calibFrame:SetScript("OnEvent", nil)
	end
	calibOn = false
	db.watching = nil
	local put = {}
	for cvar, was in pairs(db.calibRestore or {}) do
		if was then SetCVar(cvar, was); put[#put + 1] = cvar end
	end
	db.calibRestore = nil
	msg(string.format("Weather watch is |cffff6666OFF|r. " ..
		"|cff66ff66%d|r sightings saved, and they survive a /reload.",
		db.calib and #db.calib or 0))
	if #put > 0 then
		msg("Your graphics settings are back as they were.")
	end
end

local function CalibReport()
	local n = db.calib and #db.calib or 0
	msg(string.format("Weather watch: %s. |cff66ff66%d|r sightings so far.",
		calibOn and "|cff66ff66ON|r" or "|cffff6666off|r", n))
	for i = math.max(1, n - 4), n do
		local e = db.calib[i]
		msg(string.format("  %s %s%s", date("%H:%M", e.at), e.zone or "?",
			e.console and string.format(" - type %s @ %s", tostring(e.console.type),
				tostring(e.console.intensity)) or ""))
	end
	if n == 0 then
		msg("What this is for: every look setting in this addon is a guess, " ..
		    "because this machine has never drawn Blizzard's own rain.")
		msg("|cffffd100/comfy calib on|r watches for the real thing so ours can " ..
		    "be matched to it. Then just play.")
	else
		msg("|cffffd100/comfy watch off|r when you are done.")
	end
end

-- Rain is wanted right now: on, not in a cinematic, and either outdoors or
-- the player has asked for it indoors too.
-- Indoors has three settings, not two. "off" hides everything, "on" draws it
-- at full strength, and "dim" - the default - keeps it running quietly. The
-- middle one exists because the honest answer to "I went inside and the rain
-- stopped dead" is that silence is wrong: you can hear rain from indoors.
--
-- What CANNOT be fixed: seeing the rain through a window. The overlay is one
-- full-screen quad and the addon has no depth buffer, no camera matrix and no
-- way to ask which pixels are sky, so there is nothing to mask it against.
-- Drawing it only over the window is not a hard problem, it is an unavailable
-- one. "dim" is the closest reachable thing: a faint wash over the whole view
-- that reads as weather outside rather than as rain falling in the tavern.
function IndoorMode()
	local v = db.indoors
	if v == true then return "on" end
	if v == false or v == nil then return "dim" end
	return v
end

-- How much of the effect survives being indoors, and the two halves are NOT the
-- same number. Reported twice from live play, most recently from the Stormwind
-- barbershop: a 25% wash of rain under a solid roof does not read as "weather
-- outside", it reads as the addon failing to notice there is a ceiling. The ear
-- has no such problem - muffled rain through a wall is exactly right, and it is
-- the thing that makes an inn feel like shelter rather than like a loading
-- screen. So "dim" now means heard and not seen, which is also what Blizzard's
-- own weather does.
local INDOOR_SEE  = 0.0
local INDOOR_HEAR = 0.35

-- kind is "hear" for anything that comes out of the speakers, nil for pixels.
function IndoorFactor(kind)
	if not indoorsNow then return 1 end
	local m = IndoorMode()
	if m == "on" then return 1 end
	if m == "off" then return 0 end
	return kind == "hear" and INDOOR_HEAR or INDOOR_SEE
end

local function ShouldRain()
	if not db.enabled or cinematic then return false end
	if indoorsNow and IndoorMode() == "off" then return false end
	return true
end

-- Whether anything is DRAWN, as opposed to whether the weather is running at
-- all. Splitting these is what lets the bed keep playing in the inn while the
-- quads fade out, and routing it through fadeTarget rather than through Hide()
-- means walking through a door is a 0.7s fade instead of a pop.
local function ShouldDraw()
	return ShouldRain() and IndoorFactor() > 0
end

-- Indoor state has no reliable event of its own, so it is polled.
--
-- The poll cannot live on the overlay's OnUpdate, which is where it started.
-- The overlay hides when it is not raining, a hidden frame stops receiving
-- OnUpdate, and going indoors is exactly what hides it - so the poll would
-- stop running at the precise moment it is needed, and the addon would be
-- blind to the player walking back outside. A ticker runs either way.
-- IsIndoors() and IsOutdoors() are NOT complements on this client, and that
-- gap is the whole bug. A WMO interior sets IsIndoors true. Open world sets
-- IsOutdoors true. But awnings, cave mouths, tents, bridges, mine entrances and
-- the lip of most doorways set NEITHER - the player is under a roof the engine
-- does not count as a room, and the old test, which only asked IsIndoors(),
-- read every one of those as open sky and kept drawing rain on the ceiling.
-- Asking both turns two states into three and treats "sheltered" as indoors,
-- which is what it looks like.
local function Sheltered()
	if IsIndoors() then return true end
	if IsOutdoors() then return false end
	return true
end

-- Entering shelter is debounced much shorter than leaving it, because the two
-- errors are not equally bad. Rain falling through a roof is the thing being
-- reported; a second of missing rain after stepping back out is not. The long
-- exit debounce is also what keeps a quick in-and-out under an arch from
-- flickering: coming back needs a full ENTER_OUT seconds of clear sky.
local ENTER_IN, ENTER_OUT = 0.35, 1.2

-- Every committed transition, written down. `/comfy where` asks the player to
-- type a command at the exact moment he is busy looking at the thing, and two
-- of the places that got this wrong - the Stormwind inn and the barbershop -
-- were reported from memory afterwards rather than from a reading. This costs
-- one table per doorway and turns "it was wrong somewhere in Stormwind" into a
-- row with a subzone on it. Capped, because it runs for the life of the
-- character and SavedVariables is read on every login.
local WHERE_MAX = 300

-- Where the player is standing, as map coordinates, or nil.
--
-- The subzone alone is not enough to act on. Five readings off the live client
-- all said "Stormwind City / Trade District", which is fifty doorways, a
-- bridge and two awnings: enough to know something was wrong and not enough to
-- go back and look at it. A coordinate makes a bad doorway findable.
--
-- Guarded three deep because each layer can fail separately. C_Map.
-- GetPlayerMapPosition is in the binary (confirmed against WowB.exe
-- 1.60.1.70425); GetXY is a FrameXML mixin and is not, so it is tried and then
-- fallen back on the plain fields; and position is restricted in instances,
-- where it returns nil rather than erroring.
local function MapPos()
	if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return end
	local id = Readable(C_Map.GetBestMapForUnit("player"))
	if not id then return end
	local ok, pos = pcall(C_Map.GetPlayerMapPosition, id, "player")
	if not ok or not pos then return end
	local x, y
	if pos.GetXY then
		local got
		got, x, y = pcall(pos.GetXY, pos)
		if not got then x, y = nil, nil end
	end
	x, y = x or pos.x, y or pos.y
	if type(x) ~= "number" or type(y) ~= "number" then return end
	return id, x, y
end

local function WhereLog(reason)
	if not db then return end
	db.where = db.where or {}
	while #db.where >= WHERE_MAX do table.remove(db.where, 1) end
	local uiMapID, x, y = MapPos()
	db.where[#db.where + 1] = {
		at        = time(),
		reason    = reason,
		zone      = GetRealZoneText(),
		subzone   = GetSubZoneText(),
		-- A subzone names a district; this names a doorway.
		uiMapID   = uiMapID,
		x         = x and math.floor(x * 10000 + 0.5) / 10000 or nil,
		y         = y and math.floor(y * 10000 + 0.5) / 10000 or nil,
		-- All three, because the bug has always been in the gap between the
		-- first two, and a log that stored only the conclusion could not show
		-- which of the two APIs produced it.
		indoors   = IsIndoors() and true or false,
		outdoors  = IsOutdoors() and true or false,
		sheltered = Sheltered() and true or false,
		mode      = IndoorMode(),
	}
end

local function PollIndoors()
	local inside = Sheltered()
	if inside ~= indoorsNow then
		indoorsSince = indoorsSince or GetTime()
		if GetTime() - indoorsSince > (inside and ENTER_IN or ENTER_OUT) then
			indoorsNow = inside
			indoorsSince = nil
			WhereLog(inside and "entered" or "left")
			ComfyRain_Refresh()
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

	-- Camera zoom. The world camera's pitch and yaw are not exposed to addons
	-- at all, so distance is the only thing it will tell us - and it happens to
	-- be the one that changes what the weather ought to look like. First person
	-- puts the player inside the field: fewer drops, larger, falling faster.
	-- Fully pulled back puts fifteen yards of air between camera and character,
	-- and the same rain has to read finer and denser to still be the same rain.
	--
	-- Carried on tiling, which is the opposite of how the gust does it. The note
	-- on tilesY below says changing it mid-flight reads as the camera zooming.
	-- That is an artefact when nothing is zooming and it is the entire point
	-- when something is. Smoothed hard, because mouse-wheel zoom arrives in
	-- discrete steps and an unsmoothed jump would pop the whole field.
	local zoom = Readable(GetCameraZoom and GetCameraZoom())
	if zoom then
		local target = zoom / ZOOM_FULL
		if target < 0 then target = 0 elseif target > 1 then target = 1 end
		zoomNorm = zoomNorm + (target - zoomNorm) * math.min(1, elapsed * 5)
	end

	local aspect = w / h
	local weather, p = W(), Preset()
	local rate = p.speed * db.speed * (1 + runSpeed * 0.3)
	local density = p.density
	if db.zoom then
		density = density * (1 + (zoomNorm - ZOOM_PIVOT) * ZOOM_RANGE)
		rate = rate * (1 + (1 - zoomNorm) * ZOOM_RATE)
	end
	local slant = p.slant or weather.slant

	-- Step the gust, then let each layer chase it at its own pace. The noise is
	-- the sum of two uniforms rather than a real Gaussian: it is within a few
	-- percent of normal, costs two calls, and nobody is ever going to plot it.
	local gustAmp = (GUST_BY_INTENSITY[db.intensity] or 1) * db.gust
	if gustAmp > 0 then
		local n = (math.random() + math.random() - 1) * NOISE_SCALE
		gust = gust + (-gust / GUST_TAU) * elapsed + GUST_SIGMA * math.sqrt(elapsed) * n
		if gust > GUST_CLAMP then gust = GUST_CLAMP
		elseif gust < -GUST_CLAMP then gust = -GUST_CLAMP end
		for key, k in pairs(GUST_FOLLOW) do
			layerGust[key] = layerGust[key] + (gust - layerGust[key]) * math.min(1, elapsed * k)
		end

		-- Slant is the second most visible parameter after rate: a gust that
		-- only changes speed looks like a framerate change, one that also
		-- shears the fall looks like wind.
		slant = slant + gust * GUST_SLANT_AMP * gustAmp

		-- Gloom rides the mist follower, the slowest of the three, so the light
		-- changes a beat after the rain does. Leading with the light would read
		-- as a flicker; trailing reads as a cloud passing.
		if baseGloom > 0 then
			local g = baseGloom * (1 + layerGust.mist * GUST_GLOOM_AMP * gustAmp)
			if g < 0 then g = 0 elseif g > 1 then g = 1 end
			gloom:SetColorTexture(
				1 - g * (1 - weather.tint[1]),
				1 - g * (1 - weather.tint[2]),
				1 - g * (1 - weather.tint[3]), 1)
		end
	end

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
		local tiling = (l.key == "mist") and 1 or density
		local tilesY = l.tilesY * tiling
		local tilesX = tilesY * aspect
		local o = offsets[l.key]
		local lg = gustAmp > 0 and layerGust[l.key] or 0
		-- Rate and density both move with the gust. Density is carried by alpha
		-- rather than by tiling: changing tilesY mid-gust reads as the camera
		-- zooming, which is the one artefact that gives the whole thing away.
		--
		-- `* tiling` is the correction. Offsets are texture coordinates, and the
		-- screen shows tilesY copies of the sheet, so a fixed step in texture
		-- space moves the image 1/tilesY of a screen. Without this term a denser
		-- preset silently fell SLOWER in the same proportion, and `speed` meant
		-- anything from 0.6x to 2.8x what the number said. Multiplying it back
		-- out makes p.speed mean screen-heights per second and nothing else; the
		-- preset numbers were divided through by their own density at the same
		-- time, so what is on screen is unchanged.
		local dy = l.speed * rate * tiling * (1 + lg * GUST_RATE_AMP * gustAmp) * elapsed
		if lg ~= 0 then
			local a = baseAlpha[l.key] * (1 + lg * GUST_ALPHA_AMP * gustAmp)
			textures[l.key]:SetAlpha(a < 0 and 0 or (a > 1 and 1 or a))
		end
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
	tod = CreateFrame("Frame", "ComfyRainTimeOfDay", WorldFrame)
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

	overlay = CreateFrame("Frame", "ComfyRainOverlay", WorldFrame)
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

-- volumeOverride is the only gain control this client exposes and it exists
-- only at play time, so a clip's level is fixed the moment it starts. The probe
-- on build 70374 confirmed `soundKitID` is the id key but tested it with a
-- SoundKit; every id this addon owns is a FileDataID, so the options call may
-- refuse them. It is wrapped and falls back to the plain call, which costs the
-- volume wobble and nothing else.
-- Resolved once and cached, and the LOOKUP is pcall'd, not just the call. A
-- table whose __index raises is a shape this client can present, and reading a
-- field off one throws before any pcall around the call itself would help. The
-- bed must never be the thing that takes the addon down.
local optionsPlay, optionsResolved
local function OptionsPlay()
	if not optionsResolved then
		optionsResolved = true
		local ok, fn = pcall(function() return C_Sound and C_Sound.PlaySoundWithOptions end)
		if ok and type(fn) == "function" then optionsPlay = fn end
	end
	return optionsPlay
end

local function Play(file, volume)
	local ok, handle
	local opts = volume and OptionsPlay()
	if opts then
		local called, a, b = pcall(opts, {
			soundKitID = file, channel = db.channel, volumeOverride = volume })
		if called and a then ok, handle = a, b end
	end
	if not ok then ok, handle = PlaySoundFile(file, db.channel) end
	return ok, handle
end

local function SlotPlay(slot, file, volume)
	local ok, handle = Play(file, volume)
	if not ok then return false end
	slot.handles[#slot.handles + 1] = handle
	while #slot.handles > 2 do table.remove(slot.handles, 1) end
	return true
end

-- How long to wait before relaunching a clip of this length. See BED_JITTER.
local function BedInterval(len)
	return math.max(0.5, len - BED_OVERLAP - math.random() * BED_JITTER)
end

-- A gain for this launch: the layer's nominal level, the player's volume
-- slider, and the per-launch wobble. volumeOverride is set once at play time
-- and cannot be changed afterwards, so moving the slider only affects clips
-- that start after it moves - StartBed is re-run on change to make it immediate.
local function BedVolume(base)
	local v = (base or 1) * (db.volume or 1) * IndoorFactor("hear")
	v = v * (1 + (math.random() * 2 - 1) * BED_VOL_JITTER)
	-- Held inside 0..1. The wobble can lift a full-volume bed to 1.07, and what
	-- an out-of-range volumeOverride does on this client is not something we
	-- have probed; clipping it is free and guessing is not.
	return math.max(0, math.min(1, v))
end

-- Re-arm a one-shot timer rather than running a fixed-period ticker, because
-- the whole point is that the period is never twice the same.
local function SlotLoop(slot, len, fn)
	if slot.ticker then slot.ticker:Cancel() end
	slot.ticker = C_Timer.NewTimer(BedInterval(len), function()
		slot.ticker = nil
		fn()
	end)
end

local function CurrentBed()
	local w = W()
	if bedFallback then return w.fallbackBed.file, w.fallbackBed.len end
	local b = Preset().bed
	return b.id, b.len
end

local function PlayBedClip()
	if not ShouldRain() or not db.sound then return end
	local file, len = CurrentBed()
	if not SlotPlay(bedSlot, file, BedVolume(1)) then
		if not bedFallback then
			bedFallback = true
			msg("the client would not play Blizzard's " .. W().label ..
			    " loop; using the bundled one.")
			return PlayBedClip()
		end
		return
	end
	SlotLoop(bedSlot, len, PlayBedClip)
end

-- A second bed under the first, at a lower level and a DIFFERENT length. One
-- loop is recognisable as a loop within two or three passes; two of unequal
-- length only re-align on their common multiple, and because each relaunch is
-- independently jittered they never truly re-align at all. This is the cheapest
-- large win in the audio layer and both consults named it first.
local function PlayUnderClip()
	local u = Preset().under
	if not u or not ShouldRain() or not db.sound or bedFallback then return end
	SlotPlay(underSlot, u.id, BedVolume(u.volume))
	SlotLoop(underSlot, u.len, PlayUnderClip)
end

-- The blizzard's third loop. Nothing else in the addon has one, and nothing
-- falls back if it will not play: wind under snow is a bonus, not the bed.
local function PlayWindClip()
	local wind = Preset().wind
	if not wind or not ShouldRain() or not db.sound then return end
	SlotPlay(windSlot, wind.id, BedVolume(wind.volume or 1))
	SlotLoop(windSlot, wind.len, PlayWindClip)
end

-- Which loops we are using right now, and so must never mute.
local function LoopsInUse()
	local p, keep = Preset(), {}
	if p.bed then keep[p.bed.id] = true end
	if p.under then keep[p.under.id] = true end
	if p.wind then keep[p.wind.id] = true end
	return keep
end

-- Re-mute from scratch: unmute everything, then mute what we are not using.
-- Done wholesale on every change rather than by diffing, because a diff that
-- drifts leaves a file muted forever and the player has no way to know why
-- their rain went quiet.
local function ApplySuppression()
	if not MuteSoundFile or not UnmuteSoundFile then return end
	-- Keyed on whether we are actually playing, not merely on db.enabled. The
	-- two come apart in three ordinary cases - sound off, inside with indoors
	-- set to off, and a cinematic - and in every one of them the old test left
	-- the realm's loops muted while ComfyRain played nothing at all. Silence
	-- with no visible cause is the worst failure an audio addon has.
	local active = db.suppress and db.sound and ShouldRain()
	local keep = active and LoopsInUse() or {}
	for _, id in ipairs(AMBIENCE_LOOPS) do
		pcall(UnmuteSoundFile, id)
		if active and not keep[id] then
			pcall(MuteSoundFile, id)
		end
	end
end

local function StopBed()
	SlotStop(bedSlot)
	SlotStop(underSlot)
	SlotStop(windSlot)
	if underSlot.start then underSlot.start:Cancel() underSlot.start = nil end
	loopedKey = nil
	bedIndoor = nil
end

local function StartBed()
	StopBed()
	ApplySuppression()
	if not ShouldRain() or not db.sound then return end
	PlayBedClip()

	-- The under-bed starts a moment after the first, so the two layers' phase is
	-- decorrelated rather than every session opening on the same aligned downbeat.
	--
	-- The offset used to be `random() * len * 0.6`, which on paper spread the
	-- start across the clip's own first cycle. In practice `len` is 30 seconds
	-- for rain and 50 for snow, so the second layer could arrive up to 18 or 30
	-- seconds after the player turned the weather on - and until it did, the bed
	-- was a single thin loop. That reads as the sound being slow to start, which
	-- is what it was. The initial offset was never what decorrelates the layers
	-- anyway: each relaunch is independently jittered (see BedInterval), so they
	-- drift apart within a cycle or two regardless of where they began.
	local u = Preset().under
	if u then
		underSlot.start = C_Timer.NewTimer(math.random() * UNDER_FIRST_MAX, function()
			underSlot.start = nil
			PlayUnderClip()
		end)
	end

	if Preset().wind then PlayWindClip() end
	loopedKey = db.weather .. "/" .. db.intensity
	bedIndoor = IndoorFactor("hear")
end

--------------------------------------------------------------------------------
-- Lightning
--------------------------------------------------------------------------------

-- Thunder does not arrive on a timer, and it does not arrive on a coin flip
-- either. Real storms CLUSTER: two or three claps close together, then a long
-- quiet. A uniform draw gives neither; an exponential (Poisson) gives the
-- memorylessness but still no clustering. A log-normal gives both, because the
-- mass sits below the median - producing the bursts - while the long right tail
-- produces the lulls. Both consults named Poisson as the one that sounds wrong.
--
-- Returned as a multiple of `median`, clamped, so a freak draw can never leave
-- the player in silence for an hour or fire four claps in four seconds.
local function LogNormal(median, sigma, lo, hi)
	local u1 = math.random()
	if u1 < 1e-9 then u1 = 1e-9 end
	local n = math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * math.random())
	local m = math.exp(sigma * n)
	if m < lo then m = lo elseif m > hi then m = hi end
	return median * m
end

-- One driver, reused. A frame cannot be destroyed in this API, so creating one
-- per thunderclap leaks a frame an hour's play - and the double flash lands at
-- 0.26 s against a 0.22 s envelope, so two never overlap and one is enough.
local flashDriver

local function FlashOnce(peak, duration)
	local elapsed = 0
	flash:SetAlpha(0)
	flashDriver = flashDriver or CreateFrame("Frame")
	local driver = flashDriver
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
		-- Scaled by the same two things every other visible part of the addon
		-- is. A flash at full strength while the rain behind it is at a quarter
		-- is the one moment the overlay stops reading as weather, and it was
		-- the single loudest thing in the room with "indoors: dim" set.
		local peak = (0.14 + Preset().mist * 1.4) * db.scale * IndoorFactor()
		FlashOnce(peak, 0.22)
		if math.random() < 0.45 then
			C_Timer.After(0.26, function() FlashOnce(peak * 0.7, 0.18) end)
		end
	end
	-- Thunder trails the flash the way distance makes it. A gust has no flash
	-- to trail, so it simply arrives.
	C_Timer.After(w.flash and (0.6 + math.random() * 2.6) or 0, function()
		if not ShouldRain() or not db.thunder or not db.sound then return end
		-- Through the same gain as the bed. A volume slider that turns the rain
		-- down and leaves the thunder where it was is not a volume slider.
		local list = w.oneShots
		local vol = BedVolume(1)
		local ok = Play(list[math.random(#list)], vol)
		if not ok and w.fallbackOneShot then
			Play(w.fallbackOneShot, vol)
		end
	end)
end

local function ScheduleLightning()
	if lightningTimer then lightningTimer:Cancel() lightningTimer = nil end
	if not db.enabled or not db.thunder then return end
	-- A blizzard gusts far more often than a storm thunders. Stated per preset
	-- rather than derived from the fall speed, which is how it used to work:
	-- that quietly tied the thunder rate to a visual tuning knob, so every
	-- change to how fast the rain fell moved how often it thundered.
	local base = Preset().strikeEvery or 60
	lightningTimer = C_Timer.NewTimer(LogNormal(base, 0.62, 0.3, 3.2), function()
		lightningTimer = nil
		Strike()
		ScheduleLightning()
	end)
end

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

function ComfyRain_Refresh()
	if not overlay then return end
	UpdateTimeOfDay()
	local want = ShouldRain()
	local draw = ShouldDraw()

	fadeTarget = draw and 1 or 0
	if draw then
		overlay:Show()
		overlay:SetAlpha(fade)
	end
	ApplyAlphas()

	if want and db.sound then
		-- bedIndoor is checked alongside loopedKey, and leaving it out is why
		-- walking into an inn did not quieten the rain. volumeOverride is set
		-- once, at play time, so the gain of a clip that is already running
		-- cannot be changed - the only way to apply the indoor duck is to
		-- relaunch. Without this the duck waited for the next natural relaunch,
		-- which is up to 30 seconds for rain and 50 for snow, by which point
		-- the player has usually walked back out again.
		if not bedSlot.ticker
		   or loopedKey ~= db.weather .. "/" .. db.intensity
		   or bedIndoor ~= IndoorFactor("hear") then
			StartBed()
		end
	else
		StopBed()
		-- Turning the weather off has to hand the realm its own loops back, or
		-- a player who tried ComfyRain once is left with silent rain forever.
		ApplySuppression()
	end

	if want and db.thunder then
		if not lightningTimer then ScheduleLightning() end
	elseif lightningTimer then
		lightningTimer:Cancel()
		lightningTimer = nil
	end
end
local Refresh = ComfyRain_Refresh

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
		IndoorMode(),
		db.channel,
		indoorsNow and " |cff888888[indoors]|r" or ""))
	local real, grade = RealWeather()
	if real and real ~= "none" then
		msg(string.format("the realm's own weather here is |cff66ff66%s|r at %.2f", real, grade))
	end
end

local function Help()
	msg("commands:")
	print("  |cffffd100/comfy|r - toggle on/off")
	print("  |cffffd100/comfy rain||snow|r - which weather to draw")
	print("  |cffffd100/comfy light||normal||heavy|r - intensity")
	print("  |cffffd100/comfy monsoon|r, |cffffd100/comfy blizzard|r - the top of each, weather included")
	print("  |cffffd100/comfy auto|r - match whatever the realm says the weather is here")
	print("  |cffffd100/comfy alpha <0-1.5>|r - how visible it is")
	print("  |cffffd100/comfy speed <0.2-3>|r - how fast it falls")
	print("  |cffffd100/comfy dim <0-2>|r - how much it darkens the world (0 = off)")
	print("  |cffffd100/comfy time local|r - make it look like YOUR clock, not the realm's")
	print("  |cffffd100/comfy time +9|r, |cffffd100/comfy time 21|r, |cffffd100/comfy time off|r")
	print("  |cffffd100/comfy indoors on||off|r - draw it inside buildings too")
	print("  |cffffd100/comfy sound on||off|r, |cffffd100/comfy thunder on||off|r (gusts, in snow)")
	print("  |cffffd100/comfy channel Ambience||SFX||Master|r - which volume slider owns it")
	print("  |cffffd100/comfy stop|r - everything off, including the light, in one go")
	print("  |cffffd100/comfy reset|r - back to defaults; |cffffd100reset look||sound||time|r for one part")
	print("  |cffffd100/comfy share|r - a string to send someone; |cffffd100/comfy import|r to paste theirs")
	print("  |cffffd100/comfy undo|r - put your own settings back after an import")
	print("  |cffffd100/comfy density|r - is the client even allowed to draw real weather?")
	print("  |cffffd100/comfy watch on|r - shout when the game's OWN rain starts, then just play")
	print("  |cffffd100/comfy probe|r - answer the client-gated questions before the beta dies")
	print("  |cffffd100/comfy status|r")
end

-- source is "ui" when the settings window issued this rather than the player.
-- The second argument a real slash handler receives is the chat edit box, a
-- table, so the sentinel can never collide with it.
local function HandleSlash(input, source)
	-- Keep the original case of the argument as well as the lowercased one. Every
	-- command here wants the lowercase version, except import, whose argument is
	-- a profile string somebody else generated: lowercasing it would turn
	-- channel=Ambience into a value no enum has and silently reset their sound.
	local raw = (input or ""):gsub("^%s+", ""):gsub("%s+$", "")
	local rawArg = raw:match("^%S*%s*(.-)$")
	input = raw:lower()
	local cmd, arg = input:match("^(%S*)%s*(.-)$")

	if cmd == "" then
		db.enabled = not db.enabled
	elseif WEATHER[cmd] then
		db.weather, db.enabled = cmd, true
		NormaliseIntensity()
		StartBed()
		ScheduleLightning()
	-- "blizzard" and "monsoon" each name a weather as well as an intensity, so
	-- they switch both at once: nobody typing /comfy blizzard wants rain.
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
		-- Name the second thing it draws. The light grading is the part a
		-- player does not associate with a rain addon, so "the screen went
		-- dark and I can't undo it" is a support ticket waiting to happen
		-- unless turning it off says out loud that the light came back.
		if db.timeMode ~= "off" then
			local at = (db.timeMode == "fixed" and ("%02d:00"):format(db.timeFixed))
				or (db.timeMode == "offset" and ("%+g h from realm time"):format(db.timeOffset))
				or "your own clock"
			msg(db.enabled
				and ("the light is held at " .. at ..
				     " again - |cffffd100/comfy time off|r for the realm's own")
				or "the light is back to the realm's own.")
		end
	elseif cmd == "alpha" then
		local v = tonumber(arg)
		if not v then msg("usage: /comfy alpha 0.75") return end
		db.scale = math.max(0, math.min(1.5, v))
	elseif cmd == "speed" then
		local v = tonumber(arg)
		if not v then msg("usage: /comfy speed 1.4") return end
		db.speed = math.max(0.2, math.min(3, v))
	elseif cmd == "time" then
		local sub, rest = arg:match("^(%S*)%s*(.-)$")
		if sub == "off" or sub == "" then
			db.timeMode = "off"
		elseif sub == "local" then
			db.timeMode = "local"
		elseif sub == "strength" then
			local v = tonumber(rest)
			if not v then msg("usage: /comfy time strength 0.7") return end
			db.timeStrength = math.max(0, math.min(1, v))
		elseif sub:match("^[+-]%d+%.?%d*$") then
			db.timeMode, db.timeOffset = "offset", tonumber(sub)
		elseif tonumber(sub) then
			db.timeMode, db.timeFixed = "fixed", tonumber(sub) % 24
		else
			msg("usage: |cffffd100/comfy time local|r (match your own clock), " ..
			    "|cffffd100+9|r / |cffffd100-5|r (shift by hours), " ..
			    "|cffffd10021|r (hold one hour), |cffffd100off|r, " ..
			    "|cffffd100strength 0.7|r")
			return
		end
		UpdateTimeOfDay()
	-- "gloom" was the name until the rename; it still works and is not advertised.
	elseif cmd == "dim" or cmd == "gloom" then
		local v = tonumber(arg)
		if not v then msg("usage: /comfy dim 0.5  (0 turns the darkening off)") return end
		db.gloom = math.max(0, math.min(2, v))
	elseif cmd == "gust" or cmd == "wind" then
		local v = tonumber(arg)
		if not v then msg("usage: /comfy gust 0.5  (0 is dead calm)") return end
		db.gust = math.max(0, math.min(2, v))
	elseif cmd == "suppress" then
		-- Silence the realm's own weather loop so ours is the only one playing.
		-- Off by default: it mutes files for the whole client, and an addon that
		-- quietly changes sounds outside its own feature is an addon people
		-- distrust. See AMBIENCE_LOOPS for why it cannot simply mute everything.
		db.suppress = (arg == "on")
		StartBed()
		msg(db.suppress
			and "suppressing the realm's own weather loops while ComfyRain is on."
			or  "the realm's own weather loops are audible again.")
	elseif cmd == "volume" or cmd == "vol" then
		local v = tonumber(arg)
		if not v then msg("usage: /comfy volume 0.5  (0 is silent)") return end
		db.volume = math.max(0, math.min(1, v))
		-- Gain is baked in at play time, so the running clips keep their old
		-- level until they reloop. Restart the bed so the slider feels live.
		StartBed()
	elseif cmd == "minimap" then
		db.minimap = (arg ~= "off")
		if ComfyRain_Minimap then pcall(ComfyRain_Minimap) end
		msg(db.minimap and "minimap button shown." or
			"minimap button hidden. |cffffd100/comfyrain|r still opens the window.")
	elseif cmd == "sound" then
		db.sound = (arg ~= "off")
	elseif cmd == "thunder" then
		db.thunder = (arg ~= "off")
		ScheduleLightning()
	elseif cmd == "indoors" then
		if arg == "on" or arg == "off" or arg == "dim" then
			db.indoors = arg
		else
			msg("usage: /comfy indoors off | dim | on  (dim is the default: " ..
			    "quiet and faint, the way weather is from inside)")
			return
		end
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
			msg("|cffffd100/comfy density on|r raises both so the realm's own weather renders")
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
		if ComfyRain_Probe then
			ComfyRain_Probe(arg)
		else
			msg("Probe.lua is not installed.")
		end
		return
	elseif cmd == "where" then
		-- Two API calls and what the addon concluded from them. This exists
		-- because IsIndoors() and IsOutdoors() are not complements and the
		-- third state - neither one true - is the whole difficulty: it is a
		-- real awning in the open world and it may also be an open street in a
		-- city built as one big WMO. Those want opposite answers and no amount
		-- of reading the source settles which this client reports where.
		-- Type this inside and then outside and the question is answered.
		local function yn(v) return v and "|cff66ff66yes|r" or "|cffff6666no|r" end
		msg(string.format("IsIndoors %s  IsOutdoors %s  -> %s",
			yn(IsIndoors()), yn(IsOutdoors()),
			Sheltered() and "SHELTERED" or "open sky"))
		msg(string.format("addon state: %s, mode %s - seen |cffffd100%d%%|r, heard |cffffd100%d%%|r",
			indoorsNow and "indoors" or "outdoors", IndoorMode(),
			math.floor(IndoorFactor() * 100 + 0.5),
			math.floor(IndoorFactor("hear") * 100 + 0.5)))
		local sub = GetSubZoneText()
		local _, px, py = MapPos()
		msg(string.format("   %s%s%s   zoom %.1f yd",
			GetRealZoneText() or "?",
			(sub and sub ~= "") and (" / " .. sub) or "",
			px and string.format("  |cffffd100%.1f, %.1f|r", px * 100, py * 100) or "",
			Readable(GetCameraZoom and GetCameraZoom()) or -1))
		WhereLog("asked")
		msg(string.format("logged; %d doorway readings saved so far", #(db.where or {})))
		return
	elseif cmd == "zoom" then
		if arg == "on" or arg == "off" then db.zoom = (arg == "on") end
		msg(string.format("camera zoom changes the rain: |cffffd100%s|r (now %.1f yd)",
			db.zoom and "on" or "off",
			Readable(GetCameraZoom and GetCameraZoom()) or -1))
		return
	-- "calib" is an abbreviation of a word that does not say what it does, and
	-- it was the one command that had to be explained twice. The name stays
	-- because it is in the notes and the logs, but "watch" is what it is.
	elseif cmd == "calib" or cmd == "calibrate" or cmd == "watch" then
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
	elseif cmd == "ui" or cmd == "config" or cmd == "options" or cmd == "settings" then
		if not ComfyRain_Panel then
			msg("UI.lua is not installed.")
		elseif not pcall(ComfyRain_Panel, "toggle") then
			msg("|cffff6666the settings window would not open.|r")
		end
		return
	elseif cmd == "reset" then
		-- Only the settings the panel owns. The calibration log and the probe
		-- results are evidence, not preferences, and a reset button that threw
		-- away a week of weather observations would be a bug with a label on it.
		local part = arg:match("^%S*") or ""
		if part == "" or part == "all" then
			for k, v in pairs(DEFAULTS) do db[k] = v end
			msg("every setting reset to defaults.")
		elseif SECTIONS[part] then
			-- One section at a time, because "I have the sound how I want it
			-- and the look is a mess" is the normal case, and a single Reset
			-- that takes the sound with it is a button people learn not to
			-- press.
			for _, k in ipairs(SECTIONS[part]) do db[k] = DEFAULTS[k] end
			msg(part .. " settings reset to defaults.")
		else
			msg("usage: |cffffd100/comfy reset|r, or " ..
			    "|cffffd100/comfy reset look||sound||time|r")
			return
		end
	elseif cmd == "stop" then
		-- The one command that means everything, which is what somebody looking
		-- at a screen they cannot explain actually wants. /comfy off used to
		-- leave the light grading up; it does not any more, but a player who
		-- has been bitten once needs a switch they can believe in rather than a
		-- promise that the other one is fixed now.
		db.enabled, db.timeMode = false, "off"
		msg("everything off: no weather, no sound, the realm's own light.")
	elseif cmd == "export" or cmd == "share" then
		-- The window, if it loaded, puts the string in a box that is already
		-- selected, because a chat line cannot be copied out of the chat frame
		-- without dragging across it. pcall for the same reason as `changed`
		-- below: a broken window must not take the command line with it.
		local text = ExportProfile()
		if not (ComfyRainAPI.share and pcall(ComfyRainAPI.share, text)) then
			msg("copy this line:")
			msg(text)
		end
		return
	elseif cmd == "about" or cmd == "version" then
		-- Read from the TOC rather than kept in a constant here, because
		-- @project-version@ is substituted by the packager at release time and
		-- a number typed into the Lua would be whatever it was when somebody
		-- last remembered. Only the C_AddOns form exists on this client; the
		-- bare GetAddOnMetadata global is not in WowB.exe at all, so calling it
		-- would have been a nil-index on the one command whose whole job is to
		-- be reassuring.
		local function meta(field)
			if C_AddOns and C_AddOns.GetAddOnMetadata then
				local ok, v = pcall(C_AddOns.GetAddOnMetadata, ADDON, field)
				if ok and v and v ~= "" then return v end
			end
		end
		local ver = meta("Version")
		-- The packager leaves this literal in an unreleased working copy.
		if not ver or ver:find("project%-version") then ver = "dev build" end
		msg("|cffffd100Comfy Rain|r " .. ver .. ", by |cffffd100" ..
			(meta("Author") or "LibruaryNFT") .. "|r. " ..
			(meta("X-License") or "MIT") .. " licensed.")
		msg("Bugs, requests and the source: |cffffd100" .. HOMEPAGE .. "|r")
		-- Same reason as share: a chat line cannot be copied out of the chat
		-- frame without dragging across it, and the whole point of printing a
		-- URL is that somebody can get it into a browser.
		if not (ComfyRainAPI.share and
		        pcall(ComfyRainAPI.share, HOMEPAGE,
		              "Ctrl-C copies it. Paste it into your browser.")) then
			msg("|cff999999(select the line above to copy it)|r")
		end
		return
	elseif cmd == "import" then
		if arg == "" then
			if ComfyRainAPI.share and pcall(ComfyRainAPI.share, nil) then return end
			msg("usage: |cffffd100/comfy import ComfyRain1:...|r")
			return
		end
		-- Taken BEFORE the import, and only kept if the import actually landed.
		-- The thing that stops somebody trying a profile a friend sent them is
		-- expecting to lose their own, and the addon already knows how to write
		-- its settings down - so the answer is not a preview dialog listing
		-- twenty values in a 330px window, it is being able to get back.
		-- Survives a reload because "import, /reload to be sure, change my
		-- mind" is the obvious way to use this.
		local before = ExportProfile()
		local n, why = ImportProfile(rawArg)
		if not n then
			msg("|cffff6666" .. tostring(why) .. "|r")
			return
		end
		db.undo = before
		msg(string.format("imported %d settings%s. |cffffd100/comfy undo|r " ..
			"puts yours back.", n,
			(type(why) == "number" and why > 0)
				and (", ignored " .. why .. " this version does not know") or ""))
	elseif cmd == "undo" then
		if type(db.undo) ~= "string" then
			msg("nothing to undo: no profile has been imported.")
			return
		end
		-- Cleared first, and the saved string held locally, so an undo that
		-- somehow fails cannot leave a stale one armed to restore settings from
		-- two imports ago. Undo is one step on purpose.
		local text = db.undo
		db.undo = nil
		local n, why = ImportProfile(text)
		if not n then
			msg("|cffff6666could not put it back: " .. tostring(why) .. "|r")
			return
		end
		msg(string.format("put your own %d settings back.", n))
	elseif cmd == "status" then
		Status()
		return
	else
		Help()
		return
	end

	Refresh()
	-- An open panel has to follow a typed command, or the two disagree in front
	-- of the player and the window is the thing they stop trusting.
	-- pcall: the window is a separate file, and a broken window may not take
	-- the command line down with it.
	if ComfyRainAPI.changed then pcall(ComfyRainAPI.changed) end
	if source ~= "ui" then Status() end
end

-- The panel drives the addon through exactly this and nothing else. Everything
-- the window can do is therefore a command that can also be typed, the two can
-- never drift apart, and the whole settings surface stays under the slash
-- parser's existing tests.
ComfyRainAPI = {
	Weather      = WEATHER,
	Command      = function(input) HandleSlash(input, "ui") end,
	DB           = function() return db end,
	Status       = function() Status() end,
	-- The window needs the section map to put a Reset beside each heading, and
	-- the export string to put in a box. Both are read-only to it: importing
	-- still goes through the slash parser like everything else.
	Sections     = SECTIONS,
	SectionOrder = SECTION_ORDER,
	-- So the per-slider resets can grey out a value already sitting on its
	-- default without the window keeping a second copy of these numbers.
	Defaults     = DEFAULTS,
	Export       = function() return ExportProfile() end,
}

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
		-- The addon was AlwaysRain until 2026-10-14 and Duskfall until
		-- 2026-10-19. Each name left its settings in a global named after
		-- itself, which exists only if that old folder is still installed and
		-- loaded first (## OptionalDeps). Strangers have neither, so this is a
		-- no-op for them. Newest first: if somebody has both, Duskfall's
		-- settings are the ones they were actually using.
		--
		-- Wrapped, because an old table that is malformed must cost the user their
		-- settings and nothing else. Bricking the addon during a rename is the
		-- stupidest available way to lose somebody on day one.
		-- Type test, not `or {}`: a SavedVariables file truncated by a client
		-- crash can read back as a string or a number, and those are both
		-- truthy. We already guard the OLD tables that way just below; our own
		-- is no less likely to be the half-written one.
		if type(ComfyRainDB) ~= "table" then ComfyRainDB = {} end
		if not ComfyRainDB.migrated then
			for _, old in ipairs({ { "Duskfall", DuskfallDB },
			                       { "AlwaysRain", AlwaysRainDB } }) do
				if type(old[2]) == "table" then
					local ok = pcall(function()
						for k, v in pairs(old[2]) do
							if ComfyRainDB[k] == nil then ComfyRainDB[k] = v end
						end
					end)
					ComfyRainDB.migrated = true
					msg(ok and ("settings carried over from " .. old[1] .. ".")
					       or ("|cffff9900could not read the old " .. old[1]
					           .. " settings, starting fresh.|r"))
				end
			end
		end

		db = ComfyRainDB
		SanitiseProfile()
		BuildOverlay()

		SLASH_COMFYRAIN1 = "/comfy"
		SLASH_COMFYRAIN2 = "/rain"          -- permanent alias, not deprecated
		SlashCmdList.COMFYRAIN = HandleSlash

		-- The long name opens the window rather than toggling the weather.
		-- Nobody types eight letters to flip a switch, and a settings window
		-- nobody can find is the single most common reason an atmosphere addon
		-- is uninstalled in its first two minutes.
		SLASH_COMFYRAINUI1 = "/comfyrain"
		SLASH_COMFYRAINUI2 = "/comfyui"
		-- The window is a separate file and is allowed to be missing or broken.
		-- Neither may cost the player the addon, so every entry into it is
		-- guarded and failure falls back to the thing that always works.
		SlashCmdList.COMFYRAINUI = function()
			if not ComfyRain_Panel then return HandleSlash("help") end
			local ok, err = pcall(ComfyRain_Panel, "toggle")
			if not ok then
				msg("|cffff6666the settings window would not open|r: " .. tostring(err))
				HandleSlash("help")
			end
		end

		-- Onboarding, once ever, and SILENT after that. An addon that greets the
		-- player at every login is a line of chat spam 300 times a year in
		-- exchange for information they needed once. The window itself is the
		-- introduction; the printed line is only there for the case where the
		-- window could not be built.
		-- The minimap button is the only way in that does not require knowing a
		-- slash command exists, which is the whole problem with slash commands.
		if ComfyRain_Minimap then pcall(ComfyRain_Minimap) end

		-- A weather watch has to survive a /reload. The event frame and the
		-- calibOn flag are both upvalues and die with the Lua state, so before
		-- this the watch stopped dead and said nothing: half an hour of walking
		-- would be logged as nothing, and the raised graphics CVars could never
		-- be put back because what they used to be died with them too. The
		-- probe asks for a /reload outright, so this is the normal case here
		-- rather than an edge one.
		if db.watching then CalibStart(true) end

		if not db.seenUI then
			db.seenUI = true
			-- Delayed, because the window should land after the world has
			-- drawn rather than on top of a loading screen.
			C_Timer.After(4, function()
				if ComfyRain_Panel and pcall(ComfyRain_Panel, "show") then return end
				msg("loaded. |cffffd100/comfyrain|r opens the settings window, " ..
				    "|cffffd100/comfy|r toggles the weather.")
			end)
		end

	elseif event == "CINEMATIC_START" or event == "PLAY_MOVIE" then
		cinematic = true
		Refresh()
	elseif event == "CINEMATIC_STOP" or event == "STOP_MOVIE" then
		cinematic = false
		Refresh()
	else
		if not db then return end

		-- A loading screen stops every sound the client is playing, and it does
		-- it below us: no event, no error, the handles simply stop making
		-- noise. The Lua side survives it untouched, so bedSlot.ticker is still
		-- there and Refresh concludes the bed is already running and leaves it
		-- alone. Result: hearth into a city during rain and the rain is silent
		-- until the ticker's next relaunch, which is up to 30 seconds for rain
		-- and 50 for snow. Reported from live play after a hearth to Stormwind.
		--
		-- Tearing the bed down first is what makes Refresh rebuild it, rather
		-- than adding a second way to start one.
		if event == "PLAYER_ENTERING_WORLD" then StopBed() end

		indoorsNow = Sheltered()
		indoorsSince = nil
		Refresh()
	end
end)

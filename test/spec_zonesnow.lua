-- Rain falls as snow on a snowy map (Winterspring, Dun Morogh, Alterac), and is
-- rain again on the way out, without the player's own choice being rewritten.

local H = require("harness")
local it, eq, gt = H.it, H.eq, H.gt

local ELWYNN, WINTERSPRING = 1429, 1452
local SNOW_MEDIUM = 538989
local RAIN_FILES = { 538981, 538982, 538983 }   -- medium, heavy, light

local function bedsSince(w, from)
	local out = {}
	for i = from + 1, #w.mock.sounds do
		local s = w.mock.sounds[i]
		if not s.stop and s.ok ~= false then out[s.file] = (out[s.file] or 0) + 1 end
	end
	return out
end

local function walk(w, map)
	w.mock.state.uiMapID = map
	w:advance(1.0, 0.1)
end

it("zone snow: rain in Elwynn, snow in Winterspring, rain again on the way back", function()
	local w = H.world()
	w:slash("gust 0")
	walk(w, ELWYNN)
	eq(w.env.ComfyRainAPI.WeatherName(), "rain", "positive control: Elwynn rains")

	walk(w, WINTERSPRING)
	eq(w.env.ComfyRainAPI.WeatherName(), "snow", "Winterspring snows")
	eq(w:db().weather, "rain", "the player's own choice is untouched")
	local from = #w.mock.sounds
	w:advance(60, 0.1)
	local beds = bedsSince(w, from)
	gt(beds[SNOW_MEDIUM] or 0, 0, "the snow loop plays")
	for _, f in ipairs(RAIN_FILES) do eq(beds[f], nil, "no rain loop plays: " .. f) end

	walk(w, ELWYNN)
	eq(w.env.ComfyRainAPI.WeatherName(), "rain", "out of Winterspring it rains again")
	eq(#w.mock.errors, 0, "errors")
end)

it("zone snow: /comfy zonesnow off keeps rain in Winterspring", function()
	local w = H.world()
	w:slash("zonesnow off")
	walk(w, WINTERSPRING)
	eq(w.env.ComfyRainAPI.WeatherName(), "rain", "off means rain everywhere")
	w:slash("zonesnow on")
	w:advance(0.5, 0.1)
	eq(w.env.ComfyRainAPI.WeatherName(), "snow", "and on puts the snow back")
end)

it("zone snow: a monsoon in Winterspring is a blizzard, and no thunder flashes", function()
	local w = H.world()
	w:slash("monsoon")
	walk(w, WINTERSPRING)
	eq(w.env.ComfyRainAPI.Weather[w.env.ComfyRainAPI.WeatherName()].flash, false, "snow has no lightning")
	eq(w:db().intensity, "monsoon", "the setting stays monsoon for the way out")
end)

it("zone snow: someone who chose snow keeps snow everywhere", function()
	local w = H.world()
	w:slash("snow")
	walk(w, ELWYNN)
	eq(w.env.ComfyRainAPI.WeatherName(), "snow", "snow in Elwynn when asked for")
end)

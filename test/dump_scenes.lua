#!/usr/bin/env lua
-- What every setting puts on screen, one JSON object per line, for
-- tools/perceive.py to render and compare.
--
--   lua test/dump_scenes.lua
--
-- The suite's own checks ask whether the addon sent the renderer the numbers
-- it meant to. This file exists for the other question, whether two settings
-- a player can choose between actually look different, and that needs the
-- art: the same alpha change is a different picture on a sheet whose faint
-- flakes are already visible than on one whose are not.
--
-- Each row is a fresh world with commands typed into it, grouped the way the
-- window groups its choices. `kind` tells perceive.py how to judge a group:
--   steps   an ordered ladder (intensity): each step has to be a different
--           amount of weather, judged on the flakes themselves
--   choices options the player picks between: each has to look different
--           from every other in some way, flakes or light
--   range   a slider: its two ends have to look different
--   toggle  each row against the first, which is Off: two ways of turning a
--           thing on may land on the same picture, but neither may look Off
--
-- `listen` keeps a row running that many more seconds and reports every file
-- that started meanwhile, for sounds that come and go: thunder and gusts.

local here = arg[0]:match("^(.*)/[^/]*$") or "."
package.path = here .. "/?.lua;" .. here .. "/../?.lua;" .. package.path
local H = require("harness")

local function json(v)
	local t = type(v)
	if t == "number" then
		if v ~= v or v == math.huge or v == -math.huge then return "null" end
		return string.format("%.6g", v)
	elseif t == "string" then
		return '"' .. v:gsub('\\', '\\\\'):gsub('"', '\\"') .. '"'
	elseif t == "boolean" then
		return tostring(v)
	elseif t == "table" then
		if #v > 0 or next(v) == nil then
			local out = {}
			for i = 1, #v do out[i] = json(v[i]) end
			return "[" .. table.concat(out, ",") .. "]"
		end
		local keys, out = {}, {}
		for k in pairs(v) do keys[#keys + 1] = tostring(k) end
		table.sort(keys)
		for _, k in ipairs(keys) do out[#out + 1] = json(k) .. ":" .. json(v[k]) end
		return "{" .. table.concat(out, ",") .. "}"
	end
	return "null"
end

local GROUPS = {
	{ group = "Rain intensity", kind = "steps", rows = {
		{ "light", "rain", "light" }, { "normal", "rain", "normal" },
		{ "heavy", "rain", "heavy" }, { "monsoon", "rain", "monsoon" } } },
	{ group = "Snow intensity", kind = "steps", rows = {
		{ "light", "snow", "light" }, { "normal", "snow", "normal" },
		{ "heavy", "snow", "heavy" }, { "blizzard", "snow", "blizzard" } } },
	{ group = "Type", kind = "choices", rows = {
		{ "Off", "off" }, { "Rain", "rain" }, { "Snow", "snow" } } },
	{ group = "Scenes (/comfy preset)", kind = "choices", rows = {
		{ "cozy", "preset cozy" }, { "storm", "preset storm" },
		{ "snow", "preset snow" }, { "overcast", "preset overcast" },
		{ "dusk", "preset dusk" }, { "night", "preset night" } } },
	{ group = "Indoors, standing inside", kind = "choices",
	  state = { indoors = true }, rows = {
		{ "Off", "indoors off" }, { "Dim", "indoors dim" }, { "On", "indoors on" } } },
	-- weatherDensity too: C_Weather reports rain on a client drawing none,
	-- and the addon rightly ignores that (spec_visuals).
	{ group = "Hide when game rains, real rain falling", kind = "choices",
	  state = { weather = { type = 1, intensity = 0.8 } }, cvars = { weatherDensity = "3" }, rows = {
		{ "ticked", "defer on" }, { "unticked", "defer off" } } },
	-- The slider's ends, 0 and 23, are an hour apart on the clock, so the
	-- check is the four parts of the day it can be set to instead.
	{ group = "Hour, fixed, realm at noon", kind = "choices",
	  state = { gameHour = 12 }, rows = {
		{ "night 0", "time 0" }, { "dawn 6", "time 6" }, { "day 12", "time 12" },
		{ "dusk 18", "time 18" } } },
	{ group = "Time of Day mode, realm at noon", kind = "toggle",
	  state = { gameHour = 12 }, rows = {
		{ "Off", "time off" }, { "Shift +9", "time +9" }, { "Fixed 21", "time 21" } } },
	{ group = "Play sounds", kind = "choices", rows = {
		{ "on", "sound on" }, { "off", "sound off" } } },
	{ group = "Volume", kind = "range", rows = {
		{ "0", "volume 0" }, { "50%", "volume 0.5" }, { "100%", "volume 1" } } },
	{ group = "Volume, a quiet step", kind = "range", rows = {
		{ "60%", "volume 0.6" }, { "85%", "volume 0.85" } } },
	{ group = "Thunder, rain", kind = "choices", listen = 240, rows = {
		{ "on", "thunder on" }, { "off", "thunder off" } } },
	{ group = "Gusts, snow", kind = "choices", listen = 240, rows = {
		{ "on", "snow", "thunder on" }, { "off", "snow", "thunder off" } } },
	{ group = "Volume follows", kind = "choices", rows = {
		{ "Ambience", "channel ambience" }, { "SFX", "channel sfx" },
		{ "Master", "channel master" }, { "Music", "channel music" },
		{ "Dialog", "channel dialog" } } },
	{ group = "Strength, fixed 21, realm at noon", kind = "range",
	  state = { gameHour = 12 }, rows = {
		{ "0%", "time 21", "time strength 0" }, { "50%", "time 21", "time strength 0.5" },
		{ "100%", "time 21", "time strength 1" } } },
}

for _, g in ipairs(GROUPS) do
	for i, row in ipairs(g.rows) do
		local w = H.world({ state = g.state })
		for k, v in pairs(g.cvars or {}) do w.mock.cvars[k] = v end
		for c = 2, #row do w:slash(row[c]) end
		w:advance(2, 0.05)
		local p = w:perceivable()
		if g.listen then
			local first, seen, started = #w.mock.sounds + 1, {}, {}
			w:advance(g.listen, 0.25)
			for k = first, #w.mock.sounds do
				local snd = w.mock.sounds[k]
				local f = snd.ok and tostring(snd.file)
				if f and not seen[f] then seen[f] = true; started[#started + 1] = f end
			end
			table.sort(started)
			p.started = started
		end
		p.group, p.kind, p.label, p.index = g.group, g.kind, row[1], i
		p.weather, p.intensity = w:db().weather, w:db().intensity
		io.write(json(p), "\n")
	end
end

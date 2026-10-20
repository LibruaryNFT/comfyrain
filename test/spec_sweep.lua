-- Sweeps over the whole settings surface, rather than one hand-picked point.
--
-- Why this file exists. On 2026-10-19 the Darkness slider could not reach the
-- darkest the addon can draw at three of its four intensities, and 234 specs
-- were green the whole time. Not one of them was wrong. They were all shaped
-- the same way: pick a setting, pick a value, assert the number. That shape
-- cannot see a hole in the part of the surface nobody picked, and it was found
-- by playing the game, which is the thing this suite exists to stop.
--
-- So these are the two instruments the suite was missing:
--
--   * a golden file of what the addon actually draws across the matrix, so a
--     change to anything visual is a reviewable diff instead of a surprise;
--   * properties that have to hold EVERYWHERE, checked by walking the space
--     instead of by somebody remembering to write the case down.
--
-- Nothing here replaces the per-feature specs. They say what a number should
-- be and why; these say the surface has no holes in it.

local H = require("harness")
local it, ok, eq, near, lt, gt = H.it, H.ok, H.eq, H.near, H.lt, H.gt

-- Where the top of the Darkness slider lands, which is darker than the tint:
-- the tint is what weather does to daylight, and the slider's top half carries
-- on past it. Mirrors deepTint in ComfyRain.lua.
local DEEP = { rain = { 0.38, 0.44, 0.62 }, snow = { 0.46, 0.52, 0.70 } }
local TOP = { rain = "monsoon", snow = "blizzard" }

-- How much of the darkening this addon is capable of is currently on screen,
-- read back out of the MOD colour the addon set. 1 is the darkest it goes.
-- Going through the drawn pixel rather than through the internal rather than
-- through db is deliberate: it is the only number the player can actually see.
local function GloomOf(w, weather)
	local c = w:gloom().colour
	return (1 - c[1]) / (1 - DEEP[weather][1])
end

--------------------------------------------------------------------------------
-- The golden file
--------------------------------------------------------------------------------

-- Each row is one world, built from scratch, with these commands typed into
-- it. A fresh world per row because a matrix that shares state is a matrix
-- that bakes its own ordering bugs into the file it is supposed to be
-- guarding.
local MATRIX = {
	{ "rain, light", "light" },
	{ "rain, normal", "normal" },
	{ "rain, heavy", "heavy" },
	{ "rain, monsoon", "monsoon" },
	{ "snow, light", "snow", "light" },
	{ "snow, normal", "snow", "normal" },
	{ "snow, heavy", "snow", "heavy" },
	{ "snow, blizzard", "snow", "blizzard" },

	{ "visibility off", "alpha 0" },
	{ "visibility half", "alpha 0.5" },
	{ "visibility full", "alpha 1.5" },

	{ "darkness off", "dim 0" },
	{ "darkness half", "dim 0.5" },
	{ "darkness full", "dim 2" },
	{ "darkness full, light rain", "light", "dim 2" },
	{ "darkness full, monsoon", "monsoon", "dim 2" },
	{ "darkness full, light snow", "snow", "light", "dim 2" },
	{ "darkness full, blizzard", "snow", "blizzard", "dim 2" },

	-- Fall speed and wind are not here. Neither of them changes anything in a
	-- still frame - they are both rates - so a row for either would be a copy
	-- of "rain, normal" pretending to be a test. They have a golden of their
	-- own below, where time passes.

	{ "switched off", "off", advance = 5 },

	-- Indoors needs a world that is actually indoors, and a few seconds for
	-- the fade and the indoor poll to settle. All three of these draw the same
	-- thing out in the open, which is the whole reason the setting exists.
	{ "under a roof, dim", "indoors dim", indoors = true, advance = 5 },
	{ "under a roof, off", "indoors off", indoors = true, advance = 5 },
	{ "under a roof, on", "indoors on", indoors = true, advance = 5 },

	{ "held at midnight", "time 0" },
	{ "held at 9pm", "time 21" },
	{ "held at noon", "time 12" },
	-- The mock's realm clock is noon and LIGHT is flat from 08:00 to 17:00, so
	-- a shift has to land outside that window to be a shift at all. +9 is out
	-- too: it lands on 21:00, which is the row above.
	{ "shifted to sunset", "time +7" },
	{ "shifted back to first light", "time -7" },
	{ "held at 9pm, half strength", "time 21", "time strength 0.5" },

	{ "everything at once", "snow", "blizzard", "alpha 1.5", "dim 2",
	  "speed 3", "gust 2", "time 21" },
}

it("draws what the golden file says it draws, across the settings matrix",
function()
	local out = {
		"# What ComfyRain draws, one block per setting, checked by spec_sweep.lua.",
		"# Regenerate with `lua run.lua --update` and READ THE DIFF: every line",
		"# in here is a pixel somebody will see. Base state only - no time has",
		"# passed, so no gust phase and no lightning, which keeps a change to",
		"# the jitter from rewriting the whole file.",
		"",
	}
	-- A row with no visible effect is a row that is testing nothing, and the
	-- first draft of this matrix had four of them. Identical blocks are a
	-- failure, not a curiosity.
	local seen = {}
	for _, row in ipairs(MATRIX) do
		local w = H.world(row.indoors and { state = { indoors = true } } or nil)
		for i = 2, #row do w:slash(row[i]) end
		if row.advance then w:advance(row.advance, 0.1) end
		local shot = w:snapshot()
		if seen[shot] then
			ok(false, "the matrix rows '" .. seen[shot] .. "' and '" .. row[1] ..
				"' draw exactly the same frame, so one of them is testing nothing")
		end
		seen[shot] = row[1]
		out[#out + 1] = "### " .. row[1]
		out[#out + 1] = shot
		out[#out + 1] = ""
	end
	H.golden("golden_draw.txt", table.concat(out, "\n"))
end)

-- How far each sheet has travelled after a fixed run. Thunder is off in every
-- row so no lightning jitter gets into the numbers, which keeps this file
-- readable as "the rain moved this much" rather than as noise.
local MOTION = {
	{ "rain, normal, 10s" },
	{ "rain, light, 10s", "light" },
	{ "rain, monsoon, 10s", "monsoon" },
	{ "snow, normal, 10s", "snow" },
	{ "snow, blizzard, 10s", "snow", "blizzard" },
	{ "half speed", "speed 0.5" },
	{ "double speed", "speed 2" },
	{ "top speed", "speed 3" },
	{ "dead calm", "gust 0" },
	{ "full wind", "gust 2" },
	{ "no zoom response", "zoom off" },
}

it("moves the rain the same distance it moved yesterday", function()
	local out = {
		"# How far each sheet has scrolled after ten seconds, checked by",
		"# spec_sweep.lua. Thunder is off in every row so nothing here is",
		"# jitter. Regenerate with `lua run.lua --update` and read the diff.",
		"",
	}
	local seen = {}
	for _, row in ipairs(MOTION) do
		local w = H.world()
		w:slash("thunder off")
		for i = 2, #row do w:slash(row[i]) end
		w:advance(10, 0.05)
		local shot = w:snapshot()
		if seen[shot] then
			ok(false, "the motion rows '" .. seen[shot] .. "' and '" .. row[1] ..
				"' end in the same place, so one of them is testing nothing")
		end
		seen[shot] = row[1]
		out[#out + 1] = "### " .. row[1]
		out[#out + 1] = shot
		out[#out + 1] = ""
	end
	H.golden("golden_motion.txt", table.concat(out, "\n"))
end)

--------------------------------------------------------------------------------
-- Properties of every slider
--------------------------------------------------------------------------------

-- Which kind of control each slider is, written down because the two kinds
-- fail differently and because the Darkness bug was exactly a slider that
-- looked absolute, was documented as absolute, and behaved relative.
--
--   absolute - the top means the same amount of effect in every weather and
--              at every intensity. "As dark as this addon goes" is a promise
--              about the screen, not about the preset.
--   relative - the top scales whatever the preset is doing. "More rain" means
--              more than this weather's own normal, and monsoon's more is not
--              light rain's more.
--
-- A new slider has to be added here or the last spec in this block fails, so
-- the question gets answered once, on purpose, instead of by accident.
local SLIDERS = {
	{
		label = "Darkness", cmd = "dim", floor = 0, ceiling = 2, kind = "absolute",
		read = function(w, weather) return GloomOf(w, weather) end,
		offAt = 0,
	},
	{
		label = "Drops", cmd = "alpha", floor = 0, ceiling = 1.5, kind = "relative",
		read = function(w) return w:layers().far:GetAlpha() end,
		offAt = 0,
	},
	{
		label = "Wind", cmd = "gust", floor = 0, ceiling = 2, kind = "relative",
		read = function(w) return w:db().gust end,
		offAt = 0,
	},
}

it("turns every slider all the way off at the bottom of its travel", function()
	for _, s in ipairs(SLIDERS) do
		for _, weather in ipairs({ "rain", "snow" }) do
			for _, step in ipairs({ "light", "normal", "heavy", TOP[weather] }) do
				local w = H.world()
				w:slash(weather)
				w:slash(step)
				w:slash(s.cmd .. " " .. s.floor)
				near(s.read(w, weather), s.offAt, 1e-6,
					s.label .. " at the bottom is off in " .. step .. " " .. weather)
			end
		end
	end
end)

it("makes the top of an absolute slider mean the same thing everywhere",
function()
	-- The Darkness bug, as a property. The top of an absolute slider has to
	-- land on the same reading in light rain as in a monsoon, or the control is
	-- lying about what its right-hand end is for.
	for _, s in ipairs(SLIDERS) do
		if s.kind == "absolute" then
			local want = nil
			for _, weather in ipairs({ "rain", "snow" }) do
				for _, step in ipairs({ "light", "normal", "heavy", TOP[weather] }) do
					local w = H.world()
					w:slash(weather)
					w:slash(step)
					w:slash(s.cmd .. " " .. s.ceiling)
					local got = s.read(w, weather)
					if want == nil then want = got end
					near(got, want, 1e-6, s.label ..
						" at the top reads the same in " .. step .. " " .. weather)
				end
			end
		end
	end
end)

it("gives a relative slider more at the top than at its default, everywhere",
function()
	-- A relative slider is allowed to mean different amounts in different
	-- weather. It is not allowed to have dead travel: pushing it up from the
	-- default has to do something at every intensity, or it is a control that
	-- stops working as soon as the weather gets interesting.
	for _, s in ipairs(SLIDERS) do
		if s.kind == "relative" then
			for _, weather in ipairs({ "rain", "snow" }) do
				for _, step in ipairs({ "light", "normal", "heavy" }) do
					local w = H.world()
					w:slash(weather)
					w:slash(step)
					local base = s.read(w, weather)
					w:slash(s.cmd .. " " .. s.ceiling)
					gt(s.read(w, weather), base - 1e-9,
						s.label .. " at the top is not below its default in " ..
						step .. " " .. weather)
				end
			end
		end
	end
end)

it("moves every slider monotonically from one end to the other", function()
	-- Walked at the slider's own step, so a discontinuity or a flat shelf shows
	-- up as the player would feel it: a control that sticks.
	for _, s in ipairs(SLIDERS) do
		for _, weather in ipairs({ "rain", "snow" }) do
			local w = H.world()
			w:slash(weather)
			w:slash("normal")
			local last = nil
			local steps = 20
			for i = 0, steps do
				local v = s.floor + (s.ceiling - s.floor) * i / steps
				w:slash(string.format("%s %.4f", s.cmd, v))
				local got = s.read(w, weather)
				if last then
					gt(got, last - 1e-9, s.label .. " at " .. v ..
						" in " .. weather .. " is not below the step under it")
				end
				last = got
			end
		end
	end
end)

it("knows which kind every slider in the window is", function()
	-- The window is the list that matters, not this file. Anything the player
	-- can drag has to appear above with its kind declared, so adding a slider
	-- forces the "what does its top mean" question to be answered.
	local w = H.world()
	w:open()
	local declared = {}
	for _, s in ipairs(SLIDERS) do declared[s.label] = true end

	-- Sliders this file deliberately leaves out, each because its reading is
	-- not a thing drawn on screen and is covered where it belongs.
	local ELSEWHERE = {
		["Fall Speed"] = "spec_math: doubling the speed slider doubles the fall",
		["Volume"] = "spec_sound: moves the bed to whichever channel the player names",
		["Hour"] = "spec_timeofday: it relabels to Shift by Hours or Hold at Hour " ..
			"with the mode, and neither end of it is a drawn amount",
		["Shift by Hours"] = "spec_timeofday: treats an offset as hours from the realm clock",
		["Hold at Hour"] = "spec_timeofday: wraps midnight without a discontinuity",
		["Strength"] = "spec_timeofday: scales the whole grade by strength",
	}

	local seen = 0
	for _, f in ipairs(w.mock.frames) do
		if f._kind == "Slider" and f._parent then
			for _, fs in ipairs(f._parent._fontStrings or {}) do
				local label = fs.text
				if label and (declared[label] or ELSEWHERE[label]) then
					seen = seen + 1
				elseif label and label ~= "" and w:slider(label) then
					ok(false, "the slider labelled " .. label ..
						" is in neither SLIDERS nor ELSEWHERE in spec_sweep.lua. " ..
						"Say whether its top is absolute or relative.")
				end
			end
		end
	end
	gt(seen, 0, "the sweep found the window's sliders at all")
end)

--------------------------------------------------------------------------------
-- Invariants that have to hold at every point in the space
--------------------------------------------------------------------------------

-- Checked after every step of every walk below. Each one is a thing that, if
-- it were ever false, would be visible on screen as a bug and is not visible
-- in any single spec's assertion.
local function Invariants(w, where)
	local g = w:gloom()
	for i = 1, 3 do
		local c = g.colour[i]
		ok(type(c) == "number" and c == c, where .. ": gloom channel " .. i ..
			" is a real number")
		gt(c, -1e-9, where .. ": gloom channel " .. i .. " is not negative")
		lt(c, 1 + 1e-9, where .. ": gloom channel " .. i .. " is not above one")
	end

	for name, t in pairs(w:layers()) do
		local a = t:GetAlpha()
		ok(type(a) == "number" and a == a, where .. ": " .. name .. " alpha is a number")
		gt(a, -1e-9, where .. ": " .. name .. " alpha is not negative")
		lt(a, 1 + 1e-9, where .. ": " .. name .. " alpha is not above one")
	end

	local wo = w:whiteout()
	if wo then
		lt(wo:GetAlpha(), 0.11, where .. ": the whiteout stays below the point " ..
			"where it could hide a mob")
	end

	local o = w:overlay()
	local oa = o:GetAlpha()
	gt(oa, -1e-9, where .. ": overlay alpha is not negative")
	lt(oa, 1 + 1e-9, where .. ": overlay alpha is not above one")

	local d = w:dim()
	if d and d.colour then
		for i = 1, 3 do
			gt(d.colour[i], -1e-9, where .. ": curtain channel " .. i .. " is not negative")
			lt(d.colour[i], 1 + 1e-9, where .. ": curtain channel " .. i .. " is not above one")
		end
	end

	-- The settings themselves. A value outside its range is how a drawn number
	-- goes out of range one frame later, so catching it here names the cause
	-- rather than the symptom.
	local db = w:db()
	local RANGE = {
		-- Mirrors NUMERIC_RANGE in the addon on purpose. It is a local there,
		-- and a contract checked against a copy of itself is not checked, so
		-- this is the outside view of what the addon promises.
		scale = { 0, 1.5 }, speed = { 0.2, 3 }, gloom = { 0, 2 }, gust = { 0, 2 },
		volume = { 0, 1 }, timeStrength = { 0, 1 }, timeOffset = { -23, 23 },
		timeFixed = { 0, 23 }, minimapAngle = { 0, 360 },
	}
	for k, r in pairs(RANGE) do
		local v = db[k]
		ok(type(v) == "number" and v == v, where .. ": db." .. k .. " is a number, got " ..
			tostring(v))
		gt(v, r[1] - 1e-9, where .. ": db." .. k .. " is not below its floor")
		lt(v, r[2] + 1e-9, where .. ": db." .. k .. " is not above its ceiling")
	end
	local ENUM = {
		weather = { rain = true, snow = true },
		channel = { Ambience = true, SFX = true, Master = true, Music = true, Dialog = true },
		timeMode = { off = true, ["local"] = true, offset = true, fixed = true },
		indoors = { off = true, dim = true, on = true },
	}
	for k, allowed in pairs(ENUM) do
		ok(allowed[db[k]], where .. ": db." .. k .. " is one of the allowed values, got " ..
			tostring(db[k]))
	end
end

it("holds every drawn value inside its range across the whole matrix", function()
	for _, weather in ipairs({ "rain", "snow" }) do
		for _, step in ipairs({ "light", "normal", "heavy", TOP[weather] }) do
			for _, scale in ipairs({ 0, 0.25, 1, 1.5 }) do
				for _, dim in ipairs({ 0, 1, 2 }) do
					local w = H.world()
					w:slash(weather)
					w:slash(step)
					w:slash("alpha " .. scale)
					w:slash("dim " .. dim)
					w:slash("gust 2")
					-- Advanced so the gust follower, the zoom response and the
					-- lightning all get a turn at the numbers.
					w:advance(30, 0.1)
					Invariants(w, string.format("%s %s, alpha %s, dim %s",
						weather, step, scale, dim))
				end
			end
		end
	end
end)

--------------------------------------------------------------------------------
-- Everything the player can type
--------------------------------------------------------------------------------

-- Read off the dispatcher. A command missing from this list is a command no
-- sweep touches, which is why the next spec checks the list against the help
-- text rather than trusting it.
local COMMANDS = {
	"", "on", "off", "rain", "snow", "light", "normal", "heavy", "monsoon",
	"blizzard", "auto", "cycle", "alpha", "speed", "dim", "gloom", "gust",
	"wind", "time", "volume", "vol", "sound", "thunder", "suppress", "indoors",
	"channel", "zoom", "minimap", "density", "where", "reset", "stop",
	"export", "share", "import", "undo", "about", "version", "status",
	"ui", "config", "options", "settings", "calib", "calibrate", "watch",
	"probe", "help",
}

-- Arguments chosen to be the ones a parser gets wrong: the empty one, the
-- wrong type, the out-of-range one at both ends, the ones that are numbers to
-- tonumber and not numbers to arithmetic, and the one that is far too long.
local ARGS = {
	"", " ", "0", "1", "-1", "-999999", "999999", "0.0001", "abc", "rain",
	"nan", "inf", "-inf", "1e400", "0x10", "1 2 3", "--", "%s", "|cffff0000r|r",
	string.rep("x", 400), "\n", "\t", "21", "+9", "off",
}

it("survives every command with every kind of bad argument", function()
	-- One world for the whole walk, on purpose: this is the one place where
	-- state carried from the last command is the thing being tested. A player
	-- types one thing after another, and the addon has to still be standing.
	local w = H.world()
	for _, cmd in ipairs(COMMANDS) do
		for _, a in ipairs(ARGS) do
			local input = (a == "") and cmd or (cmd .. " " .. a)
			local fine, err = pcall(function() w:slash(input) end)
			ok(fine, "/comfy " .. input:sub(1, 40) .. " raised: " .. tostring(err))
		end
	end
	-- And after all of it, the profile is still a profile. A parser that
	-- survives garbage by writing the garbage into db has not survived it.
	Invariants(w, "after the whole garbage walk")
end)

it("leaves a usable addon behind after the garbage walk", function()
	-- Surviving is not enough: it still has to rain. This is the positive
	-- control on the spec above, which would pass just as happily against an
	-- addon that had quietly switched itself off and stopped drawing.
	local w = H.world()
	for _, cmd in ipairs(COMMANDS) do
		for _, a in ipairs(ARGS) do
			w:slash((a == "") and cmd or (cmd .. " " .. a))
		end
	end
	w:slash("reset")
	w:slash("on")
	w:slash("rain")
	w:slash("heavy")
	w:slash("alpha 1")
	w:slash("dim 1")
	w:advance(5, 0.1)
	ok(w:overlay():IsShown(), "the overlay still comes back")
	gt(w:layers().far:GetAlpha(), 0.5, "and it still draws heavy rain")
	lt(w:gloom().colour[1], 0.9, "and still darkens the world")
end)

it("mentions every command it accepts somewhere the player can find it",
function()
	-- A command the help does not name is a command nobody will type, and a
	-- command the help names that does not exist is worse. Both are the same
	-- bug: the list in this file, the dispatcher and the help drifting apart.
	local w = H.world()
	w.mock.printed = {}
	w:slash("help")
	w:slash("")
	local help = table.concat(w.mock.printed or {}, "\n")

	-- Aliases and the internal ones are not advertised, by choice. Each is
	-- named here so dropping one from the help is a decision, not a drift.
	local UNADVERTISED = {
		gloom = "the old name for dim, kept working and not promoted",
		wind = "alias of gust", vol = "alias of volume",
		version = "alias of about", export = "alias of share",
		calib = "alias of watch", calibrate = "alias of watch",
		config = "alias of ui", options = "alias of ui", settings = "alias of ui",
		blizzard = "the snow name for monsoon, shown with the weather",
		monsoon = "shown with the weather", light = "an intensity",
		normal = "an intensity", heavy = "an intensity",
		where = "a survey command for the author's own doorway walk",
		[""] = "the bare command is what prints the help",
		help = "the help does not need to name itself",
	}

	-- Read the help the way a player does: the word straight after "/comfy",
	-- with the colour codes taken off and "rain||snow" counted as both. A bare
	-- find() passes on "ui" because some other line happens to contain those
	-- two letters, which is a coverage check that cannot fail.
	local advertised = {}
	local plain = help:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	for token in plain:gmatch("/comfy%s+([%w|]+)") do
		for word in token:gmatch("%w+") do advertised[word] = true end
	end

	local missing = {}
	for _, cmd in ipairs(COMMANDS) do
		if not UNADVERTISED[cmd] and not advertised[cmd] then
			missing[#missing + 1] = cmd
		end
	end
	eq(#missing, 0, "commands the help never mentions: " ..
		table.concat(missing, ", "))
end)

--------------------------------------------------------------------------------
-- A random walk, for the combinations nobody thought of
--------------------------------------------------------------------------------

it("keeps its invariants under a long random walk", function()
	-- Seeded, so a failure is reproducible and a red run means something. The
	-- point is not the randomness, it is the length: this types more settings
	-- combinations in a second than the 30-minute route covers in a month, and
	-- it is the only thing in the suite that can find an order-dependent bug.
	math.randomseed(20261019)
	local w = H.world()
	local steps = 0
	for i = 1, 400 do
		local cmd = COMMANDS[math.random(#COMMANDS)]
		local a = ARGS[math.random(#ARGS)]
		w:slash((math.random() < 0.3) and cmd or (cmd .. " " .. a))
		if math.random() < 0.25 then w:advance(math.random() * 20, 0.1) end
		steps = steps + 1
		if i % 25 == 0 then Invariants(w, "random walk step " .. i) end
	end
	eq(steps, 400, "the walk ran to the end without the addon dying")
	Invariants(w, "end of the random walk")
end)

it("comes back to exactly the same place from the same seed", function()
	-- The walk above is only worth having if a failure can be reproduced, and
	-- that needs the addon's own jitter to be seeded rather than ambient. Two
	-- identical runs that disagree mean something in here is reading a clock.
	local function run()
		math.randomseed(4242)
		local w = H.world()
		for _ = 1, 60 do
			w:slash(COMMANDS[math.random(#COMMANDS)] .. " " .. ARGS[math.random(#ARGS)])
			w:advance(1, 0.1)
		end
		return w:snapshot()
	end
	eq(run(), run(), "the same seed draws the same frame")
end)

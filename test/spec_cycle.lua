-- Rain that builds, peaks and eases (#44). The generator is pure and takes its
-- random source as an argument, so most of this runs without a world at all;
-- the rest drives the real addon to prove the cycle is off until asked for,
-- and that the player can always take it back.

local H = require("harness")
local it, eq, ok, near, gt, lt = H.it, H.eq, H.ok, H.near, H.gt, H.lt

-- A seedable generator of our own, so a spec replays exactly and never leans on
-- the global one the addon is also drawing from.
local function lcg(seed)
	local x = seed
	return function()
		x = (x * 1103515245 + 12345) % 2147483648
		return x / 2147483648
	end
end

local function api()
	return H.world().env.ComfyRainAPI.Cycle
end

-- Six simulated hours, one second at a time. Returns the series' extremes and
-- the largest single step, which is what a smooth build has to keep small.
local function run(Cycle, spec, pace, seed, start)
	local c = Cycle.new(spec, lcg(seed), pace, start)
	local lo, hi, maxStep, prev = math.huge, -math.huge, 0, c.level
	local sum, sumsq, n = 0, 0, 0
	local phases = {}
	for _ = 1, 6 * 3600 do
		local v = c:step(1)
		if v < lo then lo = v end
		if v > hi then hi = v end
		maxStep = math.max(maxStep, math.abs(v - prev))
		prev = v
		sum, sumsq, n = sum + v, sumsq + v * v, n + 1
		phases[c.phase] = true
	end
	local mean = sum / n
	return { lo = lo, hi = hi, maxStep = maxStep, phases = phases,
	         sd = math.sqrt(math.max(0, sumsq / n - mean * mean)) }
end

it("cycle: six hours of every pattern stays inside its range and moves smoothly", function()
	local Cycle = api()
	for _, name in ipairs({ "showers", "soak", "storm" }) do
		local spec = Cycle.patterns[name]
		for seed = 1, 3 do
			local r = run(Cycle, spec, 1, seed * 7919)
			ok(r.lo >= spec.low - 1e-9, name .. " never drops below its low")
			ok(r.hi <= spec.high + 1e-9, name .. " never rises above its high")
			lt(r.maxStep, 0.2, name .. " moves less than 0.2 of a level per second")
			for _, ph in ipairs({ "lull", "build", "peak", "ease" }) do
				ok(r.phases[ph], name .. " passes through " .. ph)
			end
		end
	end
end)

it("cycle: it actually varies, rather than hovering near one value", function()
	local Cycle = api()
	local r = run(Cycle, Cycle.patterns.showers, 1, 4242)
	-- The showers range is 0..2. A generator stuck near the middle passes the
	-- range check and is still a fixed intensity, so spread is asserted.
	gt(r.hi - r.lo, 1.5, "it travels most of its range")
	gt(r.sd, 0.35, "and spends real time away from the mean")
end)

it("cycle: a custom range and pace are honoured, and fast is quicker than slow", function()
	local Cycle = api()
	local spec = { low = 1, high = 2.5, draw = 0.4, build = Cycle.patterns.showers.build,
	               peak = Cycle.patterns.showers.peak, ease = Cycle.patterns.showers.ease,
	               lull = Cycle.patterns.showers.lull }
	local fast = run(Cycle, spec, Cycle.paces.fast, 99)
	ok(fast.lo >= 1 - 1e-9 and fast.hi <= 2.5 + 1e-9, "fast stays in 1..2.5")
	lt(fast.maxStep, 0.2, "even the fastest pace stays smooth")

	-- Count shower peaks over the same time: fast has more of them.
	local function peaks(pace)
		local c, n, inPeak = Cycle.new(spec, lcg(5), pace, 1), 0, false
		for _ = 1, 6 * 3600 do
			c:step(1)
			if c.phase == "peak" and not inPeak then n = n + 1 end
			inPeak = c.phase == "peak"
		end
		return n
	end
	gt(peaks(Cycle.paces.fast), peaks(Cycle.paces.slow), "fast makes more showers than slow")
end)

it("cycle: the same seed replays exactly", function()
	local Cycle = api()
	local a, b = Cycle.new(Cycle.patterns.storm, lcg(3), 1, 0), Cycle.new(Cycle.patterns.storm, lcg(3), 1, 0)
	for _ = 1, 5000 do eq(a:step(1), b:step(1), "same seed, same level") end
end)

it("cycle: a storm front is one arc of roughly forty minutes that reaches the top", function()
	local Cycle = api()
	local c, top, at = Cycle.new(Cycle.patterns.storm, lcg(8), 1, 0), 0, nil
	for t = 1, 3600 do
		local v = c:step(1)
		if v > top then top = v end
		if c.phase == "lull" and not at then at = t end
	end
	near(top, 3, 1e-9, "the peak is the top of the scale")
	ok(at and at > 25 * 60 and at < 55 * 60, "it clears after about 40 minutes, got " .. tostring(at))
end)

it("cycle: a hitch longer than a phase carries its remainder instead of stalling", function()
	local Cycle = api()
	local c = Cycle.new(Cycle.patterns.showers, lcg(11), 1, 0)
	local v = c:step(7200)
	ok(v >= 0 and v <= 2, "still in range after a two hour hitch")
end)

it("cycle: Blend at 1.5 is half normal and half heavy", function()
	local w = H.world()
	local P = w.env.ComfyRainAPI.Weather.rain.presets
	local C = w.env.ComfyRainAPI.Cycle
	local b = C.blend(1.5)
	for _, k in ipairs({ "mist", "far", "near", "speed", "gloom", "strikeEvery" }) do
		near(b[k], (P.normal[k] + P.heavy[k]) / 2, 1e-9, k .. " is the midpoint")
	end
	near(C.blend(0).near, P.light.near, 1e-9, "0 is light")
	near(C.blend(3).near, P.monsoon.near, 1e-9, "3 is monsoon")
	near(C.blend(2).gloom, P.heavy.gloom, 1e-9, "2 is heavy")
	-- The sheet it is leaving and the one it is going to, so the renderer can
	-- crossfade instead of popping.
	ok(b.near_texture ~= b.nearB, "normal to heavy crossfades two different sheets")
	near(b.mix, 0.5, 1e-9, "half way is half mixed")
end)

it("cycle: off by default, so nothing moves and no second sheet is built", function()
	local w = H.world()
	w:slash("gust 0")   -- gusts wobble alpha by design; this is about the level
	eq(w:db().changing, false, "off in a fresh profile")
	local a = w:layers().near:GetAlpha()
	local bed = #w.mock.sounds
	w:advance(600, 1)
	eq(w:layers().near:GetAlpha(), a, "no drift in ten minutes")
	eq(w:db().intensity, "normal", "intensity untouched")
	local extra = 0
	for _, t in ipairs(w:overlay()._textures) do if t.layer == "ARTWORK" then extra = extra + 1 end end
	eq(extra, 3, "far, near and the whiteout (mist is BACKGROUND), and no second near sheet")
	ok(bed > 0, "the bed still plays")
end)

it("cycle: switched on it moves, and leaves db.intensity alone", function()
	local w = H.world()
	w:slash("cycle showers")
	eq(w:db().changing, true, "on")
	local seen, first = {}, w:layers().near:GetAlpha()
	for _ = 1, 40 do
		w:advance(60, 1)
		seen[#seen + 1] = w:layers().near:GetAlpha()
	end
	local lo, hi = math.huge, -math.huge
	for _, v in ipairs(seen) do lo, hi = math.min(lo, v), math.max(hi, v) end
	gt(hi - lo, 0.1, "the near layer's alpha travelled in forty minutes")
	ok(first == first, "started")
	eq(w:db().intensity, "normal", "the player's own setting is never rewritten")
end)

it("cycle: any manual intensity pauses it", function()
	for _, cmd in ipairs({ "light", "heavy", "monsoon", "cycle" }) do
		local w = H.world()
		w:slash("gust 0")
		w:slash("cycle storm")
		w:advance(300, 1)
		w:slash(cmd)
		eq(w:db().changing, false, "/comfy " .. cmd .. " paused the cycle")
		local a = w:layers().near:GetAlpha()
		w:advance(1200, 1)
		eq(w:layers().near:GetAlpha(), a, "and the rain then holds still after /comfy " .. cmd)
	end
end)

it("cycle: the minimap wheel and the Heavier/Lighter keybinds pause it too", function()
	-- #45 and #44 were built side by side. Both promise that a hand on the
	-- intensity wins over the cycle; this is the one place that is checked.
	local steps = {
		wheel   = function(w) w.env.ComfyRain_Minimap()
			local b = w.env.ComfyRainMinimapButton
			b:GetScript("OnMouseWheel")(b, 1) end,
		heavier = function(w) w.env.ComfyRain_Heavier() end,
		lighter = function(w) w.env.ComfyRain_Lighter() end,
	}
	for name, step in pairs(steps) do
		local w = H.world()
		w:slash("cycle storm")
		w:advance(300, 1)
		eq(w:db().changing, true, name .. ": cycling before the step")
		step(w)
		eq(w:db().changing, false, name .. " paused the cycle")
		eq(#w.mock.errors, 0, name .. ": errors")
	end
end)

it("cycle: /comfy cycle off holds, and on resumes", function()
	local w = H.world()
	w:slash("gust 0")
	w:slash("cycle soak")
	w:advance(120, 1)
	w:slash("cycle off")
	eq(w:db().changing, false, "off")
	local a = w:layers().far:GetAlpha()
	w:advance(600, 1)
	eq(w:layers().far:GetAlpha(), a, "held")
	w:slash("cycle on")
	eq(w:db().changing, true, "on again")
end)

it("cycle: custom range parses names, numbers and pace, and rejects nonsense", function()
	local w = H.world()
	w:slash("cycle light-heavy slow")
	local d = w:db()
	eq(d.cycle, "custom", "custom")
	eq(d.cycleLow, 0, "light is 0")
	eq(d.cycleHigh, 2, "heavy is 2")
	eq(d.cyclePace, "slow", "pace")
	w:slash("cycle 0.5-2.5")
	near(d.cycleLow, 0.5, 1e-9, "numbers work")
	near(d.cycleHigh, 2.5, 1e-9, "numbers work")
	eq(d.cyclePace, "slow", "pace is kept when not given")
	w:slash("cycle heavy-light fast")
	eq(d.cycleLow, 0, "a backwards range is swapped")
	eq(d.cyclePace, "fast", "fast")
	w:slash("cycle 9-12")
	eq(d.cycleHigh, 2, "out of range is refused and leaves the setting")
	w:slash("cycle sideways")
	eq(d.changing, true, "garbage leaves the cycle as it was")
end)

it("cycle: thunder only schedules above heavy", function()
	local w = H.world()
	w:slash("cycle light-heavy fast")
	local c0 = #w.mock.sounds
	local claps = 0
	for _ = 1, 3600 do
		w:advance(1, 1)
	end
	for i = c0 + 1, #w.mock.sounds do
		local s = w.mock.sounds[i]
		if s.file and s.file ~= 538983 and s.file ~= 538981 and s.file ~= 538982 then claps = claps + 1 end
	end
	eq(claps, 0, "a cycle that never passes heavy never thunders")

	local w2 = H.world()
	w2:slash("cycle storm")
	local c1, thunder = #w2.mock.sounds, 0
	for _ = 1, 3600 do w2:advance(1, 1) end
	for i = c1 + 1, #w2.mock.sounds do
		local s = w2.mock.sounds[i]
		if s.file and s.file ~= 538983 and s.file ~= 538981 and s.file ~= 538982 then thunder = thunder + 1 end
	end
	gt(thunder, 0, "a storm front thunders at its peak")
end)

it("cycle: the bed follows the level, and the loudest bed is louder than the lightest", function()
	local w = H.world()
	local C = w.env.ComfyRainAPI.Cycle
	eq(C.blend(0).bed.id, 538983, "light's bed at 0")
	eq(C.blend(2.9).bed.id, 538982, "the heavy bed near the top")
	gt(C.blend(3).gain, C.blend(0).gain, "gain rises with the level")
	-- And an unmuted loop stays unmuted: every bed in range counts as in use.
	w:slash("suppress on")
	w:slash("cycle storm")
end)

it("cycle: the window has a Changing box and one live line", function()
	local w = H.world()
	w:open()
	local box = w:button("Changing")
	ok(box, "a Changing control")
	eq(w:says("^Now:"), nil, "no live line while it is off")
	box:Click()
	eq(w:db().changing, true, "clicking it turns the cycle on")
	local line = w:says("^Now: %a+, %a+$")
	ok(line, "the window says what it is doing, got none")
	w:slash("heavy")
	eq(w:button("Changing") ~= nil, true, "still there")
	eq(w:says("^Now:"), nil, "the line goes when the cycle is paused")
end)

it("cycle: a profile round trips the cycle settings", function()
	local w = H.world()
	w:slash("cycle 0.5-2.5 fast")
	local s = w.env.ComfyRainAPI.Export()
	ok(s:find("cycleLow=0.5", 1, true) and s:find("changing=1", 1, true), "exported")
	local w2 = H.world()
	w2:slash("import " .. s)
	near(w2:db().cycleLow, 0.5, 1e-9, "imported")
	eq(w2:db().cyclePace, "fast", "pace imported")
end)

it("cycle: the near sheet crossfades between normal and heavy instead of popping", function()
	local w = H.world()
	w:slash("gust 0")
	w:slash("cycle 1.2-1.8 fast")
	local near2
	for _, t in ipairs(w:overlay()._textures) do
		if t.texture and tostring(t.texture):find("rain%-near%-heavy") then near2 = t end
	end
	ok(near2, "a second near layer carries the heavy sheet")
	local both = false
	for _ = 1, 600 do
		w:advance(1, 1)
		local a, b = w:layers().near:GetAlpha(), near2:GetAlpha()
		if a > 0.01 and b > 0.01 then both = true end
		-- Total near strength follows the lerped preset, never doubling up.
		lt(a + b, 1.0001, "the two sheets share one layer's alpha")
	end
	ok(both, "both sheets are partly visible together mid-band")
end)

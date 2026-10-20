-- Time of day. The trickiest arithmetic in the addon, and the only part whose
-- bugs are silent: a double-darkened night still looks like night.

local H = require("harness")
local it, eq, ok, near, lt, gt = H.it, H.eq, H.ok, H.near, H.lt, H.gt

local function colourOf(tex) return tex.colour[1], tex.colour[2], tex.colour[3] end

it("does nothing at all when the mode is off", function()
	local w = H.world()
	eq(w:tod():IsShown(), false, "grade frame with timeMode off")
end)

it("darkens a midday realm towards a chosen night hour", function()
	local w = H.world({ state = { gameHour = 12, gameMinute = 0 } })
	w:slash("time 21")
	eq(w:tod():IsShown(), true, "grade frame once a mode is set")

	local r, g, b = colourOf(w:dim())
	-- 21:00 interpolates halfway between the 20:00 and 22:00 keyframes, against
	-- a realm already at full daylight, so the ratio is the target itself.
	near(r, 0.47, 0.005, "dim red")
	near(g, 0.48, 0.005, "dim green")
	near(b, 0.68, 0.005, "dim blue")
	-- Night is cooler than it is dark: blue must survive more than red.
	gt(b, r, "night keeps its blue")
	near(w:lift():GetAlpha(), 0, 1e-9, "nothing to add when darkening")
end)

it("does not double-darken when the realm is already at that hour", function()
	-- The whole reason the grade is computed as a ratio. Wanting 21:00 on a
	-- realm that already reads 21:00 is a no-op, and a MOD quad that is not
	-- white here would darken every night a second time.
	local w = H.world({ state = { gameHour = 21, gameMinute = 0 } })
	w:slash("time 21")
	local r, g, b = colourOf(w:dim())
	near(r, 1, 1e-6, "dim red")
	near(g, 1, 1e-6, "dim green")
	near(b, 1, 1e-6, "dim blue")
	near(w:lift():GetAlpha(), 0, 1e-9, "lift")
end)

it("caps the lift when asked to turn night into day", function()
	-- The weak direction. ADD can raise the black level but cannot restore
	-- contrast, and the skybox keeps its stars either way, so the cap is what
	-- stops the screen turning into milk.
	local w = H.world({ state = { gameHour = 2, gameMinute = 0 } })
	w:slash("time 12")
	local r, g, b = colourOf(w:dim())
	near(r, 1, 1e-6, "no darkening when brightening")
	near(g, 1, 1e-6, "no darkening when brightening")
	near(b, 1, 1e-6, "no darkening when brightening")
	near(w:lift():GetAlpha(), 0.13, 1e-9, "lift is clamped to LIFT_CAP")
end)

it("scales the whole grade by strength", function()
	local w = H.world({ state = { gameHour = 12, gameMinute = 0 } })
	w:slash("time 21")
	local full = w:dim().colour[1]
	w:slash("time strength 0.5")
	local half = w:dim().colour[1]
	-- Half strength is half the distance from 1, not half the value.
	near(half, 1 + (full - 1) * 0.5, 1e-6, "dim red at strength 0.5")
	w:slash("time strength 0")
	near(w:dim().colour[1], 1, 1e-6, "strength 0 is a no-op")
end)

it("treats an offset as hours from the realm clock", function()
	local w = H.world({ state = { gameHour = 12, gameMinute = 0 } })
	w:slash("time +9")
	eq(w:db().timeMode, "offset", "mode")
	eq(w:db().timeOffset, 9, "offset")
	local offset = w:dim().colour[1]
	w:slash("time 21")
	near(w:dim().colour[1], offset, 1e-6, "realm 12 plus 9 is the same as fixed 21")
end)

it("matches the player's own clock in local mode", function()
	local w = H.world()
	-- Sit on an exact hour so a fixed-hour comparison is exact.
	local t = os.date("*t", math.floor(w.mock.epoch))
	w.mock.epoch = w.mock.epoch - (t.min * 60 + t.sec)
	w.mock.state.gameHour, w.mock.state.gameMinute = 3, 0

	w:slash("time local")
	local localDim = w:dim().colour[1]
	w:slash("time " .. t.hour)
	near(w:dim().colour[1], localDim, 1e-6, "local mode equals that fixed hour")
end)

it("wraps midnight without a discontinuity", function()
	-- The LIGHT table ends at hour 24 with the same values as hour 0. If that
	-- wrap were wrong, 23:59 and 00:01 would grade to visibly different frames.
	local before, after
	local w = H.world({ state = { gameHour = 12, gameMinute = 0 } })
	w:slash("time 23")
	before = w:dim().colour[3]
	w:slash("time 1")
	after = w:dim().colour[3]
	ok(math.abs(before - after) < 0.06, "midnight wrap is continuous")
end)

it("stops grading during a cinematic", function()
	local w = H.world({ state = { gameHour = 12, gameMinute = 0 } })
	w:slash("time 21")
	w.mock.fire("CINEMATIC_START")
	eq(w:tod():IsShown(), false, "grade during a cinematic")
end)

it("gives up quietly when the realm clock is unreadable", function()
	local w = H.world({ state = { gameHour = 12 } })
	w:slash("time 21")
	w.mock.state.gameHour = nil
	w:advance(21)           -- the grade re-evaluates on a 20 second ticker
	eq(w:tod():IsShown(), false, "grade with no realm clock")
	eq(#w.mock.errors, 0, "errors")
end)

it("keeps the light graded when the rain is switched off", function()
	-- The light is not weather, and the commonest reason to want it is nothing
	-- to do with rain: a player nine hours from their realm wants their own
	-- clock and no weather at all. Making them run the rain to get the light
	-- is the addon refusing the only thing they asked for.
	--
	-- This was the other way round for one day, after "my screen is too dark
	-- and I can't turn off the changes it made" from live play 2026-10-19. The
	-- fault there was an effect with no visible cause, not an effect that
	-- outlived the rain, and the two specs below are what actually fix it.
	local w = H.world()
	w:slash("time 21")
	w:advance(1)
	eq(w:tod():IsShown(), true, "curtain up at a held hour")

	w:slash("off")
	w:advance(1)
	eq(w:tod():IsShown(), true, "still up with the rain off")

	w:slash("time off")
	w:advance(1)
	eq(w:tod():IsShown(), false, "and down when the light itself is turned off")
end)

it("takes the curtain down on /comfy stop", function()
	-- stop is the one switch for a player looking at a screen they cannot
	-- explain, so it has to mean everything. It is the escape hatch that makes
	-- the spec above safe.
	local w = H.world()
	w:slash("time 21")
	w:advance(1)
	eq(w:tod():IsShown(), true, "curtain up at a held hour")

	w:slash("stop")
	w:advance(1)
	eq(w:tod():IsShown(), false, "and stop takes it with everything else")
	eq(w:db().timeMode, "off", "and clears the mode so a reload stays clear")
end)

it("says the light is still on, so the dark screen has a visible cause", function()
	-- The curtain outliving the rain is only safe if turning the rain off says
	-- so. A player who does not know a rain addon also grades the light has no
	-- reason to look in the Time of Day section, and the only thing standing
	-- between him and a reinstall is one printed line naming it.
	local w = H.world()
	w:slash("time 21")
	w.mock.printed = {}
	w:slash("off")
	gt(#w.mock.printedMatching("light is still held"), 0, "off names the light")
	gt(#w.mock.printedMatching("21:00"), 0, "and says what it is held at")
	gt(#w.mock.printedMatching("/comfy stop"), 0, "and points at the one switch")

	-- Silent when there is nothing to explain.
	w:slash("time off")
	w.mock.printed = {}
	w:slash("off")
	eq(#w.mock.printedMatching("light"), 0, "nothing to say with the grading off")
end)

it("takes less light out of a world that has little left to give", function()
	-- The darkening's tint is calibrated against daylight: it is what a storm
	-- does to a lit frame. Multiplying an already-dark midnight frame by the
	-- same number reads as mud, not as weather, which is how every Goldshire
	-- night screenshot on 2026-10-20 came back at a tenth of a usable
	-- brightness. So it scales with how much light there is to take.
	local day = H.world({ state = { gameHour = 12, gameMinute = 0 } })
	day:slash("preset snow")
	local dr, dg, db_ = colourOf(day:gloom())

	local night = H.world({ state = { gameHour = 2, gameMinute = 0 } })
	night:slash("preset snow")
	local nr, ng, nb = colourOf(night:gloom())

	-- MOD: higher is lighter. The same preset must leave more of a night frame
	-- standing than it leaves of a noon one.
	gt(nr, dr, "night keeps more red")
	gt(ng, dg, "night keeps more green")
	gt(nb, db_, "night keeps more blue")

	-- But not all of it. A storm that stops darkening after dusk is its own
	-- kind of broken, so the floor is a fraction, never nothing.
	lt(nr, 1, "night is still darkened")
	lt(ng, 1, "night is still darkened, green")
end)

it("leaves the daylight calibration exactly where the sweep put it", function()
	-- The 2026-10-15 screenshot sweep tuned every preset at noon. Scaling the
	-- darkening by the hour is only safe because full daylight is the identity
	-- case, so this is the test that stops the next tweak moving it.
	local w = H.world({ state = { gameHour = 12, gameMinute = 0 } })
	for _, key in ipairs({ "cozy", "storm", "snow", "overcast" }) do
		w:slash("preset " .. key)
		local r, g, b = colourOf(w:gloom())
		local off = H.world({ state = { gameHour = 15, gameMinute = 0 } })
		off:slash("preset " .. key)
		local r2, g2, b2 = colourOf(off:gloom())
		near(r, r2, 1e-9, key .. " red is flat across the lit hours")
		near(g, g2, 1e-9, key .. " green is flat across the lit hours")
		near(b, b2, 1e-9, key .. " blue is flat across the lit hours")
	end
end)

it("follows the realm clock down into the night on its own", function()
	-- Nothing presses a button between dusk and midnight. The 20s tick is the
	-- only thing that can notice, so the darkening has to ride it.
	local w = H.world({ state = { gameHour = 12, gameMinute = 0 } })
	w:slash("preset storm")
	local lit = select(2, colourOf(w:gloom()))

	w.mock.state.gameHour = 2
	w:advance(21, 0.5)
	local dark = select(2, colourOf(w:gloom()))
	gt(dark, lit, "the darkening eased off without a press")
end)

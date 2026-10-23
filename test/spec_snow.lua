-- Snow, and the blizzard.
--
-- Snow is not rain with a different sprite, and the tests that matter here are
-- the ones that would still pass if it were: the sheet swap, the sway, the
-- second audio loop, the whiteout, and the fact that a snowstorm has no
-- lightning in it.

local H = require("harness")
local it, eq, ok, near, lt, gt = H.it, H.eq, H.ok, H.near, H.lt, H.gt

local SNOW_LIGHT, SNOW_MEDIUM, SNOW_HEAVY = 538985, 538989, 538984
local WIND_LOOP = 918050
local GUSTS = { [982361] = true, [982363] = true, [982365] = true, [982367] = true,
                [982369] = true, [982371] = true, [982373] = true }
local THUNDER_FIRST = 838830

-- Stops are recorded in the same list and carry no file, so they are dropped
-- here rather than guarded at every call site.
local function playsOf(mock, since)
	local out = {}
	for i = (since or 0) + 1, #mock.sounds do
		local s = mock.sounds[i]
		if s.file then out[#out + 1] = s end
	end
	return out
end

it("starts on rain, so nobody who upgrades wakes up in a snowstorm", function()
	local w = H.world()
	eq(w:db().weather, "rain", "default weather")
end)

it("swaps every sheet when the weather changes", function()
	local w = H.world()
	local l = w:layers()
	local rainFar, rainNear, rainMist = l.far.texture, l.near.texture, l.mist.texture

	w:slash("snow")
	ok(l.far.texture ~= rainFar, "the far sheet changed")
	ok(l.near.texture ~= rainNear, "the near sheet changed")
	ok(l.mist.texture ~= rainMist, "the mist changed, and it is snow mist, not rain mist")
	ok(tostring(l.far.texture):find("snow"), "the far sheet is a snow sheet")

	w:slash("rain")
	eq(l.far.texture, rainFar, "and back again")
end)

it("gives the blizzard its own gale sheet, not the same flakes faster", function()
	local w = H.world()
	w:slash("snow")
	local l = w:layers()
	local calm = l.near.texture
	w:slash("blizzard")
	ok(l.near.texture ~= calm, "the near layer is a different sprite in a gale")
	ok(tostring(l.near.texture):find("gale"), "and it is the gale sheet")
end)

-- Light and normal snow used to be the same near sheet at two alphas, and on
-- that sheet alpha barely changes how many flakes show: 552 against 618. Light
-- is fewer flakes now, so it has to be a different sheet, and the other
-- intensities have to keep the full one.
it("gives light snow fewer flakes, not the same flakes fainter", function()
	local w = H.world()
	w:slash("snow")
	local l = w:layers()
	local full = l.near.texture
	ok(not tostring(full):find("light"), "normal snow draws the full near sheet")
	w:slash("light")
	ok(l.near.texture ~= full, "light snow's near layer is a different sprite")
	ok(tostring(l.near.texture):find("snow%-near%-light"), "and it is the thinned sheet")
	w:slash("heavy")
	eq(l.near.texture, full, "heavy goes back to the full sheet")
end)

it("plays the snow bed, and relooks it on the snow clip length", function()
	local w = H.world()
	local before = #w.mock.sounds
	w:slash("snow")
	local played = playsOf(w.mock, before)
	ok(#played > 0, "a bed started")
	eq(played[#played].file, SNOW_MEDIUM, "the medium snow loop at the default intensity")

	-- SnowMedium is 50 s, not rain's 30. A loop timed on the wrong clip either
	-- gaps or doubles, and 20 seconds of silence is the louder failure. Counted
	-- on the primary file only: a quieter under-bed of a different length runs
	-- beneath it on purpose, and it is allowed to reloop whenever it likes.
	local function primary(from)
		local out = 0
		for i = from + 1, #w.mock.sounds do
			if w.mock.sounds[i].file == SNOW_MEDIUM then out = out + 1 end
		end
		return out
	end
	local n = #w.mock.sounds
	w:advance(45, 0.5)
	eq(primary(n), 0, "nothing relooped before the clip could have ended")
	w:advance(10, 0.5)
	gt(primary(n), 0, "the bed relooped once the clip was ending")
end)

it("layers wind under the snow in a blizzard, which nothing else does", function()
	local w = H.world()
	local before = #w.mock.sounds
	w:slash("blizzard")
	local files = {}
	for _, s in ipairs(playsOf(w.mock, before)) do files[s.file] = true end
	ok(files[SNOW_HEAVY], "the heavy snow bed")
	ok(files[WIND_LOOP], "and the wind loop on top of it")

	-- And it goes away again: the wind belongs to the blizzard, not to snow.
	before = #w.mock.sounds
	w:slash("normal")
	w:advance(60, 0.5)
	for _, s in ipairs(playsOf(w.mock, before)) do
		ok(s.file ~= WIND_LOOP, "no wind outside the blizzard")
	end
end)

it("gusts instead of thundering, and never flashes in snow", function()
	local w = H.world()
	w:slash("blizzard")
	local before = #w.mock.sounds
	local gusts = 0
	for _ = 1, 400 do
		w:advance(1, 0.5)
		-- A flash is the one thing a snowstorm must never do.
		near(w:flash():GetAlpha(), 0, 1e-9, "no lightning in a blizzard")
	end
	for _, s in ipairs(playsOf(w.mock, before)) do
		if GUSTS[s.file] then gusts = gusts + 1 end
		ok(s.file ~= THUNDER_FIRST, "no thunder in a blizzard")
	end
	gt(gusts, 0, "gusts arrive")
end)

it("still thunders in rain", function()
	local w = H.world()
	local before = #w.mock.sounds
	local thunder = 0
	for _ = 1, 200 do
		w:advance(1, 0.5)
		for _, s in ipairs(playsOf(w.mock, before)) do
			if s.file >= 838830 and s.file <= 839737 then thunder = thunder + 1 end
		end
		before = #w.mock.sounds
	end
	gt(thunder, 0, "rain keeps its lightning when snow exists")
end)

it("drifts sideways in snow and does not in rain", function()
	-- Sway is the whole reason snow reads as snow: a flake has no weight to
	-- resist a breeze. If this ever collapses, snow becomes slow rain and
	-- nothing else in the suite would notice.
	local function horizontalTravel(w)
		local l = w:layers()
		local seen, last = {}, nil
		local minx, maxx = math.huge, -math.huge
		for _ = 1, 60 do
			w:advance(0.5, 0.5)
			local c = l.far.texCoord
			if last then
				local d = c[1] - last
				-- Unwrap the 0..1 modulo so a crossing is not read as a jump.
				if d > 0.5 then d = d - 1 elseif d < -0.5 then d = d + 1 end
				seen[#seen + 1] = d
				minx = math.min(minx, d)
				maxx = math.max(maxx, d)
			end
			last = c[1]
		end
		return minx, maxx
	end

	-- Gusts off for both. Since 2026-10-15 the wind shears the slant on every
	-- weather, so a gusting rain would pass this test for the wrong reason and
	-- a collapsed sway would hide inside the noise. This spec is about sway.
	local rain = H.world()
	rain:slash("gust 0")
	local rainMin, rainMax = horizontalTravel(rain)
	local snow = H.world()
	snow:slash("snow")
	snow:slash("gust 0")
	local snowMin, snowMax = horizontalTravel(snow)

	-- Rain's drift is one constant slant, so the per-frame step barely varies.
	-- Snow's swings either side of it.
	lt(rainMax - rainMin, 0.02, "rain falls at one fixed slant")
	gt(snowMax - snowMin, (rainMax - rainMin) * 2, "snow's drift reverses")
end)

it("whites out in a blizzard, and only in a blizzard", function()
	local w = H.world()
	local q = w:whiteout()
	ok(q, "the whiteout quad exists")
	-- BLEND, not ADD. A whiteout is contrast collapsing towards the sky, and
	-- only BLEND does that: it scales every difference in the frame by (1-a),
	-- where ADD shifts the whole frame by a constant and leaves every
	-- difference exactly where it was. The old ADD quad could brighten but
	-- could not actually obscure anything, which is why it read as a gamma
	-- slider rather than as weather.
	eq(q.blend, "BLEND", "BLEND, because a whiteout destroys contrast, not darkness")
	near(q:GetAlpha(), 0, 1e-9, "off in rain")

	w:slash("snow")
	near(q:GetAlpha(), 0, 1e-9, "off in ordinary snow")

	w:slash("blizzard")
	gt(q:GetAlpha(), 0, "on in a blizzard")
	-- An addon that hides a mob is an addon that gets uninstalled.
	lt(q:GetAlpha(), 0.31, "and capped well short of hiding the world")

	w:slash("alpha 1.5")
	lt(q:GetAlpha(), 0.31, "still capped when the player cranks the alpha")
end)

it("snow tints cooler than rain but still darkens", function()
	local w = H.world()
	w:slash("heavy")
	local rainBlue = w:gloom().colour[3]
	w:slash("snow")
	local snowBlue = w:gloom().colour[3]
	lt(w:gloom().colour[1], 1, "snow still dims")
	gt(snowBlue, w:gloom().colour[1], "and it dims blue last, like daylight through cloud")
	ok(rainBlue, "rain had a tint to compare against")
end)

it("carries the intensity across a weather change, top included", function()
	local w = H.world()
	w:slash("monsoon")
	eq(w:db().weather, "rain", "monsoon is a rain word")
	w:slash("snow")
	-- Somebody at the top of the rain scale means the top of the snow scale,
	-- not a silent drop to normal.
	eq(w:db().intensity, "blizzard", "the top of one scale is the top of the other")
	w:slash("rain")
	eq(w:db().intensity, "monsoon", "and back")

	w:slash("light")
	w:slash("snow")
	eq(w:db().intensity, "light", "shared names are left alone")
end)

it("never leaves db.intensity naming a preset this weather does not have", function()
	-- Saved settings outlive the session, so an intensity the current weather
	-- cannot look up would come back as a nil index on the next login.
	local w = H.world()
	for _, cmd in ipairs({ "monsoon", "snow", "blizzard", "rain", "heavy", "snow", "cycle", "cycle" }) do
		w:slash(cmd)
		local weather, intensity = w:db().weather, w:db().intensity
		local valid = { rain = { light = 1, normal = 1, heavy = 1, monsoon = 1 },
		                snow = { light = 1, normal = 1, heavy = 1, blizzard = 1 } }
		ok(valid[weather][intensity],
			"after /comfy " .. cmd .. ": " .. weather .. "/" .. intensity)
	end
end)

it("cycles within the weather it is in", function()
	local w = H.world()
	w:slash("snow")
	w:slash("heavy")
	w:slash("cycle")
	eq(w:db().intensity, "blizzard", "heavy snow cycles to blizzard, not monsoon")
	w:slash("cycle")
	eq(w:db().intensity, "light", "and wraps")
	eq(w:db().weather, "snow", "cycling never changes the weather")
end)

it("saves the weather across a reload", function()
	local w = H.world()
	w:slash("blizzard")
	local saved = w:db()
	local two = H.world({ loaded = false })
	two.env.ComfyRainDB = saved
	two:load()
	eq(two:db().weather, "snow", "weather survived")
	eq(two:db().intensity, "blizzard", "and so did the intensity")
	gt(two:whiteout():GetAlpha(), 0, "and the whiteout came back with it")
end)

it("matches the realm's own weather on /comfy auto", function()
	local w = H.world()
	w.env.C_Weather = { GetCurrentWeather = function()
		return { weatherType = 2, intensity = 0.8 }
	end }
	w:slash("auto")
	eq(w:db().weather, "snow", "followed the realm into snow")

	-- A realm reporting nothing is not a reason to change anything, and
	-- sandstorm is real weather this addon has no art for. Neither may leave
	-- the addon pointed at a weather that does not exist.
	w.env.C_Weather = { GetCurrentWeather = function()
		return { weatherType = 3, intensity = 1 }
	end }
	w:slash("auto")
	eq(w:db().weather, "snow", "sandstorm is declined, not half-applied")

	w.env.C_Weather = { GetCurrentWeather = function() return { weatherType = 0 } end }
	w:slash("auto")
	eq(w:db().weather, "snow", "no weather means nothing to match")
end)

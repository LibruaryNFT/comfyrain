-- The rain layers, the gloom quad and the geometry that keeps drops the right
-- shape on a screen the author does not own.

local H = require("harness")
local it, eq, ok, near, lt, gt = H.it, H.eq, H.ok, H.near, H.lt, H.gt

it("builds three layers with the blend modes the look depends on", function()
	local w = H.world()
	local l = w:layers()
	eq(l.mist.blend, "BLEND", "mist blend")
	eq(l.far.blend, "BLEND", "far blend")
	-- Near drops are lit by the sky and read as highlights, so they add.
	eq(l.near.blend, "ADD", "near blend")
	-- MOD multiplies the finished frame, and is the only way an addon can
	-- darken the world at all. No competitor in the surveyed field uses it.
	eq(w:gloom().blend, "MOD", "gloom blend")
	eq(l.far.wrapH, "REPEAT", "far must tile horizontally")
	eq(l.far.wrapV, "REPEAT", "far must tile vertically")
end)

it("applies preset alphas and clamps the scale", function()
	local w = H.world()
	w:slash("heavy")
	local l = w:layers()
	near(l.far:GetAlpha(), 0.95, 1e-9, "far alpha at heavy")
	near(l.near:GetAlpha(), 0.90, 1e-9, "near alpha at heavy")
	near(l.mist:GetAlpha(), 0.17, 1e-9, "mist alpha at heavy")

	w:slash("alpha 1.5")
	near(l.far:GetAlpha(), 1.0, 1e-9, "far alpha is clamped to 1")
	-- Mist is clamped lower than the rain: a 0.6 alpha fog sheet already hides
	-- the world, and anything above it is a grey screen.
	near(l.mist:GetAlpha(), 0.255, 1e-9, "mist alpha scales below its own cap")

	w:slash("alpha 9")
	near(w:db().scale, 1.5, 1e-9, "scale is clamped at the parser, not the renderer")
end)

it("makes gloom 0 a true no-op", function()
	-- A MOD quad is only off when it is white. If this drifted to 0.99 the
	-- world would be permanently, invisibly dimmer with the feature disabled.
	local w = H.world()
	w:slash("gloom 0")
	local r, g, b = w:gloom().colour[1], w:gloom().colour[2], w:gloom().colour[3]
	near(r, 1, 1e-9, "gloom red at 0")
	near(g, 1, 1e-9, "gloom green at 0")
	near(b, 1, 1e-9, "gloom blue at 0")
end)

it("tints gloom cool, and clamps it before it becomes a blackout", function()
	local w = H.world()
	w:slash("normal")
	-- 0.38, raised from 0.20 on 2026-10-15 after a screenshot sweep measured
	-- normal rain darkening the scene by 0.7% against a weather-off control.
	-- The rain sheets add back almost exactly what the old gloom removed.
	local c = w:gloom().colour
	near(c[1], 1 - 0.38 * (1 - 0.55), 1e-6, "gloom red at normal")
	near(c[2], 1 - 0.38 * (1 - 0.62), 1e-6, "gloom green at normal")
	near(c[3], 1 - 0.38 * (1 - 0.78), 1e-6, "gloom blue at normal")
	gt(c[3], c[1], "rain cools the scene as well as darkening it")
	lt(c[1], 0.87, "and normal rain is actually visible as a darkening")

	w:slash("monsoon")
	w:slash("gloom 2")
	-- 0.95 * 2 would be 1.9; the clamp holds it at 1.0, which multiplies the
	-- world by the tint itself and is dark without being a blackout.
	near(w:gloom().colour[1], 1 - 1.0 * (1 - 0.55), 1e-6, "gloom is clamped at 1.0")
end)

it("darkens monotonically as the weather gets worse", function()
	-- A screenshot sweep on 2026-10-15 found heavy snow BRIGHTER than normal
	-- snow and monsoon only 1.3 points darker than normal rain: the sheets are
	-- light-coloured, so raising their alpha adds back more than the old gloom
	-- curve removed. Gloom now has to outrun the sheets, and this is the test
	-- that says so without needing the client.
	for _, weather in ipairs({ "rain", "snow" }) do
		local w = H.world()
		w:slash(weather)
		local last = nil
		for _, step in ipairs({ "light", "normal", "heavy" }) do
			w:slash(step)
			local red = w:gloom().colour[1]
			if last then
				lt(red, last, weather .. " at " .. step .. " is darker than the step below")
			end
			last = red
		end
	end
end)

it("derives horizontal tiling from the real aspect ratio", function()
	-- The author plays on 21:9. A sheet tiled by a fixed count would stretch
	-- every drop sideways on his monitor and look correct on nobody else's.
	local wide = H.world({ width = 3440, height = 1440 })
	wide:advance(0.1)
	local c = wide:layers().far.texCoord
	near(c[2] - c[1], 3.0 * (3440 / 1440), 1e-6, "far tilesX at 21:9")
	near(c[4] - c[3], 3.0, 1e-9, "far tilesY is fixed")

	local narrow = H.world({ width = 1920, height = 1080 })
	narrow:advance(0.1)
	local n = narrow:layers().far.texCoord
	near(n[2] - n[1], 3.0 * (1920 / 1080), 1e-6, "far tilesX at 16:9")
end)

it("scrolls every layer downwards, the near one fastest", function()
	local w = H.world()
	w:advance(0.2)
	local before = {}
	for k, t in pairs(w:layers()) do before[k] = t.texCoord[3] end
	-- Short enough that even the near layer, at 2.3 sheets a second, does not
	-- wrap past 1. Comparing speeds modulo the wrap would rank them backwards.
	w:advance(0.2)

	local moved = {}
	for k, t in pairs(w:layers()) do
		-- The window walks up the sheet so the image falls down the screen.
		moved[k] = (before[k] - t.texCoord[3]) % 1
		gt(moved[k], 0, k .. " layer is scrolling")
	end
	gt(moved.near, moved.far, "near parallax outruns far")
	gt(moved.far, moved.mist, "far outruns the mist")
end)

it("sweeps the curtain sideways when the camera turns", function()
	-- Yaw parallax is the single biggest tell that a sheet is 2D. Without it
	-- the rain slides at one fixed rate no matter where the player looks.
	local w = H.world()
	w:advance(0.5)
	local still = w:layers().far.texCoord[1]
	w.mock.state.facing = 1.2
	w:advance(0.5)
	local turned = w:layers().far.texCoord[1]
	ok(math.abs(((turned - still) % 1)) > 0.01, "the sheet moved with the camera")
end)

it("fades the bottom of the rain layers but not the mist", function()
	-- A fullscreen curtain runs down over the player's feet, which is the
	-- giveaway. The gradient gives the drops somewhere to land.
	local w = H.world()
	local l = w:layers()
	ok(l.far.gradient ~= nil, "far has a horizon fade")
	ok(l.near.gradient ~= nil, "near has a horizon fade")
	eq(l.far.gradient[1], "VERTICAL", "fade orientation")
	ok(l.mist.gradient == nil, "the mist layer is tinted, not faded")
	ok(l.mist.vertexColour ~= nil, "the mist layer is tinted")
end)

it("fades out rather than snapping when it is turned off", function()
	local w = H.world()
	w:advance(0.5)
	w:slash("off")
	w:advance(0.2)
	local mid = w:overlay():GetAlpha()
	lt(mid, 1, "started fading")
	gt(mid, 0, "has not snapped to nothing")
	w:advance(1.0)
	eq(w:overlay():IsShown(), false, "hidden once the fade completes")
end)

it("stops drawing indoors, after a debounce", function()
	-- Walking under an arch should not restart the whole effect, so the indoor
	-- poll has to hold for most of a second before it believes itself.
	local w = H.world()
	w:advance(0.5)
	w.mock.state.indoors = true
	w:advance(0.5)
	eq(w:overlay():IsShown(), true, "still raining inside the debounce window")
	w:advance(1.5)
	eq(w:overlay():IsShown(), false, "stopped once the debounce clears")

	w.mock.state.indoors = false
	w:advance(2.0)
	eq(w:overlay():IsShown(), true, "resumes outdoors")
end)

it("keeps polling the indoor flag while the overlay is hidden", function()
	-- The bug this pins: the poll used to live on the overlay's OnUpdate. A
	-- hidden frame gets no OnUpdate, and going indoors is what hides it, so
	-- the addon went deaf at the exact moment it needed to be listening and
	-- only a ZONE_CHANGED event could ever wake it again. Events are
	-- unreliable for indoor state, which is why there is a poll at all.
	local w = H.world()
	w:slash("off")
	w:advance(2.0)
	eq(w:overlay():IsShown(), false, "overlay off")

	w.mock.state.indoors = true
	w:advance(2.0)
	w.mock.state.indoors = false
	w:advance(2.0)
	w:slash("on")
	w:advance(0.1)
	eq(w:overlay():IsShown(), true, "the indoor state tracked while hidden")
	eq(#w.mock.errors, 0, "errors")
end)

it("keeps raining indoors when the player asks it to", function()
	local w = H.world({ state = { indoors = true } })
	w:slash("indoors on")
	w.mock.fire("ZONE_CHANGED_INDOORS")
	w:advance(2.0)
	eq(w:overlay():IsShown(), true, "overlay with indoors on")
end)

it("gusts: one shared signal, lagged per layer, and switchable off", function()
	-- The single biggest tell that this is a scrolling texture is that it
	-- scrolls at exactly one rate forever. These assert the three properties
	-- that make the gust read as wind rather than as a rendering fault.
	local function rates(w, frames)
		local l, out, last = w:layers(), {}, nil
		for _ = 1, frames do
			w:advance(1 / 30, 1 / 30)
			local y = l.far.texCoord[3]
			if last then
				local d = last - y
				if d < -0.5 then d = d + 1 elseif d > 0.5 then d = d - 1 end
				out[#out + 1] = d
			end
			last = y
		end
		return out
	end
	local function spread(t)
		local lo, hi = math.huge, -math.huge
		for _, v in ipairs(t) do lo = math.min(lo, v); hi = math.max(hi, v) end
		return hi - lo
	end

	-- 1. Dead calm is still available, and it is exactly calm.
	local calm = H.world()
	calm:slash("gust 0")
	lt(spread(rates(calm, 120)), 1e-9, "gust 0 scrolls at one unvarying rate")

	-- 2. With gusts on, the rate actually moves, and by enough to see. The
	--    consults put the perceptual floor near 2% of the base rate.
	local windy = H.world()
	local r = rates(windy, 400)
	local mean = 0
	for _, v in ipairs(r) do mean = mean + v end
	mean = mean / #r
	gt(spread(r) / mean, 0.02, "the scroll rate varies by more than the visible floor")

	-- 3. A monsoon gusts harder than a drizzle. Same seed both times, so the
	--    only difference is the intensity scale.
	local function spreadAt(step)
		math.randomseed(1234)
		local x = H.world()
		x:slash(step)
		local v = rates(x, 400)
		local m = 0
		for _, q in ipairs(v) do m = m + q end
		return spread(v) / (m / #v)
	end
	gt(spreadAt("monsoon"), spreadAt("light"), "a monsoon gusts harder than light rain")
end)

it("gusts do not drag a layer past its own limits", function()
	-- Alpha is clamped into 0..1 and gloom into 0..1 every frame. A gust that
	-- pushed either out of range would throw in the client, where the spec
	-- suite is not watching.
	local w = H.world()
	w:slash("monsoon")
	w:slash("gust 2")
	w:slash("dim 2")
	for _ = 1, 600 do w:advance(1 / 30, 1 / 30) end
	local l = w:layers()
	for _, key in ipairs({ "mist", "far", "near" }) do
		local a = l[key]:GetAlpha()
		gt(a, -1e-9, key .. " alpha is not negative")
		lt(a, 1 + 1e-9, key .. " alpha is not above one")
	end
	for i = 1, 3 do
		local c = w:gloom().colour[i]
		gt(c, -1e-9, "gloom channel " .. i .. " is not negative")
		lt(c, 1 + 1e-9, "gloom channel " .. i .. " is not above one")
	end
	eq(#w.mock.errors, 0, "errors")
end)

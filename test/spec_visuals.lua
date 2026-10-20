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
	-- The top of the slider is 1.0, which multiplies the world by the tint
	-- itself and is dark without being a blackout.
	near(w:gloom().colour[1], 1 - 1.0 * (1 - 0.55), 1e-6, "gloom tops out at 1.0")
end)

it("lets the top of the Darkness slider reach full dark at every intensity",
function()
	-- Until 2026-10-19 the slider simply multiplied the preset, so its maximum
	-- of 2 landed wherever 2x the preset happened to be: 0.76 at normal rain,
	-- 0.36 at light. The control looked like it had travel left and did not.
	-- Anything above 1 now closes the remaining gap to full instead, so the
	-- right-hand end means the same thing in every weather.
	for _, weather in ipairs({ "rain", "snow" }) do
		for _, step in ipairs({ "light", "normal", "heavy" }) do
			local w = H.world()
			w:slash(weather)
			w:slash(step)
			w:slash("gloom 2")
			local tint = (weather == "rain") and 0.55 or 0.62
			near(w:gloom().colour[1], 1 - (1 - tint), 1e-6,
				weather .. " at " .. step .. " reaches full dark at the top")
		end
	end
end)

it("leaves the middle of the Darkness slider on the measured preset curve",
function()
	-- 1 is the default and has to keep meaning "what this weather is supposed
	-- to look like", or the 2026-10-15 screenshot sweep gets invalidated by a
	-- change that was only ever about the slider's top half.
	local w = H.world()
	w:slash("rain")
	for _, case in ipairs({ { "light", 0.18 }, { "normal", 0.38 }, { "heavy", 0.75 } }) do
		w:slash(case[1])
		w:slash("gloom 1")
		near(w:gloom().colour[1], 1 - case[2] * (1 - 0.55), 1e-6,
			case[1] .. " at gloom 1 is still the preset")
		-- And half the slider is still half the preset.
		w:slash("gloom 0.5")
		near(w:gloom().colour[1], 1 - case[2] * 0.5 * (1 - 0.55), 1e-6,
			case[1] .. " at gloom 0.5 is still half the preset")
	end
end)

it("keeps Darkness monotone across the whole slider", function()
	-- The two halves are different formulas joined at 1. A discontinuity or a
	-- flat spot there would feel like the slider sticking.
	local w = H.world()
	w:slash("rain")
	w:slash("normal")
	local last = nil
	for i = 0, 40 do
		local v = i * 0.05
		w:slash(string.format("gloom %.2f", v))
		local red = w:gloom().colour[1]
		if last then
			lt(red, last + 1e-9, "gloom at " .. v .. " is no lighter than the step below")
			lt(last - red, 0.03, "and no single step of the slider is a jump")
		end
		last = red
	end
	near(last, 1 - (1 - 0.55), 1e-6, "the far end is full dark")
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

it("keeps drops the same shape from 4:3 to 32:9", function()
	-- The invariant underneath the tile counts, stated once so it holds for
	-- resolutions nobody here owns. A drop is the right shape when the tiles
	-- per screen on each axis are in the same ratio as the screen itself; if
	-- that ever stops being true the rain is stretched or squashed, which is
	-- the kind of thing only the person with the odd monitor ever reports.
	local sizes = {
		{ 1024,  768, "4:3" },
		{ 1280, 1024, "5:4" },
		{ 1920, 1080, "16:9" },
		{ 2560, 1080, "21:9" },
		{ 5120, 1440, "32:9" },
		{ 3840, 2160, "4K" },
	}
	for _, s in ipairs(sizes) do
		local w = H.world({ width = s[1], height = s[2] })
		w:advance(0.1)
		for name, tex in pairs(w:layers()) do
			local c = tex.texCoord
			local tilesX, tilesY = c[2] - c[1], c[4] - c[3]
			gt(tilesY, 0, s[3] .. " " .. name .. " has vertical tiling")
			near(tilesX / tilesY, s[1] / s[2], 1e-6,
				s[3] .. " " .. name .. " drop shape")
		end
		eq(#w.mock.errors, 0, "errors at " .. s[3])
	end
end)

it("covers the whole screen with every fullscreen quad", function()
	-- The gloom, whiteout and grade quads are flat colour over the entire
	-- view. A quad anchored by size rather than by its parent's edges leaves a
	-- visible unlit band on a resolution the author never ran, and there is no
	-- way to see that from here except to assert the anchoring.
	local w = H.world({ width = 5120, height = 1440 })
	w:advance(0.1)
	local overlay, tod = w:overlay(), w:tod()
	eq(overlay._anchor, w.env.WorldFrame, "overlay fills WorldFrame")
	eq(tod._anchor, w.env.WorldFrame, "grade fills WorldFrame")
	for _, t in ipairs(overlay._textures) do
		ok(t._anchor ~= nil, "every overlay texture is anchored to its parent")
	end
	for _, t in ipairs(tod._textures) do
		ok(t._anchor ~= nil, "every grade texture is anchored to its parent")
	end
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

-- Two fade lengths, and the whole point is that they are different.
--
-- Both were 0.7s until 2026-10-19, when pressing Turn It All Off got "we
-- clicked turn it all off and it didnt change quick enough". 0.7s is right
-- for weather leaving the sky above you and wrong for a button: most of a
-- second of nothing happening after a click reads as a click that missed,
-- and the fix for that is not a faster fade everywhere, because the doorway
-- fade is the thing that stops walking under an awning from being a pop.
it("snaps off at the switch and eases off at the doorway", function()
	local w = H.world()
	w:advance(0.5)
	w:slash("off")
	w:advance(0.2)
	eq(w:overlay():IsShown(), false, "the switch is finished inside a fifth of a second")

	-- The positive control, and the half that must NOT have been sped up. If
	-- the doorway had been shortened too, the assertion above would pass for
	-- the wrong reason and nobody would know the slow fade had been lost.
	local v = H.world()
	v:advance(0.5)
	v.mock.state.indoors = true
	v:advance(1.0)      -- past the 0.35s debounce, into the fade itself
	local mid = v:overlay():GetAlpha()
	lt(mid, 1, "the doorway has started fading")
	gt(mid, 0, "and is still on its way down a fifth of a second later")
	v:advance(1.0)
	eq(v:overlay():IsShown(), false, "hidden once that fade completes too")
end)

it("stops drawing indoors but keeps the weather running, and fades back out", function()
	-- Changed 2026-10-19, from live play in the Stormwind barbershop: "dim"
	-- used to mean a 25% wash of rain still drawn under a solid roof, and it
	-- read as the addon not noticing the ceiling rather than as weather
	-- outside. So the two halves split - nothing is SEEN indoors, the bed is
	-- still HEARD. Walking under an arch must still not restart the effect, so
	-- the poll holds for most of a second before it believes itself.
	local w = H.world()
	w:slash("gust 0")   -- or the gust's own alpha wobble masks the comparison
	w:advance(0.5)
	local outside = w:layers().far:GetAlpha()
	gt(outside, 0, "raining outdoors to begin with")
	w.mock.state.indoors = true
	w:advance(0.5)
	near(w:layers().far:GetAlpha(), outside, 1e-9, "unchanged inside the debounce window")
	w:advance(2.0)
	near(w:layers().far:GetAlpha(), 0, 1e-9, "nothing drawn once the debounce clears")
	-- Not just invisible. A hidden frame gets no OnUpdate, so an inn costs no
	-- frames at all, and asserting alpha alone would not have noticed.
	eq(w:overlay():IsShown(), false, "and the overlay stopped ticking entirely")

	w.mock.state.indoors = false
	w:advance(3.0)
	eq(w:overlay():IsShown(), true, "drawing again on the way out")
	near(w:layers().far:GetAlpha(), outside, 1e-9, "back to full outdoors")
end)

it("still plays the weather bed indoors, quieter, while drawing nothing", function()
	-- The other half of the split above, and the reason "dim" is not just
	-- "off": silence in the inn is wrong. Rain through a wall is what makes an
	-- inn feel like shelter.
	local w = H.world()
	w:advance(0.5)
	local from = #w.mock.sounds
	w.mock.state.indoors = true
	w:advance(3.0)
	local played = {}
	for i = from + 1, #w.mock.sounds do played[#played + 1] = w.mock.sounds[i] end
	gt(#played, 0, "the bed relaunched at the doorstep rather than going silent")
	for _, s in ipairs(played) do
		if s.volumeOverride then
			gt(s.volumeOverride, 0, "audible indoors")
			lt(s.volumeOverride, 0.8, "but ducked")
		end
	end
end)

it("indoors off still means off, and indoors on still means full", function()
	-- The middle setting is the new default, not the only one. Someone who
	-- genuinely wants a dry tavern must still be able to say so.
	local w = H.world()
	w:slash("gust 0")
	local outside = w:layers().far:GetAlpha()
	w:slash("indoors off")
	w.mock.state.indoors = true
	w:advance(3.0, 0.1)
	eq(w:overlay():IsShown(), false, "off hides it completely")

	w:slash("indoors on")
	w:advance(3.0, 0.1)
	eq(w:overlay():IsShown(), true, "on draws it")
	near(w:layers().far:GetAlpha(), outside, 1e-9, "at full strength")
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

it("dims under a roof the engine does not call a room", function()
	-- Reported from live play: "the rain goes through indoors sometimes". The
	-- "sometimes" was the tell. IsIndoors() is true only inside a WMO interior,
	-- so awnings, cave mouths, tents, bridges and most doorways returned false
	-- and got full-strength rain drawn on the ceiling. IsOutdoors() is false in
	-- all of those, which is the signal the old test never asked for.
	local w = H.world()
	w:advance(1.0, 0.1)
	local outside = w:layers().far:GetAlpha()
	gt(outside, 0, "raining outdoors to begin with")

	-- Neither flag set: sheltered, but not indoors by the engine's reckoning.
	w.mock.state.sheltered = true
	w:advance(2.0, 0.1)
	lt(w:layers().far:GetAlpha(), outside * 0.5, "dimmed under the awning")

	-- Compared as a ratio, not to the exact figure: the gust process keeps
	-- moving alpha on its own, so pinning the number would be testing the gust.
	w.mock.state.sheltered = false
	w:advance(3.0, 0.1)
	gt(w:layers().far:GetAlpha(), outside * 0.8, "back to full in the open")
	eq(#w.mock.errors, 0, "errors")
end)

it("takes cover faster than it leaves it", function()
	-- The two errors are not equally bad. Rain falling through a roof is the
	-- thing players report; a second of missing rain after stepping back into
	-- the open is not. The long exit debounce is also what stops a quick dash
	-- under an arch from flickering the overlay twice.
	local w = H.world()
	w:advance(1.0, 0.1)
	local outside = w:layers().far:GetAlpha()

	w.mock.state.sheltered = true
	w:advance(0.8, 0.1)
	lt(w:layers().far:GetAlpha(), outside, "inside within 0.8s")

	w.mock.state.sheltered = false
	w:advance(0.8, 0.1)
	lt(w:layers().far:GetAlpha(), outside * 0.5, "still dim 0.8s after stepping out")
end)

it("writes down WHERE a doorway was wrong, not just which district", function()
	-- Five readings off the live client all said "Stormwind City / Trade
	-- District". That is fifty doorways, a bridge and two awnings: enough to
	-- know something was wrong and not enough to go back and look at it. The
	-- log is the whole instrument for the indoor question, so it has to name a
	-- spot somebody can walk back to.
	local w = H.world()
	w.mock.state.uiMapID = 84
	w.mock.state.pos = { x = 0.5512, y = 0.6688 }
	w:advance(1.0, 0.1)

	w.mock.state.sheltered = true
	w:advance(2.0, 0.1)
	local log = w:db().where
	gt(#log, 0, "the transition was logged")
	local e = log[#log]
	eq(e.reason, "entered", "and logged as an entry")
	eq(e.uiMapID, 84, "with the map it happened on")
	near(e.x, 0.5512, 1e-4, "and the spot, to four places")
	near(e.y, 0.6688, 1e-4, "both axes")
	-- The pair of flags, not only the conclusion: this entry is the awning
	-- case, and a log that stored only `sheltered` could not show that.
	eq(e.indoors, false, "neither flag was set")
	eq(e.outdoors, false, "which is what an awning looks like")
end)

it("logs the doorway anyway when the client will not give a position", function()
	-- Instances restrict player position, and GetXY is a FrameXML mixin that is
	-- not in the executable at all. Either can be missing on the build we ship
	-- to. Losing the coordinate must cost the coordinate and nothing else.
	local w = H.world()
	w.mock.state.pos = false
	w:advance(1.0, 0.1)
	w.mock.state.sheltered = true
	w:advance(2.0, 0.1)
	local e = w:db().where[#w:db().where]
	ok(e, "still logged")
	eq(e.x, nil, "with no coordinate")
	eq(e.sheltered, true, "and the reading itself intact")
	eq(#w.mock.errors, 0, "errors")
end)

it("logs doorways with the overlay switched off, because the walk is a survey", function()
	-- The measuring walk and the addon being on are two different things, and
	-- conflating them is a fair thing to be confused by: being asked to walk
	-- around looking for rain bugs while no rain is drawn sounds like nonsense.
	-- It is not. The indoor poll is a ticker of its own rather than the
	-- overlay's OnUpdate, so the survey runs whether or not anything is
	-- rendered - the question being measured is what the ENGINE says about a
	-- doorway, which does not depend on us drawing over it.
	local w = H.world()
	w:slash("off")
	w:advance(1.0, 0.1)
	local before = #(w:db().where or {})

	w.mock.state.sheltered = true
	w:advance(2.0, 0.1)
	w.mock.state.sheltered = false
	w:advance(3.0, 0.1)

	local log = w:db().where
	eq(#log, before + 2, "in and out were both logged with the addon disabled")
	eq(log[#log - 1].reason, "entered", "going in")
	eq(log[#log].reason, "left", "and coming back out")
	eq(w:db().enabled, false, "and the addon really was off the whole time")
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

it("reads camera distance, and makes the drops bigger and faster up close", function()
	-- Asked from live play 2026-10-19: "if we zoom in or out shouldn't it change
	-- how rain/snow looks?" It should, and GetCameraZoom is the only part of the
	-- world camera an addon can read at all - there is no pitch and no yaw - so
	-- this is the single 3D cue available to a 2D overlay. Measured on tilesY,
	-- which is how many copies of the sheet fit on screen: more copies means
	-- each drop is smaller.
	local function tilesY(zoom)
		local w = H.world()
		w:slash("gust 0")
		w.mock.state.cameraZoom = zoom
		w:advance(3.0)                     -- past the zoom smoother
		local c = w:layers().far.texCoord
		return c[4] - c[3]
	end

	local out, close = tilesY(15), tilesY(0)
	gt(out, close * 1.3, "pulled back, the same rain reads as finer and denser")
	gt(close, 0, "and first person still has rain in it")
end)

it("leaves the field alone at any zoom once the zoom response is off", function()
	-- The cue is a judgement call, not a correctness fix, so it has to be
	-- switchable. Without this the setting could silently do nothing.
	local function tilesY(zoom)
		local w = H.world()
		w:slash("gust 0")
		w:slash("zoom off")
		w.mock.state.cameraZoom = zoom
		w:advance(3.0)
		local c = w:layers().far.texCoord
		return c[4] - c[3]
	end
	near(tilesY(15), tilesY(0), 1e-9, "identical with the response off")
end)

-- Deference: standing aside while the client's own weather is falling.
--
-- This is the answer to a thing no code can fix. Blizzard's rain is world-space
-- particles, so the arch at Stormwind's gate occludes them; ours is a flat
-- sheet drawn in front of the camera and nothing in the world can ever be in
-- front of it. "blizzards own rainfall doesnt go through it cuz they use 3d
-- rain", 2026-10-20. Where the real thing is falling it is simply the better
-- of the two, so ours gets out of the way.
--
-- Asserted on the overlay rather than on a layer's alpha, which is what the
-- indoor specs above use. Those two are genuinely different mechanisms:
-- "indoors" scales every layer through IndoorFactor and leaves the effect
-- running, while deference stops the effect at ShouldRain and the layers keep
-- whatever alpha they last had. A layer-alpha assertion here would pass on a
-- build where deference did nothing at all.

-- Both halves, because either one alone is a lie: C_Weather reports the
-- server's weather whether or not the client is drawing it, and weatherDensity
-- 0 means it is drawing none of it.
local function realStorm(w)
	w.mock.state.weather = { type = 1, intensity = 0.7 }
	w.mock.cvars.weatherDensity = "3"
end

it("stands aside while the game's own weather is falling, and comes back after", function()
	local w = H.world()
	w:slash("gust 0")
	w:advance(0.5)
	eq(w:overlay():IsShown(), true, "ours is drawing to begin with")

	realStorm(w)
	w:advance(0.5)
	eq(w:overlay():IsShown(), true,
		"still ours inside the debounce - a storm ramps up and crosses zero twice")
	w:advance(3.0)
	eq(w:overlay():IsShown(), false, "theirs is falling, so ours stopped")

	w.mock.state.weather = nil
	-- Leaving is the slower of the two debounces on purpose: a dying storm dips
	-- and recovers, and our sheet flickering back in for a second is worse than
	-- a few seconds with no rain at all.
	w:advance(2.0)
	eq(w:overlay():IsShown(), false, "not back the instant their intensity dips")
	w:advance(3.0)
	eq(w:overlay():IsShown(), true, "back once their storm is really over")
end)

it("ignores real weather the client has been told never to draw", function()
	-- weatherDensity has been 0 on the author's machine since before the addon
	-- existed, which is why nothing here was ever calibrated against Blizzard's
	-- rain. C_Weather still reports the server's weather on such a machine, so
	-- deferring on C_Weather alone would hand the player an empty sky and call
	-- it deference.
	local w = H.world()
	w:slash("gust 0")
	w:advance(0.5)

	w.mock.state.weather = { type = 1, intensity = 0.7 }
	w.mock.cvars.weatherDensity = "0"
	w:advance(3.0)
	eq(w:overlay():IsShown(), true,
		"their rain is reported but not drawn, so ours stays")

	-- Positive control for the assertion above: the same weather with the CVar
	-- up does stop us, so the test can tell the two apart.
	w.mock.cvars.weatherDensity = "3"
	w:advance(3.0)
	eq(w:overlay():IsShown(), false, "and the CVar is what made the difference")
end)

it("lets the player switch deference off and draw over the real thing", function()
	local w = H.world()
	w:slash("gust 0")
	realStorm(w)
	w:advance(3.0)
	eq(w:overlay():IsShown(), false, "standing aside by default")

	w:slash("defer off")
	-- No debounce when the player asks: the command re-seeds the state itself
	-- rather than waiting for the next tick to notice.
	w:advance(0.1)
	eq(w:overlay():IsShown(), true, "drawing over theirs once told to")
	eq(w:db().defer, false, "and it is remembered")

	w:slash("defer on")
	w:advance(3.0)
	eq(w:overlay():IsShown(), false, "and standing aside again")
end)

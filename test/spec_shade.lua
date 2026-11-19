-- The shade that stays on indoors (#43): drops off, a share of the gloom kept,
-- and a "Sound only" level that keeps neither.

local H = require("harness")
local it, eq, ok, near, lt, gt = H.it, H.eq, H.ok, H.near, H.lt, H.gt

-- How dark the world is multiplied right now, 0 for untouched. The red channel
-- is enough: the tint lerps all three from 1 by the same amount.
local function strength(w) return 1 - w:gloom().colour[1] end

local function outdoors()
	local w = H.world()
	-- No gust: it modulates the gloom on its own and would make every ratio
	-- below a test of the wind.
	w:slash("gust 0")
	w:advance(1.0, 0.1)
	return w, strength(w)
end

local function goIndoors(w, mode)
	w:slash("indoors " .. mode)
	w.mock.state.indoors = true
	w:advance(4.0, 0.1)
end

it("keeps about 40% of the gloom indoors on Dim, and draws no drops", function()
	local w, full = outdoors()
	gt(full, 0.1, "there is a gloom to keep")
	goIndoors(w, "dim")
	near(strength(w), full * 0.4, full * 0.02, "the shade is 40% of the outdoor gloom")
	eq(w:overlay():IsShown(), false, "the drops' overlay has faded out")
	eq(w:shade():IsShown(), true, "and the shade frame is still up")
	eq(#w.mock.errors, 0, "errors")
end)

it("gives Sound only no gloom at all, and still plays the bed", function()
	local w, full = outdoors()
	gt(full, 0.1, "there is a gloom to lose")
	goIndoors(w, "sound")
	near(strength(w), 0, 1e-9, "no shade")
	eq(w:overlay():IsShown(), false, "no drops")
	local live = 0
	for _ in pairs(w.mock.handles) do live = live + 1 end
	gt(live, 0, "the sound is still running")
	eq(#w.mock.errors, 0, "errors")
end)

it("gives Off and On their old indoor gloom", function()
	local w, full = outdoors()
	goIndoors(w, "on")
	near(strength(w), full, full * 0.05, "On is the full outdoor gloom")
	goIndoors(w, "off")
	near(strength(w), 0, 1e-9, "Off has none")
end)

it("brings the full gloom back out in the open", function()
	local w, full = outdoors()
	goIndoors(w, "dim")
	w.mock.state.indoors = false
	w:advance(5.0, 0.1)
	near(strength(w), full, full * 0.05, "back to the outdoor gloom")
	eq(w:overlay():IsShown(), true, "and the drops")
end)

it("takes the gloom away with the rest when the weather is switched off", function()
	local w = outdoors()
	w:slash("off")
	w:advance(2.0, 0.1)
	near(strength(w), 0, 1e-9, "nothing is darkened with the weather off")
	eq(w:shade():IsShown(), false, "and the frame is hidden")
end)

it("eases the light across a doorway instead of stepping it", function()
	local w, full = outdoors()
	w.mock.state.indoors = true
	local prev, biggest, moved = strength(w), 0, 0
	for _ = 1, 6 * 60 do
		w:advance(1 / 60, 1 / 60)
		local s = strength(w)
		biggest = math.max(biggest, math.abs(s - prev))
		prev = s
		if s < full - 1e-6 and s > full * 0.4 + 1e-6 then moved = moved + 1 end
	end
	-- A 60% drop over 0.7s is about 0.9% of full per frame. A step of a tenth
	-- of the gloom in one frame is a pop.
	lt(biggest, full * 0.1, "no frame moves the gloom by more than a tenth of it")
	near(prev, full * 0.4, full * 0.02, "and it lands on the shade")
	gt(moved, 10, "over several frames, not one")
end)

it("reads the saved values: dim stays Dim, sound is Sound only", function()
	for _, v in ipairs({ "dim", "sound", "on", "off" }) do
		local w = H.world({ loaded = false })
		w.env.ComfyRainDB = { indoors = v }
		w:load()
		eq(w:db().indoors, v, "saved " .. v .. " is kept")
	end
	local w = H.world({ loaded = false })
	w.env.ComfyRainDB = { indoors = "murmur" }
	w:load()
	eq(w:db().indoors, "dim", "junk falls back to the default")
end)

it("sets Sound only by slash command and by the window, between Off and Dim", function()
	local w = H.world()
	w:slash("indoors sound")
	eq(w:db().indoors, "sound", "the slash command takes it")
	w:open()
	w:select("Indoors").right:Click()
	eq(w:db().indoors, "dim", "Sound only steps up to Dim")
	w:select("Indoors").left:Click()
	w:select("Indoors").left:Click()
	eq(w:db().indoors, "off", "and down through Sound only to Off")
end)

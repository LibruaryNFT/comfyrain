-- Rain under a roof (#34, shelter half): the bed becomes the light loop at the
-- indoor gain, the under-layer stops, and a drip lands every 3-9 s.

local H = require("harness")
local it, eq, ok, gt, lt = H.it, H.eq, H.ok, H.gt, H.lt

local LIGHT, HEAVY, DRIP = 538983, 538982, 596024

local function of(mock, from, file)
	local out = {}
	for i = (from or 0) + 1, #mock.sounds do
		local s = mock.sounds[i]
		if s.file == file and s.ok ~= false and not s.stop then out[#out + 1] = s end
	end
	return out
end

local function live(w)
	local n = 0
	for _ in pairs(w.mock.handles) do n = n + 1 end
	return n
end

local function roofed(opts, setup)
	local w = H.world(opts)
	if setup then setup(w) end
	w:advance(0.5)
	w.mock.state.indoors = true
	w:advance(3.0)
	return w
end

it("under a roof in heavy rain the bed is the light loop at the indoor gain, no under-layer", function()
	local w = roofed(nil, function(w) w:slash("heavy") end)
	local from = #w.mock.sounds
	w:advance(70, 0.1)
	local light, heavy = of(w.mock, from, LIGHT), of(w.mock, from, HEAVY)
	gt(#light, 0, "the light loop is the bed")
	eq(#heavy, 0, "the heavy loop is not")
	eq(#of(w.mock, from, 538981), 0, "the under-layer is not playing")
	for _, s in ipairs(light) do
		gt(s.volumeOverride, 0.4, "audible")
		lt(s.volumeOverride, 0.7, "at the indoor gain")
	end
end)

it("drips every 3-9 seconds, quieter than the bed", function()
	local w = roofed()
	local from = #w.mock.sounds
	w:advance(120, 0.1)
	local d = of(w.mock, from, DRIP)
	gt(#d, 10, "drips are playing")
	for i = 2, #d do
		local gap = d[i].at - d[i - 1].at
		gt(gap, 2.95, "no sooner than 3 s")
		lt(gap, 9.15, "no later than 9 s")
	end
	for _, s in ipairs(d) do lt(s.volumeOverride, 0.45, "a drip is never the loudest thing") end
	eq(#w.mock.errors, 0, "errors")
end)

it("stepping outside restores the heavy bed and stops the drips", function()
	local w = roofed(nil, function(w) w:slash("heavy") end)
	local f0 = #w.mock.sounds
	w:advance(20, 0.1)
	gt(#of(w.mock, f0, DRIP), 0, "control: drips played while under the roof")
	w.mock.state.indoors = false
	w:advance(3.0)
	local from = #w.mock.sounds
	w:advance(60, 0.1)
	gt(#of(w.mock, from, HEAVY), 0, "the heavy bed is back")
	eq(#of(w.mock, from, DRIP), 0, "no more drips")
	gt(#of(w.mock, from, 538981), 0, "and the under-layer")
end)

it("plays no drips in snow, under indoors on, off, or with sound off", function()
	local function drips(setup)
		local w = H.world()
		setup(w)
		w:advance(0.5)
		w.mock.state.indoors = true
		w:advance(3.0)
		local from = #w.mock.sounds
		w:advance(60, 0.1)
		return #of(w.mock, from, DRIP)
	end
	gt(drips(function() end), 0, "control: rain under dim drips in this same harness")
	eq(drips(function(w) w:slash("snow") end), 0, "snow")
	eq(drips(function(w) w:slash("indoors on") end), 0, "on")
	eq(drips(function(w) w:slash("indoors off") end), 0, "off")
	eq(drips(function(w) w:slash("sound off") end), 0, "sound off")
end)

it("the Sound only indoor mode patters too", function()
	local w = H.world()
	w:slash("indoors sound")
	w:advance(0.5)
	w.mock.state.indoors = true
	w:advance(3.0)
	local from = #w.mock.sounds
	w:advance(60, 0.1)
	gt(#of(w.mock, from, DRIP), 0, "drips")
	gt(#of(w.mock, from, LIGHT), 0, "light bed")
end)

it("drips stop when the rain stops and in a cinematic", function()
	local w = roofed()
	local f0 = #w.mock.sounds
	w:advance(20, 0.1)
	gt(#of(w.mock, f0, DRIP), 0, "control: drips played before the rain stopped")
	w:slash("off")
	local from = #w.mock.sounds
	w:advance(60, 0.1)
	eq(#of(w.mock, from, DRIP), 0, "weather off")
	w:slash("on")
	w:advance(5, 0.1)
	from = #w.mock.sounds
	w:advance(30, 0.1)
	gt(#of(w.mock, from, DRIP), 0, "control: drips come back with the rain")
	w.mock.fire("CINEMATIC_START")
	from = #w.mock.sounds
	w:advance(60, 0.1)
	eq(#of(w.mock, from, DRIP), 0, "cinematic")
end)

it("a refused drip kit is skipped silently and latches nothing", function()
	-- No drip kit known to the client: PlaySoundWithOptions returns nil for it.
	local w = roofed({ kitFiles = {
		[8533] = 538983, [8534] = 538981, [8535] = 538982,
		[8536] = 538985, [8537] = 538989, [8538] = 538984 } })
	local from = #w.mock.sounds
	w:advance(60, 0.1)
	eq(#of(w.mock, from, DRIP), 0, "nothing played")
	local tried = 0
	for i = from + 1, #w.mock.sounds do
		local x = w.mock.sounds[i]
		if x.file == 40339 and x.ok == false then tried = tried + 1 end
	end
	gt(tried, 3, "control: drips were attempted and refused")
	gt(#of(w.mock, from, LIGHT), 0, "the bed still plays through its kit")
	eq(#w.mock.errors, 0, "errors")
	-- Had kitsRefused latched, the bed would now play by file with no gain.
	local f2 = #w.mock.sounds
	w:advance(40, 0.1)
	for _, s in ipairs(of(w.mock, f2, LIGHT)) do
		ok(s.volumeOverride, "bed still has gain control")
	end
end)

it("Retail picks its own drip kit", function()
	local w = roofed({ iface = 120107 })
	local from = #w.mock.sounds
	w:advance(30, 0.1)
	local seen
	for i = from + 1, #w.mock.sounds do
		if w.mock.sounds[i].file == DRIP then seen = w.mock.sounds[i].kit end
	end
	eq(seen, 60199, "retail kit")
end)

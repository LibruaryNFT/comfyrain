-- Rain stops when the head goes under water (#46). Only IsSubmerged counts;
-- swimming at the surface keeps the rain.

local H = require("harness")
local it, eq, ok = H.it, H.eq, H.ok

local function liveHandles(mock)
	local n = 0
	for _ in pairs(mock.handles) do n = n + 1 end
	return n
end

local function settled()
	local w = H.world()
	w:advance(2, 0.1)
	return w
end

it("hides the drops and stops the bed within a moment of diving", function()
	local w = settled()
	ok(w:perceivable().shown, "raining before the dive")
	ok(liveHandles(w.mock) > 0, "the bed is playing before the dive")
	w.mock.state.submerged = true
	w.mock.state.swimming = true
	w:advance(0.35, 0.05)
	eq(liveHandles(w.mock), 0, "every bed handle stopped within a poll")
	w:advance(0.4, 0.05)
	ok(not w:perceivable().shown, "the sheet is gone by the end of its fade")
end)

it("stops the bed with a short fade argument", function()
	local w = settled()
	w.mock.state.submerged = true
	w:advance(0.4, 0.05)
	local faded = false
	for _, s in ipairs(w.mock.sounds) do
		if s.stop and s.fadeMs and s.fadeMs > 0 then faded = true end
	end
	ok(faded, "StopSound was given a fade")
end)

it("brings the rain and the bed back about a second after surfacing", function()
	local w = settled()
	w.mock.state.submerged = true
	w:advance(1, 0.05)
	w.mock.state.submerged = false
	-- 0.8 s debounce plus up to one 0.3 s poll: back by 1.2 s, not before 0.8.
	w:advance(0.7, 0.05)
	ok(not w:perceivable().shown, "still hidden inside the debounce")
	w:advance(0.5, 0.05)
	ok(liveHandles(w.mock) > 0, "the bed restarted")
	ok(w:perceivable().shown, "the sheet is coming back")
end)

it("keeps the rain while swimming at the surface", function()
	local w = settled()
	w.mock.state.swimming = true
	w:advance(3, 0.1)
	ok(w:perceivable().shown, "still drawing")
	ok(liveHandles(w.mock) > 0, "still playing")
end)

it("does not flicker when bobbing at the surface", function()
	local w = settled()
	w.mock.state.submerged = true
	w:advance(0.4, 0.05)
	local restarts = #w.mock.sounds
	-- Head clear for 0.5 s, under for 0.5 s, repeatedly: never out for the
	-- 0.8 s the exit debounce needs, so the rain must stay off throughout.
	for _ = 1, 4 do
		w.mock.state.submerged = false
		w:advance(0.5, 0.05)
		w.mock.state.submerged = true
		w:advance(0.5, 0.05)
	end
	eq(#w.mock.sounds, restarts, "no clip was started while bobbing")
	eq(liveHandles(w.mock), 0, "still silent")
	ok(not w:perceivable().shown, "still hidden")
end)

it("strikes no thunder while submerged", function()
	local w = settled()
	w.mock.state.submerged = true
	w:advance(0.4, 0.05)
	local before = #w.mock.sounds
	w:advance(200, 0.5)
	eq(#w.mock.sounds, before, "nothing played in 200 seconds under water")
end)

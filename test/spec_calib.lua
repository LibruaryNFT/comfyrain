-- The calibration logger. It gets one session, on a client that is withdrawn
-- on 2026-10-21, and if it is broken there is no second chance to find out.

local H = require("harness")
local it, eq, ok, near, gt = H.it, H.eq, H.ok, H.near, H.gt

local LINE = "Weather changed to 1 intensity 0.80 recID 557"

it("raises the density cvars, because otherwise it measures nothing", function()
	-- weatherDensity 0 means the client never draws real weather, and that is
	-- how this machine has been set since before the addon existed. A logging
	-- session with it still at 0 would record an afternoon of clear skies and
	-- read as evidence that nothing happens.
	local w = H.world()
	eq(w.mock.cvars.weatherDensity, "0", "starting density")
	w:slash("calib on")
	eq(w.mock.cvars.weatherDensity, "3", "density after calib on")
	eq(w.mock.cvars.graphicsEnvironmentDetail, "2", "environment detail")
end)

it("records a baseline so there is something to difference against", function()
	local w = H.world()
	w:slash("calib on")
	local log = w:db().calib
	eq(#log, 1, "entries after starting")
	eq(log[1].source, "baseline", "the first entry is the clear-weather baseline")
end)

it("parses the engine's own weather line", function()
	-- Reading CONSOLE_MESSAGE is better than C_Weather here: it carries a raw
	-- numeric type and a record ID rather than a three-value enum, and it is
	-- old engine plumbing rather than a retail namespace we have only proven
	-- the strings of.
	local w = H.world({ state = { zone = "Duskwood", subzone = "Darkshire" } })
	w:slash("calib on")
	w.mock.fire("CONSOLE_MESSAGE", LINE)

	local e = w:db().calib[2]
	ok(e ~= nil, "an entry was recorded")
	eq(e.source, "console", "source")
	eq(e.console.type, 1, "weather type")
	near(e.console.intensity, 0.80, 1e-9, "intensity")
	eq(e.console.recordID, 557, "record id")
	eq(e.zone, "Duskwood", "zone")
	eq(e.subzone, "Darkshire", "subzone")
	eq(e.indoors, false, "indoor flag is a boolean, not nil")
	ok(e.at ~= nil and e.gameTime ~= nil, "timestamped against both clocks")
end)

it("ignores console traffic that is not about weather", function()
	local w = H.world()
	w:slash("calib on")
	local before = #w:db().calib
	w.mock.fire("CONSOLE_MESSAGE", "Loaded 12 addons")
	w.mock.fire("CONSOLE_MESSAGE", "")
	eq(#w:db().calib, before, "unrelated lines are not logged")
end)

it("shouts loudly enough to be noticed from across the room", function()
	-- The session is worthless if he is looking away when the weather turns,
	-- and real weather is server-driven and cannot be summoned.
	local w = H.world()
	w:slash("calib on")
	w.mock.fire("CONSOLE_MESSAGE", LINE)
	gt(#w.mock.printedMatching("REAL WEATHER"), 0, "the alert fired")
	gt(#w.mock.printedMatching("screenshot"), 0, "and said what to do about it")
end)

it("also logs through WEATHER_CHANGED when the console event is missing", function()
	local w = H.world({ missingEvents = { "CONSOLE_MESSAGE" } })
	w:slash("calib on")
	w.mock.fire("WEATHER_CHANGED")
	local log = w:db().calib
	eq(#log, 2, "entries")
	eq(log[2].source, "event", "fell back to the event")
end)

it("captures what C_Weather thinks at the same moment", function()
	local w = H.world({ state = { weather = { type = 1, intensity = 0.65 } } })
	w:slash("calib on")
	eq(w:db().calib[1].cWeather, "rain", "C_Weather reading")
	near(w:db().calib[1].cGrade, 0.65, 1e-9, "C_Weather intensity")
end)

it("keeps the log across a reload, and can be wiped", function()
	-- Early Forever builds wrote SavedVariables and never read them back. That
	-- is reportedly fixed and it is contested, which is why the logger also
	-- prints every entry. This covers the half that is ours to get right.
	local w = H.world()
	w:slash("calib on")
	w.mock.fire("CONSOLE_MESSAGE", LINE)
	local saved = w:db()
	eq(#saved.calib, 2, "entries before the reload")

	local w2 = H.world({ loaded = false })
	w2.env.ComfyRainDB = saved
	w2:load()
	eq(#w2:db().calib, 2, "entries survive a reload")

	w2:slash("calib wipe")
	eq(#w2:db().calib, 0, "wiped")
end)

it("stops cleanly and reports the count", function()
	local w = H.world()
	w:slash("calib on")
	w.mock.fire("CONSOLE_MESSAGE", LINE)
	w:slash("calib off")
	w.mock.fire("CONSOLE_MESSAGE", LINE)
	eq(#w:db().calib, 2, "nothing logged after stopping")
	gt(#w.mock.printedMatching("observations"), 0, "reported the count")
end)

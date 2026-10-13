-- Loading, saved variables, and the ways this client can abort a Lua file.

local H = require("harness")
local it, eq, ok, near = H.it, H.eq, H.ok, H.near

it("loads and registers its slash command", function()
	local w = H.world()
	eq(w.env.SLASH_ALWAYSRAIN1, "/rain", "primary slash token")
	eq(w.env.SLASH_ALWAYSRAIN2, "/alwaysrain", "secondary slash token")
	eq(type(w.env.SlashCmdList.ALWAYSRAIN), "function", "slash handler")
	eq(#w.mock.errors, 0, "errors during boot")
end)

it("builds both frames under WorldFrame, not UIParent", function()
	local w = H.world()
	-- Parenting decides whether the rain survives Alt+Z and whether it sits
	-- above the 3D scene but below the UI. Getting it wrong is invisible in a
	-- screenshot of a still frame and obvious in use.
	eq(w:overlay()._parent, w.env.WorldFrame, "overlay parent")
	eq(w:tod()._parent, w.env.WorldFrame, "time-of-day parent")
	eq(w:overlay().strata, "BACKGROUND", "overlay strata")
	ok(w:tod().level < w:overlay().level, "the grade must sit under the rain")
	eq(w:overlay().mouseEnabled, false, "a fullscreen frame must not eat clicks")
end)

it("fills defaults without overwriting a saved profile", function()
	local w = H.world({ loaded = false })
	w.env.AlwaysRainDB = { intensity = "monsoon", gloom = 0.25 }
	w:load()
	local db = w:db()
	eq(db.intensity, "monsoon", "saved intensity survives")
	near(db.gloom, 0.25, 1e-9, "saved gloom survives")
	eq(db.enabled, true, "missing key filled from defaults")
	eq(db.channel, "Ambience", "missing channel filled from defaults")
end)

it("survives a client that lacks the calibration events", function()
	-- RegisterEvent on an unknown name raises here, and the addon is one file,
	-- so an unguarded call would abort everything after it. The guard is a
	-- pcall per event; this proves the file is still whole afterwards.
	local w = H.world({ missingEvents = { "CONSOLE_MESSAGE", "WEATHER_CHANGED" } })
	w:slash("calib on")
	ok(#w.mock.printedMatching("neither CONSOLE_MESSAGE") > 0, "said so")
	w:slash("heavy")
	eq(w:db().intensity, "heavy", "the addon still works afterwards")
end)

it("does not raise when a restricted value is handed back", function()
	-- GetPlayerFacing is restricted in encounters. A secret value is non-nil and
	-- raises on arithmetic, so `if facing then` is not a sufficient guard.
	local w = H.world()
	w.mock.state.facing = w.mock.secretValue("facing")
	w:advance(1.0)
	eq(#w.mock.errors, 0, "errors while facing was secret")
	-- And the rain keeps falling, with the parallax frozen rather than gone.
	ok(w:layers().far.texCoord ~= nil, "layers still scrolling")
end)

it("hides everything during a cinematic and restores afterwards", function()
	local w = H.world()
	w.mock.fire("CINEMATIC_START")
	w:advance(1.5)
	eq(w:overlay():IsShown(), false, "overlay during a cinematic")
	w.mock.fire("CINEMATIC_STOP")
	w:advance(1.5)
	eq(w:overlay():IsShown(), true, "overlay after a cinematic")
end)

it("reports the build this client actually claims", function()
	-- 16001, not a retail five-digit interface number. Any `>= 100000` branch
	-- mis-fires here, which is why this is pinned in a test rather than trusted.
	local w = H.world()
	local _, _, _, iface = w.env.GetBuildInfo()
	eq(iface, 16001, "interface number")
end)

-- Loading, saved variables, and the ways this client can abort a Lua file.

local H = require("harness")
local it, eq, ok, near = H.it, H.eq, H.ok, H.near

it("loads and registers its slash command", function()
	local w = H.world()
	eq(w.env.SLASH_DUSKFALL1, "/dusk", "primary slash token")
	-- /rain is permanent, not deprecated. Anyone who installed the addon under
	-- its old name typed this for weeks and must never have to learn a new word.
	eq(w.env.SLASH_DUSKFALL2, "/rain", "the old name still works")
	eq(type(w.env.SlashCmdList.DUSKFALL), "function", "slash handler")
	-- The long name belongs to the window, not to the toggle.
	eq(w.env.SLASH_DUSKFALLUI1, "/duskfall", "the settings window has its own token")
	eq(type(w.env.SlashCmdList.DUSKFALLUI), "function", "window handler")
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
	w.env.DuskfallDB = { intensity = "monsoon", gloom = 0.25 }
	w:load()
	local db = w:db()
	eq(db.intensity, "monsoon", "saved intensity survives")
	near(db.gloom, 0.25, 1e-9, "saved gloom survives")
	eq(db.enabled, true, "missing key filled from defaults")
	eq(db.channel, "Ambience", "missing channel filled from defaults")
end)

it("carries settings over from the old AlwaysRain profile, once", function()
	local w = H.world({ loaded = false })
	w.env.AlwaysRainDB = { intensity = "monsoon", gloom = 0.25, channel = "SFX" }
	w:load()
	local db = w:db()
	eq(db.intensity, "monsoon", "old intensity carried over")
	near(db.gloom, 0.25, 1e-9, "old gloom carried over")
	eq(db.channel, "SFX", "old channel carried over")
	eq(db.migrated, true, "the migration marks itself done")
	ok(#w.mock.printedMatching("carried over") > 0, "and says so once")

	-- Second login: the old table is still on disk and must not be allowed to
	-- undo anything the player changed since. This is the whole point of the flag.
	local w2 = H.world({ loaded = false })
	w2.env.AlwaysRainDB = { intensity = "monsoon" }
	w2.env.DuskfallDB = { intensity = "light", migrated = true }
	w2:load()
	eq(w2:db().intensity, "light", "the new profile wins after the first migration")
end)

it("ignores an old profile that is not a table", function()
	-- A SavedVariables file that was half-written when the client was killed can
	-- read back as anything, and a restricted value is non-nil but explodes when
	-- touched. Losing the old settings is acceptable here; failing to load is not.
	--
	-- Note on what this does NOT prove: the copy loop itself is wrapped in a
	-- pcall, and on Lua 5.1 a plain table cannot make pairs() raise, so no test
	-- here can reach that pcall. It guards client-side weirdness the mock cannot
	-- reproduce. The type guard below is the part that is actually testable.
	for _, bad in ipairs({ "a string", 7, true }) do
		local w = H.world({ loaded = false })
		w.env.AlwaysRainDB = bad
		w:load()
		eq(type(w:db()), "table", "the addon still has a database")
		eq(w:db().enabled, true, "and fell back to defaults")
		eq(#w.mock.errors, 0, "errors during boot")
	end
end)

it("takes dim as the new name for gloom, and still answers to gloom", function()
	local w = H.world()
	w:slash("dim 0.4")
	near(w:db().gloom, 0.4, 1e-9, "dim sets it")
	w:slash("gloom 0.8")
	near(w:db().gloom, 0.8, 1e-9, "the old subcommand is a permanent alias")
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

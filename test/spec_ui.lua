-- The settings window.
--
-- The contract being tested is not "the panel has a button". It is that the
-- window and the slash commands are the same addon: every control goes through
-- the command parser, a typed command moves the window, and the window moving
-- does not type a command back. That loop is the only way a settings panel can
-- be subtly wrong, and it is invisible by eye.

local H = require("harness")
local it, eq, ok, near, lt, gt, contains = H.it, H.eq, H.ok, H.near, H.lt, H.gt, H.contains

it("opens on /duskfall and closes again", function()
	local w = H.world()
	w.mock.slash("DUSKFALLUI", "")
	ok(w:panel(), "the window exists once asked for")
	ok(w:panel():IsShown(), "and it is open")

	w.mock.slash("DUSKFALLUI", "")
	eq(w:panel():IsShown(), false, "typing it again closes it")
end)

it("answers /dusk ui, config, options and settings as well", function()
	-- Nobody remembers which word an addon chose, so it answers to all of them.
	for _, word in ipairs({ "ui", "config", "options", "settings" }) do
		local w = H.world()
		w:slash(word)
		ok(w:panel() and w:panel():IsShown(), "/dusk " .. word .. " opens the window")
	end
end)

it("closes on Escape, which means the frame has to have a name", function()
	local w = H.world()
	w:open()
	local found = false
	for _, name in ipairs(w.env.UISpecialFrames) do
		if name == "DuskfallPanel" then found = true end
	end
	ok(found, "DuskfallPanel is in UISpecialFrames")
	eq(w:panel():GetName(), "DuskfallPanel", "and the frame carries that name")
end)

it("shows itself once on a first install and never again", function()
	-- Someone who installs an atmosphere addon is not a power user and will not
	-- go looking for a command list. They also will not forgive a window that
	-- reopens every login.
	local w = H.world()
	w:advance(10)
	ok(w:panel() and w:panel():IsShown(), "the window introduced itself")
	eq(w:db().seenUI, true, "and recorded that it had")

	local saved = w:db()
	local two = H.world({ loaded = false })
	two.env.DuskfallDB = saved
	two:load()
	two:advance(10)
	ok(not (two:panel() and two:panel():IsShown()), "second login is left alone")
end)

it("says nothing at all on an ordinary login", function()
	-- An addon that greets you every login spends 300 lines of chat a year on
	-- information you needed once. The window is the introduction; after it has
	-- been seen, loading is silent.
	local w = H.world()
	w:advance(10)
	local saved = w:db()

	local two = H.world({ loaded = false })
	two.env.DuskfallDB = saved
	two:load()
	local before = #two.mock.printed
	two:advance(10)
	eq(#two.mock.printed - before, 0, "nothing was printed on the second login")
end)

it("falls back to printing the commands when there is no window to show", function()
	-- The greeting is not decoration, it is the only onboarding a player gets
	-- if UI.lua is missing. It has to survive that case and only that case.
	local w = H.world({ ui = false })
	w:advance(10)
	local joined = table.concat(w.mock.printed, " | ")
	contains(joined, "/duskfall", "a first install with no window still learns the command")
end)

it("drives the addon through the commands, not around them", function()
	local w = H.world()
	w:open()
	w:button("Snow"):Click()
	eq(w:db().weather, "snow", "the weather changed")
	-- Proof it went through the real path rather than writing the setting: the
	-- sheets only swap inside the command handler's Refresh.
	ok(tostring(w:layers().far.texture):find("snow"), "and the sheets followed")

	w:button("Rain"):Click()
	eq(w:db().weather, "rain", "and back")
end)

it("names the top intensity after the weather it belongs to", function()
	local w = H.world()
	w:open()
	ok(w:button("Monsoon"), "rain tops out at Monsoon")
	eq(w:button("Blizzard"), nil, "and does not offer Blizzard")

	w:button("Snow"):Click()
	ok(w:button("Blizzard"), "snow tops out at Blizzard")
	eq(w:button("Monsoon"), nil, "and the rain word is gone")

	w:button("Blizzard"):Click()
	eq(w:db().intensity, "blizzard", "clicking it applies it")
	gt(w:whiteout():GetAlpha(), 0, "and the whiteout came on, so it really ran")
end)

it("calls the lightning button what it actually does", function()
	local w = H.world()
	w:open()
	ok(w:button("Thunder"), "rain thunders")
	w:button("Snow"):Click()
	ok(w:button("Gusts"), "snow gusts")
	eq(w:button("Thunder"), nil, "and never claims to thunder")
end)

it("toggles sound, gusts and indoors from the window", function()
	local w = H.world()
	w:open()
	eq(w:db().sound, true, "sound starts on")
	w:button("Sound"):Click()
	eq(w:db().sound, false, "the button turned it off")
	w:button("Sound"):Click()
	eq(w:db().sound, true, "and on again")

	w:button("Indoors"):Click()
	eq(w:db().indoors, true, "indoors follows the same path")
end)

it("cycles the volume channel rather than opening a menu", function()
	-- UIDropDownMenu is a template, and templates are the part of the client
	-- this addon deliberately does not depend on.
	local w = H.world()
	w:open()
	eq(w:db().channel, "Ambience", "starts on Ambience")
	w:button("Volume: Ambience"):Click()
	eq(w:db().channel, "SFX", "cycles to the next")
	ok(w:button("Volume: SFX"), "and relabels itself")
end)

it("applies a slider as it moves, and clamps where the parser clamps", function()
	local w = H.world()
	w:open()
	local s = w:slider("How visible it is")
	ok(s, "the visibility slider exists")

	s:Drag(0.5)
	near(w:db().scale, 0.5, 1e-9, "dragging applied it")
	near(w:layers().far:GetAlpha(), 0.35, 1e-9, "and the rain actually got fainter")

	-- The slider's own ceiling and the command parser's have to be the same
	-- number, or the window offers a value the addon will refuse.
	s:Drag(99)
	near(w:db().scale, 1.5, 1e-9, "clamped at the same 1.5 the parser uses")
end)

it("follows a typed command while it is open", function()
	local w = H.world()
	w:open()
	w:slash("snow")
	w:slash("blizzard")
	eq(w:button("Blizzard").selected, true, "the window moved with the command")
	near(w:slider("How dark it gets"):GetValue(), w:db().gloom, 1e-9, "sliders too")
end)

it("does not type a command back at itself when it refreshes", function()
	-- Setting a widget fires its OnValueChanged. If that write escaped as a
	-- command, every refresh would issue three more, and a slider would be
	-- unmovable because its own echo would fight the drag.
	local w = H.world()
	w:open()
	w:slash("alpha 0.80")
	local before = #w.mock.printed
	for _ = 1, 5 do w.env.Duskfall_Panel("show") end
	near(w:db().scale, 0.80, 1e-9, "the value survived five refreshes unchanged")
	eq(#w.mock.printed - before, 0, "and nothing was announced, because nothing happened")
end)

it("stays quiet when the window does it, and speaks when the player types it", function()
	local w = H.world()
	w:open()
	local before = #w.mock.printed
	w:button("Snow"):Click()
	eq(#w.mock.printed - before, 0, "clicking does not narrate itself into chat")

	before = #w.mock.printed
	w:slash("rain")
	gt(#w.mock.printed - before, 0, "a typed command still reports, as it always did")
end)

it("teaches the command for whatever is under the cursor", function()
	local w = H.world()
	w:open()
	local b = w:button("Snow")
	b:GetScript("OnEnter")(b)
	local joined = table.concat(w.env.GameTooltip.lines, " | ")
	contains(joined, "/dusk snow", "the tooltip names the command")
	b:GetScript("OnLeave")(b)
	eq(w.env.GameTooltip:IsShown(), false, "and clears on the way out")
end)

it("hides the time-of-day controls until time of day is on", function()
	local w = H.world()
	w:open()
	eq(w:slider("How strongly"):GetParent():IsShown(), false, "hidden while off")

	w:button("Held"):Click()
	eq(w:db().timeMode, "fixed", "the mode changed")
	eq(w:slider("How strongly"):GetParent():IsShown(), true, "and the controls appeared")
	eq(w:slider("Hold this hour"):GetParent():IsShown(), true, "including the hour")

	w:slider("Hold this hour"):Drag(3)
	eq(w:db().timeFixed, 3, "which sets the hour it holds")

	w:button("Shifted"):Click()
	w:slider("Shift the realm's clock by hours"):Drag(-5)
	eq(w:db().timeMode, "offset", "shifted mode")
	eq(w:db().timeOffset, -5, "and a negative shift, which needs the sign")
end)

it("resets the settings and keeps the evidence", function()
	-- A reset button that threw away a week of weather observations would be a
	-- bug with a label on it.
	local w = H.world()
	w:slash("calib on")
	w:db().calib = { { zone = "Elwynn" } }
	w:open()
	w:button("Snow"):Click()
	w:slider("How visible it is"):Drag(0.3)

	w:button("Reset"):Click()
	eq(w:db().weather, "rain", "weather back to default")
	near(w:db().scale, 1.0, 1e-9, "alpha back to default")
	eq(#w:db().calib, 1, "the calibration log is untouched")
end)

it("remembers where it was dragged to", function()
	local w = H.world()
	local p = w:open()
	p:GetScript("OnDragStart")(p)
	p._point, p._x, p._y = "TOPLEFT", 120, -300
	p:GetScript("OnDragStop")(p)
	eq(w:db().ui.point, "TOPLEFT", "the anchor was saved")
	eq(w:db().ui.x, 120, "and the position")
end)

it("sizes itself to what is actually on show", function()
	local w = H.world()
	local p = w:open()
	local short = p:GetHeight()
	w:button("Held"):Click()
	gt(p:GetHeight(), short, "the window grew for the time controls")
	w:button("Off"):Click()
	near(p:GetHeight(), short, 1e-9, "and shrank back")
end)

it("is not load-bearing: the addon works with the window deleted", function()
	-- UI.lua is a separate file and a player can delete it, a packager can miss
	-- it, and a future client can break it. None of that may cost the weather.
	local w = H.world({ ui = false })
	eq(w.env.Duskfall_Panel, nil, "no window")
	w:slash("snow")
	eq(w:db().weather, "snow", "the addon still answers")

	local before = #w.mock.printed
	w.mock.slash("DUSKFALLUI", "")
	gt(#w.mock.printed - before, 0, "/duskfall falls back to printing the commands")
	eq(#w.mock.errors, 0, "and nothing escaped to the client")
end)

it("survives a window that cannot be built at all", function()
	local w = H.world()
	w.env.CreateFrame = function() error("no frames for you", 2) end
	w:slash("ui")
	w.env.CreateFrame = nil
	w:slash("heavy")
	eq(w:db().intensity, "heavy", "the addon still answers afterwards")
	eq(#w.mock.errors, 0, "and the failure was caught, not thrown at the client")
end)

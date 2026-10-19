-- The settings window.
--
-- The contract being tested is not "the panel has a button". It is that the
-- window and the slash commands are the same addon: every control goes through
-- the command parser, a typed command moves the window, and the window moving
-- does not type a command back. That loop is the only way a settings panel can
-- be subtly wrong, and it is invisible by eye.

local H = require("harness")
local it, eq, ok, near, lt, gt, contains = H.it, H.eq, H.ok, H.near, H.lt, H.gt, H.contains

it("opens on /comfyrain and closes again", function()
	local w = H.world()
	w.mock.slash("COMFYRAINUI", "")
	ok(w:panel(), "the window exists once asked for")
	ok(w:panel():IsShown(), "and it is open")

	w.mock.slash("COMFYRAINUI", "")
	eq(w:panel():IsShown(), false, "typing it again closes it")
end)

it("answers /comfy ui, config, options and settings as well", function()
	-- Nobody remembers which word an addon chose, so it answers to all of them.
	for _, word in ipairs({ "ui", "config", "options", "settings" }) do
		local w = H.world()
		w:slash(word)
		ok(w:panel() and w:panel():IsShown(), "/comfy " .. word .. " opens the window")
	end
end)

it("closes on Escape, which means the frame has to have a name", function()
	local w = H.world()
	w:open()
	local found = false
	for _, name in ipairs(w.env.UISpecialFrames) do
		if name == "ComfyRainPanel" then found = true end
	end
	ok(found, "ComfyRainPanel is in UISpecialFrames")
	eq(w:panel():GetName(), "ComfyRainPanel", "and the frame carries that name")
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
	two.env.ComfyRainDB = saved
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
	two.env.ComfyRainDB = saved
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
	contains(joined, "/comfyrain", "a first install with no window still learns the command")
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

	-- Indoors cycles three ways rather than toggling two, because the useful
	-- setting is the middle one.
	eq(w:db().indoors, "dim", "starts dimmed")
	w:button("Indoors: Dim"):Click()
	eq(w:db().indoors, "on", "dim then on")
	w:button("Indoors: On"):Click()
	eq(w:db().indoors, "off", "on then off")
	w:button("Indoors: Off"):Click()
	eq(w:db().indoors, "dim", "and back round")
end)

it("switches the camera-zoom response from the window", function()
	-- The one setting whose effect a player cannot see without moving the
	-- camera, which is exactly why it needs to be visible in the window rather
	-- than living only behind a slash command nobody will find.
	local w = H.world()
	w:open()
	eq(w:db().zoom, true, "on by default")
	w:button("Zoom Response"):Click()
	eq(w:db().zoom, false, "the button turned it off")
	w:button("Zoom Response"):Click()
	eq(w:db().zoom, true, "and on again")
end)

it("cycles the volume channel rather than opening a menu", function()
	-- UIDropDownMenu is a template, and templates are the part of the client
	-- this addon deliberately does not depend on.
	local w = H.world()
	w:open()
	eq(w:db().channel, "Ambience", "starts on Ambience")
	w:button("Channel: Ambience"):Click()
	eq(w:db().channel, "SFX", "cycles to the next")
	ok(w:button("Channel: SFX"), "and relabels itself")
end)

it("applies a slider as it moves, and clamps where the parser clamps", function()
	local w = H.world()
	w:open()
	local s = w:slider("Visibility")
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
	near(w:slider("Darkness"):GetValue(), w:db().gloom, 1e-9, "sliders too")
end)

it("does not type a command back at itself when it refreshes", function()
	-- Setting a widget fires its OnValueChanged. If that write escaped as a
	-- command, every refresh would issue three more, and a slider would be
	-- unmovable because its own echo would fight the drag.
	local w = H.world()
	w:open()
	w:slash("alpha 0.80")
	local before = #w.mock.printed
	for _ = 1, 5 do w.env.ComfyRain_Panel("show") end
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
	contains(joined, "/comfy snow", "the tooltip names the command")
	b:GetScript("OnLeave")(b)
	eq(w.env.GameTooltip:IsShown(), false, "and clears on the way out")
end)

it("hides the time-of-day controls until time of day is on", function()
	local w = H.world()
	w:open()
	eq(w:slider("Strength"):GetParent():IsShown(), false, "hidden while off")

	w:button("Held"):Click()
	eq(w:db().timeMode, "fixed", "the mode changed")
	eq(w:slider("Strength"):GetParent():IsShown(), true, "and the controls appeared")
	eq(w:slider("Hold at Hour"):GetParent():IsShown(), true, "including the hour")

	w:slider("Hold at Hour"):Drag(3)
	eq(w:db().timeFixed, 3, "which sets the hour it holds")

	w:button("Shifted"):Click()
	w:slider("Shift by Hours"):Drag(-5)
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
	w:slider("Visibility"):Drag(0.3)

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
	eq(w.env.ComfyRain_Panel, nil, "no window")
	w:slash("snow")
	eq(w:db().weather, "snow", "the addon still answers")

	local before = #w.mock.printed
	w.mock.slash("COMFYRAINUI", "")
	gt(#w.mock.printed - before, 0, "/comfyrain falls back to printing the commands")
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

it("puts a button on the minimap, because a slash command nobody knows is not a UI", function()
	-- The whole discoverability problem: a player who installs an atmosphere
	-- addon and is never told a window exists will never find the sliders.
	local w = H.world()
	w.env.ComfyRain_Minimap()
	local b = w.env.ComfyRainMinimapButton
	ok(b, "the button exists")
	ok(b:IsShown(), "and it is shown by default")

	-- Left-click opens the window, right-click toggles the weather.
	b:GetScript("OnClick")(b, "LeftButton")
	ok(w.env.ComfyRainPanel and w.env.ComfyRainPanel:IsShown(), "left-click opened the panel")
	local on = w:db().enabled
	b:GetScript("OnClick")(b, "RightButton")
	eq(w:db().enabled, not on, "right-click toggled the weather")

	-- And it can be turned off by someone whose minimap is already full.
	w:slash("minimap off")
	eq(b:IsShown(), false, "hidden on request")
	w:slash("minimap on")
	ok(b:IsShown(), "and back")
end)

it("orbits the minimap the player actually has, not a 140px one", function()
	-- Reported from a live client 2026-10-15: on an enlarged minimap the button
	-- sat inside the map, on top of the terrain, because the radius was the
	-- hard-coded 80 that every addon copies from a default-sized minimap.
	local function radiusOn(size)
		local w = H.world()
		w.env.Minimap:SetSize(size, size)
		w.env.ComfyRain_Minimap()
		local b = w.env.ComfyRainMinimapButton
		local p = b._lastPoint
		return math.sqrt(p.x * p.x + p.y * p.y), w
	end

	local small = radiusOn(140)
	near(small, 80, 0.5, "a default minimap still gets the familiar 80")

	local big = radiusOn(240)
	ok(big > 240 / 2, "a doubled minimap puts the button outside its edge")

	-- And it keeps up if the minimap is resized after the button was built.
	local w = H.world()
	w.env.ComfyRain_Minimap()
	local b = w.env.ComfyRainMinimapButton
	w.env.Minimap:SetSize(300, 300)
	local resize = w.env.Minimap:GetScript("OnSizeChanged")
	ok(resize, "the button watches the minimap for a resize")
	resize(w.env.Minimap, 300, 300)
	local p = b._lastPoint
	ok(math.sqrt(p.x * p.x + p.y * p.y) > 150, "and moved back out to the new edge")
end)

it("remembers where the minimap button was dragged to", function()
	local w = H.world()
	w.env.ComfyRain_Minimap()
	local b = w.env.ComfyRainMinimapButton
	local before = w:db().minimapAngle
	b:GetScript("OnDragStart")(b)
	-- Cursor directly above the minimap centre is 90 degrees.
	w.mock.cursor.x, w.mock.cursor.y = 1000, 800
	b:GetScript("OnUpdate")(b, 0.1)
	b:GetScript("OnDragStop")(b)
	near(w:db().minimapAngle, 90, 1, "the angle followed the cursor")
	ok(w:db().minimapAngle ~= before, "and it is not the default any more")
end)

it("has a volume slider that only touches our own weather", function()
	-- Asked for directly: sliders for the audio, the snow, the rain and the
	-- darkness. The other three already existed; this is the audio one.
	local w = H.world()
	w:slash("volume 0.25")
	near(w:db().volume, 0.25, 1e-9, "the command set it")
	w:slash("volume 9")
	near(w:db().volume, 1, 1e-9, "clamped at the top")
	w:slash("volume -3")
	near(w:db().volume, 0, 1e-9, "and at the bottom")

	-- It reaches the actual playback, not just the saved variable. Counted from
	-- after the change: gain is baked in at play time, so clips that started
	-- before the slider moved legitimately keep their old level.
	local from = #w.mock.sounds
	w:slash("volume 0.5")
	local loudest = 0
	for i = from + 1, #w.mock.sounds do
		local s = w.mock.sounds[i]
		if s.volumeOverride and s.volumeOverride > loudest then loudest = s.volumeOverride end
	end
	lt(loudest, 0.6, "nothing played above the slider, allowing for the wobble")
	gt(loudest, 0, "and something played")
end)

it("wears the game's own frame, and still builds on a client without one", function()
	-- "Make it look more native to WoW", 2026-10-16. The gold nine-sliced dialog
	-- edge and the carved header plate are the two pieces that make a frame read
	-- as part of the interface rather than as an addon's dark rectangle.
	local w = H.world()
	local p = w:open()
	local b = p:GetBackdrop()
	ok(b and b.edgeFile, "the panel took Blizzard's dialog border")
	contains(b.edgeFile, "UI-DialogBox-Border", "the gold one")

	local header, title = nil, nil
	for _, t in ipairs(p._textures) do
		if t.texture and t.texture:find("UI%-DialogBox%-Header") then header = t end
	end
	for _, fs in ipairs(p._fontStrings) do
		if fs.text == "ComfyRain" then title = fs end
	end
	ok(header, "and the carved header plate")
	ok(title, "with the addon's name on it")

	-- The fallback is not decoration either: a client with no BackdropTemplate
	-- must still get a bordered window, not a floating pile of controls.
	local old = H.world({ backdropTemplate = false })
	local q = old:open()
	ok(q and q:IsShown(), "the window still opens")
	eq(q.GetBackdrop, nil, "with no backdrop available")
	local edges = 0
	for _, t in ipairs(q._textures) do
		if t.layer == "BORDER" and t.colour then edges = edges + 1 end
	end
	eq(edges, 4, "so it drew its own four-sided border instead")
	eq(#old.mock.errors, 0, "and nothing was thrown at the client")
end)

it("draws its own minimap icon and repaints it with the weather", function()
	-- "The icon doesn't look too unique", 2026-10-16. It was a stock Blizzard
	-- spell texture, which is what half of CurseForge uses.
	local w = H.world()
	w.env.ComfyRain_Minimap()
	local b = w.env.ComfyRainMinimapButton

	for _, t in ipairs(b._textures) do
		ok(not (t.texture and t.texture:find("Interface\\\\Icons")),
			"nothing on the button is a borrowed spell icon")
	end

	local function drops()
		local out = {}
		for _, t in ipairs(b._textures) do
			if t.layer == "ARTWORK" and t.colour then out[#out + 1] = t end
		end
		return out
	end
	local function sky()
		for _, t in ipairs(b._textures) do
			if t.layer == "BACKGROUND" then return t end
		end
	end

	local rain = drops()
	gt(#rain, 3, "the rain is drawn as streaks")
	gt(rain[1]:GetHeight(), rain[1]:GetWidth(), "which are taller than they are wide")
	near(rain[1].rotation, -0.131, 1e-6, "slanted the same way the sheets are")

	w:slash("snow")
	local flakes = drops()
	near(flakes[1]:GetHeight(), flakes[1]:GetWidth(), 1e-9, "a flake is a dot")
	eq(flakes[1].rotation, 0, "and does not slant")

	local lit = { unpack(sky().colour) }
	w:slash("off")
	local dark = sky().colour
	ok(lit[1] ~= dark[1] or lit[3] ~= dark[3],
		"the sky greys out when the weather is off")
	ok(dark[3] <= dark[1] + 0.02, "no blue left in it")
end)

-- The settings window.
--
-- The contract being tested is not "the panel has a button". It is that the
-- window and the slash commands are the same addon: every control goes through
-- the command parser, a typed command moves the window, and the window moving
-- does not type a command back. That loop is the only way a settings panel can
-- be subtly wrong, and it is invisible by eye.

local H = require("harness")
local it, eq, ok, near, lt, gt, contains = H.it, H.eq, H.ok, H.near, H.lt, H.gt, H.contains

-- Step a Select row until it reads `value`. These specs used to click a pill
-- by name; a selector shows one value at a time, so "choose Snow" became
-- "press the arrow until it says Snow". Capped so a value that can never come
-- up fails the assertion that follows rather than hanging the suite.
local function choose(w, label, value)
	local s = w:select(label)
	if not s then return nil end
	for _ = 1, 8 do
		if s.value.text == value then return s end
		s.right:Click()
	end
	return s
end

local function reads(w, label)
	local s = w:select(label)
	return s and s.value.text
end

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
	choose(w, "Weather", "Snow")
	eq(w:db().weather, "snow", "the weather changed")
	-- Proof it went through the real path rather than writing the setting: the
	-- sheets only swap inside the command handler's Refresh.
	ok(tostring(w:layers().far.texture):find("snow"), "and the sheets followed")

	choose(w, "Weather", "Rain")
	eq(w:db().weather, "rain", "and back")
end)

it("names the top intensity after the weather it belongs to", function()
	local w = H.world()
	w:open()
	choose(w, "Intensity", "Monsoon")
	eq(w:db().intensity, "monsoon", "rain tops out at Monsoon")

	choose(w, "Weather", "Snow")
	-- The selector steps through the weather's OWN order, so the rain word is
	-- not reachable under snow rather than merely not shown.
	eq(reads(w, "Intensity"), "Blizzard", "and the top step renamed itself")
	choose(w, "Intensity", "Monsoon")
	eq(w:db().intensity, "blizzard", "Monsoon cannot be stepped to under snow")
	gt(w:whiteout():GetAlpha(), 0, "and the whiteout came on, so it really ran")
end)

it("steps an intensity backwards as well as forwards", function()
	-- Four values behind one control: the left arrow is the difference between
	-- this and a cycling button, and it is the reason a selector replaced one.
	local w = H.world()
	w:open()
	choose(w, "Intensity", "Light")
	w:select("Intensity").right:Click()
	eq(w:db().intensity, "normal", "forward a step")
	w:select("Intensity").left:Click()
	eq(w:db().intensity, "light", "and back again")
	w:select("Intensity").left:Click()
	eq(w:db().intensity, "monsoon", "off the bottom, round to the top")
end)

it("calls the lightning button what it actually does", function()
	local w = H.world()
	w:open()
	ok(w:button("Thunder"), "rain thunders")
	choose(w, "Weather", "Snow")
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
	eq(reads(w, "Indoors"), "Dim", "and says so")
	w:select("Indoors").right:Click()
	eq(w:db().indoors, "on", "dim then on")
	w:select("Indoors").right:Click()
	eq(w:db().indoors, "off", "on then off")
	w:select("Indoors").right:Click()
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
	w:select("Channel").right:Click()
	eq(w:db().channel, "SFX", "steps to the next")
	eq(reads(w, "Channel"), "SFX", "and says so")
	w:select("Channel").left:Click()
	eq(w:db().channel, "Ambience", "and back")
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
	eq(reads(w, "Weather"), "Snow", "the window moved with the command")
	eq(reads(w, "Intensity"), "Blizzard", "both selectors did")
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
	w:select("Weather").right:Click()
	eq(#w.mock.printed - before, 0, "clicking does not narrate itself into chat")

	before = #w.mock.printed
	w:slash("rain")
	gt(#w.mock.printed - before, 0, "a typed command still reports, as it always did")
end)

it("teaches the command for whatever is under the cursor", function()
	local w = H.world()
	w:open()
	local b = w:select("Weather").well
	b:GetScript("OnEnter")(b)
	local joined = table.concat(w.env.GameTooltip.lines, " | ")
	contains(joined, "/comfy rain", "the tooltip names the command")
	b:GetScript("OnLeave")(b)
	eq(w.env.GameTooltip:IsShown(), false, "and clears on the way out")
end)

it("hides the time-of-day controls until time of day is on", function()
	local w = H.world()
	w:open()
	eq(w:slider("Strength"):GetParent():IsShown(), false, "hidden while off")

	choose(w, "Mode", "Held")
	eq(w:db().timeMode, "fixed", "the mode changed")
	eq(w:slider("Strength"):GetParent():IsShown(), true, "and the controls appeared")
	eq(w:slider("Hold at Hour"):GetParent():IsShown(), true, "including the hour")

	w:slider("Hold at Hour"):Drag(3)
	eq(w:db().timeFixed, 3, "which sets the hour it holds")

	choose(w, "Mode", "Shifted")
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
	choose(w, "Weather", "Snow")
	w:slider("Visibility"):Drag(0.3)

	w:button("Reset All"):Click()
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
	choose(w, "Mode", "Held")
	gt(p:GetHeight(), short, "the window grew for the time controls")
	choose(w, "Mode", "Off")
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

--------------------------------------------------------------------------------
-- Turning it off, resetting it, and handing it to somebody else
--------------------------------------------------------------------------------

it("names every change it is making to the screen, in the window", function()
	-- From a live report: "my screen is too dark and i cant reset it easily,
	-- like i want to turn off the changes it made but i cant". The time of day
	-- grading has no weather attached to it, so a player who switched the
	-- weather off and still has a dark world has nothing to connect it to.
	local w = H.world()
	w:slash("time 21")
	w:slash("off")
	w:open()

	ok(w:says("Weather off"), "it says the weather is off")
	ok(w:says("21:00"), "and names the hour the light is being held at")
end)

it("says nothing is on when nothing is on, and hides the stop button", function()
	local w = H.world()
	w:slash("off")
	w:open()
	ok(w:says("Everything off"), "the all-clear is stated, not implied")

	local stop = w:button("Turn It All Off")
	eq(stop:IsShown(), false, "nothing left to stop, so no button to press")

	w:slash("on")
	ok(stop:IsShown(), "and it comes back the moment something is on")
end)

it("turns off the weather AND the light in one press", function()
	local w = H.world()
	w:slash("time 21")
	w:open()
	ok(w:db().enabled, "weather on to start with")

	w:button("Turn It All Off"):Click()
	eq(w:db().enabled, false, "the weather stopped")
	eq(w:db().timeMode, "off", "and so did the light grading")
	eq(w:tod():IsShown(), false, "nothing is left over the world")
end)

it("keeps the settings when it stops: it is a switch, not a reset", function()
	local w = H.world()
	w:slash("snow")
	w:slash("alpha 0.4")
	w:slash("time 21")
	w:slash("stop")

	eq(w:db().weather, "snow", "the weather it chose is still chosen")
	near(w:db().scale, 0.4, 1e-9, "and the slider it moved has not moved back")
	eq(w:db().timeFixed, 21, "the hour is remembered for when it comes back on")
end)

it("resets one section without touching the others", function()
	local w = H.world()
	w:slash("alpha 0.4")
	w:slash("volume 0.2")
	w:slash("time 21")
	w:open()

	w:button("Reset Sound"):Click()
	near(w:db().volume, 1.0, 1e-9, "the sound went back to default")
	near(w:db().scale, 0.4, 1e-9, "the look did not")
	eq(w:db().timeMode, "fixed", "and neither did the time of day")
end)

it("has a Reset for every section a setting can live in", function()
	-- The guard against a new setting being added to DEFAULTS and to no section:
	-- it would be a setting no Reset button can reach and no shared profile
	-- carries. Furniture is listed here deliberately, so adding to THAT list is
	-- a decision somebody makes on purpose.
	local w = H.world()
	w:open()

	local FURNITURE = { minimap = true, minimapAngle = true, ui = true,
	                    migrated = true, calib = true, calibrating = true,
	                    probe = true, where = true, seen = true, seenUI = true,
	                    undo = true }
	local covered = {}
	for _, name in ipairs(w.env.ComfyRainAPI.SectionOrder) do
		ok(w:button("Reset " .. name:gsub("^%l", string.upper)),
			name .. " has a Reset button")
		for _, k in ipairs(w.env.ComfyRainAPI.Sections[name]) do covered[k] = true end
	end
	for k in pairs(w:db()) do
		ok(covered[k] or FURNITURE[k], k .. " belongs to a section")
	end
end)

it("hands out a profile string, already selected, in a box", function()
	-- There is no SetClipboard in the client's Lua, so an EditBox is the only
	-- route out. A box the player has to drag across is not sharing.
	local w = H.world()
	w:slash("snow")
	w:slash("alpha 0.4")
	w:open()
	w:button("Share"):Click()

	local box = w:editBox()
	ok(box, "a box opened")
	ok(box:HasFocus(), "with the cursor already in it")
	ok(box._highlighted, "and the text already selected")
	contains(box:GetText(), "ComfyRain1:", "it is tagged as ours")
	contains(box:GetText(), "weather=snow", "and carries the settings")
	contains(box:GetText(), "scale=0.4", "including the ones off a slider")
end)

it("applies a profile pasted into the box and closes it", function()
	local w = H.world()
	w:slash("snow")
	w:open()
	w:button("Share"):Click()

	local box = w:editBox()
	box:Type("ComfyRain1:weather=rain;intensity=heavy;volume=0.25")
	box:Press("OnEnterPressed")

	eq(w:db().weather, "rain", "the pasted weather took")
	eq(w:db().intensity, "heavy", "and the intensity with it")
	near(w:db().volume, 0.25, 1e-9, "and the numbers")
	eq(w:shareBox():IsShown(), false, "the box got out of the way")
end)

it("round-trips: what it hands out is what it reads back", function()
	local w = H.world()
	w:slash("snow")
	w:slash("blizzard")
	w:slash("alpha 0.65")
	w:slash("volume 0.3")
	w:slash("channel master")
	w:slash("time 21")
	w:slash("sound off")
	local text = w.env.ComfyRainAPI.Export()

	local v = H.world()
	v:slash("import " .. text)
	for _, k in ipairs({ "weather", "intensity", "scale", "volume", "channel",
	                     "timeMode", "timeFixed", "sound", "enabled" }) do
		eq(tostring(v:db()[k]), tostring(w:db()[k]), k .. " survived the trip")
	end
end)

it("takes a capitalised value exactly as the sender wrote it", function()
	-- /comfy lowercases what it is given, because every other command wants
	-- that. channel=Ambience is not every other command, so import is handed
	-- the untouched argument - and the enum is recovered by name as well, so
	-- the setting survives either way.
	local w = H.world()
	w:slash("channel sfx")
	w:slash("import ComfyRain1:channel=Ambience")
	eq(w:db().channel, "Ambience", "the capital survived")
end)

it("reads a profile that something else lowercased on the way", function()
	-- Discord, forums and chat all mangle case, and refusing a correct paste
	-- over a capital letter is a bug the player cannot diagnose.
	local w = H.world()
	w:slash("channel sfx")
	w:slash("import comfyrain1:channel=ambience;weather=snow")
	eq(w:db().channel, "Ambience", "the canonical spelling is recovered")
	eq(w:db().weather, "snow", "and the rest of it still applied")
end)

it("refuses a string that is not ours, and says what it was", function()
	local w = H.world()
	w:slash("snow")
	w.mock.printed = {}
	w:slash("import WeakAuras:abc123")

	eq(w:db().weather, "snow", "nothing was touched")
	gt(#w.mock.printedMatching("WeakAuras"), 0,
		"and it named the tag it found, so a truncated paste is fixable")
end)

it("cannot be made to set anything a profile does not own", function()
	-- The safety property. Import is restricted to the section keys, coerced to
	-- the type DEFAULTS declares, and then sanitised, so the worst a hostile
	-- string can do is set rain to heavy.
	local w = H.world()
	local before = w:db().migrated
	w:slash("import ComfyRain1:minimapAngle=0;migrated=0;scale=99;weather=goats")

	eq(w:db().minimapAngle, 196, "furniture is not a setting a stranger can move")
	eq(w:db().migrated, before, "and neither is bookkeeping")
	near(w:db().scale, 1.5, 1e-9, "an out-of-range number is clamped, not taken")
	eq(w:db().weather, "rain", "and an invented enum falls back to the default")
end)

it("prints the string to chat when the window did not load", function()
	-- A client that failed to build the panel still has to be able to share.
	local w = H.world()
	w.env.ComfyRainAPI.share = nil
	w.mock.printed = {}
	w:slash("share")
	gt(#w.mock.printedMatching("ComfyRain1:"), 0, "the string went to chat instead")
end)

--------------------------------------------------------------------------------
-- Per-slider reset
--------------------------------------------------------------------------------

-- The row's value is a button, so these reach it through the row rather than by
-- hunting for a frame whose text happens to be "1.00" - four sliders sit on
-- their default at once and that search would find whichever came first.
local function valueOf(w, label)
	w:open()
	local row = w:slider(label):GetParent()
	return row.value, row.valueText
end

it("the number beside a slider puts just that slider back", function()
	-- Reset Look already exists and takes the whole section with it. The case
	-- this is for is "the darkness is wrong and everything else is how I want
	-- it", which the section button cannot do without collateral.
	local w = H.world()
	w:slash("dim 1.80")
	w:slash("alpha 0.40")
	w:slash("gust 0.20")

	local btn = valueOf(w, "Darkness")
	btn:Click()

	near(w:db().gloom, 1.0, 1e-9, "darkness went back to its default")
	near(w:db().scale, 0.40, 1e-9, "visibility was not touched")
	near(w:db().gust, 0.20, 1e-9, "and neither was wind")
end)

it("looks up the default by db key, not by the slider's name", function()
	-- Visibility writes `scale` through the `alpha` command and Darkness writes
	-- `gloom` through `dim`. Two of the seven sliders have a label, a key and a
	-- verb that are all different words, so a reset that guessed any of them
	-- from the others would silently reset the wrong thing or nothing.
	local w = H.world()
	w:slash("alpha 0.10")
	valueOf(w, "Visibility"):Click()
	near(w:db().scale, 1.0, 1e-9, "Visibility reset the scale key")

	w:slash("dim 0.10")
	valueOf(w, "Darkness"):Click()
	near(w:db().gloom, 1.0, 1e-9, "Darkness reset the gloom key")
end)

it("brightens the number that has moved and greys the ones that have not", function()
	-- The second job the clickable value does: answering "what have I actually
	-- changed in here" without pressing anything or reading a single tooltip.
	-- The step is brightness, not hue. It was gold until 2026-10-19, and five
	-- gold numbers down one side of the window was most of what "the weird
	-- tellow is offputting" was pointing at.
	local w = H.world()
	local _, text = valueOf(w, "Wind")
	eq(text.colour[1] < 0.8, true, "grey while it sits on the default")

	w:slash("gust 0.25")
	local _, moved = valueOf(w, "Wind")
	near(moved.colour[1], 1.00, 1e-9, "white once it has moved")
	near(moved.colour[2], 1.00, 1e-9, "white, not a colour of ours")
	near(moved.colour[3], 1.00, 1e-9, "on all three channels")

	valueOf(w, "Wind"):Click()
	local _, back = valueOf(w, "Wind")
	eq(back.colour[1] < 0.8, true, "and grey again after the reset")
end)

it("every slider starts grey on a fresh profile", function()
	local w = H.world()
	for _, label in ipairs({ "Visibility", "Fall Speed", "Darkness",
	                         "Wind", "Volume" }) do
		local _, text = valueOf(w, label)
		eq(text.colour[1] < 0.8, true, label .. " is grey on a fresh profile")
	end
end)

it("resets the hour to whichever default that mode actually uses", function()
	-- One control, two settings: a shift from realm time (default 0) and an
	-- hour to hold at (default 21). A fixed number here would reset one of the
	-- two modes to the other's default.
	local w = H.world()
	w:slash("time fixed")
	w:slash("time 4")
	valueOf(w, "Hold at Hour"):Click()
	eq(w:db().timeFixed, 21, "fixed mode went back to 21")

	w:slash("time offset")
	w:slash("time +5")
	valueOf(w, "Shift by Hours"):Click()
	eq(w:db().timeOffset, 0, "and offset mode back to 0, not to 21")
end)

it("routes a per-slider reset through the command parser like everything else", function()
	-- The window must never be able to do something the command line cannot.
	local w = H.world()
	w:slash("volume 0.30")
	w.mock.printed = {}
	local ran
	local real = w.env.ComfyRainAPI.Command
	w.env.ComfyRainAPI.Command = function(c) ran = c; return real(c) end
	valueOf(w, "Volume"):Click()
	ok(ran and ran:match("^volume"), "it issued a volume command: " .. tostring(ran))
	near(w:db().volume, 1.0, 1e-9, "and the command did the work")
end)

--------------------------------------------------------------------------------
-- About
--------------------------------------------------------------------------------

it("about names the project, the licence and the page, and no person", function()
	local w = H.world()
	w.mock.printed = {}
	w:slash("about")
	gt(#w.mock.printedMatching("Comfy Rain"), 0, "says what it is")
	gt(#w.mock.printedMatching("LibruaryNFT"), 0, "and who, by handle")
	gt(#w.mock.printedMatching("MIT"), 0, "and the licence")
	gt(#w.mock.printedMatching("github%.com/LibruaryNFT/comfyrain"), 0, "and where")
end)

it("puts the link in a box, because chat cannot be copied out of", function()
	local w = H.world()
	local got
	w.env.ComfyRainAPI.share = function(text, note) got = { text, note } end
	w:slash("about")
	ok(got, "the copy box was opened")
	contains(got[1], "github.com/LibruaryNFT/comfyrain", "with the URL in it")
	-- The share box's own caption is about pasting a profile back to another
	-- ComfyRain user, which is nonsense for a GitHub link.
	ok(got[2] and not got[2]:match("paste it back"),
		"and a caption that fits a URL: " .. tostring(got[2]))
end)

it("about still works when the window never loaded", function()
	local w = H.world()
	w.env.ComfyRainAPI.share = nil
	w.mock.printed = {}
	w:slash("about")
	gt(#w.mock.printedMatching("github%.com"), 0, "the link went to chat instead")
end)

it("the About button in the window runs the command", function()
	local w = H.world()
	w.mock.slash("COMFYRAINUI", "")
	local b = w:button("About")
	ok(b, "the window has an About button")
	w.mock.printed = {}
	b:Click()
	gt(#w.mock.printedMatching("github%.com"), 0, "and it printed the about block")
end)

it("the homepage in the Lua and the one in the TOC are the same URL", function()
	-- HOMEPAGE is a constant in ComfyRain.lua because X-Website is not
	-- guaranteed readable as metadata everywhere, which means there are two
	-- copies of the project URL in the package and they can drift. They drift
	-- silently: /comfy about would keep printing a working link to the old
	-- repository name long after the real one moved. The rename to comfyrain
	-- is still pending, so this will be the thing that catches it.
	local function read(path)
		local fh = io.open(path, "r")
		ok(fh ~= nil, "could read " .. path)
		local body = fh:read("*a")
		fh:close()
		return body
	end
	local dir = (debug.getinfo(1, "S").source:match("@(.*/)") or "./")
	local lua = read(dir .. "../ComfyRain/ComfyRain.lua")
	local toc = read(dir .. "../ComfyRain/ComfyRain.toc")

	local inLua = lua:match('HOMEPAGE%s*=%s*"([^"]+)"')
	local inToc = toc:match("##%s*X%-Website:%s*(%S+)")
	ok(inLua, "ComfyRain.lua declares a HOMEPAGE")
	ok(inToc, "the TOC declares an X-Website")
	eq(inLua, inToc, "and they are the same URL")

	-- The name is the handle, not the person. Asserted rather than trusted,
	-- because a TOC is exactly the file somebody fixes up by hand before a
	-- release and puts a real name back into.
	local author = toc:match("##%s*Author:%s*(.-)%s*\n")
	eq(author, "LibruaryNFT", "the shipped author is the GitHub handle")
end)

--------------------------------------------------------------------------------
-- Blizzard's own furniture
--------------------------------------------------------------------------------
--
-- Asked 2026-10-19: can the window look more like the game's own, or is that
-- not allowed? It is allowed. The seven provisions of the UI Add-On
-- Development Policy are about money, obfuscation, realm load, advertising,
-- donations, content and the EULA, and not one of them touches using the
-- interface the client ships - the templates exist to be inherited. What is not
-- allowed is putting Blizzard's art INSIDE the package, which is why every
-- piece below is a template name or a texture path: the file is read out of the
-- player's own installation at draw time and this repo contains none of it.
--
-- These specs are about the other half of that. Templates and art live in the
-- game's data archive rather than in WowB.exe, so there is no offline way to
-- know which flavour has what - tools/api_surface.py is blind to both - and
-- borrowed furniture must therefore never be the reason a window comes up
-- blank.

it("dresses its buttons in the client's own panel-button art", function()
	local w = H.world()
	w:open()
	local b = w:button("Turn It All Off")
	ok(b, "the button is there")
	eq(b._template, "UIPanelButtonTemplate", "wearing Blizzard's own button")
	ok(b:GetFontString(), "and the template's font string, not one we drew")
end)

it("still draws a usable button on a client without that template", function()
	local w = H.world({ uiTemplates = { "BackdropTemplate", "UIPanelCloseButton" } })
	w:open()
	local b = w:button("Turn It All Off")
	ok(b, "the button still exists")
	eq(b._template, nil, "built bare instead")
	ok(b:GetFontString(), "with a label of our own")
	local painted = false
	for _, t in ipairs(b._textures) do if t.colour then painted = true end end
	ok(painted, "and a face, so it is not an invisible hit box")
	eq(#w.mock.errors, 0, "and the absent template threw nothing at the client")
end)

it("shows one value at a time, with an arrow either side of it", function()
	-- What the pills could not do. Four buttons in a row have to say which one
	-- is live using nothing but a difference in how the same button is drawn,
	-- and both attempts were reported unreadable from live play: the pressed
	-- bevel ("i cant tell if its on or off") and then a gold wash ("the weird
	-- tellow is offputting"). There is nothing here to misread.
	local w = H.world()
	w:open()
	local s = w:select("Intensity")
	ok(s, "the intensity row is a selector")
	ok(s.left and s.right, "with an arrow on each side")
	eq(s.value.text, "Normal", "and the live value on its face, spelled out")

	-- The well is a third place to press, because somebody who has worked out
	-- that the row cycles will click the middle of it first.
	s.well:Click()
	eq(w:db().intensity, "heavy", "pressing the value steps it forward")
end)

it("puts the weather's picture in the well beside its name", function()
	-- The one icon left in the window. Rain and snow are the only pair a
	-- player picks between by shape rather than by reading, and the whole
	-- reason FrostShock won over the better-looking ChillingBlast: two icons
	-- that reduce to the same thing at 14px are worse than none.
	local w = H.world()
	w:open()
	local s = w:select("Weather")
	ok(s.icon:IsShown(), "rain has a picture")
	local rain = s.icon.texture
	choose(w, "Weather", "Snow")
	ok(s.icon.texture ~= rain, "and snow does not wear the same one")
end)

it("draws arrows a client has the art for, and letters when it has not", function()
	local w = H.world()
	w:open()
	ok(w:select("Intensity").right.art, "the game's own arrow")

	local bare = H.world({ artPaths = {} })
	bare:open()
	local r = bare:select("Intensity").right
	eq(r.art, nil, "no art on a client without the file")
	eq(r._text, ">", "but something to press anyway")
	r:Click()
	eq(bare:db().intensity, "heavy", "and it still steps")
	eq(#bare.mock.errors, 0, "with nothing thrown at the client")
end)

it("lays the real dialog stone over its own fill, never instead of it", function()
	local w = H.world()
	local p = w:open()
	local stone, flat
	for _, t in ipairs(p._textures) do
		if t.texture and t.texture:find("UI%-DialogBox%-Background") then stone = t end
		if not flat and t.layer == "BACKGROUND" and t.colour then flat = t end
	end
	ok(stone, "the client's own dark dialog background is there")
	eq(stone.wrapH, "REPEAT", "tiled, the way the client tiles it")
	ok(flat, "and our own fill is still underneath")
	-- The order is the whole point. A path this build does not have draws
	-- nothing at all, and a window whose background was ONLY that path would
	-- come up transparent with the controls floating over the world.
	ok(stone.sublevel and stone.sublevel > (flat.sublevel or 0),
		"with the stone on top, so a missing file leaves a plain panel")
end)

it("uses the client's slider knob, and draws one when the art is absent", function()
	local w = H.world()
	w:open()
	local thumb = w:slider("Visibility")._thumb
	ok(thumb and thumb.texture and thumb.texture:find("UI%-SliderBar%-Button"),
		"the metal knob from the game's own options")

	-- The one piece with no silent fallback. Everywhere else the Blizzard
	-- texture sits over something we drew, so a path that does not resolve
	-- degrades on its own; a thumb is the part you grab, and an invisible one
	-- is a slider nobody can find. So this one is asked about.
	local bare = H.world({ artPaths = {} })
	bare:open()
	local drawn = bare:slider("Visibility")._thumb
	ok(drawn and drawn.colour, "a drawn knob when the client has not got the file")
	eq(#bare.mock.errors, 0, "and no error for art it did not have")
end)

it("comes up on a client with none of it: no templates, no art", function()
	local w = H.world({ uiTemplates = {}, artPaths = {} })
	local p = w:open()
	ok(p and p:IsShown(), "the window still opens")
	eq(p.GetBackdrop, nil, "with no backdrop, no close button and no stone")
	ok(w:button("Turn It All Off"), "the buttons are still buttons")
	ok(w:slider("Visibility"), "and the sliders are still sliders")
	choose(w, "Weather", "Snow")
	eq(w:db().weather, "snow", "and clicking one still runs its command")
	eq(#w.mock.errors, 0, "and nothing was thrown at the client")
end)

--------------------------------------------------------------------------------
-- The weather icons
--------------------------------------------------------------------------------
--
-- Same rule as the furniture above: the path is referenced, the file is not
-- shipped. What is worth specifying here is the part that is easy to break by
-- "improving" it later. There is no rain icon in this game - the whole 2.27M
-- file catalogue was searched, not just the classic range - so Rain borrows
-- IceStorm, whose shards lose their detail at 14px and leave slanted streaks.
-- Snow is FrostShock rather than the prettier ChillingBlast because
-- ChillingBlast reduces to a white diagonal slash at that size, which is the
-- same shape as the rain icon beside it. Telling rain from snow is the one job
-- this row has.

it("gives the Weather selector a picture, and only that one", function()
	-- Thunder and Gusts carried icons too until 2026-10-19. The client's own
	-- Options window has no pictures on anything, matching it was the ask, and
	-- a bolt beside a tick was two widgets saying one thing.
	local w = H.world()
	w:open()
	ok(w:select("Weather").icon:IsShown(), "the weather has one")
	eq(w:button("Thunder").icon, nil, "and nothing else in the window does")
end)

it("draws no picture and no hole on a client without the icon files", function()
	-- A path this flavour lacks draws nothing, so a well laid out for a
	-- picture would show an off-centre word with a gap beside it.
	local w = H.world({ artPaths = {} })
	w:open()
	local s = w:select("Weather")
	eq(s.icon:IsShown(), false, "no picture was drawn")
	eq(s.value._lastPoint.point, "CENTER", "and the word is centred in the well")
	eq(w:button("Thunder").lamp:IsShown(), true, "the checkbox falls back to a lamp")
	eq(w:button("Thunder").label._lastPoint.x, 0, "with the label still at the row's left edge")
	choose(w, "Weather", "Snow")
	eq(w:db().weather, "snow", "and the controls still work")
	eq(#w.mock.errors, 0, "with nothing thrown at the client")
end)

it("ticks the box, and clears it, on a checkbox with no picture to hide behind",
function()
	local w = H.world()
	w:open()
	local t = w:button("Thunder")
	eq(t.tick:IsShown(), true, "on by default, so the box is ticked")
	near(t.label.colour[1], 1, 1e-9, "and the word is white")

	w:slash("thunder off")
	eq(t.tick:IsShown(), false, "turned off, the tick clears")
	near(t.label.colour[1], 0.62, 1e-9, "and the word goes grey")
end)

-- Seen on screen 2026-10-19: "Everything off. Nothing here is to...". The
-- status line had one fixed width, sized to leave room for the Turn It All
-- Off button - and that button is hidden in exactly the state that produces
-- the longest sentence the window ever shows, so the row was free and the
-- sentence was cut anyway.
it("gives the status line the whole row once there is nothing left to stop", function()
	local w = H.world()
	w:open()
	local narrow = w:says("^Drawing"):GetWidth()
	eq(w:button("Turn It All Off"):IsShown(), true, "the button is there to make room for")

	w:slash("stop")
	local line = w:says("^Everything off")
	ok(line, "the window says everything is off")
	eq(w:button("Turn It All Off"):IsShown(), false, "and the button has gone")
	gt(line:GetWidth(), narrow, "so the sentence gets the room the button was holding")
end)

it("stands the checkbox on the panel, not on a button face", function()
	-- "the button doesnt look right for zoom response" was this: a checkbox
	-- drawn inside a UIPanelButton face, which is a promise that the face does
	-- something separate from the box. The client's own options rows are a
	-- word and a box on the background.
	local w = H.world()
	w:open()
	local z = w:button("Zoom Response")
	eq(z._template, nil, "no panel-button template under it")
	eq(z.label._lastPoint.x, 0, "the words start at the left edge of the row")
	eq(z.box._lastPoint.relPoint, "RIGHT",
		"and the box is placed off the right edge, so it holds its column "
		.. "whatever width the row is given")
end)

-- Every control in the client's Options window starts at the same x, and that
-- column is most of why a page of unrelated settings reads as one list. Ours
-- had the checkboxes against the left edge and the selectors against the
-- right: "it doesnt appear exactl like the wow options".
it("lines every checkbox and every selector up in one column", function()
	local w = H.world()
	w:open()
	w:slash("time +9")            -- every row on screen, hidden ones included

	-- Every one of these is anchored off its row's RIGHT edge, so the column
	-- is one number per control: how far in from that edge it begins.
	local seen = {}
	for _, name in ipairs({ "Weather on", "Zoom Response", "Sound", "Thunder" }) do
		local b = w:button(name)
		ok(b, name .. " is a checkbox in the window")
		seen[b.box._lastPoint.x] = true
	end
	for _, name in ipairs({ "Weather", "Intensity", "Indoors", "Channel", "Mode" }) do
		local s = w:select(name)
		ok(s, name .. " is a selector in the window")
		-- The well hangs off the right edge and the arrow hangs off the well,
		-- so the start of the group is the two of them plus the gap between.
		seen[s.well._lastPoint.x - s.well:GetWidth() - 2 - s.left:GetWidth()] = true
	end
	local n = 0
	for _ in pairs(seen) do n = n + 1 end
	eq(n, 1, "all nine controls start at the same x, not " .. n .. " columns")
end)

--------------------------------------------------------------------------------
-- Hover tooltips
--------------------------------------------------------------------------------
--
-- Asked 2026-10-19: can we get a WoW-item-style tooltip on hover? That is what
-- these already are. GameTooltip is the same frame the game draws item
-- tooltips into, so the border, the fonts and the anchoring come free and
-- match whatever the player's client looks like. Nothing here is drawn by us.
--
-- The contract is coverage, not existence. A tooltip is where the slash
-- command lives, so a control without one is a control whose command is
-- unreachable from the window - and that is exactly the failure a hand-written
-- list of Teach calls produces, silently, one control at a time.

it("teaches every button and slider in the window, with no gaps", function()
	local w = H.world()
	w:open()
	w:slash("time +9")           -- bring the two time rows on screen as well
	local checked = 0
	for _, f in ipairs(w:hoverables()) do
		local rows = w:hover(f)
		local what = tostring(f._text or (f._parent and "slider") or "?")
		ok(rows and rows[1] and rows[1].text ~= "" and rows[1].text ~= nil,
			"something under the cursor says what it is: " .. what)
		checked = checked + 1
	end
	H.gt(checked, 15, "and the sweep actually walked the window")
end)

it("says which of its two jobs the Hour row is doing", function()
	-- One slider stands in for two settings, so a tooltip fixed at build time
	-- is wrong half the time. It was the last control in the window with none.
	local w = H.world()
	w:open()
	w:slash("time +9")
	local _, shifted = w:hover(w:slider("Shift by Hours"))
	contains(shifted, "Shift by Hours", "shifted mode names itself")
	contains(shifted, "realm", "and says what it shifts from")

	w:slash("time 21")
	local _, held = w:hover(w:slider("Hold at Hour"))
	contains(held, "Hold at Hour", "holding mode names itself")
	contains(held, "/comfy time 21", "and offers the command that does it")
end)

it("wraps its explanations instead of growing wider than the window", function()
	-- GameTooltip sizes itself to its longest line. A two-sentence note that
	-- does not wrap is a tooltip several hundred pixels wider than the panel
	-- it is explaining, which is invisible to any spec that reads only text.
	local w = H.world()
	w:open()
	local rows = w:hover(w:select("Indoors").well)
	local long
	for _, r in ipairs(rows) do
		if r.text and #r.text > 60 then long = r end
	end
	ok(long, "the long explanation is there")
	eq(long.wrap, true, "and it is set to wrap")
end)

--------------------------------------------------------------------------------
-- Channel, and why it is still on the panel
--------------------------------------------------------------------------------
--
-- Asked 2026-10-19: do we really need the Channel button? Yes, for one reason,
-- and it is the likeliest complaint this addon will get. The addon can play
-- into any of the game's five volume sliders but it cannot make a sound on one
-- the player has already pulled to zero, and Ambience at zero is a common
-- setting - the beta's own config shipped with Master at 0.1 and Music at 0.
-- Without this, Sound says On, Volume is up, and nothing can be heard, with
-- nothing on screen to explain it. Clicking the button is also the fix.

it("says on its face when the game's own volume slider is at zero", function()
	local w = H.world({ cvars = { Sound_AmbienceVolume = 0 } })
	w:open()
	eq(w:select("Channel").value.text, "Ambience (muted)", "the row admits it")

	local rows = w:hover(w:select("Channel").well)
	local warned
	for _, r in ipairs(rows) do
		if r.r == 1 and r.g and r.g < 0.5 then warned = r end
	end
	ok(warned, "and the tooltip says it in red, not in the same grey as the rest")
	contains(warned.text, "zero", "naming what is wrong")
end)

it("stops warning once the weather is moved to a channel that works", function()
	local w = H.world({ cvars = { Sound_AmbienceVolume = 0 } })
	w:open()
	ok(w:says("%(muted%)"), "muted to start with")
	w:slash("channel master")
	eq(w:says("%(muted%)"), nil, "and the warning goes with the move")
	eq(reads(w, "Channel"), "Master", "leaving the row reading plainly")
end)

it("catches the master switch and the master slider, not just its own", function()
	for _, case in ipairs({
		{ Sound_EnableAllSound = 0 },
		{ Sound_MasterVolume = 0 },
		{ Sound_EnableAmbience = 0 },
	}) do
		local w = H.world({ cvars = case })
		w:open()
		local which = next(case)
		ok(w:says("%(muted%)"), which .. " at zero is still silence")
	end
end)

it("says nothing at all when it cannot read the sound settings", function()
	-- A CVar name that moves in some later flavour must not put a red warning
	-- on a panel whose sound is working. Cannot-tell is not muted.
	local w = H.world({ cvars = false })
	w:open()
	eq(w:says("%(muted%)"), nil, "no warning it has not earned")
	eq(#w.mock.errors, 0, "and nothing thrown reading CVars that answer nil")
end)

it("keeps quiet about the channel while the sound is switched off", function()
	-- Sound off is the player's own doing and the panel already says so. A
	-- second complaint about a muted channel is noise.
	local w = H.world({ cvars = { Sound_AmbienceVolume = 0 } })
	w:open()
	w:slash("sound off")
	eq(w:says("%(muted%)"), nil, "one explanation, not two")
end)

--------------------------------------------------------------------------------
-- Sharing a profile: the caption, and the way back
--------------------------------------------------------------------------------
--
-- Asked 2026-10-19: the caption on the share box is cut off, we never tell
-- anybody how to paste one, and should pasting be allowed to overwrite their
-- own settings?
--
-- The caption was not cut off, it was wrapping onto a second line that was
-- drawn underneath the text well, in a frame fixed at 104 tall. The frame now
-- grows to its caption, which is what lets the caption be long enough to say
-- anything useful.
--
-- On overwriting: a preview dialog listing twenty values in a 330px window is
-- the wrong shape, and "merge without changing anything" is a contradiction -
-- the profile IS the settings. What actually stops somebody trying a friend's
-- profile is expecting to lose their own, so the answer is one step back.
-- /comfy undo, armed by the import itself, surviving a reload.

local function shareNote(w)
	local box = w:shareBox()
	return box and box.note and box.note.text or ""
end

it("grows the share box to fit a caption that needs two lines", function()
	local w = H.world()
	w:open()
	w:button("Share"):Click()
	local box = w:shareBox()
	local noteH = box.note:GetStringHeight()
	H.gt(noteH, 16, "the caption really does need more than one line")
	-- 88 is the box minus the single line it used to allow for. Anything less
	-- and the wrapped remainder is drawn over the text well.
	H.gt(box:GetHeight(), 88 + noteH - 1, "and the frame made room for all of it")
end)

it("keeps the box its old size for a caption that fits", function()
	-- The growth is for the caption that needs it, not a taller box for
	-- everyone. /comfy about borrows this frame for a one-line URL note.
	local w = H.world()
	w:slash("about")
	eq(w:shareBox():GetHeight(), 104, "one line, one box")
end)

it("tells you how to use a profile somebody sent you", function()
	-- The whole round trip was a slash command nobody had been told about.
	local w = H.world()
	w:open()
	w:button("Share"):Click()
	contains(shareNote(w), "Paste One", "the caption names the way in")
	ok(w:button("Paste One"), "and the button is actually there")
end)

it("empties the box when you say you want to paste one", function()
	local w = H.world()
	w:open()
	w:button("Share"):Click()
	contains(w:editBox():GetText(), "ComfyRain1:", "your own, to start with")

	w:button("Paste One"):Click()
	eq(w:editBox():GetText(), "", "the box is cleared for theirs")
	ok(w:editBox():HasFocus(), "with the cursor in it")
	contains(shareNote(w), "undo", "and it says how to change your mind")
end)

it("does not offer to import the project URL", function()
	-- /comfy about reuses this box. Offering to paste a GitHub link back in as
	-- a weather profile would be nonsense.
	local w = H.world()
	w:slash("about")
	eq(w:button("Paste One"):IsShown(), false, "no import button on a URL")
end)

it("puts your own settings back after an import you did not want", function()
	local w = H.world()
	w:slash("snow")
	w:slash("alpha 0.4")
	local mine = w.env.ComfyRainAPI.Export()

	w:slash("rain")
	w:slash("alpha 0.9")
	local theirs = w.env.ComfyRainAPI.Export()

	w:slash("import " .. mine)
	eq(w:db().weather, "snow", "their profile landed")
	near(w:db().scale, 0.4, 1e-9, "all of it")

	w:slash("undo")
	eq(w:db().weather, "rain", "and undo put mine back")
	near(w:db().scale, 0.9, 1e-9, "every value, not just the obvious one")
	eq(w.env.ComfyRainAPI.Export(), theirs, "exactly as it was")
end)

it("says so plainly when there is nothing to undo", function()
	local w = H.world()
	w:slash("undo")
	contains(table.concat(w.mock.printed, " | "), "nothing to undo",
		"rather than silently doing something")
end)

it("is one step back, not a history", function()
	-- A second undo must not restore from two imports ago. An undo that is
	-- quietly a stack is an undo nobody can predict.
	local w = H.world()
	w:slash("alpha 0.3")
	w:slash("import ComfyRain1:scale=0.8")
	w:slash("undo")
	near(w:db().scale, 0.3, 1e-9, "back where I was")

	w:slash("undo")
	near(w:db().scale, 0.3, 1e-9, "and a second undo moves nothing")
	-- It also has to SAY there is nothing left, or a player cannot tell an
	-- undo that is spent from one that is still armed.
	contains(w.mock.printed[#w.mock.printed], "nothing to undo",
		"and says the way back has been used")
end)

it("arms nothing when the paste was not a profile at all", function()
	local w = H.world()
	w:slash("alpha 0.3")
	w:slash("import this is not a profile")
	near(w:db().scale, 0.3, 1e-9, "the junk changed nothing")
	w:slash("undo")
	contains(table.concat(w.mock.printed, " | "), "nothing to undo",
		"and it did not arm an undo for a change that never happened")
end)

it("still remembers the way back after a reload", function()
	-- "Import it, reload to be sure, change my mind" is the obvious way to use
	-- this, so the undo lives in the saved variables rather than in memory.
	local w = H.world()
	w:slash("alpha 0.3")
	w:slash("import ComfyRain1:scale=0.8")
	local saved = w:db()

	local two = H.world({ loaded = false })
	two.env.ComfyRainDB = saved
	two:load()
	two:slash("undo")
	near(two:db().scale, 0.3, 1e-9, "the way back survived the reload")
end)

--------------------------------------------------------------------------------
-- Colour
--------------------------------------------------------------------------------
--
-- Reported 2026-10-19, about a gold wash added that same day to make a chosen
-- pill readable: "we did reload, now what, im confused, can u pleae fix the
-- ui, the weird tellow is offputting.. why cant we make it like their options
-- menu". Gold is the client's heading colour and this window now uses it for
-- exactly what the client uses it for: headings, the title, and the one line
-- that says what is being done to the screen. Nothing a player operates is
-- gold, because a control that is gold is a control claiming to be a heading.

it("keeps gold for headings and the status line, and off every control", function()
	local w = H.world()
	w:open()
	w:slash("time +9")          -- every row on screen, including the hidden two
	w:slash("gust 0.25")        -- and a slider knocked off its default
	local gold = 0
	for _, f in ipairs(w:hoverables()) do
		for _, fs in ipairs(f._fontStrings or {}) do
			local c = fs.colour
			-- Gold is bright red, bright green, no blue. Grey and white both
			-- have their three channels equal, so neither can trip this.
			if c and c[1] > 0.9 and c[2] > 0.7 and c[2] < 0.95 and c[3] < 0.3 then
				gold = gold + 1
			end
		end
	end
	H.eq(gold, 0, "no button, slider or selector in the window is gold")

	-- The positive control. If the detector above cannot see gold where gold
	-- IS, then zero means nothing.
	local heading = w:says("^Weather$")
	ok(heading, "the Weather heading is there to look at")
	near(heading.colour[1], 1.00, 1e-9, "and it is gold")
	near(heading.colour[2], 0.82, 1e-9, "on the channel the detector tests")
	lt(heading.colour[3], 0.3, "with no blue in it")
end)

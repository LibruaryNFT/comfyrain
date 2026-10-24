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

-- The one line of words at the top of the window. It lives in the same row
-- as the Use mine button, which is how a spec finds it without a name.
local function noteOf(w)
	return w:button("Use mine"):GetParent()._fontStrings[1]
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
	choose(w, "Type", "Snow")
	eq(w:db().weather, "snow", "the weather changed")
	-- Proof it went through the real path rather than writing the setting: the
	-- sheets only swap inside the command handler's Refresh.
	ok(tostring(w:layers().far.texture):find("snow"), "and the sheets followed")

	choose(w, "Type", "Rain")
	eq(w:db().weather, "rain", "and back")
end)

it("names the top intensity after the weather it belongs to", function()
	local w = H.world()
	w:open()
	choose(w, "Intensity", "Monsoon")
	eq(w:db().intensity, "monsoon", "rain tops out at Monsoon")

	choose(w, "Type", "Snow")
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
	choose(w, "Type", "Snow")
	ok(w:button("Gusts"), "snow gusts")
	eq(w:button("Thunder"), nil, "and never claims to thunder")
end)

it("toggles sound, gusts and indoors from the window", function()
	local w = H.world()
	w:open()
	eq(w:db().sound, true, "sound starts on")
	w:button("Play sounds"):Click()
	eq(w:db().sound, false, "the button turned it off")
	w:button("Play sounds"):Click()
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

it("keeps the fine-tuning out of the window", function()
	-- "we shouldnt allow a user to change the settings of the rain, thats too
	-- granular". The scenes and the intensity set all five of these, and the
	-- fall speeds are derived from drop physics, so a slider for each was five
	-- ways to un-derive them in a window meant to be unintimidating.
	local w = H.world()
	w:open()
	ok(w:slider("Volume"), "the lookup finds a slider that is there")
	ok(w:button("Hide when game rains"), "and a checkbox that is there")
	for _, label in ipairs({ "Drops", "Fall Speed", "Darkness", "Wind" }) do
		eq(w:slider(label), nil, label .. " is not in the window")
	end
	eq(w:button("Follow camera zoom"), nil, "nor is the camera-zoom switch")

	-- Still settings underneath: the scenes write them and the commands reach them.
	w:slash("zoom off")
	eq(w:db().zoom, false, "the command still turns camera zoom off")
	w:slash("speed 1.4")
	near(w:db().speed, 1.4, 1e-9, "and still sets the fall speed")
end)

it("gives every row label room to be read whole", function()
	-- A row label is told not to wrap and gets what is left beside the control
	-- column, so one that is too long is cut to "Step aside for real we...",
	-- which shipped. The mock's 5.2 px a character said it fitted. Measured
	-- off an in-game screenshot on 2026-10-23, the client's font runs 5.8 to
	-- 7.4 px a character ("Show rain & snow" 112 px, "Thunder" 50), so this
	-- asks at 7.0: a proxy for the real font, not the font.
	local PX = 7.0
	ok(#"Step aside for real weather" * PX > 148,
		"the rate flags the label that was cut off in the game")

	local w = H.world()
	w:open()
	w:slash("time +9")            -- every row on screen, hidden ones included
	local seen = 0
	for _, f in ipairs(w.mock.frames) do
		local l = f.label
		if type(l) == "table" and l.wordWrap == false and l.text then
			f:GetScript("OnSizeChanged")(f, f:GetWidth())
			seen = seen + 1
			ok(#l.text * PX <= l:GetWidth(), string.format(
				"%q needs about %d px and has %d", l.text, #l.text * PX, l:GetWidth()))
		end
	end
	gt(seen, 10, "and it found the rows to measure")
end)

it("cycles the volume channel rather than opening a menu", function()
	-- UIDropDownMenu is a template, and templates are the part of the client
	-- this addon deliberately does not depend on.
	local w = H.world()
	w:open()
	eq(w:db().channel, "Ambience", "starts on Ambience")
	w:select("Volume follows").right:Click()
	eq(w:db().channel, "SFX", "steps to the next")
	eq(reads(w, "Volume follows"), "SFX", "and says so")
	w:select("Volume follows").left:Click()
	eq(w:db().channel, "Ambience", "and back")
end)

it("applies a slider as it moves, and clamps where the parser clamps", function()
	local w = H.world()
	w:open()
	local s = w:slider("Volume")
	ok(s, "the volume slider exists")

	s:Drag(0.5)
	near(w:db().volume, 0.5, 1e-9, "dragging applied it")

	-- The slider's own ends and the command parser's have to be the same
	-- numbers, or the window offers a value the addon will refuse.
	s:Drag(99)
	near(w:db().volume, 1.0, 1e-9, "clamped at the same 1.0 the parser uses")
	s:Drag(-5)
	near(w:db().volume, 0, 1e-9, "and floored at the same 0")
end)

it("follows a typed command while it is open", function()
	local w = H.world()
	w:open()
	w:slash("snow")
	w:slash("blizzard")
	eq(reads(w, "Type"), "Snow", "the window moved with the command")
	eq(reads(w, "Intensity"), "Blizzard", "both selectors did")
	w:slash("volume 0.30")
	near(w:slider("Volume"):GetValue(), 0.30, 1e-9, "sliders too")
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
	w:select("Type").right:Click()
	eq(#w.mock.printed - before, 0, "clicking does not narrate itself into chat")

	before = #w.mock.printed
	w:slash("rain")
	gt(#w.mock.printed - before, 0, "a typed command still reports, as it always did")
end)

it("teaches the command for whatever is under the cursor", function()
	local w = H.world()
	w:open()
	local b = w:select("Type").well
	b:GetScript("OnEnter")(b)
	local joined = table.concat(w.env.GameTooltip.lines, " | ")
	contains(joined, "/comfy rain", "the tooltip names the command")
	b:GetScript("OnLeave")(b)
	eq(w.env.GameTooltip:IsShown(), false, "and clears on the way out")
end)

it("greys the time-of-day controls until time of day is on, and never hides them",
function()
	-- Hidden, they made Off then Dusk grow the window by two rows and Dusk
	-- then Off shrink it, every press. "we choose a setting and it shifts
	-- the ui a lot", 2026-10-23.
	local w = H.world()
	w:open()
	local strength = w:slider("Strength"):GetParent()
	eq(strength:IsShown(), true, "on screen while off")
	eq(strength.active, false, "but greyed")
	eq(w:slider("Hour"):GetParent().active, false, "and so is the hour")
	eq(w:slider("Hour"):GetParent().value._text, "-", "which has no number to show")

	choose(w, "Mode", "Fixed hour")
	eq(w:db().timeMode, "fixed", "the mode changed")
	eq(strength.active, true, "and the controls came alive")
	eq(w:slider("Hold at Hour"):GetParent().active, true, "including the hour")

	choose(w, "Mode", "My PC clock")
	eq(strength.active, true, "your own clock still has a strength")
	eq(w:slider("Hour"):GetParent().active, false, "and no hour to set")
	choose(w, "Mode", "Fixed hour")

	w:slider("Hold at Hour"):Drag(3)
	eq(w:db().timeFixed, 3, "which sets the hour it holds")

	choose(w, "Mode", "Shift by hours")
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
	choose(w, "Type", "Snow")
	w:slider("Volume"):Drag(0.3)

	w:button("Reset All"):Click()
	eq(w:db().weather, "rain", "weather back to default")
	near(w:db().volume, 1.0, 1e-9, "volume back to default")
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

it("holds still whatever is pressed: no row appears, vanishes or moves", function()
	-- "we choose a setting and it shifts the ui a lot, like puts text
	-- somewhere then moves stuff, like if we choose normal light then dusk",
	-- 2026-10-23. Anchored at its centre, a window that changes height also
	-- moves its top, so the button just clicked slides out from under the
	-- mouse. Every press, mode and screen state below must leave both the
	-- window's height and the Volume row's place exactly where they were.
	local w = H.world({ state = { gameHour = 22, gameMinute = 0 } })
	local p = w:open()
	local volume = w:slider("Volume"):GetParent()
	local h0, y0 = p:GetHeight(), volume._lastPoint.y
	gt(h0, 300, "a real window to measure")

	local function same(what)
		eq(p:GetHeight(), h0, what .. ": same height")
		eq(volume._lastPoint.y, y0, what .. ": Volume in the same place")
	end
	for _, t in ipairs({ "Snow", "Off", "Rain" }) do
		choose(w, "Type", t)
		w:advance(0.5)
		same("Type " .. t)
	end
	for _, i in ipairs({ "Heavy", "Monsoon", "Light" }) do
		choose(w, "Intensity", i)
		w:advance(0.5)
		same("Intensity " .. i)
	end
	for _, mode in ipairs({ "Fixed hour", "Shift by hours", "My PC clock", "Off" }) do
		choose(w, "Mode", mode)
		same(mode)
	end
	w:slash("preset night")
	w:advance(0.5)
	ok(noteOf(w).text ~= "", "a note is up: the realm is already at 22:00")
	same("with a note showing")
	w.mock.state.indoors = true
	w:advance(3.0, 0.1)
	same("under a roof")

	-- Positive control: the measurement does see a row that changes size.
	w:button("Use mine"):GetParent():SetHeight(60)
	w:slash("snow")
	gt(p:GetHeight(), h0, "a taller row does grow the window")
	lt(volume._lastPoint.y, y0, "and does push Volume down")
end)

it("reads Weather, then Time of Day, then Sound, top to bottom", function()
	-- "we might want time of day after rain & snow, maybe rename that to
	-- weather", 2026-10-23. The two sections that change what you see sit
	-- together; sound is the other sense, so it goes last.
	local w = H.world()
	w:open()
	local function y(text)
		local fs = w:says("^" .. text .. "$")
		ok(fs, text .. " is a heading in the window")
		return fs:GetParent()._lastPoint.y
	end
	local weather, time, sound = y("Weather"), y("Time of Day"), y("Sound")
	gt(weather, time, "Time of Day sits under Weather")
	gt(time, sound, "and Sound under Time of Day")
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
		if fs.text == "Comfy Rain" then title = fs end
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

	local function art()
		for _, t in ipairs(b._textures) do
			if t.layer == "ARTWORK" then return t end
		end
	end

	ok(art().texture:find("ComfyRain"), "the picture is one we shipped")
	local rain = art().texture
	w:slash("snow")
	eq(art().texture, rain,
		"one picture for both weathers - the tooltip and the panel say which "
		.. "is running, and an icon that changes under the player is a worse "
		.. "readout than one they can learn")

	w:slash("rain")
	w:slash("off")
	eq(art().desaturated, true, "with the weather off the lamp goes out")
	ok(art().vertexColour[1] < 0.8, "and the whole thing dims")
	w:slash("on")
	eq(art().desaturated, false, "and comes back when it is turned on")
end)

-- "the current one doesnt fix in the circle properly", 2026-10-19. The hole in
-- MiniMap-TrackingBorder is not centred on the button: with the 53x53 border
-- anchored TOPLEFT on a 31x31 button it is 20px across, centred at (17, -15)
-- from the top-left corner, which is 1.5 right and 0.5 up from the button's
-- own centre. The art was painted at (-1, +1) and so hung off the ring.
it("centres the icon on the ring's hole, not on the button", function()
	local w = H.world()
	w.env.ComfyRain_Minimap()
	local b = w.env.ComfyRainMinimapButton

	local border
	for _, t in ipairs(b._textures) do
		if t.texture and t.texture:find("TrackingBorder") then border = t end
	end
	ok(border, "the button wears the client's own tracking ring")

	-- Asserted as ratios off the button's actual size rather than as the four
	-- measured pixel values, because the button is no longer 31px - "we need
	-- the minimap icon thing to be bigger circle", 2026-10-19 - and the whole
	-- point of that measurement is that it is one piece of art, so it scales
	-- as one piece. Pinning the literals would have made growing the button a
	-- spec edit, which is how the art gets left behind off-centre.
	local k = b:GetWidth() / 31
	gt(k, 1.0, "and the button is bigger than LibDBIcon's cramped default")
	near(border:GetWidth(), 53 * k, 1e-9, "the ring scales with it")

	local holeWidth = 20 * k
	for _, t in ipairs(b._textures) do
		if t.layer == "ARTWORK" or t.layer == "BACKGROUND" then
			local p = t._lastPoint
			near(p.x, 1.5 * k, 1e-9, "the art sits over the hole's centre in x")
			near(p.y, 0.5 * k, 1e-9, "and in y")
			gt(t:GetWidth(), holeWidth,
				"drawn wider than the hole, so its soft edge tucks under "
				.. "the brass instead of showing a seam against the map")
		end
	end
end)

-- "it seems the icon is square maybe and bleeds out the circle", 2026-10-23.
-- The backing was a SetColorTexture square relying on SetMask to round it, and
-- a live client masked the picture but not the colour fill: four dark corners
-- outside the ring. Wider than the hole is fine; square is not.
it("puts nothing square under the ring", function()
	local w = H.world()
	w.env.ComfyRain_Minimap()
	local b = w.env.ComfyRainMinimapButton

	local seen = 0
	for _, t in ipairs(b._textures) do
		if t.layer == "ARTWORK" or t.layer == "BACKGROUND" then
			seen = seen + 1
			eq(t.colour, nil, "no flat colour fill, which no mask is sure to round")
			ok(t.texture, "every layer is a file, round in the file itself")
		end
	end
	eq(seen, 2, "the backing and the picture were both checked")
end)

--------------------------------------------------------------------------------
-- Turning it off, resetting it, and handing it to somebody else
--------------------------------------------------------------------------------

it("shows the light it is holding with the weather off", function()
	-- From a live report: "my screen is too dark and i cant reset it easily,
	-- like i want to turn off the changes it made but i cant". The time of day
	-- grading has no weather attached to it, so a player who switched the
	-- weather off and still has a dark world has nothing to connect it to.
	-- The controls carry it now, not a sentence: Type reads Off, and Time of
	-- Day reads the mode and the hour.
	local w = H.world()
	w:slash("time 21")
	w:slash("off")
	w:open()

	eq(reads(w, "Type"), "Off", "the weather reads as off")
	eq(reads(w, "Mode"), "Fixed hour", "Time of Day names the mode")
	eq(w:slider("Hold at Hour"):GetParent().value._text, "21",
		"and the hour the light is being held at")
end)

it("says nothing is on when nothing is on, and both selectors read Off", function()
	local w = H.world()
	w:slash("off")
	w:open()
	eq(noteOf(w).text, "", "no sentence repeating what the selectors say")
	eq(reads(w, "Type"), "Off", "Type reads Off")
	eq(reads(w, "Mode"), "Off", "and so does Time of Day")

	w:slash("on")
	eq(reads(w, "Type"), "Rain", "and Type names the weather the moment it is on")
end)

it("turns off the weather AND the light from their own sections", function()
	-- There is no all-off button. Type and Mode each start with Off, and
	-- /comfy stop is still the one-line version for people who type.
	local w = H.world()
	w:slash("time 21")
	w:open()
	ok(w:db().enabled, "weather on to start with")
	eq(w:button("Turn It All Off"), nil, "and no third kind of off")

	choose(w, "Type", "Off")
	eq(w:db().enabled, false, "the weather stopped")
	eq(w:db().timeMode, "fixed", "and Off left the light alone")
	choose(w, "Mode", "Off")
	eq(w:db().timeMode, "off", "until Time of Day's Off handed it back")
	eq(w:tod():IsShown(), false, "nothing is left over the world")

	w:slash("time 21")
	w:slash("on")
	w:slash("stop")
	eq(w:db().enabled, false, "/comfy stop still does the weather")
	eq(w:db().timeMode, "off", "and the light, in one line")
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
	-- The button is named for the heading the player reads, which is not
	-- always the section key: `look` sits under a heading that says Weather.
	local SHOWN = { look = "Weather" }
	local covered = {}
	for _, name in ipairs(w.env.ComfyRainAPI.SectionOrder) do
		ok(w:button("Reset " .. (SHOWN[name] or name:gsub("^%l", string.upper))),
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
	w:button("Share / Import"):Click()

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
	w:button("Share / Import"):Click()

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
	-- this is for is "the volume is wrong and everything else is how I want
	-- it", which the section button cannot do without collateral.
	local w = H.world()
	w:slash("volume 0.30")
	w:slash("time local")
	w:slash("time strength 0.40")

	local btn = valueOf(w, "Volume")
	btn:Click()

	near(w:db().volume, 1.0, 1e-9, "volume went back to its default")
	near(w:db().timeStrength, 0.40, 1e-9, "strength was not touched")
end)

it("looks up the default by db key, not by the slider's name", function()
	-- Strength writes `timeStrength` through `time strength`: a label, a key
	-- and a verb that are three different words, so a reset that guessed any
	-- of them from the others would silently reset the wrong thing or nothing.
	local w = H.world()
	w:slash("time local")
	w:slash("time strength 0.10")
	valueOf(w, "Strength"):Click()
	near(w:db().timeStrength, 1.0, 1e-9, "Strength reset the timeStrength key")
end)

it("brightens the number that has moved and greys the ones that have not", function()
	-- The second job the clickable value does: answering "what have I actually
	-- changed in here" without pressing anything or reading a single tooltip.
	-- The step is brightness, not hue. It was gold until 2026-10-19, and five
	-- gold numbers down one side of the window was most of what "the weird
	-- tellow is offputting" was pointing at.
	local w = H.world()
	local _, text = valueOf(w, "Volume")
	eq(text.colour[1] < 0.8, true, "grey while it sits on the default")

	w:slash("volume 0.25")
	local _, moved = valueOf(w, "Volume")
	near(moved.colour[1], 1.00, 1e-9, "white once it has moved")
	near(moved.colour[2], 1.00, 1e-9, "white, not a colour of ours")
	near(moved.colour[3], 1.00, 1e-9, "on all three channels")

	valueOf(w, "Volume"):Click()
	local _, back = valueOf(w, "Volume")
	eq(back.colour[1] < 0.8, true, "and grey again after the reset")
end)

it("every slider starts grey on a fresh profile", function()
	local w = H.world()
	for _, label in ipairs({ "Volume", "Strength" }) do
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
	local b = w:button("Commands")
	ok(b, "the button is there")
	eq(b._template, "UIPanelButtonTemplate", "wearing Blizzard's own button")
	ok(b:GetFontString(), "and the template's font string, not one we drew")
end)

it("still draws a usable button on a client without that template", function()
	local w = H.world({ uiTemplates = { "BackdropTemplate", "UIPanelCloseButton" } })
	w:open()
	local b = w:button("Commands")
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
	local thumb = w:slider("Volume")._thumb
	ok(thumb and thumb.texture and thumb.texture:find("UI%-SliderBar%-Button"),
		"the metal knob from the game's own options")

	-- The one piece with no silent fallback. Everywhere else the Blizzard
	-- texture sits over something we drew, so a path that does not resolve
	-- degrades on its own; a thumb is the part you grab, and an invisible one
	-- is a slider nobody can find. So this one is asked about.
	local bare = H.world({ artPaths = {} })
	bare:open()
	local drawn = bare:slider("Volume")._thumb
	ok(drawn and drawn.colour, "a drawn knob when the client has not got the file")
	eq(#bare.mock.errors, 0, "and no error for art it did not have")
end)

it("comes up on a client with none of it: no templates, no art", function()
	local w = H.world({ uiTemplates = {}, artPaths = {} })
	local p = w:open()
	ok(p and p:IsShown(), "the window still opens")
	eq(p.GetBackdrop, nil, "with no backdrop, no close button and no stone")
	ok(w:button("Commands"), "the buttons are still buttons")
	ok(w:slider("Volume"), "and the sliders are still sliders")
	choose(w, "Type", "Snow")
	eq(w:db().weather, "snow", "and clicking one still runs its command")
	eq(#w.mock.errors, 0, "and nothing was thrown at the client")
end)

it("puts no picture anywhere, Type included", function()
	-- "maybe we dont need icons for type", 2026-10-23. The client's own
	-- Options window has none, and the word in the well already says it.
	local w = H.world()
	w:open()
	local s = w:select("Type")
	eq(s.icon, nil, "no picture beside Rain")
	eq(s.value._lastPoint.point, "CENTER", "and the word is centred in the well")
	eq(s.value.text, "Rain", "and it is the word that says which")
	eq(w:button("Thunder").icon, nil, "and nothing else in the window has one")
	choose(w, "Type", "Snow")
	eq(s.value.text, "Snow", "Snow too")
	local function spellIcon()
		for _, f in ipairs(w.mock.frames) do
			for _, tex in ipairs(f._textures or {}) do
				if type(tex.texture) == "string"
					and tex.texture:find("Interface\\Icons\\", 1, true) then
					return true
				end
			end
		end
		return false
	end
	eq(spellIcon(), false, "no spell icon drawn anywhere")
	-- Positive control: the same scan sees one when there is one.
	s.well:CreateTexture(nil, "ARTWORK"):SetTexture("Interface\\Icons\\Spell_Frost_IceStorm")
	eq(spellIcon(), true, "the scan finds a spell icon when one is drawn")
end)

it("falls back cleanly on a client without the checkbox art", function()
	local w = H.world({ artPaths = {} })
	w:open()
	eq(w:button("Thunder").lamp:IsShown(), true, "the checkbox falls back to a lamp")
	eq(w:button("Thunder").label._lastPoint.x, 0, "with the label still at the row's left edge")
	choose(w, "Type", "Snow")
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

-- "we choose overcast, why do we need drawing normal rain", 2026-10-23. The
-- window used to read the settings back in a sentence under the title. The lit
-- buttons are that readout; words are only for when the screen disagrees.
it("says nothing the selectors already say", function()
	local w = H.world()
	w:open()
	for _, step in ipairs({ { "Type", "Snow" }, { "Intensity", "Heavy" },
	                        { "Type", "Off" }, { "Mode", "Fixed hour" },
	                        { "Mode", "Off" } }) do
		choose(w, step[1], step[2])
		w:advance(0.5)
		local what = step[1] .. " " .. step[2]
		eq(noteOf(w).text, "", "nothing written after " .. what)
		eq(w:says("^Drawing"), nil, "and no Drawing sentence anywhere")
	end

	-- Positive control: the line does speak when the screen disagrees.
	choose(w, "Type", "Rain")
	w.mock.state.indoors = true
	w:advance(3.0, 0.1)
	contains(noteOf(w).text, "Under a roof", "it speaks under a roof")
end)

it("fits every note on its one line", function()
	-- The line does not wrap. Same calibrated 7.0 px a character as the row
	-- labels; the yield note shares its row with the 78 px Use mine button.
	local PX = 7.0
	local w = H.world({ state = { gameHour = 22, gameMinute = 0 } })
	w:open()
	local function fits(what)
		local fs = noteOf(w)
		ok(fs.text ~= "", what .. " is saying something")
		ok(#fs.text * PX <= fs:GetWidth(),
			what .. ": \"" .. fs.text .. "\" fits " .. fs:GetWidth() .. " px")
	end
	w:slash("preset night")
	w:advance(0.5)
	fits("the realm already at that hour")
	choose(w, "Mode", "Off")
	w.mock.state.indoors = true
	w:advance(3.0, 0.1)
	fits("heard under a roof")
	w:slash("sound off")
	fits("silent under a roof")
	w.mock.state.indoors = false
	w.mock.state.weather = { type = 1, intensity = 0.7 }
	w.mock.cvars.weatherDensity = "3"
	w:advance(3.0, 0.1)
	fits("standing aside for real rain")
	eq(w:button("Use mine"):IsShown(), true, "beside its button")
	lt(noteOf(w):GetWidth(), 328, "which really did narrow the line")
end)

-- Reported 2026-10-19: "we reload and hear rain but dont see anything". Under
-- a roof the overlay is hidden and the bed keeps playing, which is the design
-- - but the window went on saying "Drawing normal rain." because the sentence
-- was computed from the settings alone and the settings were, truthfully, on.
-- A status line that describes the settings is not a status line.
it("says what the screen is doing, not what the settings ask for", function()
	local w = H.world()
	w:open()
	eq(noteOf(w).text, "", "outdoors it is drawing, so there is nothing to say")

	w:advance(0.5)
	w.mock.state.indoors = true
	w:advance(3.0, 0.1)
	eq(w:overlay():IsShown(), false, "the roof has stopped the drawing")
	eq(w:db().enabled, true, "with the setting still on, which is the trap")
	ok(w:says("heard, not drawn"),
		"so the window says it is heard and not seen")

	-- The positive control. If the sentence had simply been hard-wired to the
	-- indoor wording, the assertion above would pass for the wrong reason.
	w:slash("sound off")
	ok(w:says("Under a roof: nothing drawn"),
		"and with the sound off too, nothing is claimed at all")

	w.mock.state.indoors = false
	w:advance(3.0, 0.1)
	eq(noteOf(w).text, "", "back outside, drawing again and nothing to say")
end)

it("stands the checkbox on the panel, not on a button face", function()
	-- "the button doesnt look right for zoom response" was this: a checkbox
	-- drawn inside a UIPanelButton face, which is a promise that the face does
	-- something separate from the box. The client's own options rows are a
	-- word and a box on the background.
	local w = H.world()
	w:open()
	local z = w:button("Hide when game rains")
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
	for _, name in ipairs({ "Hide when game rains", "Play sounds", "Thunder" }) do
		local b = w:button(name)
		ok(b, name .. " is a checkbox in the window")
		seen[b.box._lastPoint.x] = true
	end
	for _, name in ipairs({ "Type", "Intensity", "Indoors", "Volume follows", "Mode" }) do
		local s = w:select(name)
		ok(s, name .. " is a selector in the window")
		-- The well hangs off the right edge and the arrow hangs off the well,
		-- so the start of the group is the two of them plus the gap between.
		seen[s.well._lastPoint.x - s.well:GetWidth() - 2 - s.left:GetWidth()] = true
	end
	local n = 0
	for _ in pairs(seen) do n = n + 1 end
	eq(n, 1, "all eight controls start at the same x, not " .. n .. " columns")
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
	contains(shifted, "server", "and says what it shifts from")

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
	eq(w:select("Volume follows").value.text, "Ambience (muted)", "the row admits it")

	local rows = w:hover(w:select("Volume follows").well)
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
	eq(reads(w, "Volume follows"), "Master", "leaving the row reading plainly")
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
	w:button("Share / Import"):Click()
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
	w:button("Share / Import"):Click()
	contains(shareNote(w), "Paste One", "the caption names the way in")
	ok(w:button("Paste One"), "and the button is actually there")
end)

it("empties the box when you say you want to paste one", function()
	local w = H.world()
	w:open()
	w:button("Share / Import"):Click()
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

it("has one weather switch, Type: Off, and the selectors turn it back on",
function()
	-- "if we wanted no weather but wanted it day or night", 2026-10-23. The
	-- weather used to be switched by a checkbox under its own heading, by an
	-- all-off button, as a side effect of Dusk and Night, and then by an Off
	-- button in a row of scenes. Now it is the first step of Type.
	local w = H.world()
	w:open()
	eq(w:button("Show rain & snow"), nil, "the checkbox is gone")
	ok(w:button("Hide when game rains"), "while the section's other checkbox is not")

	choose(w, "Type", "Off")
	eq(w:db().enabled, false, "Off switches the weather off")
	choose(w, "Type", "Snow")
	eq(w:db().enabled, true, "and stepping Type is a way back on")
	eq(w:db().weather, "snow", "to the weather it reads")
	choose(w, "Type", "Off")
	w:select("Intensity").right:Click()
	eq(w:db().enabled, true, "so is stepping Intensity")
end)

it("assembles a bug report nobody has to be asked follow-up questions about", function()
	-- There is no HTTP in WoW's Lua at all, so an addon can never submit
	-- anything anywhere. The most a reporter can do is assemble the line and
	-- hand it over already selected; the player pastes it. The point is that
	-- the triage questions - what version, what client, what settings, where
	-- were you standing, what was it doing - are answered before they are
	-- asked.
	local w = H.world()
	w:slash("snow")
	w:slash("alpha 0.4")
	w:slash("bug")

	local box = w:editBox()
	ok(box, "a box opened")
	ok(box._highlighted, "with the line already selected, so copying is one key")
	local t = box:GetText()

	contains(t, "ComfyRain ", "the addon version")
	contains(t, "wow ", "the client build")
	contains(t, "enUS", "the locale, because a mangled string is usually this")
	-- The reporter's exact configuration, in the format the addon reads back:
	-- whoever triages it can paste this into their own client and be looking
	-- at the same settings in one step, rather than asking for them one at a
	-- time.
	contains(t, "ComfyRain1:", "the whole profile, importable as-is")
	contains(t, "weather=snow", "with the settings actually set")
	contains(t, "scale=0.4", "including slider values")
	-- All three shelter reads, never the conclusion alone. Every shelter bug
	-- so far has lived in the gap between the first two, and a report carrying
	-- only "it was indoors" cannot show which of them said so.
	contains(t, "in0 out1 shel0", "both shelter APIs and what was concluded")
	contains(t, "draw1 hear1 yield0", "and what the addon was actually doing")
	contains(t, "real=", "plus the client's own weather and density")

	-- One line. The box is single-line, and more to the point a block is a
	-- drag where a line is a Ctrl-C.
	eq(t:find("\n"), nil, "and it is a single line")
end)

it("does not try to import the bug line when Enter is pressed over it", function()
	-- Enter is the reflex after Ctrl-C, and the box's Enter key means "apply
	-- this profile". The bug line is not a profile, so that would fail loudly
	-- on the single most likely keystroke.
	local w = H.world()
	w:slash("snow")
	w:slash("bug")
	local box = w:editBox()
	-- Counted rather than matched on wording: a rejected import complains in
	-- chat, and the point is that the player sees no complaint at all, not
	-- that it says any particular thing.
	local before = #w.mock.printed
	box:Press("OnEnterPressed")
	eq(w:db().weather, "snow", "settings untouched")
	eq(#w.mock.printed, before, "and nothing was said about it either")
	eq(#w.mock.errors, 0, "nor thrown")

	-- Positive control: the same key over a real profile string still imports,
	-- so the guard above is narrow rather than a dead Enter key.
	local v = H.world()
	v:slash("share")
	local pbox = v:editBox()
	pbox:SetText("ComfyRain1:weather=snow")
	pbox:Press("OnEnterPressed")
	eq(v:db().weather, "snow", "a profile still applies on Enter")
end)

it("says why nothing is drawn when it is standing aside, not just that nothing is", function()
	-- "everything says on and nothing is drawing" was already reported once,
	-- for the indoor case. Deference is the same failure with no visible cause
	-- at all: the player is outdoors, in the open, with rain on screen that is
	-- not ours, and the window used to say "normal rain, not drawn".
	local w = H.world()
	w:open()
	eq(noteOf(w).text, "", "drawing to begin with")

	w.mock.state.weather = { type = 1, intensity = 0.7 }
	w.mock.cvars.weatherDensity = "3"
	w:advance(3.0, 0.1)
	eq(w:overlay():IsShown(), false, "their storm has stopped ours")
	eq(w:db().enabled, true, "with the setting still on, which is the trap")
	ok(w:says("Game rain here"), "and the window says so, in words")

	-- Positive control: it is the deference talking, not a hard-wired string.
	w:slash("defer off")
	w:advance(0.5)
	eq(noteOf(w).text, "", "and it goes back to normal when told to")
end)

it("says what Off leaves, on the selector itself", function()
	-- "does the ui menus allow it to be used easily as well, im confused",
	-- 2026-10-20: nothing said the light keeps working with the weather off.
	-- That was a line that appeared under the heading while off, and pushed
	-- the window around. The selectors that switch things say it instead.
	local w = H.world()
	w:open()
	choose(w, "Type", "Off")
	local _, off = w:hover(w:select("Type").well)
	contains(off, "Off leaves Time of Day as it is", "Type: Off says the light stays")
	contains(off, "/comfy off", "and teaches the command")
	local _, mode = w:hover(w:select("Mode").well)
	contains(mode, "server's own day and night", "Mode: Off says it is the game's light")
	contains(mode, "/comfy time off", "and teaches its command")
end)

it("keeps a whole look one command away", function()
	-- The scenes were buttons from 2026-10-20 ("can we not have like quick
	-- preset buttons") until 2026-10-23 ("do we need those presets at the top
	-- ... im confused cause theres redundancy"). They are commands now.
	local w = H.world()
	w:open()

	w:slash("preset storm")
	local db = w:db()
	eq(db.enabled, true, "storm turns the weather on")
	eq(db.weather, "rain", "storm is rain")
	eq(db.intensity, "monsoon", "at the top of it")
	eq(db.thunder, true, "with thunder")
	gt(db.gust, 1, "and wind")

	-- The one a player does not find on their own: a dark sky with nothing
	-- falling out of it.
	w:slash("preset overcast")
	db = w:db()
	eq(db.enabled, true, "overcast leaves the addon on")
	eq(db.scale, 0, "with the drops not drawing")
	eq(db.gloom, 2, "and the darkening as far as it goes")
	eq(db.sound, true, "the sound stays")
end)

it("leaves nothing behind from the scene before it", function()
	-- Every preset writes the same keys, so pressing two of them in a row ends
	-- on the second one and not on a mixture. A preset that sets eight keys
	-- after one that set nine is how a button stops being reproducible.
	local w = H.world()
	w:slash("preset storm")
	w:slash("preset cozy")
	local a = {}
	for k, v in pairs(w:db()) do a[k] = v end

	local w2 = H.world()
	w2:slash("preset cozy")
	for _, k in ipairs({ "enabled", "weather", "intensity", "scale", "speed",
	                     "gloom", "gust", "sound", "thunder" }) do
		eq(a[k], w2:db()[k], "Cozy after Storm matches Cozy from fresh: " .. k)
	end
end)

it("runs a scene typed, and lists the real ones for a wrong name", function()
	local w = H.world()
	w:slash("preset overcast")
	eq(w:db().scale, 0, "typed preset lands the same way")
	w:slash("preset nonsense")
	gt(#w.mock.printedMatching("usage"), 0, "and an unknown name lists the real ones")
end)

it("keeps the storm's rain at the speed the preset table was calibrated at",
function()
	-- "storm feels too fast and fake to be honest", 2026-10-20. monsoon's own
	-- fall speed is 2.76, the highest in the table and already measured; a
	-- multiplier above 1 on top of that is how a 2D sheet stops reading as
	-- rain and starts reading as a scrolling texture. Density and dark are
	-- what sell heavy rain, not pace.
	local w = H.world()
	w:slash("preset storm")
	local db = w:db()
	ok(db.speed <= 1.0, "storm does not speed the drops up past the preset")
	lt(db.gust, 1.5, "nor swing them as hard as it did")
	eq(db.intensity, "monsoon", "it is still a monsoon")
	gt(db.gloom, 1.0, "and still dark")
end)

it("changes the light on its own, and night with nothing falling is two presses",
function()
	-- "maybe we want just like night and day without weather", 2026-10-20,
	-- and "if we wanted no weather but wanted it day or night", 2026-10-23.
	-- Night used to switch the weather off itself, so Storm then Night threw
	-- the storm away. Now each owns one thing.
	local w = H.world({ state = { gameHour = 12, gameMinute = 0 } })
	w:open()

	w:slash("preset storm")
	w:slash("preset night")
	local db = w:db()
	eq(db.enabled, true, "night leaves the weather on")
	eq(db.intensity, "monsoon", "and leaves it the storm it was")
	eq(db.timeMode, "fixed", "while holding an hour")
	eq(db.timeFixed, 22, "a late one")
	w:advance(1)
	eq(w:tod():IsShown(), true, "with the grade actually up")
	lt(w:dim().colour[1], 0.6, "and the scene darkened")
	gt(w:dim().colour[3], w:dim().colour[1], "cooler than it is dark")

	-- No weather, still night: Type: Off, and the hour stays.
	choose(w, "Type", "Off")
	db = w:db()
	eq(db.enabled, false, "Off stops the weather")
	eq(db.timeFixed, 22, "and leaves the held hour alone")
	w:advance(1)
	eq(w:tod():IsShown(), true, "so it is still night, with nothing falling")

	-- Composable the other way too: a weather scene on top keeps the hour.
	w:slash("preset cozy")
	db = w:db()
	eq(db.enabled, true, "a weather scene turns it back on")
	eq(db.timeFixed, 22, "still at the held hour")
	eq(db.intensity, "light", "while setting its own look")
end)

it("names its own off switch when a light preset darkens the screen", function()
	-- The one state this addon has already been reported for is a dark screen
	-- with no visible cause. A button that produces it does not get to arrive
	-- without saying how to leave.
	local w = H.world()
	w:open()
	w.mock.printed = {}
	w:slash("preset dusk")
	gt(#w.mock.printedMatching("/comfy time off"), 0, "dusk names the way back")
end)

it("writes the same keys for every preset of the same kind", function()
	-- The invariant the whole preset table rests on, checked structurally
	-- rather than by eye. A preset that sets eight keys where its siblings set
	-- nine leaves the ninth behind from whatever was pressed before it, so the
	-- same button gives two different screens on two different days. By kind,
	-- because weather and light presets write deliberately disjoint sets.
	local w = H.world()
	local seen = {}
	for _, p in ipairs(w.env.ComfyRainAPI.Presets) do
		local keys = {}
		for k in pairs(p.set) do keys[#keys + 1] = k end
		table.sort(keys)
		local sig = table.concat(keys, ",")
		ok(p.kind, p.key .. " declares a kind")
		if seen[p.kind] then
			eq(sig, seen[p.kind].sig,
				p.key .. " writes the same keys as " .. seen[p.kind].key)
		else
			seen[p.kind] = { sig = sig, key = p.key }
		end
	end

	-- And the two kinds really are disjoint, which is what makes Night then
	-- Cozy a light rain at ten at night instead of a fight.
	local weather, light = {}, {}
	for _, p in ipairs(w.env.ComfyRainAPI.Presets) do
		for k in pairs(p.set) do
			(p.kind == "light" and light or weather)[k] = true
		end
	end
	-- No exception for `enabled` any more: a light preset that switched the
	-- weather was the bug that made the two rows one.
	local n = 0
	for k in pairs(light) do
		n = n + 1
		eq(weather[k], nil, "no weather preset also writes " .. k)
	end
	gt(n, 0, "and there were light keys to check")
	ok(weather.enabled, "weather presets still switch the weather on")
end)

it("has no row of scenes: the sections are the one way to set things", function()
	-- "do we need those presets at the top, cant we just use the rain & snow
	-- type of ui, and then under that time of day, im confused cause theres
	-- redundancy", 2026-10-23.
	local w = H.world()
	w:open()
	local found = 0
	for _, p in ipairs(w.env.ComfyRainAPI.Presets) do
		found = found + 1
		eq(w:button(p.label), nil, "no " .. p.label .. " button")
	end
	gt(found, 0, "and there were scenes to look for")
	-- Positive control: the same lookup finds a pill that is there.
	ok(w:button("Use mine"), "the lookup does find a button that exists")
end)

it("starts Type and Time of Day with Off, the way back for each", function()
	local w = H.world()
	w:open()
	w:slash("preset night")
	eq(reads(w, "Mode"), "Fixed hour", "the light is held")
	choose(w, "Mode", "Off")
	eq(w:db().timeMode, "off", "Mode: Off hands the light back")
	eq(w:db().enabled, true, "without touching the weather")

	w:slash("time 21")
	choose(w, "Type", "Off")
	eq(w:db().enabled, false, "Type: Off stops the weather")
	eq(w:db().timeMode, "fixed", "without touching the light")
end)

it("reads its multipliers as percentages of the default", function()
	-- "1.30" is a number out of a config file: it does not say what it is 1.30
	-- OF. 0 is the one value worth reading as a state rather than a quantity.
	local w = H.world()
	w:open()
	w:slash("volume 0.30")
	eq(valueOf(w, "Volume")._text, "30%", "a multiplier reads as a percentage")
	w:slash("volume 0")
	eq(valueOf(w, "Volume")._text, "Off", "and zero reads as a state")
	w:slash("time 21")
	eq(valueOf(w, "Hold at Hour")._text, "21",
		"the one non-multiplier keeps its own units")
end)

it("offers the fix beside the reason when real weather has won", function()
	-- The status line can only say what is happening. "Real rain here, so the
	-- game's own is showing" is a complete explanation and still leaves the
	-- player hunting nine controls down the window for the tickbox that
	-- changes it, which is the half of the answer that actually helps.
	local w = H.world()
	w:open()
	eq(w:button("Use mine") and w:button("Use mine"):IsVisible() or false, false,
		"no fix offered while there is nothing to fix")

	w.mock.state.weather = { type = 1, intensity = 0.7 }
	w.mock.cvars.weatherDensity = "3"
	w:advance(3.0, 0.1)

	ok(w:says("Game rain here"), "the reason is spelled out under the status")
	local use = w:button("Use mine")
	ok(use and use:IsVisible(), "and the fix is right beside it")

	use:Click()
	w:advance(0.5)
	eq(w:db().defer, false, "pressing it stops the deferring")
	eq(w:overlay():IsShown(), true, "and ours is on screen")
	eq(w:button("Use mine"):IsVisible(), false, "the fix goes with the problem")
end)

it("says when a light scene asks for the hour the server is already at",
function()
	-- The grade is a ratio against the server's own light, so holding 22:00 on
	-- a server already at 22:00 is correctly nothing at all. Correct and
	-- indistinguishable from broken: the button goes down and the screen does
	-- not change. Naming it is the whole fix; there is nothing to press.
	local w = H.world()
	w.mock.state.gameHour, w.mock.state.gameMinute = 22, 0
	w:open()
	w:slash("preset night")
	w:advance(0.5)

	eq(w:db().timeFixed, 22, "asking for the hour it already is")
	ok(w:says("already at that hour"), "and the window says why nothing moved")
	eq(w:button("Use mine") and w:button("Use mine"):IsVisible() or false, false,
		"with no button, because there is nothing to undo")

	-- Positive control: the same scene on a bright server does change things,
	-- and then the note has no business being up.
	-- The note has no control press coming to correct it, so the clock tick is
	-- what has to take it down. That tick is a 20s one: game time moves slowly
	-- and a sentence about the hour can afford to be a third of a minute late.
	w.mock.state.gameHour = 12
	w:advance(21, 0.5)
	eq(w:says("already at that hour"), nil, "and it goes when the hour moves")
end)

it("opens from the addon compartment without a slash command", function()
	-- Somebody who installed this from CurseForge and read nothing has two
	-- ways to find it: the minimap ring, which half of them have hidden behind
	-- an icon manager, and the compartment, which is the one list that always
	-- holds every addon. The slash command is for people who already know.
	local w = H.world()
	ok(w.env.ComfyRain_Compartment, "the TOC names a function and it exists")

	w.env.ComfyRain_Compartment("ComfyRain", "LeftButton")
	ok(w:panel() and w:panel():IsShown(), "left-click is the settings window")

	local before = w:db().enabled
	w.env.ComfyRain_Compartment("ComfyRain", "RightButton")
	eq(w:db().enabled, not before, "right-click is the weather itself")

	-- Older clients pass only the addon name. Anything that is not a stated
	-- right-click has to be the harmless one.
	w.env.ComfyRain_Panel("hide")
	w.env.ComfyRain_Compartment("ComfyRain")
	ok(w:panel():IsShown(), "and a client that passes no button still opens it")
end)

it("lists itself in the client's own addon settings, and points home", function()
	-- The first place somebody looks for an addon they just installed. What is
	-- registered is a STUB with one button: the real window is movable, closes
	-- on Escape and is opened by a slash command, and a frame hosted inside
	-- the settings canvas is none of those three.
	local w = H.world()
	w.env.ComfyRain_Settings()

	local cat = w.mock.settingsRegistered
	ok(cat, "a category is registered with the client")
	eq(cat.name, "Comfy Rain", "under the name on the addon list")

	local open = w:button("Open Comfy Rain")
	ok(open, "with a way through to the real window")
	open:Click()
	ok(w:panel() and w:panel():IsShown(), "which opens it")

	-- Registering twice would put a second Comfy Rain in the list.
	w.env.ComfyRain_Settings()
	eq(#w.mock.settingsCategories, 1, "and it only ever registers once")
end)

it("survives a client with no settings API at all", function()
	-- Whether this build hosts an options panel is genuinely unknown, and the
	-- client is gone before it can be asked. So the thing worth testing is
	-- that the answer costs the entry and not the addon: no error, and every
	-- other way in still working.
	local w = H.world({ noSettings = true })

	local fine, err = pcall(w.env.ComfyRain_Settings)
	eq(fine, true, "registering is a no-op rather than an error: " .. tostring(err))
	eq(w.mock.settingsRegistered, nil, "nothing half-registered is left behind")

	w:open()
	ok(w:panel():IsShown() and w:select("Type"), "and the real window is untouched")
end)

-- Classic Era, MoP Classic and TBC Anniversary have neither C_Weather nor
-- C_Sound.PlaySoundWithOptions: the Era binary and Blizzard's API docs for all
-- three agree (issue #20). This is the addon booted the way they would boot it.
local function classicWorld()
	local w = H.world({ loaded = false })
	w.env.C_Weather = nil
	w.env.C_Sound.PlaySoundWithOptions = nil
	w:load()
	return w
end

it("leaves out Volume and Hide when game rains where the client cannot do them", function()
	local w = classicWorld()
	w:open()
	eq(w:slider("Volume"), nil, "no volume slider without a gain control")
	eq(w:button("Hide when game rains"), nil, "no hide box without C_Weather")
	ok(w:button("Play sounds") and w:button("Thunder"), "the rest of Sound is still there")
	ok(w:select("Type") and w:select("Mode"), "and so are Weather and Time of Day")
	-- A refresh with both controls absent, which is where a nil would bite.
	w:slash("snow")
	eq(#w.mock.errors, 0, "errors with the two controls absent")
end)

it("says why on a client without them, instead of quietly doing nothing", function()
	-- Control: the full client lists both commands in its help.
	local full = H.world()
	full:slash("help")
	gt(#full.mock.printedMatching("/comfy auto"), 0, "help lists auto where it works")
	gt(#full.mock.printedMatching("/comfy volume"), 0, "and volume")

	local w = classicWorld()
	w:slash("help")
	eq(#w.mock.printedMatching("/comfy auto"), 0, "help leaves out auto")
	eq(#w.mock.printedMatching("/comfy volume"), 0, "and volume")

	local vol, defer = w:db().volume, w:db().defer
	w:slash("auto")
	gt(#w.mock.printedMatching("does not tell addons its weather, so there is nothing"), 0,
		"auto says the game will not say")
	eq(#w.mock.printedMatching("reports no weather here"), 0, "rather than claiming a clear sky")
	w:slash("volume 0.2")
	gt(#w.mock.printedMatching("no volume control"), 0, "volume points at the game's slider")
	eq(w:db().volume, vol, "and stores nothing that would drive nothing")
	w:slash("defer off")
	gt(#w.mock.printedMatching("cannot see the game's rain"), 0, "defer says why")
	eq(w:db().defer, defer, "and leaves the setting alone")

	local played = 0
	for _, s in ipairs(w.mock.sounds) do if s.file then played = played + 1 end end
	gt(played, 0, "the rain is still heard, through the plain call")
	eq(#w.mock.errors, 0, "errors")
end)

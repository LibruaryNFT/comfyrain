-- Duskfall settings window.
--
-- Three decisions, because each one is a thing that could have been done the
-- obvious way and should not have been:
--
-- 1. This is a frame we draw ourselves, not a Blizzard Settings panel. The
--    Settings API is not known to work on this client at all: AddSearchTags
--    already throws ADDON_ACTION_FORBIDDEN here, and whether a canvas category
--    registers on build 70338 is still an open Phase 1 question. A settings
--    window is the thing a non-power-user needs most, so it cannot be the one
--    part of the addon that depends on an API we have never seen work. Nothing
--    below uses a template, a Backdrop, or UIDropDownMenu either: every pixel
--    comes from CreateFrame, CreateTexture and CreateFontString, which the
--    weather overlay has already proven on this client.
--
-- 2. Every control issues a slash command through DuskfallAPI.Command. Not one
--    of them writes to the saved variables directly. So the window can never do
--    something the command line cannot, the two can never disagree, and the
--    whole settings surface stays behind the slash parser's existing tests.
--
-- 3. Every control's tooltip names the command it runs. The window is not a
--    replacement for the commands, it is how you learn them: drag the slider,
--    read "/dusk alpha 0.75", and next time type it.
--
-- There is no OK, Apply or Cancel. The weather is drawn live behind the window,
-- so every change shows itself immediately, and a dialog that makes you press
-- Apply to see what you just chose is a dialog that gets closed.

local ADDON = "Duskfall"

local WIDTH    = 330
local PAD      = 14
local ROW      = 24
local GAP      = 7

-- The chat prefix colour, so the window and the addon's voice match.
local ACCENT   = { 0.50, 0.72, 1.00 }
local BG       = { 0.04, 0.05, 0.07, 0.94 }
local EDGE     = { 0.50, 0.72, 1.00, 0.35 }
local PILL     = { 0.16, 0.18, 0.23, 1 }
local PILL_ON  = { 0.22, 0.42, 0.72, 1 }
local DIM      = { 0.62, 0.64, 0.70 }

local panel, rows, controls
local updating = false      -- guards the write-back loop while we set widgets

local function DB() return DuskfallAPI and DuskfallAPI.DB() end
local function Run(cmd) DuskfallAPI.Command(cmd) end

--------------------------------------------------------------------------------
-- Pieces
--------------------------------------------------------------------------------

local function Fill(parent, colour, layer, sublevel)
	local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sublevel)
	t:SetColorTexture(colour[1], colour[2], colour[3], colour[4] or 1)
	return t
end

-- A one-pixel border drawn as four quads. SetBackdrop needs BackdropTemplate on
-- modern clients and BackdropTemplateMixin on others; four textures need neither
-- and look the same.
local function Border(frame, colour)
	local function edge(p1, p2, w, h)
		local t = Fill(frame, colour, "BORDER")
		t:SetPoint(p1)
		t:SetPoint(p2)
		if w then t:SetWidth(w) end
		if h then t:SetHeight(h) end
		return t
	end
	edge("TOPLEFT", "TOPRIGHT", nil, 1)
	edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, 1)
	edge("TOPLEFT", "BOTTOMLEFT", 1, nil)
	edge("TOPRIGHT", "BOTTOMRIGHT", 1, nil)
end

local function Text(parent, inherits, justify)
	local fs = parent:CreateFontString(nil, "OVERLAY", inherits or "GameFontHighlightSmall")
	fs:SetJustifyH(justify or "LEFT")
	return fs
end

-- The tooltip is where the command lives, so it is not optional on any control.
local function Teach(widget, title, command, note)
	widget.command = command
	widget:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(title)
		if note then GameTooltip:AddLine(note) end
		if self.command then GameTooltip:AddLine("|cffffd100" .. self.command .. "|r") end
		GameTooltip:Show()
	end)
	widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function Pill(parent, label, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetHeight(ROW - 4)
	b.bg = Fill(b, PILL)
	b.bg:SetAllPoints(b)
	b.label = Text(b, "GameFontHighlightSmall", "CENTER")
	b.label:SetPoint("CENTER")
	-- Without this the button's own SetText has nothing to draw into, and
	-- GetText would answer for a string nobody can see.
	b:SetFontString(b.label)
	b:SetScript("OnClick", onClick)

	-- The button's own text is kept in step with the font string it draws, so
	-- what the widget reports and what the player reads can never differ.
	function b:SetLabel(text)
		self.label:SetText(text)
		self:SetText(text)
	end
	b:SetLabel(label)

	local hi = Fill(b, { 1, 1, 1, 0.10 }, "HIGHLIGHT")
	hi:SetAllPoints(b)
	b:SetHighlightTexture(hi)

	function b:SetSelected(on)
		self.selected = on and true or false
		local c = on and PILL_ON or PILL
		self.bg:SetColorTexture(c[1], c[2], c[3], c[4])
		if on then
			self.label:SetTextColor(1, 1, 1)
		else
			self.label:SetTextColor(DIM[1], DIM[2], DIM[3])
		end
	end
	b:SetSelected(false)
	return b
end

-- A row of pills that share a width and act as one choice.
-- The saved value may be a boolean from before indoors became three-state.
local function INDOORS(db)
	if db.indoors == true then return "on" end
	if db.indoors == false or db.indoors == nil then return "dim" end
	return db.indoors
end

local function PillRow(parent, n)
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(ROW)
	row.pills = {}
	for i = 1, n do
		local p = Pill(row, "", nil)
		p:SetPoint("TOPLEFT", row, "TOPLEFT", (i - 1) * ((WIDTH - PAD * 2) / n), 0)
		p:SetWidth((WIDTH - PAD * 2) / n - 3)
		row.pills[i] = p
	end
	return row
end

-- A checkbox is a pill with a lamp on it: one widget type instead of two, and
-- no dependency on the client's checkbox art existing.
local function Toggle(parent, label, command, onClick)
	local b = Pill(parent, label, onClick)
	b.lamp = Fill(b, PILL_ON, "ARTWORK")
	b.lamp:SetSize(7, 7)
	b.lamp:SetPoint("LEFT", b, "LEFT", 7, 0)
	b.label:ClearAllPoints()
	b.label:SetPoint("LEFT", b, "LEFT", 19, 0)
	b.label:SetJustifyH("LEFT")

	function b:SetOn(on)
		if on then
			self.lamp:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 1)
			self.label:SetTextColor(1, 1, 1)
		else
			self.lamp:SetColorTexture(0.25, 0.26, 0.30, 1)
			self.label:SetTextColor(DIM[1], DIM[2], DIM[3])
		end
		self.on = on and true or false
	end
	b:SetOn(false)
	Teach(b, label, command)
	return b
end

local function Slider(parent, label, lo, hi, step, fmt, apply)
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(36)

	row.label = Text(row)
	row.label:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
	row.label:SetText(label)

	row.value = Text(row, "GameFontNormalSmall", "RIGHT")
	row.value:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)

	local s = CreateFrame("Slider", nil, row)
	s:SetOrientation("HORIZONTAL")
	s:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -16)
	s:SetWidth(WIDTH - PAD * 2)
	s:SetHeight(14)
	s:SetMinMaxValues(lo, hi)
	s:SetValueStep(step)
	s:SetObeyStepOnDrag(true)

	local track = Fill(s, { 0.15, 0.16, 0.20, 1 }, "BACKGROUND")
	track:SetHeight(3)
	track:SetPoint("LEFT")
	track:SetPoint("RIGHT")

	local thumb = s:CreateTexture(nil, "ARTWORK")
	thumb:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 1)
	thumb:SetSize(8, 14)
	s:SetThumbTexture(thumb)

	s:SetScript("OnValueChanged", function(self, v)
		row.value:SetText(string.format(fmt, v))
		-- Refresh() sets every widget from the database; without this guard that
		-- write would bounce straight back out as a command.
		if updating then return end
		apply(v)
	end)

	row.slider = s
	function row:Set(v)
		s:SetValue(v)
		row.value:SetText(string.format(fmt, s:GetValue()))
	end
	return row
end

local function Heading(parent, label)
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(18)
	local fs = Text(row, "GameFontNormalSmall")
	fs:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 2)
	fs:SetText(label)
	fs:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])
	local line = Fill(row, { 1, 1, 1, 0.08 }, "ARTWORK")
	line:SetHeight(1)
	line:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
	line:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
	return row
end

--------------------------------------------------------------------------------
-- Layout
--------------------------------------------------------------------------------

-- Rows are stacked top-down and the window is sized to whatever is visible, so
-- hiding the time-of-day controls when the feature is off shrinks the window
-- instead of leaving a hole in it.
local function Relayout()
	local y = -PAD - 20
	for _, r in ipairs(rows) do
		local show = (not r.visible) or r.visible()
		if show then
			r.frame:ClearAllPoints()
			r.frame:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, y)
			r.frame:SetWidth(WIDTH - PAD * 2)
			r.frame:Show()
			y = y - r.frame:GetHeight() - (r.gap or GAP)
		else
			r.frame:Hide()
		end
	end
	panel:SetHeight(-y + PAD)
end

--------------------------------------------------------------------------------
-- Reading the addon back
--------------------------------------------------------------------------------

local CHANNELS = { "Ambience", "SFX", "Master", "Music", "Dialog" }
local TIME_MODES = {
	{ key = "off",    label = "Off",      cmd = "time off" },
	{ key = "local",  label = "My clock", cmd = "time local" },
	{ key = "offset", label = "Shifted",  cmd = "time +9" },
	{ key = "fixed",  label = "Held",     cmd = "time 21" },
}

local function Refresh()
	if not panel or not panel:IsShown() then return end
	local db = DB()
	if not db then return end
	updating = true

	local weather = DuskfallAPI.Weather[db.weather] or DuskfallAPI.Weather.rain

	controls.rain:SetSelected(db.weather == "rain")
	controls.snow:SetSelected(db.weather == "snow")
	controls.power:SetOn(db.enabled)
	controls.power:SetLabel(db.enabled and "Weather on" or "Weather off")

	-- The intensity pills are relabelled rather than rebuilt: the top step is
	-- named for its weather (monsoon, blizzard) and the rest are shared.
	for i, pill in ipairs(controls.intensity.pills) do
		local name = weather.order[i]
		pill.intensity = name
		pill:SetLabel(name and (name:gsub("^%l", string.upper)) or "")
		pill:SetSelected(name == db.intensity)
		Teach(pill, "Intensity", name and ("/dusk " .. name) or nil)
	end

	controls.alpha:Set(db.scale)
	controls.speed:Set(db.speed)
	controls.dim:Set(db.gloom)
	controls.gust:Set(db.gust)
	controls.volume:Set(db.volume)

	controls.sound:SetOn(db.sound)
	controls.thunder:SetOn(db.thunder)
	-- Rain has lightning, snow has gusts, and the button must say which.
	controls.thunder:SetLabel(weather.flash and "Thunder" or "Gusts")
	controls.indoors:SetLabel("Indoors: " .. INDOORS(db))
	controls.channel:SetLabel("Volume: " .. db.channel)

	for _, pill in ipairs(controls.timeMode.pills) do
		pill:SetSelected(pill.mode == db.timeMode)
	end
	if db.timeMode == "offset" then
		controls.hour.label:SetText("Shift the realm's clock by hours")
		controls.hour:Set(db.timeOffset)
	elseif db.timeMode == "fixed" then
		controls.hour.label:SetText("Hold this hour")
		controls.hour:Set(db.timeFixed)
	end
	controls.strength:Set(db.timeStrength)

	updating = false
	Relayout()
end

--------------------------------------------------------------------------------
-- The window
--------------------------------------------------------------------------------

local function Build()
	local db = DB()

	panel = CreateFrame("Frame", "DuskfallPanel", UIParent)
	panel:SetWidth(WIDTH)
	panel:SetHeight(400)
	panel:SetFrameStrata("DIALOG")
	panel:EnableMouse(true)
	panel:SetMovable(true)
	panel:SetClampedToScreen(true)
	panel:SetToplevel(true)
	panel:RegisterForDrag("LeftButton")
	panel:SetScript("OnDragStart", function(self) self:StartMoving() end)
	panel:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local point, _, rel, x, y = self:GetPoint()
		DB().ui = { point = point, rel = rel, x = x, y = y }
	end)
	panel:Hide()

	local bg = Fill(panel, BG)
	bg:SetAllPoints(panel)
	Border(panel, EDGE)

	local title = Text(panel, "GameFontNormal")
	title:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -PAD)
	title:SetText("Duskfall")
	title:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])

	local close = CreateFrame("Button", nil, panel)
	close:SetSize(20, 20)
	close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD + 4, -PAD + 4)
	local x = Text(close, "GameFontNormal", "CENTER")
	x:SetPoint("CENTER")
	x:SetText("x")
	close:SetScript("OnClick", function() panel:Hide() end)
	Teach(close, "Close", "/duskfall")

	controls, rows = {}, {}
	local function add(frame, opts)
		rows[#rows + 1] = { frame = frame, visible = opts and opts.visible,
		                    gap = opts and opts.gap }
		return frame
	end

	-- Weather, and the master switch, on one line: the two things somebody
	-- opening this window for the first time is looking for.
	local top = add(CreateFrame("Frame", nil, panel))
	top:SetHeight(ROW)
	local third = (WIDTH - PAD * 2) / 3
	controls.rain = Pill(top, "Rain", function() Run("rain") end)
	controls.rain:SetPoint("TOPLEFT", top, "TOPLEFT", 0, 0)
	controls.rain:SetWidth(third - 3)
	Teach(controls.rain, "Rain", "/dusk rain")

	controls.snow = Pill(top, "Snow", function() Run("snow") end)
	controls.snow:SetPoint("TOPLEFT", top, "TOPLEFT", third, 0)
	controls.snow:SetWidth(third - 3)
	Teach(controls.snow, "Snow", "/dusk snow")

	controls.power = Toggle(top, "Weather on", "/dusk", function()
		Run(DB().enabled and "off" or "on")
	end)
	controls.power:SetPoint("TOPLEFT", top, "TOPLEFT", third * 2, 0)
	controls.power:SetWidth(third)

	controls.intensity = add(PillRow(panel, 4))
	for _, pill in ipairs(controls.intensity.pills) do
		pill:SetScript("OnClick", function(self)
			if self.intensity then Run(self.intensity) end
		end)
	end

	controls.alpha = add(Slider(panel, "How visible it is", 0, 1.5, 0.05, "%.2f",
		function(v) Run(string.format("alpha %.2f", v)) end))
	Teach(controls.alpha.slider, "How visible it is", "/dusk alpha 0.75")

	controls.speed = add(Slider(panel, "How fast it falls", 0.2, 3, 0.05, "%.2f",
		function(v) Run(string.format("speed %.2f", v)) end))
	Teach(controls.speed.slider, "How fast it falls", "/dusk speed 1.4")

	controls.dim = add(Slider(panel, "How dark it gets", 0, 2, 0.05, "%.2f",
		function(v) Run(string.format("dim %.2f", v)) end))
	Teach(controls.dim.slider, "How dark it gets", "/dusk dim 0.5",
		"0 leaves the world's own light alone.")

	controls.gust = add(Slider(panel, "How much it gusts", 0, 2, 0.05, "%.2f",
		function(v) Run(string.format("gust %.2f", v)) end))
	Teach(controls.gust.slider, "How much it gusts", "/dusk gust 0.5",
		"0 is dead calm: one fixed rate, no wind.")

	add(Heading(panel, "Sound"), { gap = 4 })

	controls.volume = add(Slider(panel, "How loud it is", 0, 1, 0.05, "%.2f",
		function(v) Run(string.format("volume %.2f", v)) end))
	Teach(controls.volume.slider, "How loud it is", "/dusk volume 0.5",
		"Only Duskfall's own weather. Your game volume is untouched.")

	local audio = add(CreateFrame("Frame", nil, panel))
	audio:SetHeight(ROW)
	controls.sound = Toggle(audio, "Sound", "/dusk sound off",
		function() Run(DB().sound and "sound off" or "sound on") end)
	controls.sound:SetPoint("TOPLEFT", audio, "TOPLEFT", 0, 0)
	controls.sound:SetWidth(third - 3)

	controls.thunder = Toggle(audio, "Thunder", "/dusk thunder off",
		function() Run(DB().thunder and "thunder off" or "thunder on") end)
	controls.thunder:SetPoint("TOPLEFT", audio, "TOPLEFT", third, 0)
	controls.thunder:SetWidth(third - 3)

	-- Three states, so a cycling pill rather than a lamp. "Dim" is the default
	-- and the one most people want: weather you can still hear and faintly see
	-- from inside, instead of it vanishing the moment you cross a threshold.
	controls.indoors = Pill(audio, "Indoors: dim", function()
		local order = { off = "dim", dim = "on", on = "off" }
		Run("indoors " .. (order[INDOORS(DB())] or "dim"))
	end)
	controls.indoors:SetPoint("TOPLEFT", audio, "TOPLEFT", third * 2, 0)
	controls.indoors:SetWidth(third)

	-- A cycling button rather than a dropdown: UIDropDownMenu is a template,
	-- and five options do not need a menu.
	controls.channel = add(Pill(panel, "Volume: Ambience", function()
		local db2, at = DB(), 1
		for i, c in ipairs(CHANNELS) do if c == db2.channel then at = i end end
		Run("channel " .. CHANNELS[(at % #CHANNELS) + 1]:lower())
	end))
	Teach(controls.channel, "Which volume slider owns it",
		"/dusk channel Ambience", "Ambience keeps it out of the way of music.")

	add(Heading(panel, "Time of day"), { gap = 4 })

	controls.timeMode = add(PillRow(panel, 4))
	for i, pill in ipairs(controls.timeMode.pills) do
		local mode = TIME_MODES[i]
		pill.mode = mode.key
		pill:SetLabel(mode.label)
		pill:SetScript("OnClick", function() Run(mode.cmd) end)
		Teach(pill, mode.label, "/dusk " .. mode.cmd)
	end

	controls.hour = add(Slider(panel, "Hour", -12, 23, 1, "%d", function(v)
		if DB().timeMode == "offset" then
			Run(string.format("time %+d", v))
		else
			Run(string.format("time %d", v))
		end
	end), { visible = function()
		local m = DB().timeMode
		return m == "offset" or m == "fixed"
	end })

	controls.strength = add(Slider(panel, "How strongly", 0, 1, 0.05, "%.2f",
		function(v) Run(string.format("time strength %.2f", v)) end),
		{ visible = function() return DB().timeMode ~= "off" end })

	local foot = add(CreateFrame("Frame", nil, panel))
	foot:SetHeight(ROW)
	local half = (WIDTH - PAD * 2) / 2
	local commands = Pill(foot, "All commands", function() Run("help") end)
	commands:SetPoint("TOPLEFT", foot, "TOPLEFT", 0, 0)
	commands:SetWidth(half - 3)
	Teach(commands, "Print every command to chat", "/dusk help")

	local reset = Pill(foot, "Reset", function() Run("reset") end)
	reset:SetPoint("TOPLEFT", foot, "TOPLEFT", half, 0)
	reset:SetWidth(half)
	Teach(reset, "Back to defaults", "/dusk reset",
		"Settings only. The calibration log is kept.")

	local hint = add(CreateFrame("Frame", nil, panel), { gap = 2 })
	hint:SetHeight(14)
	local hintText = Text(hint, "GameFontDisableSmall")
	hintText:SetPoint("TOPLEFT", hint, "TOPLEFT", 0, 0)
	hintText:SetText("Hover anything to see the command for it.")

	-- Escape closes it, which is a list of frame names and therefore the reason
	-- this frame has one.
	tinsert(UISpecialFrames, "DuskfallPanel")

	if db and db.ui and db.ui.point then
		panel:ClearAllPoints()
		panel:SetPoint(db.ui.point, UIParent, db.ui.rel or db.ui.point,
			db.ui.x or 0, db.ui.y or 0)
	else
		panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	end

	-- A typed command has to move the window too, or they disagree in front of
	-- the player and the window is the half that stops being trusted.
	DuskfallAPI.changed = Refresh
end

function Duskfall_Panel(mode)
	if not DuskfallAPI or not DuskfallAPI.DB() then return end
	if not panel then Build() end

	if mode == "hide" or (mode ~= "show" and panel:IsShown()) then
		panel:Hide()
		return
	end
	panel:Show()
	Refresh()
end

--------------------------------------------------------------------------------
-- Minimap button
--------------------------------------------------------------------------------

-- Hand-rolled rather than LibDBIcon. The library is the right answer in a repo
-- that already embeds Ace; pulling in an embed chain for one draggable circle
-- is not. Position is one number - the angle around the minimap - which is all
-- LibDBIcon persists either.
local minimap

local function MinimapPlace()
	local db = DuskfallAPI and DuskfallAPI.DB()
	if not minimap or not db then return end
	local a = math.rad(db.minimapAngle or 196)
	-- Measured, not the usual hard-coded 80. That constant is the radius of a
	-- 140px default minimap, and anyone who has scaled theirs up gets the button
	-- parked inside the map over the terrain. Read the real width every time it
	-- is placed, so a resize mid-session lands correctly on the next drag.
	local w = Minimap and Minimap.GetWidth and Minimap:GetWidth() or 0
	local r = (w and w > 0) and (w / 2 + 10) or 80
	minimap:SetPoint("CENTER", Minimap, "CENTER", r * math.cos(a), r * math.sin(a))
end

local function BuildMinimap()
	if minimap or not Minimap then return end
	minimap = CreateFrame("Button", "DuskfallMinimapButton", Minimap)
	minimap:SetSize(31, 31)
	minimap:SetFrameStrata("MEDIUM")
	minimap:SetFrameLevel(Minimap:GetFrameLevel() + 8)

	local border = minimap:CreateTexture(nil, "OVERLAY")
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetSize(53, 53)
	border:SetPoint("TOPLEFT")

	local icon = minimap:CreateTexture(nil, "ARTWORK")
	icon:SetTexture("Interface\\Icons\\Spell_Frost_IceStorm")
	icon:SetSize(19, 19)
	icon:SetPoint("CENTER", -1, 1)
	-- Round it off so the square icon does not poke out of the round border.
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	minimap:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

	minimap:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	minimap:SetScript("OnClick", function(_, button)
		if button == "RightButton" then
			-- The bare command is the weather toggle; "toggle" is not a command.
			DuskfallAPI.Command("")
		else
			Duskfall_Panel()
		end
	end)

	-- Dragged around the ring, not across the screen: a free-floating button
	-- gets lost behind other frames and there is nowhere better for it to be.
	minimap:RegisterForDrag("LeftButton")
	minimap:SetMovable(true)
	minimap:SetScript("OnDragStart", function(self) self.dragging = true end)
	minimap:SetScript("OnDragStop", function(self) self.dragging = nil end)
	minimap:SetScript("OnUpdate", function(self)
		if not self.dragging then return end
		local mx, my = Minimap:GetCenter()
		local cx, cy = GetCursorPosition()
		local scale = Minimap:GetEffectiveScale()
		local db = DuskfallAPI.DB()
		if not mx or not db then return end
		db.minimapAngle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
		MinimapPlace()
	end)

	minimap:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:AddLine("Duskfall")
		GameTooltip:AddLine("Left-click: settings", 1, 1, 1)
		GameTooltip:AddLine("Right-click: weather on or off", 1, 1, 1)
		GameTooltip:AddLine("Drag: move around the minimap", 0.6, 0.6, 0.6)
		GameTooltip:Show()
	end)
	minimap:SetScript("OnLeave", function() GameTooltip:Hide() end)

	-- A player who drags the minimap's resize handle would otherwise leave the
	-- button orbiting the old radius until the next login.
	if Minimap.HookScript then
		pcall(Minimap.HookScript, Minimap, "OnSizeChanged", function() MinimapPlace() end)
	end

	MinimapPlace()
end

-- Called by Duskfall.lua once the DB exists, and again whenever the player
-- toggles the button off and on.
function Duskfall_Minimap(mode)
	local db = DuskfallAPI and DuskfallAPI.DB()
	if not db then return end
	if mode == "toggle" then db.minimap = not db.minimap end
	if db.minimap == false then
		if minimap then minimap:Hide() end
		return
	end
	BuildMinimap()
	if minimap then minimap:Show() MinimapPlace() end
end

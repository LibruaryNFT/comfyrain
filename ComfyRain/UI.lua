-- ComfyRain settings window.
--
-- Three decisions, because each one is a thing that could have been done the
-- obvious way and should not have been:
--
-- 1. This is a frame we draw ourselves, not a Blizzard Settings panel. The
--    Settings API is not known to work on this client at all: AddSearchTags
--    already throws ADDON_ACTION_FORBIDDEN here, and whether a canvas category
--    registers on build 70338 is still an open Phase 1 question. A settings
--    window is the thing a non-power-user needs most, so it cannot be the one
--    part of the addon that depends on an API we have never seen work.
--
--    What it DOES use is the client's own furniture: the dialog border and its
--    carved header plate, the close button, the stone dialog background, the
--    panel-button art and the slider groove. All of it is reached by template
--    name or by texture path, which means the art comes out of the player's own
--    installation and nothing Blizzard made is inside this package. That is the
--    line: using the interface is what the templates are for, shipping a copy
--    of it is redistribution. Every one of them is probed first - templates with
--    pcall, textures with GetFileIDFromPath - and every one has a hand-drawn
--    fallback, so a client missing any of it still gets a usable window rather
--    than a blank one.
--
-- 2. Every control issues a slash command through ComfyRainAPI.Command. Not one
--    of them writes to the saved variables directly. So the window can never do
--    something the command line cannot, the two can never disagree, and the
--    whole settings surface stays behind the slash parser's existing tests.
--
-- 3. Every control's tooltip names the command it runs. The window is not a
--    replacement for the commands, it is how you learn them: drag the slider,
--    read "/comfy alpha 0.75", and next time type it.
--
-- There is no OK, Apply or Cancel. The weather is drawn live behind the window,
-- so every change shows itself immediately, and a dialog that makes you press
-- Apply to see what you just chose is a dialog that gets closed.

local ADDON = "ComfyRain"

local WIDTH    = 330
local PAD      = 14
local ROW      = 24
local GAP      = 7
-- Room at the top for the carved header plate to sit over the frame edge.
local TOP_INSET = 30

-- Gold is WoW's own heading colour and the single cheapest way to make a
-- hand-drawn frame belong to the rest of the interface. The blue is kept, but
-- only for the lamp on a lit toggle and the slider thumb: it is the addon's
-- chat-prefix colour, so it reads as ComfyRain's and not as a second theme.
local GOLD     = { 1.00, 0.82, 0.00 }
local ACCENT   = { 0.50, 0.72, 1.00 }
local BG       = { 0.04, 0.05, 0.07, 0.94 }
local EDGE     = { 0.50, 0.72, 1.00, 0.35 }
local PILL     = { 0.16, 0.18, 0.23, 1 }
local PILL_ON  = { 0.22, 0.42, 0.72, 1 }
local DIM      = { 0.62, 0.64, 0.70 }

-- Blizzard's own dialog border, nine-sliced by the client. Drawn around our own
-- dark fill rather than over the brown stone background that usually comes with
-- it: the gold edge and the header plate are what make a frame read as WoW
-- furniture, and a parchment panel full of flat dark controls does not.
local BORDER_BACKDROP = {
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	edgeSize = 32,
	insets   = { left = 11, right = 12, top = 12, bottom = 11 },
}

-- The groove the client's own options sliders sit in: a tiled background inside
-- an 8px edge. The numbers are OptionsSliderTemplate's, copied rather than
-- inherited, because that template also brings three named font strings we do
-- not want and would have to hunt down and hide.
local SLIDER_BACKDROP = {
	bgFile   = "Interface\\Buttons\\UI-SliderBar-Background",
	edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
	tile     = true,
	tileSize = 8,
	edgeSize = 8,
	insets   = { left = 3, right = 3, top = 6, bottom = 6 },
}

-- Blizzard art referenced by path. The file is read out of the player's own
-- installation at draw time; none of it is in this package.
local ART = {
	stone = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
	thumb = "Interface\\Buttons\\UI-SliderBar-Button-Horizontal",
}

-- Icons for the three buttons that name a kind of weather. Picked by rendering
-- the candidates at 14px and looking at them, which is the size they are drawn
-- at here, not by reading their names at 64px:
--
--   rain     IceStorm's shards lose their detail on the way down and what is
--            left is slanted streaks, which is exactly what rain looks like.
--   snow     FrostShock keeps a bold white snowflake at 14px. ChillingBlast is
--            the better picture at full size and was the first choice, but it
--            dissolves into a white diagonal slash that is indistinguishable
--            from the rain icon beside it, and telling rain from snow is the
--            one thing this row has to do.
--   thunder  LightningBolt01 is still a bolt at 14px.
--
-- Worth recording because it is the kind of thing that gets "fixed" later: no
-- icon anywhere in the game depicts rain. The whole 2.27M-file catalogue was
-- searched, not just the classic range. So rain borrows a shape rather than a
-- subject, and that is deliberate.
local ICON = {
	rain    = "Interface\\Icons\\Spell_Frost_IceStorm",
	snow    = "Interface\\Icons\\Spell_Frost_FrostShock",
	thunder = "Interface\\Icons\\Spell_Lightning_LightningBolt01",
	gusts   = "Interface\\Icons\\Spell_Frost_ArcticWinds",
}

-- An unknown template name raises inside CreateFrame, so each is asked for once
-- and the answer cached. Which templates a client has cannot be read out of the
-- binary at all - they are defined in FrameXML, which lives in the game's data
-- archive and not in WowB.exe, which is why tools/api_surface.py has nothing to
-- say about them - so asking the client itself is the only honest test.
local templateOK = {}
local function Supports(kind, name, probe)
	local key = kind .. "/" .. name
	if templateOK[key] == nil then
		local ok, f = pcall(CreateFrame, kind, nil, UIParent, name)
		templateOK[key] = (ok and f and (probe == nil or probe(f))) or false
		-- Frames cannot be destroyed, so the probe's leftover is parked rather
		-- than left floating over the middle of the screen.
		if ok and f and f.Hide then f:Hide() end
	end
	return templateOK[key]
end

local function SupportsBackdrop()
	return Supports("Frame", "BackdropTemplate",
		function(f) return type(f.SetBackdrop) == "function" end)
end

-- GetFileIDFromPath resolves a path against the player's own installed data and
-- answers nil for art this build does not have. Only used where a missing file
-- would leave nothing visible at all - the slider thumb is the whole grabbable
-- part of the control, and an invisible one is a broken slider. Everywhere else
-- the Blizzard texture is laid OVER a flat quad, so a path that does not
-- resolve degrades to the old look on its own and needs no asking.
local artOK = {}
local function HasArt(path)
	if artOK[path] == nil then
		if type(GetFileIDFromPath) ~= "function" then
			-- A client that cannot be asked gets a yes. These are paths the game
			-- has shipped since 2004, and refusing to draw them because the
			-- question was unavailable is the wrong way round.
			artOK[path] = true
		else
			local ok, id = pcall(GetFileIDFromPath, path)
			artOK[path] = (not ok) or (id ~= nil and id ~= 0)
		end
	end
	return artOK[path]
end

local panel, rows, controls
local updating = false      -- guards the write-back loop while we set widgets

local function DB() return ComfyRainAPI and ComfyRainAPI.DB() end
local function Run(cmd) ComfyRainAPI.Command(cmd) end
-- Read-only, like Sections. The per-slider resets need to know what a default
-- IS in order to grey out a value that is already sitting on it, and hardcoding
-- a second copy of the numbers here is how the window and the addon start
-- disagreeing about what "default" means.
local function Defaults()
	return (ComfyRainAPI and ComfyRainAPI.Defaults) or {}
end

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
-- GameTooltip is the same frame the game draws item tooltips into, so these
-- inherit the border, the fonts and the anchoring without asking for any of it.
--
-- Everything is read off the widget at hover time rather than closed over, so a
-- control whose meaning changes can change its tooltip: the Hour slider is two
-- settings wearing one row, and the Channel button has to be able to say that
-- the volume slider it is pointing at is turned down.
--
-- The note wraps. Without that, GameTooltip sizes itself to the longest line
-- and a two-sentence explanation becomes a tooltip wider than the window it is
-- explaining.
local function Teach(widget, title, command, note)
	widget.tipTitle, widget.command, widget.tipNote = title, command, note
	widget:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(self.tipTitle or "")
		if self.tipNote then
			GameTooltip:AddLine(self.tipNote, 0.9, 0.9, 0.9, true)
		end
		if self.tipWarn then
			GameTooltip:AddLine(self.tipWarn, 1, 0.3, 0.3, true)
		end
		if self.command then GameTooltip:AddLine("|cffffd100" .. self.command .. "|r") end
		GameTooltip:Show()
	end)
	widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Blizzard's own stone-and-gold button where the client has the template.
-- Through the template rather than by painting UI-Panel-Button-Up by hand,
-- because that file is one sheet that has to be cut into three and the slicing
-- numbers live in FrameXML, where they are free and correct for whichever
-- flavour is running. The flat pill stays as the fallback and is still what
-- gets drawn on a client without the template.
local function Pill(parent, label, onClick)
	local native = Supports("Button", "UIPanelButtonTemplate")
	local b = CreateFrame("Button", nil, parent,
		native and "UIPanelButtonTemplate" or nil)
	b:SetHeight(ROW - 4)

	-- The template brings its own font string, its own highlight and its own
	-- pressed art. Asking for the font string is also the real test: a template
	-- that exists by name but hands back a bare button would otherwise give us
	-- a button with no text on it, which is worse than the flat pill.
	b.label = native and b.GetFontString and b:GetFontString() or nil
	b.native = b.label and true or false
	if not b.native then
		b.bg = Fill(b, PILL)
		b.bg:SetAllPoints(b)
		b.label = Text(b, "GameFontHighlightSmall", "CENTER")
		b.label:SetPoint("CENTER")
		-- Without this the button's own SetText has nothing to draw into, and
		-- GetText would answer for a string nobody can see.
		b:SetFontString(b.label)
		local hi = Fill(b, { 1, 1, 1, 0.10 }, "HIGHLIGHT")
		hi:SetAllPoints(b)
		b:SetHighlightTexture(hi)
	end
	b:SetScript("OnClick", onClick)

	-- The button's own text is kept in step with the font string it draws, so
	-- what the widget reports and what the player reads can never differ.
	function b:SetLabel(text)
		self.label:SetText(text)
		self:SetText(text)
	end
	b:SetLabel(label)

	-- An icon on the left with the label sliding over to make room. Asked about
	-- with HasArt rather than drawn blind, because a path this flavour does not
	-- have leaves a 14px hole where the eye expects a picture, and a centred
	-- label with no icon beats an off-centre one with a gap.
	function b:SetIcon(path, off)
		if path and not HasArt(path) then path = nil end
		if not path then
			if self.icon then self.icon:Hide() end
			self.label:ClearAllPoints()
			self.label:SetPoint("CENTER")
			self.label:SetJustifyH("CENTER")
			return
		end
		if not self.icon then
			self.icon = self:CreateTexture(nil, "ARTWORK")
			self.icon:SetSize(14, 14)
			self.icon:SetPoint("LEFT", self, "LEFT", 6, 0)
		end
		self.icon:SetTexture(path)
		self.icon:Show()
		-- Greying it out is how the client itself says a thing is switched off,
		-- and it is why the Thunder button can carry a picture instead of the
		-- little lamp: one widget says both what it is and whether it is on.
		if self.icon.SetDesaturated then
			pcall(self.icon.SetDesaturated, self.icon, off and true or false)
		end
		self.label:ClearAllPoints()
		self.label:SetPoint("LEFT", self, "LEFT", 24, 0)
		self.label:SetJustifyH("LEFT")
	end

	function b:SetSelected(on)
		self.selected = on and true or false
		if self.native then
			-- How the client shows a chosen tab: the button is locked in its own
			-- pressed state rather than tinted a colour of ours, so a selected
			-- option looks pressed in instead of looking like a second theme
			-- sitting on top of Blizzard's art.
			if self.SetButtonState then
				self:SetButtonState(on and "PUSHED" or "NORMAL", on and true or false)
			end
		else
			local c = on and PILL_ON or PILL
			self.bg:SetColorTexture(c[1], c[2], c[3], c[4])
		end
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

local function Title(s)
	return (tostring(s):gsub("^%l", string.upper))
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
		-- A toggle that has been given an icon says on/off by greying the picture,
		-- which is the client's own idiom, and the lamp goes away rather than
		-- sitting beside it saying the same thing twice.
		if self.icon and self.icon:IsShown() then
			self.lamp:Hide()
			if self.icon.SetDesaturated then
				pcall(self.icon.SetDesaturated, self.icon, not on)
			end
		else
			self.lamp:Show()
			if on then
				self.lamp:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 1)
			else
				self.lamp:SetColorTexture(0.25, 0.26, 0.30, 1)
			end
		end
		if on then
			self.label:SetTextColor(1, 1, 1)
		else
			self.label:SetTextColor(DIM[1], DIM[2], DIM[3])
		end
		self.on = on and true or false
	end
	b:SetOn(false)

	-- Same icon as a plain pill, except that losing it has to put the label back
	-- beside the lamp rather than in the middle of the button.
	local setIcon = b.SetIcon
	function b:SetIcon(path, off)
		setIcon(self, path, off)
		if not (self.icon and self.icon:IsShown()) then
			self.label:ClearAllPoints()
			self.label:SetPoint("LEFT", self, "LEFT", 19, 0)
			self.label:SetJustifyH("LEFT")
		end
		self:SetOn(self.on)
	end

	Teach(b, label, command)
	return b
end

-- reset, when given, returns the default for THIS slider and the command that
-- sets it. It is a function rather than a constant because the Hour slider's
-- default depends on which time mode is live, and because Defaults() is not
-- available until the addon has loaded.
--
-- The affordance is the number itself rather than a separate button. A 330px
-- row already carries a label, a track and a value, and seven little undo icons
-- down the right-hand edge is how a settings window starts looking like a
-- cockpit. Making the value clickable also puts the control exactly where the
-- eye already is when you decide you have gone too far, and it gives the row a
-- second job for free: the number is GOLD when the setting is off its default
-- and grey when it is on it, so "what have I actually changed here" is
-- answerable at a glance without pressing anything.
local function Slider(parent, label, lo, hi, step, fmt, apply, reset)
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(36)

	row.label = Text(row)
	row.label:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
	row.label:SetText(label)

	row.value = CreateFrame("Button", nil, row)
	row.value:SetSize(58, 14)
	row.value:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
	row.valueText = Text(row.value, "GameFontNormalSmall", "RIGHT")
	row.valueText:SetPoint("RIGHT")
	-- Without this the button's own SetText has nothing to draw into, the same
	-- reason Pill does it.
	row.value:SetFontString(row.valueText)

	local s = CreateFrame("Slider", nil, row,
		SupportsBackdrop() and "BackdropTemplate" or nil)
	s:SetOrientation("HORIZONTAL")
	s:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -16)
	s:SetWidth(WIDTH - PAD * 2)
	-- 17 rather than 14 because that is the height the client's own groove art
	-- is cut for, and the row has the three pixels spare.
	s:SetHeight(17)
	s:SetMinMaxValues(lo, hi)
	s:SetValueStep(step)
	s:SetObeyStepOnDrag(true)

	-- The flat bar is drawn first and kept. The groove goes over it, so a build
	-- without the slider art shows a plain track instead of an empty gap.
	local track = Fill(s, { 0.15, 0.16, 0.20, 1 }, "BACKGROUND")
	track:SetHeight(3)
	track:SetPoint("LEFT")
	track:SetPoint("RIGHT")
	if s.SetBackdrop then pcall(s.SetBackdrop, s, SLIDER_BACKDROP) end

	local thumb = s:CreateTexture(nil, "ARTWORK")
	-- The one place a missing file would be fatal rather than plain: the thumb
	-- is the part you grab, and an invisible one is a slider nobody can find.
	if HasArt(ART.thumb) then
		thumb:SetTexture(ART.thumb)
		thumb:SetSize(32, 32)
	else
		thumb:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 1)
		thumb:SetSize(8, 14)
	end
	s:SetThumbTexture(thumb)

	s:SetScript("OnValueChanged", function(self, v)
		row.value:SetText(string.format(fmt, v))
		-- Refresh() sets every widget from the database; without this guard that
		-- write would bounce straight back out as a command.
		if updating then return end
		apply(v)
	end)

	row.slider = s

	if reset then
		local hi = Fill(row.value, { 1, 1, 1, 0.10 }, "HIGHLIGHT")
		hi:SetAllPoints(row.value)
		row.value:SetHighlightTexture(hi)
		row.value:SetScript("OnClick", function()
			local _, cmd = reset()
			if cmd then Run(cmd) end
		end)
		-- Teach reads self.command at hover time, so the tooltip can follow a
		-- default that moves. The Hour slider's does.
		Teach(row.value, label, nil, "Click to put just this back to its "
			.. "default. Nothing else moves.")
	else
		row.value:EnableMouse(false)
	end

	function row:Set(v)
		s:SetValue(v)
		local shown = s:GetValue()
		row.value:SetText(string.format(fmt, shown))
		if not reset then return end
		local default, cmd = reset()
		row.value.command = cmd
		-- Half a step of tolerance rather than equality. The value shown is
		-- whatever the Slider widget quantised our db number to, and a
		-- comparison that demanded the two match bit for bit would light a row
		-- up as "changed" permanently the first time they did not. Defensive:
		-- the quantisation has NOT been observed to drift on this client, and
		-- half a step is below the resolution of anything the player can
		-- express anyway, so it costs nothing to be wrong about.
		--
		-- Deliberately unspecced, and that is the honest state rather than an
		-- oversight. The mock's Slider quantises on the way IN, so GetValue
		-- never returns an off-grid number and no spec written against it can
		-- tell the tolerance from an equality test - two attempts at one both
		-- passed with the tolerance removed. A guard that cannot fail is worse
		-- than none, because it reads as cover.
		local at = default and math.abs(shown - default) < (step / 2)
		if at then
			row.valueText:SetTextColor(DIM[1], DIM[2], DIM[3])
		else
			row.valueText:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
		end
	end
	return row
end

-- A section heading, and - when it names a section - the Reset that belongs to
-- it. Per-section rather than one Reset at the bottom, because "the sound is
-- how I want it and the look is a mess" is the normal case, and a single button
-- that takes the whole profile with it is one people learn not to press.
local function Heading(parent, label, section)
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(18)
	local fs = Text(row, "GameFontNormalSmall")
	fs:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 2)
	fs:SetText(label)
	fs:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
	local line = Fill(row, { 1, 1, 1, 0.08 }, "ARTWORK")
	line:SetHeight(1)
	line:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
	line:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)

	if section then
		local label = "Reset " .. Title(section)
		local b = CreateFrame("Button", nil, row)
		b:SetHeight(14)
		b:SetWidth(76)
		b:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 2)
		local t = Text(b, "GameFontDisableSmall", "RIGHT")
		t:SetPoint("RIGHT")
		t:SetText(label)
		b:SetFontString(t)
		b:SetText(label)
		b:SetScript("OnClick", function() Run("reset " .. section) end)
		local hi = Fill(b, { 1, 1, 1, 0.10 }, "HIGHLIGHT")
		hi:SetAllPoints(b)
		b:SetHighlightTexture(hi)
		Teach(b, label, "/comfy reset " .. section,
			"Put just this section back to its defaults. Nothing else moves.")
		row.reset = b
	end
	return row
end

--------------------------------------------------------------------------------
-- Layout
--------------------------------------------------------------------------------

-- Rows are stacked top-down and the window is sized to whatever is visible, so
-- hiding the time-of-day controls when the feature is off shrinks the window
-- instead of leaving a hole in it.
local function Relayout()
	local y = -TOP_INSET
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

-- Which of the game's own volume sliders each channel rides on, and the switch
-- above it where there is one. Verified against WowB.exe 1.60.1.70425: all nine
-- names below are in the binary, and an invented one is not.
--
-- This exists because of the single likeliest launch complaint. The addon can
-- play into any channel but it cannot make an audible sound on a slider the
-- player has already pulled to zero, and Ambience at zero is a common setting -
-- the beta's own config had Master at 0.1 and Music at 0. Without this the
-- panel shows a Volume slider, a Sound toggle that says On, and no sound, and
-- there is nothing on screen that explains it. That is what the Channel button
-- is for, and until now it never said so.
local CHANNEL_CVAR = {
	Ambience = { "Sound_EnableAmbience", "Sound_AmbienceVolume" },
	SFX      = { "Sound_EnableSFX",      "Sound_SFXVolume" },
	Music    = { "Sound_EnableMusic",    "Sound_MusicVolume" },
	Master   = { nil,                    "Sound_MasterVolume" },
	Dialog   = { nil,                    "Sound_DialogVolume" },
}

local function CVarNum(name)
	local get = (C_CVar and C_CVar.GetCVar) or GetCVar
	if type(get) ~= "function" then return nil end
	local ok, v = pcall(get, name)
	if not ok then return nil end
	return tonumber(v)
end

-- False where the answer is "cannot tell". A CVar name that moved in some
-- future flavour would otherwise put a red line on a panel whose sound is
-- working perfectly, and a warning that cries wolf is worse than none.
local function ChannelMuted(name)
	if CVarNum("Sound_EnableAllSound") == 0 then return true end
	local master = CVarNum("Sound_MasterVolume")
	if master and master <= 0 then return true end
	local pair = CHANNEL_CVAR[name]
	if not pair then return false end
	if pair[1] and CVarNum(pair[1]) == 0 then return true end
	local v = CVarNum(pair[2])
	return (v ~= nil and v <= 0) and true or false
end
-- Title Case nouns throughout, which is how the client labels its own options.
-- The sentence that used to be the label is now the tooltip's first line, so
-- nothing was lost: the panel scans, and the explanation is one hover away.
local TIME_MODES = {
	{ key = "off",    label = "Off",      cmd = "time off",
	  note = "Leave the realm's own day and night alone." },
	{ key = "local",  label = "My Clock", cmd = "time local",
	  note = "Light the world by your clock instead of the realm's." },
	{ key = "offset", label = "Shifted",  cmd = "time +9",
	  note = "Move the realm's clock by a set number of hours." },
	{ key = "fixed",  label = "Held",     cmd = "time 21",
	  note = "Hold one hour, all session. Permanent dusk." },
}

-- What is still changing the screen, in one sentence.
--
-- This exists because of a real report: "my screen is too dark and i cant reset
-- it easily, like i want to turn off the changes it made but i cant". The time
-- of day grading is the one ComfyRain effect with no weather attached to it, so
-- a player who turns the weather off and still has a dark world has no way to
-- connect the two. Naming the held hour, in the window, every refresh, is what
-- turns an unexplained dark screen into a setting with an off switch next to it.
local function LightPhrase(db)
	if db.timeMode == "off" then return nil end
	if db.timeMode == "local" then return "light on your own clock" end
	if db.timeMode == "offset" then
		return string.format("light shifted %+g h", db.timeOffset)
	end
	return string.format("light held at %02d:00", db.timeFixed)
end

local function StatusPhrase(db)
	local light = LightPhrase(db)
	local weather = db.enabled and (db.intensity .. " " .. db.weather) or nil
	if weather and light then
		return "Drawing " .. weather .. ", " .. light .. ".", GOLD
	elseif weather then
		return "Drawing " .. weather .. ".", GOLD
	elseif light then
		-- The dangerous state, and the one that generated the report: the
		-- weather is off, so the player believes the addon is off, and the
		-- world is still being graded.
		return "Weather off, but " .. light .. ".", GOLD
	end
	return "Everything off. Nothing here is touching your screen.", DIM
end

local function Refresh()
	if not panel or not panel:IsShown() then return end
	local db = DB()
	if not db then return end
	updating = true

	local weather = ComfyRainAPI.Weather[db.weather] or ComfyRainAPI.Weather.rain

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
		Teach(pill, "Intensity", name and ("/comfy " .. name) or nil)
	end

	controls.alpha:Set(db.scale)
	controls.speed:Set(db.speed)
	controls.dim:Set(db.gloom)
	controls.gust:Set(db.gust)
	controls.volume:Set(db.volume)

	controls.sound:SetOn(db.sound)
	controls.zoom:SetOn(db.zoom)
	-- Rain has lightning, snow has gusts, and the button must say which. The
	-- icon changes with the word, and SetIcon re-applies the on/off state, so
	-- it is the last of the three to run.
	controls.thunder:SetOn(db.thunder)
	controls.thunder:SetLabel(weather.flash and "Thunder" or "Gusts")
	controls.thunder:SetIcon(weather.flash and ICON.thunder or ICON.gusts)
	controls.indoors:SetLabel("Indoors: " .. Title(INDOORS(db)))

	-- The one place the panel can tell a player why an addon they have switched
	-- on is making no noise. Said on the face of the button rather than only in
	-- the tooltip, because nobody hovers a control they have no reason to
	-- suspect, and clicking it is also the fix.
	local muted = db.sound and ChannelMuted(db.channel)
	controls.channel:SetLabel("Channel: " .. db.channel .. (muted and "  (muted)" or ""))
	controls.channel.tipWarn = muted and ("The game's own " .. db.channel ..
		" volume is at zero, so nothing here can be heard. Click to move the " ..
		"weather onto a different slider, or turn that one up in the game's " ..
		"Sound options.") or nil

	for _, pill in ipairs(controls.timeMode.pills) do
		pill:SetSelected(pill.mode == db.timeMode)
	end
	-- One row, two settings, so the tooltip has to move with the label. It was
	-- the only control in the window without one.
	if db.timeMode == "offset" then
		controls.hour.label:SetText("Shift by Hours")
		controls.hour:Set(db.timeOffset)
		controls.hour.slider.tipTitle = "Shift by Hours"
		controls.hour.slider.tipNote =
			"Move the light forward or back from the realm's own clock."
		controls.hour.slider.command = "/comfy time +9"
	elseif db.timeMode == "fixed" then
		controls.hour.label:SetText("Hold at Hour")
		controls.hour:Set(db.timeFixed)
		controls.hour.slider.tipTitle = "Hold at Hour"
		controls.hour.slider.tipNote =
			"Hold the light at one hour of the day and leave it there."
		controls.hour.slider.command = "/comfy time 21"
	end
	controls.strength:Set(db.timeStrength)

	local phrase, colour = StatusPhrase(db)
	controls.status:SetText(phrase)
	controls.status:SetTextColor(colour[1], colour[2], colour[3])
	-- Hidden when there is nothing left to stop, so the button is never a lie:
	-- if it is on screen, pressing it changes something.
	if db.enabled or db.timeMode ~= "off" then
		controls.stop:Show()
	else
		controls.stop:Hide()
	end

	updating = false
	Relayout()
end

--------------------------------------------------------------------------------
-- The window
--------------------------------------------------------------------------------

local function Build()
	local db = DB()

	panel = CreateFrame("Frame", "ComfyRainPanel", UIParent,
		SupportsBackdrop() and "BackdropTemplate" or nil)
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

	-- The fill is inset so the nine-sliced gold edge has somewhere to sit; with
	-- no backdrop it covers the whole frame and the hand-drawn border goes back
	-- around the outside of it.
	local bg = Fill(panel, BG)
	local backdrop = panel.SetBackdrop and pcall(panel.SetBackdrop, panel, BORDER_BACKDROP)
	if backdrop then
		bg:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -11)
		bg:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -11, 10)
	else
		bg:SetAllPoints(panel)
		Border(panel, EDGE)
	end

	-- The client's own dark dialog stone, tiled over the flat fill rather than
	-- replacing it. Over, because a path this build does not have draws nothing
	-- at all, and the window would go transparent rather than plain. This is the
	-- single change that stops the panel reading as a flat rectangle sitting
	-- inside a gold WoW frame.
	local stone = panel:CreateTexture(nil, "BACKGROUND", nil, 1)
	stone:SetTexture(ART.stone, "REPEAT", "REPEAT")
	stone:SetAllPoints(bg)
	stone:SetAlpha(0.9)

	-- The carved plate the client hangs over the top edge of its own dialogs.
	-- One texture, and the thing most responsible for a frame looking like it
	-- shipped with the game rather than with an addon.
	local header = panel:CreateTexture(nil, "ARTWORK")
	header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
	header:SetSize(230, 64)
	header:SetPoint("TOP", panel, "TOP", 0, 12)

	local title = Text(panel, "GameFontNormal", "CENTER")
	title:SetPoint("TOP", header, "TOP", 0, -15)
	title:SetText("ComfyRain")
	title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])

	-- The client's own round close button if the template is there, and our
	-- own letter if it is not. Neither may be the reason the window fails.
	local close
	local okClose = pcall(function()
		close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
	end)
	if okClose and close then
		close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -5, -5)
	else
		close = CreateFrame("Button", nil, panel)
		close:SetSize(20, 20)
		close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD + 4, -PAD + 4)
		local x = Text(close, "GameFontNormal", "CENTER")
		x:SetPoint("CENTER")
		x:SetText("x")
	end
	close:SetScript("OnClick", function() panel:Hide() end)
	Teach(close, "Close", "/comfyrain")

	controls, rows = {}, {}
	local function add(frame, opts)
		rows[#rows + 1] = { frame = frame, visible = opts and opts.visible,
		                    gap = opts and opts.gap }
		return frame
	end

	-- The state line comes before any control, because the first question
	-- somebody opens this window with is "what is this doing to my screen", and
	-- the answer has to be readable without understanding a single widget below
	-- it. The stop button sits on the same line so the answer and the undo are
	-- never in different parts of the window.
	local state = add(CreateFrame("Frame", nil, panel), { gap = 9 })
	state:SetHeight(ROW)
	local quarter = (WIDTH - PAD * 2) / 4
	controls.status = Text(state, "GameFontHighlightSmall")
	controls.status:SetPoint("LEFT", state, "LEFT", 0, 0)
	controls.status:SetWidth(WIDTH - PAD * 2 - quarter * 1.5 - 8)
	controls.status:SetWordWrap(false)
	controls.status:SetText("")

	controls.stop = Pill(state, "Turn It All Off", function() Run("stop") end)
	controls.stop:SetPoint("TOPRIGHT", state, "TOPRIGHT", 0, 0)
	controls.stop:SetWidth(quarter * 1.5)
	Teach(controls.stop, "Turn It All Off", "/comfy stop",
		"Weather, sound and the light grading, all off in one press. " ..
		"Your settings are kept; this is a switch, not a reset.")

	add(Heading(panel, "Weather", "look"), { gap = 4 })

	-- Weather, and the master switch, on one line: the two things somebody
	-- opening this window for the first time is looking for.
	local top = add(CreateFrame("Frame", nil, panel))
	top:SetHeight(ROW)
	local third = (WIDTH - PAD * 2) / 3
	controls.rain = Pill(top, "Rain", function() Run("rain") end)
	controls.rain:SetPoint("TOPLEFT", top, "TOPLEFT", 0, 0)
	controls.rain:SetWidth(third - 3)
	controls.rain:SetIcon(ICON.rain)
	Teach(controls.rain, "Rain", "/comfy rain")

	controls.snow = Pill(top, "Snow", function() Run("snow") end)
	controls.snow:SetPoint("TOPLEFT", top, "TOPLEFT", third, 0)
	controls.snow:SetWidth(third - 3)
	controls.snow:SetIcon(ICON.snow)
	Teach(controls.snow, "Snow", "/comfy snow")

	controls.power = Toggle(top, "Weather on", "/comfy", function()
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

	-- The db key and the command verb differ for two of these - Visibility
	-- writes `scale` through `alpha`, Darkness writes `gloom` through `dim` -
	-- which is exactly why the default is looked up by key rather than assumed
	-- to match the slider's name.
	local function Back(key, verb, fmt)
		return function()
			local d = Defaults()[key]
			if d == nil then return end
			return d, string.format(verb .. " " .. (fmt or "%.2f"), d)
		end
	end

	controls.alpha = add(Slider(panel, "Visibility", 0, 1.5, 0.05, "%.2f",
		function(v) Run(string.format("alpha %.2f", v)) end,
		Back("scale", "alpha")))
	Teach(controls.alpha.slider, "Visibility", "/comfy alpha 0.75",
		"How much weather you see through.")

	controls.speed = add(Slider(panel, "Fall Speed", 0.2, 3, 0.05, "%.2f",
		function(v) Run(string.format("speed %.2f", v)) end,
		Back("speed", "speed")))
	Teach(controls.speed.slider, "Fall Speed", "/comfy speed 1.4",
		"How fast it comes down.")

	controls.dim = add(Slider(panel, "Darkness", 0, 2, 0.05, "%.2f",
		function(v) Run(string.format("dim %.2f", v)) end,
		Back("gloom", "dim")))
	Teach(controls.dim.slider, "Darkness", "/comfy dim 0.5",
		"How much the storm dims the world. 0 leaves the light alone.")

	controls.gust = add(Slider(panel, "Wind", 0, 2, 0.05, "%.2f",
		function(v) Run(string.format("gust %.2f", v)) end,
		Back("gust", "gust")))
	Teach(controls.gust.slider, "Wind", "/comfy gust 0.5",
		"How hard it gusts. 0 is dead calm: one fixed rate, no wind.")

	-- Camera distance is the only part of the world camera an addon can read,
	-- and it is a judgement call rather than a correctness fix, so it gets a
	-- switch. Full width: it has no natural partner on a row.
	local zoomRow = add(CreateFrame("Frame", nil, panel))
	zoomRow:SetHeight(ROW)
	controls.zoom = Toggle(zoomRow, "Zoom Response", "/comfy zoom off",
		function() Run(DB().zoom and "zoom off" or "zoom on") end)
	controls.zoom:SetPoint("TOPLEFT", zoomRow, "TOPLEFT", 0, 0)
	controls.zoom:SetWidth(third - 3)
	Teach(controls.zoom, "Zoom Response", "/comfy zoom off",
		"Drops get bigger and faster the closer the camera is, finer and " ..
		"denser when you pull back.")

	add(Heading(panel, "Sound", "sound"), { gap = 4 })

	controls.volume = add(Slider(panel, "Volume", 0, 1, 0.05, "%.2f",
		function(v) Run(string.format("volume %.2f", v)) end,
		Back("volume", "volume")))
	Teach(controls.volume.slider, "Volume", "/comfy volume 0.5",
		"ComfyRain's weather only. Your game volume is untouched.")

	local audio = add(CreateFrame("Frame", nil, panel))
	audio:SetHeight(ROW)
	controls.sound = Toggle(audio, "Sound", "/comfy sound off",
		function() Run(DB().sound and "sound off" or "sound on") end)
	controls.sound:SetPoint("TOPLEFT", audio, "TOPLEFT", 0, 0)
	controls.sound:SetWidth(third - 3)

	controls.thunder = Toggle(audio, "Thunder", "/comfy thunder off",
		function() Run(DB().thunder and "thunder off" or "thunder on") end)
	controls.thunder:SetPoint("TOPLEFT", audio, "TOPLEFT", third, 0)
	controls.thunder:SetWidth(third - 3)

	-- Three states, so a cycling pill rather than a lamp. "Dim" is the default
	-- and the one most people want: weather you can still HEAR from inside but
	-- cannot see, instead of either silence or rain falling through the roof.
	controls.indoors = Pill(audio, "Indoors: Dim", function()
		local order = { off = "dim", dim = "on", on = "off" }
		Run("indoors " .. (order[INDOORS(DB())] or "dim"))
	end)
	controls.indoors:SetPoint("TOPLEFT", audio, "TOPLEFT", third * 2, 0)
	controls.indoors:SetWidth(third)
	Teach(controls.indoors, "Indoors", "/comfy indoors dim",
		"Off stops it dead. Dim keeps the sound and draws nothing, the way " ..
		"weather is from inside. On draws it at full strength.")

	-- A cycling button rather than a dropdown: UIDropDownMenu is a template,
	-- and five options do not need a menu.
	controls.channel = add(Pill(panel, "Channel: Ambience", function()
		local db2, at = DB(), 1
		for i, c in ipairs(CHANNELS) do if c == db2.channel then at = i end end
		Run("channel " .. CHANNELS[(at % #CHANNELS) + 1]:lower())
	end))
	Teach(controls.channel, "Channel", "/comfy channel Ambience",
		"Which of the game's volume sliders owns the weather. Ambience keeps " ..
		"it out of the way of music.")

	add(Heading(panel, "Time of Day", "time"), { gap = 4 })

	controls.timeMode = add(PillRow(panel, 4))
	for i, pill in ipairs(controls.timeMode.pills) do
		local mode = TIME_MODES[i]
		pill.mode = mode.key
		pill:SetLabel(mode.label)
		pill:SetScript("OnClick", function() Run(mode.cmd) end)
		Teach(pill, mode.label, "/comfy " .. mode.cmd, mode.note)
	end

	controls.hour = add(Slider(panel, "Hour", -12, 23, 1, "%d", function(v)
		if DB().timeMode == "offset" then
			Run(string.format("time %+d", v))
		else
			Run(string.format("time %d", v))
		end
	end,
	-- The only slider whose default moves. One control is shown for two
	-- settings - an offset from realm time, and an absolute hour to hold at -
	-- so "the default" is 0 in one mode and 21 in the other, and a fixed
	-- number here would grey out the wrong one half the time.
	function()
		local d = Defaults()
		if DB() and DB().timeMode == "offset" then
			return d.timeOffset, string.format("time %+d", d.timeOffset or 0)
		end
		return d.timeFixed, string.format("time %d", d.timeFixed or 21)
	end), { visible = function()
		local m = DB().timeMode
		return m == "offset" or m == "fixed"
	end })
	-- Title, note and command are all replaced by Refresh, which knows which of
	-- the two settings this row is currently standing in for.
	Teach(controls.hour.slider, "Hour", "/comfy time +9",
		"Move the light away from the realm's own clock.")

	controls.strength = add(Slider(panel, "Strength", 0, 1, 0.05, "%.2f",
		function(v) Run(string.format("time strength %.2f", v)) end,
		Back("timeStrength", "time strength")),
		{ visible = function() return DB().timeMode ~= "off" end })
	Teach(controls.strength.slider, "Strength", "/comfy time strength 0.7",
		"How far towards that hour to grade the light.")

	local foot = add(CreateFrame("Frame", nil, panel))
	foot:SetHeight(ROW)
	local commands = Pill(foot, "Commands", function() Run("help") end)
	commands:SetPoint("TOPLEFT", foot, "TOPLEFT", 0, 0)
	commands:SetWidth(third - 3)
	Teach(commands, "Commands", "/comfy help", "Print every command to chat.")

	-- Share is one button for both directions. Sending somebody your weather and
	-- pasting theirs are the same box with the text selected or empty, and two
	-- buttons for one box is how a 330px window stops being readable.
	local share = Pill(foot, "Share", function() Run("share") end)
	share:SetPoint("TOPLEFT", foot, "TOPLEFT", third, 0)
	share:SetWidth(third - 3)
	Teach(share, "Share", "/comfy share",
		"A short line of text holding every setting. Send it to someone, or " ..
		"paste theirs in to use it.")

	local reset = Pill(foot, "Reset All", function() Run("reset") end)
	reset:SetPoint("TOPLEFT", foot, "TOPLEFT", third * 2, 0)
	reset:SetWidth(third)
	Teach(reset, "Reset All", "/comfy reset",
		"Every section back to defaults. Settings only; the calibration log " ..
		"is kept.")

	local hint = add(CreateFrame("Frame", nil, panel), { gap = 2 })
	hint:SetHeight(14)
	local hintText = Text(hint, "GameFontDisableSmall")
	hintText:SetPoint("TOPLEFT", hint, "TOPLEFT", 0, 0)
	hintText:SetText("Hover anything to see its slash command.")

	-- About rides on the hint line rather than taking a fourth pill. The footer
	-- holds three already, a 330px row does not take a fourth without the
	-- labels truncating, and this is the least-pressed button in the window:
	-- small type on the right of a line that was empty anyway is the correct
	-- amount of room to give it.
	local about = CreateFrame("Button", nil, hint)
	about:SetSize(46, 14)
	about:SetPoint("TOPRIGHT", hint, "TOPRIGHT", 0, 0)
	local aboutText = Text(about, "GameFontDisableSmall", "RIGHT")
	aboutText:SetPoint("RIGHT")
	about:SetFontString(aboutText)
	about:SetText("About")
	local aboutHi = Fill(about, { 1, 1, 1, 0.10 }, "HIGHLIGHT")
	aboutHi:SetAllPoints(about)
	about:SetHighlightTexture(aboutHi)
	about:SetScript("OnClick", function() Run("about") end)
	Teach(about, "About", "/comfy about",
		"Version, licence, and the GitHub page for bugs and requests. The " ..
		"link opens in a box you can copy out of.")

	-- Escape closes it, which is a list of frame names and therefore the reason
	-- this frame has one.
	tinsert(UISpecialFrames, "ComfyRainPanel")

	if db and db.ui and db.ui.point then
		panel:ClearAllPoints()
		panel:SetPoint(db.ui.point, UIParent, db.ui.rel or db.ui.point,
			db.ui.x or 0, db.ui.y or 0)
	else
		panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	end

end

function ComfyRain_Panel(mode)
	if not ComfyRainAPI or not ComfyRainAPI.DB() then return end
	if not panel then Build() end

	if mode == "hide" or (mode ~= "show" and panel:IsShown()) then
		panel:Hide()
		return
	end
	panel:Show()
	Refresh()
end

--------------------------------------------------------------------------------
-- The share box
--
-- An EditBox is the only route a string has out of an addon and into the
-- clipboard: there is no SetClipboard in the client's Lua. So sharing is a box
-- with the text already in it and already selected, and the one thing that
-- would make it useless is making the player drag across the text first.
--
-- The same box reads as well as writes. Export arrives with text, selected;
-- import arrives empty, focused, and Enter applies whatever is in it. Two
-- buttons for one box is how a 330px window stops being readable.
--------------------------------------------------------------------------------

local shareBox

local function BuildShare()
	local f = CreateFrame("Frame", "ComfyRainShare", UIParent,
		SupportsBackdrop() and "BackdropTemplate" or nil)
	f:SetWidth(WIDTH)
	f:SetHeight(104)
	f:SetFrameStrata("FULLSCREEN_DIALOG")
	f:SetToplevel(true)
	f:EnableMouse(true)
	f:SetMovable(true)
	f:SetClampedToScreen(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function(self) self:StartMoving() end)
	f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
	f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	f:Hide()

	local bg = Fill(f, BG)
	if f.SetBackdrop and pcall(f.SetBackdrop, f, BORDER_BACKDROP) then
		bg:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -11)
		bg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -11, 10)
	else
		bg:SetAllPoints(f)
		Border(f, EDGE)
	end

	local title = Text(f, "GameFontNormalSmall")
	title:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + 4, -PAD - 2)
	title:SetText("Share a Profile")
	title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])

	f.note = Text(f, "GameFontDisableSmall")
	f.note:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + 4, -PAD - 18)
	f.note:SetWidth(WIDTH - PAD * 2 - 8)

	local well = CreateFrame("Frame", nil, f)
	well:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + 4, -PAD - 34)
	well:SetWidth(WIDTH - PAD * 2 - 8)
	well:SetHeight(26)
	local wellBG = Fill(well, { 0.10, 0.11, 0.14, 1 })
	wellBG:SetAllPoints(well)
	Border(well, EDGE)

	f.edit = CreateFrame("EditBox", nil, well)
	f.edit:SetPoint("TOPLEFT", well, "TOPLEFT", 6, -4)
	f.edit:SetPoint("BOTTOMRIGHT", well, "BOTTOMRIGHT", -6, 4)
	f.edit:SetAutoFocus(false)
	f.edit:SetMultiLine(false)
	-- ChatFontNormal rather than a font path: an EditBox with no font object
	-- draws no characters at all, and a hardcoded path is the kind of thing
	-- that breaks on a client we have not seen.
	f.edit:SetFontObject(ChatFontNormal or "ChatFontNormal")
	f.edit:SetTextInsets(0, 0, 0, 0)
	f.edit:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
		f:Hide()
	end)
	f.edit:SetScript("OnEnterPressed", function(self)
		-- Enter applies whatever is in the box, including the string we just
		-- put there. Re-importing your own profile is a no-op, so one key does
		-- the sensible thing in both directions and there is nothing to learn.
		Run("import " .. (self:GetText() or ""))
		self:ClearFocus()
		f:Hide()
	end)

	local close = Pill(f, "Close", function() f:Hide() end)
	close:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD - 4, PAD)
	close:SetWidth(80)
	Teach(close, "Close", nil, "Escape closes it too.")

	tinsert(UISpecialFrames, "ComfyRainShare")
	shareBox = f
end

-- text = the profile to hand out, or nil to open the box empty for a paste.
-- note overrides the default caption. /comfy about reuses this box for the
-- project URL, and telling somebody that a GitHub link can be "pasted back" to
-- another ComfyRain user would be nonsense.
local function ShowShare(text, note)
	if not shareBox then BuildShare() end
	shareBox.edit:SetText(text or "")
	shareBox.note:SetText(note or (text
		and "Ctrl-C copies it. Anyone running ComfyRain can paste it back."
		or "Paste a profile here and press Enter."))
	shareBox:Show()
	shareBox.edit:SetFocus()
	-- Selected on open: the whole point is that copying it costs one keystroke
	-- rather than a drag across a 200-character line.
	if text then shareBox.edit:HighlightText() end
	return true
end

--------------------------------------------------------------------------------
-- Minimap button
--------------------------------------------------------------------------------

-- Hand-rolled rather than LibDBIcon. The library is the right answer in a repo
-- that already embeds Ace; pulling in an embed chain for one draggable circle
-- is not. Position is one number - the angle around the minimap - which is all
-- LibDBIcon persists either.
local minimap

--------------------------------------------------------------------------------
-- The icon
--------------------------------------------------------------------------------
--
-- Drawn, not borrowed. Every stock spell icon that is nearly right is also the
-- icon of a spell three other addons already use, and Spell_Frost_IceStorm -
-- what this was - is a generic blue swirl that says nothing about weather.
--
-- So: a dusk sky behind falling weather, built from colour quads, which is the
-- same toolkit the overlay itself is drawn with and needs no art file in the
-- package. It shows the CURRENT weather, which no stock icon can do: blue-grey
-- streaks for rain, pale dots for snow, and the whole thing greyed out when the
-- weather is off, so the button answers "is it on, and what is it" at a glance.
--
-- Two optional APIs, both guarded, both degrading to something still worth
-- looking at: SetMask rounds the sky off inside the brass ring (without it, a
-- square of sky, which the ring mostly covers anyway) and SetRotation slants
-- the rain (without it, the streaks fall straight down).
local ROUND_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local ICON_SIZE = 20
local STREAKS = {
	-- x, y, length: scattered by hand rather than randomly, because a random
	-- scatter clumps and this is twenty pixels across.
	{ -6,  3, 7 }, { -2, -2, 5 }, {  1,  4, 6 },
	{  5, -1, 7 }, { -4, -5, 5 }, {  6,  5, 5 },
}

local icon = {}

local function BuildIcon(button)
	local sky = button:CreateTexture(nil, "BACKGROUND")
	sky:SetSize(ICON_SIZE, ICON_SIZE)
	sky:SetPoint("CENTER", -1, 1)
	sky:SetColorTexture(1, 1, 1, 1)
	pcall(sky.SetMask, sky, ROUND_MASK)
	icon.sky = sky

	icon.drops = {}
	for i, s in ipairs(STREAKS) do
		local t = button:CreateTexture(nil, "ARTWORK")
		t:SetPoint("CENTER", sky, "CENTER", s[1], s[2])
		t.length = s[3]
		pcall(t.SetMask, t, ROUND_MASK)
		icon.drops[i] = t
	end
	icon.button = button
end

-- Repainted whenever the weather changes, which is why it is not just set once
-- at build time. Cheap: eight SetColorTexture calls on a frame nobody redraws.
local function PaintIcon()
	if not icon.sky then return end
	local db = ComfyRainAPI and ComfyRainAPI.DB()
	if not db then return end
	local snow = db.weather == "snow"
	local lit = db.enabled

	-- Dusk, which is the name of the addon: deep blue above a last band of
	-- light at the horizon. Flat colour if the client will not do a gradient.
	local function colour(r, g, b, a)
		if CreateColor then return CreateColor(r, g, b, a) end
		return { r = r, g = g, b = b, a = a,
		         GetRGBA = function(s) return s.r, s.g, s.b, s.a end }
	end
	if lit then
		icon.sky:SetColorTexture(0.09, 0.12, 0.21, 1)
		pcall(icon.sky.SetGradient, icon.sky, "VERTICAL",
			colour(0.40, 0.31, 0.33, 1), colour(0.07, 0.10, 0.20, 1))
	else
		icon.sky:SetColorTexture(0.14, 0.14, 0.15, 1)
		pcall(icon.sky.SetGradient, icon.sky, "VERTICAL",
			colour(0.22, 0.22, 0.23, 1), colour(0.11, 0.11, 0.12, 1))
	end

	for _, t in ipairs(icon.drops) do
		if snow then
			-- A flake is a dot, and it does not slant.
			t:SetSize(2, 2)
			pcall(t.SetRotation, t, 0)
		else
			t:SetSize(1.4, t.length)
			-- The same 7.5 degrees the rain sheets are drawn at.
			pcall(t.SetRotation, t, -0.131)
		end
		if not lit then
			t:SetColorTexture(0.45, 0.45, 0.47, 0.55)
		elseif snow then
			t:SetColorTexture(0.95, 0.97, 1.00, 0.95)
		else
			t:SetColorTexture(0.68, 0.80, 0.98, 0.85)
		end
	end
end

local function MinimapPlace()
	local db = ComfyRainAPI and ComfyRainAPI.DB()
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
	minimap = CreateFrame("Button", "ComfyRainMinimapButton", Minimap)
	minimap:SetSize(31, 31)
	minimap:SetFrameStrata("MEDIUM")
	minimap:SetFrameLevel(Minimap:GetFrameLevel() + 8)

	local border = minimap:CreateTexture(nil, "OVERLAY")
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetSize(53, 53)
	border:SetPoint("TOPLEFT")

	BuildIcon(minimap)
	PaintIcon()
	minimap:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

	minimap:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	minimap:SetScript("OnClick", function(_, button)
		if button == "RightButton" then
			-- The bare command is the weather toggle; "toggle" is not a command.
			ComfyRainAPI.Command("")
		else
			ComfyRain_Panel()
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
		local db = ComfyRainAPI.DB()
		if not mx or not db then return end
		db.minimapAngle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
		MinimapPlace()
	end)

	minimap:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:AddLine("ComfyRain")
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

-- Called by ComfyRain.lua once the DB exists, and again whenever the player
-- toggles the button off and on.
function ComfyRain_Minimap(mode)
	local db = ComfyRainAPI and ComfyRainAPI.DB()
	if not db then return end
	if mode == "toggle" then db.minimap = not db.minimap end
	if db.minimap == false then
		if minimap then minimap:Hide() end
		return
	end
	BuildMinimap()
	if minimap then minimap:Show() MinimapPlace() PaintIcon() end
end

-- One place that answers "something changed". A typed command has to move the
-- window too, or the two disagree in front of the player and the window is the
-- half that stops being trusted; and the minimap icon is a readout of the
-- weather, so it is stale the moment anything else is.
local function Changed()
	Refresh()
	PaintIcon()
end

if ComfyRainAPI then
	ComfyRainAPI.changed = Changed
	-- /comfy share prints the string to chat if this is missing, which is what a
	-- client that failed to load the window gets. A chat line can be read; it
	-- just cannot be copied without dragging.
	ComfyRainAPI.share = ShowShare
end

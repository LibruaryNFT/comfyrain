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

-- Measured off the client's own Options window rather than picked. Its rows
-- are a 12pt label on the left and a control in a right-hand column, with room
-- around both; ours were a 10pt label and a control wherever it fitted, which
-- is what "it doesnt appear exactl like the wow options ... size of fonts etc"
-- was looking at. The window got 30px wider to pay for the bigger type.
local WIDTH    = 360
local PAD      = 16
local ROW      = 26
local GAP      = 8
-- Room at the top for the carved header plate to sit over the frame edge.
local TOP_INSET = 30

-- Gold is WoW's own heading colour and the single cheapest way to make a
-- hand-drawn frame belong to the rest of the interface. The blue is kept, but
-- only for the lamp on a lit toggle and the slider thumb: it is the addon's
-- chat-prefix colour, so it reads as ComfyRain's and not as a second theme.
local GOLD     = { 1.00, 0.82, 0.00 }
local ACCENT   = { 0.50, 0.72, 1.00 }
-- You can see the world through the client's Options window, and that is most
-- of why it reads as part of the game rather than as a box on top of it. This
-- fill plus the stone over it lands at about 85% opaque, which is where
-- Blizzard's sits: enough to read 12pt white text on, not enough to feel like
-- a lid. It was 94% plus stone at 90%, which is 99% - a solid black rectangle.
local BG       = { 0.05, 0.06, 0.09, 0.72 }
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
	-- The client's own checkbox, at the size the client draws it, standing on
	-- the background rather than on a button face. See Check.
	check     = "Interface\\Buttons\\UI-CheckBox-Up",
	checkMark = "Interface\\Buttons\\UI-CheckBox-Check",
	-- The arrows either side of a Select. These two rather than
	-- UI-SquareButton-Up, which is what the modern options window uses: the
	-- square button is FileDataID 796424 and the spellbook arrows are 130866
	-- and 130869, which is to say the arrows have been in the game since 2004
	-- and the square button has not. On a client built from the 1.60 branch
	-- the older pair is the safer bet, and HasArt covers the rest.
	prev = "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up",
	next = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up",
}

-- The one picture left in the window, in the Weather selector. Picked by
-- rendering the candidates at 14px and looking at them, which is the size they
-- are drawn at here, not by reading their names at 64px:
--
--   rain     IceStorm's shards lose their detail on the way down and what is
--            left is slanted streaks, which is exactly what rain looks like.
--   snow     FrostShock keeps a bold white snowflake at 14px. ChillingBlast is
--            the better picture at full size and was the first choice, but it
--            dissolves into a white diagonal slash that is indistinguishable
--            from the rain icon, and telling rain from snow is the one thing
--            this picture has to do.
--
-- Worth recording because it is the kind of thing that gets "fixed" later: no
-- icon anywhere in the game depicts rain. The whole 2.27M-file catalogue was
-- searched, not just the classic range. So rain borrows a shape rather than a
-- subject, and that is deliberate.
--
-- Thunder and Gusts used to carry icons too, on their toggles. The client's
-- own Options window has no icons on anything, and matching it was the whole
-- point of the 2026-10-19 rebuild, so they went.
local ICON = {
	rain    = "Interface\\Icons\\Spell_Frost_IceStorm",
	snow    = "Interface\\Icons\\Spell_Frost_FrostShock",
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

-- GameFontHighlight, not GameFontHighlightSmall. The client labels every row
-- in its own Options window at 12pt and this window was at 10, which is the
-- difference between "an addon window" and "a page of the game's settings".
local function Text(parent, inherits, justify)
	local fs = parent:CreateFontString(nil, "OVERLAY", inherits or "GameFontHighlight")
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

		-- Nothing else. A gold wash was tried here on 2026-10-19 to make the
		-- chosen one of four pills obvious, and the answer from live play was
		-- "the weird tellow is offputting.. why cant we make it like their
		-- options menu". It was the right reading of the wrong problem: a row
		-- of four pills has to shout which one is live, and the client's own
		-- Options window never asks that question of itself, because it shows
		-- one value at a time. Select is that, and it is what the groups became.
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

--------------------------------------------------------------------------------
-- The control column
--------------------------------------------------------------------------------
--
-- Every row in the client's Options window is the same shape: words on the
-- left, the thing you operate in a column on the right, and every control in
-- that column starting at the same x. That alignment is most of what makes a
-- long page of unrelated settings scan as one list. Ours had the checkboxes
-- hard against the left edge and the selectors against the right, which is
-- two columns facing away from each other.
--
-- COL_IN is how far in from the row's RIGHT edge that column starts. Measured
-- from the right rather than the left because the right arrow is flush to the
-- row end, so the whole group is built backwards from there, and because
-- Relayout sets a row's width after it is built - an offset from the left
-- would have to be recomputed every time the window resizes and an offset
-- from the right never does.
local SELECT_W = 130
local ARROW = 20
local CHECK = 24
local COL_IN = ARROW * 2 + 4 + SELECT_W
-- A slider's number sits outside the track, at the far right of the row, the
-- way the client puts 5.5 after Mouse Look Speed.
local VALUE_W = 44

-- A checkbox row, which is the single most common row in the client's own
-- Options window: the words on the left, the box in the control column, and
-- nothing else. No button face. A face is a promise that pressing it does
-- something separate from the box, and on a row where the whole thing is one
-- control that promise is a lie - which is roughly what "the button doesnt
-- look right for zoom response" was describing.
--
-- The box used to sit on the left with the word after it, which is how a
-- checkbox is drawn when it is on its own somewhere. It is not how one is
-- drawn in a settings list, and a list where some rows read left-to-right and
-- the rest read right-to-left has no column at all. Clicking anywhere on the
-- row toggles it, the way the client's own rows work.
local function Check(parent, label, command, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetHeight(ROW)

	-- Asked about with HasArt because a missing box would leave the row saying
	-- nothing at all, which is the one case the whole HasArt rule exists for.
	-- The hand-drawn well and lamp below are what a client without the
	-- checkbox art gets, and are still a box with a light in it rather than a
	-- different idea.
	b.boxed = HasArt(ART.check) and HasArt(ART.checkMark)
	if b.boxed then
		b.box = b:CreateTexture(nil, "ARTWORK")
		b.box:SetTexture(ART.check)
		b.box:SetSize(CHECK, CHECK)
		b.box:SetPoint("LEFT", b, "RIGHT", -COL_IN, 0)
		b.tick = b:CreateTexture(nil, "OVERLAY")
		b.tick:SetTexture(ART.checkMark)
		b.tick:SetSize(CHECK, CHECK)
		b.tick:SetPoint("CENTER", b.box, "CENTER")
	else
		b.well = Fill(b, { 0, 0, 0, 0.45 }, "ARTWORK")
		b.well:SetSize(16, 16)
		b.well:SetPoint("LEFT", b, "RIGHT", -COL_IN + 4, 0)
		b.lamp = Fill(b, ACCENT, "OVERLAY")
		b.lamp:SetSize(9, 9)
		b.lamp:SetPoint("CENTER", b.well, "CENTER")
	end

	b.label = Text(b, nil, "LEFT")
	b.label:SetPoint("LEFT", b, "LEFT", 0, 0)
	b.label:SetWordWrap(false)
	b:SetFontString(b.label)

	-- The whole row lights up, because the whole row is the control now. That
	-- is also what the client does: hovering a settings row highlights the row,
	-- not the twenty pixels of box at the end of it.
	local hi = Fill(b, { 1, 1, 1, 0.08 }, "HIGHLIGHT")
	hi:SetAllPoints(b)
	b:SetHighlightTexture(hi)
	b.highlight = hi

	-- The label is given the room left over beside the column and told not to
	-- wrap, so a long one is cut off before the box rather than pushing a
	-- second line into the row below it. Same rule as Select.
	b:SetScript("OnSizeChanged", function(self, w)
		self.label:SetWidth(math.max(10, (w or WIDTH) - COL_IN - 6))
	end)

	function b:SetLabel(text)
		self.label:SetText(text)
		self:SetText(text)
	end
	b:SetLabel(label)

	function b:SetOn(on)
		if self.tick then
			if on then self.tick:Show() else self.tick:Hide() end
		elseif self.lamp then
			if on then self.lamp:Show() else self.lamp:Hide() end
		end
		-- White when it is doing something, grey when it is not. The same step
		-- the client uses, and the only state colour left in the window.
		if on then
			self.label:SetTextColor(1, 1, 1)
		else
			self.label:SetTextColor(DIM[1], DIM[2], DIM[3])
		end
		self.on = on and true or false
	end
	b:SetOn(false)

	b:SetScript("OnClick", onClick)
	Teach(b, label, command)
	return b
end

-- One choice, shown one value at a time: a label on the left, and on the right
-- an arrow, the current value in a sunken well, and another arrow. This is the
-- row the client's own Options window uses for Loot Key, and it replaced five
-- separate grids of pills on 2026-10-19.
--
-- The pills were not ugly, they were unanswerable. Four of them side by side
-- have to say which one is live using nothing but a difference in how the same
-- button is drawn, and every difference tried was reported as unreadable:
-- first the two-pixel pressed bevel ("i cant tell if its on or off"), then a
-- gold wash ("the weird tellow is offputting"). A selector never has to say
-- it. There is one value on the row and it is the value.
--
-- It also costs four rows of height across the window and makes every group
-- the same shape, which is the other half of "why cant we make it like their
-- options menu". SELECT_W, ARROW and the column they sit in are up with CHECK.
local function Arrow(row, dir, onStep)
	local b = CreateFrame("Button", nil, row)
	b:SetSize(ARROW, ARROW)
	local path = dir < 0 and ART.prev or ART.next
	if HasArt(path) then
		local t = b:CreateTexture(nil, "ARTWORK")
		t:SetTexture(path)
		t:SetAllPoints(b)
		b.art = t
	else
		-- A client without the spellbook art still gets something to press.
		local t = Text(b, "GameFontNormal", "CENTER")
		t:SetPoint("CENTER")
		b:SetFontString(t)
		b:SetText(dir < 0 and "<" or ">")
	end
	local hi = Fill(b, { 1, 1, 1, 0.16 }, "HIGHLIGHT")
	hi:SetAllPoints(b)
	b:SetHighlightTexture(hi)
	b:SetScript("OnClick", function() onStep(dir) end)

	-- The arrows borrow the well's tooltip rather than keeping their own. Only
	-- the well is re-Taught on every refresh - the value and therefore the
	-- command it teaches change with the setting - and three copies of a
	-- moving target is three chances for two of them to go stale.
	b:SetScript("OnEnter", function(self)
		local enter = row.well:GetScript("OnEnter")
		if enter then enter(row.well) end
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return b
end

local function Select(parent, label, onStep)
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(ROW)

	row.label = Text(row)
	row.label:SetPoint("LEFT", row, "LEFT", 0, 0)
	row.label:SetText(label)

	-- The value sits in a sunken well, not on a button face: the things to
	-- press are either side of it. It is clickable anyway, stepping forward,
	-- because a player who has worked out that this row cycles will click the
	-- middle of it first.
	local well = CreateFrame("Button", nil, row)
	well:SetSize(SELECT_W, ROW - 4)
	well:SetPoint("RIGHT", row, "RIGHT", -(ARROW + 2), 0)
	local bg = Fill(well, { 0, 0, 0, 0.45 })
	bg:SetAllPoints(well)
	Border(well, { 1, 1, 1, 0.13 })
	local wellHi = Fill(well, { 1, 1, 1, 0.08 }, "HIGHLIGHT")
	wellHi:SetAllPoints(well)
	well:SetHighlightTexture(wellHi)
	well:SetScript("OnClick", function() onStep(1) end)
	row.well = well

	row.value = Text(well, nil, "CENTER")
	well:SetFontString(row.value)

	row.icon = well:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(16, 16)
	row.icon:SetPoint("LEFT", well, "LEFT", 5, 0)
	row.icon:Hide()

	row.left  = Arrow(row, -1, onStep)
	row.left:SetPoint("RIGHT", well, "LEFT", -2, 0)
	row.right = Arrow(row, 1, onStep)
	row.right:SetPoint("LEFT", well, "RIGHT", 2, 0)

	-- The label is given exactly the room left over, and told not to wrap, so a
	-- long one is cut off at the arrow rather than pushing a second line into
	-- the row below it.
	row:SetScript("OnSizeChanged", function(self, w)
		self.label:SetWidth(math.max(10, (w or WIDTH) - COL_IN - 6))
	end)
	row.label:SetWordWrap(false)

	-- icon is a path or nil. Passing one shifts the word right to make room,
	-- which is the only layout this widget has two of.
	function row:SetValue(text, icon)
		self.value:SetText(text or "")
		self.well:SetText(text or "")
		self.value:ClearAllPoints()
		if icon and HasArt(icon) then
			self.icon:SetTexture(icon)
			self.icon:Show()
			self.value:SetPoint("LEFT", self.icon, "RIGHT", 4, 0)
			self.value:SetPoint("RIGHT", self.well, "RIGHT", -5, 0)
		else
			self.icon:Hide()
			self.value:SetPoint("CENTER", self.well, "CENTER", 0, 0)
		end
	end
	row:SetValue("")

	return row
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
	row:SetHeight(ROW)

	row.label = Text(row)
	row.label:SetPoint("LEFT", row, "LEFT", 0, 0)
	row.label:SetText(label)
	row.label:SetWordWrap(false)

	row.value = CreateFrame("Button", nil, row)
	row.value:SetSize(VALUE_W, 16)
	row.value:SetPoint("RIGHT", row, "RIGHT", 0, 0)
	row.valueText = Text(row.value, "GameFontNormal", "RIGHT")
	row.valueText:SetPoint("RIGHT")
	-- Without this the button's own SetText has nothing to draw into, the same
	-- reason Pill does it.
	row.value:SetFontString(row.valueText)

	local s = CreateFrame("Slider", nil, row,
		SupportsBackdrop() and "BackdropTemplate" or nil)
	s:SetOrientation("HORIZONTAL")
	-- In the column with everything else, and on the same line as its label,
	-- which is how the client draws Mouse Look Speed. The track used to be a
	-- second line running the full width of the window: easier to aim at, and
	-- 16px of height per slider, which over seven sliders is 112px of window
	-- - the difference between a panel that fits on the screen and one that
	-- does not. It also made the sliders the one row shape in here that was
	-- not the client's.
	s:SetPoint("RIGHT", row.value, "LEFT", -6, 0)
	s:SetWidth(COL_IN - VALUE_W - 6)
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

	-- Cut off before the track rather than wrapping under it, same as Select.
	row:SetScript("OnSizeChanged", function(self, w)
		self.label:SetWidth(math.max(10, (w or WIDTH) - COL_IN - 6))
	end)

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
		-- White when it has been moved off its default, grey when it is sitting
		-- on it. This was gold, and gold is what five slider numbers and a row
		-- of pills all being gold at once looked like: "the weird tellow is
		-- offputting". The affordance is the brightness step, not the hue, and
		-- the client's own options numbers are white.
		local at = default and math.abs(shown - default) < (step / 2)
		if at then
			row.valueText:SetTextColor(DIM[1], DIM[2], DIM[3])
		else
			row.valueText:SetTextColor(1, 1, 1)
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
	row:SetHeight(24)
	-- Large, the way "Controls" and "Mouse" are drawn on the client's own
	-- page. A heading set one point above its rows is a label; a heading set
	-- four points above them is what makes a list of settings into sections
	-- you can find your way around without reading.
	local fs = Text(row, "GameFontNormalLarge")
	fs:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 3)
	fs:SetText(label)
	fs:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
	local line = Fill(row, { 1, 1, 1, 0.08 }, "ARTWORK")
	line:SetHeight(1)
	line:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
	line:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)

	if section then
		local label = "Reset " .. Title(section)
		local b = CreateFrame("Button", nil, row)
		b:SetHeight(16)
		b:SetWidth(90)
		b:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 4)
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

-- The order the Weather and Indoors selectors step through. Intensity has no
-- list here because its one is the weather's own `order`, which is the whole
-- reason the top step can be called monsoon under rain and blizzard under snow.
local WEATHERS = { "rain", "snow" }
local INDOOR_ORDER = { "off", "dim", "on" }

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

-- The weather half of the sentence, which is not the same question as "is the
-- weather switched on".
--
-- Reported 2026-10-19: "we reload and hear rain but dont see anything". Under
-- a roof the engine counts as indoors - and that includes awnings, cave
-- mouths and most doorways - "dim" means heard and not seen, and the window
-- went on saying "Drawing normal rain." the whole time. The setting was on,
-- so the old sentence was true about the setting and a lie about the screen,
-- which is the only thing the player was looking at.
local function WeatherPhrase(db)
	if not db.enabled then return nil end
	local full = db.intensity .. " " .. db.weather
	local st = (ComfyRainAPI and ComfyRainAPI.State and ComfyRainAPI.State()) or {}
	-- No State() means an addon older than this window; drawing is the honest
	-- assumption there, because that is what every build before today did.
	if st.drawing == false then
		if st.cinematic then return "Paused for the cutscene" end
		if st.indoors then
			return st.hearing
				and "Indoors: " .. db.weather .. " heard, not drawn"
				or  "Indoors: nothing drawn"
		end
		return full .. ", not drawn"
	end
	return "Drawing " .. full
end

local function StatusPhrase(db)
	local light = LightPhrase(db)
	local weather = WeatherPhrase(db)
	if weather and light then
		return weather .. ", " .. light .. ".", GOLD
	elseif weather then
		return weather .. ".", GOLD
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

	-- The tick carries the state and the label never moves. It used to read
	-- "Weather on" when it was on and "Weather off" when it was off, which is
	-- a checkbox arguing with itself: a ticked box labelled "Weather off" can
	-- be read as off, or as "off is ticked", and the two are opposites.
	-- "should be the same button but the checkbox turns it on or off",
	-- 2026-10-19.
	controls.power:SetOn(db.enabled)

	controls.weather:SetValue(Title(db.weather), ICON[db.weather])
	Teach(controls.weather.well, "Weather", "/comfy " .. db.weather,
		"Rain or snow. The arrows step between them; so do /comfy rain and " ..
		"/comfy snow.")

	-- Named for the weather it is under: the top step is monsoon in rain and
	-- blizzard in snow, so the value shown and the command the tooltip teaches
	-- both come out of the weather's own order rather than a list here.
	controls.intensity:SetValue(Title(db.intensity))
	Teach(controls.intensity.well, "Intensity", "/comfy " .. db.intensity,
		"How hard it comes down. " ..
		table.concat(weather.order, ", ") .. ".")

	controls.alpha:Set(db.scale)
	controls.speed:Set(db.speed)
	controls.dim:Set(db.gloom)
	controls.gust:Set(db.gust)
	controls.volume:Set(db.volume)

	controls.sound:SetOn(db.sound)
	controls.zoom:SetOn(db.zoom)
	-- ~= false, not a plain read: this one defaults to ON, so an absent key
	-- and an explicit false are different answers.
	controls.defer:SetOn(db.defer ~= false)
	-- Rain has lightning, snow has gusts, and the row must say which.
	controls.thunder:SetOn(db.thunder)
	controls.thunder:SetLabel(weather.flash and "Thunder" or "Gusts")
	controls.indoors:SetValue(Title(INDOORS(db)))

	-- The one place the panel can tell a player why an addon they have switched
	-- on is making no noise. Said on the face of the control rather than only
	-- in the tooltip, because nobody hovers a control they have no reason to
	-- suspect, and stepping it is also the fix.
	local muted = db.sound and ChannelMuted(db.channel)
	controls.channel:SetValue(db.channel .. (muted and " (muted)" or ""))
	controls.channel.well.tipWarn = muted and ("The game's own " .. db.channel ..
		" volume is at zero, so nothing here can be heard. Step this to move " ..
		"the weather onto a different slider, or turn that one up in the " ..
		"game's Sound options.") or nil

	for _, m in ipairs(TIME_MODES) do
		if m.key == db.timeMode then
			controls.timeMode:SetValue(m.label)
			Teach(controls.timeMode.well, m.label, "/comfy " .. m.cmd, m.note)
		end
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
		controls.status:SetWidth(controls.statusNarrow)
	else
		controls.stop:Hide()
		controls.status:SetWidth(controls.statusWide)
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
	stone:SetAlpha(0.45)

	-- The carved plate the client hangs over the top edge of its own dialogs.
	-- One texture, and the thing most responsible for a frame looking like it
	-- shipped with the game rather than with an addon.
	local header = panel:CreateTexture(nil, "ARTWORK")
	header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
	header:SetSize(250, 64)
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
	local STOP_W = 110
	controls.status = Text(state, "GameFontHighlightSmall")
	controls.status:SetPoint("LEFT", state, "LEFT", 0, 0)
	controls.status:SetWordWrap(false)
	controls.status:SetText("")
	-- Two widths, because the button beside it comes and goes. One fixed
	-- width sized for the button being there is how "Everything off. Nothing
	-- here is touching your screen." got cut to "Nothing here is to..." on the
	-- one screen where the button is hidden and the whole row was free.
	controls.statusWide = WIDTH - PAD * 2
	controls.statusNarrow = WIDTH - PAD * 2 - STOP_W - 8

	controls.stop = Pill(state, "Turn It All Off", function() Run("stop") end)
	controls.stop:SetPoint("TOPRIGHT", state, "TOPRIGHT", 0, 0)
	controls.stop:SetWidth(STOP_W)
	Teach(controls.stop, "Turn It All Off", "/comfy stop",
		"Weather, sound and the light grading, all off in one press. " ..
		"Your settings are kept; this is a switch, not a reset.")

	add(Heading(panel, "Weather", "look"), { gap = 4 })

	-- The master switch first, because it is the one control in the section
	-- that can make every other one in it do nothing. A Check is a full row of
	-- its own now, so it is added directly rather than parked inside a spacer
	-- frame; Relayout gives it the width and OnSizeChanged does the rest.
	-- Not plain "Weather": the heading above it and the rain/snow selector
	-- below it are both already called that, and three things with one name in
	-- 330 pixels is worse than a slightly longer label.
	controls.power = add(Check(panel, "Weather effects", "/comfy", function()
		Run(DB().enabled and "off" or "on")
	end))

	controls.weather = add(Select(panel, "Weather", function(d)
		local order, db2 = WEATHERS, DB()
		local at = 1
		for i, n in ipairs(order) do if n == db2.weather then at = i end end
		Run(order[((at - 1 + d) % #order) + 1])
	end))

	controls.intensity = add(Select(panel, "Intensity", function(d)
		local db2 = DB()
		local w = ComfyRainAPI.Weather[db2.weather] or ComfyRainAPI.Weather.rain
		local at = 1
		for i, n in ipairs(w.order) do if n == db2.intensity then at = i end end
		Run(w.order[((at - 1 + d) % #w.order) + 1])
	end))

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
		"How much the storm dims the world. 0 leaves the light alone, 1 is " ..
		"what this weather is meant to look like, and 2 is as dark as this " ..
		"addon goes.")

	controls.gust = add(Slider(panel, "Wind", 0, 2, 0.05, "%.2f",
		function(v) Run(string.format("gust %.2f", v)) end,
		Back("gust", "gust")))
	Teach(controls.gust.slider, "Wind", "/comfy gust 0.5",
		"How hard it gusts. 0 is dead calm: one fixed rate, no wind.")

	-- Camera distance is the only part of the world camera an addon can read,
	-- and it is a judgement call rather than a correctness fix, so it gets a
	-- switch. Full width: it has no natural partner on a row.
	controls.zoom = add(Check(panel, "Zoom Response", "/comfy zoom off",
		function() Run(DB().zoom and "zoom off" or "zoom on") end))
	Teach(controls.zoom, "Zoom Response", "/comfy zoom off",
		"Drops get bigger and faster the closer the camera is, finer and " ..
		"denser when you pull back.")

	-- Sits with the look rather than with the switches, because what it changes
	-- is what you see when the real thing is already on screen. On by default,
	-- which is the one default that argues with the addon's own name.
	controls.defer = add(Check(panel, "Yield to Real Weather", "/comfy defer off",
		function() Run(DB().defer ~= false and "defer off" or "defer on") end))
	Teach(controls.defer, "Yield to Real Weather", "/comfy defer off",
		"Stand aside while the game's own rain or snow is falling. Theirs is " ..
		"3D and stops under an arch or a bridge; ours is drawn in front of " ..
		"the camera and cannot. Where the real thing exists, it wins.")

	add(Heading(panel, "Sound", "sound"), { gap = 4 })

	controls.volume = add(Slider(panel, "Volume", 0, 1, 0.05, "%.2f",
		function(v) Run(string.format("volume %.2f", v)) end,
		Back("volume", "volume")))
	Teach(controls.volume.slider, "Volume", "/comfy volume 0.5",
		"ComfyRain's weather only. Your game volume is untouched.")

	-- One checkbox per row, which is what the client does. These two shared a
	-- row while the box was on the left of its label and the window was 330
	-- wide; a box in the right-hand column cannot share a row with anything,
	-- because there is only one column.
	controls.sound = add(Check(panel, "Sound", "/comfy sound off",
		function() Run(DB().sound and "sound off" or "sound on") end))

	controls.thunder = add(Check(panel, "Thunder", "/comfy thunder off",
		function() Run(DB().thunder and "thunder off" or "thunder on") end))

	-- Three states, which is why this is a selector and not a checkbox. "Dim"
	-- is the default and the one most people want: weather you can still HEAR
	-- from inside but cannot see, instead of either silence or rain falling
	-- through the roof.
	controls.indoors = add(Select(panel, "Indoors", function(d)
		local at = 2
		for i, n in ipairs(INDOOR_ORDER) do
			if n == INDOORS(DB()) then at = i end
		end
		Run("indoors " .. INDOOR_ORDER[((at - 1 + d) % #INDOOR_ORDER) + 1])
	end))
	Teach(controls.indoors.well, "Indoors", "/comfy indoors dim",
		"Off stops it dead. Dim keeps the sound and draws nothing, the way " ..
		"weather is from inside. On draws it at full strength.")

	controls.channel = add(Select(panel, "Channel", function(d)
		local db2, at = DB(), 1
		for i, c in ipairs(CHANNELS) do if c == db2.channel then at = i end end
		Run("channel " .. CHANNELS[((at - 1 + d) % #CHANNELS) + 1]:lower())
	end))
	Teach(controls.channel.well, "Channel", "/comfy channel Ambience",
		"Which of the game's volume sliders owns the weather. Ambience keeps " ..
		"it out of the way of music.")

	add(Heading(panel, "Time of Day", "time"), { gap = 4 })

	controls.timeMode = add(Select(panel, "Mode", function(d)
		local db2, at = DB(), 1
		for i, m in ipairs(TIME_MODES) do if m.key == db2.timeMode then at = i end end
		Run(TIME_MODES[((at - 1 + d) % #TIME_MODES) + 1].cmd)
	end))

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
	local third = (WIDTH - PAD * 2) / 3
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
-- Forward-declared because the box's own "Paste One" button reopens it empty,
-- which is the only route from "here is mine" to "here is where yours goes".
local ShowShare

-- The box with a one-line caption, and how tall one line of GameFontDisableSmall
-- is. Anything longer pushes the frame down by the difference.
local SHARE_BASE, NOTE_LINE = 104, 16

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

	-- The caption is the only instruction anybody gets, so it has to be allowed
	-- to be two or three lines. A FontString given a width wraps, but the frame
	-- around it does not grow on its own: the box was a fixed 104 tall with 16
	-- pixels between this and the text well, so the second line was drawn
	-- underneath the well and the sentence appeared to stop mid-word. The well
	-- now hangs off the bottom of the caption and ShowShare sizes the frame to
	-- whatever it turned out to be.
	f.note = Text(f, "GameFontDisableSmall")
	f.note:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + 4, -PAD - 18)
	f.note:SetWidth(WIDTH - PAD * 2 - 8)
	f.note:SetJustifyV("TOP")
	if f.note.SetWordWrap then f.note:SetWordWrap(true) end

	local well = CreateFrame("Frame", nil, f)
	well:SetPoint("TOPLEFT", f.note, "BOTTOMLEFT", 0, -8)
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

	-- The other direction, which until now existed only as a slash command
	-- nobody was told about. Somebody who has been handed a profile string
	-- opens this box to look at their own first; this is the button that is
	-- there when they do.
	f.paste = Pill(f, "Paste One", function() ShowShare(nil) end)
	f.paste:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD + 4, PAD)
	f.paste:SetWidth(96)
	Teach(f.paste, "Paste One", "/comfy import",
		"Empty the box so you can paste a profile somebody sent you. Your own " ..
		"settings are kept and /comfy undo puts them back.")

	tinsert(UISpecialFrames, "ComfyRainShare")
	shareBox = f
end

-- text = the profile to hand out, or nil to open the box empty for a paste.
-- note overrides the default caption. /comfy about reuses this box for the
-- project URL, and telling somebody that a GitHub link can be "pasted back" to
-- another ComfyRain user would be nonsense.
function ShowShare(text, note)
	if not shareBox then BuildShare() end
	shareBox.edit:SetText(text or "")
	-- Both halves of the round trip are spelled out, because a string in a box
	-- with no instructions is a string nobody uses. The import caption leads
	-- with the undo: the reason people do not paste a stranger's profile is
	-- that they expect to lose their own.
	shareBox.note:SetText(note or (text
		and "Ctrl-C copies it, then send it to them. To use one somebody " ..
		    "sent you, press Paste One."
		or "Ctrl-V pastes it in, then press Enter. Your own settings are " ..
		   "saved first, and /comfy undo puts them back."))

	-- Only when this is a profile of ours to hand out. /comfy about borrows the
	-- box for a URL, and offering to import a GitHub link would be nonsense.
	if text and not note then shareBox.paste:Show() else shareBox.paste:Hide() end

	-- A caption that wrapped to two lines used to be drawn underneath the text
	-- well, which read as the sentence being cut off. The frame grows instead.
	local h = shareBox.note.GetStringHeight
		and shareBox.note:GetStringHeight() or NOTE_LINE
	if not h or h < NOTE_LINE then h = NOTE_LINE end
	shareBox:SetHeight(SHARE_BASE + (h - NOTE_LINE))

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
-- So: our own art, rasterised by build/make_icon_tga.py and shipped in the
-- package. One raindrop, which is the picture the addon is named after, and it
-- desaturates when the weather is off so the button still answers "is this on"
-- at a glance.
--
-- This was six colour quads until 2026-10-19: a dusk gradient with little
-- streaks scattered over it. Twenty pixels is not enough room for scattered
-- detail, so what it actually looked like was grey noise, which is what "it
-- needs to be more comfy and maybe bigger" was looking at. A picture drawn at
-- 256px and resampled once, by a good filter, offline, beats anything assembled
-- from rectangles at draw time.
--
-- One picture, not one per weather. A matching snowflake was built and dropped
-- the same day - "do the rain drop i guess first one" - and nothing is lost by
-- it: the tooltip and the panel both name the weather in words, and an icon
-- that changes under the player is a worse readout than one they can learn.
local ROUND_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local ICON_ART = "Interface\\AddOns\\ComfyRain\\icon"

-- The hole in MiniMap-TrackingBorder is NOT centred on the button. With the
-- 53x53 border anchored TOPLEFT on a 31x31 button - the arrangement every
-- addon on CurseForge uses, and the one BuildMinimap uses - the round opening
-- is 20px across with its centre at (17, -15) from the button's top-left
-- corner. The button's own centre is at (15.5, -15.5), so the hole sits 1.5px
-- right and 0.5px up from it.
--
-- Ours was painted at (-1, +1): two and a half pixels out on a twenty pixel
-- disc. It overhung the brass on the left and left a crescent of bare map
-- showing on the right, which is "the current one doesnt fix in the circle
-- properly".
--
-- Those four numbers - button, border, hole, offset - are one measurement of
-- one piece of art, so they scale together or not at all. MINIMAP_SCALE is the
-- only one to touch: the ring is a texture and stretches, and every derived
-- figure below follows it. Nudging the button size on its own is how the art
-- ends up off-centre again, because the offset is a fraction of the button.
local BUTTON_BASE, BORDER_BASE, HOLE_BASE = 31, 53, 20
-- 31px is the LibDBIcon default and it is small - "we need the minimap icon
-- thing to be bigger circle", 2026-10-19. A quarter up is noticeably bigger
-- without crowding the ring, which already carries the clock and the tracking
-- button on most setups.
local MINIMAP_SCALE = 1.25

local BUTTON_SIZE = BUTTON_BASE * MINIMAP_SCALE
local BORDER_SIZE = BORDER_BASE * MINIMAP_SCALE
local HOLE_X, HOLE_Y = 1.5 * MINIMAP_SCALE, 0.5 * MINIMAP_SCALE
-- Two pixels wider than the hole, so the mask's soft edge lands under the
-- brass lip instead of against the map, where it would read as a seam.
local ICON_SIZE = (HOLE_BASE + 2) * MINIMAP_SCALE

local icon = {}

local function BuildIcon(button)
	-- Behind the picture, and never removed. If the art file is missing - a
	-- half-extracted zip, a packager that dropped a TGA - a bare button in the
	-- ring is indistinguishable from a broken addon, and a warm disc is still
	-- recognisably this one.
	local back = button:CreateTexture(nil, "BACKGROUND")
	back:SetSize(ICON_SIZE, ICON_SIZE)
	back:SetPoint("CENTER", HOLE_X, HOLE_Y)
	back:SetColorTexture(0.13, 0.10, 0.09, 1)
	pcall(back.SetMask, back, ROUND_MASK)
	icon.back = back

	local art = button:CreateTexture(nil, "ARTWORK")
	art:SetSize(ICON_SIZE, ICON_SIZE)
	art:SetPoint("CENTER", HOLE_X, HOLE_Y)
	-- Rounds the square render off inside the ring. Without it the corners
	-- show, and the brass covers all four of them anyway, so it is allowed to
	-- fail on a client that does not have SetMask.
	pcall(art.SetMask, art, ROUND_MASK)
	icon.art = art
	icon.button = button
end

-- Repainted whenever the weather is switched, which is why it is not just set
-- once at build time. Cheap: one SetTexture on a frame nobody redraws.
local function PaintIcon()
	if not icon.art then return end
	local db = ComfyRainAPI and ComfyRainAPI.DB()
	if not db then return end

	icon.art:SetTexture(ICON_ART)
	-- Off is the same picture greyed out, and dimmer than the ring around it,
	-- so the eye reads it as inactive rather than as a darker sky.
	pcall(icon.art.SetDesaturated, icon.art, not db.enabled)
	if db.enabled then
		icon.art:SetVertexColor(1, 1, 1)
	else
		icon.art:SetVertexColor(0.55, 0.55, 0.58)
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
	minimap:SetSize(BUTTON_SIZE, BUTTON_SIZE)
	minimap:SetFrameStrata("MEDIUM")
	minimap:SetFrameLevel(Minimap:GetFrameLevel() + 8)

	local border = minimap:CreateTexture(nil, "OVERLAY")
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetSize(BORDER_SIZE, BORDER_SIZE)
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

-- A mock of the World of Warcraft addon API, enough to run Duskfall under
-- stock Lua 5.1 with no client.
--
-- The beta client is withdrawn on 2026-10-21 and the game does not exist again
-- until 4 November, which leaves fourteen days in which code can be written and
-- not executed. This is how it gets executed. Lua 5.1 is deliberate: that is
-- WoW's own interpreter version, so a 5.2+ construct that would fail in the
-- client fails here too.
--
-- What it does NOT do is render anything or judge how the rain looks. It records
-- what the addon asked the renderer for, which is the part that can be wrong in a
-- way a human staring at the screen would not notice: a MOD texture left at an
-- alpha that makes it a no-op, a double-darkened night, a sound ticker that
-- reloops at the wrong interval.
--
-- Fidelity notes, where this mock deliberately reproduces a client quirk rather
-- than an idealised API:
--   * RegisterEvent on an unknown event raises, as it does on Forever, because
--     that is the trap that silently aborts the rest of a Lua file.
--   * GetPlayerFacing and friends can be made to return a secret value, which is
--     non-nil and raises when touched.
--   * PlaySoundFile can be made to fail, because playing Blizzard's library by
--     FileDataID is an assumption, not a guarantee.

local M = {}

local unpack = unpack or table.unpack

--------------------------------------------------------------------------------
-- Secret values
--------------------------------------------------------------------------------
--
-- Midnight's restricted-value machinery, which this client carries. A secret
-- value is non-nil and looks ordinary until arithmetic touches it, so a plain
-- `if x then` guard is not enough and the addon has to route every restricted
-- getter through canaccessvalue.

local secrets = setmetatable({}, { __mode = "k" })

local function makeSecret(label)
	local t = setmetatable({}, {
		__metatable = "secret",
		__tostring = function() return "secret:" .. tostring(label) end,
		__add = function() error("attempt to perform arithmetic on a secret value", 2) end,
		__sub = function() error("attempt to perform arithmetic on a secret value", 2) end,
		__mul = function() error("attempt to perform arithmetic on a secret value", 2) end,
		__div = function() error("attempt to perform arithmetic on a secret value", 2) end,
		__lt  = function() error("attempt to compare a secret value", 2) end,
		__le  = function() error("attempt to compare a secret value", 2) end,
	})
	secrets[t] = true
	return t
end

--------------------------------------------------------------------------------
-- Regions
--------------------------------------------------------------------------------

local Region = {}
Region.__index = Region

function Region:SetAllPoints(target) self._anchor = target or self._parent end
-- Anchoring is not simulated, but the offsets are kept: a button placed on a
-- radius the addon worked out itself can only be checked by reading them back.
-- SetPoint has five legal shapes and the offsets are always the trailing pair
-- of numbers, so they are picked out positionally rather than by signature.
function Region:SetPoint(point, ...)
	local nums = {}
	for i = 1, select("#", ...) do
		local v = select(i, ...)
		if type(v) == "number" then nums[#nums + 1] = v end
	end
	self._lastPoint = {
		point = point,
		x = nums[#nums - 1] or 0,
		y = nums[#nums] or 0,
	}
end
function Region:ClearAllPoints() self._anchor = nil end

function Region:SetSize(w, h) self._width, self._height = w, h end
function Region:SetWidth(w) self._width = w end
function Region:SetHeight(h) self._height = h end
function Region:GetWidth()
	if self._width then return self._width end
	if self._anchor then return self._anchor:GetWidth() end
	return 0
end
function Region:GetHeight()
	if self._height then return self._height end
	if self._anchor then return self._anchor:GetHeight() end
	return 0
end

function Region:SetAlpha(a) self._alpha = a end
function Region:GetAlpha() return self._alpha or 1 end
function Region:Show() self._shown = true end
function Region:Hide() self._shown = false end
function Region:IsShown() return self._shown and true or false end
function Region:IsVisible()
	if not self._shown then return false end
	local p = self._parent
	while p do
		if not p._shown then return false end
		p = p._parent
	end
	return true
end
function Region:GetName() return self._name end
function Region:GetParent() return self._parent end

--------------------------------------------------------------------------------
-- Textures
--------------------------------------------------------------------------------
--
-- Every setter records, because the recorded value IS the assertion. There is no
-- framebuffer to inspect, so "the gloom quad is a no-op at gloom 0" can only be
-- checked by reading back the colour the addon asked for.

local Texture = setmetatable({}, { __index = Region })
Texture.__index = Texture

function Texture:SetTexture(file, wrapH, wrapV)
	self.texture, self.wrapH, self.wrapV = file, wrapH, wrapV
end
function Texture:GetTexture() return self.texture end
function Texture:SetBlendMode(mode) self.blend = mode end
function Texture:GetBlendMode() return self.blend end
function Texture:SetColorTexture(r, g, b, a)
	self.colour = { r, g, b, a or 1 }
	self.texture = nil
end
function Texture:SetVertexColor(r, g, b, a) self.vertexColour = { r, g, b, a or 1 } end
function Texture:SetTexCoord(l, r, t, b) self.texCoord = { l, r, t, b } end
function Texture:SetGradient(orientation, a, b)
	-- The colour-object shape moved between clients, which is why the addon
	-- pcalls this. Reject anything that is not a real colour object so the
	-- fallback path is exercised rather than silently accepted.
	if type(a) ~= "table" or type(a.GetRGBA) ~= "function" then
		error("SetGradient: expected a colour object", 2)
	end
	self.gradient = { orientation, a, b }
end
function Texture:SetDrawLayer(layer, sublevel) self.layer, self.sublevel = layer, sublevel end
-- Both of these are modern-client only, which is why the addon pcalls them.
-- Recorded rather than ignored: the slant on the minimap icon's streaks is the
-- difference between rain and snow, and nothing else distinguishes them.
function Texture:SetMask(file) self.mask = file end
function Texture:SetRotation(r) self.rotation = r end

--------------------------------------------------------------------------------
-- Font strings
--------------------------------------------------------------------------------
--
-- Text is the whole readable surface of a settings panel, so the mock keeps it:
-- a spec asserting that the window says "blizzard" is asserting the thing the
-- player actually reads, which no amount of checking db.intensity does.

local FontString = setmetatable({}, { __index = Region })
FontString.__index = FontString

function FontString:SetText(t) self.text = t end
function FontString:GetText() return self.text end
function FontString:SetFormattedText(fmt, ...) self.text = string.format(fmt, ...) end
function FontString:SetTextColor(r, g, b, a) self.colour = { r, g, b, a or 1 } end
function FontString:SetJustifyH(j) self.justifyH = j end
function FontString:SetJustifyV(j) self.justifyV = j end
function FontString:SetFontObject(o) self.fontObject = o end
function FontString:SetFont(f, size) self.font, self.fontSize = f, size end

--------------------------------------------------------------------------------
-- Frames
--------------------------------------------------------------------------------

local Frame = setmetatable({}, { __index = Region })
Frame.__index = Frame

function Frame:CreateTexture(name, layer, template, sublevel)
	local t = setmetatable({
		_name = name, _parent = self, _shown = true,
		layer = layer, sublevel = sublevel,
	}, Texture)
	self._textures[#self._textures + 1] = t
	return t
end

function Frame:CreateFontString(name, layer, inherits)
	local fs = setmetatable({
		_name = name, _parent = self, _shown = true,
		layer = layer, inherits = inherits,
	}, FontString)
	self._fontStrings[#self._fontStrings + 1] = fs
	return fs
end

function Frame:SetScript(which, fn) self._scripts[which] = fn end
function Frame:GetScript(which) return self._scripts[which] end
function Frame:HookScript(which, fn)
	local prev = self._scripts[which]
	self._scripts[which] = function(...)
		if prev then prev(...) end
		return fn(...)
	end
end

function Frame:RegisterEvent(event)
	-- The trap. An unknown event name raises on this client, and because the
	-- addon is one file, an unguarded RegisterEvent aborts everything after it.
	if not M.knownEvents[event] then
		error("RegisterEvent: unknown event '" .. tostring(event) .. "'", 2)
	end
	self._events[event] = true
end
function Frame:UnregisterEvent(event) self._events[event] = nil end
function Frame:UnregisterAllEvents() self._events = {} end
function Frame:IsEventRegistered(event) return self._events[event] and true or false end

function Frame:SetFrameStrata(s) self.strata = s end
function Frame:GetFrameStrata() return self.strata end
function Frame:SetFrameLevel(l) self.level = l end
function Frame:GetFrameLevel() return self.level or 1 end
function Frame:EnableMouse(v) self.mouseEnabled = v and true or false end
function Frame:GetEffectiveScale() return self.scale or 1 end
function Frame:SetMovable() end
function Frame:RegisterForDrag() end
function Frame:SetClampedToScreen() end
function Frame:SetToplevel() end
function Frame:EnableMouseWheel(v) self.mouseWheelEnabled = v and true or false end
function Frame:StartMoving() self._moving = true end
function Frame:StopMovingOrSizing() self._moving = false end
function Frame:SetHitRectInsets() end
function Frame:GetPoint() return self._point or "CENTER", nil, self._point or "CENTER",
	self._x or 0, self._y or 0 end

--------------------------------------------------------------------------------
-- The world
--------------------------------------------------------------------------------

-- Events this client is prepared to admit exist. Anything outside this list
-- raises on RegisterEvent, which is the point.
local DEFAULT_EVENTS = {
	"ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD",
	"ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA",
	"CINEMATIC_START", "CINEMATIC_STOP", "PLAY_MOVIE", "STOP_MOVIE",
	"CONSOLE_MESSAGE", "WEATHER_CHANGED", "PLAYER_LOGOUT",
	-- Verified present in WowB.exe 1.60.1.70338 at offset 81230320.
	"SOUNDKIT_FINISHED",
}

function M.reset(opts)
	opts = opts or {}

	M.now = 1000.0                       -- GetTime(), a monotonic session clock
	M.epoch = opts.epoch or 1792000000   -- time(), wall clock
	M.frames = {}
	M.timers = {}
	M.sounds = {}                        -- every PlaySoundFile, in order
	M.handles = {}                       -- handle -> true while playing
	M.printed = {}
	M.errors = {}
	M.nextHandle = 1

	M.knownEvents = {}
	for _, e in ipairs(DEFAULT_EVENTS) do M.knownEvents[e] = true end
	for _, e in ipairs(opts.events or {}) do M.knownEvents[e] = true end
	for _, e in ipairs(opts.missingEvents or {}) do M.knownEvents[e] = nil end

	M.cvars = {
		weatherDensity = "0",            -- as found on the author's machine
		graphicsEnvironmentDetail = "1",
		Sound_EnableMusic = "1",
		Sound_EnableAmbience = "1",
		Sound_EnableSFX = "1",
		-- The client ships defaults for these, so a spec about restoring them
		-- has to start from a value rather than from nil.
		screenshotFormat = "jpeg",
		screenshotQuality = "7",
	}
	for k, v in pairs(opts.cvars or {}) do M.cvars[k] = tostring(v) end

	-- A CVar an addon may not write. The client does NOT raise on one: SetCVar
	-- returns as though it worked and the value does not move, which is the
	-- whole reason anything probing a CVar needs a positive control.
	M.protectedCVars = {}
	for _, name in ipairs(opts.protectedCVars or {}) do M.protectedCVars[name] = true end

	-- World state the addon reads. Tests write these directly.
	M.state = {
		gameHour = 12, gameMinute = 0,   -- the realm clock
		facing = 0.0,
		speed = 0.0,
		indoors = false,
		sheltered = false,   -- under a roof the engine does not call a room
		zone = "Elwynn Forest",
		subzone = "Goldshire",
		uiMapID = 37,
		weather = nil,                   -- { type = 1, intensity = 0.8 }
	}
	for k, v in pairs(opts.state or {}) do M.state[k] = v end

	-- Whether the client will play a given sound. Returning false models the one
	-- real risk with Blizzard's library: a FileDataID the user's install lacks.
	M.canPlaySound = opts.canPlaySound or function() return true end
	M.muted = {}

	-- Three things nobody has seen on a live 1.60.1 client. The mock takes a
	-- position only because a test has to; the probe exists to replace these
	-- with observations, and every spec that depends on one says which it set.
	local function pick(v, default) if v == nil then return default end return v end
	M.muteAffectsOwnPlayback = pick(opts.muteAffectsOwnPlayback, true)
	M.finishEventForKits     = pick(opts.finishEventForKits, true)   -- documented since 7.0.3
	M.finishEventForFiles    = pick(opts.finishEventForFiles, false) -- unknown, assumed hostile
	-- Which params key carries the sound id. Unknown on the real client; the
	-- probe discovers it by trying each candidate. Specs set this to whichever
	-- name they want the client to be pretending to accept.
	M.soundParamsKey         = pick(opts.soundParamsKey, "soundKitID")
	M.screenshotBlocked      = pick(opts.screenshotBlocked, false)
	-- Whether CreateFrame(..., "BackdropTemplate") hands back a frame that can
	-- actually take a backdrop. True on every current client; a spec sets it
	-- false to prove the hand-drawn border still comes up on one that cannot.
	M.backdropTemplate       = pick(opts.backdropTemplate, true)
	M.screenshots = {}
	M.soundKits = {}
	for _, id in ipairs(opts.soundKits or { 567 }) do M.soundKits[id] = true end

	-- How long each file runs, so a handle stops being live when the sound
	-- ends. Without this every handle looks like it is still playing forever
	-- and the addon appears to leak audio it has in fact finished with. Lengths
	-- are the spec's to supply: the mock has no way to measure a file it does
	-- not have, and inventing a default would be a fabricated number.
	M.reloads = 0
	M.inCombat = opts.inCombat or false
	M.soundLengths = opts.soundLengths or {}
	M.defaultSoundLength = opts.defaultSoundLength

	M.screen = { width = opts.width or 3440, height = opts.height or 1440 }
	return M
end

local function newFrame(kind, name, parent, template)
	local f = setmetatable({
		_name = name, _parent = parent, _kind = kind, _template = template,
		_shown = true, _scripts = {}, _events = {}, _textures = {}, _fontStrings = {},
	}, Frame)
	-- SetBackdrop lives on the template, not on every frame: asking for it
	-- without inheriting BackdropTemplate is the classic post-9.0 error, and a
	-- mock that answered anyway would hide it.
	if template == "BackdropTemplate" and M.backdropTemplate then
		f.SetBackdrop = function(self, b) self._backdrop = b end
		f.GetBackdrop = function(self) return self._backdrop end
		f.SetBackdropColor = function(self, ...) self._backdropColour = { ... } end
		f.SetBackdropBorderColor = function(self, ...) self._backdropBorder = { ... } end
	end

	-- Only a Model frame has SetModel, so code that forgets to pass "Model"
	-- fails here the way it would in the client.
	if kind == "Model" then
		f.SetModel = function(self, id) self._model = id end
		f.GetModelFileID = function(self) return self._model end
		f.SetCamDistanceScale = function() end
	end

	-- A Button is only a button because it can be clicked, and a spec that
	-- cannot click one is testing the layout rather than the panel.
	if kind == "Button" or kind == "CheckButton" then
		f.SetText = function(self, t) self._text = t end
		f.GetText = function(self) return self._text end
		f.RegisterForClicks = function() end
		f.SetFontString = function(self, fs) self._fontString = fs end
		f.SetNormalTexture = function(self, t) self._normalTexture = t end
		f.SetHighlightTexture = function(self, t) self._highlightTexture = t end
		f.Enable = function(self) self._enabled = true end
		f.Disable = function(self) self._enabled = false end
		f.IsEnabled = function(self) return self._enabled ~= false end
		f.Click = function(self, button)
			if self._enabled == false then return end
			local fn = self._scripts.OnClick
			if fn then fn(self, button or "LeftButton", false) end
		end
	end

	-- Sliders clamp and step in C, so the mock does too: a panel that writes
	-- 1.7 into a 0-1.5 slider must read back 1.5 here as well, or the spec
	-- proves something the client would not do.
	if kind == "Slider" then
		f._min, f._max, f._step, f._value = 0, 1, nil, 0
		f.SetOrientation = function(self, o) self._orientation = o end
		f.SetThumbTexture = function(self, t) self._thumb = t end
		f.SetObeyStepOnDrag = function(self, v) self._obeyStep = v and true or false end
		f.SetMinMaxValues = function(self, lo, hi) self._min, self._max = lo, hi end
		f.GetMinMaxValues = function(self) return self._min, self._max end
		f.SetValueStep = function(self, st) self._step = st end
		f.GetValue = function(self) return self._value end
		f.SetValue = function(self, v)
			v = math.max(self._min, math.min(self._max, v or 0))
			if self._step and self._step > 0 then
				v = self._min + math.floor((v - self._min) / self._step + 0.5) * self._step
			end
			local changed = v ~= self._value
			self._value = v
			local fn = self._scripts.OnValueChanged
			if fn and changed then fn(self, v, true) end
		end
		-- What a drag does: the user moved the thumb, so the handler runs even
		-- if the value happens to land where it already was.
		f.Drag = function(self, v)
			self:SetValue(v)
			local fn = self._scripts.OnValueChanged
			if fn then fn(self, self._value, true) end
		end
	end
	M.frames[#M.frames + 1] = f
	if name then M.env[name] = f end
	return f
end

--------------------------------------------------------------------------------
-- Driving time
--------------------------------------------------------------------------------

local function fireTimers()
	-- Collect first: a timer callback may schedule another, and a ticker that
	-- rearms inside this loop must not fire twice in one step.
	local due = {}
	for _, t in ipairs(M.timers) do
		if not t.cancelled and t.at <= M.now then due[#due + 1] = t end
	end
	table.sort(due, function(a, b) return a.at < b.at end)
	for _, t in ipairs(due) do
		if not t.cancelled then
			if t.interval then
				t.at = t.at + t.interval
				t.fired = (t.fired or 0) + 1
				if t.iterations and t.fired >= t.iterations then t.cancelled = true end
			else
				t.cancelled = true
			end
			t.fn(t.proxy)
		end
	end
	-- Compact, so a long run does not accumulate dead timers.
	local live = {}
	for _, t in ipairs(M.timers) do
		if not t.cancelled then live[#live + 1] = t end
	end
	M.timers = live
end

local function fireOnUpdate(dt)
	-- Snapshot: an OnUpdate may create a frame (the lightning driver does) and
	-- the new one should not run until the next step.
	local snapshot = {}
	for i, f in ipairs(M.frames) do snapshot[i] = f end
	for _, f in ipairs(snapshot) do
		local fn = f._scripts.OnUpdate
		if fn and f:IsVisible() then
			local ok, err = pcall(fn, f, dt)
			if not ok then M.errors[#M.errors + 1] = err end
		end
	end
end

-- Advance the session clock. Stepped rather than jumped, because OnUpdate
-- handlers integrate against elapsed and a single huge step is not the same
-- thing as many small ones: the scroll offsets, the fade and the indoor
-- debounce all behave differently.
function M.advance(seconds, step)
	step = step or (1 / 60)
	local remaining = seconds
	while remaining > 1e-9 do
		local dt = math.min(step, remaining)
		M.now = M.now + dt
		M.epoch = M.epoch + dt
		fireTimers()
		fireOnUpdate(dt)
		remaining = remaining - dt
	end
end

function M.fire(event, ...)
	local snapshot = {}
	for i, f in ipairs(M.frames) do snapshot[i] = f end
	for _, f in ipairs(snapshot) do
		if f._events[event] and f._scripts.OnEvent then
			local ok, err = pcall(f._scripts.OnEvent, f, event, ...)
			if not ok then M.errors[#M.errors + 1] = err end
		end
	end
end

function M.slash(command, input)
	local fn = M.env.SlashCmdList and M.env.SlashCmdList[command]
	if not fn then error("no slash handler registered for " .. tostring(command), 2) end
	return fn(input or "")
end

--------------------------------------------------------------------------------
-- The API surface
--------------------------------------------------------------------------------

function M.install(env)
	M.env = env

	env.WorldFrame = setmetatable({
		_name = "WorldFrame", _shown = true, _scripts = {}, _events = {}, _textures = {},
		_fontStrings = {}, _width = M.screen.width, _height = M.screen.height,
	}, Frame)
	M.frames[#M.frames + 1] = env.WorldFrame

	env.UIParent = setmetatable({
		_name = "UIParent", _shown = true, _scripts = {}, _events = {}, _textures = {},
		_width = M.screen.width, _height = M.screen.height, _scale = 1,
		_fontStrings = {},
	}, Frame)
	env.UIParent.GetScale = function(self) return self._scale end
	env.UIParent.SetScale = function(self, s) self._scale = s end
	M.frames[#M.frames + 1] = env.UIParent

	env.CreateFrame = function(kind, name, parent, template)
		return newFrame(kind, name, parent, template)
	end

	-- Escape-to-close is a list of frame NAMES, which is why the panel has to
	-- have one. A spec can assert membership and that is the whole contract.
	env.UISpecialFrames = {}

	-- The minimap. Real enough to parent a button to and to compute a position
	-- against: the addon reads GetCenter, GetEffectiveScale and GetFrameLevel
	-- off it and nothing else.
	env.Minimap = newFrame("Frame")
	env.Minimap.GetCenter = function() return 1000, 700 end
	env.Minimap:SetSize(140, 140)
	-- Cursor position in screen pixels, which is what the real one returns.
	M.cursor = { x = 1080, y = 700 }
	env.GetCursorPosition = function() return M.cursor.x, M.cursor.y end

	-- Tooltips are how a settings window teaches its own slash commands, so
	-- what was put in one is recorded rather than thrown away.
	env.GameTooltip = {
		lines = {},
		SetOwner = function(self, owner, anchor) self.owner, self.anchor = owner, anchor end,
		SetText = function(self, text) self.lines = { text } end,
		AddLine = function(self, text) self.lines[#self.lines + 1] = text end,
		ClearLines = function(self) self.lines = {} end,
		Show = function(self) self.shown = true end,
		Hide = function(self) self.shown = false end,
		IsShown = function(self) return self.shown and true or false end,
	}

	env.print = function(...)
		local parts = {}
		for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
		local line = table.concat(parts, " ")
		M.printed[#M.printed + 1] = line
		if M.echo then io.write(line, "\n") end
	end

	-- Clocks. time() and date() are overridden so a spec can sit at a chosen
	-- wall-clock hour without depending on when the suite is run.
	env.GetTime = function() return M.now end
	env.time = function() return math.floor(M.epoch) end
	env.date = function(fmt, t) return os.date(fmt, math.floor(t or M.epoch)) end
	env.GetGameTime = function()
		local s = M.state
		if s.gameHour == nil then return nil end
		return math.floor(s.gameHour), math.floor(s.gameMinute or 0)
	end
	env.GetServerTime = function() return math.floor(M.epoch) end

	-- ReloadUI is recorded, not performed. A spec that wants the other side of
	-- a reload builds a new world and carries DuskfallDB across, which is what
	-- the client actually does and is the only way to test the write-read cycle.
	env.ReloadUI = function() M.reloads = M.reloads + 1 end
	env.InCombatLockdown = function() return M.inCombat end

	env.C_Timer = {
		After = function(delay, fn)
			M.timers[#M.timers + 1] = { at = M.now + delay, fn = fn }
		end,
		NewTimer = function(delay, fn)
			local t = { at = M.now + delay, fn = fn }
			t.proxy = { Cancel = function() t.cancelled = true end,
			            IsCancelled = function() return t.cancelled == true end }
			M.timers[#M.timers + 1] = t
			return t.proxy
		end,
		NewTicker = function(interval, fn, iterations)
			local t = { at = M.now + interval, interval = interval, fn = fn,
			            iterations = iterations }
			t.proxy = { Cancel = function() t.cancelled = true end,
			            IsCancelled = function() return t.cancelled == true end }
			M.timers[#M.timers + 1] = t
			return t.proxy
		end,
	}

	-- Restricted values. Anything a test marks secret comes back non-nil and
	-- raises on arithmetic, which is exactly how the client behaves in an
	-- encounter and is the reason the addon has a Readable() wrapper at all.
	env.canaccessvalue = function(v) return not secrets[v] end
	env.issecurevariable = function() return true end
	M.secretValue = makeSecret

	env.GetPlayerFacing = function() return M.state.facing end
	env.GetUnitSpeed = function(unit) return (unit == "player") and M.state.speed or 0 end
	-- These are NOT complements on the real client. Under an awning, a cave
	-- mouth or a doorway both return false, and modelling them as opposites is
	-- what let the rain-through-roofs bug live in a green test suite. `sheltered`
	-- is that third state; leave it nil and the two behave as before.
	env.IsIndoors = function() return M.state.indoors and true or false end
	env.IsOutdoors = function()
		if M.state.sheltered then return false end
		return not M.state.indoors
	end
	env.IsSubmerged = function() return M.state.submerged and true or false end
	env.GetRealZoneText = function() return M.state.zone end
	env.GetSubZoneText = function() return M.state.subzone end
	env.GetZoneText = function() return M.state.zone end

	env.C_Map = {
		GetBestMapForUnit = function() return M.state.uiMapID end,
	}

	-- C_Weather reads only. There is no setter anywhere in the API; that absence
	-- is the whole reason the addon draws its own rain.
	env.C_Weather = {
		GetCurrentWeather = function()
			local w = M.state.weather
			if not w then return { weatherType = 0, intensity = 0 } end
			return { weatherType = w.type, intensity = w.intensity or 0 }
		end,
	}
	env.Enum = { WeatherType = { None = 0, Rain = 1, Snow = 2, Sandstorm = 3 } }

	env.GetCVar = function(name) return M.cvars[name] end
	env.SetCVar = function(name, value)
		if M.protectedCVars[name] then return true end   -- silently ignored, as in the client
		M.cvars[name] = tostring(value)
		return true
	end
	env.GetCVarBool = function(name) return M.cvars[name] == "1" end
	-- Screenshot() writes a file and returns nothing, so the only thing a test
	-- can see is that it was called and what the world looked like at the time.
	-- Set screenshotBlocked to reproduce a client that refuses.
	env.Screenshot = nil
	if not M.screenshotBlocked then
	env.Screenshot = function()
		M.screenshots[#M.screenshots + 1] = {
			weather   = env.DuskfallDB and env.DuskfallDB.weather,
			intensity = env.DuskfallDB and env.DuskfallDB.intensity,
			enabled   = env.DuskfallDB and env.DuskfallDB.enabled,
			timeMode  = env.DuskfallDB and env.DuskfallDB.timeMode,
			timeFixed = env.DuskfallDB and env.DuskfallDB.timeFixed,
		}
	end
	end

	-- Sound. Every call is logged with the channel, because which channel a bed
	-- lands on decides whether a player who muted the music hears it at all, and
	-- that is the single assumption the whole audio plan rests on.
	local function play(file, channel, kind)
		-- Warcraft Wiki says MuteSoundFile reaches "sounds played manually by
		-- PlaySoundFile()". Unverified on 1.60.1, and it decides whether the
		-- suppression plan works, so it is a switch, not an assumption.
		if M.muteAffectsOwnPlayback and M.muted and M.muted[file] then
			M.sounds[#M.sounds + 1] = { file = file, channel = channel, kind = kind,
			                            at = M.now, ok = false, muted = true }
			return false
		end
		if not M.canPlaySound(file, channel) then
			M.sounds[#M.sounds + 1] = { file = file, channel = channel, kind = kind,
			                            at = M.now, ok = false }
			return false
		end
		local handle = M.nextHandle
		M.nextHandle = M.nextHandle + 1
		M.handles[handle] = true
		M.sounds[#M.sounds + 1] = { file = file, channel = channel, kind = kind,
		                            at = M.now, ok = true, handle = handle }

		local length = M.soundLengths[file] or M.defaultSoundLength
		if length then
			M.timers[#M.timers + 1] = {
				at = M.now + length,
				fn = function() M.handles[handle] = nil end,
			}
		end
		return true, handle
	end

	env.PlaySoundFile = function(file, channel) return play(file, channel, "file") end
	env.PlaySound = function(kit, channel) return play(kit, channel, "kit") end
	env.StopSound = function(handle, fadeMs)
		if handle and M.handles[handle] then
			M.handles[handle] = nil
			M.sounds[#M.sounds + 1] = { stop = handle, at = M.now, fadeMs = fadeMs }
			return true
		end
		return false
	end
	env.PlayMusic = function(file) return play(file, "Music", "music") end
	env.StopMusic = function() end
	env.MuteSoundFile = function(id) M.muted = M.muted or {}; M.muted[id] = true end
	env.UnmuteSoundFile = function(id) if M.muted then M.muted[id] = nil end end

	-- C_Sound as probed in the binary. uiSoundSubType, forceNoDuplicates,
	-- runFinishCallback, overridePriority and volumeOverride sit at 81780880 to
	-- 81780968, immediately before both "(params)" usage strings, so they are a
	-- declared struct rather than adjacency. runFinishCallback is a FLAG: it
	-- arms SOUNDKIT_FINISHED, it does not call anything. The
	-- real check is /dump C_Sound on a live client before 21 October.
	env.C_Sound = {
		PlaySound = function(kit, channel) return play(kit, channel, "kit") end,
		-- ONE argument, a params table. Confirmed on build 70374, which answered
		-- a two-argument call with its own usage string:
		--   local success, soundHandle = C_Sound.PlaySoundWithOptions(params)
		-- Which key inside it holds the sound id is still unknown, so the mock
		-- accepts exactly one (M.soundParamsKey) and raises on anything else,
		-- the way the client does. A spec that guesses wrong has to fail here.
		PlaySoundWithOptions = function(params)
			if type(params) ~= "table" then
				error("bad argument #1 to '?' (Usage: local success, soundHandle = " ..
					"C_Sound.PlaySoundWithOptions(params))", 2)
			end
			local id = params[M.soundParamsKey or "soundKitID"]
			if id == nil then
				error("bad argument #1 to '?' (Usage: local success, soundHandle = " ..
					"C_Sound.PlaySoundWithOptions(params))", 2)
			end
			local ok, handle = play(id, params.channel, "options")
			local entry = M.sounds[#M.sounds]
			entry.volumeOverride = params.volumeOverride
			entry.runFinishCallback = params.runFinishCallback and true or false
			if ok and params.runFinishCallback then
				-- runFinishCallback does not call anything. It arms the
				-- SOUNDKIT_FINISHED event, which the binary does contain. The
				-- open question is whether it fires for a FileDataID or only
				-- for a SoundKit, so the mock is told, never assumes.
				local isKit = M.soundKits[id] and true or false
				local fires = isKit and M.finishEventForKits or M.finishEventForFiles
				local length = params.length or M.soundLengths[id] or M.defaultSoundLength or 1.0
				if fires then
					M.timers[#M.timers + 1] = {
						at = M.now + length,
						fn = function() M.fire("SOUNDKIT_FINISHED", handle) end,
					}
				end
			end
			return ok, handle
		end,
		IsPlaying = function(handle) return M.handles[handle] and true or false end,
		GetSoundScaledVolume = function() return 1.0 end,
	}

	env.CreateColor = function(r, g, b, a)
		return { r = r, g = g, b = b, a = a,
		         GetRGBA = function(s) return s.r, s.g, s.b, s.a end }
	end

	env.wipe = function(t)
		for k in pairs(t) do t[k] = nil end
		return t
	end
	-- WoW's own aliases for the table and string libraries. Present on every
	-- client and used by every addon, so code that reaches for them is correct
	-- and the mock has to supply them.
	env.tinsert = table.insert
	env.tremove = table.remove
	env.tContains = function(t, v)
		for _, x in ipairs(t) do if x == v then return true end end
		return false
	end
	env.strsplit = function(sep, str)
		local out = {}
		for piece in tostring(str):gmatch("[^" .. sep .. "]+") do out[#out + 1] = piece end
		return unpack(out)
	end
	env.SlashCmdList = {}
	env.GetBuildInfo = function()
		-- Note the fourth return. It is 16001 on this client, not >= 100000, so
		-- any retail-era interface-number check mis-branches here.
		return "1.60.1", "70338", "2026-09-17", 16001
	end
	env.GetPhysicalScreenSize = function() return M.width, M.height end
	env.GetLocale = function() return "enUS" end
	env.UnitName = function() return "Tester" end
	env.GetAddOnMetadata = function(_, field)
		return ({ Version = "2.0.0", Title = "Duskfall" })[field]
	end

	-- Settings API. Present so a stub panel can be written, but registration is
	-- recorded rather than honoured: whether Forever hosts a panel at all is
	-- unverified, and AddSearchTags is already known to raise here.
	env.Settings = {
		RegisterCanvasLayoutCategory = function(frame, name)
			local cat = {
				frame = frame, name = name, ID = name,
				-- Known to raise ADDON_ACTION_FORBIDDEN on Forever. Reproduced,
				-- because a probe that does not survive it is useless.
				AddSearchTags = function()
					error("ADDON_ACTION_FORBIDDEN: AddSearchTags", 2)
				end,
			}
			M.settingsCategories = M.settingsCategories or {}
			M.settingsCategories[#M.settingsCategories + 1] = cat
			return cat
		end,
		RegisterAddOnCategory = function(cat) M.settingsRegistered = cat end,
		OpenToCategory = function(id) M.settingsOpened = id end,
	}

	return env
end

--------------------------------------------------------------------------------
-- Inspection helpers, for specs
--------------------------------------------------------------------------------

function M.frameNamed(name)
	for _, f in ipairs(M.frames) do
		if f._name == name then return f end
	end
end

-- Textures on a frame, in creation order. The addon keys its layers by order
-- and sublevel, so a spec that wants "the MOD quad" asks by blend mode instead.
function M.texturesOf(frame, blend)
	local out = {}
	for _, t in ipairs(frame._textures) do
		if not blend or t.blend == blend then out[#out + 1] = t end
	end
	return out
end

function M.playedSince(index)
	local out = {}
	for i = index + 1, #M.sounds do out[#out + 1] = M.sounds[i] end
	return out
end

function M.printedMatching(pattern)
	local out = {}
	for _, line in ipairs(M.printed) do
		if line:find(pattern) then out[#out + 1] = line end
	end
	return out
end

return M

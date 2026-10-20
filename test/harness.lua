-- Spec runner and world builder.
--
-- Every spec gets a world of its own: a fresh environment table, a fresh mock,
-- and a fresh load of the addon chunk. That last part matters more than it
-- looks. The addon is one file full of upvalues (db, overlay, calibOn, fade),
-- and reusing a loaded chunk between specs would carry all of that state across,
-- so a test could pass only because of what the previous one left behind.
-- setfenv is a Lua 5.1 feature and WoW is Lua 5.1, so this is not a trick the
-- real client lacks.

local H = {}

-- Every global name read that the mock did not provide, counted across every
-- world the suite builds. See the __index hook in H.world.
H.unmocked = {}

local root = (...):match("^(.*)%.harness$") or ""
local prefix = (root ~= "" and root .. "." or "")

local DIR = debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$") or "."
local ADDON_FILE = DIR .. "/../ComfyRain/ComfyRain.lua"
local PROBE_FILE = DIR .. "/../ComfyRain/Probe.lua"
local UI_FILE = DIR .. "/../ComfyRain/UI.lua"

--------------------------------------------------------------------------------
-- Assertions
--------------------------------------------------------------------------------

local failures

local function fail(msg)
	error({ spec = true, msg = msg }, 3)
end

function H.ok(cond, what)
	if not cond then fail(what or "expected a truthy value") end
end

function H.eq(got, want, what)
	if got ~= want then
		fail(string.format("%s: expected %s, got %s",
			what or "value", tostring(want), tostring(got)))
	end
end

-- Floats compared with a tolerance, because every colour and alpha in this
-- addon is the output of an interpolation.
function H.near(got, want, tol, what)
	tol = tol or 1e-6
	if type(got) ~= "number" then
		fail(string.format("%s: expected a number near %s, got %s",
			what or "value", tostring(want), tostring(got)))
	end
	if math.abs(got - want) > tol then
		fail(string.format("%s: expected %.4f +/- %.4f, got %.4f",
			what or "value", want, tol, got))
	end
end

function H.lt(got, bound, what)
	if not (type(got) == "number" and got < bound) then
		fail(string.format("%s: expected < %s, got %s",
			what or "value", tostring(bound), tostring(got)))
	end
end

function H.gt(got, bound, what)
	if not (type(got) == "number" and got > bound) then
		fail(string.format("%s: expected > %s, got %s",
			what or "value", tostring(bound), tostring(got)))
	end
end

function H.contains(haystack, needle, what)
	if type(haystack) ~= "string" or not haystack:find(needle, 1, true) then
		fail(string.format("%s: %q does not contain %q",
			what or "string", tostring(haystack), tostring(needle)))
	end
end

--------------------------------------------------------------------------------
-- Building a world
--------------------------------------------------------------------------------

-- opts goes straight to mock.reset: state, cvars, events, missingEvents,
-- canPlaySound, width, height, epoch. Pass loaded = false to get the world
-- without booting the addon, for specs about loading itself.
function H.world(opts)
	opts = opts or {}

	-- Every world starts from the same seed unless a spec sets its own after
	-- this call. The addon is full of deliberate jitter - lightning intervals,
	-- gust phase, bed relaunch offsets - and specs that assert "a strike
	-- happened within 200 seconds" are sampling a log-normal with a 3.2x
	-- ceiling, so an unseeded suite fails a few percent of the time on code
	-- that is perfectly correct. A fixed seed makes a red CI run mean
	-- something. Specs that need a different draw reseed themselves.
	math.randomseed(20261019)

	package.loaded[prefix .. "wowmock"] = nil
	local mock = require(prefix .. "wowmock")
	mock.reset(opts)

	-- Inherit the stdlib but keep every global the addon writes (ComfyRainDB,
	-- SLASH_COMFYRAIN1, ComfyRain_Refresh) inside this world.
	--
	-- __index fires only for a name the mock did NOT provide, which makes it a
	-- free audit of the gap between the two: anything that lands here is either
	-- Lua stdlib, something the addon writes itself, or a client API nobody is
	-- modelling. That last case is the dangerous one - the addon reads nil in
	-- every spec and something else entirely in the client, so the tested path
	-- and the shipped path are different ones. Found SOUNDKIT exactly that way.
	-- run.lua checks the accumulated list against a written-down allowlist.
	local env = setmetatable({}, { __index = function(_, k)
		H.unmocked[k] = (H.unmocked[k] or 0) + 1
		return _G[k]
	end })
	env._G = env
	mock.install(env)

	local chunk, err = loadfile(ADDON_FILE)
	if not chunk then error("could not load the addon: " .. tostring(err)) end
	setfenv(chunk, env)

	-- Probe.lua is a second chunk in the real TOC, and that separation is the
	-- point of it, so it is loaded as a second chunk here too. Specs that do not
	-- need it pass probe = false and get a world where /comfy probe is absent,
	-- which is also what a shipped build without the file looks like.
	local probe
	if opts.probe ~= false then
		local pchunk, perr = loadfile(PROBE_FILE)
		if not pchunk then error("could not load the probe: " .. tostring(perr)) end
		setfenv(pchunk, env)
		probe = pchunk
	end

	-- UI.lua is the third chunk, and separate for the same reason: the addon
	-- has to work with the window missing, because a player can delete the file
	-- and because every path through the settings panel must survive it.
	local ui
	if opts.ui ~= false then
		local uchunk, uerr = loadfile(UI_FILE)
		if not uchunk then error("could not load the UI: " .. tostring(uerr)) end
		setfenv(uchunk, env)
		ui = uchunk
	end

	local w = { mock = mock, env = env, chunk = chunk }

	function w:load()
		chunk()
		if probe then probe() end
		if ui then ui() end
		mock.fire("ADDON_LOADED", "ComfyRain")
		mock.fire("PLAYER_ENTERING_WORLD")
		return self
	end

	function w:slash(input) return mock.slash("COMFYRAIN", input) end
	function w:advance(s, step) mock.advance(s, step) return self end
	function w:db() return env.ComfyRainDB end

	-- The frames the addon builds, by the names it gives them.
	function w:overlay() return mock.frameNamed("ComfyRainOverlay") end
	function w:tod() return mock.frameNamed("ComfyRainTimeOfDay") end

	-- The MOD quad under the rain: what the world is multiplied by. One per
	-- frame, so asking by blend mode is unambiguous.
	function w:gloom() return mock.texturesOf(self:overlay(), "MOD")[1] end
	function w:dim() return mock.texturesOf(self:tod(), "MOD")[1] end
	function w:lift()
		for _, t in ipairs(mock.texturesOf(self:tod(), "ADD")) do return t end
	end

	-- The three rain layers, in creation order after the gloom quad.
	function w:layers()
		local o, out = self:overlay(), {}
		local names = { "mist", "far", "near" }
		local i = 0
		for _, t in ipairs(o._textures) do
			if t.blend ~= "MOD" and t ~= self:flash() then
				i = i + 1
				if names[i] then out[names[i]] = t end
			end
		end
		return out
	end

	-- The blizzard whiteout: the only ADD colour quad in the ARTWORK layer. The
	-- near snow layer also adds, but it is a texture, not a colour.
	function w:whiteout()
		for _, t in ipairs(self:overlay()._textures) do
			if t.layer == "ARTWORK" and t.blend == "ADD" and t.colour then return t end
		end
	end

	-- The settings window, and the widgets inside it by the name the panel code
	-- knows them by.
	function w:panel() return mock.frameNamed("ComfyRainPanel") end
	function w:open() self.env.ComfyRain_Panel("show") return self:panel() end

	-- Controls are found by the text the player reads, not by an index into a
	-- table the panel happens to keep. A spec that clicks "Snow" is clicking
	-- what somebody with a mouse would click.
	function w:button(text)
		for _, f in ipairs(mock.frames) do
			if (f._kind == "Button" or f._kind == "CheckButton") and f._text == text then
				return f
			end
		end
	end

	-- Anything the window is currently SAYING, found by a pattern over the text
	-- rather than by walking to a widget. A status line is read, not clicked, so
	-- the spec should find it the way the player's eye does.
	function w:says(pattern)
		for _, f in ipairs(mock.frames) do
			for _, fs in ipairs(f._fontStrings or {}) do
				if fs.text and fs.text:match(pattern) then return fs end
			end
		end
	end

	function w:shareBox() return mock.frameNamed("ComfyRainShare") end
	function w:editBox()
		for _, f in ipairs(mock.frames) do
			if f._kind == "EditBox" then return f end
		end
	end

	-- A Select row, found by the label on its left. `.value.text` is what the
	-- player reads in the well, and `.left` / `.right` / `.well` are the three
	-- things they can click.
	function w:select(label)
		for _, f in ipairs(mock.frames) do
			if f._kind == "Frame" and f.well and f.value
				and f.label and f.label.text == label then
				return f
			end
		end
	end

	function w:slider(label)
		for _, f in ipairs(mock.frames) do
			if f._kind == "Slider" and f._parent then
				for _, fs in ipairs(f._parent._fontStrings or {}) do
					if fs.text == label then return f end
				end
			end
		end
	end

	-- Hover something and read back what the game would have drawn into the
	-- tooltip. Returns the rows, which carry each line's colour and wrap flag,
	-- and the text joined for a plain `contains`. A warning that is not red and
	-- a two-sentence note that does not wrap are both wrong in ways the text on
	-- its own cannot show.
	function w:hover(widget)
		self.env.GameTooltip:ClearLines()
		local enter = widget and widget.GetScript and widget:GetScript("OnEnter")
		if not enter then return nil, "" end
		enter(widget)
		return self.env.GameTooltip.rows,
			table.concat(self.env.GameTooltip.lines, " | ")
	end

	-- Every button and slider the window is currently showing, by walking up to
	-- the panel rather than by trusting a list somebody maintains by hand.
	function w:hoverables()
		local panel, found = self:panel(), {}
		for _, f in ipairs(mock.frames) do
			if f._kind == "Button" or f._kind == "CheckButton" or f._kind == "Slider" then
				local at, hidden = f, false
				while at do
					if at._shown == false then hidden = true end
					if at == panel then
						if not hidden then found[#found + 1] = f end
						break
					end
					at = at._parent
				end
			end
		end
		return found
	end

	-- Every word the window is currently showing, as one string. Walks up to
	-- the panel the same way hoverables() does, so a line inside a row that
	-- Relayout has hidden does not count as being on screen.
	function w:panelText()
		local panel, out = self:panel(), {}
		for _, f in ipairs(mock.frames) do
			local at, hidden = f, false
			while at do
				if at._shown == false then hidden = true end
				if at == panel then break end
				at = at._parent
			end
			if at == panel and not hidden then
				for _, fs in ipairs(f._fontStrings or {}) do
					if fs.text then out[#out + 1] = fs.text end
				end
			end
		end
		return table.concat(out, "\n")
	end

	function w:flash()
		local o = self:overlay()
		for _, t in ipairs(o._textures) do
			if t.layer == "OVERLAY" then return t end
		end
	end

	-- Everything the player can SEE, as one block of text.
	--
	-- Every other accessor above answers one question, which is right for a
	-- spec that is about one thing and is why the Darkness ceiling survived 234
	-- of them: no spec was wrong, and none of them was looking at the shape of
	-- the whole surface. This is the second instrument. A committed golden file
	-- of these blocks across the settings matrix turns "does it still look the
	-- same" into a git diff, so a change to one preset cannot quietly move
	-- another, and a change that is meant to move things has to be reviewed as
	-- a number before it ships.
	--
	-- Base state only: no advance, so no gust phase and no lightning jitter.
	-- Four decimals because these are all interpolations and the last bit of a
	-- float is not a behaviour anybody is defending.
	function w:snapshot()
		local out = {}
		local function n(v)
			if type(v) ~= "number" then return tostring(v) end
			return string.format("%.4f", v)
		end
		local function line(k, v) out[#out + 1] = k .. " = " .. v end

		local o = self:overlay()
		line("overlay.shown", tostring(o and o:IsShown() or false))
		line("overlay.alpha", n(o and o:GetAlpha()))

		local g = self:gloom()
		line("gloom", g and (n(g.colour[1]) .. ", " .. n(g.colour[2]) ..
			", " .. n(g.colour[3])) or "none")

		local layers = self:layers()
		for _, name in ipairs({ "mist", "far", "near" }) do
			local t = layers[name]
			if t then
				local tint, tc = t.vertexColour, t.texCoord
				line(name, n(t:GetAlpha()) ..
					"  tex " .. tostring(t:GetTexture()) ..
					"  blend " .. tostring(t.blend) ..
					-- Where the sheet has scrolled to. Zero in every static
					-- block, which is itself the claim that nothing moves
					-- before time passes, and the whole payload of the motion
					-- golden where time does.
					(tc and ("  at " .. n(tc[1]) .. ", " .. n(tc[3])) or "  at none") ..
					(tint and ("  tint " .. n(tint[1]) .. ", " .. n(tint[2]) ..
						", " .. n(tint[3])) or ""))
			else
				line(name, "none")
			end
		end

		local wo = self:whiteout()
		line("whiteout", wo and n(wo:GetAlpha()) or "none")
		local fl = self:flash()
		line("flash", fl and n(fl:GetAlpha()) or "none")

		local tod = self:tod()
		line("curtain.shown", tostring(tod and tod:IsShown() or false))
		local d, l = self:dim(), self:lift()
		line("curtain.dim", (d and d.colour) and (n(d.colour[1]) .. ", " ..
			n(d.colour[2]) .. ", " .. n(d.colour[3])) or "none")
		line("curtain.lift", l and n(l:GetAlpha()) or "none")

		return table.concat(out, "\n")
	end

	if opts.loaded ~= false then w:load() end
	return w
end

--------------------------------------------------------------------------------
-- Golden files
--------------------------------------------------------------------------------

-- Set by run.lua when the suite is run with --update.
H.updateGolden = false

-- Compare a generated block against a committed file. The point is not that
-- the numbers in the file are right - nobody can tell by reading them - it is
-- that a change to any of them shows up as a reviewable diff in the commit
-- that caused it, instead of being found later by playing the game.
function H.golden(name, text)
	local path = DIR .. "/" .. name
	if H.updateGolden then
		local out, err = io.open(path, "w")
		if not out then fail("could not write " .. name .. ": " .. tostring(err)) end
		out:write(text)
		out:close()
		return
	end

	local f = io.open(path, "r")
	if not f then
		fail(name .. " is missing. Run `lua run.lua --update` to write it, then " ..
			"read the diff before committing it.")
	end
	local have = f:read("*a")
	f:close()
	if have == text then return end

	-- Name the first line that moved. A whole-file dump in a failure message is
	-- unreadable, and the first difference is almost always the cause.
	local mine, theirs = {}, {}
	for l in text:gmatch("([^\n]*)\n?") do mine[#mine + 1] = l end
	for l in have:gmatch("([^\n]*)\n?") do theirs[#theirs + 1] = l end
	for i = 1, math.max(#mine, #theirs) do
		if mine[i] ~= theirs[i] then
			fail(string.format(
				"%s line %d changed.\n        was:  %s\n        now:  %s\n" ..
				"      If that is the change you meant, run `lua run.lua --update` " ..
				"and commit the diff.",
				name, i, tostring(theirs[i]), tostring(mine[i])))
		end
	end
	fail(name .. " differs in trailing whitespace")
end

--------------------------------------------------------------------------------
-- Running
--------------------------------------------------------------------------------

local specs = {}

function H.it(name, fn) specs[#specs + 1] = { name = name, fn = fn } end

-- Names that are SUPPOSED to fall through, each for a stated reason. Anything
-- here that is a client API is one the addon must survive the absence of, and
-- there is a spec for each of those; anything else is Lua or ours.
local EXPECTED_UNMOCKED = {
	-- Lua 5.1 itself.
	ipairs = true, pairs = true, pcall = true, select = true, type = true,
	tonumber = true, tostring = true, math = true, string = true, table = true,
	unpack = true, setmetatable = true, getmetatable = true, error = true,
	next = true, rawget = true, rawset = true, assert = true, print = true,
	os = true, io = true, debug = true,
	-- Written by the addon before it is read, or by an older version of it.
	ComfyRainDB = true, DuskfallDB = true, AlwaysRainDB = true,
	ComfyRainAPI = true, ComfyRain_Panel = true, ComfyRain_Probe = true,
	ComfyRain_Refresh = true, ComfyRain_Minimap = true, ComfyRainPanel = true,
	ComfyRain_Settings = true,
	ComfyRainShare = true,
	-- Deliberately absent so the "this client cannot do it" path is the one
	-- under test. Screenshot is set by the mock only when the client allows
	-- screenshots, which is the point of the screenshotBlocked option.
	Screenshot = true,
	-- Same shape: modelled by default, and removed on purpose in the one world
	-- that asks what happens on a client with no options API. Whether Forever
	-- has one is unverified and the client is gone, so the no-API path is the
	-- one that must be proven harmless.
	Settings = true,
}

-- Client globals the addon read that nothing modelled. Sorted, for a message.
function H.strayGlobals()
	local out = {}
	for k in pairs(H.unmocked) do
		if not EXPECTED_UNMOCKED[k] then out[#out + 1] = k end
	end
	table.sort(out)
	return out
end

function H.run(files)
	for _, f in ipairs(files) do require(prefix .. f) end

	local passed, failed = 0, {}
	for _, spec in ipairs(specs) do
		local ok, err = pcall(spec.fn)
		if ok then
			passed = passed + 1
		else
			local msg = (type(err) == "table" and err.spec) and err.msg or tostring(err)
			failed[#failed + 1] = { name = spec.name, msg = msg }
		end
	end

	for _, f in ipairs(failed) do
		io.write(string.format("FAIL  %s\n      %s\n", f.name, f.msg))
	end
	io.write(string.format("%d passed, %d failed, %d total\n",
		passed, #failed, #specs))

	local strays = H.strayGlobals()
	if #strays > 0 then
		io.write("\nGLOBALS NOTHING MODELS: " .. table.concat(strays, ", ") ..
			"\nThe addon read each of these and the mock does not provide it, so " ..
			"every spec\nsaw nil where the client will not. Model it in " ..
			"wowmock.lua, or add it to\nEXPECTED_UNMOCKED in harness.lua with " ..
			"a reason.\n")
		return false
	end
	return #failed == 0
end

return H

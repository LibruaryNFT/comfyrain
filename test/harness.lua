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

local root = (...):match("^(.*)%.harness$") or ""
local prefix = (root ~= "" and root .. "." or "")

local DIR = debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$") or "."
local ADDON_FILE = DIR .. "/../Duskfall/Duskfall.lua"
local PROBE_FILE = DIR .. "/../Duskfall/Probe.lua"

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

	package.loaded[prefix .. "wowmock"] = nil
	local mock = require(prefix .. "wowmock")
	mock.reset(opts)

	-- Inherit the stdlib but keep every global the addon writes (DuskfallDB,
	-- SLASH_DUSKFALL1, Duskfall_Refresh) inside this world.
	local env = setmetatable({}, { __index = _G })
	env._G = env
	mock.install(env)

	local chunk, err = loadfile(ADDON_FILE)
	if not chunk then error("could not load the addon: " .. tostring(err)) end
	setfenv(chunk, env)

	-- Probe.lua is a second chunk in the real TOC, and that separation is the
	-- point of it, so it is loaded as a second chunk here too. Specs that do not
	-- need it pass probe = false and get a world where /dusk probe is absent,
	-- which is also what a shipped build without the file looks like.
	local probe
	if opts.probe ~= false then
		local pchunk, perr = loadfile(PROBE_FILE)
		if not pchunk then error("could not load the probe: " .. tostring(perr)) end
		setfenv(pchunk, env)
		probe = pchunk
	end

	local w = { mock = mock, env = env, chunk = chunk }

	function w:load()
		chunk()
		if probe then probe() end
		mock.fire("ADDON_LOADED", "Duskfall")
		mock.fire("PLAYER_ENTERING_WORLD")
		return self
	end

	function w:slash(input) return mock.slash("DUSKFALL", input) end
	function w:advance(s, step) mock.advance(s, step) return self end
	function w:db() return env.DuskfallDB end

	-- The frames the addon builds, by the names it gives them.
	function w:overlay() return mock.frameNamed("DuskfallOverlay") end
	function w:tod() return mock.frameNamed("DuskfallTimeOfDay") end

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

	function w:flash()
		local o = self:overlay()
		for _, t in ipairs(o._textures) do
			if t.layer == "OVERLAY" then return t end
		end
	end

	if opts.loaded ~= false then w:load() end
	return w
end

--------------------------------------------------------------------------------
-- Running
--------------------------------------------------------------------------------

local specs = {}

function H.it(name, fn) specs[#specs + 1] = { name = name, fn = fn } end

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
	return #failed == 0
end

return H

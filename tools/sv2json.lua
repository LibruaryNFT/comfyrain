-- Read a WoW SavedVariables file and print it as JSON.
--
-- A SavedVariables file is plain Lua: a sequence of global assignments. So the
-- only correct parser for it is Lua, and anything regex-shaped would be a
-- guess. It is loaded in an empty environment with no stdlib reachable, because
-- it is a file written by a game client and there is no reason to let it call
-- anything.
--
--   lua tools/sv2json.lua <path> <globalName>

local path, name = ...
if not path or not name then
	io.stderr:write("usage: sv2json.lua <file> <globalName>\n")
	os.exit(2)
end

local chunk, err = loadfile(path)
if not chunk then
	io.stderr:write("cannot read " .. path .. ": " .. tostring(err) .. "\n")
	os.exit(1)
end

local sandbox = {}
setfenv(chunk, sandbox)
local ok, lerr = pcall(chunk)
if not ok then
	io.stderr:write("cannot evaluate " .. path .. ": " .. tostring(lerr) .. "\n")
	os.exit(1)
end

local function esc(s)
	s = s:gsub('[%c"\\]', function(c)
		local map = { ['"'] = '\\"', ['\\'] = '\\\\', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t' }
		return map[c] or string.format("\\u%04x", c:byte())
	end)
	return '"' .. s .. '"'
end

local encode

-- A Lua table is an array, a map, or both. The distinction is invented here,
-- so it is made explicitly rather than implied: contiguous 1..n is an array.
local function isArray(t)
	local n = 0
	for k in pairs(t) do
		if type(k) ~= "number" then return false end
		n = n + 1
	end
	for i = 1, n do if t[i] == nil then return false end end
	return n > 0
end

function encode(v)
	local tv = type(v)
	if tv == "nil" then return "null" end
	if tv == "boolean" then return tostring(v) end
	if tv == "number" then
		if v ~= v or v == math.huge or v == -math.huge then return "null" end
		return string.format("%.14g", v)
	end
	if tv == "string" then return esc(v) end
	if tv ~= "table" then return esc(tostring(v)) end

	if isArray(v) then
		local out = {}
		for _, item in ipairs(v) do out[#out + 1] = encode(item) end
		return "[" .. table.concat(out, ",") .. "]"
	end

	local keys = {}
	for k in pairs(v) do keys[#keys + 1] = k end
	table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
	local out = {}
	for _, k in ipairs(keys) do
		out[#out + 1] = esc(tostring(k)) .. ":" .. encode(v[k])
	end
	return "{" .. table.concat(out, ",") .. "}"
end

print(encode(sandbox[name]))

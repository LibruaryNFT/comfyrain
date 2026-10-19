-- Read the doorway log out of SavedVariables and say which doorways were wrong.
--
-- The indoor question is the one thing in this addon that cannot be settled by
-- reading the source. IsIndoors() and IsOutdoors() are not complements, and the
-- third state - neither one true - is a real awning in the open world and may
-- also be an open street in a city built as one big WMO. Those want opposite
-- answers. Sheltered() currently calls that state indoors, which is a decision
-- taken on reasoning and never once confirmed against the client.
--
-- So: walk a route, log out, run this. The addon writes a row on every
-- committed transition by itself, which means the measurement costs no typing
-- at the moment the player is busy looking at the thing. The first five rows
-- off the live client were all two-state, so the awning case had still never
-- been observed when this was written.
--
-- The SavedVariables file is Lua, so it is loaded as Lua rather than scraped.
-- It is written by our own client from our own addon's table.
--
-- Usage: lua tools/where_report.lua [path/to/ComfyRain.lua]

local DEFAULT = os.getenv("HOME") ..
	"/Games/battlenet/pfx/drive_c/Program Files (x86)/World of Warcraft/" ..
	"_classic_beta_/WTF/Account/916451#1/SavedVariables/ComfyRain.lua"

local path = arg[1] or DEFAULT

local chunk, err = loadfile(path)
if not chunk then
	io.stderr:write("could not read the saved variables: " .. tostring(err) .. "\n")
	os.exit(1)
end

-- The file assigns globals. Catch them in a table of our own rather than
-- letting a game-written file land in _G.
local sv = {}
setfenv(chunk, sv)
local ok, loadErr = pcall(chunk)
if not ok then
	io.stderr:write("saved variables did not load: " .. tostring(loadErr) .. "\n")
	os.exit(1)
end

local db = sv.ComfyRainDB
local log = db and db.where

if not log or #log == 0 then
	io.write("No doorway readings in " .. path .. "\n\n" ..
		"The log is written on every committed indoor/outdoor transition and by\n" ..
		"/comfy where. Zero rows means either the addon has not run since the\n" ..
		"log was added, or the game has not written SavedVariables yet - that\n" ..
		"happens on /reload and on logout, not continuously.\n")
	os.exit(1)
end

--------------------------------------------------------------------------------

local function flags(e)
	if e.indoors and not e.outdoors then return "indoors" end
	if e.outdoors and not e.indoors then return "open" end
	if e.indoors and e.outdoors then return "BOTH" end
	return "NEITHER"
end

local function place(e)
	local where = e.zone or "?"
	if e.subzone and e.subzone ~= "" then where = where .. " / " .. e.subzone end
	if e.x then
		where = where .. string.format("  %.1f,%.1f", e.x * 100, e.y * 100)
	end
	return where
end

io.write(string.format("%d doorway readings from %s\n\n", #log, path))
io.write(string.format("%-8s %-9s %-9s %-9s %s\n",
	"when", "reason", "flags", "verdict", "where"))
io.write(string.rep("-", 78) .. "\n")

local counts = { indoors = 0, open = 0, NEITHER = 0, BOTH = 0 }
local noCoord, lastAt, flips = 0, nil, 0

for _, e in ipairs(log) do
	local f = flags(e)
	counts[f] = (counts[f] or 0) + 1
	if not e.x then noCoord = noCoord + 1 end
	-- Two committed transitions inside a few seconds of each other is the
	-- flicker signature: the debounce let a doorway lip toggle the overlay
	-- twice while the player walked through it once.
	if lastAt and e.at and (e.at - lastAt) <= 3 then flips = flips + 1 end
	lastAt = e.at
	io.write(string.format("%-8s %-9s %-9s %-9s %s\n",
		e.at and os.date("%H:%M:%S", e.at) or "?",
		e.reason or "?", f,
		e.sheltered and "SHELTERED" or "open sky",
		place(e)))
end

io.write("\n")

--------------------------------------------------------------------------------
-- What the rows mean, which is the part worth having

io.write(string.format("two-state (one flag set): %d of %d\n",
	counts.indoors + counts.open, #log))

if counts.NEITHER == 0 then
	io.write(
		"NEITHER-flag readings: 0.\n" ..
		"  Every reading here was a clean indoors-or-open. The awning case that\n" ..
		"  Sheltered() exists to handle has still not been seen on this client,\n" ..
		"  so the decision to treat it as indoors remains untested rather than\n" ..
		"  confirmed. That is not the same as it being wrong: walk under an\n" ..
		"  awning, a bridge and a cave mouth and run this again.\n")
else
	io.write(string.format(
		"NEITHER-flag readings: %d. The third state is REAL on this client.\n" ..
		"  Each of these is a spot where the engine says neither indoors nor\n" ..
		"  outdoors and the addon chose to stop the rain. Check the coordinates\n" ..
		"  above against where you actually were: under a roof is correct, an\n" ..
		"  open street is the false positive that kills the feature.\n",
		counts.NEITHER))
end

if counts.BOTH > 0 then
	io.write(string.format(
		"BOTH flags set: %d. This should be impossible and the logic above does\n" ..
		"  not account for it. Report the rows.\n", counts.BOTH))
end

if flips > 0 then
	io.write(string.format(
		"flicker: %d transitions landed within 3s of the one before. The " ..
		"overlay\n  toggled twice while you walked through one doorway. " ..
		"ENTER_IN / ENTER_OUT\n  in ComfyRain.lua are the debounce.\n", flips))
end

if noCoord > 0 then
	io.write(string.format(
		"%d readings have no coordinate. Rows written before the position was\n" ..
		"  added are expected; new ones mean the client refused the position.\n",
		noCoord))
end

#!/usr/bin/env lua
-- Run the suite:  lua test/run.lua
--
-- Lua 5.1, because that is what WoW runs. A 5.2+ construct that would fail in
-- the client fails here too, which is most of the point.

local here = arg[0]:match("^(.*)/[^/]*$") or "."
package.path = here .. "/?.lua;" .. here .. "/../?.lua;" .. package.path

if _VERSION ~= "Lua 5.1" then
	io.write("warning: this is ", _VERSION,
		". WoW runs Lua 5.1, so a passing suite here proves less than it looks.\n")
end

local H = require("harness")

-- --update rewrites the golden files instead of checking against them. The
-- diff it leaves in the working tree is the thing to review; committing one
-- without reading it defeats the point of having them.
for _, a in ipairs(arg) do
	if a == "--update" then
		H.updateGolden = true
		io.write("--update: rewriting golden files. Read the diff.\n")
	end
end

local SPECS = {
	"spec_boot",
	"spec_timeofday",
	"spec_visuals",
	"spec_math",
	"spec_sound",
	"spec_calib",
	"spec_snow",
	"spec_ui",
	"spec_probe",
	"spec_sweep",
	"spec_perceive",
}

os.exit(H.run(SPECS) and 0 or 1)

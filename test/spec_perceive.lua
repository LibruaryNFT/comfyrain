-- Every control in the window, clicked, against the command it stands for.
--
-- tools/perceive.py renders what each typed command puts on screen and fails
-- any two a player could not tell apart. That judges the commands. This judges
-- the window: each control, operated the way a mouse would, has to leave the
-- screen and the speakers exactly where typing its command does, and somewhere
-- other than where they were before the click. Together the two mean a click
-- in the window is a change a player can see or hear.
--
-- Compared on w:perceivable(), what is drawn and what is sounding, rather than
-- on the saved settings: a control that saved the right value and never
-- refreshed the overlay would pass a settings check and still do nothing.

local H = require("harness")
local it, ok = H.it, H.ok

-- Thunder and gusts come and go, so a moment's snapshot cannot tell on from
-- off. These cases listen for a while and add every file that started.
local LISTEN = 240

local function view(w, listen)
	w:advance(2, 0.05)
	local p = w:perceivable()
	if listen then
		local first, seen = #w.mock.sounds + 1, {}
		w:advance(listen, 0.25)
		p.started = {}
		for k = first, #w.mock.sounds do
			local s = w.mock.sounds[k]
			if s.ok and not seen[tostring(s.file)] then
				seen[tostring(s.file)] = true
				p.started[#p.started + 1] = tostring(s.file)
			end
		end
		table.sort(p.started)
	end
	return p
end

-- The first difference between two views, or nil. Not exact, because the two
-- paths do not draw from the random stream identically (a slider fires its
-- command more than once on the way), and that stream feeds the gust, which
-- breathes the gloom, and the 7% gain wobble each clip launches with. So light
-- gets 0.01, a hundredth of a multiplier and well under anything visible, and
-- volume 15%.
local function diff(a, b)
	local function num(x, y, what, tol)
		if math.abs((x or 0) - (y or 0)) > (tol or 0.01) then
			return string.format("%s %.4g vs %.4g", what, x or 0, y or 0)
		end
	end
	if a.shown ~= b.shown then return "shown " .. tostring(a.shown) .. " vs " .. tostring(b.shown) end
	local d = num(a.alpha, b.alpha, "overlay alpha") or num(a.whiteout, b.whiteout, "whiteout")
		or num(a.lift, b.lift, "lift")
	if d then return d end
	for i = 1, 3 do
		d = num(a.gloom[i], b.gloom[i], "gloom") or num(a.dim[i], b.dim[i], "dim")
		if d then return d end
	end
	for _, name in ipairs({ "mist", "far", "near" }) do
		local la, lb = a.layers[name] or {}, b.layers[name] or {}
		if la.texture ~= lb.texture then
			return name .. " texture " .. tostring(la.texture) .. " vs " .. tostring(lb.texture)
		end
		d = num(la.alpha, lb.alpha, name .. " alpha") or num(la.speed, lb.speed, name .. " speed", 1e-3)
			or num(la.tilesY, lb.tilesY, name .. " tiling")
		if d then return d end
	end
	local function key(p)
		local t = {}
		for _, s in ipairs(p.sounds) do t[#t + 1] = tostring(s.file) .. "@" .. tostring(s.channel) end
		table.sort(t)
		return table.concat(t, " ")
	end
	if key(a) ~= key(b) then return "sounds [" .. key(a) .. "] vs [" .. key(b) .. "]" end
	local la, lb = 0, 0
	for _, s in ipairs(a.sounds) do la = la + s.volume end
	for _, s in ipairs(b.sounds) do lb = lb + s.volume end
	if math.abs(la - lb) > 0.15 * math.max(la, lb) then
		return string.format("loudness %.3f vs %.3f", la, lb)
	end
	if table.concat(a.started or {}, " ") ~= table.concat(b.started or {}, " ") then
		return "sounds over time"
	end
end

local function world(case)
	local w = H.world({ state = case.state })
	for k, v in pairs(case.cvars or {}) do w.mock.cvars[k] = v end
	for _, c in ipairs(case.before or {}) do w:slash(c) end
	return w
end

local function click(w, how)
	local kind, label, arg = how[1], how[2], how[3]
	if kind == "select" then
		local s = w:select(label)
		ok(s, label .. " selector exists")
		s[arg or "right"]:Click()
	elseif kind == "check" then
		local b = w:button(label)
		ok(b, label .. " checkbox exists")
		b:Click()
	elseif kind == "slider" then
		local s = w:slider(label)
		ok(s, label .. " slider exists")
		s:Drag(arg)
	end
end

local STORM = { weather = { type = 1, intensity = 0.8 } }

-- { control, how to operate it, the command it stands for, the world it is
-- operated in }. Every control the window has: spec_ui's "keeps the
-- fine-tuning out of the window" holds the list to these.
local CASES = {
	{ "Type, Rain to Snow", { "select", "Type" }, "snow" },
	{ "Type, Rain to Off", { "select", "Type", "left" }, "off" },
	{ "Intensity, light to normal", { "select", "Intensity" }, "normal", before = { "light" } },
	{ "Intensity, normal to heavy", { "select", "Intensity" }, "heavy" },
	{ "Intensity, heavy to monsoon", { "select", "Intensity" }, "monsoon", before = { "heavy" } },
	{ "Intensity, snow normal to heavy", { "select", "Intensity" }, "heavy", before = { "snow" } },
	{ "Intensity, snow heavy to blizzard", { "select", "Intensity" }, "blizzard",
	  before = { "snow", "heavy" } },
	{ "Hide when game rains, in a real storm", { "check", "Hide when game rains" }, "defer off",
	  state = STORM, cvars = { weatherDensity = "3" } },
	{ "Play sounds", { "check", "Play sounds" }, "sound off" },
	{ "Volume", { "slider", "Volume", 0.3 }, "volume 0.30" },
	{ "Thunder", { "check", "Thunder" }, "thunder off", listen = LISTEN },
	{ "Gusts, under snow", { "check", "Gusts" }, "thunder off", before = { "snow" }, listen = LISTEN },
	{ "Indoors, standing inside", { "select", "Indoors" }, "indoors on",
	  state = { indoors = true }, before = { "indoors dim" } },
	{ "Volume follows", { "select", "Volume follows" }, "channel sfx" },
	{ "Mode, Off to My PC clock", { "select", "Mode" }, "time local",
	  state = { gameHour = 3 }, before = { "time off" } },
	{ "Hour, held", { "slider", "Hold at Hour", 21 }, "time 21", state = { gameHour = 12 }, before = { "time 12" } },
	{ "Hour, shifted", { "slider", "Shift by Hours", 9 }, "time +9", state = { gameHour = 12 }, before = { "time +0" } },
	{ "Strength", { "slider", "Strength", 0.5 }, "time strength 0.50",
	  state = { gameHour = 12 }, before = { "time 21" } },
}

for _, case in ipairs(CASES) do
	local name, how, command = case[1], case[2], case[3]
	it("the window's " .. name .. " is what /comfy " .. command .. " does, and shows", function()
		local w = world(case)
		w:open()
		local before = view(w, case.listen)
		click(w, how)
		local clicked = view(w, case.listen)

		local t = world(case)
		view(t, case.listen)
		t:slash(command)
		local typed = view(t, case.listen)

		local d = diff(clicked, typed)
		ok(d == nil, "clicking it lands where typing it does" .. (d and (": " .. d) or ""))
		ok(diff(before, clicked) ~= nil, "and somewhere other than where it started")
	end)
end

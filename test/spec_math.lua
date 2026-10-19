-- The arithmetic, pinned.
--
-- Written 2026-10-16 after an audit of every formula in the addon found four
-- real errors that no existing spec could have caught, because every spec until
-- now asserted behaviour the player can name ("snow drifts", "it darkens") and
-- none of them asserted that a constant meant what its comment said.
--
-- The rule these follow: if a number in the source is justified by a sentence
-- of maths, there is a spec here that checks the sentence.

local H = require("harness")
local it, eq, ok, near, lt, gt = H.it, H.eq, H.ok, H.near, H.lt, H.gt

-- How far a layer's image travelled DOWN THE SCREEN, as a fraction of screen
-- heights. The texture coordinate is not that number: the screen shows tilesY
-- copies of the sheet, so a step of 0.1 in texture space moves the picture
-- 0.1/tilesY of a screen. Getting this wrong in the addon is exactly the bug
-- these specs exist for, so it is spelled out rather than shared with it.
local function screenTravel(w, key, seconds, step)
	local l = w:layers()[key]
	local total, last = 0, nil
	local n = math.floor(seconds / step)
	for _ = 1, n do
		w:advance(step, step)
		local c = l.texCoord
		local tilesY = c[4] - c[3]
		local y = c[3]
		if last then
			local d = last - y             -- the window moves UP the sheet
			if d < -0.5 then d = d + 1 elseif d > 0.5 then d = d - 1 end
			total = total + d / tilesY
		end
		last = y
	end
	return total
end

it("falls at the speed the preset says, whatever its density is", function()
	-- The bug: offsets are texture coordinates and a denser preset tiles the
	-- sheet more times, so for years a fixed texture-space step moved the image
	-- less of a screen. Fall speed was silently divided by density, and `speed`
	-- meant 0.59x to 2.76x what it said depending on which preset read it.
	--
	-- This is the spec that would have caught it: the ratio of two presets'
	-- travel must be the ratio of the two numbers a reader sees in the source,
	-- and the densities deliberately differ between them.
	local function travelOf(intensity)
		local w = H.world()
		w:slash("gust 0")
		w:slash(intensity)
		return screenTravel(w, "far", 6, 0.05), w
	end

	local light = travelOf("light")
	local heavy, w = travelOf("heavy")
	local presets = w.env.ComfyRainAPI.Weather.rain.presets
	ok(presets.light.density ~= presets.heavy.density, "the two densities differ")

	local want = presets.heavy.speed / presets.light.speed
	near(heavy / light, want, 0.02,
		"heavy falls faster than light by exactly the ratio of their speeds")
end)

it("doubling the speed slider doubles the fall, and nothing else moves", function()
	local function travelAt(speed)
		local w = H.world()
		w:slash("gust 0")
		w:slash("speed " .. speed)
		return screenTravel(w, "near", 6, 0.05)
	end
	near(travelAt(2) / travelAt(1), 2, 0.02, "the slider is linear")
end)

it("gusts at the spread the comment claims, not 71% of it", function()
	-- The driving noise is two uniforms summed, which has variance 2/12. To
	-- reach unit variance it needs sqrt(6); the source had sqrt(3), which is
	-- the scale for ONE uniform, so every gust ran at 1/sqrt(2) of its stated
	-- size and the stationary spread was 0.46 against a documented 0.65.
	--
	-- Measured off the near layer's alpha, which is the only place the follower
	-- is observable from outside: alpha = base * (1 + lag * 0.10 * amp).
	local w = H.world()
	w:slash("normal")            -- amp 1.0, so the recovered number is the lag
	local l = w:layers().near
	local base = l:GetAlpha()    -- before a single gust step has run

	local sum, sumsq, n = 0, 0, 0
	for _ = 1, 8000 do
		w:advance(0.05, 0.05)
		local lag = (l:GetAlpha() / base - 1) / 0.10
		sum, sumsq, n = sum + lag, sumsq + lag * lag, n + 1
	end
	local mean = sum / n
	local sd = math.sqrt(sumsq / n - mean * mean)

	near(mean, 0, 0.12, "a mean-reverting process sits on zero")
	-- sigma * sqrt(tau/2) = 0.35 * sqrt(3.5) = 0.655, less a little from the
	-- clamp at 1.6 and the near layer's own 0.17 s lag.
	gt(sd, 0.52, "not the sqrt(3) spread of 0.46")
	lt(sd, 0.80, "and not wilder than the clamp allows")
end)

it("never lets a gust push a layer outside its own alpha", function()
	local w = H.world()
	w:slash("monsoon")           -- the largest gust amplitude in the addon
	local l = w:layers()
	for _ = 1, 3000 do
		w:advance(0.05, 0.05)
		for _, key in ipairs({ "mist", "far", "near" }) do
			local a = l[key]:GetAlpha()
			ok(a >= 0 and a <= 1, key .. " alpha stayed inside 0..1: " .. tostring(a))
		end
	end
end)

it("keeps the thunder rate out of the fall speed's hands", function()
	-- It used to be derived from it: base = 70 - (speed - 0.8) * 28. Harmless
	-- until the speed numbers were corrected above, at which point a monsoon
	-- would have started thundering every 15 seconds for no stated reason.
	-- Pinned per preset instead, and pinned here.
	local function strikes(speedCmd)
		local w = H.world()
		-- Fixed draws: LogNormal and the gust both read math.random, and a
		-- stochastic count would make this spec flap rather than fail.
		w.env.math = setmetatable({ random = function(a, b)
			if a == nil then return 0.5 end
			if b == nil then return 1 end
			return a
		end }, { __index = math })
		w:slash("speed " .. speedCmd)
		local before = #w.mock.sounds
		w:advance(600, 0.5)
		local n = 0
		for i = before + 1, #w.mock.sounds do
			local f = w.mock.sounds[i].file
			if f and f >= 838830 and f <= 839737 then n = n + 1 end
		end
		return n
	end

	local slow, fast = strikes(0.3), strikes(3)
	gt(slow, 0, "it thunders at all")
	eq(fast, slow, "and exactly as often however fast the rain is falling")
end)

it("puts the lightning flash behind the same two dimmers as everything else", function()
	-- A flash at full strength over rain drawn at a quarter is the one frame
	-- where the overlay stops reading as weather. It ignored both the
	-- visibility slider and the indoor fade until 2026-10-16.
	local function peakFlash(setup)
		local w = H.world()
		setup(w)
		local flash = w:flash()
		local peak = 0
		for _ = 1, 8000 do
			w:advance(0.1, 0.1)
			local a = flash:GetAlpha()
			if a > peak then peak = a end
		end
		return peak
	end

	local full = peakFlash(function(w) w:slash("alpha 1.0") end)
	gt(full, 0, "lightning flashed at all")

	local faint = peakFlash(function(w) w:slash("alpha 0.25") end)
	lt(faint, full * 0.6, "the visibility slider takes the flash down with it")

	local inside = peakFlash(function(w)
		w:advance(0.5)
		w.mock.state.indoors = true
		w:advance(3.0, 0.1)
	end)
	lt(inside, full * 0.6, "and so does being indoors on the default dim setting")
end)

it("runs the thunder through the volume slider, like the rain", function()
	local function loudest(volume)
		local w = H.world()
		w:slash("volume " .. volume)
		local before = #w.mock.sounds
		w:advance(600, 0.5)
		local peak = 0
		for i = before + 1, #w.mock.sounds do
			local s = w.mock.sounds[i]
			if s.file and s.file >= 838830 and s.file <= 839737 then
				local v = s.volumeOverride or 1
				if v > peak then peak = v end
			end
		end
		return peak
	end

	local loud = loudest(1.0)
	gt(loud, 0.8, "thunder plays at full volume by default")
	lt(loudest(0.2), 0.35, "and quietly when the slider is down")
end)

it("hands the realm its loops back when it stands down, and not when it is told to be quiet",
function()
	-- Suppression mutes Blizzard's ambience files so ours is the only weather
	-- audible. The question it is keyed on is "is ComfyRain the weather here",
	-- which is NOT "is ComfyRain making a noise", and getting those two
	-- confused goes wrong in opposite directions:
	--
	--   `sound off` was handing the loops back, so pressing off swapped our
	--   rain for the realm's and the player went on hearing rain. Reported
	--   2026-10-19 as "we cant even turn off the rain sound". Off means
	--   silence, and the box they just unticked is the visible cause.
	--
	--   `indoors off` and a cinematic must still hand them back, because
	--   there ComfyRain has stood down rather than been asked to be quiet,
	--   and a realm muted by an addon that is drawing and playing nothing is
	--   silence with no visible cause at all.
	local function mutedCount(w)
		local n = 0
		for _ in pairs(w.mock.muted or {}) do n = n + 1 end
		return n
	end

	local w = H.world()
	w:slash("suppress on")
	gt(mutedCount(w), 0, "suppression mutes the loops we are not using")

	w:slash("sound off")
	gt(mutedCount(w), 0, "sound off is silence, not the realm's rain instead")
	local quiet = 0
	for _, s in ipairs(w.mock.sounds) do if s.file then quiet = quiet + 1 end end
	w:advance(120, 0.5)
	local after = 0
	for _, s in ipairs(w.mock.sounds) do if s.file then after = after + 1 end end
	eq(after, quiet, "and we are not playing anything either, two minutes on")

	w:slash("sound on")
	gt(mutedCount(w), 0, "still taken when we resume")

	w:slash("off")
	eq(mutedCount(w), 0, "weather off hands every one of them back")
	w:slash("on")

	w:slash("indoors off")
	w:advance(0.5)
	w.mock.state.indoors = true
	w:advance(3.0, 0.1)
	eq(mutedCount(w), 0, "inside with indoors off, the realm is audible again")
end)

it("keeps every gain it asks the client for inside 0 to 1", function()
	local w = H.world()
	for _ = 1, 40 do
		w:slash("heavy")
		w:slash("normal")
	end
	w:advance(300, 0.5)
	local seen = 0
	for _, s in ipairs(w.mock.sounds) do
		local v = s.volumeOverride
		if v then
			seen = seen + 1
			ok(v >= 0 and v <= 1, "volumeOverride in range: " .. tostring(v))
		end
	end
	gt(seen, 20, "and it did ask, many times")
end)

it("reuses one frame for the lightning instead of one per clap", function()
	-- CreateFrame has no inverse in this API, so a frame per thunderclap is a
	-- permanent leak: roughly fifty an hour, forever, for a texture fade.
	local w = H.world()
	-- Past the four-second onboarding, which builds the settings window and
	-- every widget in it. Counting from zero would measure that instead.
	w:advance(10, 0.5)
	local before = #w.mock.frames
	w:advance(900, 0.5)
	local after = #w.mock.frames
	lt(after - before, 4, "a long storm built almost no new frames")
end)

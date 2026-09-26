local DayNight = require("../../src/shared/Logic/DayNight")
local Economy = require("../../src/shared/Config/Economy")

local cfg = Economy.DayNight

return function(t)
	t.test("starts at day 06:00", function()
		local p = DayNight.Get(0, cfg)
		t.eq(p.phase, "Day")
		t.near(p.clockTime, 6)
		t.eq(p.secondsLeft, cfg.DayLength)
	end)

	t.test("mid day is noon", function()
		t.near(DayNight.Get(cfg.DayLength / 2, cfg).clockTime, 12)
	end)

	t.test("night starts at 18:00 and wraps past midnight", function()
		local p = DayNight.Get(cfg.DayLength, cfg)
		t.eq(p.phase, "Night")
		t.near(p.clockTime, 18)
		t.near(DayNight.Get(cfg.DayLength + cfg.NightLength / 2, cfg).clockTime, 0)
	end)

	t.test("cycle repeats", function()
		local cycle = cfg.DayLength + cfg.NightLength
		t.eq(DayNight.Get(cycle * 5 + 10, cfg).phase, "Day")
	end)
end

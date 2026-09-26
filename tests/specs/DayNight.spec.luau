local DayNight = require("../../src/shared/Logic/DayNight")
local Economy = require("../../src/shared/Config/Economy")

local cfg = { DayLength = 600, NightLength = 360 } -- default clock ranges

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

	t.test("custom clock ranges skip dusk and dawn", function()
		local c = { DayLength = 100, NightLength = 100, DayClockStart = 7, DayClockEnd = 17, NightClockStart = 19, NightClockEnd = 5 }
		t.near(DayNight.Get(0, c).clockTime, 7)
		t.near(DayNight.Get(99.999, c).clockTime, 17, 1e-3)
		t.near(DayNight.Get(100, c).clockTime, 19)
		t.near(DayNight.Get(150, c).clockTime, 0)
		t.near(DayNight.Get(199.999, c).clockTime, 5, 1e-3)
	end)

	t.test("the game config keeps midnight in the middle of the night", function()
		local c = Economy.DayNight
		t.near(DayNight.Get(c.DayLength + c.NightLength / 2, c).clockTime % 24, 0, 1e-6)
	end)

	t.test("OffsetTo jumps to the start of the other phase", function()
		local c = Economy.DayNight
		for _, now in { 5, c.DayLength - 1, c.DayLength + 10, 1000 * (c.DayLength + c.NightLength) + 42 } do
			for _, phase in { "Day", "Night" } do
				local offset = DayNight.OffsetTo(now, c, phase)
				t.truthy(offset >= 0)
				t.eq(DayNight.Get(now + offset, c).phase, phase)
				if offset > 0 then
					t.near(DayNight.Get(now + offset, c).progress, 0, 1e-6)
				end
			end
		end
	end)
end

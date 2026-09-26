local DailyReward = require("../../src/shared/Logic/DailyReward")

local cfg = { Rewards = { 100, 200, 300 } }

return function(t)
	t.test("first claim starts a streak", function()
		local s = { LastDay = 0, Streak = 0 }
		local ok, cash, streak = DailyReward.Claim(s, 500, cfg)
		t.truthy(ok)
		t.eq(cash, 100)
		t.eq(streak, 1)
	end)

	t.test("only once per day", function()
		local s = { LastDay = 500, Streak = 1 }
		local ok = DailyReward.Claim(s, 500, cfg)
		t.falsy(ok)
		t.eq(s.Streak, 1)
	end)

	t.test("consecutive days grow the streak and the reward loops", function()
		local s = { LastDay = 0, Streak = 0 }
		local got = {}
		for day = 10, 14 do
			local _, cash = DailyReward.Claim(s, day, cfg)
			table.insert(got, cash)
		end
		t.eq(s.Streak, 5)
		t.eq(table.concat(got, ","), "100,200,300,100,200")
	end)

	t.test("missing a day restarts at 1", function()
		local s = { LastDay = 10, Streak = 4 }
		local _, _, streak = DailyReward.Claim(s, 12, cfg)
		t.eq(streak, 1)
	end)

	t.test("day number from UTC seconds", function()
		t.eq(DailyReward.Day(0), 0)
		t.eq(DailyReward.Day(86399), 0)
		t.eq(DailyReward.Day(86400), 1)
	end)
end

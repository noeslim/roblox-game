local Progression = require("../../src/shared/Logic/Progression")

local cfg = { XpBase = 100, XpGrowth = 1.25 }

return function(t)
	t.test("xp needed grows each level", function()
		t.eq(Progression.XpToNext(1, cfg), 100)
		t.eq(Progression.XpToNext(2, cfg), 125)
		t.eq(Progression.XpToNext(3, cfg), 156)
	end)

	t.test("adding xp levels up and keeps the rest", function()
		local level, xp, gained = Progression.AddXp(1, 90, 40, cfg, 100)
		t.eq(level, 2)
		t.eq(xp, 30)
		t.eq(gained, 1)
	end)

	t.test("several levels at once", function()
		local level, xp, gained = Progression.AddXp(1, 0, 100 + 125 + 10, cfg, 100)
		t.eq(level, 3)
		t.eq(xp, 10)
		t.eq(gained, 2)
	end)

	t.test("capped at max level", function()
		local level, xp = Progression.AddXp(4, 0, 1e9, cfg, 5)
		t.eq(level, 5)
		t.eq(xp, 0)
		local l2, x2, g2 = Progression.AddXp(5, 0, 50, cfg, 5)
		t.eq(l2, 5)
		t.eq(x2, 0)
		t.eq(g2, 0)
	end)

	t.test("zero or negative xp changes nothing", function()
		local level, xp = Progression.AddXp(2, 10, -5, cfg, 100)
		t.eq(level, 2)
		t.eq(xp, 10)
	end)
end

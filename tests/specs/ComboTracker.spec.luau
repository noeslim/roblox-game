local ComboTracker = require("../../src/shared/Logic/ComboTracker")
local Economy = require("../../src/shared/Config/Economy")

return function(t)
	t.test("first sale is x1, chained sales climb", function()
		local c = ComboTracker.new(Economy.Combo)
		t.eq((c:RegisterSale(0)), 1)
		t.eq((c:RegisterSale(5)), 1.1)
		t.eq((c:RegisterSale(12)), 1.2)
	end)

	t.test("combo breaks after the window", function()
		local c = ComboTracker.new(Economy.Combo)
		c:RegisterSale(0)
		c:RegisterSale(5)
		local m, count = c:RegisterSale(20)
		t.eq(m, 1)
		t.eq(count, 1)
	end)

	t.test("multiplier is capped", function()
		local c = ComboTracker.new(Economy.Combo)
		local m = 1
		for i = 0, 30 do
			m = c:RegisterSale(i)
		end
		t.eq(m, 2)
	end)

	t.test("GetMultiplier decays to 1 after the window", function()
		local c = ComboTracker.new(Economy.Combo)
		c:RegisterSale(0)
		c:RegisterSale(1)
		t.eq(c:GetMultiplier(3), 1.1)
		t.eq(c:GetMultiplier(100), 1)
	end)
end

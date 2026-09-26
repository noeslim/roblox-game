local DealScene = require("../../src/shared/Logic/DealScene")
local Cinematics = require("../../src/shared/Config/Cinematics")

local cfg = Cinematics.Deal

return function(t)
	t.test("phases follow each other", function()
		local plan = DealScene.Plan(cfg)
		local order = {}
		local last = nil
		local time = 0
		while time <= plan.total + 0.1 do
			local p = DealScene.Phase(plan, time)
			if p ~= last then
				table.insert(order, p)
				last = p
			end
			time += 0.05
		end
		t.eq(table.concat(order, ","), "intro,place,inspect,pay,take,shake,count,outro,done")
		t.truthy(plan.total > 6 and plan.total < 12)
	end)

	t.test("bills are counted one by one during the count", function()
		local plan = DealScene.Plan(cfg)
		t.eq(DealScene.BillsCounted(plan, plan.count - 0.1, 10), 0)
		t.eq(DealScene.BillsCounted(plan, plan.outro, 10), 10)
		local last = 0
		local time = plan.count
		while time < plan.outro do
			local n = DealScene.BillsCounted(plan, time, 10)
			t.truthy(n >= last and n - last <= 1)
			last = n
			time += 0.02
		end
	end)
end

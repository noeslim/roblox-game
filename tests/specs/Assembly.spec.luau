local Assembly = require("../../src/shared/Logic/Assembly")
local Cinematics = require("../../src/shared/Config/Cinematics")
local Economy = require("../../src/shared/Config/Economy")

local cfg = Cinematics.Craft
local all = { Body = true, Barrel = true, Stock = true, Sight = true, Magazine = true }

return function(t)
	t.test("the body goes first, then the slots in order; the magazine is loaded later", function()
		local plan = Assembly.Plan(all, Economy.Crafting.Slots, cfg)
		t.eq(plan.steps[1].slot, "Body")
		t.eq(#plan.steps, 4)
		t.eq(plan.load.slot, "Magazine")
		t.truthy(plan.load.start >= plan.liftStart)
		for i = 2, #plan.steps do
			t.truthy(plan.steps[i].start >= plan.steps[i - 1].done, "parts overlap")
		end
	end)

	t.test("missing slots are skipped", function()
		local plan = Assembly.Plan({ Body = true, Barrel = true }, Economy.Crafting.Slots, cfg)
		t.eq(#plan.steps, 2)
		t.eq(plan.steps[2].slot, "Barrel")
	end)

	t.test("phases follow each other and end", function()
		local plan = Assembly.Plan(all, Economy.Crafting.Slots, cfg)
		t.eq(Assembly.Phase(plan, 0), "intro")
		t.eq(Assembly.Phase(plan, plan.steps[1].start + 0.01), "assemble")
		t.eq(Assembly.Phase(plan, plan.screwStart + 0.01), "screw")
		t.eq(Assembly.Phase(plan, plan.liftStart + 0.01), "lift")
		t.eq(Assembly.Phase(plan, plan.loadStart + 0.01), "load")
		t.eq(Assembly.Phase(plan, plan.rackStart + 0.01), "rack")
		t.eq(Assembly.Phase(plan, plan.testStart + 0.01), "test")
		t.eq(Assembly.Phase(plan, plan.inspectStart + 0.01), "inspect")
		t.eq(Assembly.Phase(plan, plan.outroStart + 0.01), "outro")
		t.eq(Assembly.Phase(plan, plan.total), "done")
		t.truthy(plan.total > 8 and plan.total < 16, "total " .. plan.total)
	end)

	t.test("a part goes tray -> pick -> carry -> seat -> fitted", function()
		local plan = Assembly.Plan(all, Economy.Crafting.Slots, cfg)
		local step = plan.steps[3]
		local order = {}
		local last = nil
		local time = 0
		while time < plan.total do
			local phase, u = Assembly.PartState(step, time)
			t.truthy(u >= 0 and u <= 1)
			if phase ~= last then
				table.insert(order, phase)
				last = phase
			end
			time += 0.01
		end
		t.eq(table.concat(order, ","), "tray,pick,carry,seat,fitted")
		t.eq(Assembly.Current(plan, step.carry), step)
		t.falsy(Assembly.Current(plan, plan.screwStart + 0.01))
	end)

	t.test("smooth is an ease in 0..1", function()
		t.eq(Assembly.Smooth(-1), 0)
		t.eq(Assembly.Smooth(2), 1)
		t.near(Assembly.Smooth(0.5), 0.5, 1e-9)
	end)
end

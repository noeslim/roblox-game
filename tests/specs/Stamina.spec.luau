local Stamina = require("../../src/shared/Logic/Stamina")

local cfg = { Max = 100, SprintDrain = 20, JumpCost = 10, Regen = 10, RegenDelay = 1, ExhaustedBelow = 1, RecoverAbove = 30 }

return function(t)
	t.test("sprinting drains stamina", function()
		local s = Stamina.new(cfg)
		t.eq(Stamina.Step(s, 1, true, true, cfg), "sprint")
		t.near(s.value, 80, 1e-6)
	end)

	t.test("standing still with shift held does not drain", function()
		local s = Stamina.new(cfg)
		t.eq(Stamina.Step(s, 1, true, false, cfg), "walk")
		t.eq(s.value, 100)
	end)

	t.test("empty stamina exhausts until it recovers", function()
		local s = Stamina.new(cfg)
		for _ = 1, 5 do
			Stamina.Step(s, 1, true, true, cfg)
		end
		t.eq(s.value, 0)
		t.eq(Stamina.Step(s, 0.5, true, true, cfg), "exhausted")
		-- regen starts after the delay, exhausted until RecoverAbove
		for _ = 1, 3 do
			t.eq(Stamina.Step(s, 1, false, true, cfg), "exhausted")
		end
		for _ = 1, 3 do
			Stamina.Step(s, 1, false, true, cfg)
		end
		t.truthy(s.value >= 30)
		t.eq(Stamina.Step(s, 0.1, true, true, cfg), "sprint")
	end)

	t.test("regen waits for the delay and caps at max", function()
		local s = Stamina.new(cfg)
		Stamina.Step(s, 1, true, true, cfg)
		Stamina.Step(s, 0.5, false, true, cfg)
		t.near(s.value, 80, 1e-6)
		for _ = 1, 10 do
			Stamina.Step(s, 1, false, false, cfg)
		end
		t.eq(s.value, 100)
	end)

	t.test("jumping costs stamina and is refused when exhausted", function()
		local s = Stamina.new(cfg)
		t.truthy(Stamina.TryJump(s, cfg))
		t.eq(s.value, 90)
		s.value = 5
		t.falsy(Stamina.TryJump(s, cfg))
		s.value, s.exhausted = 50, true
		t.falsy(Stamina.TryJump(s, cfg))
	end)
end

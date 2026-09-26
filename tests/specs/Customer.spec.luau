local Customer = require("../../src/shared/Logic/Customer")
local Economy = require("../../src/shared/Config/Economy")
local Rng = require("../helpers/Rng")

local cfg = Economy.Customers

return function(t)
	t.test("Shady customers never appear during the day", function()
		local rng = Rng.new(7)
		for _ = 1, 1000 do
			t.falsy(Customer.Generate(rng, cfg, false).personality == "Shady")
		end
	end)

	t.test("Shady customers appear at night", function()
		local rng = Rng.new(7)
		local shady = 0
		for _ = 1, 1000 do
			if Customer.Generate(rng, cfg, true).personality == "Shady" then
				shady += 1
			end
		end
		-- weight 20 / 110 ~ 18%
		t.near(shady / 1000, 20 / 110, 0.04)
	end)

	t.test("budget stays in the personality range", function()
		local rng = Rng.new(3)
		for _ = 1, 500 do
			local c = Customer.Generate(rng, cfg, true)
			local p = cfg.Personalities[c.personality]
			t.truthy(c.budgetMultiplier >= p.budgetMin and c.budgetMultiplier <= p.budgetMax)
		end
	end)

	local function make(personality, budget)
		local p = cfg.Personalities[personality]
		return {
			personality = personality,
			budgetMultiplier = budget,
			patience = p.patience,
			tip = p.tip,
			negotiates = p.negotiates,
			minRarity = p.minRarity,
			wantsContraband = p.wantsContraband == true,
		}
	end

	t.test("accept, counter, refuse", function()
		local cheap = make("Cheap", 1.0)
		t.eq(Customer.EvaluateOffer(cheap, 100, 100, cfg), "Accept")
		local d, counter = Customer.EvaluateOffer(cheap, 120, 100, cfg)
		t.eq(d, "Counter")
		t.eq(counter, 100)
		t.eq(Customer.EvaluateOffer(cheap, 130, 100, cfg), "Refuse")

		local rushed = make("Rushed", 1.0)
		t.eq(Customer.EvaluateOffer(rushed, 110, 100, cfg), "Refuse") -- no negotiation
	end)

	t.test("collector wants Rare+, shady wants contraband", function()
		local order = Economy.RarityOrder
		local collector = make("Collector", 1.2)
		t.falsy(Customer.IsInterested(collector, { rarity = "Uncommon", contraband = false }, order))
		t.truthy(Customer.IsInterested(collector, { rarity = "Epic", contraband = false }, order))
		local shady = make("Shady", 1.5)
		t.falsy(Customer.IsInterested(shady, { rarity = "Common", contraband = false }, order))
		t.truthy(Customer.IsInterested(shady, { rarity = "Common", contraband = true }, order))
	end)

	t.test("tip only when served fast", function()
		local rushed = make("Rushed", 1.0)
		t.eq(Customer.Tip(rushed, 200, 5, cfg), 30)
		t.eq(Customer.Tip(rushed, 200, 30, cfg), 0)
	end)
end

local Market = require("../../src/shared/Logic/Market")
local BlackMarket = require("../../src/shared/Logic/BlackMarket")
local Economy = require("../../src/shared/Config/Economy")
local Parts = require("../../src/shared/Config/Parts")

local BM = Economy.BlackMarket
local SD = Economy.StreetDemand

return function(t)
	t.test("each unit bought pushes the price up, capped", function()
		t.eq(Market.UnitPrice(100, 0, BM), 100)
		t.eq(Market.UnitPrice(100, 1, BM), math.floor(100 * (1 + BM.DemandStep) + 0.5))
		t.truthy(Market.UnitPrice(100, 3, BM) > Market.UnitPrice(100, 2, BM))
		t.eq(Market.UnitPrice(100, 1000, BM), math.floor(100 * (1 + BM.MaxRise) + 0.5))
	end)

	t.test("buying two costs the first price plus the next one", function()
		t.eq(Market.Cost(100, 2, 2, BM), Market.UnitPrice(100, 2, BM) + Market.UnitPrice(100, 3, BM))
	end)

	t.test("live offers show what is left", function()
		local stock = { { id = "a", price = 50, quantity = 5 }, { id = "b", price = 80, quantity = 2 } }
		local live = Market.Live(stock, { a = 2, b = 9 }, BM)
		t.eq(live[1].left, 3)
		t.eq(live[1].price, Market.UnitPrice(50, 2, BM))
		t.eq(live[2].left, 0)
	end)

	t.test("every night's offers have a quantity in range", function()
		for night = 1, 30 do
			for _, offer in BlackMarket.Stock(night, Parts, Economy) do
				t.truthy(offer.quantity >= BM.QuantityMin and offer.quantity <= BM.QuantityMax, offer.id)
			end
		end
	end)

	t.test("the hot set is a real set and changes from night to night", function()
		local seen = {}
		for night = 1, 40 do
			local set = Market.HotSet(night, Parts) :: string
			local exists = false
			for _, p in Parts do
				if p.set == set then
					exists = true
				end
			end
			t.truthy(exists, set)
			seen[set] = true
		end
		local n = 0
		for _ in seen do
			n += 1
		end
		t.truthy(n >= 2)
	end)

	t.test("night premium on contraband, hot set bonus, nothing by day", function()
		local ghost = { Body = "ghost_body" }
		local street = { Body = "street_body" }
		t.eq((Market.SaleMultiplier(ghost, true, false, "Ghost", Parts, SD)), 1)
		local m, why = Market.SaleMultiplier(ghost, true, true, "Street", Parts, SD)
		t.near(m, SD.NightContrabandMultiplier)
		t.truthy(why.night)
		t.falsy(why.hot)
		local m2, why2 = Market.SaleMultiplier(street, false, true, "Street", Parts, SD)
		t.near(m2, 1 + SD.HotSetBonus)
		t.truthy(why2.hot)
		t.near((Market.SaleMultiplier(ghost, true, true, "Ghost", Parts, SD)), SD.NightContrabandMultiplier * (1 + SD.HotSetBonus))
	end)
end

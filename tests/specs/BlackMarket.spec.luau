local BlackMarket = require("../../src/shared/Logic/BlackMarket")
local Economy = require("../../src/shared/Config/Economy")
local Parts = require("../../src/shared/Config/Parts")
local Shop = require("../../src/shared/Logic/Shop")

return function(t)
	t.test("stock is contraband only, distinct, priced in range", function()
		for night = 1, 30 do
			local stock = BlackMarket.Stock(night, Parts, Economy)
			t.truthy(#stock >= 1 and #stock <= Economy.BlackMarket.StockSize)
			local seen = {}
			for _, offer in stock do
				local part = Parts[offer.id]
				t.truthy(part.contraband, offer.id)
				t.falsy(seen[offer.id])
				seen[offer.id] = true
				local base = part.value * Economy.RarityMultiplier[part.rarity]
				t.truthy(offer.price >= math.floor(base * Economy.BlackMarket.PriceMin) and offer.price <= math.ceil(base * Economy.BlackMarket.PriceMax))
			end
		end
	end)

	t.test("same night same stock, nights differ", function()
		local a = BlackMarket.Stock(42, Parts, Economy)
		local b = BlackMarket.Stock(42, Parts, Economy)
		for i, offer in a do
			t.eq(offer.id, b[i].id)
			t.eq(offer.price, b[i].price)
		end
		local differ = 0
		for night = 1, 10 do
			local x, y = BlackMarket.Stock(night, Parts, Economy), BlackMarket.Stock(night + 1, Parts, Economy)
			if x[1].id ~= y[1].id or x[1].price ~= y[1].price then
				differ += 1
			end
		end
		t.truthy(differ >= 8)
	end)

	t.test("night index follows the day/night cycle", function()
		local cycle = Economy.DayNight.DayLength + Economy.DayNight.NightLength
		t.eq(BlackMarket.NightIndex(0, Economy.DayNight), 0)
		t.eq(BlackMarket.NightIndex(cycle * 3 + 5, Economy.DayNight), 3)
	end)

	t.test("phone orders pay the delivery fee, on site does not", function()
		local part = Parts.street_body
		local onSite = Shop.PartPrice(part, Economy, true) :: number
		local phone = Shop.PartPrice(part, Economy, false) :: number
		t.eq(Shop.PartPrice(part, Economy), onSite)
		t.near(phone, onSite * (1 + Economy.Supplier.DeliveryFee), 1)
		t.truthy(phone > onSite)
	end)
end

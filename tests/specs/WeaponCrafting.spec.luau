local WeaponCrafting = require("../../src/shared/Logic/WeaponCrafting")
local Parts = require("../../src/shared/Config/Parts")
local Economy = require("../../src/shared/Config/Economy")

local street = { Body = "street_body", Barrel = "street_barrel", Stock = "street_stock", Sight = "street_sight", Magazine = "street_mag" }

return function(t)
	t.test("full common set gets the set bonus", function()
		local w = assert(WeaponCrafting.Craft(street, "Nico", Parts, Economy))
		-- 40+25+20+20+25 = 130 * 1.25 = 162.5 -> 163
		t.eq(w.value, 163)
		t.eq(w.fullSet, "Street")
		t.eq(w.rarity, "Common")
		t.eq(w.suggestedPrice, math.floor(163 * 1.4 + 0.5))
		t.eq(w.brand, "Nico")
		t.falsy(w.contraband)
	end)

	t.test("stats are summed", function()
		local w = assert(WeaponCrafting.Craft(street, "Nico", Parts, Economy))
		t.eq(w.stats.Damage, 12)
		t.eq(w.stats.Range, 25)
		t.eq(w.stats.Accuracy, 11)
		t.eq(w.stats.FireRate, 4)
		t.eq(w.stats.Reload, 2)
	end)

	t.test("mixed parts: no set bonus, rarity multipliers applied", function()
		local mixed = table.clone(street)
		mixed.Stock = "gold_stock" -- Legendary, 120 * 10
		local w = assert(WeaponCrafting.Craft(mixed, "Nico", Parts, Economy))
		t.eq(w.fullSet, nil)
		t.eq(w.value, 40 + 25 + 1200 + 20 + 25)
		-- rarity indices 1,1,5,1,1 -> avg 1.8 -> floor 1 -> Common
		t.eq(w.rarity, "Common")
	end)

	t.test("one contraband part makes the weapon contraband", function()
		local mixed = table.clone(street)
		mixed.Barrel = "ghost_barrel"
		local w = assert(WeaponCrafting.Craft(mixed, "Nico", Parts, Economy))
		t.truthy(w.contraband)
	end)

	t.test("rejects missing, wrong or unknown parts", function()
		local missing = table.clone(street)
		missing.Sight = nil
		local w, err = WeaponCrafting.Craft(missing, "Nico", Parts, Economy)
		t.eq(w, nil)
		t.eq(err, "MissingSlot:Sight")

		local wrong = table.clone(street)
		wrong.Sight = "street_barrel"
		_, err = WeaponCrafting.Craft(wrong, "Nico", Parts, Economy)
		t.eq(err, "WrongSlot:street_barrel")

		local unknown = table.clone(street)
		unknown.Body = "admin_gun"
		_, err = WeaponCrafting.Craft(unknown, "Nico", Parts, Economy)
		t.eq(err, "UnknownPart:admin_gun")

		local extra = table.clone(street) :: any
		extra.Laser = "street_sight"
		_, err = WeaponCrafting.Craft(extra, "Nico", Parts, Economy)
		t.eq(err, "UnknownSlot:Laser")
	end)

	t.test("knockout commission is capped", function()
		t.eq(WeaponCrafting.KnockoutCommission(500, Economy), 10)
		t.eq(WeaponCrafting.KnockoutCommission(100000, Economy), 25)
	end)
end

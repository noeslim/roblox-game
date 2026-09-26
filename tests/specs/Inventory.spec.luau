local Inventory = require("../../src/shared/Logic/Inventory")
local Parts = require("../../src/shared/Config/Parts")
local Economy = require("../../src/shared/Config/Economy")

local recipe = {
	Body = "street_body",
	Barrel = "street_barrel",
	Stock = "street_stock",
	Sight = "street_sight",
	Magazine = "street_mag",
}

return function(t)
	t.test("add respects the stack cap", function()
		local inv = {}
		t.eq(Inventory.Add(inv, "street_body", 3, 5), 3)
		t.eq(Inventory.Add(inv, "street_body", 3, 5), 2)
		t.eq(Inventory.Count(inv, "street_body"), 5)
		t.eq(Inventory.Add(inv, "street_body", -1, 5), 0)
		t.eq(Inventory.Add(inv, "street_body", 0.5, 5), 0)
	end)

	t.test("remove never goes negative and clears empty stacks", function()
		local inv = { street_body = 2 }
		t.falsy(Inventory.Remove(inv, "street_body", 3))
		t.truthy(Inventory.Remove(inv, "street_body", 2))
		t.eq(inv.street_body, nil)
		t.falsy(Inventory.Remove(inv, "street_body", 0))
	end)

	t.test("RemoveAll is atomic", function()
		local inv = { street_body = 1, street_barrel = 1, street_stock = 1, street_sight = 1 }
		t.falsy(Inventory.RemoveAll(inv, recipe))
		t.eq(inv.street_body, 1)
		inv.street_mag = 2
		t.truthy(Inventory.RemoveAll(inv, recipe))
		t.eq(inv.street_body, nil)
		t.eq(inv.street_mag, 1)
	end)

	t.test("owned parts for a slot, sorted by rarity", function()
		local inv = { gold_stock = 1, neon_stock = 2, street_stock = 1, street_body = 4 }
		local list = Inventory.OwnedForSlot(inv, Parts, "Stock", Economy.RarityOrder)
		t.eq(table.concat(list, ","), "street_stock,neon_stock,gold_stock")
	end)
end

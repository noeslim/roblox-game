local StockLayout = require("../../src/shared/Logic/StockLayout")
local Buildables = require("../../src/shared/Config/Buildables")

local function items(weapons, parts)
	local list = {}
	for i = 1, weapons do
		table.insert(list, { ref = "w" .. i, kind = "weapon" })
	end
	for i = 1, parts do
		table.insert(list, { ref = "p" .. i, kind = "parts" })
	end
	return list
end

return function(t)
	t.test("weapons fill racks and cases first, one per slot", function()
		local spots, overflow = StockLayout.Assign(items(3, 0), { { kind = "pile", slots = 1 }, { kind = "standing", slots = 2 } }, 5)
		t.eq(overflow, 0)
		t.eq(spots[1].place, 2)
		t.eq(spots[2].place, 2)
		t.eq(spots[2].slot, 2)
		t.eq(spots[3].place, 1) -- rack full: on the pile
	end)

	t.test("parts only go on piles, stacked in layers", function()
		local spots, overflow = StockLayout.Assign(items(0, 3), { { kind = "lying", slots = 2 }, { kind = "pile", slots = 1 } }, 2)
		t.eq(overflow, 1)
		t.eq(spots[1].place, 2)
		t.eq(spots[1].layer, 1)
		t.eq(spots[2].layer, 2)
	end)

	t.test("piles fill a whole layer (every slot of every crate) before stacking", function()
		local spots = StockLayout.Assign(items(0, 7), { { kind = "pile", slots = 3 }, { kind = "pile", slots = 3 } }, 2)
		for i = 1, 6 do
			t.eq(spots[i].layer, 1)
		end
		t.eq(spots[7].layer, 2)
		t.eq(spots[7].place, 1)
		t.eq(spots[7].slot, 1)
	end)

	t.test("nowhere to show: everything overflows", function()
		local spots, overflow = StockLayout.Assign(items(2, 2), {}, 4)
		t.eq(#spots, 0)
		t.eq(overflow, 4)
	end)

	t.test("the starter stash can show weapons and parts", function()
		local places = {}
		for _, s in Buildables.ById["storage_crate"] and { "storage_crate" } or {} do
			local stock = Buildables.ById[s].stock
			t.truthy(stock, "supply crates show a pile")
			table.insert(places, { kind = stock.kind, slots = #stock.slots })
		end
		local _, overflow = StockLayout.Assign(items(1, 1), places, 3)
		t.eq(overflow, 0)
	end)
end

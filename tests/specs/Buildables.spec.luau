local Buildables = require("../../src/shared/Config/Buildables")
local Economy = require("../../src/shared/Config/Economy")

local EPS = 1e-6

return function(t)
	t.test("24 buildables, all listed in the menu order", function()
		local n = 0
		for _ in Buildables.ById do
			n += 1
		end
		t.eq(n, 24)
		t.eq(#Buildables.Order, 24)
	end)

	t.test("secret compartments: a level the search chances know, some room", function()
		local levels = 0
		for id, def in Buildables.ById do
			if def.hide then
				levels += 1
				t.eq(def.category, "Secret", id)
				t.truthy(Economy.Heat.HiddenFindChance[def.hide.level] ~= nil, id .. " level")
				t.truthy(def.hide.capacity >= 1, id .. " capacity")
			end
		end
		t.eq(levels, 4)
	end)

	t.test("every buildable is well formed", function()
		for id, def in Buildables.ById do
			t.eq(def.id, id)
			t.truthy(table.find(Buildables.Categories, def.category), id .. " category")
			t.truthy(def.price > 0 and math.floor(def.price) == def.price, id .. " price")
			t.truthy(def.size.y <= Economy.Building.PlotMaxHeight, id .. " height")
			-- width and depth must be whole studs so corners land on the grid
			t.eq(def.size.x % Economy.Building.GridSize, 0, id .. " width")
			t.eq(def.size.z % Economy.Building.GridSize, 0, id .. " depth")
			t.truthy(#def.parts > 0, id .. " has parts")
		end
	end)

	t.test("model parts stay inside the object's box", function()
		for id, def in Buildables.ById do
			for i, p in def.parts do
				for _, axis in { "x", "y", "z" } do
					local half = def.size[axis] / 2
					local lo = p.pos[axis] - p.size[axis] / 2
					local hi = p.pos[axis] + p.size[axis] / 2
					t.truthy(lo >= -half - EPS and hi <= half + EPS, ("%s part %d sticks out on %s"):format(id, i, axis))
				end
			end
		end
	end)
end

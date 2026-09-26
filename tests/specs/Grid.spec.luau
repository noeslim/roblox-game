local Grid = require("../../src/shared/Logic/Grid")

local plot = { sizeX = 40, sizeZ = 40, maxHeight = 30 }
local opts = { gridSize = 1, rotationStep = 45, maxObjects = 3 }

local function obj(id, x, z, sx, sz, rot)
	return { id = id, x = x, y = 2, z = z, sizeX = sx or 4, sizeY = 4, sizeZ = sz or 2, rotation = rot or 0 }
end

return function(t)
	t.test("snap helpers", function()
		t.eq(Grid.Snap(3.4, 1), 3)
		t.eq(Grid.Snap(3.6, 0.5), 3.5)
		t.eq(Grid.SnapRotation(100, 45), 90)
		t.eq(Grid.SnapRotation(-45, 45), 315)
	end)

	t.test("valid placement", function()
		t.truthy(Grid.ValidatePlacement(obj("a", 0, 0), plot, {}, opts))
	end)

	t.test("rotation swaps the footprint", function()
		local b = Grid.GetBounds(obj("a", 0, 0, 4, 2, 90))
		t.near(b.maxX - b.minX, 2)
		t.near(b.maxZ - b.minZ, 4)
	end)

	t.test("rejects outside the plot and too high", function()
		t.eq(select(2, Grid.ValidatePlacement(obj("a", 19, 0), plot, {}, opts)), "OutsidePlot")
		local tall = obj("a", 0, 0)
		tall.y = 29
		t.eq(select(2, Grid.ValidatePlacement(tall, plot, {}, opts)), "OutsideHeight")
	end)

	t.test("rejects collisions but allows touching", function()
		local existing = { obj("a", 0, 0) }
		t.eq(select(2, Grid.ValidatePlacement(obj("b", 1, 0), plot, existing, opts)), "Collision:a")
		t.truthy(Grid.ValidatePlacement(obj("b", 4, 0), plot, existing, opts))
	end)

	t.test("decorations can overlap", function()
		local rug = obj("rug", 1, 0)
		rug.solid = false
		t.truthy(Grid.ValidatePlacement(rug, plot, { obj("a", 0, 0) }, opts))
	end)

	t.test("moving an object ignores itself and the count limit", function()
		local existing = { obj("a", 0, 0), obj("b", 10, 0), obj("c", -10, 0) }
		local o = obj("a", 1, 0)
		t.truthy(Grid.ValidatePlacement(o, plot, existing, { gridSize = 1, rotationStep = 45, maxObjects = 3, ignoreId = "a" }))
	end)

	t.test("object limit", function()
		local existing = { obj("a", 0, 0), obj("b", 10, 0), obj("c", -10, 0) }
		t.eq(select(2, Grid.ValidatePlacement(obj("d", 0, 10), plot, existing, opts)), "TooManyObjects")
	end)

	t.test("rejects NaN, bad rotation, off-grid", function()
		local nan = obj("a", 0 / 0, 0)
		t.eq(select(2, Grid.ValidatePlacement(nan, plot, {}, opts)), "InvalidNumber:x")
		t.eq(select(2, Grid.ValidatePlacement(obj("a", 0, 0, 4, 2, 30), plot, {}, opts)), "BadRotation")
		t.eq(select(2, Grid.ValidatePlacement(obj("a", 0.3, 0), plot, {}, opts)), "OffGrid")
	end)

	t.test("45 degree placement is allowed on a centered grid", function()
		t.truthy(Grid.ValidatePlacement(obj("a", 0, 0, 4, 2, 45), plot, {}, opts))
	end)
end

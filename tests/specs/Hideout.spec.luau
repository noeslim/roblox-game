local Hideout = require("../../src/shared/Logic/Hideout")
local Buildables = require("../../src/shared/Config/Buildables")
local Economy = require("../../src/shared/Config/Economy")

local B = Economy.Building
local plot = { sizeX = B.PlotSizeX, sizeZ = B.PlotSizeZ, maxHeight = B.PlotMaxHeight }
local opts = { gridSize = B.GridSize, rotationStep = B.RotationStep, maxObjects = B.MaxObjects }
local cat = Buildables.ById

local function new()
	return Hideout.new(plot, opts, cat)
end

return function(t)
	t.test("place, get and count", function()
		local h = new()
		local o = h:Place("storage_crate", 0.5, 0.5, 0)
		t.truthy(o)
		t.eq(h:Count(), 1)
		t.eq(h:Get((o :: any).id), o)
	end)

	t.test("rejects unknown ids and garbage input", function()
		local h = new()
		t.eq(select(2, h:Place("nuke", 0, 0, 0)), "UnknownBuildable")
		t.eq(select(2, h:Place(nil, 0, 0, 0)), "UnknownBuildable")
		t.eq(select(2, h:Place("rug", 0 / 0, 0, 0)), "InvalidNumber")
		t.eq(select(2, h:Place("rug", "1", 0, 0)), "InvalidNumber")
	end)

	t.test("collisions, but rugs can go under things", function()
		local h = new()
		t.truthy(h:Place("storage_crate", 0.5, 0.5, 0))
		t.falsy(h:Place("storage_crate", 1.5, 0.5, 0))
		t.truthy(h:Place("rug", 0, 0, 0))
	end)

	t.test("move ignores itself, remove frees the spot", function()
		local h = new()
		local a = h:Place("storage_crate", 0.5, 0.5, 0) :: any
		t.truthy(h:Move(a.id, 1.5, 0.5, 0))
		t.eq(a.x, 1.5)
		local b = h:Place("storage_crate", 5.5, 0.5, 0) :: any
		t.falsy(h:Move(b.id, 2.5, 0.5, 0))
		t.truthy(h:Remove(a.id))
		t.truthy(h:Move(b.id, 2.5, 0.5, 0))
		t.eq(select(2, h:Remove("nope")), "UnknownObject")
		t.eq(select(2, h:Move("nope", 0, 0, 0)), "UnknownObject")
	end)

	t.test("snap puts corners on the grid for every rotation", function()
		local h = new()
		for _, rot in { 0, 45, 90, 135, 180, 270 } do
			local def = cat.workbench_basic
			local x, z = Hideout.Snap(def, 3.37, -7.81, rot, B.GridSize)
			local ok, err = h:Validate("workbench_basic", x, z, rot)
			t.truthy(ok, "rotation " .. rot .. ": " .. tostring(err))
		end
	end)

	t.test("encode / decode round trip", function()
		local s = Hideout.Encode({ id = "o1", buildableId = "couch", x = -3.5, z = 12, rotation = 90 })
		t.eq(s, "couch,-3.5,12,90")
		local id, x, z, r = Hideout.Decode(s)
		t.eq(id, "couch")
		t.eq(x, -3.5)
		t.eq(z, 12)
		t.eq(r, 90)
		t.eq(Hideout.Decode("couch,1,2"), nil)
		t.eq(Hideout.Decode("co uch,1,2,3"), nil)
		t.eq(Hideout.Decode(42), nil)
	end)

	t.test("load drops invalid and colliding entries", function()
		local h, dropped = Hideout.Load({
			"storage_crate,0.5,0.5,0",
			"storage_crate,0.5,0.5,0", -- collides
			"unknown_thing,0,0,0",
			"garbage",
			"rug,0,0,0",
		}, plot, opts, cat)
		t.eq(h:Count(), 2)
		t.eq(dropped, 3)
		t.eq(table.concat(h:Serialize(), "|"), "storage_crate,0.5,0.5,0|rug,0,0,0")
	end)

	t.test("starter stash loads completely and has a counter and a workbench", function()
		local h, dropped = Hideout.Load(Economy.Profile.StarterHideout, plot, opts, cat)
		t.eq(dropped, 0)
		t.eq(#h:FindByRole("Counter"), 1)
		t.eq(#h:FindByRole("Workbench"), 1)
	end)

	t.test("object limit", function()
		local h = Hideout.new(plot, { gridSize = 1, rotationStep = 45, maxObjects = 2 }, cat)
		t.truthy(h:Place("rug", 0, 0, 0))
		t.truthy(h:Place("rug", 0, 0, 0))
		t.eq(select(2, h:Place("rug", 0, 0, 0)), "TooManyObjects")
		h:SetMaxObjects(3)
		t.truthy(h:Place("rug", 0, 0, 0))
	end)
end

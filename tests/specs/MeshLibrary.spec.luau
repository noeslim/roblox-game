local MeshLibrary = require("../../src/shared/Config/MeshLibrary")

return function(t)
	t.test("every mesh of every model has a bounding box", function()
		for id, model in MeshLibrary.Models do
			for _, mat in model.materials do
				local box = MeshLibrary.Parts[id .. "__" .. mat]
				t.truthy(box, "missing box for " .. id .. "__" .. mat)
				t.truthy(box.s[1] >= 0 and box.s[2] >= 0 and box.s[3] >= 0, "negative size")
				t.truthy(MeshLibrary.Materials[mat], "unknown material " .. mat)
			end
		end
	end)

	t.test("buildings stand on their origin and fit a street block", function()
		for id, model in MeshLibrary.Models do
			if model.kind == "building" then
				for _, mat in model.materials do
					local box = MeshLibrary.Parts[id .. "__" .. mat]
					t.truthy(box.c[2] - box.s[2] / 2 > -1, id .. "__" .. mat .. " goes under the ground")
					t.truthy(math.abs(box.c[1]) + box.s[1] / 2 < 80, id .. "__" .. mat .. " is too wide")
				end
			end
		end
	end)
end

local City = require("../../src/shared/Config/City")
local CityParts = require("../../src/shared/Logic/CityParts")

local function box(p)
	local sx, sy, sz = p.size.x, p.size.y, p.size.z
	if p.shape == "Cylinder" and p.rotZ == 90 then
		sx, sy = sy, sx -- cylinders run along X, turned upright
	end
	if p.rotY and p.rotY ~= 0 then
		local r = math.max(sx, sz) * 0.75 -- rough bound for turned rubble
		sx, sz = r * 2, r * 2
	end
	return p.pos.x - sx / 2, p.pos.x + sx / 2, p.pos.y - sy / 2, p.pos.y + sy / 2, p.pos.z - sz / 2, p.pos.z + sz / 2
end

return function(t)
	local I = City.Interiors

	t.test("every archetype has a door on its front face and an interior", function()
		for name, a in City.Archetypes do
			t.truthy(a.door and a.interior, name)
			t.truthy(math.abs(a.door.x) + a.door.w / 2 < a.w / 2 - I.WallThickness, name .. " door off the facade")
			t.truthy(a.door.h < a.interior.height, name .. " door taller than the ground floor")
			t.truthy(a.interior.height < a.h, name .. " interior taller than the building")
		end
	end)

	t.test("furniture stays inside the room and out of the doorway", function()
		for name, a in City.Archetypes do
			for seed = 1, 5 do
				local parts, lights = CityParts.Interior(a, seed, I)
				t.truthy(#parts > 3 and #lights > 0, name .. " is empty")
				t.truthy(#parts <= 60, name .. " has too many parts: " .. #parts)
				local t0 = I.WallThickness
				local X0, X1, Z0, Z1 = -a.w / 2 + t0, a.w / 2 - t0, -a.d / 2 + t0, a.d / 2 - t0
				local cx0, cx1 = a.door.x - I.CorridorWidth / 2, a.door.x + I.CorridorWidth / 2
				local cz0 = Z1 - I.CorridorDepth
				for _, p in parts do
					local x0, x1, y0, y1, z0, z1 = box(p)
					local label = name .. "." .. p.name
					t.truthy(x0 >= X0 - 0.01 and x1 <= X1 + 0.01 and z0 >= Z0 - 0.01 and z1 <= Z1 + 0.01, label .. " outside the walls")
					t.truthy(y0 >= 0.39 and y1 <= a.interior.height + 0.01, label .. " through the floor or ceiling")
					local blocks = x1 > cx0 and x0 < cx1 and z1 > cz0 and p.canCollide ~= false
					t.falsy(blocks, label .. " blocks the doorway")
				end
				for _, l in lights do
					t.truthy(l.pos.y < a.interior.height and math.abs(l.pos.x) < a.w / 2 and math.abs(l.pos.z) < a.d / 2, name .. " light outside")
				end
			end
		end
	end)

	t.test("the shell leaves a doorway where the door is", function()
		for name, a in City.Archetypes do
			local parts, door = CityParts.BuildingShell(a, "#FFFFFF", I.WallThickness)
			if a.door.open then
				t.falsy(door, name .. " open doorway has a door")
			else
				t.truthy(door and door.w == a.door.w and door.h == a.door.h, name .. " door")
			end
			local total = 0
			for _, p in parts do
				local x0, x1, y0, _, z0, z1 = box(p)
				-- nothing solid in the doorway (except the lintel above it)
				local inDoorway = x1 > a.door.x - a.door.w / 2 + 0.01 and x0 < a.door.x + a.door.w / 2 - 0.01 and z1 > a.d / 2 - 1 and y0 < a.door.h - 0.01
				t.falsy(inDoorway and p.name ~= "InteriorFloor", name .. "." .. p.name .. " fills the doorway")
				if p.name == "Body" then
					t.eq(y0, a.interior.height)
				end
				total += 1
				t.truthy(z0 >= -a.d / 2 - 0.01 and z1 <= a.d / 2 + 0.01, name .. " wall outside the footprint")
			end
			t.eq(total, 8)
		end
	end)
end

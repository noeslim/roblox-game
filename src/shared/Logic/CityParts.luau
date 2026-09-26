--!strict
-- Turns CityLayout entries into plain part descriptions (size, position, material, color).
-- Pure: the Roblox MapBuilder instantiates them, the Blender preview renders the same data.
-- Positions are local to the entry (house: plot origin = basement floor center; building / prop /
-- special: center of the base at ground level). rotY / rotZ in degrees.

local CityParts = {}

export type Vec = { x: number, y: number, z: number }
export type PartSpec = {
	name: string,
	shape: string, -- "Block" | "Wedge" | "Cylinder" | "Ball"
	size: Vec,
	pos: Vec,
	rotY: number?,
	rotZ: number?,
	material: string,
	color: string,
	transparency: number?,
	canCollide: boolean?,
	group: string?, -- where the MapBuilder puts it ("Anchor", "Waypoints", "Sign", "Zone"...)
	texture: string?, -- tileable PBR texture name (MaterialVariant "BM_<name>" when imported)
}
export type LightSpec = { pos: Vec, color: string, range: number, brightness: number, shadows: boolean }

local function v(x: number, y: number, z: number): Vec
	return { x = x, y = y, z = z }
end

local function part(name: string, size: Vec, pos: Vec, material: string, color: string, extra: { [string]: any }?): PartSpec
	local p: PartSpec = { name = name, shape = "Block", size = size, pos = pos, material = material, color = color }
	if extra then
		for k, val in extra do
			(p :: any)[k] = val
		end
	end
	return p
end

CityParts.SlabLooks = {
	road = { material = "Asphalt", color = "#26262C", texture = "asphalt" },
	line = { material = "SmoothPlastic", color = "#D8B645" },
	paint = { material = "SmoothPlastic", color = "#E8E8E4" },
	sidewalk = { material = "Pavement", color = "#6A6A70", texture = "sidewalk" },
	lot = { material = "Asphalt", color = "#3A3A40", texture = "asphalt" },
	grass = { material = "Grass", color = "#3E5A32" },
	plaza = { material = "Cobblestone", color = "#6E6A66", texture = "cobblestone" },
	alley = { material = "Cobblestone", color = "#4A3E3A", texture = "cobblestone" },
	concrete = { material = "Concrete", color = "#6A6A6E", texture = "concrete" },
	dirt = { material = "Ground", color = "#4A3E30", texture = "dirt" },
	path = { material = "Concrete", color = "#8A8A8E", texture = "sidewalk" },
	outer = { material = "Ground", color = "#3A4230", texture = "dirt" },
} :: { [string]: { material: string, color: string, texture: string? } }

-- A ground slab, in world coordinates (relative to the city origin).
function CityParts.Slab(s: any): PartSpec
	local look = CityParts.SlabLooks[s.kind] or CityParts.SlabLooks.lot
	return part(s.kind, v(s.x1 - s.x0, s.thickness, s.z1 - s.z0), v((s.x0 + s.x1) / 2, s.top - s.thickness / 2, (s.z0 + s.z1) / 2), look.material, look.color, {
		canCollide = s.kind ~= "line" and s.kind ~= "paint",
		texture = look.texture,
	})
end

-- Plain walls of a building (the details come from the mesh library).
function CityParts.BuildingBody(archetype: any, color: string): { PartSpec }
	return { part("Body", v(archetype.w, archetype.h, archetype.d), v(0, archetype.h / 2, 0), archetype.material, color, { texture = archetype.texture }) }
end

local HOUSE_SIDING = { "#6E7F86", "#8A7A66", "#7A6A5A", "#5E6E5A", "#8A8A82", "#6A5E70" }

-- Trap house "shack" structure, in plot-local coordinates. Returns parts and lights.
function CityParts.House(cfg: any, index: number): ({ PartSpec }, { LightSpec })
	local H = cfg.Houses
	local B = H.BasementDepth
	local GF = H.GroundFloorHeight
	local top = B + GF
	local siding = HOUSE_SIDING[(index - 1) % #HOUSE_SIDING + 1]
	local concrete, dark = "#4E4E54", "#2E2E34"
	local parts: { PartSpec } = {}
	local function add(p: PartSpec)
		table.insert(parts, p)
	end

	-- basement (x -24..24 buildable, x 24..32 stairwell, z -24..24)
	add(part("Floor", v(48, 1, 48), v(0, -0.5, 0), "Concrete", "#3A3A40", { group = "Anchor", texture = "concrete" }))
	add(part("StairwellFloor", v(8, 1, 48), v(28, -0.5, 0), "Concrete", "#34343A", { texture = "concrete" }))
	add(part("BasementWallN", v(58, B, 1), v(4, B / 2, -24.5), "Concrete", concrete, { texture = "concrete" }))
	add(part("BasementWallS", v(58, B, 1), v(4, B / 2, 24.5), "Concrete", concrete, { texture = "concrete" }))
	add(part("BasementWallW", v(1, B, 48), v(-24.5, B / 2, 0), "Concrete", concrete, { texture = "concrete" }))
	add(part("BasementWallE", v(1, B, 48), v(32.5, B / 2, 0), "Concrete", concrete, { texture = "concrete" }))
	-- ground floor slab with the stair opening (x 24..33, z 0..22)
	add(part("GroundSlab", v(49, 1, 50), v(-0.5, B - 0.5, 0), "WoodPlanks", "#5A4632", { texture = "planks" }))
	add(part("GroundSlabBack", v(9, 1, 25), v(28.5, B - 0.5, -12.5), "WoodPlanks", "#5A4632", { texture = "planks" }))
	add(part("GroundSlabLanding", v(9, 1, 3), v(28.5, B - 0.5, 23.5), "WoodPlanks", "#5A4632", { texture = "planks" }))
	-- stairs: a ramp from the landing (z 22, top) down to the basement (z 0); steps are drawn by the mesh
	add({ name = "Stairs", shape = "Wedge", size = v(8, B, 22), pos = v(28, B / 2, 11), material = "Concrete", color = dark })
	-- ground floor walls with the front door above the stairwell (x 25.5..30.5)
	local wy = B + GF / 2
	add(part("WallN", v(58, GF, 1), v(4, wy, -24.5), "WoodPlanks", siding, { texture = "siding" }))
	add(part("WallW", v(1, GF, 48), v(-24.5, wy, 0), "WoodPlanks", siding, { texture = "siding" }))
	add(part("WallE", v(1, GF, 48), v(32.5, wy, 0), "WoodPlanks", siding, { texture = "siding" }))
	add(part("WallS", v(50.5, GF, 1), v(0.25, wy, 24.5), "WoodPlanks", siding, { texture = "siding" }))
	add(part("WallSDoorSide", v(2.5, GF, 1), v(31.75, wy, 24.5), "WoodPlanks", siding, { texture = "siding" }))
	add(part("Lintel", v(5, GF - H.DoorHeight, 1), v(28, B + H.DoorHeight + (GF - H.DoorHeight) / 2, 24.5), "WoodPlanks", siding, { texture = "siding" }))
	add(part("HallWall", v(0.5, GF, 48), v(24.25, wy, 0), "Plaster", "#8A8278", { texture = "plaster" }))
	add(part("Ceiling", v(58, 1, 50), v(4, top + 0.5, 0), "WoodPlanks", "#4A3A2A", { texture = "planks" }))
	-- gable roof (ridge along x), with overhang, and the two gable ends
	local roofH = 10
	add({ name = "RoofFront", shape = "Wedge", size = v(62, roofH, 27), pos = v(4, top + 1 + roofH / 2, 13.5), rotY = 180, material = "RoofShingles", color = "#3A3230", texture = "shingles" })
	add({ name = "RoofBack", shape = "Wedge", size = v(62, roofH, 27), pos = v(4, top + 1 + roofH / 2, -13.5), material = "RoofShingles", color = "#3A3230", texture = "shingles" })
	for _, x in { -24.5, 32.5 } do
		add({ name = "GableFront", shape = "Wedge", size = v(1, roofH, 25), pos = v(x, top + 1 + roofH / 2, 12.5), rotY = 180, material = "WoodPlanks", color = siding })
		add({ name = "GableBack", shape = "Wedge", size = v(1, roofH, 25), pos = v(x, top + 1 + roofH / 2, -12.5), material = "WoodPlanks", color = siding })
	end
	-- porch (x 14..33, z 25..33)
	add(part("Porch", v(19, 0.8, 8), v(23.5, B + 0.1, 29), "WoodPlanks", "#6B4A2E", { texture = "planks" }))
	add(part("PorchRoof", v(20, 0.5, 9), v(23.5, B + 9.2, 29.5), "WoodPlanks", "#4A3A2A", { texture = "planks" }))
	for _, x in { 14.5, 32.5 } do
		add(part("PorchPost", v(0.7, 9, 0.7), v(x, B + 4.7, 32.5), "Wood", "#D8D0C0"))
	end
	-- owner sign in the front yard, right of the path
	local lotFront = H.Depth / 2 + 1 + H.PorchDepth + H.YardDepth - 1
	add(part("SignPost", v(0.4, 6, 0.4), v(38, B + 3, lotFront - 1), "Metal", "#2B2B30", { group = "Sign" }))
	add(part("SignBoard", v(8, 2.5, 0.4), v(38, B + 6.5, lotFront - 1), "SmoothPlastic", "#141418", { group = "Sign" }))
	-- where customers walk (invisible)
	local waypoints: { { name: string, pos: Vec } } = {
		{ name = "Door", pos = v(28, B + 2.5, 36) },
		{ name = "StairsTop", pos = v(28, B + 2.5, 22.5) },
		{ name = "StairsBottom", pos = v(28, 2.5, -2) },
	}
	for _, w in waypoints do
		add(part(w.name, v(1, 1, 1), w.pos, "SmoothPlastic", "#FFFFFF", { transparency = 1, canCollide = false, group = "Waypoints" }))
	end

	local lights: { LightSpec } = {
		{ pos = v(0, B - 1.8, -8), color = "#FFD9A0", range = 26, brightness = 1.4, shadows = true },
		{ pos = v(0, B - 1.8, 10), color = "#FFD9A0", range = 26, brightness = 1.4, shadows = false },
		{ pos = v(28, B - 1.8, 6), color = "#FFD9A0", range = 18, brightness = 1.1, shadows = false },
		{ pos = v(31.2, B + 7, 25.8), color = "#FFC870", range = 14, brightness = 1.2, shadows = false },
	}
	return parts, lights
end

-- Structures that are not meshes: fences, pier, court floor, gang spawn bunkers, gas station shop...
function CityParts.Special(s: any, cfg: any): { PartSpec }
	local out: { PartSpec } = {}
	local function add(p: PartSpec)
		table.insert(out, p)
	end
	if s.kind == "fence" then
		local len, h = s.sx or 10, cfg.WarZone.FenceHeight
		add(part("FencePanel", v(len, h - 1, 0.2), v(0, h / 2, 0), "DiamondPlate", "#8A8A90", { transparency = 0.55 }))
		add(part("FenceTop", v(len, 0.3, 0.3), v(0, h, 0), "Metal", "#5A5A60"))
		local posts = math.max(2, math.floor(len / 16) + 1)
		for i = 0, posts - 1 do
			add(part("FencePost", v(0.5, h + 0.5, 0.5), v(-len / 2 + i * len / (posts - 1), (h + 0.5) / 2, 0), "Metal", "#4A4A50"))
		end
	elseif s.kind == "pier" then
		add(part("PierDeck", v(s.sx, 1, s.sz), v(0, -0.5 + 0.5, 0), "WoodPlanks", "#5A4632", { texture = "planks" }))
		for x = -s.sx / 2 + 3, s.sx / 2 - 3, 12 do
			for _, z in { -s.sz / 2 + 1, s.sz / 2 - 1 } do
				add({ name = "PierPost", shape = "Cylinder", size = v(14, 1.4, 1.4), pos = v(x, -6.5, z), rotZ = 90, material = "Wood", color = "#3A2A1E" })
			end
		end
	elseif s.kind == "court" then
		add(part("CourtFloor", v(s.sx, 0.2, s.sz), v(0, 0.1, 0), "SmoothPlastic", "#2E5A7A"))
		add(part("CourtLine", v(s.sx - 2, 0.05, 0.3), v(0, 0.22, 0), "SmoothPlastic", "#E8E8E8", { canCollide = false }))
	elseif s.kind == "spawn_red" or s.kind == "spawn_blue" then
		local color = if s.kind == "spawn_red" then "#C0392B" else "#2E6FD8"
		add(part("BunkerFloor", v(34, 1, 34), v(0, 0.5, 0), "Concrete", "#5A5A5E"))
		add(part("BunkerWallBack", v(34, 10, 2), v(0, 5.5, -16), "Concrete", "#6A6A6E"))
		add(part("BunkerWallLeft", v(2, 10, 30), v(-16, 5.5, -1), "Concrete", "#6A6A6E"))
		add(part("BunkerWallRight", v(2, 10, 30), v(16, 5.5, -1), "Concrete", "#6A6A6E"))
		add(part("BunkerRoof", v(36, 1.2, 34), v(0, 11, -1), "Concrete", "#55555A"))
		add(part("BunkerStripe", v(34, 0.8, 0.3), v(0, 10, -14.8), "Neon", color, { canCollide = false }))
		add(part(if s.kind == "spawn_red" then "RedSpawn" else "BlueSpawn", v(10, 1, 10), v(0, 1.1, -4), "SmoothPlastic", color, { group = "Spawn" }))
	elseif s.kind == "control_point" then
		add({ name = "Zone_" .. tostring(s.label), shape = "Cylinder", size = v(14, cfg.WarZone.ControlPointRadius * 2, cfg.WarZone.ControlPointRadius * 2), pos = v(0, 7, 0), rotZ = 90, material = "SmoothPlastic", color = "#FFB020", transparency = 1, canCollide = false, group = "Zone" })
	elseif s.kind == "gas_station" then
		add(part("GasShop", v(28, 12, 16), v(15, 6, -12), "Brick", "#5E4A3E", { texture = "brick_dark" }))
		add(part("GasShopWindow", v(20, 6, 0.3), v(15, 4, -3.9), "Glass", "#1E2A36"))
		add(part("GasSign", v(24, 2.5, 0.5), v(15, 10.5, -3.8), "SmoothPlastic", "#141418", { group = "Sign" }))
	elseif s.kind == "lanterns" then
		-- cables across the alley every 20 studs (lantern meshes hang on them)
		local length = s.sz or 100
		for z = -length / 2 + 20, length / 2 - 20, 20 do
			add(part("LanternCable", v((s.sx or 16) + 2, 0.12, 0.12), v(0, 17, z), "Metal", "#1A1A1E", { canCollide = false }))
		end
	end
	return out
end

-- Placeholder parts for a prop when the mesh library is not imported.
function CityParts.PropFallback(kind: string): { PartSpec }
	if kind == "lamp" then
		return {
			part("Pole", v(0.5, 15, 0.5), v(0, 7.5, 0), "Metal", "#2B2B30"),
			part("Head", v(1.4, 0.5, 2.4), v(0, 15.2, 4.5), "Metal", "#2B2B30"),
			part("Lens", v(1.1, 0.12, 2), v(0, 14.9, 4.5), "SmoothPlastic", "#FFE2B0", { canCollide = false }),
		}
	elseif kind == "tree" then
		return {
			{ name = "Trunk", shape = "Cylinder", size = v(10, 1.2, 1.2), pos = v(0, 5, 0), rotZ = 90, material = "Wood", color = "#4A3626" },
			{ name = "Canopy", shape = "Ball", size = v(9, 9, 9), pos = v(0, 11, 0), material = "Grass", color = "#2E6B30", canCollide = false },
		}
	elseif kind == "car" then
		return {
			part("Body", v(6.2, 2.4, 14), v(0, 2.1, 0), "SmoothPlastic", "#7A1F1F"),
			part("Cabin", v(5.8, 1.8, 7), v(0, 4.2, -1), "Glass", "#1E2A36"),
		}
	elseif kind == "container" then
		return { part("Container", v(20, 8.5, 8), v(0, 4.25, 0), "CorrodedMetal", "#8A3A2A") }
	elseif kind == "barrier" then
		return { part("Barrier", v(7.8, 2.8, 2.4), v(0, 1.4, 0), "Concrete", "#7A7A7E") }
	elseif kind == "bench" then
		return { part("Bench", v(5, 1.6, 1.8), v(0, 0.8, 0), "WoodPlanks", "#6B4A2E") }
	elseif kind == "trashcan" then
		return { { name = "Can", shape = "Cylinder", size = v(3.4, 2, 2), pos = v(0, 1.7, 0), rotZ = 90, material = "Metal", color = "#2F4F3A" } }
	elseif kind == "hydrant" then
		return { { name = "Hydrant", shape = "Cylinder", size = v(2.4, 0.9, 0.9), pos = v(0, 1.2, 0), rotZ = 90, material = "Metal", color = "#7A1F1F" } }
	elseif kind == "mailbox" then
		return { part("Mailbox", v(0.9, 4, 1.6), v(0, 2, 0), "Metal", "#2B2D33") }
	elseif kind == "smokestack" then
		return { { name = "Stack", shape = "Cylinder", size = v(62, 6, 6), pos = v(0, 31, 0), rotZ = 90, material = "Brick", color = "#6E3A2E" } }
	elseif kind == "lantern" then
		return { part("Lantern", v(1.4, 1.8, 1.4), v(0, 0, 0), "Neon", "#FF3B3B", { canCollide = false }) }
	elseif kind == "hoop" then
		return { part("Board", v(6, 3.5, 0.3), v(0, 11.5, 2), "SmoothPlastic", "#E8E8E8") }
	elseif kind == "utility_pole" then
		return {
			part("Pole", v(0.8, 26, 0.8), v(0, 13, 0), "Wood", "#4A3A2C"),
			part("Crossarm", v(0.45, 0.5, 7), v(0, 24.5, 0), "Wood", "#4A3A2C"),
		}
	elseif kind == "traffic_light" then
		return {
			part("Pole", v(0.7, 19.5, 0.7), v(0, 9.75, 0), "Metal", "#2B2D33"),
			part("Arm", v(0.4, 0.4, 15), v(0, 18.7, 7.5), "Metal", "#2B2D33"),
			part("Head", v(1.2, 4.2, 1.5), v(0, 16.3, 10.5), "Metal", "#16171B"),
			part("Head", v(1.2, 4.2, 1.5), v(0, 16.3, 14.5), "Metal", "#16171B"),
		}
	elseif kind == "billboard" then
		return {
			part("Leg", v(0.9, 20, 0.9), v(-28 / 3, 10, -0.8), "Metal", "#2B2D33"),
			part("Leg", v(0.9, 20, 0.9), v(28 / 3, 10, -0.8), "Metal", "#2B2D33"),
			part("Frame", v(28.8, 12.8, 0.5), v(0, 14, 0), "Metal", "#16171B"),
		}
	end
	return {}
end

-- Parts added to a prop whatever its model (mesh or fallback): the billboard's ad surface.
function CityParts.PropExtras(kind: string): { PartSpec }
	if kind == "billboard" then
		return { part("AdFace", v(28, 12, 0.1), v(0, 14, 0.45), "SmoothPlastic", "#E8E2D6", { canCollide = false }) }
	end
	return {}
end

return CityParts

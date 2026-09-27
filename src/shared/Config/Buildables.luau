--!strict
-- Everything a dealer can build in their stash.
-- Sizes are in studs (x = width, y = height, z = depth). The object rests on the floor.
-- `parts` describes a placeholder 3D model made of simple parts, positions relative to the object's
-- center. To use a real model instead, put a Model named after the id in
-- ReplicatedStorage.Assets.Buildables (see ModelFactory).
-- Customers stand on the +Z side of a counter (the side facing the street at rotation 0).

export type Vec = { x: number, y: number, z: number }

export type PartSpec = {
	size: Vec,
	pos: Vec,
	color: string, -- hex
	material: string?, -- Enum.Material name, default SmoothPlastic
	shape: string?, -- "Block" (default) | "Ball" | "Cylinder" (cylinder axis = X)
	transparency: number?,
}

export type LightSpec = {
	pos: Vec,
	color: string,
	range: number,
	brightness: number,
}

export type Buildable = {
	id: string,
	name: string,
	category: string, -- "Business" | "Structure" | "Decor"
	price: number,
	size: Vec,
	solid: boolean?, -- false = can overlap other objects (rugs, floor tiles)
	role: string?, -- "Counter" | "Workbench" | "Display" | "Storage"
	parts: { PartSpec },
	light: LightSpec?,
	-- secret compartment: stock hidden here escapes a raid unless the search finds it
	-- (Economy.Heat.HiddenFindChance[level]); capacity = weapons or part units
	hide: { level: number, capacity: number }?,
}

local Buildables: { [string]: Buildable } = {}
local Order: { string } = {} -- display order in the build menu

local function v(x: number, y: number, z: number): Vec
	return { x = x, y = y, z = z }
end

local function add(def: Buildable)
	assert(Buildables[def.id] == nil, "duplicate buildable " .. def.id)
	Buildables[def.id] = def
	table.insert(Order, def.id)
end

-- Business ------------------------------------------------------------------
add({
	id = "counter_folding", name = "Folding Table", category = "Business", role = "Counter", price = 60,
	size = v(4, 3, 2),
	parts = {
		{ size = v(4, 0.2, 2), pos = v(0, 1.4, 0), color = "#8A8F99", material = "Metal" },
		{ size = v(0.2, 2.8, 0.2), pos = v(-1.8, -0.1, -0.8), color = "#2B2B30", material = "Metal" },
		{ size = v(0.2, 2.8, 0.2), pos = v(1.8, -0.1, -0.8), color = "#2B2B30", material = "Metal" },
		{ size = v(0.2, 2.8, 0.2), pos = v(-1.8, -0.1, 0.8), color = "#2B2B30", material = "Metal" },
		{ size = v(0.2, 2.8, 0.2), pos = v(1.8, -0.1, 0.8), color = "#2B2B30", material = "Metal" },
	},
})
add({
	id = "counter_wood", name = "Wooden Counter", category = "Business", role = "Counter", price = 180,
	size = v(6, 4, 2),
	parts = {
		{ size = v(6, 3.6, 1.8), pos = v(0, -0.2, 0), color = "#5A3A22", material = "Wood" },
		{ size = v(6, 0.4, 2), pos = v(0, 1.8, 0), color = "#3B2616", material = "WoodPlanks" },
		{ size = v(6, 0.15, 0.1), pos = v(0, 1.2, 0.95), color = "#B45CFF", material = "Neon" },
	},
})
add({
	id = "counter_metal", name = "Steel Counter", category = "Business", role = "Counter", price = 450,
	size = v(8, 4, 2),
	parts = {
		{ size = v(8, 3.6, 1.8), pos = v(0, -0.2, 0), color = "#2B2D33", material = "DiamondPlate" },
		{ size = v(8, 0.4, 2), pos = v(0, 1.8, 0), color = "#9FD8FF", material = "Glass", transparency = 0.3 },
		{ size = v(8, 0.15, 0.1), pos = v(0, 1.2, 0.95), color = "#39FF88", material = "Neon" },
	},
	light = { pos = v(0, 1.2, 1), color = "#39FF88", range = 10, brightness = 1 },
})
add({
	id = "workbench_basic", name = "Workbench", category = "Business", role = "Workbench", price = 150,
	size = v(6, 4, 3),
	parts = {
		{ size = v(6, 0.4, 3), pos = v(0, 0.8, 0), color = "#6B4A2E", material = "WoodPlanks" },
		{ size = v(0.4, 2.6, 0.4), pos = v(-2.6, -0.7, -1.2), color = "#2B2B30", material = "Metal" },
		{ size = v(0.4, 2.6, 0.4), pos = v(2.6, -0.7, -1.2), color = "#2B2B30", material = "Metal" },
		{ size = v(0.4, 2.6, 0.4), pos = v(-2.6, -0.7, 1.2), color = "#2B2B30", material = "Metal" },
		{ size = v(0.4, 2.6, 0.4), pos = v(2.6, -0.7, 1.2), color = "#2B2B30", material = "Metal" },
		{ size = v(6, 1, 0.2), pos = v(0, 1.5, -1.4), color = "#3A3A40", material = "DiamondPlate" },
		{ size = v(0.8, 0.6, 0.8), pos = v(2, 1.3, 0.3), color = "#55575E", material = "Metal" },
		{ size = v(1.5, 0.2, 0.2), pos = v(-1.5, 1.9, -1.2), color = "#FFB020", material = "Neon" },
	},
	light = { pos = v(-1.5, 1.6, -1), color = "#FFC870", range = 12, brightness = 1.5 },
})
add({
	id = "display_case", name = "Glass Display Case", category = "Business", role = "Display", price = 220,
	size = v(4, 4, 2),
	parts = {
		{ size = v(4, 2, 2), pos = v(0, -1, 0), color = "#1E1B2E", material = "SmoothPlastic" },
		{ size = v(3.8, 1.9, 1.8), pos = v(0, 0.95, 0), color = "#BFE9FF", material = "Glass", transparency = 0.7 },
		{ size = v(3.8, 0.1, 0.1), pos = v(0, 0.05, 0.9), color = "#3FA9F5", material = "Neon" },
	},
	light = { pos = v(0, 0.5, 0), color = "#9FD8FF", range = 8, brightness = 1 },
})
add({
	id = "wall_rack", name = "Weapon Wall Rack", category = "Business", role = "Display", price = 90,
	size = v(6, 6, 1),
	parts = {
		{ size = v(6, 6, 0.3), pos = v(0, 0, -0.35), color = "#3A3A40", material = "WoodPlanks" },
		{ size = v(5, 0.2, 0.5), pos = v(0, 1.5, 0.15), color = "#1F1F24", material = "Metal" },
		{ size = v(5, 0.2, 0.5), pos = v(0, -0.5, 0.15), color = "#1F1F24", material = "Metal" },
		{ size = v(5, 0.2, 0.5), pos = v(0, -2.5, 0.15), color = "#1F1F24", material = "Metal" },
	},
})
add({
	id = "storage_crate", name = "Supply Crate", category = "Business", role = "Storage", price = 30,
	size = v(3, 3, 3),
	parts = {
		{ size = v(2.9, 2.9, 2.9), pos = v(0, 0, 0), color = "#7A5230", material = "WoodPlanks" },
		{ size = v(3, 0.3, 3), pos = v(0, 0.9, 0), color = "#3C3C42", material = "Metal" },
		{ size = v(3, 0.3, 3), pos = v(0, -0.9, 0), color = "#3C3C42", material = "Metal" },
	},
})
add({
	id = "safe", name = "Safe", category = "Business", role = "Storage", price = 350,
	size = v(3, 4, 3),
	parts = {
		{ size = v(3, 4, 2.9), pos = v(0, 0, -0.05), color = "#3C4048", material = "Metal" },
		{ size = v(2.4, 3.2, 0.1), pos = v(0, 0, 1.45), color = "#4A4F58", material = "DiamondPlate" },
		{ size = v(0.5, 0.5, 0.5), pos = v(0.6, 0.3, 1.2), color = "#FFB020", material = "Neon", shape = "Ball" },
	},
})

-- Secret --------------------------------------------------------------------
-- Hold E on one to hide your contraband before the cops come in (Logic/Raid).
add({
	id = "floor_hatch", name = "Floor Hatch", category = "Secret", price = 150, solid = false,
	size = v(4, 0.4, 4),
	hide = { level = 1, capacity = 8 },
	parts = {
		{ size = v(4, 0.2, 4), pos = v(0, -0.1, 0), color = "#3B2F25", material = "WoodPlanks" },
		{ size = v(0.8, 0.15, 0.2), pos = v(0, 0.075, 1.3), color = "#2A2A2E", material = "Metal" },
	},
})
add({
	id = "bookshelf_secret", name = "Pivoting Bookshelf", category = "Secret", price = 450,
	size = v(6, 8, 2),
	hide = { level = 2, capacity = 20 },
	parts = {
		{ size = v(6, 8, 1.2), pos = v(0, 0, -0.4), color = "#4A3526", material = "WoodPlanks" },
		{ size = v(5.4, 1.4, 0.7), pos = v(0, 2.4, 0.55), color = "#6B2E2E", material = "Fabric" },
		{ size = v(5.4, 1.4, 0.7), pos = v(0, 0.2, 0.55), color = "#2E4A5C", material = "Fabric" },
		{ size = v(5.4, 1.4, 0.7), pos = v(0, -2, 0.55), color = "#5C4A2E", material = "Fabric" },
	},
})
add({
	id = "false_wall", name = "False Wall", category = "Secret", price = 900,
	size = v(8, 10, 1),
	hide = { level = 3, capacity = 40 },
	parts = {
		{ size = v(8, 10, 1), pos = v(0, 0, 0), color = "#6B3A2E", material = "Brick" },
	},
})
add({
	id = "floor_vault", name = "Floor Vault", category = "Secret", price = 2200, solid = false,
	size = v(4, 0.4, 4),
	hide = { level = 4, capacity = 80 },
	parts = {
		{ size = v(4, 0.2, 4), pos = v(0, -0.1, 0), color = "#3C4048", material = "DiamondPlate" },
		{ size = v(3.4, 0.1, 3.4), pos = v(0, 0.05, 0), color = "#2E3238", material = "Metal" },
	},
})

-- Structure -----------------------------------------------------------------
add({
	id = "wall_brick", name = "Brick Wall", category = "Structure", price = 25,
	size = v(8, 10, 1),
	parts = { { size = v(8, 10, 1), pos = v(0, 0, 0), color = "#8B4A3A", material = "Brick" } },
})
add({
	id = "wall_concrete", name = "Concrete Wall", category = "Structure", price = 35,
	size = v(8, 10, 1),
	parts = { { size = v(8, 10, 1), pos = v(0, 0, 0), color = "#6E6E73", material = "Concrete" } },
})
add({
	id = "wall_window", name = "Window Wall", category = "Structure", price = 45,
	size = v(8, 10, 1),
	parts = {
		{ size = v(8, 4, 1), pos = v(0, -3, 0), color = "#8B4A3A", material = "Brick" },
		{ size = v(8, 2, 1), pos = v(0, 4, 0), color = "#8B4A3A", material = "Brick" },
		{ size = v(1.5, 4, 1), pos = v(-3.25, 1, 0), color = "#8B4A3A", material = "Brick" },
		{ size = v(1.5, 4, 1), pos = v(3.25, 1, 0), color = "#8B4A3A", material = "Brick" },
		{ size = v(5, 4, 0.2), pos = v(0, 1, 0), color = "#A8D8FF", material = "Glass", transparency = 0.6 },
	},
})
add({
	id = "door_frame", name = "Doorway", category = "Structure", price = 40,
	size = v(8, 10, 1),
	parts = {
		{ size = v(2.5, 10, 1), pos = v(-2.75, 0, 0), color = "#8B4A3A", material = "Brick" },
		{ size = v(2.5, 10, 1), pos = v(2.75, 0, 0), color = "#8B4A3A", material = "Brick" },
		{ size = v(3, 2, 1), pos = v(0, 4, 0), color = "#8B4A3A", material = "Brick" },
	},
})
add({
	id = "fence_chain", name = "Chain Fence", category = "Structure", price = 20,
	size = v(8, 6, 1),
	parts = {
		{ size = v(0.3, 6, 0.3), pos = v(-3.85, 0, 0), color = "#7A7A80", material = "Metal" },
		{ size = v(0.3, 6, 0.3), pos = v(3.85, 0, 0), color = "#7A7A80", material = "Metal" },
		{ size = v(7.4, 5.5, 0.1), pos = v(0, 0.25, 0), color = "#9A9AA0", material = "DiamondPlate", transparency = 0.6 },
	},
})
add({
	id = "floor_tile", name = "Floor Tiles", category = "Structure", price = 15, solid = false,
	size = v(8, 0.2, 8),
	parts = { { size = v(8, 0.2, 8), pos = v(0, 0, 0), color = "#2A2438", material = "Marble" } },
})

-- Decor -----------------------------------------------------------------------
add({
	id = "neon_sign_pink", name = "Neon Sign", category = "Decor", price = 80,
	size = v(6, 6, 1),
	parts = {
		{ size = v(0.3, 3, 0.3), pos = v(-2.5, -1.5, 0), color = "#2B2B30", material = "Metal" },
		{ size = v(0.3, 3, 0.3), pos = v(2.5, -1.5, 0), color = "#2B2B30", material = "Metal" },
		{ size = v(6, 3, 0.3), pos = v(0, 1.5, -0.35), color = "#111111", material = "SmoothPlastic" },
		{ size = v(5, 0.3, 0.3), pos = v(0, 2.3, 0), color = "#FF3FA4", material = "Neon" },
		{ size = v(5, 0.3, 0.3), pos = v(0, 0.7, 0), color = "#FF3FA4", material = "Neon" },
		{ size = v(0.3, 1.9, 0.3), pos = v(-2.35, 1.5, 0), color = "#FF3FA4", material = "Neon" },
		{ size = v(0.3, 1.9, 0.3), pos = v(2.35, 1.5, 0), color = "#FF3FA4", material = "Neon" },
	},
	light = { pos = v(0, 1.5, 0.5), color = "#FF3FA4", range = 16, brightness = 2 },
})
add({
	id = "neon_tube_blue", name = "Neon Tube", category = "Decor", price = 40,
	size = v(1, 8, 1),
	parts = {
		{ size = v(1, 0.4, 1), pos = v(0, -3.8, 0), color = "#1F1F24", material = "Metal" },
		{ size = v(0.5, 7.6, 0.5), pos = v(0, 0.2, 0), color = "#3FA9F5", material = "Neon" },
	},
	light = { pos = v(0, 0, 0), color = "#3FA9F5", range = 14, brightness = 1.5 },
})
add({
	id = "couch", name = "Couch", category = "Decor", price = 110,
	size = v(6, 3, 3),
	parts = {
		{ size = v(6, 1.2, 3), pos = v(0, -0.9, 0), color = "#4B2E83", material = "Fabric" },
		{ size = v(6, 1.8, 0.8), pos = v(0, 0.6, -1.1), color = "#3D2570", material = "Fabric" },
		{ size = v(0.8, 1, 3), pos = v(-2.6, 0.2, 0), color = "#3D2570", material = "Fabric" },
		{ size = v(0.8, 1, 3), pos = v(2.6, 0.2, 0), color = "#3D2570", material = "Fabric" },
	},
})
add({
	id = "plant", name = "Potted Plant", category = "Decor", price = 25,
	size = v(2, 4, 2),
	parts = {
		{ size = v(1.6, 1.2, 1.6), pos = v(0, -1.4, 0), color = "#5B3A29", material = "Slate" },
		{ size = v(2, 2, 2), pos = v(0, 0.8, 0), color = "#2E7D32", material = "Grass", shape = "Ball" },
	},
})
add({
	id = "rug", name = "Rug", category = "Decor", price = 20, solid = false,
	size = v(6, 0.2, 4),
	parts = { { size = v(6, 0.2, 4), pos = v(0, 0, 0), color = "#7A1E3A", material = "Fabric" } },
})
add({
	id = "speaker", name = "Speaker", category = "Decor", price = 70,
	size = v(2, 4, 2),
	parts = {
		{ size = v(2, 4, 1.8), pos = v(0, 0, -0.1), color = "#15151A", material = "SmoothPlastic" },
		{ size = v(1.2, 1.2, 1.2), pos = v(0, -0.8, 0.35), color = "#2E2E36", material = "SmoothPlastic", shape = "Ball" },
		{ size = v(0.6, 0.6, 0.6), pos = v(0, 1, 0.65), color = "#B45CFF", material = "Neon", shape = "Ball" },
	},
})

return {
	ById = Buildables,
	Order = Order,
	Categories = { "Business", "Secret", "Structure", "Decor" },
}

--!strict
-- Black Market City layout settings (docs/GAME_DESIGN.md §19). Read by Logic/CityLayout (pure,
-- tested), by the MapBuilder (Roblox) and by tools/meshgen (3D preview of the whole city).
-- Studs. x = east, z = south, y = up. The city is centered on Origin.

local City = {}

City.Origin = { x = 0, y = 0, z = 0 }
City.Seed = 2026

City.Grid = {
	Cells = 3, -- 3 x 3 districts
	CellSize = 520,
	AvenueWidth = 40, -- roads between districts and the ring road around them
	SidewalkWidth = 8,
	SidewalkHeight = 0.5,
	InnerRoadWidth = 30, -- cross road splitting a district into 4 blocks
	AlleyWidth = 16, -- Chinatown's cross road is a pedestrian alley (black market)
}

-- District of each cell, row by row from the north (row 1) to the south (row 3).
City.Districts = {
	{ "RichHills", "Chinatown", "Docks" },
	{ "Blocks", "Downtown", "Industrial" },
	{ "Blocks", "Strip", "WarZone" },
}

City.DistrictNames = {
	RichHills = "Rich Hills",
	Chinatown = "Chinatown",
	Docks = "The Docks",
	Blocks = "The Blocks",
	Downtown = "Downtown",
	Industrial = "Industrial",
	Strip = "The Strip",
	WarZone = "War Zone",
}

-- Building archetypes: footprint W (along the street) x D (depth), height H. The 3D details come
-- from the mesh library (model "bld_<archetype>"), the walls are plain parts (cheap collisions).
export type Archetype = {
	w: number,
	d: number,
	h: number,
	material: string, -- body Enum.Material name
	colors: { string },
}

City.Archetypes = {
	apartment = { w = 40, d = 30, h = 48, material = "Brick", colors = { "#6B3A2E", "#7A4A38", "#5A3A30", "#4F3B34" } },
	shop = { w = 32, d = 26, h = 24, material = "Brick", colors = { "#5E4A3E", "#3E3A40", "#6A4A3A", "#4A4E52" } },
	office = { w = 44, d = 40, h = 100, material = "Concrete", colors = { "#5A5E66", "#4A4E56", "#6A6660" } },
	tower = { w = 40, d = 40, h = 160, material = "Concrete", colors = { "#3E4450", "#4A4E58" } },
	warehouse = { w = 60, d = 44, h = 26, material = "CorrodedMetal", colors = { "#5A5048", "#4A5058", "#6A5A48" } },
	chinatown = { w = 28, d = 24, h = 30, material = "Brick", colors = { "#7A2E2A", "#8A5A2E", "#5A2A2E", "#6A3A30" } },
	mansion = { w = 56, d = 40, h = 22, material = "Plaster", colors = { "#E8E2D6", "#D8D0C0", "#EDE6DA" } },
	ruin = { w = 44, d = 32, h = 18, material = "Concrete", colors = { "#4A4640", "#55504A" } },
} :: { [string]: Archetype }

-- Which buildings each district uses (weights). Special districts are laid out by hand in CityLayout.
City.DistrictBuildings = {
	Downtown = { office = 3, tower = 1, shop = 2, apartment = 1 },
	Chinatown = { chinatown = 5, shop = 1 },
	Strip = { shop = 4, apartment = 2 },
	Industrial = { warehouse = 4, shop = 1 },
	RichHills = { mansion = 1 },
	Docks = { warehouse = 1 },
	WarZone = { ruin = 1 },
} :: { [string]: { [string]: number } }

City.BuildingGap = { Downtown = 4, Chinatown = 0, Strip = 3, Industrial = 10, RichHills = 30, Docks = 14, WarZone = 18 } :: { [string]: number }

-- Signs on shops, by district (neon text on the facade)
City.ShopSigns = {
	Downtown = { "BANK", "DINER", "PAWN", "HOTEL", "PHARMACY", "BARBER" },
	Chinatown = { "NOODLES", "DUMPLINGS", "TEA", "KARAOKE", "HERBS", "MAHJONG" },
	Strip = { "LIQUOR", "BAR", "ARCADE", "TATTOO", "24/7", "CHECKS CASHED", "PIZZA" },
	Industrial = { "SCRAP", "TIRES" },
}

-- Trap houses (player bases) in the Blocks districts: 3 x 3 per district.
City.Houses = {
	PerRow = 3,
	Rows = 3,
	StreetWidth = 26, -- street in front of each row (the last row faces the avenue)
	YardDepth = 14, -- front yard between the porch and the sidewalk
	PorchDepth = 8,
	-- House geometry in plot-local studs (origin = basement floor center, +Z = street side)
	BasementDepth = 14, -- basement floor to ground level
	Width = 56, -- x from -24 to +32 (48 of basement to build in + an 8 stud stairwell on +X)
	Depth = 48, -- z from -24 to +24
	WallThickness = 1,
	GroundFloorHeight = 12,
	StairwellWidth = 8,
	DoorWidth = 5,
	DoorHeight = 8,
}

City.WarZone = {
	ControlPoints = {
		{ label = "A", x = 0.22, z = 0.3 },
		{ label = "B", x = 0.62, z = 0.3 },
		{ label = "C", x = 0.45, z = 0.55 },
		{ label = "D", x = 0.3, z = 0.8 },
		{ label = "E", x = 0.75, z = 0.72 },
	},
	ControlPointRadius = 18,
	RedSpawn = { x = 0.9, z = 0.12 },
	BlueSpawn = { x = 0.12, z = 0.9 },
	FenceHeight = 12,
	Cover = 40, -- containers / barriers / ruined walls scattered inside
}

City.Props = {
	LampSpacing = 80, -- along sidewalks (alternating sides)
	ParkedCarChance = 0.35, -- per lamp slot, a car parked at the curb
	TreeSpacing = 40, -- Rich Hills and the plaza
	Hydrants = 30,
	Benches = 20,
	TrashCans = 40,
}

City.Boundary = {
	OuterGround = 220, -- ground around the city
	SeaWidth = 260, -- sea on the east side (terrain water)
	WallHeight = 60, -- invisible walls at the edge of the map
}

return City

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
export type Door = { x: number, w: number, h: number, open: boolean? } -- entrance on the front (+Z) face, x = center; open = no door leaf
export type Interior = { kind: string, height: number } -- furnished ground floor (Logic/CityParts.Interior)
export type Archetype = {
	w: number,
	d: number,
	h: number,
	material: string, -- body Enum.Material name
	colors: { string },
	texture: string?, -- tileable PBR texture (tools/meshgen/textures.py) applied to the walls
	door: Door, -- shared with tools/meshgen (the facade's door frame is drawn there)
	interior: Interior?,
}

City.Archetypes = {
	apartment = { w = 40, d = 30, h = 48, material = "Brick", texture = "brick_red", colors = { "#6B3A2E", "#7A4A38", "#5A3A30", "#4F3B34" }, door = { x = 0, w = 5, h = 8 }, interior = { kind = "lobby", height = 11 } },
	shop = { w = 32, d = 26, h = 24, material = "Brick", texture = "brick_dark", colors = { "#5E4A3E", "#3E3A40", "#6A4A3A", "#4A4E52" }, door = { x = 12, w = 4, h = 8 }, interior = { kind = "store", height = 11 } },
	office = { w = 44, d = 40, h = 100, material = "Concrete", texture = "concrete", colors = { "#5A5E66", "#4A4E56", "#6A6660" }, door = { x = 0, w = 6, h = 8.5 }, interior = { kind = "office", height = 10 } },
	tower = { w = 40, d = 40, h = 160, material = "Concrete", texture = "concrete", colors = { "#3E4450", "#4A4E58" }, door = { x = 0, w = 6, h = 8.5 }, interior = { kind = "office", height = 10 } },
	warehouse = { w = 60, d = 44, h = 26, material = "CorrodedMetal", texture = "metal_corrugated", colors = { "#5A5048", "#4A5058", "#6A5A48" }, door = { x = 0, w = 3.5, h = 7.5 }, interior = { kind = "warehouse", height = 24 } },
	chinatown = { w = 28, d = 24, h = 30, material = "Brick", texture = "brick_red", colors = { "#7A2E2A", "#8A5A2E", "#5A2A2E", "#6A3A30" }, door = { x = 10, w = 3.5, h = 7.5 }, interior = { kind = "restaurant", height = 9.5 } },
	mansion = { w = 56, d = 40, h = 22, material = "Plaster", texture = "plaster", colors = { "#E8E2D6", "#D8D0C0", "#EDE6DA" }, door = { x = 0, w = 5, h = 9 }, interior = { kind = "mansion", height = 10.5 } },
	ruin = { w = 44, d = 32, h = 18, material = "Concrete", texture = "concrete", colors = { "#4A4640", "#55504A" }, door = { x = 0, w = 6, h = 7, open = true }, interior = { kind = "squat", height = 9 } },
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
	-- utility poles and overhead wires along the trap house streets (the hood look)
	PoleSpacing = 84,
	PoleHeight = 26, -- the crossarm is 1.5 below the top
	WireOffsets = { -2.6, -0.9, 2.6 }, -- positions of the wires along the crossarm
	WireSag = 3,
	WireWidth = 0.12,
	-- traffic lights on the corners of the avenue intersections
	TrafficLights = true,
	-- rooftop billboards (lit at night)
	BillboardChance = 0.22, -- per shop / apartment in the districts below
	BillboardDistricts = { Strip = true, Downtown = true, Chinatown = true, Industrial = true },
}

-- Text of the rooftop billboards (in-game signage, so in English)
City.BillboardAds = {
	{ text = "CASH 4 GOLD", color = "#FFD84A", background = "#1A1A20" },
	{ text = "NEED A LAWYER? CALL 555-0199", color = "#FFFFFF", background = "#8A1E22" },
	{ text = "BAIL BONDS 24/7", color = "#111114", background = "#E8C23A" },
	{ text = "FRESH KICKS - THE STRIP", color = "#FFFFFF", background = "#1E3A8A" },
	{ text = "QUICK LOANS NO QUESTIONS", color = "#39FF88", background = "#101418" },
	{ text = "STAY IN SCHOOL", color = "#1A1A20", background = "#E8E2D6" },
	{ text = "LUCKY DRAGON BUFFET", color = "#FFD84A", background = "#7A1E1E" },
	{ text = "SEE SOMETHING? SAY NOTHING", color = "#FF3B3B", background = "#111114" },
}

-- Building interiors: every building has a furnished ground floor (Logic/CityParts.Interior) and a
-- door that opens when someone walks up to it (DoorController, client side)
City.Interiors = {
	Enabled = true,
	WallThickness = 1,
	DoorOpenDistance = 7, -- studs
	DoorOpenAngle = 100, -- degrees
	DoorSeconds = 0.35,
	CorridorWidth = 6, -- kept free of furniture in front of the door
	CorridorDepth = 8,
}

-- Instance streaming (phones only load what is around the player). Applied by MapBuilder.
City.Streaming = {
	TargetRadius = 640,
	MinRadius = 128,
	BuildingLod = false, -- Model.LevelOfDetail = StreamingMesh on tall buildings (ugly stand-ins, off)
}

City.Boundary = {
	OuterGround = 220, -- ground around the city
	SeaWidth = 260, -- sea on the east side (terrain water)
	WallHeight = 60, -- invisible walls at the edge of the map
}

return City

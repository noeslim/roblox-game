--!strict
-- Layout and look of the generated city block (CityService). Not balancing: pure visuals / layout.
-- If workspace already contains a Model/Folder named "City", nothing is generated and your map is used
-- (it must then contain workspace.Hideouts/Plot_N folders with a "Floor" part, see CityService).

return {
	Origin = { x = 0, y = 0, z = 300 }, -- center of the street, away from anything built near 0,0,0
	PlotsPerSide = 4, -- 8 plots in total: set the server size to 8 players in Experience Settings
	PlotGap = 10,
	StreetWidth = 28,
	SidewalkWidth = 8,
	SidewalkHeight = 0.5,
	StreetEndPadding = 40,
	BackWallHeight = 18,
	BuildingDepth = 40,
	BuildingWidthMin = 18,
	BuildingWidthMax = 34,
	BuildingHeightMin = 30,
	BuildingHeightMax = 90,
	WindowLitChance = 0.35,
	SignChance = 0.5,
	StreetLightSpacing = 30,
	Seed = 1337, -- same seed = same city every time

	Colors = {
		Asphalt = "#1B1B22",
		LaneMark = "#E8C547",
		Sidewalk = "#4A4A52",
		Lot = "#2C2C33",
		PlotFloor = "#34343C",
		PlotEdge = "#E8C547",
		BackWall = "#5B3129",
		Buildings = { "#2A2433", "#3A2E2A", "#23262E", "#3B3340", "#2E2A26" },
		Windows = { "#FFB347", "#FFD27A", "#FF3FA4", "#3FA9F5", "#39FF88" },
		Signs = { "#FF3FA4", "#3FA9F5", "#39FF88", "#FFB020", "#B45CFF" },
		StreetLight = "#FF9A3C",
		SignBoard = "#141418",
	},

	Signs = { "LIQUOR", "24/7", "PAWN SHOP", "MOTEL", "CHECKS CASHED", "NOODLES", "ARCADE", "BAR", "HOTEL", "GARAGE" },

	-- Lighting presets applied by WorldService when the phase changes
	Lighting = {
		TweenSeconds = 8,
		Day = { Brightness = 2, Ambient = "#5A5A6E", OutdoorAmbient = "#8C8CA0", FogColor = "#9AA3B8", ExposureCompensation = 0 },
		Night = { Brightness = 0.4, Ambient = "#1E1630", OutdoorAmbient = "#2A2046", FogColor = "#1A1430", ExposureCompensation = 0.3 },
		Atmosphere = { Density = 0.35, Haze = 1.5, Color = "#C7C0E0", Decay = "#6A5A8C" },
		Bloom = { Intensity = 0.6, Size = 30, Threshold = 1.2 },
		ColorCorrection = { Saturation = 0.1, Contrast = 0.1, TintColor = "#F2ECFF" },
	},
}

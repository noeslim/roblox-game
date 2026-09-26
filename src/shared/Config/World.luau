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
		Day = { Brightness = 2.2, Ambient = "#6E6E80", OutdoorAmbient = "#9A9AB0", FogColor = "#9AA3B8", ExposureCompensation = 0 },
		Night = { Brightness = 1, Ambient = "#34304A", OutdoorAmbient = "#454368", FogColor = "#10121E", ExposureCompensation = 0 },
		-- no haze/glare: they turn the whole street red at sunset
		Atmosphere = { Density = 0.25, Haze = 0, Glare = 0, Color = "#9FA8C8", Decay = "#3A3F5C" },
		Bloom = { Intensity = 0.4, Size = 24, Threshold = 1.6 }, -- only neon glows
		ColorCorrection = { Saturation = 0.05, Contrast = 0.08, TintColor = "#FFFFFF" },
	},

	Weather = {
		NightRainChance = 0.6, -- chance that a night is rainy
		DayRainChance = 0.1,
		RainRate = 700, -- particles per second (lower it for weak phones)
		RainArea = 90, -- studs, square above the camera
		RainHeight = 35,
		RainSpeed = 90,
		RainSize = 0.12,
		RainSquash = -3, -- stretches drops into streaks (ParticleEmitter.Squash)
		RainColor = "#AFC3E0",
		RainTransparency = 0.45,
		RainTexture = "", -- empty = Roblox default particle; put a streak texture id for nicer rain
		WetReflectance = 0.15, -- street reflectance while it rains
		RainAtmosphereDensity = 0.38,
	},

	Props = {
		FireBarrels = 6,
		Dumpsters = 6,
		TrashBags = 18,
		SteamVents = 5,
		Puddles = 14,
		FlickerSignChance = 0.35, -- part of the neon signs that flicker
	},

	-- Ambient sounds: paste ids from the Creator Store (Toolbox > Audio), e.g. "rbxassetid://123".
	-- Empty = no sound. Search: "city ambience loop", "rain loop", "police siren distant", "dog bark".
	Sounds = {
		CityLoop = "",
		RainLoop = "",
		Sirens = {} :: { string },
		SirenIntervalMin = 40,
		SirenIntervalMax = 110,
		Volume = 0.4,
	},

	StreetLight = { Brightness = 1.3, Range = 26, Angle = 90, Color = "#FFC48A" },
}

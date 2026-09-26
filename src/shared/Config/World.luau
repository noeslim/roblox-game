--!strict
-- Look of the city: lighting presets, weather, street lights, ambience, sounds. Not balancing.
-- The layout of the city itself is in Config/City.

return {
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

	-- Traffic lights (client side, Logic/TrafficCycle): north-south green, amber, all red, then east-west
	TrafficLights = {
		GreenSeconds = 14,
		AmberSeconds = 3,
		AllRedSeconds = 1.5,
		Colors = { signal_red = "#FF3B30", signal_amber = "#FFB020", signal_green = "#39FF88" },
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

--!strict
-- Look and sound of heat and raids (the rules and numbers are in Economy.Heat).
return {
	-- the heat gauge under the money counter
	Gauge = {
		Colors = { Clear = "#5A6070", Patrol = "#FFB020", Investigation = "#FF7A30", Raid = "#FF3B3B" },
		Labels = { Clear = "LOW", Patrol = "PATROL", Investigation = "WATCHED", Raid = "RAID" },
	},
	-- police lights at the raided trap house (seen by everyone around)
	Lights = {
		Red = "#FF2A2A",
		Blue = "#2A5BFF",
		FlashHz = 2.5, -- red/blue swaps per second
		Range = 26,
		Brightness = 3,
	},
	-- the owner's screen during a raid: colored edges that pulse red and blue
	ScreenPulse = { Transparency = 0.82, Width = 0.12 },
	Inspector = {
		Shirt = "#1C2A44",
		Pants = "#14161C",
		Skin = { "#F1C27D", "#C68642", "#8D5524", "#FFDBAC" },
		Cap = "#10141E",
		WalkSpeed = 12,
		LookSeconds = 2.2, -- at each thing searched
		MaxStops = 4,
		InvestigationLookSeconds = 7, -- the lone inspector who comes to your door at level Investigation
	},
	HideHoldSeconds = 1, -- hold E on a secret compartment
	-- the stock that is not hidden shows in the stash (racks, display cases, piles on supply crates)
	Stock = {
		WeaponScale = 0.5,
		PileLayers = 2, -- layers of things on a supply crate (3 rows each)
		BoxSize = { x = 1.4, y = 0.6, z = 0.85 }, -- a box of parts
		BoxColor = "#8A6B45",
		ContrabandTape = "#C0392B", -- stripe on boxes of contraband parts
		Highlight = "#FF3B3B", -- outline of what will be seized, during a raid
	},
	Sounds = {
		Siren = "", -- looped during the countdown (Toolbox: "police siren")
		Hide = "", -- stock hidden ("wood slide", "drawer")
		Report = "", -- raid report shown
		Volume = 0.6,
	},
}

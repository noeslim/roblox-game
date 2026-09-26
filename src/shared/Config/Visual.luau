--!strict
-- Look of procedurally generated things (weapons, customers) and sound ids.
-- Replace the sound ids with your own from the Creator Store (rbxassetid://...).

export type WeaponPiece = { size: { x: number, y: number, z: number }, pos: { x: number, y: number, z: number }, shape: string? }

return {
	-- true: grounded feedback (sounds, small notifications, the first-person crafting scene) instead of
	-- arcade effects (floating texts, sparkles, flying bills, flashes)
	Realistic = true,

	-- base color of a part per set; parts without a set use their rarity color
	SetColors = {
		Street = "#6B5B4B",
		Neon = "#1FD1E0",
		Ghost = "#1C1F26",
	},
	-- placeholder weapon model: one piece per slot (studs, relative to the weapon center)
	WeaponLayout = {
		Body = { size = { x = 1.6, y = 0.7, z = 0.4 }, pos = { x = 0, y = 0, z = 0 } },
		Barrel = { size = { x = 1.4, y = 0.3, z = 0.3 }, pos = { x = 1.5, y = 0.12, z = 0 }, shape = "Cylinder" },
		Stock = { size = { x = 1.0, y = 0.5, z = 0.35 }, pos = { x = -1.3, y = -0.1, z = 0 } },
		Sight = { size = { x = 0.6, y = 0.25, z = 0.25 }, pos = { x = 0.2, y = 0.48, z = 0 } },
		Magazine = { size = { x = 0.35, y = 0.8, z = 0.3 }, pos = { x = 0.35, y = -0.7, z = 0 } },
	} :: { [string]: WeaponPiece },

	CustomerSkinColors = { "#F1C27D", "#E0AC69", "#C68642", "#8D5524", "#5C3A21", "#FFDBAC" },
	CustomerShirtColors = { "#1B1B22", "#3A2E5C", "#5C1F2E", "#1F3A5C", "#2E4A2E", "#4A4A52", "#6B4A2E" },
	CustomerPantsColors = { "#15151A", "#23262E", "#2B2D33", "#3B3340" },

	Sounds = {
		Cash = "rbxasset://sounds/electronicpingshort.wav",
		Craft = "rbxasset://sounds/electronicpingshort.wav",
		Place = "rbxasset://sounds/electronicpingshort.wav",
		Error = "rbxasset://sounds/electronicpingshort.wav",
	},
}

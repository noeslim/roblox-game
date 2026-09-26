--!strict
-- Weapon parts catalogue. Stats are additive; the weapon's stats are the sum of its parts.
-- stats keys: Damage, FireRate, Range, Accuracy, Reload

export type PartDef = {
	id: string,
	name: string,
	slot: string,
	rarity: string,
	set: string?,
	value: number, -- base value in $ before rarity multiplier
	contraband: boolean?,
	stats: { [string]: number },
}

local Parts: { [string]: PartDef } = {}

local function add(def: PartDef)
	assert(Parts[def.id] == nil, "duplicate part id " .. def.id)
	Parts[def.id] = def
end

-- Street set (Common) -------------------------------------------------------
add({ id = "street_body", name = "Street Frame", slot = "Body", rarity = "Common", set = "Street", value = 40, stats = { Damage = 8, FireRate = 4 } })
add({ id = "street_barrel", name = "Pipe Barrel", slot = "Barrel", rarity = "Common", set = "Street", value = 25, stats = { Damage = 4, Range = 20 } })
add({ id = "street_stock", name = "Taped Stock", slot = "Stock", rarity = "Common", set = "Street", value = 20, stats = { Accuracy = 5 } })
add({ id = "street_sight", name = "Iron Sight", slot = "Sight", rarity = "Common", set = "Street", value = 20, stats = { Accuracy = 6, Range = 5 } })
add({ id = "street_mag", name = "Rusty Mag", slot = "Magazine", rarity = "Common", set = "Street", value = 25, stats = { Reload = 2 } })

-- Neon set (Uncommon) -------------------------------------------------------
add({ id = "neon_body", name = "Neon Frame", slot = "Body", rarity = "Uncommon", set = "Neon", value = 60, stats = { Damage = 11, FireRate = 6 } })
add({ id = "neon_barrel", name = "Glow Barrel", slot = "Barrel", rarity = "Uncommon", set = "Neon", value = 45, stats = { Damage = 6, Range = 28 } })
add({ id = "neon_stock", name = "Light Stock", slot = "Stock", rarity = "Uncommon", set = "Neon", value = 35, stats = { Accuracy = 8 } })
add({ id = "neon_sight", name = "Holo Sight", slot = "Sight", rarity = "Uncommon", set = "Neon", value = 40, stats = { Accuracy = 10, Range = 8 } })
add({ id = "neon_mag", name = "Cell Mag", slot = "Magazine", rarity = "Uncommon", set = "Neon", value = 40, stats = { Reload = 4 } })

-- Ghost set (Rare, contraband) ---------------------------------------------
add({ id = "ghost_body", name = "Ghost Frame", slot = "Body", rarity = "Rare", set = "Ghost", value = 90, contraband = true, stats = { Damage = 15, FireRate = 7 } })
add({ id = "ghost_barrel", name = "Silent Barrel", slot = "Barrel", rarity = "Rare", set = "Ghost", value = 70, contraband = true, stats = { Damage = 8, Range = 34 } })
add({ id = "ghost_sight", name = "Thermal Sight", slot = "Sight", rarity = "Rare", set = "Ghost", value = 65, contraband = true, stats = { Accuracy = 14, Range = 12 } })

-- Loose parts (no set) -----------------------------------------------------
add({ id = "drum_mag", name = "Drum Mag", slot = "Magazine", rarity = "Epic", value = 80, contraband = true, stats = { Reload = -2, FireRate = 5 } })
add({ id = "gold_stock", name = "Gold Stock", slot = "Stock", rarity = "Legendary", value = 120, stats = { Accuracy = 12 } })

return Parts

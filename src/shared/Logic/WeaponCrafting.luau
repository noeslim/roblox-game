--!strict
-- Assembles a weapon from 5 parts. Pure: receives the parts catalogue and economy config.

local WeaponCrafting = {}

export type Weapon = {
	parts: { [string]: string }, -- slot -> part id
	stats: { [string]: number },
	rarity: string,
	value: number,
	suggestedPrice: number,
	fullSet: string?,
	contraband: boolean,
	brand: string,
}

local STAT_KEYS = { "Damage", "FireRate", "Range", "Accuracy", "Reload" }

local function rarityIndex(economy: any, rarity: string): number
	for i, r in economy.RarityOrder do
		if r == rarity then
			return i
		end
	end
	error("unknown rarity " .. tostring(rarity))
end

-- partIds: { [slot]: partId }
-- Returns (weapon, nil) or (nil, errorCode)
function WeaponCrafting.Craft(partIds: { [string]: string }, brand: string, catalogue: { [string]: any }, economy: any): (Weapon?, string?)
	if type(partIds) ~= "table" then
		return nil, "InvalidInput"
	end

	local slots = economy.Crafting.Slots
	local stats: { [string]: number } = {}
	for _, key in STAT_KEYS do
		stats[key] = 0
	end

	local value = 0
	local rarityTotal = 0
	local firstSet: string? = nil
	local sameSet = true
	local contraband = false
	local cleanParts: { [string]: string } = {}

	for _, slot in slots do
		local id = partIds[slot]
		if id == nil then
			return nil, "MissingSlot:" .. slot
		end
		local part = catalogue[id]
		if part == nil then
			return nil, "UnknownPart:" .. tostring(id)
		end
		if part.slot ~= slot then
			return nil, "WrongSlot:" .. tostring(id)
		end

		cleanParts[slot] = id
		for key, amount in part.stats do
			stats[key] = (stats[key] or 0) + amount
		end

		value += part.value * economy.RarityMultiplier[part.rarity]
		rarityTotal += rarityIndex(economy, part.rarity)
		contraband = contraband or (part.contraband == true)

		if firstSet == nil then
			firstSet = part.set
		end
		if part.set == nil or part.set ~= firstSet then
			sameSet = false
		end
	end

	-- extra keys (unknown slots) are rejected to avoid exploit payloads
	for slot in partIds do
		if cleanParts[slot] == nil then
			return nil, "UnknownSlot:" .. tostring(slot)
		end
	end

	local fullSet: string? = if sameSet then firstSet else nil
	if fullSet then
		value *= 1 + economy.Crafting.FullSetBonus
	end

	-- weapon rarity = average part rarity, rounded down
	local avgIndex = math.max(1, math.floor(rarityTotal / #slots))
	local rarity = economy.RarityOrder[avgIndex]

	value = math.floor(value + 0.5)

	return {
		parts = cleanParts,
		stats = stats,
		rarity = rarity,
		value = value,
		suggestedPrice = math.floor(value * economy.Crafting.SuggestedPriceMultiplier + 0.5),
		fullSet = fullSet,
		contraband = contraband,
		brand = brand,
	}, nil
end

-- Commission paid to the brand owner when their weapon gets a K.O.
function WeaponCrafting.KnockoutCommission(weaponValue: number, economy: any): number
	local c = economy.BrandCommission
	return math.min(math.floor(weaponValue * c.Rate), c.MaxPerKnockout)
end

return WeaponCrafting

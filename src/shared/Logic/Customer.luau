--!strict
-- NPC customer generation and buying decisions. Pure: randomness is injected.

local Customer = {}

export type Rng = {
	NextNumber: (self: any, min: number, max: number) -> number,
}

export type CustomerData = {
	personality: string,
	budgetMultiplier: number, -- applied to a weapon's suggested price
	patience: number,
	tip: number,
	negotiates: boolean,
	minRarity: string?,
	wantsContraband: boolean,
}

export type Decision = "Accept" | "Counter" | "Refuse"

local function sortedNames(personalities: { [string]: any }): { string }
	local names = {}
	for name in personalities do
		table.insert(names, name)
	end
	table.sort(names) -- deterministic order for seeded tests
	return names
end

function Customer.Generate(rng: Rng, customersCfg: any, isNight: boolean): CustomerData
	local names = sortedNames(customersCfg.Personalities)

	local total = 0
	for _, name in names do
		local p = customersCfg.Personalities[name]
		if isNight or not p.nightOnly then
			total += p.weight
		end
	end

	local roll = rng:NextNumber(0, total)
	local chosen = names[1]
	local acc = 0
	for _, name in names do
		local p = customersCfg.Personalities[name]
		if isNight or not p.nightOnly then
			acc += p.weight
			chosen = name
			if roll <= acc then
				break
			end
		end
	end

	local p = customersCfg.Personalities[chosen]
	return {
		personality = chosen,
		budgetMultiplier = rng:NextNumber(p.budgetMin, p.budgetMax),
		patience = p.patience,
		tip = p.tip,
		negotiates = p.negotiates,
		minRarity = p.minRarity,
		wantsContraband = p.wantsContraband == true,
	}
end

local function rarityIndex(order: { string }, rarity: string): number
	return table.find(order, rarity) or 1
end

-- Can this customer be interested in this weapon at all?
function Customer.IsInterested(c: CustomerData, weapon: { rarity: string, contraband: boolean }, rarityOrder: { string }): boolean
	if c.minRarity and rarityIndex(rarityOrder, weapon.rarity) < rarityIndex(rarityOrder, c.minRarity) then
		return false
	end
	if c.wantsContraband and not weapon.contraband then
		return false
	end
	return true
end

-- Returns decision and, for "Counter", the counter-offer price.
function Customer.EvaluateOffer(c: CustomerData, price: number, suggestedPrice: number, customersCfg: any): (Decision, number?)
	local budget = math.floor(suggestedPrice * c.budgetMultiplier)
	if price <= budget then
		return "Accept", nil
	end
	if c.negotiates and price <= budget * (1 + customersCfg.NegotiationTolerance) then
		return "Counter", budget
	end
	return "Refuse", nil
end

-- Tip given when served within FastServiceSeconds.
function Customer.Tip(c: CustomerData, price: number, waitedSeconds: number, customersCfg: any): number
	if waitedSeconds > customersCfg.FastServiceSeconds then
		return 0
	end
	return math.floor(price * c.tip)
end

return Customer

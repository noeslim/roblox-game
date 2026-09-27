--!strict
-- Night prices that move (GAME_DESIGN §11, roadmap 2.3). Pure: the night number and what was
-- bought are handed in.
--  * Black market supply: each offer has a limited quantity per night, and every unit bought on the
--    server pushes its price up (demand), until the next night brings a new stock.
--  * Street demand: at night contraband weapons sell with a premium, and one part set is "hot"
--    (weapons with a part of that set sell with a bonus). Both multiply what the customer pays.

local Market = {}

export type Offer = { id: string, price: number, quantity: number } -- from Logic/BlackMarket
export type LiveOffer = { id: string, price: number, left: number, base: number }

-- Price of the next unit once `sold` units were bought tonight.
function Market.UnitPrice(base: number, sold: number, cfg: any): number
	local rise = math.min(sold * cfg.DemandStep, cfg.MaxRise)
	return math.max(1, math.floor(base * (1 + rise) + 0.5))
end

-- Total for `amount` units, each one priced after the previous ones.
function Market.Cost(base: number, sold: number, amount: number, cfg: any): number
	local total = 0
	for n = 0, amount - 1 do
		total += Market.UnitPrice(base, sold + n, cfg)
	end
	return total
end

-- Tonight's offers as the players see them: current price and units left.
function Market.Live(stock: { Offer }, sold: { [string]: number }, cfg: any): { LiveOffer }
	local out: { LiveOffer } = {}
	for _, offer in stock do
		local n = sold[offer.id] or 0
		table.insert(out, {
			id = offer.id,
			base = offer.price,
			price = Market.UnitPrice(offer.price, n, cfg),
			left = math.max(0, offer.quantity - n),
		})
	end
	return out
end

-- The part set the street wants tonight (nil when the catalogue has no set).
function Market.HotSet(night: number, catalogue: { [string]: any }): string?
	local sets: { string } = {}
	local seen: { [string]: boolean } = {}
	for _, part in catalogue do
		if part.set and not seen[part.set] then
			seen[part.set] = true
			table.insert(sets, part.set)
		end
	end
	if #sets == 0 then
		return nil
	end
	table.sort(sets)
	local state = (night * 48271 + 12345) % 2147483647
	return sets[state % #sets + 1]
end

-- What a sale is multiplied by, and why: { night = x, hot = x } (only the ones that apply).
function Market.SaleMultiplier(partIds: { [string]: string }, contraband: boolean, isNight: boolean, hotSet: string?, catalogue: { [string]: any }, cfg: any): (number, { [string]: number })
	local reasons: { [string]: number } = {}
	local mult = 1
	if isNight and contraband then
		reasons.night = cfg.NightContrabandMultiplier
		mult *= cfg.NightContrabandMultiplier
	end
	if isNight and hotSet then
		for _, id in partIds do
			local part = catalogue[id]
			if part and part.set == hotSet then
				reasons.hot = 1 + cfg.HotSetBonus
				mult *= 1 + cfg.HotSetBonus
				break
			end
		end
	end
	return mult, reasons
end

return Market

--!strict
-- Tonight's black market stock: a few contraband parts at a price that changes every night.
-- Pure and deterministic: the night number is injected (BlackMarket.NightIndex).

local BlackMarket = {}

export type Offer = { id: string, price: number }

-- Number of the current day+night cycle; the market of one night keeps the same stock.
function BlackMarket.NightIndex(now: number, dayNight: any): number
	return math.floor(now / (dayNight.DayLength + dayNight.NightLength))
end

function BlackMarket.Stock(night: number, catalogue: { [string]: any }, economy: any): { Offer }
	local ids = {}
	for id, part in catalogue do
		if part.contraband then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	local cfg = economy.BlackMarket
	local state = (night * 16807 + 911) % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	local function rand(): number
		state = (state * 48271) % 2147483647
		return state / 2147483647
	end
	local offers: { Offer } = {}
	for _ = 1, math.min(cfg.StockSize, #ids) do
		local pick = math.floor(rand() * #ids) + 1
		local id = table.remove(ids, pick) :: string
		local part = catalogue[id]
		local base = part.value * economy.RarityMultiplier[part.rarity]
		local price = base * (cfg.PriceMin + (cfg.PriceMax - cfg.PriceMin) * rand())
		table.insert(offers, { id = id, price = math.max(1, math.floor(price + 0.5)) })
	end
	return offers
end

function BlackMarket.Find(stock: { Offer }, id: string): Offer?
	for _, offer in stock do
		if offer.id == id then
			return offer
		end
	end
	return nil
end

return BlackMarket

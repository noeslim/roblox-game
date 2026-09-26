--!strict
-- Legal supplier prices and dealer price validation. Pure.

local Shop = {}

-- Price of one part at the legal supplier, or nil if the supplier does not sell it.
function Shop.PartPrice(part: any, economy: any): number?
	if part == nil or part.contraband then
		return nil
	end
	if not table.find(economy.Supplier.Rarities, part.rarity) then
		return nil
	end
	local price = part.value * economy.RarityMultiplier[part.rarity] * economy.Supplier.PriceMultiplier
	return math.max(1, math.floor(price + 0.5))
end

-- Sorted list of part ids sold by the supplier (by slot order, then price).
function Shop.Catalogue(catalogue: { [string]: any }, economy: any): { string }
	local list = {}
	for id, part in catalogue do
		if Shop.PartPrice(part, economy) then
			table.insert(list, id)
		end
	end
	local slots = economy.Crafting.Slots
	table.sort(list, function(a, b)
		local sa = table.find(slots, catalogue[a].slot) or 0
		local sb = table.find(slots, catalogue[b].slot) or 0
		if sa ~= sb then
			return sa < sb
		end
		local pa, pb = Shop.PartPrice(catalogue[a], economy) :: number, Shop.PartPrice(catalogue[b], economy) :: number
		if pa ~= pb then
			return pa < pb
		end
		return a < b
	end)
	return list
end

function Shop.MaxPrice(weaponValue: number, economy: any): number
	return math.max(economy.Pricing.MinPrice, math.floor(weaponValue * economy.Pricing.MaxPriceMultiplier))
end

-- Returns (ok, errorCode) for a price chosen by the dealer.
function Shop.ValidatePrice(price: any, weaponValue: number, economy: any): (boolean, string?)
	if type(price) ~= "number" or price ~= price or math.floor(price) ~= price then
		return false, "InvalidPrice"
	end
	if price < economy.Pricing.MinPrice then
		return false, "PriceTooLow"
	end
	if price > Shop.MaxPrice(weaponValue, economy) then
		return false, "PriceTooHigh"
	end
	return true, nil
end

-- Price after pressing +/- `steps` times (steps of PriceStep x suggested price), clamped.
function Shop.StepPrice(price: number, steps: number, suggestedPrice: number, weaponValue: number, economy: any): number
	local step = math.max(1, math.floor(suggestedPrice * economy.Pricing.PriceStep + 0.5))
	local p = price + steps * step
	return math.clamp(p, economy.Pricing.MinPrice, Shop.MaxPrice(weaponValue, economy))
end

return Shop

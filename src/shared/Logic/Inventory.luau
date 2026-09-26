--!strict
-- Part inventory: { [partId]: count }. Pure, works in place on the given table.

local Inventory = {}

export type Parts = { [string]: number }

function Inventory.Count(parts: Parts, id: string): number
	return parts[id] or 0
end

-- Adds up to the stack cap. Returns how many were actually added.
function Inventory.Add(parts: Parts, id: string, amount: number, maxStack: number): number
	if amount <= 0 or math.floor(amount) ~= amount then
		return 0
	end
	local have = parts[id] or 0
	local added = math.max(0, math.min(amount, maxStack - have))
	if added > 0 then
		parts[id] = have + added
	end
	return added
end

function Inventory.Remove(parts: Parts, id: string, amount: number): boolean
	local have = parts[id] or 0
	if amount <= 0 or have < amount then
		return false
	end
	local left = have - amount
	if left > 0 then
		parts[id] = left
	else
		(parts :: any)[id] = nil
	end
	return true
end

-- partIds: { [slot]: partId } (a recipe). Counts duplicates in case two slots use the same id.
local function needed(partIds: { [string]: string }): { [string]: number }
	local need: { [string]: number } = {}
	for _, id in partIds do
		need[id] = (need[id] or 0) + 1
	end
	return need
end

function Inventory.HasAll(parts: Parts, partIds: { [string]: string }): boolean
	for id, n in needed(partIds) do
		if (parts[id] or 0) < n then
			return false
		end
	end
	return true
end

-- Atomic: removes nothing if one part is missing.
function Inventory.RemoveAll(parts: Parts, partIds: { [string]: string }): boolean
	if not Inventory.HasAll(parts, partIds) then
		return false
	end
	for id, n in needed(partIds) do
		Inventory.Remove(parts, id, n)
	end
	return true
end

-- Owned part ids for one slot, sorted by rarity then name (for the workbench UI).
function Inventory.OwnedForSlot(parts: Parts, catalogue: { [string]: any }, slot: string, rarityOrder: { string }): { string }
	local list = {}
	for id, n in parts do
		local def = catalogue[id]
		if n > 0 and def and def.slot == slot then
			table.insert(list, id)
		end
	end
	table.sort(list, function(a, b)
		local ra = table.find(rarityOrder, catalogue[a].rarity) or 0
		local rb = table.find(rarityOrder, catalogue[b].rarity) or 0
		if ra ~= rb then
			return ra < rb
		end
		return a < b
	end)
	return list
end

return Inventory

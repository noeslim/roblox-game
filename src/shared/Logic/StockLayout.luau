--!strict
-- Where the stock that is not hidden shows in the stash: weapons on racks and in display cases,
-- the rest piled on supply crates (weapons and boxes of parts). What shows is what the cops see.
-- Pure: the caller hands in the items in order (contraband first) and the places built.

local StockLayout = {}

export type Kind = "standing" | "lying" | "pile"
export type Place = { kind: Kind, slots: number }
export type Item = { ref: string, kind: "weapon" | "parts" }
-- place: index in the places list; slot: 1..slots; layer: 1.. (piles only, 1 otherwise)
export type Spot = { item: Item, place: number, slot: number, layer: number }

-- Returns the spots, and how many items found no room.
function StockLayout.Assign(items: { Item }, places: { Place }, maxLayers: number): ({ Spot }, number)
	local used: { [number]: { [number]: number } } = {} -- place -> slot -> items in it
	for i, p in places do
		used[i] = {}
		for s = 1, p.slots do
			used[i][s] = 0
		end
	end
	local spots: { Spot } = {}
	local overflow = 0

	local function take(item: Item, accept: (Place) -> boolean, cap: (Place) -> number): boolean
		for i, p in places do
			if accept(p) then
				for s = 1, p.slots do
					if used[i][s] < cap(p) then
						used[i][s] += 1
						table.insert(spots, { item = item, place = i, slot = s, layer = used[i][s] })
						return true
					end
				end
			end
		end
		return false
	end

	for _, item in items do
		local placed = false
		if item.kind == "weapon" then
			-- a rack or a case first (one weapon each), then a pile
			placed = take(item, function(p)
				return p.kind ~= "pile"
			end, function()
				return 1
			end)
		end
		if not placed then
			placed = take(item, function(p)
				return p.kind == "pile"
			end, function()
				return maxLayers
			end)
		end
		if not placed then
			overflow += 1
		end
	end
	return spots, overflow
end

return StockLayout

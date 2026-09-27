--!strict
-- What the cops can find in a stash, how secret compartments hide it, and the raid timeline.
-- Pure: the caller hands in the saved weapons / parts and the compartments built in the stash.
-- Seizing itself is Logic/Heat.ResolveRaid (these items are Heat.StashItem plus a reference).

local Raid = {}

export type Compartment = { level: number, capacity: number }

-- One seizable thing: a contraband weapon, or ONE unit of a contraband part.
export type Item = {
	id: string, -- unique in the list
	kind: "weapon" | "part",
	ref: string, -- weapon id or part id
	value: number,
	contraband: boolean,
	hidden: boolean,
	hiddenLevel: number?,
}

export type WeaponInfo = { id: string, value: number, contraband: boolean, hidden: boolean? }

-- Everything contraband in the stash. Parts come one item per unit; the hidden units of a part
-- (hiddenParts[id]) are its first units.
function Raid.Items(weapons: { WeaponInfo }, parts: { [string]: number }, hiddenParts: { [string]: number }, catalogue: { [string]: any }): { Item }
	local items: { Item } = {}
	for _, w in weapons do
		if w.contraband then
			table.insert(items, { id = "w:" .. w.id, kind = "weapon", ref = w.id, value = w.value, contraband = true, hidden = w.hidden == true })
		end
	end
	local ids = {}
	for id in parts do
		table.insert(ids, id)
	end
	table.sort(ids) -- deterministic order
	for _, id in ids do
		local def = catalogue[id]
		if def and def.contraband then
			local hiddenCount = math.min(hiddenParts[id] or 0, parts[id])
			for n = 1, parts[id] do
				table.insert(items, {
					id = ("p:%s:%d"):format(id, n),
					kind = "part",
					ref = id,
					value = def.value or 0,
					contraband = true,
					hidden = n <= hiddenCount,
				})
			end
		end
	end
	return items
end

function Raid.Capacity(compartments: { Compartment }): number
	local total = 0
	for _, c in compartments do
		total += c.capacity
	end
	return total
end

local function byValue(a: Item, b: Item): boolean
	if a.value ~= b.value then
		return a.value > b.value
	end
	return a.id < b.id
end

-- Puts the hidden items into the compartments: the most valuable ones in the best compartments.
-- Hidden items that do not fit anywhere (a compartment was removed) are visible again.
-- Returns new tables; `hiddenLevel` is set on every item that stays hidden.
function Raid.Allocate(items: { Item }, compartments: { Compartment }): { Item }
	local slots = {}
	for _, c in compartments do
		table.insert(slots, { level = c.level, left = c.capacity })
	end
	table.sort(slots, function(a, b)
		return a.level > b.level
	end)
	local hidden: { Item } = {}
	local out: { Item } = {}
	for _, item in items do
		local copy = table.clone(item)
		copy.hiddenLevel = nil
		if copy.hidden then
			table.insert(hidden, copy)
		end
		table.insert(out, copy)
	end
	table.sort(hidden, byValue)
	local s = 1
	for _, item in hidden do
		while slots[s] and slots[s].left <= 0 do
			s += 1
		end
		local slot = slots[s]
		if slot then
			slot.left -= 1
			item.hiddenLevel = slot.level
		else
			item.hidden = false
		end
	end
	return out
end

-- The visible contraband to hide in the free room: the most valuable first.
function Raid.PickToHide(items: { Item }, compartments: { Compartment }): { Item }
	local allocated = Raid.Allocate(items, compartments)
	local used = 0
	local visible: { Item } = {}
	for _, item in allocated do
		if item.contraband then
			if item.hidden then
				used += 1
			else
				table.insert(visible, item)
			end
		end
	end
	table.sort(visible, byValue)
	local free = math.max(0, Raid.Capacity(compartments) - used)
	local pick: { Item } = {}
	for i = 1, math.min(free, #visible) do
		table.insert(pick, visible[i])
	end
	return pick
end

function Raid.CountVisible(items: { Item }, compartments: { Compartment }): number
	local n = 0
	for _, item in Raid.Allocate(items, compartments) do
		if item.contraband and not item.hidden then
			n += 1
		end
	end
	return n
end

-- What was seized, grouped: weapon ids, units per part id, and how many of those units were hidden
-- (to lower the saved hidden counts).
function Raid.Group(seized: { any }): ({ [string]: boolean }, { [string]: number }, { [string]: number })
	local weapons: { [string]: boolean } = {}
	local parts: { [string]: number } = {}
	local hiddenParts: { [string]: number } = {}
	for _, item in seized do
		if item.kind == "weapon" then
			weapons[item.ref] = true
		elseif item.kind == "part" then
			parts[item.ref] = (parts[item.ref] or 0) + 1
			if item.hidden then
				hiddenParts[item.ref] = (hiddenParts[item.ref] or 0) + 1
			end
		end
	end
	return weapons, parts, hiddenParts
end

-- Timeline: sirens and the countdown to hide the stock, then the search, then the report.
export type Plan = { search: number, total: number }
export type Phase = "Warning" | "Search" | "Done"

function Raid.Plan(cfg: { RaidWarningSeconds: number, SearchSeconds: number }): Plan
	return { search = cfg.RaidWarningSeconds, total = cfg.RaidWarningSeconds + cfg.SearchSeconds }
end

function Raid.Phase(plan: Plan, t: number): Phase
	if t >= plan.total then
		return "Done"
	elseif t >= plan.search then
		return "Search"
	end
	return "Warning"
end

return Raid

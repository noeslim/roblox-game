--!strict
-- Saved player profile: shape, version migrations and sanitizing. Pure: no Roblox APIs.
-- Every function works IN PLACE on the given table, because ProfileStore saves profile.Data itself.
--
-- Adding a field or changing the shape:
--   1. bump ProfileSchema.VERSION
--   2. add Migrations[oldVersion] that upgrades a table from oldVersion to oldVersion + 1
--   3. update Template() and Sanitize(), then add a test in tests/specs/ProfileSchema.spec.luau

local ProfileSchema = {}

ProfileSchema.VERSION = 5

export type WeaponData = {
	id: string,
	parts: { [string]: string }, -- slot -> part id
	name: string?,
	price: number?, -- price chosen by the dealer; nil = suggested price
	hidden: boolean?, -- in a secret compartment (Logic/Raid)
}

export type HideoutData = {
	Objects: { string }, -- "buildableId,x,z,rotation" (see Logic/Hideout)
}

export type StatsData = {
	Crafted: number,
	Sold: number,
	Earned: number,
}

export type DailyData = { LastDay: number, Streak: number }
export type ContractEntry = { id: string, progress: number, done: boolean }
export type ContractsData = { Day: number, List: { ContractEntry } }
-- Heat gauge of the stash (Logic/Heat). LastRaidAt: os.time(). PendingRaid: a raid had started
-- when the player left; it is resolved at the next join.
export type HeatData = { Value: number, LastRaidAt: number, PendingRaid: boolean }

export type ProfileData = {
	Version: number,
	Money: number,
	Level: number,
	Xp: number,
	Parts: { [string]: number }, -- part id -> count
	Weapons: { WeaponData },
	Hideout: HideoutData,
	Stats: StatsData,
	Daily: DailyData,
	Contracts: ContractsData,
	Heat: HeatData,
	HiddenParts: { [string]: number }, -- part id -> units in secret compartments (<= Parts[id])
}

export type SchemaConfig = {
	startingMoney: number,
	maxMoney: number,
	starterParts: { [string]: number },
	maxPartStack: number,
	maxWeapons: number,
	maxLevel: number,
	maxWeaponNameLength: number,
	maxHideoutObjects: number,
	starterHideout: { string },
	parts: { [string]: any }, -- the parts catalogue (Config/Parts); only `.slot` is read
	contractIds: { [string]: number }, -- contract id -> target (Config/Economy.Contracts)
	contractsPerDay: number,
	maxHeat: number,
}

-- Builds the SchemaConfig from Config/Economy and Config/Parts.
function ProfileSchema.ConfigFrom(economy: any, parts: { [string]: any }): SchemaConfig
	local p = economy.Profile
	local contractIds = {}
	for _, def in economy.Contracts.Pool do
		contractIds[def.id] = def.target
	end
	return {
		startingMoney = economy.StartingMoney,
		maxMoney = economy.MaxMoney,
		starterParts = p.StarterParts,
		maxPartStack = p.MaxPartStack,
		maxWeapons = p.MaxWeapons,
		maxLevel = p.MaxLevel,
		maxWeaponNameLength = p.MaxWeaponNameLength,
		maxHideoutObjects = economy.Building.MaxObjectsExtended,
		starterHideout = p.StarterHideout,
		parts = parts,
		contractIds = contractIds,
		contractsPerDay = economy.Contracts.PerDay,
		maxHeat = economy.Heat.Max,
	}
end

export type Migration = (data: any, cfg: SchemaConfig) -> ()

-- Migrations[v] upgrades a profile from version v to v + 1. Version 0 = profile saved before versioning.
ProfileSchema.Migrations = {
	[0] = function(data: any, cfg: SchemaConfig)
		-- nothing to convert: the missing fields are filled by Sanitize
	end,
	[1] = function(data: any, cfg: SchemaConfig)
		-- v2 introduced building: v1 stashes were always empty, give them the starter furniture
		if type(data.Hideout) ~= "table" or type(data.Hideout.Objects) ~= "table" or #data.Hideout.Objects == 0 then
			data.Hideout = { Objects = table.clone(cfg.starterHideout) }
		end
	end,
	[2] = function(data: any, cfg: SchemaConfig)
		-- v3 moved stashes into trap house basements: the starter counter moves back so that the
		-- queue of customers fits before the front wall
		if type(data.Hideout) == "table" and type(data.Hideout.Objects) == "table" then
			for i, s in data.Hideout.Objects do
				if s == "counter_folding,0,14,0" then
					data.Hideout.Objects[i] = "counter_folding,0,6,0"
				end
			end
		end
	end,
	[3] = function(data: any, cfg: SchemaConfig)
		-- v4 added the daily streak and daily contracts: filled with defaults by Sanitize
	end,
	[4] = function(data: any, cfg: SchemaConfig)
		-- v5 added the heat gauge and hidden stock: filled with defaults by Sanitize
	end,
} :: { [number]: Migration }

local function isFiniteNumber(v: any): boolean
	return type(v) == "number" and v == v and v > -math.huge and v < math.huge
end

local function wholeInRange(v: any, min: number, max: number, default: number): number
	if not isFiniteNumber(v) then
		return default
	end
	return math.clamp(math.floor(v), min, max)
end

function ProfileSchema.Template(cfg: SchemaConfig): ProfileData
	return {
		Version = ProfileSchema.VERSION,
		Money = cfg.startingMoney,
		Level = 1,
		Xp = 0,
		Parts = table.clone(cfg.starterParts),
		Weapons = {},
		Hideout = { Objects = table.clone(cfg.starterHideout) },
		Stats = { Crafted = 0, Sold = 0, Earned = 0 },
		Daily = { LastDay = 0, Streak = 0 },
		Contracts = { Day = 0, List = {} },
		Heat = { Value = 0, LastRaidAt = 0, PendingRaid = false },
		HiddenParts = {},
	}
end

-- Upgrades `data` to `target` (default: VERSION). Returns (ok, errorCode).
-- "FutureVersion": the profile was saved by a newer server; it must NOT be loaded or overwritten.
function ProfileSchema.Migrate(data: any, cfg: SchemaConfig, migrations: { [number]: Migration }?, target: number?): (boolean, string?)
	if type(data) ~= "table" then
		return false, "NotATable"
	end
	local list = migrations or ProfileSchema.Migrations
	local goal = target or ProfileSchema.VERSION
	local version = data.Version
	if version == nil then
		version = 0
	elseif not isFiniteNumber(version) or version < 0 or math.floor(version) ~= version then
		return false, "InvalidVersion"
	end
	if version > goal then
		return false, "FutureVersion"
	end
	while version < goal do
		local migrate = list[version]
		if migrate == nil then
			return false, "MissingMigration"
		end
		migrate(data, cfg)
		version += 1
		data.Version = version
	end
	return true, nil
end

local function sanitizeWeapon(w: any, cfg: SchemaConfig): WeaponData?
	if type(w) ~= "table" or type(w.id) ~= "string" or type(w.parts) ~= "table" then
		return nil
	end
	local parts: { [string]: string } = {}
	for slot, partId in w.parts do
		if type(slot) ~= "string" or type(partId) ~= "string" then
			return nil
		end
		local def = cfg.parts[partId]
		if def == nil or def.slot ~= slot then
			return nil
		end
		parts[slot] = partId
	end
	local name: string? = nil
	if type(w.name) == "string" then
		name = string.sub(w.name, 1, cfg.maxWeaponNameLength)
	end
	local price: number? = nil
	if isFiniteNumber(w.price) and w.price >= 1 then
		price = math.floor(w.price)
	end
	return { id = w.id, parts = parts, name = name, price = price, hidden = if w.hidden == true then true else nil }
end

-- Fills missing fields and clamps everything to legal values (corrupted or tampered saves).
-- Unknown part ids are dropped (a part removed from the catalogue disappears from inventories).
function ProfileSchema.Sanitize(data: any, cfg: SchemaConfig): ProfileData
	data.Money = wholeInRange(data.Money, 0, cfg.maxMoney, cfg.startingMoney)
	data.Level = wholeInRange(data.Level, 1, cfg.maxLevel, 1)
	data.Xp = wholeInRange(data.Xp, 0, math.huge, 0)

	local parts: { [string]: number } = {}
	if type(data.Parts) == "table" then
		for id, count in data.Parts do
			if type(id) == "string" and cfg.parts[id] ~= nil then
				local n = wholeInRange(count, 0, cfg.maxPartStack, 0)
				if n > 0 then
					parts[id] = n
				end
			end
		end
	elseif data.Parts == nil then
		parts = table.clone(cfg.starterParts)
	end
	data.Parts = parts

	local weapons: { WeaponData } = {}
	if type(data.Weapons) == "table" then
		for _, w in ipairs(data.Weapons) do
			local clean = sanitizeWeapon(w, cfg)
			if clean and #weapons < cfg.maxWeapons then
				table.insert(weapons, clean)
			end
		end
	end
	data.Weapons = weapons

	local objects: { string } = {}
	if type(data.Hideout) == "table" and type(data.Hideout.Objects) == "table" then
		for _, s in ipairs(data.Hideout.Objects) do
			if type(s) == "string" and #objects < cfg.maxHideoutObjects then
				table.insert(objects, s)
			end
		end
	end
	data.Hideout = { Objects = objects }

	local stats = if type(data.Stats) == "table" then data.Stats else {}
	data.Stats = {
		Crafted = wholeInRange(stats.Crafted, 0, math.huge, 0),
		Sold = wholeInRange(stats.Sold, 0, math.huge, 0),
		Earned = wholeInRange(stats.Earned, 0, math.huge, 0),
	}

	local daily = if type(data.Daily) == "table" then data.Daily else {}
	data.Daily = {
		LastDay = wholeInRange(daily.LastDay, 0, math.huge, 0),
		Streak = wholeInRange(daily.Streak, 0, math.huge, 0),
	}

	local contracts = if type(data.Contracts) == "table" then data.Contracts else {}
	local list: { ContractEntry } = {}
	if type(contracts.List) == "table" then
		for _, e in ipairs(contracts.List) do
			local target: number? = if type(e) == "table" and type(e.id) == "string" then cfg.contractIds[e.id] else nil
			if target and #list < cfg.contractsPerDay then
				table.insert(list, {
					id = e.id,
					progress = wholeInRange(e.progress, 0, target, 0),
					done = e.done == true,
				})
			end
		end
	end
	data.Contracts = { Day = wholeInRange(contracts.Day, 0, math.huge, 0), List = list }

	local heat = if type(data.Heat) == "table" then data.Heat else {}
	data.Heat = {
		Value = if isFiniteNumber(heat.Value) then math.clamp(heat.Value, 0, cfg.maxHeat) else 0,
		LastRaidAt = wholeInRange(heat.LastRaidAt, 0, math.huge, 0),
		PendingRaid = heat.PendingRaid == true,
	}

	local hiddenParts: { [string]: number } = {}
	if type(data.HiddenParts) == "table" then
		for id, count in data.HiddenParts do
			if type(id) == "string" and parts[id] then
				local n = wholeInRange(count, 0, parts[id], 0)
				if n > 0 then
					hiddenParts[id] = n
				end
			end
		end
	end
	data.HiddenParts = hiddenParts

	return data :: ProfileData
end

-- Migrate + Sanitize. Returns (ok, errorCode).
function ProfileSchema.Prepare(data: any, cfg: SchemaConfig): (boolean, string?)
	local ok, err = ProfileSchema.Migrate(data, cfg)
	if not ok then
		return false, err
	end
	ProfileSchema.Sanitize(data, cfg)
	return true, nil
end

return ProfileSchema

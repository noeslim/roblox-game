--!strict
-- All balancing values live here. Never hard-code these numbers elsewhere.

local Economy = {}

Economy.StartingMoney = 500
Economy.MaxMoney = 1_000_000_000_000

-- Profile limits (anti-exploit caps applied when a saved profile is loaded) -----
Economy.Profile = {
	-- parts given to a brand-new player so they can craft their first weapon
	StarterParts = {
		street_body = 1,
		street_barrel = 1,
		street_stock = 1,
		street_sight = 1,
		street_mag = 1,
	},
	MaxPartStack = 999,
	MaxWeapons = 200,
	MaxLevel = 100,
	MaxWeaponNameLength = 24,
	-- furniture a brand-new player starts with ("buildableId,x,z,rotation", plot-local studs)
	StarterHideout = {
		"counter_folding,0,6,0",
		"workbench_basic,-14,-18.5,0",
		"storage_crate,17.5,-19.5,0",
		"storage_crate,20.5,-19.5,0",
	},
}

-- Legal supplier (parts shop at the workbench) -------------------------------
Economy.Supplier = {
	Rarities = { "Common", "Uncommon" }, -- rarer parts come from the black market (phase 2)
	PriceMultiplier = 1, -- price = part value x rarity multiplier x this
	MaxBuyPerRequest = 10,
}

-- Weapon prices set by the dealer ---------------------------------------------
Economy.Pricing = {
	MinPrice = 1,
	MaxPriceMultiplier = 5, -- max price = weapon value x this
	PriceStep = 0.05, -- +/- buttons change the price by 5% of the suggested price
}

-- Dealer level ------------------------------------------------------------------
Economy.Progression = {
	XpPerSale = 10,
	XpPerCraft = 5,
	XpBase = 100, -- xp needed from level 1 to 2
	XpGrowth = 1.25, -- each level needs 25% more
}

-- Rarity ------------------------------------------------------------------
Economy.RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }

Economy.RarityMultiplier = {
	Common = 1,
	Uncommon = 1.6,
	Rare = 2.8,
	Epic = 5,
	Legendary = 10,
}

Economy.RarityColor = { -- hex, used by the client for glows / text
	Common = "#B8B8B8",
	Uncommon = "#4CD964",
	Rare = "#3FA9F5",
	Epic = "#B45CFF",
	Legendary = "#FFB020",
}

-- Crafting ----------------------------------------------------------------
Economy.Crafting = {
	Slots = { "Body", "Barrel", "Stock", "Sight", "Magazine" },
	FullSetBonus = 0.25, -- +25% value when all 5 parts share a set
	SuggestedPriceMultiplier = 1.4,
	WorkbenchRange = 14, -- studs between the player and their workbench to craft
}

-- Sales / combo -------------------------------------------------------------
Economy.Combo = {
	Window = 8, -- seconds between two sales to keep the combo
	StepPerSale = 0.1,
	MaxMultiplier = 2,
}

Economy.BrandCommission = {
	Rate = 0.02, -- 2% of weapon value per K.O. made with your weapon
	MaxPerKnockout = 25,
}

-- Customers ---------------------------------------------------------------
-- weight: spawn weight, budget: multiplier range on the suggested price,
-- patience: seconds, tip: fraction of the price given as tip when served fast
Economy.Customers = {
	BudgetRange = { 0.8, 1.3 },
	FastServiceSeconds = 10,
	Personalities = {
		Rushed = { weight = 25, budgetMin = 0.9, budgetMax = 1.3, patience = 25, tip = 0.15, negotiates = false, nightOnly = false },
		Cheap = { weight = 25, budgetMin = 0.7, budgetMax = 1.0, patience = 60, tip = 0, negotiates = true, nightOnly = false },
		Collector = { weight = 10, budgetMin = 1.1, budgetMax = 1.6, patience = 90, tip = 0.05, negotiates = false, nightOnly = false, minRarity = "Rare" },
		Regular = { weight = 30, budgetMin = 0.85, budgetMax = 1.2, patience = 45, tip = 0.05, negotiates = false, nightOnly = false },
		Shady = { weight = 20, budgetMin = 1.3, budgetMax = 2.0, patience = 40, tip = 0.1, negotiates = true, nightOnly = true, wantsContraband = true },
	},
	-- how far above a customer's budget a Cheap/Shady customer will still counter-offer
	NegotiationTolerance = 0.25,
	SpawnIntervalMin = 10, -- seconds between two customers for one stash
	SpawnIntervalMax = 22,
	MaxQueue = 4,
	WalkSpeed = 12,
	MaxServeDistance = 16, -- dealer must be this close to the customer to sell
	QueueSpacing = 3.5,
	-- how many studs in front of the counter the first customer stands
	CounterGap = 2.5,
	-- the customer leaves if they could not reach the queue in this many seconds
	MaxWalkSeconds = 40,
	RefusePatiencePenalty = 4, -- seconds of patience lost per refused offer
	BigSaleTotal = 500, -- a sale worth this much triggers the "big order" effects
}

-- Heat & raids ------------------------------------------------------------
Economy.Heat = {
	Max = 100,
	Thresholds = { Patrol = 30, Investigation = 60, Raid = 85 },
	Gains = {
		ContrabandSale = 6,
		NightSale = 2,
		VisibleContraband = 0.1, -- per visible contraband item, per second
		CustomerComplaint = 3,
		ShootingRangeNoise = 1,
	},
	DecayPerSecond = 0.05,
	NightDecayMultiplier = 0.5,
	CleanDecayMultiplier = 2, -- no visible contraband
	RaidCooldown = 600, -- seconds between two raids on the same stash
	ProtectedBelowLevel = 5,
	RaidWarningSeconds = 20,
	HeatAfterRaid = 20,
	FineRate = 0.25, -- fine = 25% of seized value
	-- chance a hidden compartment is found, by compartment level
	HiddenFindChance = { 0.5, 0.3, 0.15, 0.07, 0.02 },
}

-- Day / night ---------------------------------------------------------------
Economy.DayNight = {
	DayLength = 600,
	NightLength = 360,
	-- Lighting.ClockTime ranges: jumping over dusk/dawn avoids long red sunsets in the fog
	DayClockStart = 7,
	DayClockEnd = 17,
	NightClockStart = 19.5,
	NightClockEnd = 4.5,
	NightContrabandPriceMultiplier = 1.5,
}

-- Building ----------------------------------------------------------------
Economy.Building = {
	GridSize = 1,
	FineGridSize = 0.5,
	RotationStep = 45,
	MaxObjects = 400,
	MaxObjectsExtended = 800,
	SellRefundRate = 0.5,
	PlotSizeX = 48,
	PlotSizeZ = 48,
	PlotMaxHeight = 13, -- the basement ceiling is 14 studs high
}

return Economy

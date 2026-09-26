--!strict
-- All balancing values live here. Never hard-code these numbers elsewhere.

local Economy = {}

Economy.StartingMoney = 500
Economy.MaxMoney = 1_000_000_000_000

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
}

return Economy

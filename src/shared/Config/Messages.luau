--!strict
-- Player-facing text (English). Error codes returned by the server are translated here.

local Messages = {}

Messages.Errors = {
	UnknownVehicle = "Unknown car.",
	NotOwned = "You don't own that car.",
	NoCarsHere = "No cars in the War Zone.",
	NoRoom = "No room to park here.",
	AlreadyOwned = "You already own it.",
	LevelTooLow = "Your level is too low.",
	NotEnoughMoney = "Not enough cash.",
	MissionRunning = "Finish or drop your current job first.",
	MissionCooldown = "That job is not available yet.",
	UnknownMission = "Unknown job.",
	NoMission = "No job running.",
	RateLimited = "Slow down!",
	ServerError = "Something went wrong. Try again.",
	NetworkError = "Connection problem. Try again.",
	NotLoaded = "Your data is still loading...",
	NoPlot = "You don't have a plot yet.",
	InsufficientFunds = "Not enough cash.",
	InvalidAmount = "Invalid amount.",
	UnknownBuildable = "Unknown item.",
	UnknownObject = "That object is gone.",
	InvalidNumber = "Invalid position.",
	BadRotation = "Invalid rotation.",
	OffGrid = "Not aligned with the grid.",
	OutsidePlot = "Stay inside your plot.",
	OutsideHeight = "Too high.",
	Collision = "Something is in the way.",
	TooManyObjects = "Your stash is full.",
	NotNearWorkbench = "Get closer to your workbench.",
	NoWorkbench = "Build a workbench first.",
	MissingParts = "You don't have these parts.",
	MissingSlot = "Pick a part for every slot.",
	UnknownPart = "Unknown part.",
	WrongSlot = "That part doesn't fit there.",
	UnknownSlot = "Invalid slot.",
	InvalidInput = "Invalid request.",
	TooManyWeapons = "Your weapon storage is full. Sell some first.",
	NotSold = "The supplier doesn't sell that part.",
	StackFull = "You can't carry more of that part.",
	UnknownWeapon = "That weapon is gone.",
	InvalidPrice = "Invalid price.",
	PriceTooLow = "Price too low.",
	PriceTooHigh = "Price too high.",
	UnknownCustomer = "That customer left.",
	NotYourCustomer = "That's not your customer.",
	NotReady = "That customer isn't ready.",
	AlreadyClaimed = "Already claimed today. Come back tomorrow.",
	MarketClosed = "The black market only opens at night.",
	TooFarFromPoi = "Get closer.",
	SoldOut = "Not in stock tonight.",
	TooSoon = "Wait a bit.",
	TooFar = "Get closer to the customer.",
	NoCounterOffer = "There's no offer to accept.",
}

-- Error codes can carry a detail after ":" (e.g. "Collision:o3", "MissingSlot:Body").
function Messages.ForError(code: any): string
	if type(code) ~= "string" then
		return Messages.Errors.ServerError
	end
	local key = string.match(code, "^([^:]+)") or code
	return Messages.Errors[key] or code
end

-- War Zone (WarZoneService / WarZoneController)
Messages.War = {
	Joined = "You joined %s. Stand on the control points to take them.",
	Left = "You left the War Zone.",
	Captured = "%s took point %s",
	Neutralized = "Point %s is neutral",
	Won = "%s wins the round!",
	Draw = "Draw! Nobody wins this round.",
	RoundStart = "New round. Take the points!",
	NoRewards = "No rewards this round: both teams need players.",
	Intermission = "NEXT ROUND IN %d",
	Title = "WAR ZONE",
}

-- Points of interest
Messages.Poi = {
	SupplierPrompt = "Browse parts",
	BlackMarketPrompt = "Deal",
	GasPrompt = "Eat ($%d)",
	Refilled = "Back on your feet.",
	DeliveryNote = "Phone order: +%d%% delivery. No fee at the SUPPLIER (Docks).",
	OnSiteNote = "At the supplier: no delivery fee.",
	BlackMarketTitle = "BLACK MARKET",
	BlackMarketNote = "Tonight only, limited stock: every buy pushes the price up.",
}

-- Daily streak and contracts (GoalsService / GoalsController)
Messages.Goals = {
	ContractDone = "Contract done: %s  +$%d",
	AllDone = "All contracts done! Bonus +$%d",
	DailyClaimed = "Day %d streak  +$%d",
	Title = "CONTRACTS",
	AllDoneTitle = "ALL DONE - new ones tomorrow",
	DailyTitle = "DAILY STREAK",
	DailySubtitle = "Come back every day. Miss one and the streak starts over.",
	Claim = "CLAIM $%d",
	Day = "DAY %d",
}

Messages.PersonalityNames = {
	Rushed = "In a hurry",
	Cheap = "Bargain hunter",
	Collector = "Collector",
	Regular = "Regular",
	Shady = "Shady type",
}

Messages.CustomerLines = {
	Greet = { "Yo. What you got?", "Show me something good.", "I need a blaster. Fast.", "Heard you're the plug." },
	Refuse = { "Too expensive, bro.", "Nah, that's a rip-off.", "You're dreaming." },
	NotInterested = { "Not what I'm looking for.", "Nah, show me something else." },
	Counter = { "How about $%d?", "I'll give you $%d. Final.", "$%d, take it or leave it." },
	Thanks = { "Pleasure doing business.", "Nice piece. Later.", "Respect.", "I'll tell my crew." },
	Angry = { "Too slow. I'm out.", "Waste of my time.", "Forget it." },
	Declined = { "Your loss.", "Fine. Keep it." },
	Cops = { "Cops! I'm out.", "Nah, not with sirens around.", "Too hot here. Later." },
}

Messages.Vehicles = {
	Button = "CAR",
	Title = "GARAGE",
	Note = "Your car comes next to you, or in front of your trap house. Jump to get out.",
	Spawn = "DRIVE",
	Park = "PUT AWAY",
	Buy = "BUY %s",
	Level = "LV %d",
	Bought = "You bought the %s.",
	Gift = "The %s is yours. Open the garage (CAR) to drive it.",
	Drive = "Drive",
	Ride = "Ride",
	Speed = "%d KM/H",
	Stats = "Top speed %d",
}

Messages.Missions = {
	Board = "JOBS",
	BoardTitle = "STREET JOBS",
	BoardNote = "One job at a time. Pays cash and XP.",
	Take = "TAKE",
	Drop = "DROP",
	Started = "New job: %s",
	Done = "Job done: %s (+$%d)",
	Failed = "Job failed: %s (%s)",
	Reasons = {
		customerLost = "a customer walked out",
		dayStart = "the night is over",
		nightStart = "night fell",
		timeout = "out of time",
		abandoned = "dropped",
		default = "failed",
	},
	Available = "Available in %d:%02d",
	Reward = "$%d · %d XP",
}

Messages.Market = {
	NightStart = "Night falls: contraband sells x%.1f, and the street wants %s parts (+%d%%).",
	Hot = "Wanted tonight: %s parts (+%d%%)",
	Left = "%d left",
	SoldOut = "SOLD OUT",
	Night = "night x%.1f",
	HotTag = "wanted +%d%%",
}

-- The extras of a sale (SaleService info): streak, night premium, wanted set, tip.
function Messages.SaleExtras(info: any): { string }
	local extra = {}
	if type(info.combo) == "number" and info.combo > 1 and type(info.multiplier) == "number" then
		table.insert(extra, ("streak x%.1f"):format(info.multiplier))
	end
	local premium = if type(info.premium) == "table" then info.premium else {}
	if type(premium.night) == "number" then
		table.insert(extra, Messages.Market.Night:format(premium.night))
	end
	if type(premium.hot) == "number" then
		table.insert(extra, Messages.Market.HotTag:format(math.floor((premium.hot - 1) * 100 + 0.5)))
	end
	if type(info.tip) == "number" and info.tip > 0 then
		table.insert(extra, ("tip $%d"):format(info.tip))
	end
	return extra
end

Messages.Raid = {
	Patrol = "A patrol car is cruising your block. Keep it low.",
	Investigation = "An inspector is asking around about your place.",
	Warning = "RAID!",
	Hint = "Everything outlined in red will be seized. Hold E on a secret compartment to hide it",
	NoCompartmentHint = "Everything outlined in red will be seized. Build a secret compartment (Build > Secret) to hide it",
	Search = "The inspectors are searching your stash...",
	Hidden = "Hid %d item(s) in the %s.",
	NothingToHide = "No contraband left in sight.",
	NoRoom = "Your secret compartments are full.",
	TooLate = "Too late, they are already searching.",
	Fled = "You left during a raid: the inspectors searched your stash without you.",
	ReportTitle = "RAID REPORT",
	Clean = "They found nothing illegal. Only contraband (Ghost parts, black market parts) can be seized.",
	CleanHint = "No contraband in sight: your legal weapons are safe",
	Seized = "Seized",
	Saved = "Stayed hidden: %d",
	Fine = "Fine: %s",
}

return Messages

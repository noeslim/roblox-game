--!strict
-- Player-facing text (English). Error codes returned by the server are translated here.

local Messages = {}

Messages.Errors = {
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
	BlackMarketNote = "Tonight only. New stock every night.",
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

Messages.Raid = {
	Patrol = "A patrol car is cruising your block. Keep it low.",
	Investigation = "An inspector is asking around about your place.",
	Warning = "RAID!",
	Hint = "Hold E on a secret compartment to hide your contraband",
	NoCompartmentHint = "No secret compartment: everything in sight will be seized",
	Search = "The inspectors are searching your stash...",
	Hidden = "Hid %d item(s) in the %s.",
	NothingToHide = "No contraband left in sight.",
	NoRoom = "Your secret compartments are full.",
	TooLate = "Too late, they are already searching.",
	Fled = "You left during a raid: the inspectors searched your stash without you.",
	ReportTitle = "RAID REPORT",
	Clean = "They found nothing. Clean.",
	Seized = "Seized",
	Saved = "Stayed hidden: %d",
	Fine = "Fine: %s",
}

return Messages

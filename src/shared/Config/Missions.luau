--!strict
-- Mission definitions (Logic/Mission). Street jobs are offered on the JOBS board (one at a time,
-- CooldownSeconds before the same job again); recruits' chains will come with R.2.
-- Targets: "poi:<Name>" (Config/City.Poi), "home" (your trap house), "district:<Name>" (Config/City).
-- Events: sale, saleNight, craft, craftRare, buy, tip, combo, earned, warWin (fired by the services),
-- customerLost (a customer left angry), dayStart / nightStart.

local Missions = {}

Missions.Settings = {
	GotoRadius = 22, -- studs around a point target
	CooldownSeconds = 600, -- before the same street job again
	ResultSeconds = 4, -- the tracker shows "done" / "failed" this long
}

-- (shape: Logic/Mission.Def)
Missions.Jobs = {
	{
		id = "supply_run",
		title = "Supply Run",
		text = "Restock and put something together.",
		timeLimit = 600,
		steps = {
			{ kind = "goto", target = "poi:Supplier", text = "Go to the supplier" },
			{ kind = "event", event = "buy", count = 3, text = "Buy 3 parts" },
			{ kind = "goto", target = "home", text = "Back to your trap house" },
			{ kind = "event", event = "craft", count = 1, text = "Craft a weapon" },
		} :: { any },
		reward = { money = 400, xp = 60 },
	},
	{
		id = "night_shift",
		title = "Night Shift",
		text = "Serve everyone tonight. Nobody walks out.",
		failOn = { "customerLost", "dayStart" },
		steps = {
			{ kind = "event", event = "sale", count = 5, filter = { night = true }, text = "Sell 5 weapons tonight" },
		} :: { any },
		reward = { money = 900, xp = 120 },
	},
	{
		id = "lay_low",
		title = "Lay Low",
		text = "Be seen somewhere else for a while.",
		timeLimit = 480,
		steps = {
			{ kind = "goto", target = "poi:GasStation", text = "Go to the gas station" },
			{ kind = "stay", target = "poi:GasStation", seconds = 30, text = "Hang around the gas station" },
			{ kind = "goto", target = "home", text = "Back to your trap house" },
		} :: { any },
		reward = { money = 250, xp = 40 },
	},
	{
		id = "quality_piece",
		title = "Quality Piece",
		text = "A client wants something serious.",
		timeLimit = 900,
		steps = {
			{ kind = "event", event = "craft", count = 1, filter = { minRarity = "Rare" }, text = "Craft a Rare weapon or better" },
			{ kind = "event", event = "sale", count = 1, filter = { minRarity = "Rare" }, text = "Sell a Rare weapon or better" },
		} :: { any },
		reward = { money = 700, xp = 100 },
	},
} :: { any }

Missions.ById = {} :: { [string]: any }
for _, def in Missions.Jobs do
	Missions.ById[def.id] = def
end

return Missions

--!strict
-- Rate limits for client requests (token bucket: burst, then per second).

return {
	Default = { capacity = 10, refillPerSecond = 4 },
	PerRemote = {
		RequestPlace = { capacity = 8, refillPerSecond = 4 },
		RequestMove = { capacity = 8, refillPerSecond = 4 },
		RequestRemove = { capacity = 8, refillPerSecond = 4 },
		RequestCraft = { capacity = 3, refillPerSecond = 1 },
		RequestBuyPart = { capacity = 10, refillPerSecond = 5 },
		RequestSetPrice = { capacity = 20, refillPerSecond = 10 },
		RequestSell = { capacity = 5, refillPerSecond = 2 },
		LookAt = { capacity = 10, refillPerSecond = 8 },
		RequestClaimDaily = { capacity = 3, refillPerSecond = 0.5 },
		RequestBlackMarket = { capacity = 4, refillPerSecond = 1 },
		RequestStartMission = { capacity = 3, refillPerSecond = 0.5 },
		RequestAbandonMission = { capacity = 3, refillPerSecond = 0.5 },
		RequestMissions = { capacity = 3, refillPerSecond = 1 },
	} :: { [string]: { capacity: number, refillPerSecond: number } },
}

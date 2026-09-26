--!strict
-- Daily login streak. Pure: the day number is injected (DailyReward.Day(now) with UTC seconds).
-- Claim once per day; coming back the next day grows the streak, missing a day restarts it at 1.

local DailyReward = {}

export type State = { LastDay: number, Streak: number }
export type Config = { Rewards: { number } }

function DailyReward.Day(now: number): number
	return math.floor(now / 86400)
end

-- (canClaim, streak the claim would give)
function DailyReward.Status(state: State, day: number): (boolean, number)
	if state.LastDay == day then
		return false, state.Streak
	end
	if state.LastDay == day - 1 then
		return true, state.Streak + 1
	end
	return true, 1
end

-- Cash for a given streak day (the table loops after its last day).
function DailyReward.RewardFor(streak: number, cfg: Config): number
	local n = #cfg.Rewards
	return cfg.Rewards[(math.max(1, streak) - 1) % n + 1]
end

-- Claims today's reward. Returns (ok, cash, streak); updates the state.
function DailyReward.Claim(state: State, day: number, cfg: Config): (boolean, number, number)
	local can, streak = DailyReward.Status(state, day)
	if not can then
		return false, 0, state.Streak
	end
	state.LastDay = day
	state.Streak = streak
	return true, DailyReward.RewardFor(streak, cfg), streak
end

return DailyReward

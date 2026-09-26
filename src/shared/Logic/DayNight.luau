--!strict
-- Day / night cycle computed from a shared clock (e.g. workspace:GetServerTimeNow()).

local DayNight = {}

export type Phase = "Day" | "Night"

export type PhaseInfo = {
	phase: Phase,
	progress: number, -- 0..1 within the current phase
	secondsLeft: number,
	clockTime: number, -- 0..24, for Lighting.ClockTime
}

function DayNight.Get(now: number, cfg: { DayLength: number, NightLength: number }): PhaseInfo
	local cycle = cfg.DayLength + cfg.NightLength
	local t = now % cycle

	if t < cfg.DayLength then
		local progress = t / cfg.DayLength
		return {
			phase = "Day",
			progress = progress,
			secondsLeft = cfg.DayLength - t,
			clockTime = 6 + progress * 12, -- 06:00 -> 18:00
		}
	end

	local nt = t - cfg.DayLength
	local progress = nt / cfg.NightLength
	return {
		phase = "Night",
		progress = progress,
		secondsLeft = cfg.NightLength - nt,
		clockTime = (18 + progress * 12) % 24, -- 18:00 -> 06:00
	}
end

return DayNight

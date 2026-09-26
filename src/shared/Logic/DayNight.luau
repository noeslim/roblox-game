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

export type DayNightConfig = {
	DayLength: number,
	NightLength: number,
	-- optional clock ranges (hours). Skipping the dusk/dawn hours avoids long red sunsets.
	DayClockStart: number?, -- default 6
	DayClockEnd: number?, -- default 18
	NightClockStart: number?, -- default 18
	NightClockEnd: number?, -- default 6 (next morning)
}

function DayNight.Get(now: number, cfg: DayNightConfig): PhaseInfo
	local cycle = cfg.DayLength + cfg.NightLength
	local t = now % cycle
	local dayStart = cfg.DayClockStart or 6
	local dayEnd = cfg.DayClockEnd or 18
	local nightStart = cfg.NightClockStart or 18
	local nightEnd = cfg.NightClockEnd or 6
	local nightSpan = (nightEnd - nightStart) % 24

	if t < cfg.DayLength then
		local progress = t / cfg.DayLength
		return {
			phase = "Day",
			progress = progress,
			secondsLeft = cfg.DayLength - t,
			clockTime = dayStart + progress * (dayEnd - dayStart),
		}
	end

	local nt = t - cfg.DayLength
	local progress = nt / cfg.NightLength
	return {
		phase = "Night",
		progress = progress,
		secondsLeft = cfg.NightLength - nt,
		clockTime = (nightStart + progress * nightSpan) % 24,
	}
end

return DayNight

--!strict
-- Traffic light cycle shared by every intersection: the north-south signals go green, amber, red,
-- then (after an all-red pause) the east-west ones do the same. Pure: the time is injected.

local TrafficCycle = {}

export type Settings = { GreenSeconds: number, AmberSeconds: number, AllRedSeconds: number }
export type Signal = "signal_green" | "signal_amber" | "signal_red"

function TrafficCycle.Period(s: Settings): number
	return 2 * (s.GreenSeconds + s.AmberSeconds + s.AllRedSeconds)
end

-- Lit signal of the "NS" and "EW" axes at time now (seconds, any origin).
function TrafficCycle.State(now: number, s: Settings): (Signal, Signal)
	local half = s.GreenSeconds + s.AmberSeconds + s.AllRedSeconds
	local t = now % (2 * half)
	local first = t < half
	local local_t = if first then t else t - half
	local active: Signal = if local_t < s.GreenSeconds then "signal_green" elseif local_t < s.GreenSeconds + s.AmberSeconds then "signal_amber" else "signal_red"
	if first then
		return active, "signal_red"
	end
	return "signal_red", active
end

return TrafficCycle

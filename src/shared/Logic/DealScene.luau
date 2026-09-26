--!strict
-- Timeline of the first-person sale: place the weapon, the customer inspects it, pays, you take the
-- cash, shake hands, count the bills. Shared by the client scene and the server (customer gestures).

local DealScene = {}

export type Config = {
	IntroSeconds: number,
	PlaceSeconds: number,
	InspectSeconds: number,
	PaySeconds: number,
	TakeSeconds: number,
	ShakeSeconds: number,
	CountSeconds: number,
	OutroSeconds: number,
}
export type Plan = {
	place: number,
	inspect: number,
	pay: number,
	take: number,
	shake: number,
	count: number,
	outro: number,
	total: number,
}
export type Phase = "intro" | "place" | "inspect" | "pay" | "take" | "shake" | "count" | "outro" | "done"

function DealScene.Plan(cfg: Config): Plan
	local place = cfg.IntroSeconds
	local inspect = place + cfg.PlaceSeconds
	local pay = inspect + cfg.InspectSeconds
	local take = pay + cfg.PaySeconds
	local shake = take + cfg.TakeSeconds
	local count = shake + cfg.ShakeSeconds
	local outro = count + cfg.CountSeconds
	return { place = place, inspect = inspect, pay = pay, take = take, shake = shake, count = count, outro = outro, total = outro + cfg.OutroSeconds }
end

function DealScene.Phase(plan: Plan, t: number): Phase
	if t >= plan.total then
		return "done"
	elseif t >= plan.outro then
		return "outro"
	elseif t >= plan.count then
		return "count"
	elseif t >= plan.shake then
		return "shake"
	elseif t >= plan.take then
		return "take"
	elseif t >= plan.pay then
		return "pay"
	elseif t >= plan.inspect then
		return "inspect"
	elseif t >= plan.place then
		return "place"
	end
	return "intro"
end

-- Progress 0..1 of time t inside [from, to).
function DealScene.Progress(t: number, from: number, to: number): number
	if to <= from then
		return 1
	end
	return math.clamp((t - from) / (to - from), 0, 1)
end

function DealScene.Smooth(u: number): number
	u = math.clamp(u, 0, 1)
	return u * u * (3 - 2 * u)
end

-- How many bills have been counted at time t.
function DealScene.BillsCounted(plan: Plan, t: number, bills: number): number
	local u = DealScene.Progress(t, plan.count, plan.outro - 0.2)
	return math.clamp(math.floor(u * bills), 0, bills)
end

return DealScene

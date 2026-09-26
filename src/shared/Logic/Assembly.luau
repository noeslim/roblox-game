--!strict
-- Timeline of the first-person crafting scene: which part is waiting, carried, sliding in or fitted
-- at time t, then the screw, inspection and outro phases. Pure: the client animates from it.

local Assembly = {}

export type Config = {
	IntroSeconds: number,
	PickSeconds: number,
	CarrySeconds: number,
	SeatSeconds: number,
	SettleSeconds: number,
	ScrewSeconds: number,
	InspectSeconds: number,
	OutroSeconds: number,
}
export type Step = { slot: string, start: number, carry: number, seat: number, done: number }
export type Plan = { steps: { Step }, screwStart: number, inspectStart: number, outroStart: number, total: number }
export type Phase = "intro" | "assemble" | "screw" | "inspect" | "outro" | "done"
export type PartPhase = "tray" | "pick" | "carry" | "seat" | "fitted"

-- The body first (the other parts fit on it), then the others in `order`, only the ones present.
function Assembly.Plan(present: { [string]: boolean }, order: { string }, cfg: Config): Plan
	local steps: { Step } = {}
	local t = cfg.IntroSeconds
	local sequence = {}
	if present.Body then
		table.insert(sequence, "Body")
	end
	for _, slot in order do
		if slot ~= "Body" and present[slot] then
			table.insert(sequence, slot)
		end
	end
	for _, slot in sequence do
		local step = {
			slot = slot,
			start = t,
			carry = t + cfg.PickSeconds,
			seat = t + cfg.PickSeconds + cfg.CarrySeconds,
			done = t + cfg.PickSeconds + cfg.CarrySeconds + cfg.SeatSeconds,
		}
		table.insert(steps, step)
		t = step.done + cfg.SettleSeconds
	end
	local screwStart = t
	local inspectStart = screwStart + cfg.ScrewSeconds
	local outroStart = inspectStart + cfg.InspectSeconds
	return { steps = steps, screwStart = screwStart, inspectStart = inspectStart, outroStart = outroStart, total = outroStart + cfg.OutroSeconds }
end

function Assembly.Phase(plan: Plan, t: number): Phase
	if t >= plan.total then
		return "done"
	elseif t >= plan.outroStart then
		return "outro"
	elseif t >= plan.inspectStart then
		return "inspect"
	elseif t >= plan.screwStart then
		return "screw"
	elseif #plan.steps > 0 and t >= plan.steps[1].start then
		return "assemble"
	end
	return "intro"
end

-- Where a part is at time t, with the progress (0..1) inside that phase.
function Assembly.PartState(step: Step, t: number): (PartPhase, number)
	if t < step.start then
		return "tray", 0
	elseif t < step.carry then
		return "pick", (t - step.start) / (step.carry - step.start)
	elseif t < step.seat then
		return "carry", (t - step.carry) / (step.seat - step.carry)
	elseif t < step.done then
		return "seat", (t - step.seat) / (step.done - step.seat)
	end
	return "fitted", 1
end

-- The step being worked on at time t (nil between parts or outside the assembly).
function Assembly.Current(plan: Plan, t: number): Step?
	for _, step in plan.steps do
		if t >= step.start and t < step.done then
			return step
		end
	end
	return nil
end

function Assembly.Smooth(u: number): number
	u = math.clamp(u, 0, 1)
	return u * u * (3 - 2 * u)
end

return Assembly

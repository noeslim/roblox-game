--!strict
-- Timeline of the first-person crafting scene. On the bench: the parts are fitted one by one (the
-- body first) and screwed; then the weapon is lifted, the magazine loaded, the action racked, the
-- weapon tested (aim + dry fire) and inspected. Pure: the client animates from it.

local Assembly = {}

export type Config = {
	IntroSeconds: number,
	PickSeconds: number,
	CarrySeconds: number,
	SeatSeconds: number,
	SettleSeconds: number,
	ScrewSeconds: number,
	LiftSeconds: number,
	LoadSeconds: number,
	RackSeconds: number,
	TestSeconds: number,
	InspectSeconds: number,
	OutroSeconds: number,
	LoadSlot: string, -- fitted in the hands after the lift (the magazine)
}
export type Step = { slot: string, start: number, carry: number, seat: number, done: number }
export type Plan = {
	steps: { Step }, -- parts fitted on the bench
	load: Step?, -- the magazine, fitted in the hands
	screwStart: number,
	liftStart: number,
	loadStart: number,
	rackStart: number,
	testStart: number,
	inspectStart: number,
	outroStart: number,
	total: number,
}
export type Phase = "intro" | "assemble" | "screw" | "lift" | "load" | "rack" | "test" | "inspect" | "outro" | "done"
export type PartPhase = "tray" | "pick" | "carry" | "seat" | "fitted"

local function step(slot: string, t: number, cfg: Config): Step
	return {
		slot = slot,
		start = t,
		carry = t + cfg.PickSeconds,
		seat = t + cfg.PickSeconds + cfg.CarrySeconds,
		done = t + cfg.PickSeconds + cfg.CarrySeconds + cfg.SeatSeconds,
	}
end

function Assembly.Plan(present: { [string]: boolean }, order: { string }, cfg: Config): Plan
	local steps: { Step } = {}
	local t = cfg.IntroSeconds
	local sequence = {}
	if present.Body then
		table.insert(sequence, "Body")
	end
	for _, slot in order do
		if slot ~= "Body" and slot ~= cfg.LoadSlot and present[slot] then
			table.insert(sequence, slot)
		end
	end
	for _, slot in sequence do
		local s = step(slot, t, cfg)
		table.insert(steps, s)
		t = s.done + cfg.SettleSeconds
	end
	local screwStart = t
	local liftStart = screwStart + cfg.ScrewSeconds
	local loadStart = liftStart + cfg.LiftSeconds
	local load: Step? = nil
	local rackStart = loadStart
	if present[cfg.LoadSlot] then
		-- the load fits in LoadSeconds: pick, carry and seat scaled into it
		local total = cfg.PickSeconds + cfg.CarrySeconds + cfg.SeatSeconds
		local k = cfg.LoadSeconds / total
		load = {
			slot = cfg.LoadSlot,
			start = loadStart,
			carry = loadStart + cfg.PickSeconds * k,
			seat = loadStart + (cfg.PickSeconds + cfg.CarrySeconds) * k,
			done = loadStart + cfg.LoadSeconds,
		}
		rackStart = loadStart + cfg.LoadSeconds
	end
	local testStart = rackStart + cfg.RackSeconds
	local inspectStart = testStart + cfg.TestSeconds
	local outroStart = inspectStart + cfg.InspectSeconds
	return {
		steps = steps,
		load = load,
		screwStart = screwStart,
		liftStart = liftStart,
		loadStart = loadStart,
		rackStart = rackStart,
		testStart = testStart,
		inspectStart = inspectStart,
		outroStart = outroStart,
		total = outroStart + cfg.OutroSeconds,
	}
end

function Assembly.Phase(plan: Plan, t: number): Phase
	if t >= plan.total then
		return "done"
	elseif t >= plan.outroStart then
		return "outro"
	elseif t >= plan.inspectStart then
		return "inspect"
	elseif t >= plan.testStart then
		return "test"
	elseif t >= plan.rackStart then
		return "rack"
	elseif t >= plan.loadStart then
		return "load"
	elseif t >= plan.liftStart then
		return "lift"
	elseif t >= plan.screwStart then
		return "screw"
	elseif #plan.steps > 0 and t >= plan.steps[1].start then
		return "assemble"
	end
	return "intro"
end

-- Where a part is at time t, with the progress (0..1) inside that phase.
function Assembly.PartState(s: Step, t: number): (PartPhase, number)
	if t < s.start then
		return "tray", 0
	elseif t < s.carry then
		return "pick", (t - s.start) / (s.carry - s.start)
	elseif t < s.seat then
		return "carry", (t - s.carry) / (s.seat - s.carry)
	elseif t < s.done then
		return "seat", (t - s.seat) / (s.done - s.seat)
	end
	return "fitted", 1
end

-- The bench step being worked on at time t (nil between parts or outside the bench assembly).
function Assembly.Current(plan: Plan, t: number): Step?
	for _, s in plan.steps do
		if t >= s.start and t < s.done then
			return s
		end
	end
	return nil
end

-- Progress 0..1 inside [from, to).
function Assembly.Progress(t: number, from: number, to: number): number
	if to <= from then
		return 1
	end
	return math.clamp((t - from) / (to - from), 0, 1)
end

function Assembly.Smooth(u: number): number
	u = math.clamp(u, 0, 1)
	return u * u * (3 - 2 * u)
end

return Assembly

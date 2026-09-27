--!strict
-- Generic missions (roadmap R.1, GAME_DESIGN §21): a chain of steps, an optional time limit and
-- events that fail it. Used by the street jobs now, by the recruits' chains, the smuggling runs and
-- the server events later. Pure: time, places reached and events are handed in by MissionService.
--
-- Step kinds:
--   "event": count `count` events named `event` (optionally filtered: night, minRarity, contraband)
--   "goto":  reach `target` (resolved to a place by the server: "poi:Supplier", "home", "district:Docks")
--   "stay":  stay `seconds` at `target` (time only counts while inside)

local Mission = {}

export type Filter = { night: boolean?, minRarity: string?, contraband: boolean? }
export type Step = {
	kind: string,
	text: string,
	event: string?,
	count: number?,
	filter: Filter?,
	target: string?,
	seconds: number?,
}
export type Def = {
	id: string,
	title: string,
	text: string?,
	steps: { Step },
	timeLimit: number?, -- seconds for the whole mission
	failOn: { string }?, -- events that fail it (e.g. "customerLost", "dayStart")
	reward: { money: number, xp: number },
}
export type Status = "active" | "done" | "failed"
export type State = { id: string, step: number, progress: number, startedAt: number, status: Status, reason: string? }
export type Info = { night: boolean?, rarity: string?, contraband: boolean? }

local KINDS = { event = true, goto = true, stay = true }

function Mission.Start(def: Def, now: number): State
	return { id = def.id, step = 1, progress = 0, startedAt = now, status = "active", reason = nil }
end

function Mission.Current(state: State, def: Def): Step?
	return if state.status == "active" then def.steps[state.step] else nil
end

local function advance(state: State, def: Def)
	state.step += 1
	state.progress = 0
	if state.step > #def.steps then
		state.status = "done"
	end
end

local function fail(state: State, reason: string)
	state.status = "failed"
	state.reason = reason
end

local function passes(filter: Filter?, info: Info?, rarityOrder: { string }): boolean
	if filter == nil then
		return true
	end
	local i: Info = info or {}
	if filter.night ~= nil and (i.night == true) ~= filter.night then
		return false
	end
	if filter.contraband ~= nil and (i.contraband == true) ~= filter.contraband then
		return false
	end
	if filter.minRarity then
		local need = table.find(rarityOrder, filter.minRarity) or math.huge
		local have = if i.rarity then table.find(rarityOrder, i.rarity) else nil
		if have == nil or have < need then
			return false
		end
	end
	return true
end

-- An event happened to the player. Returns true when the state changed.
function Mission.Record(state: State, def: Def, event: string, amount: number, info: Info?, rarityOrder: { string }): boolean
	if state.status ~= "active" then
		return false
	end
	if def.failOn and table.find(def.failOn, event) then
		fail(state, event)
		return true
	end
	local step = def.steps[state.step]
	if step.kind ~= "event" or step.event ~= event or not passes(step.filter, info, rarityOrder) then
		return false
	end
	state.progress += amount
	if state.progress >= (step.count or 1) then
		advance(state, def)
	end
	return true
end

-- Time passes. inside: whether the player is at the current step's target. Returns true on change.
function Mission.Update(state: State, def: Def, now: number, dt: number, inside: boolean): boolean
	if state.status ~= "active" then
		return false
	end
	if def.timeLimit and now - state.startedAt >= def.timeLimit then
		fail(state, "timeout")
		return true
	end
	local step = def.steps[state.step]
	if step.kind == "goto" and inside then
		advance(state, def)
		return true
	elseif step.kind == "stay" and inside then
		state.progress += dt
		if state.progress >= (step.seconds or 0) then
			advance(state, def)
		end
		return true
	end
	return false
end

-- What the tracker shows.
export type View = { id: string, title: string, text: string, progress: number, goal: number, step: number, steps: number, timeLeft: number?, status: Status, reason: string?, target: string? }

function Mission.Describe(state: State, def: Def, now: number): View
	local step = def.steps[math.min(state.step, #def.steps)]
	local goal = if step.kind == "event" then (step.count or 1) elseif step.kind == "stay" then (step.seconds or 0) else 1
	return {
		id = def.id,
		title = def.title,
		text = step.text,
		progress = math.floor(state.progress),
		goal = goal,
		step = math.min(state.step, #def.steps),
		steps = #def.steps,
		timeLeft = if def.timeLimit then math.max(0, def.timeLimit - (now - state.startedAt)) else nil,
		status = state.status,
		reason = state.reason,
		target = if step.kind ~= "event" and state.status == "active" then step.target else nil,
	}
end

-- Config check: returns an error message or nil.
function Mission.Validate(def: Def, rarityOrder: { string }): string?
	if type(def.id) ~= "string" or type(def.title) ~= "string" or #def.steps == 0 then
		return "needs an id, a title and steps"
	end
	for i, step in def.steps do
		if not KINDS[step.kind] then
			return ("step %d: unknown kind %s"):format(i, tostring(step.kind))
		end
		if type(step.text) ~= "string" then
			return ("step %d: no text"):format(i)
		end
		if step.kind == "event" and (type(step.event) ~= "string" or (step.count or 1) < 1) then
			return ("step %d: event steps need an event and a count >= 1"):format(i)
		end
		if step.kind ~= "event" and type(step.target) ~= "string" then
			return ("step %d: %s steps need a target"):format(i, step.kind)
		end
		if step.kind == "stay" and (step.seconds or 0) <= 0 then
			return ("step %d: stay steps need seconds"):format(i)
		end
		if step.filter and step.filter.minRarity and not table.find(rarityOrder, step.filter.minRarity) then
			return ("step %d: unknown rarity %s"):format(i, step.filter.minRarity)
		end
	end
	if def.reward == nil or def.reward.money < 0 or def.reward.xp < 0 then
		return "needs a reward"
	end
	return nil
end

return Mission

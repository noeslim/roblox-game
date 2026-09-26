--!strict
-- Daily contracts: a few goals picked every day for each player, progressed by game events and paid
-- as soon as they are done. Pure: the day and the player seed are injected.

local Contracts = {}

export type Def = { id: string, event: string, target: number, reward: number, xp: number, text: string, mode: string? }
export type Config = { PerDay: number, AllDoneBonus: number, Pool: { Def } }
export type Entry = { id: string, progress: number, done: boolean }
export type State = { Day: number, List: { Entry } }

function Contracts.Find(cfg: Config, id: string): Def?
	for _, def in cfg.Pool do
		if def.id == id then
			return def
		end
	end
	return nil
end

-- The contracts of `day` for a player (seed = UserId): distinct, same answer every time.
function Contracts.Roll(day: number, seed: number, cfg: Config): { Entry }
	local state = (day * 7919 + seed * 104729 + 12345) % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	local indices = {}
	for i = 1, #cfg.Pool do
		indices[i] = i
	end
	local list: { Entry } = {}
	for _ = 1, math.min(cfg.PerDay, #cfg.Pool) do
		state = (state * 48271) % 2147483647
		local pick = state % #indices + 1
		local def = cfg.Pool[indices[pick]]
		table.remove(indices, pick)
		table.insert(list, { id = def.id, progress = 0, done = false })
	end
	return list
end

-- New contracts when the day changed. Returns true if they were rolled.
function Contracts.Ensure(state: State, day: number, seed: number, cfg: Config): boolean
	if state.Day == day and #state.List > 0 then
		return false
	end
	state.Day = day
	state.List = Contracts.Roll(day, seed, cfg)
	return true
end

function Contracts.AllDone(state: State): boolean
	if #state.List == 0 then
		return false
	end
	for _, e in state.List do
		if not e.done then
			return false
		end
	end
	return true
end

-- Counts an event. Returns the contracts it just completed and whether it just completed all of them.
function Contracts.Record(state: State, event: string, amount: number, cfg: Config): ({ Def }, boolean)
	local completed: { Def } = {}
	if amount <= 0 then
		return completed, false
	end
	local wasAllDone = Contracts.AllDone(state)
	for _, e in state.List do
		local def = Contracts.Find(cfg, e.id)
		if def and not e.done and def.event == event then
			if def.mode == "max" then
				e.progress = math.max(e.progress, amount)
			else
				e.progress += amount
			end
			if e.progress >= def.target then
				e.progress = def.target
				e.done = true
				table.insert(completed, def)
			end
		end
	end
	return completed, (not wasAllDone) and Contracts.AllDone(state)
end

return Contracts

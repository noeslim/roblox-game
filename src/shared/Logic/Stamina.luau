--!strict
-- Sprint stamina. Pure: the time step and the input are injected.
--   local s = Stamina.new(cfg)
--   local mode = Stamina.Step(s, dt, wantsSprint, moving, cfg) -- "walk" | "sprint" | "exhausted"

local Stamina = {}

export type Config = {
	Max: number,
	SprintDrain: number,
	JumpCost: number,
	Regen: number,
	RegenDelay: number,
	ExhaustedBelow: number,
	RecoverAbove: number,
}

export type State = {
	value: number,
	exhausted: boolean,
	sinceDrain: number, -- seconds since stamina was last spent
}

export type Mode = "walk" | "sprint" | "exhausted"

function Stamina.new(cfg: Config): State
	return { value = cfg.Max, exhausted = false, sinceDrain = math.huge }
end

local function spend(s: State, amount: number, cfg: Config)
	s.value = math.max(0, s.value - amount)
	s.sinceDrain = 0
	if s.value < cfg.ExhaustedBelow then
		s.exhausted = true
	end
end

-- Advances by dt seconds and returns the movement mode.
function Stamina.Step(s: State, dt: number, wantsSprint: boolean, moving: boolean, cfg: Config): Mode
	dt = math.max(0, dt)
	if s.exhausted and s.value >= cfg.RecoverAbove then
		s.exhausted = false
	end
	local sprinting = wantsSprint and moving and not s.exhausted
	if sprinting then
		spend(s, cfg.SprintDrain * dt, cfg)
		sprinting = not s.exhausted
	else
		s.sinceDrain += dt
		if s.sinceDrain >= cfg.RegenDelay then
			s.value = math.min(cfg.Max, s.value + cfg.Regen * dt)
		end
	end
	if s.exhausted then
		return "exhausted"
	end
	return if sprinting then "sprint" else "walk"
end

-- A jump costs stamina; returns false when too tired to jump.
function Stamina.TryJump(s: State, cfg: Config): boolean
	if s.exhausted or s.value < cfg.JumpCost then
		return false
	end
	spend(s, cfg.JumpCost, cfg)
	return true
end

function Stamina.Fraction(s: State, cfg: Config): number
	return s.value / cfg.Max
end

return Stamina

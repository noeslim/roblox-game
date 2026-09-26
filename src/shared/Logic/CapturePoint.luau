--!strict
-- One control point. progress goes from -1 (Blue owns it) to +1 (Red owns it); 0 is neutral.
-- A point changes owner only after being pushed all the way through neutral. Pure.

local CapturePoint = {}

export type Team = "Red" | "Blue"
export type State = { owner: Team?, progress: number }
export type Config = { CaptureSeconds: number, MaxCapturers: number, RegenSeconds: number }
export type Event = "captured" | "neutralized" | nil

function CapturePoint.new(): State
	return { owner = nil, progress = 0 }
end

-- Advances the point by dt with `red` and `blue` players standing on it.
-- Returns "captured" (owner changed to a team), "neutralized" (lost its owner) or nil.
function CapturePoint.Step(state: State, red: number, blue: number, dt: number, cfg: Config): Event
	local before = state.owner
	if red > 0 and blue > 0 then
		return nil -- contested: frozen
	end
	if red > 0 or blue > 0 then
		local count = math.min(math.max(red, blue), cfg.MaxCapturers)
		local dir = if red > 0 then 1 else -1
		state.progress = math.clamp(state.progress + dir * count * dt / cfg.CaptureSeconds, -1, 1)
	else
		-- nobody: drift back to the owner (or to neutral)
		local target = if state.owner == "Red" then 1 elseif state.owner == "Blue" then -1 else 0
		local step = dt / cfg.RegenSeconds
		if state.progress < target then
			state.progress = math.min(target, state.progress + step)
		elseif state.progress > target then
			state.progress = math.max(target, state.progress - step)
		end
	end
	-- snap float noise (10 x 0.1 must reach 1)
	if state.progress > 1 - 1e-6 then
		state.progress = 1
	elseif state.progress < -1 + 1e-6 then
		state.progress = -1
	elseif math.abs(state.progress) < 1e-6 then
		state.progress = 0
	end
	if state.progress >= 1 then
		state.owner = "Red"
	elseif state.progress <= -1 then
		state.owner = "Blue"
	elseif (state.owner == "Red" and state.progress <= 0) or (state.owner == "Blue" and state.progress >= 0) then
		state.owner = nil
	end
	if state.owner ~= before then
		return if state.owner then "captured" else "neutralized"
	end
	return nil
end

return CapturePoint

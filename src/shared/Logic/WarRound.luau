--!strict
-- Score of a War Zone round: owned points score every second; first to ScoreToWin (or the best
-- score when time runs out) wins. Pure.

local WarRound = {}

export type Team = "Red" | "Blue"
export type State = { scores: { Red: number, Blue: number }, elapsed: number, over: boolean, winner: Team? }
export type Config = { PointsPerSecond: number, ScoreToWin: number, RoundMaxSeconds: number }

function WarRound.new(): State
	return { scores = { Red = 0, Blue = 0 }, elapsed = 0, over = false, winner = nil }
end

-- owners: the owner of each control point (nil = neutral)
function WarRound.Tick(state: State, owners: { Team? }, dt: number, cfg: Config)
	if state.over then
		return
	end
	state.elapsed += dt
	for _, owner in owners do
		if owner then
			state.scores[owner] = math.min(cfg.ScoreToWin, state.scores[owner] + cfg.PointsPerSecond * dt)
		end
	end
	local red, blue = state.scores.Red, state.scores.Blue
	if red >= cfg.ScoreToWin or blue >= cfg.ScoreToWin or state.elapsed >= cfg.RoundMaxSeconds then
		state.over = true
		state.winner = if red > blue then "Red" elseif blue > red then "Blue" else nil
	end
end

function WarRound.TimeLeft(state: State, cfg: Config): number
	return math.max(0, cfg.RoundMaxSeconds - state.elapsed)
end

-- Team for a new player: the smaller one (Red on a tie).
function WarRound.PickTeam(red: number, blue: number): Team
	if blue < red then
		return "Blue"
	end
	return "Red"
end

return WarRound

--!strict
-- War Zone rounds (Logic/CapturePoint, Logic/WarRound, WarZoneService). Walk into the fenced zone to
-- join the smaller team; stand on a control point to capture it; owned points score every second.
-- Rewards are in-game cash.

return {
	Teams = {
		Red = { color = "#E23A3A", name = "Red" },
		Blue = { color = "#3A7AE2", name = "Blue" },
	} :: { [string]: { color: string, name: string } },
	CaptureSeconds = 10, -- one player, from neutral to owned
	MaxCapturers = 3, -- more players capture faster, up to this many
	RegenSeconds = 20, -- an abandoned half-captured point drifts back to its owner in this time
	PointsPerSecond = 1, -- score per owned point per second
	ScoreToWin = 400,
	RoundMaxSeconds = 900,
	IntermissionSeconds = 20,
	LeaveAfterSeconds = 4, -- outside the zone this long: you leave your team
	MinPlayersPerTeam = 1, -- rewards only when both teams had players (no farming an empty zone)
	WinReward = 400,
	LossReward = 100,
	XpWin = 60,
	XpLoss = 20,
	RingHeight = 0.3, -- the colored disc on each control point
}

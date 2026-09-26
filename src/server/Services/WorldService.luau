--!strict
-- Drives the day/night cycle for everyone. Publishes the phase as attributes on ReplicatedStorage
-- so the client can react (music, UI, neons) without extra Remotes.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local DayNight = require(Shared.Logic.DayNight)

local WorldService = {}

function WorldService:Start()
	local lastPhase: string? = nil
	while true do
		local info = DayNight.Get(workspace:GetServerTimeNow(), Economy.DayNight)
		Lighting.ClockTime = info.clockTime
		ReplicatedStorage:SetAttribute("PhaseSecondsLeft", math.floor(info.secondsLeft))
		if info.phase ~= lastPhase then
			lastPhase = info.phase
			ReplicatedStorage:SetAttribute("Phase", info.phase)
			print("[WorldService] phase ->", info.phase)
		end
		task.wait(1)
	end
end

return WorldService

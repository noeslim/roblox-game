--!strict
-- Drives the day/night cycle for everyone. Publishes the phase as attributes on ReplicatedStorage
-- so the client can react (music, UI, neons) without extra Remotes. Lighting presets: Config/World.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local World = require(Shared.Config.World)
local DayNight = require(Shared.Logic.DayNight)

local WorldService = {}

local function applyLighting(phase: string, instant: boolean)
	local preset = if phase == "Night" then World.Lighting.Night else World.Lighting.Day
	local goal = {
		Brightness = preset.Brightness,
		Ambient = Color3.fromHex(preset.Ambient),
		OutdoorAmbient = Color3.fromHex(preset.OutdoorAmbient),
		FogColor = Color3.fromHex(preset.FogColor),
		ExposureCompensation = preset.ExposureCompensation,
	}
	local seconds = if instant then 0 else World.Lighting.TweenSeconds
	TweenService:Create(Lighting, TweenInfo.new(seconds), goal):Play()
end

function WorldService:Start()
	local lastPhase: string? = nil
	while true do
		local info = DayNight.Get(workspace:GetServerTimeNow(), Economy.DayNight)
		Lighting.ClockTime = info.clockTime
		ReplicatedStorage:SetAttribute("PhaseSecondsLeft", math.floor(info.secondsLeft))
		if info.phase ~= lastPhase then
			applyLighting(info.phase, lastPhase == nil)
			lastPhase = info.phase
			ReplicatedStorage:SetAttribute("Phase", info.phase)
			print("[WorldService] phase ->", info.phase)
		end
		task.wait(1)
	end
end

return WorldService

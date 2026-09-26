--!strict
-- Drives the day/night cycle for everyone. Publishes the phase as attributes on ReplicatedStorage
-- so the client can react (music, UI, neons) without extra Remotes. Lighting presets: Config/World.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local World = require(Shared.Config.World)
local DayNight = require(Shared.Logic.DayNight)

local WorldService = {}

local rng = Random.new()
local clockOffset = 0 -- seconds added to the server clock (Studio shortcut, see watchDebugPhase)

-- The game clock: the server time, shifted when a tester skipped to the night / day.
function WorldService.Now(): number
	return workspace:GetServerTimeNow() + clockOffset
end

-- Studio only: from the command bar (Server view),
-- `game.ReplicatedStorage:SetAttribute("DebugPhase", "Night")` (or "Day") skips to that phase.
local function watchDebugPhase()
	if not RunService:IsStudio() then
		return
	end
	ReplicatedStorage:GetAttributeChangedSignal("DebugPhase"):Connect(function()
		local phase = ReplicatedStorage:GetAttribute("DebugPhase")
		if phase == "Night" or phase == "Day" then
			clockOffset += DayNight.OffsetTo(WorldService.Now(), Economy.DayNight, phase)
			ReplicatedStorage:SetAttribute("DebugPhase", nil)
			print("[WorldService] debug: skipped to", phase)
		end
	end)
end

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
	watchDebugPhase()
	local lastPhase: string? = nil
	while true do
		local info = DayNight.Get(WorldService.Now(), Economy.DayNight)
		Lighting.ClockTime = info.clockTime
		ReplicatedStorage:SetAttribute("PhaseSecondsLeft", math.floor(info.secondsLeft))
		if info.phase ~= lastPhase then
			applyLighting(info.phase, lastPhase == nil)
			local chance = if info.phase == "Night" then World.Weather.NightRainChance else World.Weather.DayRainChance
			ReplicatedStorage:SetAttribute("Raining", rng:NextNumber() < chance)
			lastPhase = info.phase
			ReplicatedStorage:SetAttribute("Phase", info.phase)
			print("[WorldService] phase ->", info.phase)
		end
		task.wait(1)
	end
end

return WorldService

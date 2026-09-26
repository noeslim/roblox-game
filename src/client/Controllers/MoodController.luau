--!strict
-- The street's mood, client side (Config/Mood): dark desaturated grade that shifts with day/night,
-- vignette, optional film grain, and the "hurt" look (colors drain, red pulsing edges, blur,
-- heartbeat) when health is low.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Mood = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Mood"))

local MoodController = {}

local grade: ColorCorrectionEffect
local hurtGrade: ColorCorrectionEffect
local blur: BlurEffect
local edges: { Frame } = {}
local heartbeat: Sound? = nil
local hurt = 0 -- 0 = healthy, 1 = about to die

local function effect(className: string, name: string): any
	local e = Lighting:FindFirstChild(name)
	if e == nil then
		e = Instance.new(className)
		e.Name = name
		e.Parent = Lighting -- created by the client: only this player sees it
	end
	return e
end

local function applyPhase(instant: boolean)
	local night = ReplicatedStorage:GetAttribute("Phase") == "Night"
	local g = if night then Mood.Grade.Night else Mood.Grade.Day
	local goal = { Saturation = g.Saturation, Contrast = g.Contrast, Brightness = g.Brightness, TintColor = Color3.fromHex(g.Tint) }
	TweenService:Create(grade, TweenInfo.new(if instant then 0 else Mood.Grade.TweenSeconds), goal):Play()
end

-- Four gradient frames darkening the screen edges.
local function buildVignette(gui: ScreenGui)
	local V = Mood.Vignette
	local sides = {
		{ pos = UDim2.fromScale(0, 0), size = UDim2.fromScale(1, V.Size), rotation = 90 },
		{ pos = UDim2.fromScale(0, 1 - V.Size), size = UDim2.fromScale(1, V.Size), rotation = -90 },
		{ pos = UDim2.fromScale(0, 0), size = UDim2.fromScale(V.Size, 1), rotation = 0 },
		{ pos = UDim2.fromScale(1 - V.Size, 0), size = UDim2.fromScale(V.Size, 1), rotation = 180 },
	}
	for i, side in sides do
		local frame = Instance.new("Frame")
		frame.Name = "Vignette" .. i
		frame.BorderSizePixel = 0
		frame.Position = side.pos
		frame.Size = side.size
		frame.BackgroundColor3 = Color3.fromHex(V.Color)
		frame.Active = false
		frame.Parent = gui
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = side.rotation
		gradient.Parent = frame
		table.insert(edges, frame)
	end
end

local function setVignette(opacity: number, color: Color3)
	for _, frame in edges do
		frame.BackgroundColor3 = color
		local gradient = frame:FindFirstChildOfClass("UIGradient")
		if gradient then
			-- opaque at the screen edge, invisible towards the center
			gradient.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1 - opacity),
				NumberSequenceKeypoint.new(0.6, 1 - opacity * 0.25),
				NumberSequenceKeypoint.new(1, 1),
			})
		end
	end
end

local function buildGrain(gui: ScreenGui)
	local G = Mood.Grain
	if G.Image == "" then
		return
	end
	local grain = Instance.new("ImageLabel")
	grain.Name = "Grain"
	grain.BackgroundTransparency = 1
	grain.Size = UDim2.new(1, G.TileSize, 1, G.TileSize)
	grain.Image = G.Image
	grain.ImageTransparency = 1 - G.Opacity
	grain.ScaleType = Enum.ScaleType.Tile
	grain.TileSize = UDim2.fromOffset(G.TileSize, G.TileSize)
	grain.Parent = gui
	local rng = Random.new()
	task.spawn(function()
		while grain.Parent do
			grain.Position = UDim2.fromOffset(-rng:NextInteger(0, G.TileSize), -rng:NextInteger(0, G.TileSize))
			task.wait(1 / G.FramesPerSecond)
		end
	end)
end

local function watchHealth(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if humanoid == nil then
		return
	end
	local L = Mood.LowHealth
	local function update()
		local fraction = if humanoid.MaxHealth > 0 then humanoid.Health / humanoid.MaxHealth else 1
		hurt = math.clamp((L.Threshold - fraction) / L.Threshold, 0, 1)
	end
	humanoid.HealthChanged:Connect(update)
	update()
end

function MoodController:Start()
	grade = effect("ColorCorrectionEffect", "BM_Mood")
	hurtGrade = effect("ColorCorrectionEffect", "BM_Hurt")
	blur = effect("BlurEffect", "BM_HurtBlur")
	blur.Size = 0

	local gui = Instance.new("ScreenGui")
	gui.Name = "Mood"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = -10 -- under every HUD
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	buildVignette(gui)
	buildGrain(gui)

	local L = Mood.LowHealth
	if L.HeartbeatSound ~= "" then
		local sound = Instance.new("Sound")
		sound.SoundId = L.HeartbeatSound
		sound.Looped = true
		sound.Volume = 0
		sound.Parent = SoundService
		sound:Play()
		heartbeat = sound
	end

	ReplicatedStorage:GetAttributeChangedSignal("Phase"):Connect(function()
		applyPhase(false)
	end)
	applyPhase(true)

	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(watchHealth)
	if player.Character then
		task.spawn(watchHealth, player.Character)
	end

	local normal = Color3.fromHex(Mood.Vignette.Color)
	local red = Color3.fromHex(L.VignetteColor)
	RunService.RenderStepped:Connect(function()
		local h = hurt
		local pulse = if h > 0 then (math.sin(os.clock() * math.pi * 2 * L.PulseSpeed * (0.5 + h)) + 1) / 2 else 0
		hurtGrade.Saturation = L.Saturation * h
		hurtGrade.Brightness = -0.05 * h * pulse
		blur.Size = L.BlurSize * h * (0.6 + 0.4 * pulse)
		local opacity = Mood.Vignette.Opacity + (L.VignetteOpacity - Mood.Vignette.Opacity) * h * (0.7 + 0.3 * pulse)
		setVignette(opacity, normal:Lerp(red, h))
		local beat = heartbeat
		if beat then
			beat.Volume = L.Volume * h
			beat.PlaybackSpeed = 0.9 + 0.5 * h
		end
	end)
end

return MoodController

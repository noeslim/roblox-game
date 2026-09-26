--!strict
-- Client-side atmosphere: rain around the camera, wet shiny ground, flickering neon signs,
-- fire light flicker, city / rain loops and distant sirens. Settings: Config/World (Weather, Sounds).
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local World = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("World"))

local AmbienceController = {}

local W = World.Weather
local rng = Random.new()

local rainPart: Part? = nil
local rainEmitter: ParticleEmitter? = nil
local rainSound: Sound? = nil
local baseReflectance: { [BasePart]: number } = {}

local function makeLoop(id: string, volume: number): Sound?
	if id == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Looped = true
	sound.Volume = volume
	sound.Parent = SoundService
	return sound
end

local function buildRain()
	local p = Instance.new("Part")
	p.Name = "RainEmitter"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(W.RainArea, 1, W.RainArea)
	p.Parent = workspace

	local e = Instance.new("ParticleEmitter")
	e.EmissionDirection = Enum.NormalId.Bottom
	e.Rate = 0
	e.Speed = NumberRange.new(W.RainSpeed * 0.9, W.RainSpeed * 1.1)
	e.Lifetime = NumberRange.new(W.RainHeight / W.RainSpeed * 1.1)
	e.Size = NumberSequence.new(W.RainSize)
	e.Squash = NumberSequence.new(W.RainSquash)
	e.Orientation = Enum.ParticleOrientation.VelocityParallel
	e.Color = ColorSequence.new(Color3.fromHex(W.RainColor))
	e.Transparency = NumberSequence.new(W.RainTransparency)
	e.LightInfluence = 0.6
	e.SpreadAngle = Vector2.new(4, 4)
	if W.RainTexture ~= "" then
		e.Texture = W.RainTexture
	end
	e.Parent = p
	rainPart = p
	rainEmitter = e
end

local function setRain(raining: boolean)
	local e = rainEmitter
	if e then
		e.Rate = if raining then W.RainRate else 0
	end
	-- wet ground
	for _, surface in CollectionService:GetTagged("WetSurface") do
		if surface:IsA("BasePart") then
			if baseReflectance[surface] == nil then
				baseReflectance[surface] = surface.Reflectance
			end
			surface.Reflectance = if raining then W.WetReflectance else baseReflectance[surface]
		end
	end
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		local density = if raining then W.RainAtmosphereDensity else World.Lighting.Atmosphere.Density
		TweenService:Create(atmosphere, TweenInfo.new(6), { Density = density }):Play()
	end
	local sound = rainSound
	if sound then
		if raining then
			sound:Play()
		else
			sound:Stop()
		end
	end
end

-- Signs: short random blackouts. Fire: light breathing.
local function flickerLoop()
	while true do
		task.wait(rng:NextNumber(0.3, 1.2))
		local signs = CollectionService:GetTagged("FlickerSign")
		if #signs > 0 then
			local sign = signs[rng:NextInteger(1, #signs)]
			local gui = sign:FindFirstChildOfClass("SurfaceGui")
			local light = sign:FindFirstChildOfClass("PointLight")
			task.spawn(function()
				for _ = 1, rng:NextInteger(1, 4) do
					if gui then
						gui.Enabled = false
					end
					if light then
						light.Enabled = false
					end
					task.wait(rng:NextNumber(0.04, 0.12))
					if gui then
						gui.Enabled = true
					end
					if light and ReplicatedStorage:GetAttribute("Phase") == "Night" then
						light.Enabled = true
					end
					task.wait(rng:NextNumber(0.04, 0.2))
				end
			end)
		end
	end
end

local function fireLoop()
	while true do
		task.wait(0.08)
		for _, light in CollectionService:GetTagged("FireLight") do
			if light:IsA("PointLight") then
				light.Brightness = 1.3 + rng:NextNumber() * 0.8
			end
		end
	end
end

local function sirenLoop()
	local S = World.Sounds
	if #S.Sirens == 0 then
		return
	end
	while true do
		task.wait(rng:NextNumber(S.SirenIntervalMin, S.SirenIntervalMax))
		local sound = Instance.new("Sound")
		sound.SoundId = S.Sirens[rng:NextInteger(1, #S.Sirens)]
		sound.Volume = S.Volume * rng:NextNumber(0.4, 0.8)
		sound.Parent = SoundService
		sound:Play()
		sound.Ended:Connect(function()
			sound:Destroy()
		end)
	end
end

function AmbienceController:Start()
	buildRain()
	rainSound = makeLoop(World.Sounds.RainLoop, World.Sounds.Volume)
	local city = makeLoop(World.Sounds.CityLoop, World.Sounds.Volume)
	if city then
		city:Play()
	end

	ReplicatedStorage:GetAttributeChangedSignal("Raining"):Connect(function()
		setRain(ReplicatedStorage:GetAttribute("Raining") == true)
	end)
	task.delay(3, function() -- the city may still be streaming in
		setRain(ReplicatedStorage:GetAttribute("Raining") == true)
	end)

	RunService.RenderStepped:Connect(function()
		local p = rainPart
		if p and rainEmitter and rainEmitter.Rate > 0 then
			local cam = workspace.CurrentCamera.CFrame.Position
			p.CFrame = CFrame.new(cam + Vector3.new(0, W.RainHeight, 0))
		end
	end)

	task.spawn(flickerLoop)
	task.spawn(fireLoop)
	task.spawn(sirenLoop)
end

return AmbienceController

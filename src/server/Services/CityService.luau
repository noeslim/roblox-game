--!strict
-- The city: makes sure Black Market City exists (built by Lib/MapBuilder, ideally once in Studio and
-- saved in the place), sets up the lighting effects and switches the night lights / neon on and off.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = require(Shared.Config.World)
local MapBuilder = require(script.Parent.Parent.Lib.MapBuilder)

local CityService = {}

local NIGHT_LIGHT_TAG = "NightLight" -- lights switched on at night
local NIGHT_GLOW_TAG = "NightGlow" -- parts that become Neon at night

local built = false

local function hex(s: string): Color3
	return Color3.fromHex(s)
end

local function setGlow(p: BasePart, night: boolean)
	if night then
		p.Material = Enum.Material.Neon
		local mesh = p:GetAttribute("MeshMaterial")
		local c = if mesh == "window_lit" then World.Lighting.NightWindowColor elseif mesh == "lamp_lens" then World.Lighting.NightLampColor else p:GetAttribute("NightColor")
		if type(c) == "string" then
			p.Color = hex(c)
		end
	else
		local m = p:GetAttribute("DayMaterial")
		p.Material = if type(m) == "string" then (Enum.Material :: any)[m] else Enum.Material.SmoothPlastic
		local c = p:GetAttribute("DayColor")
		if type(c) == "string" then
			p.Color = hex(c)
		end
	end
end

local function applyPhase()
	local night = ReplicatedStorage:GetAttribute("Phase") == "Night"
	for _, light in CollectionService:GetTagged(NIGHT_LIGHT_TAG) do
		if light:IsA("Light") then
			light.Enabled = night
		end
	end
	for _, p in CollectionService:GetTagged(NIGHT_GLOW_TAG) do
		if p:IsA("BasePart") then
			setGlow(p, night)
		end
	end
end

local function ensureEffect(className: string, name: string): Instance
	local existing = Lighting:FindFirstChild(name)
	if existing then
		return existing
	end
	local e = Instance.new(className)
	e.Name = name
	e.Parent = Lighting
	return e
end

local function setupLighting()
	local L = World.Lighting
	-- The place's own Sky, Atmosphere and post effects (Baseplate template, plugins, free models...)
	-- stack with ours and tint the city (red nights). Set them aside for this play session: nothing is
	-- saved, the place file keeps them. Everything we control is named BM_*.
	for _, child in Lighting:GetChildren() do
		local ours = string.sub(child.Name, 1, 3) == "BM_"
		if not ours and (child:IsA("Atmosphere") or child:IsA("Sky") or child:IsA("PostEffect")) then
			print(("[CityService] set aside Lighting.%s (%s)"):format(child.Name, child.ClassName))
			child.Parent = nil
		end
	end
	local sky = ensureEffect("Sky", "BM_Sky") :: Sky -- default Roblox sky textures
	sky.StarCount = L.Sky.StarCount
	sky.SunAngularSize = L.Sky.SunAngularSize
	sky.MoonAngularSize = L.Sky.MoonAngularSize
	sky.CelestialBodiesShown = true
	Lighting.ColorShift_Top = Color3.new(0, 0, 0)
	Lighting.ColorShift_Bottom = Color3.new(0, 0, 0)
	Lighting.FogStart = 0
	Lighting.FogEnd = 100000
	print(("[CityService] lighting: technology %s"):format(Lighting.Technology.Name))
	local atmosphere = ensureEffect("Atmosphere", "BM_Atmosphere") :: Atmosphere
	atmosphere.Density = L.Atmosphere.Density
	atmosphere.Haze = L.Atmosphere.Haze
	atmosphere.Glare = L.Atmosphere.Glare
	atmosphere.Offset = 0
	atmosphere.Color = hex(L.Atmosphere.Color)
	atmosphere.Decay = hex(L.Atmosphere.Decay)
	local bloom = ensureEffect("BloomEffect", "BM_Bloom") :: BloomEffect
	bloom.Intensity = L.Bloom.Intensity
	bloom.Size = L.Bloom.Size
	bloom.Threshold = L.Bloom.Threshold
	local cc = ensureEffect("ColorCorrectionEffect", "BM_ColorCorrection") :: ColorCorrectionEffect
	cc.Saturation = L.ColorCorrection.Saturation
	cc.Contrast = L.ColorCorrection.Contrast
	cc.TintColor = hex(L.ColorCorrection.TintColor)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.GlobalShadows = true
end

-- Makes sure the city exists. Returns workspace.Hideouts (the trap house plots).
function CityService.EnsureBuilt(): Instance
	if not built then
		built = true
		if workspace:FindFirstChild("City") and workspace:FindFirstChild("Hideouts") then
			print("[CityService] using the city saved in the place")
		else
			print("[CityService] no city in the place: building it now (tip: build it once in Studio, see docs)")
			MapBuilder.Build()
		end
		setupLighting()
		applyPhase()
	end
	return workspace:WaitForChild("Hideouts")
end

function CityService:Start()
	CityService.EnsureBuilt()
	ReplicatedStorage:GetAttributeChangedSignal("Phase"):Connect(applyPhase)
	applyPhase()
end

return CityService

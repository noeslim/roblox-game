--!strict
-- Builds placeholder 3D models from the configs (buildables and weapons), used by server and client.
-- To use real models made in Studio, put them in ReplicatedStorage.Assets:
--   Assets/Buildables/<buildableId>  (Model sized like the config `size`, pivot at its center)
--   Assets/Weapons/<fullSet>         (optional, used when the weapon is a full set)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = script.Parent.Parent:WaitForChild("Config")
local Visual = require(Config:WaitForChild("Visual"))
local Economy = require(Config:WaitForChild("Economy"))

local ModelFactory = {}

local function vec(v: { x: number, y: number, z: number }): Vector3
	return Vector3.new(v.x, v.y, v.z)
end

local function material(name: string?): Enum.Material
	if name then
		local ok, m = pcall(function()
			return (Enum.Material :: any)[name]
		end)
		if ok and m then
			return m
		end
	end
	return Enum.Material.SmoothPlastic
end

local function shape(name: string?): Enum.PartType
	if name == "Ball" then
		return Enum.PartType.Ball
	elseif name == "Cylinder" then
		return Enum.PartType.Cylinder
	end
	return Enum.PartType.Block
end

local function findAsset(folderName: string, name: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild(folderName)
	local model = folder and folder:FindFirstChild(name)
	if model and model:IsA("Model") then
		return model
	end
	return nil
end

local function anchorAll(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
end

-- Invisible box matching the object's footprint; used as PrimaryPart and for click selection.
local function makeRoot(size: Vector3, cf: CFrame): Part
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = size
	root.CFrame = cf
	root.Transparency = 1
	root.CanCollide = false
	root.CanTouch = false
	root.CastShadow = false
	root.Anchored = true
	return root
end

function ModelFactory.MakePart(spec: any, parent: Instance, originCf: CFrame, canCollide: boolean): Part
	local p = Instance.new("Part")
	p.Shape = shape(spec.shape)
	p.Size = vec(spec.size)
	p.CFrame = originCf * CFrame.new(vec(spec.pos))
	p.Color = Color3.fromHex(spec.color)
	p.Material = material(spec.material)
	p.Transparency = spec.transparency or 0
	p.Anchored = true
	p.CanCollide = canCollide
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = spec.material ~= "Neon" and spec.material ~= "Glass"
	p.Parent = parent
	return p
end

-- Model centered on CFrame.identity; move it with model:PivotTo().
function ModelFactory.Buildable(def: any): Model
	local size = vec(def.size)
	local asset = findAsset("Buildables", def.id)
	if asset then
		local model = asset:Clone()
		anchorAll(model)
		if model.PrimaryPart == nil then
			local cf = model:GetBoundingBox()
			local root = makeRoot(size, cf)
			root.Parent = model
			model.PrimaryPart = root
		end
		model:PivotTo(CFrame.identity)
		model.Name = def.id
		return model
	end

	local model = Instance.new("Model")
	model.Name = def.id
	local root = makeRoot(size, CFrame.identity)
	root.Parent = model
	model.PrimaryPart = root

	local solid = def.solid ~= false
	for _, spec in def.parts do
		ModelFactory.MakePart(spec, model, CFrame.identity, solid)
	end

	if def.light then
		local att = Instance.new("Attachment")
		att.Position = vec(def.light.pos)
		att.Parent = root
		local light = Instance.new("PointLight")
		light.Color = Color3.fromHex(def.light.color)
		light.Range = def.light.range
		light.Brightness = def.light.brightness
		light.Shadows = false
		light.Parent = att
	end
	return model
end

local function partColor(part: any): string
	if part.set and Visual.SetColors[part.set] then
		return Visual.SetColors[part.set]
	end
	return Economy.RarityColor[part.rarity] or "#888888"
end

-- Placeholder weapon (about 4 studs long) from { [slot]: partId }, centered on CFrame.identity.
-- Missing slots are simply skipped, so it also works as a live preview at the workbench.
function ModelFactory.Weapon(partIds: { [string]: string }, catalogue: { [string]: any }, rarity: string?, fullSet: string?): Model
	local asset = if fullSet then findAsset("Weapons", fullSet) else nil
	if asset then
		local model = asset:Clone()
		anchorAll(model)
		model:PivotTo(CFrame.identity)
		return model
	end

	local model = Instance.new("Model")
	model.Name = "Weapon"
	local root = makeRoot(Vector3.new(4, 1.6, 0.5), CFrame.identity)
	root.Parent = model
	model.PrimaryPart = root

	for slot, piece in Visual.WeaponLayout do
		local part = catalogue[partIds[slot] or ""]
		if part then
			local p = ModelFactory.MakePart({
				size = piece.size,
				pos = piece.pos,
				shape = piece.shape,
				color = partColor(part),
				material = if part.set == "Neon" then "Neon" else "Metal",
			}, model, CFrame.identity, false)
			p.Name = slot
		end
	end

	if rarity then
		ModelFactory.MakePart({
			size = { x = 1.3, y = 0.08, z = 0.42 },
			pos = { x = 0, y = 0.12, z = 0 },
			color = Economy.RarityColor[rarity] or "#FFFFFF",
			material = "Neon",
		}, model, CFrame.identity, false).Name = "RarityStrip"
	end
	return model
end

return ModelFactory

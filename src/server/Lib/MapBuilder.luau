--!strict
-- Builds Black Market City (docs/GAME_DESIGN.md §19) from Config/City: ground, roads, buildings,
-- 18 trap houses (workspace.Hideouts), street furniture, war zone, sea.
--
-- Recommended: build it ONCE in Studio (edit mode) and save the place, so it can stream and be
-- edited by hand. Command bar:
--     require(game.ServerScriptService.Server.Lib.MapBuilder).Build()
-- If the place has no workspace.City when a server starts, CityService builds it at runtime.
-- Looks, best first:
--   1. your prefabs: ReplicatedStorage.Assets.Buildings.<archetype> and Assets.Props.<kind> (a Model,
--      or a Folder of Model variants). Build them from Roblox's official Modern City kit or any model.
--   2. the generated mesh library ReplicatedStorage.Assets.BlackMarketMeshes (tools/meshgen)
--   3. plain parts
-- Every MaterialVariant found in MaterialService (e.g. a materials pack from the Toolbox) is applied
-- to the parts of the same base material (bricks, concrete, asphalt...).
local CollectionService = game:GetService("CollectionService")
local MaterialService = game:GetService("MaterialService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local City = require(Shared.Config.City)
local Economy = require(Shared.Config.Economy)
local World = require(Shared.Config.World)
local CityLayout = require(Shared.Logic.CityLayout)
local CityParts = require(Shared.Logic.CityParts)
local ModelFactory = require(Shared.Visual.ModelFactory)
local MeshLibrary = require(Shared.Config.MeshLibrary)

local MapBuilder = {}

local CAR_COLORS = { "#7A1F1F", "#1F2F4A", "#2A2A2E", "#C8C8CC", "#3A4A3A", "#6A5A40", "#101014", "#4A1A3A" }
local CONTAINER_COLORS = { "#8A3A2A", "#2A4A7A", "#2E5A3A", "#B06A2A", "#5A5A5E", "#7A2A4A" }
local AWNING_COLORS = { "#7A1E2A", "#1E4A2A", "#1E2E5A", "#5A3A1E", "#2A2A2E" }
local SIGN_COLORS = { "#FF3FA4", "#3FA9F5", "#39FF88", "#FFB020", "#B45CFF", "#FF3B3B" }
local SPECIAL_SIGN_COLORS = { POLICE = "#3FA9F5", BANK = "#39FF88", SUPPLIER = "#FFB020", BAR = "#FF3FA4" }
local COLLIDING_PROPS = {
	utility_pole = true, traffic_light = true, billboard = true, lamp = true, car = true, container = true, barrier = true,
	bench = true, trashcan = true, hydrant = true, mailbox = true, smokestack = true,
	dumpster = true, newspaper = true, phone_booth = true, bus_stop = true, parking_meter = true, planter = true,
	utility_box = true, barrels = true, crates = true,
}

local function hex(s: string): Color3
	return Color3.fromHex(s)
end

local function material(name: string): Enum.Material
	local ok, m = pcall(function()
		return (Enum.Material :: any)[name]
	end)
	return if ok and m then m else Enum.Material.SmoothPlastic
end

local function folder(name: string, parent: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- texture name -> MaterialVariant name, filled by setupTextureVariants()
local textureVariants: { [string]: string } = {}
local TEXTURE_TINT = 0.6 -- textured parts: color blended this much towards white (the texture has the color)

local function readMap(from: Instance, prop: string): any
	local ok, value = pcall(function()
		return (from :: any)[prop]
	end)
	return if ok then value else nil
end

local function writeMap(to: Instance, prop: string, value: any): boolean
	if value == nil or value == "" then
		return false
	end
	return (pcall(function()
		(to :: any)[prop] = value
	end))
end

-- The imported library carries one "__swatch__<name>" mesh per texture, whose SurfaceAppearance holds
-- the uploaded PBR maps. Each becomes a MaterialVariant "BM_<name>" in MaterialService.
local function setupTextureVariants(): number
	table.clear(textureVariants)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local library = assets and assets:FindFirstChild("BlackMarketMeshes")
	if library == nil then
		return 0
	end
	local count = 0
	for name, info in MeshLibrary.Textures do
		local swatch = library:FindFirstChild("__swatch__" .. name, true)
		if swatch and swatch:IsA("MeshPart") then
			local sa = swatch:FindFirstChildOfClass("SurfaceAppearance")
			local variantName = "BM_" .. name
			local old = MaterialService:FindFirstChild(variantName)
			if old then
				old:Destroy()
			end
			local variant = Instance.new("MaterialVariant")
			variant.Name = variantName
			variant.BaseMaterial = material(info.baseMaterial)
			variant.StudsPerTile = info.studsPerTile
			local ok = false
			if sa then
				for _, map in { "ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap" } do
					-- older and newer (Content) property names
					local done = writeMap(variant, map, readMap(sa, map))
					if not done then
						done = writeMap(variant, map .. "Content", readMap(sa, map .. "Content"))
					end
					ok = ok or (done and map == "ColorMap")
				end
			end
			if not ok then
				ok = writeMap(variant, "ColorMap", readMap(swatch, "TextureID"))
			end
			if ok then
				variant.Parent = MaterialService
				textureVariants[name] = variantName
				count += 1
			else
				variant:Destroy()
			end
		end
	end
	return count
end

local function makePart(spec: CityParts.PartSpec, parent: Instance, base: CFrame): BasePart
	local p: BasePart
	if spec.shape == "Wedge" then
		p = Instance.new("WedgePart")
	else
		local block = Instance.new("Part")
		if spec.shape == "Cylinder" then
			block.Shape = Enum.PartType.Cylinder
		elseif spec.shape == "Ball" then
			block.Shape = Enum.PartType.Ball
		end
		p = block
	end
	p.Name = spec.name
	p.Anchored = true
	p.Size = Vector3.new(spec.size.x, spec.size.y, spec.size.z)
	p.CFrame = base
		* CFrame.new(spec.pos.x, spec.pos.y, spec.pos.z)
		* CFrame.Angles(0, math.rad(spec.rotY or 0), 0)
		* CFrame.Angles(0, 0, math.rad(spec.rotZ or 0))
	p.Material = material(spec.material)
	p.Color = hex(spec.color)
	local variant = spec.texture and textureVariants[spec.texture]
	if variant then
		p.Material = material(MeshLibrary.Textures[spec.texture :: string].baseMaterial)
		p.MaterialVariant = variant
		p.Color = p.Color:Lerp(Color3.new(1, 1, 1), TEXTURE_TINT)
	end
	p.Transparency = spec.transparency or 0
	p.CanCollide = spec.canCollide ~= false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if p.Transparency >= 1 then
		p.CanQuery = false
		p.CastShadow = false
	end
	if spec.material == "Neon" or spec.material == "Glass" then
		p.CastShadow = false
	end
	p.Parent = parent
	return p
end

local function surfaceText(target: BasePart, face: Enum.NormalId, text: string, color: string, font: Enum.Font)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.LightInfluence = 0
	gui.Brightness = 2
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = target
	local label = Instance.new("TextLabel")
	label.Name = "SignText"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = hex(color)
	label.TextScaled = true
	label.Font = font
	label.Parent = gui
end

-- Night behaviour of library meshes: lit windows and lamp lenses glow at night (CityService).
local function tagMeshes(parts: { MeshPart }, rng: Random, alwaysOn: boolean?)
	for _, p in parts do
		local m = p:GetAttribute("MeshMaterial")
		if m == "window_lit" or m == "lamp_lens" then
			if alwaysOn then
				p.Material = Enum.Material.Neon
				p.Color = hex("#FFD9A0")
			else
				p:SetAttribute("DayMaterial", p.Material.Name)
				p:SetAttribute("DayColor", "#" .. p.Color:ToHex())
				p:SetAttribute("NightColor", if m == "lamp_lens" then World.Lighting.NightLampColor else World.Lighting.NightWindowColor)
				CollectionService:AddTag(p, "NightGlow")
			end
		elseif m == "awning" then
			p.Color = hex(AWNING_COLORS[rng:NextInteger(1, #AWNING_COLORS)])
		elseif m == "car_paint" then
			p.Color = hex(CAR_COLORS[rng:NextInteger(1, #CAR_COLORS)])
		elseif m == "container_paint" then
			p.Color = hex(CONTAINER_COLORS[rng:NextInteger(1, #CONTAINER_COLORS)])
		end
	end
end

local function findLens(parts: { MeshPart }): MeshPart?
	for _, p in parts do
		if p:GetAttribute("MeshMaterial") == "lamp_lens" then
			return p
		end
	end
	return nil
end

local function streetLight(parent: Instance)
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Bottom
	light.Angle = World.StreetLight.Angle
	light.Range = World.StreetLight.Range
	light.Brightness = World.StreetLight.Brightness
	light.Color = hex(World.StreetLight.Color)
	light.Shadows = false
	light.Parent = parent
	CollectionService:AddTag(light, "NightLight")
end

-- Prefabs & materials --------------------------------------------------------------------------------

-- A prefab from ReplicatedStorage.Assets.<folderName>.<key>: a Model, or a Folder of Model variants.
local function findPrefab(folderName: string, key: string, rng: Random): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild(folderName)
	local entry = folder and folder:FindFirstChild(key)
	if entry == nil then
		return nil
	end
	if entry:IsA("Model") then
		return entry
	end
	local variants = {}
	for _, c in entry:GetChildren() do
		if c:IsA("Model") then
			table.insert(variants, c)
		end
	end
	return if #variants > 0 then variants[rng:NextInteger(1, #variants)] else nil
end

-- Clones a prefab with the bottom center of its bounding box on `cf` (its front must face +Z).
-- With a footprint, it is scaled uniformly to fit w x d. Returns the clone and its size.
local function placePrefab(prefab: Model, parent: Instance, cf: CFrame, w: number?, d: number?): (Model, Vector3)
	local clone = prefab:Clone()
	for _, x in clone:GetDescendants() do
		if x:IsA("BasePart") then
			x.Anchored = true
		end
	end
	local box, size = clone:GetBoundingBox()
	if w and d and size.X > 0 and size.Z > 0 then
		local scale = math.min(w / size.X, d / size.Z)
		if math.abs(scale - 1) > 0.02 then
			clone:ScaleTo(clone:GetScale() * scale)
			box, size = clone:GetBoundingBox()
		end
	end
	local bottom = box * CFrame.new(0, -size.Y / 2, 0)
	clone:PivotTo(cf * bottom:ToObjectSpace(clone:GetPivot()))
	clone.Parent = parent
	return clone, size
end

-- Applies the MaterialVariants of MaterialService (one variant per material + color, so a building
-- or a road keeps one look). Returns how many parts changed.
local function applyMaterialVariants(roots: { Instance }, rng: Random): number
	local byBase: { [Enum.Material]: { string } } = {}
	for _, v in MaterialService:GetDescendants() do
		-- BM_* are our own textures, applied on purpose through PartSpec.texture
		if v:IsA("MaterialVariant") and string.sub(v.Name, 1, 3) ~= "BM_" then
			local list = byBase[v.BaseMaterial] or {}
			byBase[v.BaseMaterial] = list
			table.insert(list, v.Name)
		end
	end
	if next(byBase) == nil then
		return 0
	end
	local chosen: { [string]: string } = {}
	local count = 0
	for _, root in roots do
		for _, d in root:GetDescendants() do
			-- plain parts only: library meshes have no texture coordinates, a tiled texture smears on them
			if d:IsA("Part") and d.MaterialVariant == "" then
				local list = byBase[d.Material]
				if list then
					local key = d.Material.Name .. d.Color:ToHex()
					local name = chosen[key] or list[rng:NextInteger(1, #list)]
					chosen[key] = name
					d.MaterialVariant = name
					count += 1
				end
			end
		end
	end
	return count
end

-- Pieces --------------------------------------------------------------------------------------------

local SIGN_HEIGHT = { shop = 12, chinatown = 26, office = 12, tower = 12, warehouse = 21, apartment = 10 }

-- Furnished ground floor (Logic/CityParts.Interior): small pieces cast no shadow (cheaper).
local function buildInterior(a: City.Archetype, model: Model, cf: CFrame, seed: number)
	local interior = Instance.new("Model")
	interior.Name = "Interior"
	local parts, lights = CityParts.Interior(a, seed, City.Interiors)
	for _, spec in parts do
		local p = makePart(spec, interior, cf)
		p.CastShadow = false
	end
	for i, l in lights do
		local holder = makePart({ name = "Light" .. i, shape = "Block", size = { x = 0.2, y = 0.2, z = 0.2 }, pos = l.pos, material = "SmoothPlastic", color = "#FFFFFF", transparency = 1, canCollide = false }, interior, cf)
		holder.CanQuery = false
		local light = Instance.new("PointLight")
		light.Color = hex(l.color)
		light.Range = l.range
		light.Brightness = l.brightness
		light.Shadows = l.shadows
		light.Parent = holder
	end
	interior.Parent = model
end

-- A door leaf in the doorway, hinged on its left edge; clients swing it open (DoorController).
local function buildDoor(spec: CityParts.DoorSpec, model: Model, cf: CFrame)
	local door = makePart({ name = "Door", shape = "Block", size = { x = spec.w, y = spec.h, z = spec.t }, pos = { x = spec.x, y = spec.y, z = spec.z }, material = spec.material, color = spec.color }, model, cf)
	if spec.material == "Glass" then
		door.Transparency = 0.35
	end
	door:SetAttribute("ClosedCFrame", door.CFrame)
	door:SetAttribute("HingeOffset", -spec.w / 2)
	CollectionService:AddTag(door, "AutoDoor")
end

local function buildBuilding(b: CityLayout.Building, parent: Instance, origin: CFrame, groundTop: number, rng: Random)
	local a = City.Archetypes[b.archetype]
	local model = Instance.new("Model")
	model.Name = b.archetype
	local cf = origin * CFrame.new(b.x, groundTop, b.z) * CFrame.Angles(0, math.rad(b.rot), 0)
	local body: BasePart? = nil
	local front, signTop = a.d / 2, a.h
	local prefab = findPrefab("Buildings", b.archetype, rng)
	if prefab then
		local _, size = placePrefab(prefab, model, cf, a.w, a.d)
		front, signTop = size.Z / 2, size.Y
	else
		local I = City.Interiors
		local furnished = I.Enabled and a.interior ~= nil
		local shell, door
		if furnished then
			shell, door = CityParts.BuildingShell(a, b.color, I.WallThickness)
		else
			shell = CityParts.BuildingBody(a, b.color)
		end
		for _, spec in shell do
			local p = makePart(spec, model, cf)
			if spec.name == "Body" then
				body = p
			end
		end
		-- one of the archetype's facade variants, always the same for this spot
		local variants = ModelFactory.LibraryVariants("bld_" .. b.archetype)
		local pick = if #variants > 0 then variants[math.floor(math.abs(b.x * 3 + b.z * 7)) % #variants + 1] else "bld_" .. b.archetype
		local meshes = ModelFactory.PlaceLibraryModel(pick, model, cf, false)
		if furnished then
			-- the facade's closed door leaf gives way to a door that opens (DoorController)
			for i = #meshes, 1, -1 do
				local m = meshes[i]:GetAttribute("MeshMaterial")
				if type(m) == "string" and string.sub(m, 1, 5) == "door_" then
					meshes[i]:Destroy()
					table.remove(meshes, i)
				end
			end
			buildInterior(a, model, cf, math.floor(b.x * 7 + b.z * 13))
			if door then
				buildDoor(door, model, cf)
			end
		end
		tagMeshes(meshes, rng)
	end
	if b.sign then
		local width = math.min(a.w * 0.6, 18)
		local board = makePart({
			name = "Sign",
			shape = "Block",
			size = { x = width, y = 3, z = 0.4 },
			pos = { x = 0, y = math.min(SIGN_HEIGHT[b.archetype] or 10, signTop - 2), z = front + 0.7 },
			material = "SmoothPlastic",
			color = "#141418",
		}, model, cf)
		local color = SPECIAL_SIGN_COLORS[b.sign] or SIGN_COLORS[rng:NextInteger(1, #SIGN_COLORS)]
		surfaceText(board, Enum.NormalId.Back, b.sign, color, Enum.Font.Arcade)
		local light = Instance.new("PointLight")
		light.Color = hex(color)
		light.Range = 16
		light.Brightness = 1.2
		light.Shadows = false
		light.Parent = board
		CollectionService:AddTag(light, "NightLight")
		if rng:NextNumber() < World.Props.FlickerSignChance then
			CollectionService:AddTag(board, "FlickerSign")
		end
	end
	model.PrimaryPart = body
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	-- StreamingMesh shows an automatic low-poly stand-in for far buildings: it mangles the facades
	-- (tilted windows, floating pieces), so it is off unless Config/City.Streaming asks for it
	if City.Streaming.BuildingLod and a.h >= 40 then
		pcall(function()
			(model :: any).LevelOfDetail = Enum.ModelLevelOfDetail.StreamingMesh
		end)
	end
	model.Parent = parent
end

local function buildHouse(h: CityLayout.House, hideouts: Instance, origin: CFrame, groundTop: number, rng: Random)
	local H = City.Houses
	local B = Economy.Building
	local plot = Instance.new("Folder")
	plot.Name = "Plot_" .. h.index
	plot:SetAttribute("Index", h.index)
	plot:SetAttribute("SizeX", B.PlotSizeX)
	plot:SetAttribute("SizeZ", B.PlotSizeZ)
	plot:SetAttribute("MaxHeight", B.PlotMaxHeight)
	plot:SetAttribute("OwnerUserId", 0)
	plot:SetAttribute("District", h.district)

	local cf = origin * CFrame.new(h.x, groundTop - H.BasementDepth, h.z)
	local anchor = Instance.new("Model")
	anchor.Name = "Anchor"
	anchor.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- clients always know every plot origin
	local house = Instance.new("Model")
	house.Name = "House"
	house.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local sign = Instance.new("Model")
	sign.Name = "Sign"
	local waypoints = folder("Waypoints", plot)
	folder("Objects", plot)
	local groups: { [string]: Instance } = { Anchor = anchor, Sign = sign, Waypoints = waypoints }

	local parts, lights = CityParts.House(City, h.index)
	for _, spec in parts do
		local p = makePart(spec, groups[spec.group or ""] or house, cf)
		if spec.name == "Floor" then
			anchor.PrimaryPart = p
		elseif spec.name == "SignBoard" then
			surfaceText(p, Enum.NormalId.Front, "FOR RENT", "#FFB020", Enum.Font.GothamBlack)
			surfaceText(p, Enum.NormalId.Back, "FOR RENT", "#FFB020", Enum.Font.GothamBlack)
		end
	end
	for i, l in lights do
		local holder = makePart({
			name = "Light" .. i,
			shape = "Block",
			size = { x = 0.2, y = 0.2, z = 0.2 },
			pos = l.pos,
			material = "SmoothPlastic",
			color = "#FFFFFF",
			transparency = 1,
			canCollide = false,
		}, house, cf)
		local light = Instance.new("PointLight")
		light.Color = hex(l.color)
		light.Range = l.range
		light.Brightness = l.brightness
		light.Shadows = l.shadows
		light.Parent = holder
	end
	local houses = ModelFactory.LibraryVariants("house_shack")
	local look = if #houses > 0 then houses[(h.index - 1) % #houses + 1] else "house_shack"
	tagMeshes(ModelFactory.PlaceLibraryModel(look, house, cf, false), rng, true)

	anchor.Parent = plot
	house.Parent = plot
	sign.Parent = plot
	plot.Parent = hideouts
end

-- Traffic lights: the signals of the north-south roads show green, the east-west ones red.
-- Tagged TrafficSignal (attributes Color / Axis) so a controller can cycle them later.
local SIGNAL_COLORS: { [string]: string } = World.TrafficLights.Colors

local function lightSignals(parts: { MeshPart }, rot: number)
	local axis = if math.abs(rot) == 90 then "NS" else "EW"
	local lit = if axis == "NS" then "signal_green" else "signal_red"
	for _, p in parts do
		local m = p:GetAttribute("MeshMaterial")
		if type(m) == "string" and SIGNAL_COLORS[m] then
			p:SetAttribute("Color", m)
			p:SetAttribute("Axis", axis)
			p:SetAttribute("OffMaterial", p.Material.Name)
			p:SetAttribute("OffColor", "#" .. p.Color:ToHex())
			CollectionService:AddTag(p, "TrafficSignal")
			if m == lit then
				p.Material = Enum.Material.Neon
				p.Color = hex(SIGNAL_COLORS[m])
			end
		end
	end
end

local function addPropExtras(p: CityLayout.Prop, model: Model, cf: CFrame)
	for _, spec in CityParts.PropExtras(p.kind) do
		local part = makePart(spec, model, cf)
		if spec.name == "AdFace" then
			local ad = City.BillboardAds[p.ad or 1] or City.BillboardAds[1]
			part.Color = hex(ad.background)
			surfaceText(part, Enum.NormalId.Back, ad.text, ad.color, Enum.Font.GothamBlack)
			local gui = part:FindFirstChildOfClass("SurfaceGui")
			if gui then
				gui.Brightness = 1.2
				local label = gui:FindFirstChild("SignText") :: TextLabel?
				if label then
					label.BackgroundTransparency = 0
					label.BackgroundColor3 = hex(ad.background)
					label.Size = UDim2.fromScale(0.94, 0.8)
					label.Position = UDim2.fromScale(0.03, 0.1)
					gui.ClipsDescendants = true
				end
			end
		end
	end
end

local function buildProp(p: CityLayout.Prop, parent: Instance, origin: CFrame, sidewalkTop: number, rng: Random): Model
	local ground = if p.kind == "car" then 0 else sidewalkTop
	local cf = origin * CFrame.new(p.x, ground + (p.y or 0), p.z) * CFrame.Angles(0, math.rad(p.rot), 0)
	local model = Instance.new("Model")
	model.Name = p.kind
	local prefab = findPrefab("Props", p.kind, rng)
	if prefab then
		placePrefab(prefab, model, cf)
		model.Parent = parent
		return model
	end
	-- one of the prop's variants (parked cars: sedan, van, pickup, hatchback), fixed per spot
	local variants = ModelFactory.LibraryVariants("prop_" .. p.kind)
	local asset = if #variants > 0 then variants[math.floor(math.abs(p.x * 3 + p.z * 7)) % #variants + 1] else "prop_" .. p.kind
	local meshes = ModelFactory.PlaceLibraryModel(asset, model, cf, COLLIDING_PROPS[p.kind] == true)
	if #meshes == 0 then
		for _, spec in CityParts.PropFallback(p.kind) do
			local part = makePart(spec, model, cf)
			if p.kind == "car" and spec.name == "Body" then
				part.Color = hex(CAR_COLORS[rng:NextInteger(1, #CAR_COLORS)])
			elseif p.kind == "container" then
				part.Color = hex(CONTAINER_COLORS[rng:NextInteger(1, #CONTAINER_COLORS)])
			elseif p.kind == "lamp" and spec.name == "Lens" then
				streetLight(part)
				CollectionService:AddTag(part, "NightGlow")
			end
		end
	else
		tagMeshes(meshes, rng)
		if p.kind == "lamp" then
			local lens = findLens(meshes)
			if lens then
				streetLight(lens)
			end
		elseif p.kind == "traffic_light" then
			lightSignals(meshes, p.rot)
		end
	end
	addPropExtras(p, model, cf)
	model.Parent = parent
	return model
end

-- Overhead wires: a sagging Beam per wire between the crossarms of two poles (no parts, no collisions).
local function buildWires(layout: CityLayout.Layout, poles: { [string]: Model }, origin: CFrame, sidewalkTop: number)
	local P = City.Props
	local armY = P.PoleHeight - 1.5 + 0.55
	local down = Vector3.new(0, -1, 0)
	for _, w in layout.wires do
		local a, b = poles[w.x0 .. "," .. w.z0], poles[w.x1 .. "," .. w.z1]
		local holderA = a and a:FindFirstChildWhichIsA("BasePart")
		local holderB = b and b:FindFirstChildWhichIsA("BasePart")
		if holderA and holderB then
			local rot = CFrame.Angles(0, math.rad(w.rot), 0)
			local cfA = origin * CFrame.new(w.x0, sidewalkTop, w.z0) * rot
			local cfB = origin * CFrame.new(w.x1, sidewalkTop, w.z1) * rot
			for _, offset in P.WireOffsets do
				local pa = (cfA * CFrame.new(0, armY, offset)).Position
				local pb = (cfB * CFrame.new(0, armY, offset)).Position
				local along = (pb - pa).Unit
				local att0 = Instance.new("Attachment")
				att0.Name = "Wire"
				att0.Parent = holderA
				att0.WorldCFrame = CFrame.fromMatrix(pa, down, along) -- X axis points down: the curve sags
				local att1 = Instance.new("Attachment")
				att1.Name = "Wire"
				att1.Parent = holderB
				att1.WorldCFrame = CFrame.fromMatrix(pb, down, along)
				local beam = Instance.new("Beam")
				beam.Attachment0 = att0
				beam.Attachment1 = att1
				beam.CurveSize0 = P.WireSag
				beam.CurveSize1 = -P.WireSag
				beam.Width0 = P.WireWidth
				beam.Width1 = P.WireWidth
				beam.Segments = 12
				beam.FaceCamera = true
				beam.Color = ColorSequence.new(hex("#141416"))
				beam.LightInfluence = 1
				beam.Transparency = NumberSequence.new(0)
				beam.Parent = holderA
			end
		end
	end
end

local function buildSpecial(s: CityLayout.Special, parent: Instance, origin: CFrame, sidewalkTop: number, rng: Random)
	if s.kind == "sea" then
		local sx, sz = s.sx or 200, s.sz or 200
		local center = origin * CFrame.new(s.x, 0, s.z)
		local ok = pcall(function()
			workspace.Terrain:FillBlock(center * CFrame.new(0, -12, 0), Vector3.new(sx, 20, sz), Enum.Material.Water)
			workspace.Terrain:FillBlock(center * CFrame.new(0, -27, 0), Vector3.new(sx, 10, sz), Enum.Material.Sand)
		end)
		if not ok then
			makePart({ name = "Sea", shape = "Block", size = { x = sx, y = 1, z = sz }, pos = { x = 0, y = -2.5, z = 0 }, material = "Glass", color = "#1E4A6A", transparency = 0.2 }, parent, center)
		end
		return
	end
	local cf = origin * CFrame.new(s.x, sidewalkTop, s.z) * CFrame.Angles(0, math.rad(s.rot), 0)
	local model = Instance.new("Model")
	model.Name = s.kind .. (if s.label then "_" .. s.label else "")
	for _, spec in CityParts.Special(s, City) do
		local p = makePart(spec, model, cf)
		if spec.name == "GasSign" then
			surfaceText(p, Enum.NormalId.Back, "GAS & SNACKS", "#FF3B3B", Enum.Font.Arcade)
		end
	end
	local meshName = ({ fountain = "sp_fountain", gas_station = "sp_gas_station", control_point = "sp_control_point" } :: { [string]: string })[s.kind]
	if meshName then
		tagMeshes(ModelFactory.PlaceLibraryModel(meshName, model, cf, s.kind ~= "control_point"), rng)
	end
	if s.kind == "court" then
		local half = (s.sz or 50) / 2 - 2
		ModelFactory.PlaceLibraryModel("prop_hoop", model, cf * CFrame.new(0, 0, -half), true)
		ModelFactory.PlaceLibraryModel("prop_hoop", model, cf * CFrame.new(0, 0, half) * CFrame.Angles(0, math.pi, 0), true)
	elseif s.kind == "lanterns" then
		local length, width = s.sz or 100, s.sx or 16
		for z = -length / 2 + 20, length / 2 - 20, 20 do
			for x = -width / 2 + 2, width / 2 - 2, 4 do
				local lcf = cf * CFrame.new(x, 16, z)
				if #ModelFactory.PlaceLibraryModel("prop_lantern", model, lcf, false) == 0 then
					for _, spec in CityParts.PropFallback("lantern") do
						makePart(spec, model, lcf)
					end
				end
			end
		end
	elseif s.kind == "control_point" then
		model:SetAttribute("Label", s.label)
	end
	model.Parent = parent
end

-- Street ambience: steam from manholes, puddles, fire barrels
local function buildAmbience(layout: CityLayout.Layout, parent: Instance, origin: CFrame, sidewalkTop: number, rng: Random)
	local avenues = {}
	for _, r in layout.roads do
		if r.kind == "avenue" then
			table.insert(avenues, r)
		end
	end
	for _ = 1, World.Props.SteamVents * 3 do
		local r = avenues[rng:NextInteger(1, #avenues)]
		local pos = origin * CFrame.new(rng:NextNumber(r.x0 + 4, r.x1 - 4), 0.05, rng:NextNumber(r.z0 + 4, r.z1 - 4))
		local lid = makePart({ name = "Manhole", shape = "Cylinder", size = { x = 0.1, y = 3, z = 3 }, pos = { x = 0, y = 0, z = 0 }, rotZ = 90, material = "DiamondPlate", color = "#202024", canCollide = false }, parent, pos)
		-- the scanned cover when the library has it (the part stays, invisible, to carry the steam)
		if #ModelFactory.PlaceLibraryModel("prop_manhole", parent, pos * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), false) > 0 then
			lid.Transparency = 1
		end
		local smoke = Instance.new("Smoke")
		smoke.Color = hex("#C8C8D0")
		smoke.Opacity = 0.12
		smoke.RiseVelocity = 5
		smoke.Size = 4
		smoke.TimeScale = 0.6
		smoke.Parent = lid
	end
	for _ = 1, World.Props.Puddles * 4 do
		local r = layout.roads[rng:NextInteger(1, #layout.roads)]
		local d = rng:NextNumber(3, 8)
		local pos = origin * CFrame.new(rng:NextNumber(r.x0 + 2, r.x1 - 2), 0.02, rng:NextNumber(r.z0 + 2, r.z1 - 2))
		local p = makePart({ name = "Puddle", shape = "Cylinder", size = { x = 0.04, y = d, z = d * 0.7 }, pos = { x = 0, y = 0, z = 0 }, rotY = rng:NextNumber(0, 180), rotZ = 90, material = "Glass", color = "#15171F", transparency = 0.25, canCollide = false }, parent, pos)
		p.Reflectance = 0.35
		p.CanQuery = false
	end
	-- fire barrels where people hang out: war zone, alley, the blocks
	local spots = {}
	for _, c in layout.cells do
		if c.district == "WarZone" or c.district == "Blocks" or c.district == "Chinatown" then
			table.insert(spots, c.rect)
		end
	end
	for _ = 1, World.Props.FireBarrels * 2 do
		local c = spots[rng:NextInteger(1, #spots)]
		local x, z = rng:NextNumber(c.x0 + 12, c.x1 - 12), rng:NextNumber(c.z0 + 12, c.z1 - 12)
		local blocked = false
		for _, b in layout.buildings do
			if CityLayout.Contains(b.footprint, x, z) then
				blocked = true
			end
		end
		for _, h in layout.houses do
			if math.abs(h.x + 4 - x) < 36 and math.abs(h.z - z) < 36 then
				blocked = true
			end
		end
		if not blocked then
			local base = origin * CFrame.new(x, sidewalkTop, z)
			if #ModelFactory.PlaceLibraryModel("prop_fire_barrel", parent, base, true) == 0 then
				for _, spec in CityParts.PropFallback("fire_barrel") do
					makePart(spec, parent, base)
				end
			end
			local top = makePart({ name = "FireTop", shape = "Block", size = { x = 1.6, y = 0.2, z = 1.6 }, pos = { x = 0, y = 3.1, z = 0 }, material = "SmoothPlastic", color = "#1A1410", transparency = 1, canCollide = false }, parent, base)
			local fire = Instance.new("Fire")
			fire.Size = 4
			fire.Heat = 7
			fire.Color = hex("#FF8A2B")
			fire.SecondaryColor = hex("#FF3B1F")
			fire.Parent = top
			local light = Instance.new("PointLight")
			light.Color = hex("#FF9A4A")
			light.Range = 16
			light.Brightness = 1.6
			light.Shadows = false
			light.Parent = top
			CollectionService:AddTag(light, "FireLight")
		end
	end
end

-- Build ---------------------------------------------------------------------------------------------------

-- Printed at every build: tells whether Studio runs the latest code (Rojo connected).
MapBuilder.VERSION = "2026-10-01 polyhaven"

function MapBuilder.Build(): (Instance, Instance)
	local started = os.clock()
	print(("[MapBuilder] version %s"):format(MapBuilder.VERSION))
	local textures = setupTextureVariants()
	print(("[MapBuilder] %d textures ready"):format(textures))
	local layout = CityLayout.Build(City)
	local origin = CFrame.new(City.Origin.x, City.Origin.y, City.Origin.z)
	local sidewalkTop = City.Grid.SidewalkHeight
	local rng = Random.new(City.Seed)

	for _, name in { "City", "Hideouts" } do
		local old = workspace:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		pcall(function()
			baseplate.Name = "Baseplate_backup"
			baseplate.Parent = ServerStorage -- it would fill the basements; kept just in case
		end)
	end

	local city = Instance.new("Model")
	city.Name = "City"
	local ground = folder("Ground", city)
	local buildings = folder("Buildings", city)
	local props = folder("Props", city)
	local specials = folder("Specials", city)
	local ambience = folder("Ambience", city)
	local pois = folder("POI", city)
	local spawns = folder("CustomerSpawns", city)

	for _, s in layout.slabs do
		makePart(CityParts.Slab(s), ground, origin)
	end
	for _, b in layout.buildings do
		buildBuilding(b, buildings, origin, sidewalkTop, rng)
	end
	local poles: { [string]: Model } = {}
	for _, p in layout.props do
		local model = buildProp(p, props, origin, sidewalkTop, rng)
		if p.kind == "utility_pole" then
			poles[p.x .. "," .. p.z] = model
		end
	end
	buildWires(layout, poles, origin, sidewalkTop)
	for _, s in layout.specials do
		buildSpecial(s, specials, origin, sidewalkTop, rng)
	end
	buildAmbience(layout, ambience, origin, sidewalkTop, rng)

	for _, poi in layout.pois do
		makePart({ name = poi.name, shape = "Block", size = { x = 2, y = 2, z = 2 }, pos = { x = poi.x, y = sidewalkTop + 1, z = poi.z }, material = "SmoothPlastic", color = "#FFFFFF", transparency = 1, canCollide = false }, pois, origin)
		if poi.name == "Spawn" then
			local spawn = Instance.new("SpawnLocation")
			spawn.Name = "CitySpawn"
			spawn.Anchored = true
			spawn.Size = Vector3.new(10, 0.4, 10)
			spawn.CFrame = origin * CFrame.new(poi.x, sidewalkTop + 0.2, poi.z)
			spawn.Material = Enum.Material.Cobblestone
			spawn.Color = hex("#5A5652")
			spawn.Neutral = true
			spawn.Duration = 0
			spawn.Parent = city
		end
	end
	for _, s in layout.customerSpawns do
		makePart({ name = "Spawn", shape = "Block", size = { x = 2, y = 1, z = 2 }, pos = { x = s.x, y = sidewalkTop + 0.5, z = s.z }, material = "SmoothPlastic", color = "#000000", transparency = 1, canCollide = false }, spawns, origin)
	end

	-- invisible walls around the playable area (city + outside ground + sea)
	local B = City.Boundary
	local half = layout.half
	local west, east = -half - B.OuterGround, half + B.SeaWidth
	local north, south = -half - B.OuterGround, half + B.OuterGround
	local walls = folder("Boundary", city)
	local function wall(x0: number, z0: number, x1: number, z1: number)
		makePart({ name = "Wall", shape = "Block", size = { x = math.max(2, x1 - x0), y = B.WallHeight, z = math.max(2, z1 - z0) }, pos = { x = (x0 + x1) / 2, y = B.WallHeight / 2 - 30, z = (z0 + z1) / 2 }, material = "SmoothPlastic", color = "#000000", transparency = 1 }, walls, origin)
	end
	wall(west, north, east, north)
	wall(west, south, east, south)
	wall(west, north, west, south)
	wall(east, north, east, south)

	local hideouts = Instance.new("Folder")
	hideouts.Name = "Hideouts"
	for _, h in layout.houses do
		buildHouse(h, hideouts, origin, sidewalkTop, rng)
	end

	local variants = applyMaterialVariants({ city, hideouts }, rng)
	if variants > 0 then
		print(("[MapBuilder] custom materials applied to %d parts"):format(variants))
	end

	city.Parent = workspace
	hideouts.Parent = workspace

	-- streaming: phones only load what is around the player (can only be changed in edit mode)
	pcall(function()
		workspace.StreamingEnabled = true
		workspace.StreamingTargetRadius = City.Streaming.TargetRadius
		workspace.StreamingMinRadius = City.Streaming.MinRadius
	end)

	local count = 0
	for _, d in city:GetDescendants() do
		if d:IsA("BasePart") then
			count += 1
		end
	end
	for _, d in hideouts:GetDescendants() do
		if d:IsA("BasePart") then
			count += 1
		end
	end
	print(("[MapBuilder] city built in %.1fs: %d buildings, %d houses, %d props, %d parts"):format(os.clock() - started, #layout.buildings, #layout.houses, #layout.props, count))
	return city, hideouts
end

return MapBuilder

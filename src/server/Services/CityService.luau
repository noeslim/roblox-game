--!strict
-- Generates the city block: street, sidewalks, 8 plots with owner signs, back walls, buildings with
-- lit windows and neon signs, street lights. All layout values come from Config/World.
-- If workspace already has a "City", nothing is generated (your own map), but workspace.Hideouts
-- must then exist with Plot_N folders, each holding a "Floor" part (see PlotUtil).
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = require(Shared.Config.World)
local Economy = require(Shared.Config.Economy)

local CityService = {}

local NIGHT_LIGHT_TAG = "NightLight" -- lights switched on at night
local NIGHT_GLOW_TAG = "NightGlow" -- parts that become Neon at night
local FLICKER_TAG = "FlickerSign" -- neon signs that flicker (client AmbienceController)
local FIRE_LIGHT_TAG = "FireLight" -- lights that flicker like fire
local WET_TAG = "WetSurface" -- ground that shines when it rains

local built = false

local function hex(s: string): Color3
	return Color3.fromHex(s)
end

local function part(props: {
	name: string?,
	size: Vector3,
	cframe: CFrame,
	color: string,
	material: Enum.Material?,
	shape: Enum.PartType?,
	transparency: number?,
	canCollide: boolean?,
	parent: Instance,
}): Part
	local p = Instance.new("Part")
	p.Name = props.name or "Part"
	p.Anchored = true
	p.Size = props.size
	p.CFrame = props.cframe
	p.Color = hex(props.color)
	p.Material = props.material or Enum.Material.SmoothPlastic
	p.Shape = props.shape or Enum.PartType.Block
	p.Transparency = props.transparency or 0
	p.CanCollide = if props.canCollide == nil then true else props.canCollide
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = props.parent
	return p
end

local function folder(name: string, parent: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function surfaceText(target: BasePart, face: Enum.NormalId, text: string, color: string, font: Enum.Font): TextLabel
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
	return label
end

local function pick<T>(rng: Random, list: { T }): T
	return list[rng:NextInteger(1, #list)]
end

local function buildStreetLight(parent: Instance, x: number, z: number, groundY: number, towardStreet: number)
	local cfg = World.Colors
	part({
		name = "Pole",
		size = Vector3.new(12, 0.6, 0.6),
		cframe = CFrame.new(x, groundY + 6, z) * CFrame.Angles(0, 0, math.rad(90)),
		color = "#2B2B30",
		material = Enum.Material.Metal,
		shape = Enum.PartType.Cylinder,
		parent = parent,
	})
	part({
		name = "Arm",
		size = Vector3.new(0.4, 0.4, 4),
		cframe = CFrame.new(x, groundY + 11.8, z + towardStreet * 2),
		color = "#2B2B30",
		material = Enum.Material.Metal,
		parent = parent,
	})
	local head = part({
		name = "Lamp",
		size = Vector3.new(1.8, 0.5, 1.2),
		cframe = CFrame.new(x, groundY + 11.5, z + towardStreet * 3.8),
		color = cfg.StreetLight,
		material = Enum.Material.Neon,
		canCollide = false,
		parent = parent,
	})
	CollectionService:AddTag(head, NIGHT_GLOW_TAG)
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Bottom
	light.Angle = World.StreetLight.Angle
	light.Range = World.StreetLight.Range
	light.Brightness = World.StreetLight.Brightness
	light.Color = hex(World.StreetLight.Color)
	light.Shadows = false
	light.Parent = head
	CollectionService:AddTag(light, NIGHT_LIGHT_TAG)
end

local function buildBuildings(parent: Instance, rng: Random, side: number, groundY: number, startX: number, endX: number, zNear: number)
	-- zNear: z of the building face closest to the street; buildings extend away from the street
	local away = side
	local x = startX
	while x < endX - 4 do
		local w = math.min(rng:NextInteger(World.BuildingWidthMin, World.BuildingWidthMax), endX - x)
		local h = rng:NextInteger(World.BuildingHeightMin, World.BuildingHeightMax)
		local cx = x + w / 2
		local cz = zNear + away * World.BuildingDepth / 2
		local body = part({
			name = "Building",
			size = Vector3.new(w - 1, h, World.BuildingDepth),
			cframe = CFrame.new(cx, groundY + h / 2, cz),
			color = pick(rng, World.Colors.Buildings),
			material = if rng:NextNumber() < 0.5 then Enum.Material.Brick else Enum.Material.Concrete,
			parent = parent,
		})
		body.CastShadow = false

		-- lit windows on the street side, above the back wall
		local faceZ = zNear - away * 0.15
		local y = groundY + World.BackWallHeight + 4
		while y < groundY + h - 4 do
			local wx = x + 3
			while wx < x + w - 3 do
				if rng:NextNumber() < World.WindowLitChance then
					local win = part({
						name = "Window",
						size = Vector3.new(2.5, 3.5, 0.2),
						cframe = CFrame.new(wx + 1.25, y, faceZ),
						color = pick(rng, World.Colors.Windows),
						material = Enum.Material.SmoothPlastic,
						canCollide = false,
						parent = parent,
					})
					win.CastShadow = false
					CollectionService:AddTag(win, NIGHT_GLOW_TAG)
				end
				wx += 5
			end
			y += 7
		end

		-- rooftop neon sign facing the street
		if rng:NextNumber() < World.SignChance and w > 12 then
			local signColor = pick(rng, World.Colors.Signs)
			local pos = Vector3.new(cx, groundY + h + 3, zNear + away * 1)
			local board = part({
				name = "Sign",
				size = Vector3.new(math.min(w - 4, 18), 5, 0.6),
				cframe = CFrame.lookAt(pos, pos - Vector3.new(0, 0, away)),
				color = World.Colors.SignBoard,
				parent = parent,
			})
			surfaceText(board, Enum.NormalId.Front, pick(rng, World.Signs), signColor, Enum.Font.Arcade)
			if rng:NextNumber() < World.Props.FlickerSignChance then
				CollectionService:AddTag(board, FLICKER_TAG)
			end
			local light = Instance.new("PointLight")
			light.Color = hex(signColor)
			light.Range = 18
			light.Brightness = 1.2
			light.Shadows = false
			light.Parent = board
			CollectionService:AddTag(light, NIGHT_LIGHT_TAG)
		end
		x += w
	end
end

-- Street clutter -----------------------------------------------------------------------

local function trashBag(parent: Instance, rng: Random, pos: Vector3)
	local bag = part({
		name = "TrashBag",
		size = Vector3.new(2, 1.6, 2),
		cframe = CFrame.new(pos + Vector3.new(0, 0.8, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.2, 0.2)),
		color = "#141418",
		material = Enum.Material.SmoothPlastic,
		parent = parent,
	})
	bag.Reflectance = 0.08
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = bag
end

local function dumpster(parent: Instance, pos: Vector3, facing: number)
	local cf = CFrame.new(pos) * CFrame.Angles(0, facing, 0)
	part({ name = "Dumpster", size = Vector3.new(6, 3.4, 3.2), cframe = cf * CFrame.new(0, 1.9, 0), color = "#2F4F3A", material = Enum.Material.Metal, parent = parent })
	part({ name = "DumpsterLid", size = Vector3.new(6.2, 0.3, 3.4), cframe = cf * CFrame.new(0, 3.75, 0.1) * CFrame.Angles(math.rad(-8), 0, 0), color = "#26402F", material = Enum.Material.Metal, parent = parent })
	part({ name = "DumpsterRim", size = Vector3.new(6.3, 0.4, 0.4), cframe = cf * CFrame.new(0, 2.6, 1.7), color = "#1E2E24", material = Enum.Material.Metal, parent = parent })
end

local function fireBarrel(parent: Instance, pos: Vector3)
	local barrel = part({
		name = "FireBarrel",
		size = Vector3.new(3, 2.2, 2.2),
		cframe = CFrame.new(pos + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		color = "#5A3A28",
		material = Enum.Material.CorrodedMetal,
		shape = Enum.PartType.Cylinder,
		parent = parent,
	})
	local top = part({
		name = "FireTop",
		size = Vector3.new(1.6, 0.2, 1.6),
		cframe = CFrame.new(pos + Vector3.new(0, 3.1, 0)),
		color = "#1A1410",
		canCollide = false,
		parent = parent,
	})
	top.Transparency = 1
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
	light.Shadows = true
	light.Parent = top
	CollectionService:AddTag(light, FIRE_LIGHT_TAG)
	barrel.CastShadow = true
end

local function steamVent(parent: Instance, pos: Vector3)
	local lid = part({
		name = "Manhole",
		size = Vector3.new(0.1, 3, 3),
		cframe = CFrame.new(pos + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		color = "#202024",
		material = Enum.Material.DiamondPlate,
		shape = Enum.PartType.Cylinder,
		canCollide = false,
		parent = parent,
	})
	lid.CanQuery = false
	local smoke = Instance.new("Smoke")
	smoke.Color = hex("#C8C8D0")
	smoke.Opacity = 0.12
	smoke.RiseVelocity = 5
	smoke.Size = 4
	smoke.TimeScale = 0.6
	smoke.Parent = lid
end

local function puddle(parent: Instance, rng: Random, pos: Vector3)
	local d = rng:NextNumber(3, 8)
	local p = part({
		name = "Puddle",
		size = Vector3.new(0.04, d, d * rng:NextNumber(0.5, 0.9)),
		cframe = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi), math.rad(90)),
		color = "#15171F",
		material = Enum.Material.Glass,
		shape = Enum.PartType.Cylinder,
		transparency = 0.25,
		canCollide = false,
		parent = parent,
	})
	p.Reflectance = 0.35
	p.CanQuery = false
	p.CastShadow = false
end

-- Clutter in the gaps between plots, steam and puddles on the street.
local function buildClutter(parent: Instance, rng: Random, O: Vector3, streetY: number, topY: number, L: number, rowLength: number, stride: number)
	local B = Economy.Building
	local halfStreet = World.StreetWidth / 2
	-- spots between plots (and at both ends of each row), on both sides
	local spots: { { x: number, side: number } } = {}
	for _, side in { -1, 1 } do
		for i = 0, World.PlotsPerSide do
			local x = if i == 0
				then O.X - rowLength / 2 - World.PlotGap / 2
				elseif i == World.PlotsPerSide then O.X + rowLength / 2 + World.PlotGap / 2
				else O.X - rowLength / 2 + i * stride - World.PlotGap / 2
			table.insert(spots, { x = x, side = side })
		end
	end
	local function spotPos(spot: { x: number, side: number }, depth: number, jitter: number): Vector3
		local z = O.Z + spot.side * (halfStreet + World.SidewalkWidth + depth)
		return Vector3.new(spot.x + rng:NextNumber(-jitter, jitter), topY, z)
	end
	for i = 1, math.min(World.Props.Dumpsters, #spots) do
		local spot = spots[rng:NextInteger(1, #spots)]
		dumpster(parent, spotPos(spot, B.PlotSizeZ - 4, 0.5), if spot.side == -1 then 0 else math.pi)
	end
	for i = 1, World.Props.FireBarrels do
		fireBarrel(parent, spotPos(spots[rng:NextInteger(1, #spots)], rng:NextNumber(8, B.PlotSizeZ - 12), 1.5))
	end
	for i = 1, World.Props.TrashBags do
		trashBag(parent, rng, spotPos(spots[rng:NextInteger(1, #spots)], rng:NextNumber(4, B.PlotSizeZ - 2), 3))
	end
	for i = 1, World.Props.SteamVents do
		steamVent(parent, Vector3.new(O.X + rng:NextNumber(-L / 2 + 20, L / 2 - 20), streetY, O.Z + rng:NextNumber(-halfStreet + 4, halfStreet - 4)))
	end
	for i = 1, World.Props.Puddles do
		puddle(parent, rng, Vector3.new(O.X + rng:NextNumber(-L / 2 + 10, L / 2 - 10), streetY + 0.02, O.Z + rng:NextNumber(-halfStreet + 2, halfStreet - 2)))
	end
end

local function buildPlot(hideouts: Instance, index: number, origin: CFrame)
	local B = Economy.Building
	local plot = folder("Plot_" .. index, hideouts)
	plot:SetAttribute("Index", index)
	plot:SetAttribute("SizeX", B.PlotSizeX)
	plot:SetAttribute("SizeZ", B.PlotSizeZ)
	plot:SetAttribute("MaxHeight", B.PlotMaxHeight)
	plot:SetAttribute("OwnerUserId", 0)

	part({
		name = "Floor",
		size = Vector3.new(B.PlotSizeX, 1, B.PlotSizeZ),
		cframe = origin * CFrame.new(0, -0.5, 0),
		color = World.Colors.PlotFloor,
		material = Enum.Material.Concrete,
		parent = plot,
	})

	-- yellow lines showing the building area
	local edges = folder("Edges", plot)
	local hx, hz = B.PlotSizeX / 2, B.PlotSizeZ / 2
	for _, e in {
		{ Vector3.new(B.PlotSizeX, 0.1, 0.3), Vector3.new(0, 0.05, hz - 0.15) },
		{ Vector3.new(B.PlotSizeX, 0.1, 0.3), Vector3.new(0, 0.05, -hz + 0.15) },
		{ Vector3.new(0.3, 0.1, B.PlotSizeZ), Vector3.new(hx - 0.15, 0.05, 0) },
		{ Vector3.new(0.3, 0.1, B.PlotSizeZ), Vector3.new(-hx + 0.15, 0.05, 0) },
	} do
		local p = part({
			size = e[1],
			cframe = origin * CFrame.new(e[2]),
			color = World.Colors.PlotEdge,
			transparency = 0.4,
			canCollide = false,
			parent = edges,
		})
		p.CanQuery = false
	end

	-- owner sign on the sidewalk, readable from both sides
	local signFolder = folder("Sign", plot)
	local signX, signZ = hx - 4, hz + 1.5
	part({
		name = "Post",
		size = Vector3.new(0.4, 7, 0.4),
		cframe = origin * CFrame.new(signX, 3.5, signZ),
		color = "#2B2B30",
		material = Enum.Material.Metal,
		parent = signFolder,
	})
	local board = part({
		name = "Board",
		size = Vector3.new(8, 2.5, 0.4),
		cframe = origin * CFrame.new(signX, 7, signZ),
		color = World.Colors.SignBoard,
		parent = signFolder,
	})
	surfaceText(board, Enum.NormalId.Front, "FOR RENT", "#FFB020", Enum.Font.GothamBlack)
	surfaceText(board, Enum.NormalId.Back, "FOR RENT", "#FFB020", Enum.Font.GothamBlack)

	folder("Objects", plot)
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
			p.Material = if night then Enum.Material.Neon else Enum.Material.SmoothPlastic
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
	-- only one Atmosphere can be active: the Baseplate template ships a brownish one, set it aside
	-- for this play session (nothing is saved, your place file keeps it)
	for _, child in Lighting:GetChildren() do
		if child:IsA("Atmosphere") and child.Name ~= "BM_Atmosphere" then
			child.Parent = nil
		end
	end
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

-- Builds the city once. Returns workspace.Hideouts.
function CityService.EnsureBuilt(): Instance
	if built then
		return workspace:WaitForChild("Hideouts")
	end
	built = true

	if workspace:FindFirstChild("City") then
		print("[CityService] using the existing workspace.City")
		return workspace:WaitForChild("Hideouts")
	end

	local B = Economy.Building
	local rng = Random.new(World.Seed)
	local O = Vector3.new(World.Origin.x, World.Origin.y, World.Origin.z)
	local streetY = O.Y + 0.1
	local topY = streetY + World.SidewalkHeight -- sidewalks and plots
	local stride = B.PlotSizeX + World.PlotGap
	local rowLength = World.PlotsPerSide * stride - World.PlotGap
	local L = rowLength + 2 * World.StreetEndPadding
	local halfStreet = World.StreetWidth / 2

	local city = Instance.new("Model")
	city.Name = "City"
	local ground = folder("Ground", city)
	local lights = folder("StreetLights", city)
	local buildings = folder("Buildings", city)
	local spawns = folder("CustomerSpawns", city)
	local clutter = folder("Clutter", city)

	part({
		name = "Street",
		size = Vector3.new(L, 1, World.StreetWidth),
		cframe = CFrame.new(O.X, streetY - 0.5, O.Z),
		color = World.Colors.Asphalt,
		material = Enum.Material.Asphalt,
		parent = ground,
	})
	local dx = -L / 2 + 6
	while dx < L / 2 - 6 do
		local mark = part({
			name = "LaneMark",
			size = Vector3.new(6, 0.05, 0.4),
			cframe = CFrame.new(O.X + dx, streetY + 0.025, O.Z),
			color = World.Colors.LaneMark,
			canCollide = false,
			parent = ground,
		})
		mark.CanQuery = false
		dx += 12
	end

	local hideouts = workspace:FindFirstChild("Hideouts") or folder("Hideouts", workspace)
	local plotIndex = 0

	for _, side in { -1, 1 } do
		-- side -1 = north (negative z), +1 = south. `toward` points from this side to the street.
		local toward = -side
		local sidewalkZ = O.Z + side * (halfStreet + World.SidewalkWidth / 2)
		local plotZ = O.Z + side * (halfStreet + World.SidewalkWidth + B.PlotSizeZ / 2)
		local wallZ = O.Z + side * (halfStreet + World.SidewalkWidth + B.PlotSizeZ + 1)

		part({
			name = "Sidewalk",
			size = Vector3.new(L, 1, World.SidewalkWidth),
			cframe = CFrame.new(O.X, topY - 0.5, sidewalkZ),
			color = World.Colors.Sidewalk,
			material = Enum.Material.Concrete,
			parent = ground,
		})
		part({
			name = "Lot",
			size = Vector3.new(L, 1, B.PlotSizeZ),
			cframe = CFrame.new(O.X, topY - 0.55, plotZ),
			color = World.Colors.Lot,
			material = Enum.Material.Asphalt,
			parent = ground,
		})
		part({
			name = "BackWall",
			size = Vector3.new(L, World.BackWallHeight, 2),
			cframe = CFrame.new(O.X, topY + World.BackWallHeight / 2, wallZ),
			color = World.Colors.BackWall,
			material = Enum.Material.Brick,
			parent = ground,
		})

		for i = 0, World.PlotsPerSide - 1 do
			plotIndex += 1
			local px = O.X - rowLength / 2 + B.PlotSizeX / 2 + i * stride
			-- plot local +Z must point to the street
			local rotation = if side == -1 then CFrame.identity else CFrame.Angles(0, math.pi, 0)
			buildPlot(hideouts, plotIndex, CFrame.new(px, topY, plotZ) * rotation)
		end

		local lx = -L / 2 + 10
		while lx < L / 2 - 5 do
			buildStreetLight(lights, O.X + lx, O.Z + side * (halfStreet + 1), topY, toward)
			lx += World.StreetLightSpacing
		end

		buildBuildings(buildings, rng, side, topY, O.X - L / 2, O.X + L / 2, wallZ + side * 1)

		for _, endSign in { -1, 1 } do
			local s = part({
				name = "Spawn",
				size = Vector3.new(2, 1, 2),
				cframe = CFrame.new(O.X + endSign * (L / 2 - 4), topY + 0.5, sidewalkZ),
				color = "#000000",
				transparency = 1,
				canCollide = false,
				parent = spawns,
			})
			s.CanQuery = false
			s:SetAttribute("Side", side)
		end
	end

	buildClutter(clutter, rng, O, streetY, topY, L, rowLength, stride)
	for _, p in ground:GetChildren() do
		if p.Name == "Street" or p.Name == "Sidewalk" or p.Name == "Lot" then
			CollectionService:AddTag(p, WET_TAG)
		end
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "CitySpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 0.4, 8)
	spawn.CFrame = CFrame.new(O.X, streetY + 0.2, O.Z)
	spawn.Color = hex("#23262E")
	spawn.Material = Enum.Material.Metal
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = city

	city.Parent = workspace
	setupLighting()
	applyPhase()
	print(("[CityService] city built: %d plots"):format(plotIndex))
	return hideouts
end

function CityService:Start()
	CityService.EnsureBuilt()
	ReplicatedStorage:GetAttributeChangedSignal("Phase"):Connect(applyPhase)
	applyPhase()
end

return CityService

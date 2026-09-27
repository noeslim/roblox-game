--!strict
-- Procedural car models (Config/Vehicles). Front = -Z, the PrimaryPart "Body" is the chassis at the
-- ride height. Uses ReplicatedStorage.Assets.Vehicles.<id> instead when the authors provide one.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VehicleFactory = {}

local function part(model: Model, root: BasePart?, name: string, size: Vector3, offset: CFrame, color: string, material: Enum.Material, collide: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = Color3.fromHex(color)
	p.Material = material
	p.CanCollide = collide == true
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if root then
		p.CFrame = root.CFrame * offset
		p.Massless = true
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = p
		weld.Parent = p
	end
	p.Parent = model
	return p
end

local function asset(id: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Vehicles")
	local m = folder and folder:FindFirstChild(id)
	if m and m:IsA("Model") and m.PrimaryPart and m:FindFirstChildWhichIsA("VehicleSeat", true) then
		return m:Clone()
	end
	return nil
end

-- rideHeight: height of the body's center above the ground (the wheels touch the ground)
function VehicleFactory.Build(def: any, rideHeight: number): Model
	local custom = asset(def.id)
	if custom then
		custom.Name = def.id
		return custom
	end
	local model = Instance.new("Model")
	model.Name = def.id
	local W, H, L = def.size.x, def.size.y, def.size.z
	local look = def.look
	local body = part(model, nil, "Body", Vector3.new(W, H, L), CFrame.identity, look.body, Enum.Material.SmoothPlastic, true)
	model.PrimaryPart = body

	-- cabin: tinted glass under a roof, set back a little
	local cabinH, cabinL = H * 0.95 + 0.6, L * 0.46
	local cabinZ = L * 0.06
	part(model, body, "Glass", Vector3.new(W - 0.5, cabinH, cabinL), CFrame.new(0, H / 2 + cabinH / 2, cabinZ), look.glass, Enum.Material.Glass).Transparency = 0.35
	part(model, body, "Roof", Vector3.new(W - 0.4, 0.2, cabinL * 0.9), CFrame.new(0, H / 2 + cabinH + 0.1, cabinZ + 0.2), look.cabin, Enum.Material.SmoothPlastic)
	part(model, body, "Bumper", Vector3.new(W + 0.1, 0.5, 0.4), CFrame.new(0, -H / 2 + 0.35, -L / 2 - 0.1), "#1A1A1E", Enum.Material.Metal)
	part(model, body, "RearBumper", Vector3.new(W + 0.1, 0.5, 0.4), CFrame.new(0, -H / 2 + 0.35, L / 2 + 0.1), "#1A1A1E", Enum.Material.Metal)

	-- wheels (visual only: the car hovers at its ride height)
	local wheelY = -rideHeight + 1.05 -- wheel radius 1.05
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local w = part(model, body, "Wheel", Vector3.new(0.8, 2.1, 2.1), CFrame.new(sx * (W / 2 - 0.25), wheelY, sz * L * 0.32), "#16161A", Enum.Material.SmoothPlastic)
			w.Shape = Enum.PartType.Cylinder
		end
	end

	-- lights
	for _, sx in { -1, 1 } do
		local head = part(model, body, "Headlight", Vector3.new(1.1, 0.35, 0.1), CFrame.new(sx * (W / 2 - 0.9), 0.15, -L / 2 - 0.02), "#FFF4D6", Enum.Material.Neon)
		if sx == 1 then
			local beam = Instance.new("SpotLight")
			beam.Range = 45
			beam.Angle = 55
			beam.Brightness = 3
			beam.Color = Color3.fromHex("#FFF0D0")
			beam.Face = Enum.NormalId.Front
			beam.Parent = head
		end
		part(model, body, "Taillight", Vector3.new(1.1, 0.3, 0.1), CFrame.new(sx * (W / 2 - 0.9), 0.15, L / 2 + 0.02), "#D01818", Enum.Material.Neon)
	end
	if look.underglow then
		local glow = part(model, body, "Underglow", Vector3.new(W - 1, 0.1, L - 2), CFrame.new(0, -H / 2 - 0.1, 0), look.underglow, Enum.Material.Neon)
		local light = Instance.new("PointLight")
		light.Color = glow.Color
		light.Range = 12
		light.Brightness = 2
		light.Parent = glow
	end

	-- seats: the driver on the left, passengers next and behind
	local seatY = H / 2 + 0.35
	local driver = Instance.new("VehicleSeat")
	driver.Name = "DriveSeat"
	driver.Size = Vector3.new(2, 0.5, 2)
	driver.Transparency = 1
	driver.CanCollide = false
	driver.HeadsUpDisplay = false
	driver.MaxSpeed = 0 -- the built-in drive is not used (VehicleController)
	driver.CFrame = body.CFrame * CFrame.new(-W / 4, seatY, cabinZ)
	driver.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = driver
	weld.Parent = driver
	driver.Parent = model
	local spots = { CFrame.new(W / 4, seatY, cabinZ), CFrame.new(-W / 4, seatY, cabinZ + 2.6), CFrame.new(W / 4, seatY, cabinZ + 2.6) }
	for i = 1, math.min(def.seats, #spots) do
		local seat = Instance.new("Seat")
		seat.Name = "Passenger"
		seat.Size = Vector3.new(2, 0.5, 2)
		seat.Transparency = 1
		seat.CanCollide = false
		seat.Massless = true
		seat.CFrame = body.CFrame * spots[i]
		local w = Instance.new("WeldConstraint")
		w.Part0 = body
		w.Part1 = seat
		w.Parent = seat
		seat.Parent = model
	end
	return model
end

return VehicleFactory

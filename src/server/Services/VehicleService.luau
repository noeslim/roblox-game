--!strict
-- Cars (Config/Vehicles, Logic/Vehicle): buying (saved in the profile), spawning your car next to
-- you or in front of your trap house, one car out per player. The driver's client simulates the
-- car (VehicleController); the server hands it the network ownership and parks (anchors) the car
-- when nobody drives. Players in Config/Vehicles.Settings.FreeFor (and the game's creator) own the
-- best car for free. Remotes: RequestBuyVehicle(id), RequestSpawnVehicle(id), RequestDespawnVehicle().
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Vehicles = require(Shared.Config.Vehicles)
local Messages = require(Shared.Config.Messages)
local Vehicle = require(Shared.Logic.Vehicle)
local VehicleFactory = require(Shared.Visual.VehicleFactory)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local ServerNet = require(script.Parent.Parent.Lib.ServerNet)

local VehicleService = {}

local S = Vehicles.Settings

local cars: { [Player]: Model } = {}
local lastSpawn: { [Player]: number } = {}

local function folder(): Instance
	local f = workspace:FindFirstChild("Vehicles")
	if f == nil then
		f = Instance.new("Folder")
		f.Name = "Vehicles"
		f.Parent = workspace
	end
	return f :: Instance
end

local function despawn(player: Player)
	local car = cars[player]
	cars[player] = nil
	if car then
		car:Destroy()
	end
end

-- Driving: the driver's client simulates; nobody driving = parked (anchored).
local function wireSeat(car: Model, root: BasePart)
	local seat = car:FindFirstChild("DriveSeat", true)
	if seat == nil or not seat:IsA("VehicleSeat") then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "DriveAttachment"
	attachment.Parent = root
	local linear = Instance.new("LinearVelocity")
	linear.Name = "Drive"
	linear.Attachment0 = attachment
	linear.RelativeTo = Enum.ActuatorRelativeTo.World
	linear.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	linear.MaxForce = root.AssemblyMass * S.MaxForce
	linear.Enabled = false
	linear.Parent = root
	local angular = Instance.new("AngularVelocity")
	angular.Name = "Steer"
	angular.Attachment0 = attachment
	angular.RelativeTo = Enum.ActuatorRelativeTo.World
	angular.MaxTorque = math.huge
	angular.Enabled = false
	angular.Parent = root

	-- get in with a prompt (touching the seats does nothing): the owner drives, anyone can ride
	for _, s in car:GetDescendants() do
		if s:IsA("Seat") or s:IsA("VehicleSeat") then
			(s :: BasePart).CanTouch = false
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = if s == seat then "DrivePrompt" else "RidePrompt"
			prompt.ActionText = if s == seat then Messages.Vehicles.Drive else Messages.Vehicles.Ride
			prompt.ObjectText = car.Name
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = 9
			prompt.RequiresLineOfSight = false
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.Parent = s
			s:GetPropertyChangedSignal("Occupant"):Connect(function()
				prompt.Enabled = (s :: any).Occupant == nil
			end)
		end
	end

	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local humanoid = seat.Occupant
		local driver = humanoid and Players:GetPlayerFromCharacter(humanoid.Parent)
		if driver then
			root.Anchored = false
			pcall(function()
				root:SetNetworkOwner(driver)
			end)
		else
			pcall(function()
				root:SetNetworkOwner(nil)
			end)
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
			-- keep it upright where it stopped
			local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
			if look.Magnitude > 0.1 then
				root.CFrame = CFrame.lookAt(root.Position, root.Position + look.Unit)
			end
			root.Anchored = true
		end
	end)
end

local function groundBelow(pos: Vector3, exclude: { Instance }): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	local hit = workspace:Raycast(pos + Vector3.new(0, 8, 0), Vector3.new(0, -40, 0), params)
	return if hit then hit.Position.Y else nil
end

local function isFree(cf: CFrame, size: Vector3, exclude: { Instance }): boolean
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	return #workspace:GetPartBoundsInBox(cf, size, params) == 0
end

-- Where the car appears: beside you when there is room outdoors, else in front of your trap house.
local function spawnCFrame(player: Player, def: any): CFrame?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local exclude: { Instance } = { folder() }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	local box = Vector3.new(def.size.x + 1, def.size.y + 3, def.size.z + 1)
	if root and root:IsA("BasePart") then
		local flat = root.CFrame.LookVector * Vector3.new(1, 0, 1)
		local forward = if flat.Magnitude > 0.1 then flat.Unit else Vector3.new(0, 0, -1)
		local right = forward:Cross(Vector3.yAxis)
		for _, dir in { right, -right, forward, -forward } do
			local at = root.Position + dir * S.SpawnDistance
			local ground = groundBelow(at, exclude)
			-- outdoors: nothing above the spot
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = exclude
			local roof = workspace:Raycast(at + Vector3.new(0, 2, 0), Vector3.new(0, 60, 0), params)
			if ground and roof == nil then
				local cf = CFrame.lookAt(Vector3.new(at.X, ground + S.RideHeight, at.Z), Vector3.new(at.X, ground + S.RideHeight, at.Z) + forward)
				if isFree(cf * CFrame.new(0, 1, 0), box, exclude) then
					return cf
				end
			end
		end
	end
	-- the garage: in front of the trap house door, facing along the street
	local plot = PlotService.GetPlot(player)
	local waypoints = plot and plot:FindFirstChild("Waypoints")
	local door = waypoints and waypoints:FindFirstChild("Door")
	local floor = plot and plot:FindFirstChild("Floor", true)
	if door and door:IsA("BasePart") and floor and floor:IsA("BasePart") then
		local toStreet = floor.CFrame.LookVector * -1 -- plot +Z points to the street
		local at = door.Position + toStreet * S.GarageOffset
		local ground = groundBelow(at, exclude) or (door.Position.Y - 3)
		local pos = Vector3.new(at.X, ground + S.RideHeight, at.Z)
		return CFrame.lookAt(pos, pos + floor.CFrame.RightVector)
	end
	return nil
end

local function owns(player: Player, id: string): boolean
	local data = DataService.GetData(player)
	return data ~= nil and table.find(data.Vehicles, id) ~= nil
end

local function spawnCar(player: Player, id: any): (boolean, any)
	if type(id) ~= "string" then
		return false, "InvalidInput"
	end
	local def = Vehicles.ById[id]
	if def == nil then
		return false, "UnknownVehicle"
	end
	if not owns(player, id) then
		return false, "NotOwned"
	end
	if player:GetAttribute("WarTeam") ~= nil then
		return false, "NoCarsHere"
	end
	local now = os.clock()
	if lastSpawn[player] and now - lastSpawn[player] < S.SpawnCooldown then
		return false, "TooSoon"
	end
	local cf = spawnCFrame(player, def)
	if cf == nil then
		return false, "NoRoom"
	end
	despawn(player)
	lastSpawn[player] = now
	local car = VehicleFactory.Build(def, S.RideHeight)
	local root = car.PrimaryPart :: BasePart
	car:SetAttribute("VehicleId", id)
	car:SetAttribute("OwnerUserId", player.UserId)
	car.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	car:PivotTo(cf)
	for _, d in car:GetDescendants() do
		if d:IsA("BasePart") and d ~= root then
			d.Anchored = false
		end
	end
	root.Anchored = true
	car.Parent = folder()
	wireSeat(car, root)
	cars[player] = car
	return true, nil
end

local function buyCar(player: Player, id: any): (boolean, any)
	if type(id) ~= "string" then
		return false, "InvalidInput"
	end
	local def = Vehicles.ById[id]
	local data = DataService.GetData(player)
	local ledger = DataService.GetLedger(player)
	if def == nil then
		return false, "UnknownVehicle"
	end
	if data == nil or ledger == nil then
		return false, "NotLoaded"
	end
	local ok, err = Vehicle.CanBuy(data.Vehicles, def, data.Level, ledger:GetBalance())
	if not ok then
		return false, err
	end
	local paid, payErr = ledger:Withdraw(def.price, "vehicle:" .. id)
	if not paid then
		return false, payErr
	end
	table.insert(data.Vehicles, id)
	DataService.Sync(player)
	ServerNet.Notify(player, Messages.Vehicles.Bought:format(def.name), "success")
	return true, nil
end

local function onLoaded(player: Player)
	local data = DataService.GetData(player)
	if data == nil then
		return
	end
	if Vehicle.IsFreeFor(player.UserId, player.Name, game.CreatorId, S.FreeFor) and not table.find(data.Vehicles, S.FreeVehicle) then
		table.insert(data.Vehicles, S.FreeVehicle)
		DataService.Sync(player)
		local def = Vehicles.ById[S.FreeVehicle]
		ServerNet.Notify(player, Messages.Vehicles.Gift:format(if def then def.name else S.FreeVehicle), "success")
	end
end

local function onPrompt(prompt: ProximityPrompt, player: Player)
	if prompt.Name ~= "DrivePrompt" and prompt.Name ~= "RidePrompt" then
		return
	end
	local seat = prompt.Parent
	local car = seat and seat:FindFirstAncestorOfClass("Model")
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if car == nil or humanoid == nil or humanoid.Health <= 0 or humanoid.SeatPart ~= nil then
		return
	end
	if prompt.Name == "DrivePrompt" and car:GetAttribute("OwnerUserId") ~= player.UserId then
		return
	end
	if seat and seat:IsA("VehicleSeat") and seat.Occupant == nil then
		seat:Sit(humanoid)
	elseif seat and seat:IsA("Seat") and seat.Occupant == nil then
		seat:Sit(humanoid)
	end
end

function VehicleService:Start()
	game:GetService("ProximityPromptService").PromptTriggered:Connect(onPrompt)
	ServerNet.Handle("RequestBuyVehicle", buyCar)
	ServerNet.Handle("RequestSpawnVehicle", spawnCar)
	ServerNet.Handle("RequestDespawnVehicle", function(player: Player)
		despawn(player)
		return true, nil
	end)
	DataService.OnPlayerLoaded(onLoaded)
	Players.PlayerRemoving:Connect(function(player)
		despawn(player)
		lastSpawn[player] = nil
	end)
	-- Studio only: game.Players.NAME:SetAttribute("DebugGiveVehicle", "nightrider") (or "all")
	if RunService:IsStudio() then
		local function watch(player: Player)
			player:GetAttributeChangedSignal("DebugGiveVehicle"):Connect(function()
				local id = player:GetAttribute("DebugGiveVehicle")
				local data = DataService.GetData(player)
				if type(id) ~= "string" or data == nil then
					return
				end
				player:SetAttribute("DebugGiveVehicle", nil)
				for _, def in Vehicles.List do
					if (id == "all" or id == def.id) and not table.find(data.Vehicles, def.id) then
						table.insert(data.Vehicles, def.id)
					end
				end
				DataService.Sync(player)
			end)
		end
		Players.PlayerAdded:Connect(watch)
		for _, p in Players:GetPlayers() do
			watch(p)
		end
	end
end

return VehicleService

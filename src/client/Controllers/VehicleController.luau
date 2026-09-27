--!strict
-- Cars on the client: drives the car you sit in as its driver (arcade handling, Logic/Vehicle,
-- the server gave this client the car's physics), shows the speed, and the garage (CAR button):
-- buy cars, bring yours out, put it away. Settings: Config/Vehicles.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Vehicles = require(Shared.Config.Vehicles)
local Messages = require(Shared.Config.Messages)
local Vehicle = require(Shared.Logic.Vehicle)
local Net = require(Shared.Net)
local UI = require(script.Parent.Parent.UI)
local Notify = require(script.Parent.Parent.Notify)
local State = require(script.Parent.Parent.State)

local VehicleController = {}

local S = Vehicles.Settings
local V = Messages.Vehicles
local player = Players.LocalPlayer

-- Driving -------------------------------------------------------------------------------

local speed = 0
local driving: Model? = nil
local drivingFor = 0

local function stopDriving()
	local car = driving
	driving = nil
	speed = 0
	local root = car and car.PrimaryPart
	if root then
		local linear = root:FindFirstChild("Drive")
		local angular = root:FindFirstChild("Steer")
		if linear and linear:IsA("LinearVelocity") then
			linear.Enabled = false
		end
		if angular and angular:IsA("AngularVelocity") then
			angular.Enabled = false
		end
	end
end

local function groundY(root: BasePart, car: Model): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { car }
	if player.Character then
		table.insert(exclude, player.Character)
	end
	params.FilterDescendantsInstances = exclude
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -(S.RideHeight + 6), 0), params)
	return if hit then hit.Position.Y else nil
end

local function drive(dt: number, seat: VehicleSeat)
	local car = seat:FindFirstAncestorOfClass("Model")
	local root = car and car.PrimaryPart
	local def = car and Vehicles.ById[car:GetAttribute("VehicleId") :: string]
	if car == nil or root == nil or def == nil then
		return
	end
	if driving ~= car then
		stopDriving()
		driving = car
		drivingFor = 0
	end
	drivingFor += dt
	local linear = root:FindFirstChild("Drive")
	local angular = root:FindFirstChild("Steer")
	if root.Anchored or not (linear and linear:IsA("LinearVelocity")) or not (angular and angular:IsA("AngularVelocity")) then
		return -- the server has not handed the car over yet
	end
	linear.Enabled = true
	angular.Enabled = true
	local yaw
	speed, yaw = Vehicle.Step(speed, { throttle = seat.ThrottleFloat, steer = seat.SteerFloat }, dt, def, S)
	-- hit a wall: the car really goes slower than asked
	local actual = root.AssemblyLinearVelocity:Dot(root.CFrame.LookVector)
	if drivingFor > 0.5 and math.abs(actual) + 6 < math.abs(speed) then
		speed = actual
	end
	local flat = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	local forward = if flat.Magnitude > 0.1 then flat.Unit else Vector3.new(0, 0, -1)
	local vy = Vehicle.Hover(root.Position.Y, root.AssemblyLinearVelocity.Y, groundY(root, car), dt, S)
	linear.VectorVelocity = forward * speed + Vector3.new(0, vy, 0)
	angular.AngularVelocity = Vector3.new(0, yaw, 0)
end

-- Garage ---------------------------------------------------------------------------------

function VehicleController:Start()
	local gui = UI.Screen("Garage", 12)
	local speedo = UI.Label({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24), Size = UDim2.fromOffset(200, 36), TextSize = 26, Font = UI.Theme.FontBlack, TextStrokeTransparency = 0.4, Visible = false, Parent = gui })

	local panel = UI.Panel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(460, 380), Visible = false, Parent = gui })
	UI.Padding(panel, 12)
	UI.Label({ Size = UDim2.new(1, -50, 0, 26), Text = V.Title, Font = UI.Theme.FontBlack, TextSize = 22, TextColor3 = UI.Theme.Accent, TextXAlignment = Enum.TextXAlignment.Left, Parent = panel })
	UI.Label({ Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 0, 16), Text = V.Note, TextSize = 12, TextColor3 = UI.Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, Parent = panel })
	UI.Button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(36, 30), Text = "X", BackgroundColor3 = UI.Theme.Danger, Parent = panel }, function()
		panel.Visible = false
	end)
	local list = UI.Scrolling({ Position = UDim2.fromOffset(0, 52), Size = UDim2.new(1, 0, 1, -96), Parent = panel })
	UI.List(list, 6)
	UI.Button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.new(1, 0, 0, 36), Text = V.Park, BackgroundColor3 = UI.Theme.PanelLight, Parent = panel }, function()
		Net.Invoke("RequestDespawnVehicle")
	end)

	local function render()
		UI.ClearChildren(list)
		local snapshot = State.Get()
		local owned = if snapshot and type(snapshot.Vehicles) == "table" then snapshot.Vehicles else {}
		local level = tonumber(player:GetAttribute("Level")) or 1
		for i, def in Vehicles.List do
			local has = table.find(owned, def.id) ~= nil
			local row = UI.Panel({ LayoutOrder = i, Size = UDim2.new(1, -8, 0, 54), BackgroundColor3 = UI.Theme.PanelLight, Parent = list })
			local swatch = UI.new("Frame", { Position = UDim2.fromOffset(8, 12), Size = UDim2.fromOffset(30, 30), BackgroundColor3 = Color3.fromHex(def.look.underglow or def.look.body), Parent = row })
			UI.Corner(swatch, 6)
			UI.Label({ Position = UDim2.fromOffset(48, 6), Size = UDim2.new(1, -170, 0, 20), Text = def.name, TextSize = 16, Font = UI.Theme.FontBlack, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
			UI.Label({ Position = UDim2.fromOffset(48, 28), Size = UDim2.new(1, -170, 0, 16), Text = V.Stats:format(def.maxSpeed), TextSize = 12, TextColor3 = UI.Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
			local locked = not has and level < def.level
			UI.Button({
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
				Size = UDim2.fromOffset(110, 36),
				Text = if has then V.Spawn elseif locked then V.Level:format(def.level) else V.Buy:format(UI.Money(def.price)),
				TextSize = 13,
				BackgroundColor3 = if has then UI.Theme.Accent elseif locked then UI.Theme.Disabled else UI.Theme.Money,
				TextColor3 = if has or locked then UI.Theme.Text else UI.Theme.Background,
				Parent = row,
			}, function()
				if locked then
					return
				end
				local ok, err = Net.Invoke(if has then "RequestSpawnVehicle" else "RequestBuyVehicle", def.id)
				if not ok then
					Notify.Show(Messages.ForError(err), "error")
				elseif has then
					panel.Visible = false
				end
			end)
		end
	end

	UI.Button({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -138, 1, -12), Size = UDim2.fromOffset(60, 40), Text = V.Button, TextSize = 14, BackgroundColor3 = UI.Theme.PanelLight, Parent = gui }, function()
		panel.Visible = not panel.Visible
		if panel.Visible then
			render()
		end
	end)
	State.Changed:Connect(function()
		if panel.Visible then
			render()
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local seat = humanoid and humanoid.SeatPart
		if seat and seat:IsA("VehicleSeat") and seat.Name == "DriveSeat" then
			drive(dt, seat)
			speedo.Visible = true
			local root = driving and driving.PrimaryPart
			local shown = if root then (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude else 0
			speedo.Text = V.Speed:format(math.floor(shown + 0.5))
		elseif driving then
			stopDriving()
			speedo.Visible = false
		end
	end)
end

return VehicleController

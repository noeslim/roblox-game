--!strict
-- Building doors (tag AutoDoor, made by MapBuilder) swing open when someone walks up to them and
-- close behind. Runs on each client: the swing and the collision are local, which is what moves
-- the local character; other players see their own copy open too. Settings: Config/City.Interiors.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local City = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("City"))

local DoorController = {}

local I = City.Interiors
local open: { [BasePart]: boolean } = {}

local function openCFrame(closed: CFrame, hinge: number): CFrame
	-- turn around the hinge edge, towards the inside (-Z of the building)
	return closed * CFrame.new(hinge, 0, 0) * CFrame.Angles(0, math.rad(I.DoorOpenAngle), 0) * CFrame.new(-hinge, 0, 0)
end

local function setOpen(door: BasePart, isOpen: boolean)
	local closed = door:GetAttribute("ClosedCFrame")
	local hinge = door:GetAttribute("HingeOffset")
	if typeof(closed) ~= "CFrame" or type(hinge) ~= "number" then
		return
	end
	open[door] = isOpen
	door.CanCollide = not isOpen
	local goal = if isOpen then openCFrame(closed, hinge) else closed
	TweenService:Create(door, TweenInfo.new(I.DoorSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = goal }):Play()
end

function DoorController:Start()
	local range2 = I.DoorOpenDistance * I.DoorOpenDistance
	task.spawn(function()
		while true do
			task.wait(0.15)
			local spots: { Vector3 } = {}
			for _, player in Players:GetPlayers() do
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if root and root:IsA("BasePart") then
					table.insert(spots, root.Position)
				end
			end
			for _, door in CollectionService:GetTagged("AutoDoor") do
				if not door:IsA("BasePart") then
					continue
				end
				local closed = door:GetAttribute("ClosedCFrame")
				if typeof(closed) ~= "CFrame" then
					continue
				end
				local center = closed.Position
				local near = false
				for _, pos in spots do
					local d = pos - center
					if d.X * d.X + d.Y * d.Y + d.Z * d.Z < range2 then
						near = true
						break
					end
				end
				if near ~= (open[door] == true) then
					setOpen(door, near)
				end
			end
			for door in open do
				if door.Parent == nil then
					open[door] = nil
				end
			end
		end
	end)
end

return DoorController

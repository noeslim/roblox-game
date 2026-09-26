--!strict
-- Plays the procedural animations (Config/Animations.Procedural) sent by the server with PlayPose.
-- Runs on every client, on any R15 rig (players and NPCs). Joint rotations are blended on top of the
-- normal animations in RunService.Stepped, i.e. after the Animator has posed the rig this frame.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Animations = require(Shared.Config.Animations)
local Pose = require(Shared.Logic.Pose)
local Net = require(Shared.Net)

local PoseController = {}

local CASH = {
	Size = Vector3.new(0.9, 0.25, 0.45),
	Color = Color3.fromHex("#2E8B57"),
	Offset = CFrame.new(0, -0.35, -0.2),
}

type Playing = {
	def: Animations.Procedural,
	started: number,
	joints: { [string]: Motor6D },
	prop: BasePart?,
}

local playing: { [Model]: Playing } = {}

local function findJoints(model: Model): { [string]: Motor6D }
	local joints = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") then
			joints[d.Name] = d
		end
	end
	return joints
end

local function makeCash(model: Model): BasePart?
	local hand = model:FindFirstChild("LeftHand")
	if hand == nil or not hand:IsA("BasePart") then
		return nil
	end
	local cash = Instance.new("Part")
	cash.Name = "CashProp"
	cash.Size = CASH.Size
	cash.Color = CASH.Color
	cash.Material = Enum.Material.Fabric
	cash.CanCollide = false
	cash.CanQuery = false
	cash.CanTouch = false
	cash.Massless = true
	cash.CFrame = hand.CFrame * CASH.Offset
	local band = Instance.new("Part")
	band.Size = Vector3.new(0.15, 0.27, 0.47)
	band.Color = Color3.fromHex("#E8E0C8")
	band.CanCollide = false
	band.CanQuery = false
	band.Massless = true
	band.CFrame = cash.CFrame
	band.Parent = cash
	local w1 = Instance.new("WeldConstraint")
	w1.Part0 = hand
	w1.Part1 = cash
	w1.Parent = cash
	local w2 = Instance.new("WeldConstraint")
	w2.Part0 = cash
	w2.Part1 = band
	w2.Parent = band
	cash.Parent = model
	return cash
end

local function stop(model: Model)
	local p = playing[model]
	playing[model] = nil
	if p and p.prop then
		p.prop:Destroy()
	end
end

function PoseController.Play(model: Model, name: string)
	local def = Animations.Procedural[name]
	if def == nil or model.Parent == nil then
		return
	end
	stop(model)
	local entry: Playing = {
		def = def,
		started = os.clock(),
		joints = findJoints(model),
		prop = if def.prop == "Cash" then makeCash(model) else nil,
	}
	playing[model] = entry
end

local function step()
	local now = os.clock()
	for model, p in playing do
		local t = now - p.started
		if t >= p.def.duration or model.Parent == nil then
			stop(model)
			continue
		end
		local weight = Pose.Weight(p.def, t)
		for jointName, angles in Pose.Sample(p.def, t) do
			local joint = p.joints[jointName]
			if joint and joint.Parent then
				local target = CFrame.Angles(math.rad(angles.x), math.rad(angles.y), math.rad(angles.z))
				joint.Transform = joint.Transform:Lerp(target, weight)
			end
		end
	end
end

function PoseController:Start()
	Net.GetEvent("PlayPose").OnClientEvent:Connect(function(model: any, name: any)
		if typeof(model) == "Instance" and model:IsA("Model") and type(name) == "string" then
			PoseController.Play(model, name)
		end
	end)
	RunService.Stepped:Connect(step)
end

return PoseController

--!strict
-- Body dynamics on every R15 character near the camera (players and customers), computed locally by
-- each client (Config/Mood.Body): lean forward when running, roll into turns, and the head (plus a bit
-- of the torso) follows where each player looks. The local player sends its look direction with the
-- LookAt remote; the server stores it as LookPitch / LookYaw attributes on the character.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Mood = require(Shared.Config.Mood)
local Net = require(Shared.Net)

local BodyController = {}

local B = Mood.Body
local RANGE = 160 -- studs from the camera

type Joint = { motor: Motor6D, c0: CFrame } -- c0 = the joint's rest offset, restored + offset each frame
type Rig = {
	root: BasePart,
	rootJoint: Joint?,
	waist: Joint?,
	neck: Joint?,
	lean: number,
	roll: number,
	pitch: number,
	yaw: number,
}

local rigs: { [Model]: Rig } = {}
local localLook = { pitch = 0, yaw = 0 }

-- Offsets go on C0 (never touched by the Animator), from the saved rest value: nothing accumulates.
local function joint(model: Model, partName: string, name: string): Joint?
	local part = model:FindFirstChild(partName)
	local m = part and part:FindFirstChild(name)
	if m and m:IsA("Motor6D") then
		return { motor = m, c0 = m.C0 }
	end
	return nil
end

local function apply(j: Joint?, offset: CFrame)
	if j and j.motor.Parent then
		j.motor.C0 = j.c0 * offset
	end
end

local function rigOf(model: Model): Rig?
	local existing = rigs[model]
	if existing and existing.root.Parent == model then
		return existing
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return nil
	end
	local rig: Rig = {
		root = root,
		rootJoint = joint(model, "LowerTorso", "Root"),
		waist = joint(model, "UpperTorso", "Waist"),
		neck = joint(model, "Head", "Neck"),
		lean = 0,
		roll = 0,
		pitch = 0,
		yaw = 0,
	}
	rigs[model] = rig
	return rig
end

-- Where the local player looks, relative to its body (degrees).
local function measureLook(character: Model)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root == nil then
		return
	end
	local look = workspace.CurrentCamera.CFrame.LookVector
	local rel = root.CFrame:VectorToObjectSpace(look)
	localLook.pitch = math.clamp(math.deg(math.asin(math.clamp(rel.Y, -1, 1))), -B.MaxHeadPitch, B.MaxHeadPitch)
	local yaw = math.deg(math.atan2(-rel.X, -rel.Z))
	-- looking behind: turn back to neutral instead of snapping the head around
	localLook.yaw = if math.abs(yaw) > 110 then 0 else math.clamp(yaw, -B.MaxHeadYaw, B.MaxHeadYaw)
end

local function step(dt: number)
	local camPos = workspace.CurrentCamera.CFrame.Position
	local player = Players.LocalPlayer
	local models: { Model } = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(models, p.Character)
		end
	end
	for _, npc in CollectionService:GetTagged("Npc") do
		if npc:IsA("Model") then
			table.insert(models, npc)
		end
	end
	local k = math.min(1, dt * B.Smoothing)
	for _, model in models do
		local rig = rigOf(model)
		if rig == nil or (rig.root.Position - camPos).Magnitude > RANGE then
			continue
		end
		local vel = rig.root.CFrame:VectorToObjectSpace(rig.root.AssemblyLinearVelocity)
		local forward = math.max(0, -vel.Z)
		local targetLean = math.clamp((forward - Mood.Stamina.WalkSpeed) / (Mood.Stamina.SprintSpeed - Mood.Stamina.WalkSpeed), 0, 1) * B.SprintLean
		local turn = rig.root.AssemblyAngularVelocity.Y
		local targetRoll = math.clamp(turn * forward * 0.05, -1, 1) * B.TurnLean
		local targetPitch, targetYaw = 0, 0
		if model == player.Character then
			targetPitch, targetYaw = localLook.pitch, localLook.yaw
		else
			targetPitch = (model:GetAttribute("LookPitch") :: number?) or 0
			targetYaw = (model:GetAttribute("LookYaw") :: number?) or 0
		end
		rig.lean += (targetLean - rig.lean) * k
		rig.roll += (targetRoll - rig.roll) * k
		rig.pitch += (targetPitch * B.HeadFollow - rig.pitch) * k
		rig.yaw += (targetYaw * B.HeadFollow - rig.yaw) * k
		apply(rig.rootJoint, CFrame.Angles(math.rad(-rig.lean), 0, math.rad(rig.roll)))
		apply(rig.waist, CFrame.Angles(math.rad(rig.pitch * 0.3), math.rad(rig.yaw * 0.3), 0))
		apply(rig.neck, CFrame.Angles(math.rad(rig.pitch * 0.7), math.rad(rig.yaw * 0.7), 0))
	end
	for model in rigs do
		if model.Parent == nil then
			rigs[model] = nil
		end
	end
end

function BodyController:Start()
	local lookAt = Net.GetEvent("LookAt")
	RunService.Stepped:Connect(function(_, dt: number)
		step(dt)
	end)
	task.spawn(function()
		local sentPitch, sentYaw = 999, 999
		while true do
			task.wait(1 / B.LookSendRate)
			local character = Players.LocalPlayer.Character
			if character then
				measureLook(character)
				if math.abs(localLook.pitch - sentPitch) > 2 or math.abs(localLook.yaw - sentYaw) > 2 then
					sentPitch, sentYaw = localLook.pitch, localLook.yaw
					lookAt:FireServer(math.round(sentPitch), math.round(sentYaw))
				end
			end
		end
	end)
end

return BodyController

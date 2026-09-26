--!strict
-- Server side of animations: NPC walk/idle, Roblox emotes, custom or procedural animations,
-- props that must be seen by everyone (the weapon a customer walks away with).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Animations = require(Shared.Config.Animations)
local Cinematics = require(Shared.Config.Cinematics)
local Parts = require(Shared.Config.Parts)
local ModelFactory = require(Shared.Visual.ModelFactory)
local ServerNet = require(script.Parent.ServerNet)

local AnimServer = {}

-- the placeholder weapon is ~4 studs long; scale and grip shared with the first-person sale
local WEAPON_SCALE = Cinematics.Deal.WeaponScale
local GRIP = Cinematics.Deal.CustomerGrip

local function getAnimator(humanoid: Humanoid): Animator
	local existing = humanoid:FindFirstChildOfClass("Animator")
	if existing then
		return existing
	end
	local animator = Instance.new("Animator")
	animator.Parent = humanoid
	return animator
end

local function load(humanoid: Humanoid, id: string, priority: Enum.AnimationPriority, looped: boolean): AnimationTrack?
	if id == "" then
		return nil
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local ok, track = pcall(function()
		return getAnimator(humanoid):LoadAnimation(animation)
	end)
	if not ok or not track then
		warn("[AnimServer] could not load " .. id)
		return nil
	end
	track.Priority = priority
	track.Looped = looped
	return track
end

-- Idle + walk for a server-controlled NPC (call after it is parented to workspace). While it stands
-- still it plays a random fidget now and then (Config/Animations.Npc).
function AnimServer.SetupNpc(humanoid: Humanoid)
	local model = humanoid.Parent
	if model and model:IsA("Model") then
		task.spawn(function()
			local rng = Random.new()
			local N = Animations.Npc
			while humanoid.Parent and model.Parent do
				task.wait(rng:NextNumber(N.FidgetMinSeconds, N.FidgetMaxSeconds))
				local busyUntil = (model:GetAttribute("PoseUntil") :: number?) or 0
				if model.Parent and humanoid.MoveDirection.Magnitude < 0.1 and os.clock() > busyUntil and humanoid.Health > 0 then
					AnimServer.Play(model, N.Fidgets[rng:NextInteger(1, #N.Fidgets)])
				end
			end
		end)
	end
	local idle = load(humanoid, Animations.Locomotion.Idle, Enum.AnimationPriority.Idle, true)
	local walk = load(humanoid, Animations.Locomotion.Walk, Enum.AnimationPriority.Movement, true)
	if idle then
		idle:Play()
	end
	humanoid.Running:Connect(function(speed: number)
		if walk == nil then
			return
		end
		if speed > 0.5 then
			if not walk.IsPlaying then
				walk:Play(0.2)
				if idle then
					idle:Stop(0.2)
				end
			end
			walk:AdjustSpeed(speed / Animations.Locomotion.WalkSpeedReference)
		elseif walk.IsPlaying then
			walk:Stop(0.2)
			if idle then
				idle:Play(0.2)
			end
		end
	end)
end

-- Roblox emote (Wave, Point, Cheer, Laugh) on a humanoid.
function AnimServer.Emote(humanoid: Humanoid?, name: string)
	if humanoid == nil then
		return
	end
	local id = (Animations.Emotes :: any)[name]
	if type(id) ~= "string" then
		return
	end
	local track = load(humanoid, id, Enum.AnimationPriority.Action, false)
	if track then
		track:Play(0.1)
	end
end

-- Plays a named animation on a character or NPC. Uses your published animation when
-- Config/Animations.Custom has an id, the procedural version otherwise.
function AnimServer.Play(model: Model?, name: string)
	if model == nil or model.Parent == nil then
		return
	end
	local custom = Animations.Custom[name]
	if custom and custom ~= "" then
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local track = humanoid and load(humanoid, custom, Enum.AnimationPriority.Action, false)
		if track then
			track:Play(0.1)
			return
		end
	end
	local def = Animations.Procedural[name]
	if def then
		-- fidgets wait until this one is over
		model:SetAttribute("PoseUntil", os.clock() + def.duration)
		ServerNet.FireAllClients("PlayPose", model, name)
	end
end

-- Turns a character to face a point (keeps it upright).
function AnimServer.Face(root: BasePart?, target: Vector3)
	if root == nil then
		return
	end
	local pos = root.Position
	local flat = Vector3.new(target.X, pos.Y, target.Z)
	if (flat - pos).Magnitude > 0.1 then
		root.CFrame = CFrame.lookAt(pos, flat)
	end
end

-- Welds a weapon model in the right hand of a character (seen by everyone). Returns it.
function AnimServer.AttachWeapon(model: Model, partIds: { [string]: string }, rarity: string?): Model?
	local hand = model:FindFirstChild("RightHand") or model:FindFirstChild("Right Arm")
	if hand == nil or not hand:IsA("BasePart") then
		return nil
	end
	local weapon = ModelFactory.Weapon(partIds, Parts, rarity, nil)
	weapon.Name = "CarriedWeapon"
	weapon:ScaleTo(WEAPON_SCALE)
	local root = weapon.PrimaryPart :: BasePart
	for _, d in weapon:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.Massless = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			if d ~= root then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = root
				weld.Part1 = d
				weld.Parent = d
			end
		end
	end
	-- barrel (+X of the weapon) points forward (-Z of the hand)
	weapon:PivotTo(hand.CFrame * CFrame.new(0, GRIP.y, GRIP.z) * CFrame.Angles(0, math.rad(GRIP.yaw), 0))
	local grip = Instance.new("WeldConstraint")
	grip.Part0 = hand
	grip.Part1 = root
	grip.Parent = root
	weapon.Parent = model
	return weapon
end

return AnimServer

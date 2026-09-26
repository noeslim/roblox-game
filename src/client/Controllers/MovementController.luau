--!strict
-- How moving feels (Config/Mood): walk / sprint (Shift, or the RUN button on phones) with stamina,
-- exhaustion (slow, heavy breathing), jumps that cost stamina, and a living camera: head bob,
-- breathing sway, tilt when strafing, wider view when sprinting, a knock after a fall.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Mood = require(Shared.Config.Mood)
local Stamina = require(Shared.Logic.Stamina)
local Net = require(Shared.Net)
local UI = require(script.Parent.Parent.UI)

local MovementController = {}

local S = Mood.Stamina
local C = Mood.Camera

local state = Stamina.new(S)
local wantsSprint = false
local humanoid: Humanoid? = nil
local bobPhase = 0
local tilt = 0
local shake = 0
local breath: Sound? = nil
local bar: Frame? = nil
local barFill: Frame? = nil

local function onSprint(_: string, inputState: Enum.UserInputState): Enum.ContextActionResult
	if inputState == Enum.UserInputState.Begin then
		wantsSprint = true
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		wantsSprint = false
	end
	return Enum.ContextActionResult.Pass
end

local function watchCharacter(character: Model)
	local h = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if h == nil then
		return
	end
	humanoid = h
	state = Stamina.new(S)
	h.WalkSpeed = S.WalkSpeed
	h.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Jumping then
			if not Stamina.TryJump(state, S) then
				-- too tired: cancel the jump
				h:ChangeState(Enum.HumanoidStateType.Running)
			end
		elseif new == Enum.HumanoidStateType.Landed then
			local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and root.AssemblyLinearVelocity.Y < -35 then
				shake = C.LandShake
			end
		end
	end)
end

local function buildBar()
	local gui = UI.Screen("Stamina", 1)
	local frame = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.fromOffset(180, 5),
		BackgroundColor3 = Color3.fromRGB(20, 20, 24),
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		Parent = gui,
	})
	UI.Corner(frame, 3)
	local fill = UI.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(225, 225, 215),
		BorderSizePixel = 0,
		Parent = frame,
	})
	UI.Corner(fill, 3)
	bar, barFill = frame, fill
end

function MovementController:Start()
	ContextActionService:BindAction("Sprint", onSprint, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
	ContextActionService:SetTitle("Sprint", "RUN")
	ContextActionService:SetPosition("Sprint", UDim2.new(1, -170, 1, -120))

	if S.BreathSound ~= "" then
		local sound = Instance.new("Sound")
		sound.SoundId = S.BreathSound
		sound.Looped = true
		sound.Volume = 0
		sound.Parent = SoundService
		sound:Play()
		breath = sound
	end
	buildBar()
	-- gas station meal: full stamina
	Net.GetEvent("StaminaRefill").OnClientEvent:Connect(function()
		state.value = S.Max
		state.exhausted = false
	end)

	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(watchCharacter)
	if player.Character then
		task.spawn(watchCharacter, player.Character)
	end

	RunService.RenderStepped:Connect(function(dt: number)
		local h = humanoid
		if h == nil or h.Parent == nil or h.Health <= 0 then
			return
		end
		local moving = h.MoveDirection.Magnitude > 0.1
		local mode = Stamina.Step(state, dt, wantsSprint, moving, S)
		h.WalkSpeed = if mode == "sprint" then S.SprintSpeed elseif mode == "exhausted" then S.ExhaustedSpeed else S.WalkSpeed

		-- stamina bar: only shown when not full
		local fraction = Stamina.Fraction(state, S)
		local f, b = barFill, bar
		if f and b then
			f.Size = UDim2.fromScale(fraction, 1)
			f.BackgroundColor3 = if state.exhausted then Color3.fromRGB(170, 60, 50) else Color3.fromRGB(225, 225, 215)
			b.Visible = fraction < 0.999
		end
		local sound = breath
		if sound then
			local target = if state.exhausted then S.BreathVolume elseif mode == "sprint" then S.BreathVolume * 0.35 else 0
			sound.Volume += (target - sound.Volume) * math.min(1, dt * 2)
		end

		local camera = workspace.CurrentCamera
		if camera.CameraType ~= Enum.CameraType.Custom then
			h.CameraOffset = Vector3.zero
			return
		end
		-- head bob (steps) + breathing sway
		local speed = h.RootPart and (h.RootPart.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude or 0
		local stepRate = C.BobFrequency * speed / S.WalkSpeed
		bobPhase += dt * stepRate * math.pi * 2
		local amp = if moving and h.FloorMaterial ~= Enum.Material.Air then C.BobAmplitude * (if mode == "sprint" then C.SprintBobMultiplier else 1) else 0
		local sway = C.IdleSway * (if state.exhausted then 3 else 1)
		local t = os.clock()
		shake = math.max(0, shake - dt * 1.5)
		local bob = Vector3.new(
			math.cos(bobPhase * 0.5) * amp * 0.6 + math.sin(t * 1.3) * sway,
			math.abs(math.sin(bobPhase * 0.5)) * amp - amp * 0.5 + math.sin(t * 2.1) * sway - shake,
			0
		)
		h.CameraOffset = h.CameraOffset:Lerp(bob, math.min(1, dt * 12))
		-- tilt when strafing, relative to the camera
		local side = camera.CFrame.RightVector:Dot(h.MoveDirection)
		tilt += (-side * C.StrafeTilt - tilt) * math.min(1, dt * 6)
		camera.FieldOfView += ((if mode == "sprint" and moving then C.SprintFov else C.Fov) - camera.FieldOfView) * math.min(1, dt * 4)
	end)
	-- roll applied after the default camera has been placed this frame
	RunService:BindToRenderStep("MoodTilt", Enum.RenderPriority.Camera.Value + 1, function()
		local camera = workspace.CurrentCamera
		if camera.CameraType == Enum.CameraType.Custom and math.abs(tilt) > 0.01 then
			camera.CFrame *= CFrame.Angles(0, 0, math.rad(tilt))
		end
	end)
end

return MovementController

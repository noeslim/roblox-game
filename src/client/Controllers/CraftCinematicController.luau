--!strict
-- First-person crafting scene (Config/Cinematics.Craft, timeline in Logic/Assembly). The camera moves
-- over the workbench, your hands take each part laid on the bench and fit it on the frame (click),
-- tighten two screws, then lift the weapon to look at it while its name, rarity and value show.
-- Purely visual: the server already made the weapon. Click / space / E skips.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cinematics = require(Shared.Config.Cinematics)
local Economy = require(Shared.Config.Economy)
local Parts = require(Shared.Config.Parts)
local Visual = require(Shared.Config.Visual)
local Assembly = require(Shared.Logic.Assembly)
local ModelFactory = require(Shared.Visual.ModelFactory)
local CraftPoses = require(Shared.Visual.CraftPoses)
local UI = require(script.Parent.Parent.UI)
local Freeze = require(script.Parent.Parent.Freeze)

local CraftCinematicController = {}

local C = Cinematics.Craft
local player = Players.LocalPlayer
local playing = false
local Poses = CraftPoses.new({ CFrame = CFrame, Vector3 = Vector3, Assembly = Assembly }, C, Visual.WeaponLayout, Economy.Crafting.Slots)

local function sound(id: string, pitch: number?)
	if id == "" then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = C.Volume
	s.PlaybackSpeed = pitch or 1
	s.Parent = SoundService
	s:Play()
	s.Ended:Connect(function()
		s:Destroy()
	end)
end

local function setCharacterHidden(hidden: boolean)
	local character = player.Character
	if character == nil then
		return
	end
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then
			(d :: any).LocalTransparencyModifier = if hidden then 1 else 0
		end
	end
end

local function skinColor(): Color3
	local character = player.Character
	local colors = character and character:FindFirstChildOfClass("BodyColors")
	if colors then
		return colors.RightArmColor3
	end
	local hand = character and character:FindFirstChild("RightHand")
	if hand and hand:IsA("BasePart") then
		return hand.Color
	end
	return Color3.fromHex(C.SkinColor)
end

local function piece(name: string, size: Vector3, color: Color3, material: Enum.Material, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

-- A hand: the avatar's own hand and lower arm when it has R15 parts, simple blocks otherwise.
type Hand = { hand: BasePart, arm: BasePart, fingers: BasePart?, thumb: BasePart?, side: number, avatar: boolean }

local function cloneLimb(name: string, parent: Instance): BasePart?
	local character = player.Character
	local source = character and character:FindFirstChild(name)
	if source == nil or not source:IsA("BasePart") then
		return nil
	end
	local ok, copy = pcall(function()
		return source:Clone()
	end)
	if not ok or copy == nil then
		return nil
	end
	local part = copy :: BasePart
	for _, d in part:GetChildren() do
		if not d:IsA("SpecialMesh") and not d:IsA("SurfaceAppearance") then
			d:Destroy() -- joints, attachments, scripts
		end
	end
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 0;
	(part :: any).LocalTransparencyModifier = 0
	part.Parent = parent
	return part
end

local function makeHand(side: number, parent: Instance): Hand
	local prefix = if side == 1 then "Right" else "Left"
	local hand = if C.AvatarHands then cloneLimb(prefix .. "Hand", parent) else nil
	local arm = if C.AvatarHands then cloneLimb(prefix .. "LowerArm", parent) else nil
	if hand and arm then
		arm.Color = Color3.fromHex(C.SleeveColor) -- a sleeve; the shirt texture does not follow a copy
		arm.Material = Enum.Material.Fabric
		return { hand = hand, arm = arm, side = side, avatar = true }
	end
	if hand then
		hand:Destroy()
	end
	if arm then
		arm:Destroy()
	end
	local skin = skinColor()
	return {
		hand = piece("Palm", Vector3.new(0.46, 0.17, 0.5), skin, Enum.Material.SmoothPlastic, parent),
		fingers = piece("Fingers", Vector3.new(0.44, 0.14, 0.34), skin, Enum.Material.SmoothPlastic, parent),
		thumb = piece("Thumb", Vector3.new(0.14, 0.14, 0.3), skin, Enum.Material.SmoothPlastic, parent),
		arm = piece("Forearm", Vector3.new(0.44, 0.44, 1), Color3.fromHex(C.SleeveColor), Enum.Material.Fabric, parent),
		side = side,
		avatar = false,
	}
end

-- palmCF: back of the hand up (+Y), fingers towards -Z. The forearm goes back towards `elbow`.
local function setHand(h: Hand, palmCF: CFrame, elbow: Vector3)
	local forward, up = palmCF.LookVector, palmCF.UpVector
	if h.avatar then
		-- R15 limbs hang down: fingers along -Y, the back of the right hand on +X (left hand: -X)
		local flip = if C.AvatarHandFlip then -1 else 1
		local handCF = CFrame.fromMatrix(palmCF.Position, up * h.side * flip, -forward)
		h.hand.CFrame = handCF
		local wrist = palmCF.Position - forward * (h.hand.Size.Y / 2)
		local toWrist = wrist - elbow
		local dir = if toWrist.Magnitude > 0.01 then toWrist.Unit else forward
		local side = up - dir * up:Dot(dir)
		side = if side.Magnitude > 0.01 then side.Unit else Vector3.xAxis
		-- the sleeve reaches the elbow (off screen), so no forearm floats in the air
		local length = math.max(0.5, toWrist.Magnitude)
		if math.abs(h.arm.Size.Y - length) > 0.01 then
			h.arm.Size = Vector3.new(h.arm.Size.X, length, h.arm.Size.Z)
		end
		h.arm.CFrame = CFrame.fromMatrix(wrist - dir * (length / 2), side * h.side, -dir)
		return
	end
	h.hand.CFrame = palmCF
	local fingers, thumb = h.fingers, h.thumb
	if fingers then
		fingers.CFrame = palmCF * CFrame.new(0, -0.05, -0.38) * CFrame.Angles(math.rad(-28), 0, 0)
	end
	if thumb then
		thumb.CFrame = palmCF * CFrame.new(-0.27 * h.side, -0.04, -0.08) * CFrame.Angles(0, math.rad(28 * h.side), 0)
	end
	local wrist = (palmCF * CFrame.new(0, 0, 0.3)).Position
	local length = math.max(0.3, (elbow - wrist).Magnitude)
	h.arm.Size = Vector3.new(0.44, 0.44, length)
	h.arm.CFrame = CFrame.lookAt((wrist + elbow) / 2, wrist)
end

local function revealCard(result: any): ScreenGui
	local gui = UI.Screen("CraftReveal", 30)
	gui.IgnoreGuiInset = true
	local rarityColor = UI.RarityColor(result.rarity)
	local frame = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -60), Size = UDim2.fromOffset(420, 78), BackgroundTransparency = 1, Parent = gui })
	UI.Label({ Size = UDim2.new(1, 0, 0, 30), Text = string.upper(tostring(result.name)), Font = UI.Theme.FontBlack, TextSize = 26, TextStrokeTransparency = 0.5, Parent = frame })
	UI.Label({ Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, 0, 0, 20), Text = string.upper(tostring(result.rarity)), Font = UI.Theme.FontBlack, TextSize = 18, TextColor3 = rarityColor, TextStrokeTransparency = 0.5, Parent = frame })
	UI.Label({ Position = UDim2.fromOffset(0, 54), Size = UDim2.new(1, 0, 0, 20), Text = "Suggested price " .. UI.Money(result.suggestedPrice or result.value or 0), TextSize = 15, TextColor3 = UI.Theme.Money, TextStrokeTransparency = 0.5, Parent = frame })
	frame.Position = UDim2.new(0.5, 0, 1, -40)
	TweenService:Create(frame, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Position = UDim2.new(0.5, 0, 1, -60) }):Play()
	return gui
end

local function letterbox(): (ScreenGui, Frame)
	local gui = UI.Screen("CraftLetterbox", 29)
	gui.IgnoreGuiInset = true
	for _, top in { true, false } do
		UI.new("Frame", {
			AnchorPoint = Vector2.new(0, if top then 0 else 1),
			Position = UDim2.fromScale(0, if top then 0 else 1),
			Size = UDim2.new(1, 0, 0.08, 0),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BorderSizePixel = 0,
			Parent = gui,
		})
	end
	local fade = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 5, Parent = gui })
	return gui, fade
end

-- Last resort when the scene fails to start: give everything back to the player.
local function emergencyRestore()
	playing = false
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	setCharacterHidden(false)
	Freeze.Set(false)
	local leftover = workspace:FindFirstChild("CraftCinematic")
	if leftover then
		leftover:Destroy()
	end
	local gui = player:FindFirstChild("PlayerGui")
	for _, name in { "CraftLetterbox", "CraftReveal" } do
		local g = gui and gui:FindFirstChild(name)
		if g then
			g:Destroy()
		end
	end
end

local play: (BasePart, { [string]: string }, any, (() -> ())?) -> ()

-- Plays the scene on `bench` (the workbench's root part). result = the RequestCraft answer.
-- Never leaves the player stuck: any error ends the scene and restores the camera and controls.
function CraftCinematicController.Play(bench: BasePart, partIds: { [string]: string }, result: any, onDone: (() -> ())?)
	if playing then
		return
	end
	playing = true
	local ok = xpcall(play, function(err)
		warn("[CraftCinematic] could not start: " .. tostring(err))
	end, bench, partIds, result, onDone)
	if not ok then
		emergencyRestore()
		if onDone then
			onDone()
		end
	end
end

play = function(bench: BasePart, partIds: { [string]: string }, result: any, onDone: (() -> ())?)
	local camera = workspace.CurrentCamera
	local oldFov = camera.FieldOfView
	local startCF = camera.CFrame

	local folder = Instance.new("Folder")
	folder.Name = "CraftCinematic"
	folder.Parent = workspace

	-- one model per part, all in weapon space (pivot = where the whole weapon would be)
	local models: { [string]: Model } = {}
	local present: { [string]: boolean } = {}
	for slot, id in partIds do
		local m = ModelFactory.Weapon({ [slot] = id }, Parts, nil, nil)
		local root = m.PrimaryPart
		if root then
			root.Transparency = 1
		end
		m.Parent = folder
		models[slot] = m
		present[slot] = true
	end
	local ctx = Poses.Context(bench.CFrame, present)
	local plan = ctx.plan
	for _, c in ctx.cradle do
		local block = piece("Cradle", c.size, Color3.fromHex("#3A3A40"), Enum.Material.Metal, folder)
		block.CFrame = c.cf
	end
	for slot, m in models do
		m:PivotTo(Poses.Part(ctx, slot, 0))
	end
	local right = makeHand(1, folder)
	local left = makeHand(-1, folder)
	local driver = Instance.new("Model")
	driver.Name = "Screwdriver"
	local handle = piece("Handle", Vector3.new(0.18, 0.18, 0.55), Color3.fromHex("#B8322A"), Enum.Material.Plastic, driver)
	local shaft = piece("Shaft", Vector3.new(0.05, 0.05, 0.5), Color3.fromHex("#B8BCC4"), Enum.Material.Metal, driver)
	driver.Parent = folder
	local barGui, fade = letterbox()

	-- everything is ready: take the camera and freeze the character
	Freeze.Set(true)
	setCharacterHidden(true)
	camera.CameraType = Enum.CameraType.Scriptable

	local reveal: ScreenGui? = nil
	local light: PointLight? = nil
	local fired: { [string]: boolean } = {}
	local started = os.clock()
	local skipTo: number? = nil
	local finished = false
	local elapsedOffset = 0
	local last = started
	local rightCF, leftCF = Poses.Rest(ctx, 1), Poses.Rest(ctx, -1)

	local function once(key: string, id: string, pitch: number?)
		if not fired[key] then
			fired[key] = true
			sound(id, pitch)
		end
	end

	local SKIP_INPUTS = { [Enum.UserInputType.MouseButton1] = true, [Enum.UserInputType.Touch] = true }
	local SKIP_KEYS = { [Enum.KeyCode.Space] = true, [Enum.KeyCode.E] = true, [Enum.KeyCode.ButtonA] = true, [Enum.KeyCode.Escape] = true }
	local skipConn = UserInputService.InputBegan:Connect(function(input)
		if (SKIP_INPUTS[input.UserInputType] or SKIP_KEYS[input.KeyCode]) and os.clock() - started > C.SkipAfter then
			skipTo = plan.outroStart
		end
	end)

	local conn: RBXScriptConnection? = nil
	local function finish()
		if finished then
			return
		end
		finished = true
		playing = false
		if conn then
			conn:Disconnect()
		end
		skipConn:Disconnect()
		pcall(function()
			folder:Destroy()
		end)
		if reveal then
			local r = reveal
			task.delay(1.2, function()
				r:Destroy()
			end)
		end
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = oldFov
		setCharacterHidden(false)
		Freeze.Set(false)
		TweenService:Create(fade, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
		task.delay(0.35, function()
			barGui:Destroy()
		end)
		if onDone then
			onDone()
		end
	end

	local function frame()
		local now = os.clock()
		local dt = math.min(0.1, now - last)
		last = now
		local t = now - started + elapsedOffset
		local skip = skipTo
		if skip and t < skip then
			elapsedOffset += skip - t
			t = skip
			-- jump: hands snap to their new place
			rightCF, leftCF = Poses.Hands(ctx, t)
		end
		skipTo = nil
		local phase = Assembly.Phase(plan, t)

		-- camera: glides over the bench, then stands up with the weapon
		local camCF = Poses.Camera(ctx, t)
		if t < C.IntroSeconds then
			local u = Assembly.Smooth(t / C.IntroSeconds)
			camCF = startCF:Lerp(camCF, u)
			camera.FieldOfView = oldFov + (C.Fov - oldFov) * u
		else
			camCF *= CFrame.new(math.sin(t * 1.3) * 0.01, math.sin(t * 2.1) * 0.012, 0)
			camera.FieldOfView = C.Fov
		end

		-- parts
		for slot, m in models do
			m:PivotTo(Poses.Part(ctx, slot, t))
		end
		for _, step in plan.steps do
			if t >= step.done then
				once("fit" .. step.slot, C.Sounds.Click, 0.95 + (#step.slot % 3) * 0.04)
				if t < step.done + 0.08 then
					camCF *= CFrame.new(0, -C.ClickKick, C.ClickKick)
				end
			end
		end
		local l = plan.load
		if l and t >= l.done then
			once("magIn", C.Sounds.MagIn)
		end
		if t >= plan.rackStart + (plan.testStart - plan.rackStart) * 0.3 then
			once("rack", C.Sounds.Rack)
		end
		for i, shot in Poses.Shots(ctx) do
			if t >= shot then
				once("shot" .. i, C.Sounds.DryFire)
			end
		end

		-- screwdriver
		local d = Poses.Driver(ctx, t)
		driver.Parent = if d then folder else nil
		if d then
			shaft.CFrame = d * CFrame.new(0, 0, -0.25)
			handle.CFrame = d * CFrame.new(0, 0, 0.27)
			once(if t < (plan.screwStart + plan.liftStart) / 2 then "screw1" else "screw2", C.Sounds.Ratchet)
		end

		-- hands: follow their targets smoothly (no teleport between two moves)
		local targetR, targetL = Poses.Hands(ctx, t)
		local k = 1 - math.exp(-dt * C.HandFollow)
		rightCF = rightCF:Lerp(targetR, k)
		leftCF = leftCF:Lerp(targetL, k)
		local elbowR = (camCF * CFrame.new(0.95, -1.7, 0.2)).Position
		local elbowL = (camCF * CFrame.new(-0.95, -1.7, 0.2)).Position
		setHand(right, rightCF, elbowR)
		setHand(left, leftCF, elbowL)

		-- inspection: name, rarity, price and a light in the rarity color
		local inspecting = phase == "inspect" or phase == "outro"
		if inspecting and reveal == nil then
			reveal = revealCard(result)
			local body: Model? = models.Body
			if body == nil then
				for _, m in models do
					body = m
					break
				end
			end
			local anchorPart = body and body:FindFirstChildWhichIsA("BasePart")
			if anchorPart then
				local pl = Instance.new("PointLight")
				pl.Color = UI.RarityColor(result.rarity)
				pl.Range = 6
				pl.Brightness = 0.6 + (table.find(Economy.RarityOrder, result.rarity) or 1) * 0.35
				pl.Parent = anchorPart
				light = pl
			end
		end
		if light then
			light.Enabled = inspecting
		end

		camera.CFrame = camCF
		if phase == "outro" then
			fade.BackgroundTransparency = 1 - Assembly.Smooth((t - plan.outroStart) / C.OutroSeconds)
		elseif phase == "done" then
			finish()
		end
	end
	conn = RunService.RenderStepped:Connect(function()
		xpcall(frame, function(err)
			warn("[CraftCinematic] " .. tostring(err))
			task.defer(finish)
		end)
	end)
	-- whatever happens, the player gets the controls back
	task.delay(plan.total + 3, finish)
end

function CraftCinematicController.IsPlaying(): boolean
	return playing
end

function CraftCinematicController:Start() end

return CraftCinematicController

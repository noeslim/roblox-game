--!strict
-- Shared pieces of the first-person scenes (crafting, sale): the player's hands (the avatar's own R15
-- hands and forearms, or simple blocks), hiding the character, letterbox bars, one-shot sounds.
-- Hand settings come from Config/Cinematics.Craft (AvatarHands, AvatarHandFlip, colors).
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local StarterGui = game:GetService("StarterGui")

local Cinematics = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Cinematics"))
local UI = require(script.Parent.UI)

local FirstPerson = {}

local C = Cinematics.Craft
local player = Players.LocalPlayer

function FirstPerson.Sound(id: string, pitch: number?, volume: number?)
	if id == "" then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or C.Volume
	s.PlaybackSpeed = pitch or 1
	s.Parent = SoundService
	s:Play()
	s.Ended:Connect(function()
		s:Destroy()
	end)
end

function FirstPerson.SetCharacterHidden(hidden: boolean)
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

function FirstPerson.Piece(name: string, size: Vector3, color: Color3, material: Enum.Material, parent: Instance): Part
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
export type Hand = { hand: BasePart, arm: BasePart, fingers: BasePart?, thumb: BasePart?, side: number, avatar: boolean, scale: number }

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

-- scale: 1 = the avatar's real size (seen from very close, blocky avatar hands look huge)
function FirstPerson.MakeHand(side: number, parent: Instance, scale: number?): Hand
	local k = scale or 1
	local prefix = if side == 1 then "Right" else "Left"
	local hand = if C.AvatarHands then cloneLimb(prefix .. "Hand", parent) else nil
	local arm = if C.AvatarHands then cloneLimb(prefix .. "LowerArm", parent) else nil
	if hand and arm then
		arm.Color = Color3.fromHex(C.SleeveColor) -- a sleeve; the shirt texture does not follow a copy
		arm.Material = Enum.Material.Fabric
		hand.Size *= k
		arm.Size *= k
		return { hand = hand, arm = arm, side = side, avatar = true, scale = k }
	end
	if hand then
		hand:Destroy()
	end
	if arm then
		arm:Destroy()
	end
	local skin = skinColor()
	return {
		hand = FirstPerson.Piece("Palm", Vector3.new(0.46, 0.17, 0.5) * k, skin, Enum.Material.SmoothPlastic, parent),
		fingers = FirstPerson.Piece("Fingers", Vector3.new(0.44, 0.14, 0.34) * k, skin, Enum.Material.SmoothPlastic, parent),
		thumb = FirstPerson.Piece("Thumb", Vector3.new(0.14, 0.14, 0.3) * k, skin, Enum.Material.SmoothPlastic, parent),
		arm = FirstPerson.Piece("Forearm", Vector3.new(0.44, 0.44, 1) * k, Color3.fromHex(C.SleeveColor), Enum.Material.Fabric, parent),
		side = side,
		avatar = false,
		scale = k,
	}
end

-- palmCF: back of the hand up (+Y), fingers towards -Z. The forearm goes back towards `elbow`.
function FirstPerson.SetHand(h: Hand, palmCF: CFrame, elbow: Vector3)
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
	local k = h.scale
	local fingers, thumb = h.fingers, h.thumb
	if fingers then
		fingers.CFrame = palmCF * CFrame.new(0, -0.05 * k, -0.38 * k) * CFrame.Angles(math.rad(-28), 0, 0)
	end
	if thumb then
		thumb.CFrame = palmCF * CFrame.new(-0.27 * k * h.side, -0.04 * k, -0.08 * k) * CFrame.Angles(0, math.rad(28 * h.side), 0)
	end
	local wrist = (palmCF * CFrame.new(0, 0, 0.3 * k)).Position
	local length = math.max(0.3, (elbow - wrist).Magnitude)
	h.arm.Size = Vector3.new(0.44 * k, 0.44 * k, length)
	h.arm.CFrame = CFrame.lookAt((wrist + elbow) / 2, wrist)
end

-- Hides the HUD (your ScreenGuis, markers, prompts, Roblox chat / backpack) during a scene, except
-- the guis named in `keep`. Returns the function that puts everything back as it was.
function FirstPerson.HideHud(keep: { string }): () -> ()
	local hidden: { LayerCollector } = {}
	local gui = player:FindFirstChild("PlayerGui")
	if gui then
		for _, g in gui:GetChildren() do
			if g:IsA("LayerCollector") and g.Enabled and not table.find(keep, g.Name) then
				g.Enabled = false
				table.insert(hidden, g)
			end
		end
	end
	local promptsWereOn = ProximityPromptService.Enabled
	ProximityPromptService.Enabled = false
	local core: { [Enum.CoreGuiType]: boolean } = {}
	for _, kind in { Enum.CoreGuiType.Chat, Enum.CoreGuiType.Backpack, Enum.CoreGuiType.PlayerList, Enum.CoreGuiType.Health } do
		local ok, on = pcall(function()
			return StarterGui:GetCoreGuiEnabled(kind)
		end)
		if ok and on then
			core[kind] = true
			pcall(function()
				StarterGui:SetCoreGuiEnabled(kind, false)
			end)
		end
	end
	local restored = false
	return function()
		if restored then
			return
		end
		restored = true
		for _, g in hidden do
			if g.Parent then
				g.Enabled = true
			end
		end
		ProximityPromptService.Enabled = promptsWereOn
		for kind in core do
			pcall(function()
				StarterGui:SetCoreGuiEnabled(kind, true)
			end)
		end
	end
end

function FirstPerson.Letterbox(): (ScreenGui, Frame)
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

return FirstPerson

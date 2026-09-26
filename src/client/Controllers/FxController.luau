--!strict
-- Plays the server-triggered effects: crafting show at the workbench, the deal, level ups.
-- Also hides other players' workbench / deal prompts so you only see your own.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Parts = require(Shared.Config.Parts)
local Visual = require(Shared.Config.Visual)
local Net = require(Shared.Net)
local ModelFactory = require(Shared.Visual.ModelFactory)
local UI = require(script.Parent.Parent.UI)
local Effects = require(script.Parent.Parent.Effects)
local Notify = require(script.Parent.Parent.Notify)

local FxController = {}

local CRAFT = {
	HeightAbove = 4, -- studs above the workbench
	Radius = 3.5, -- parts start on a circle
	PieceSeconds = 0.35,
	PieceDelay = 0.22,
	SpinSeconds = 2.4,
	SpinSpeed = 3, -- radians per second
}

local localPlayer = Players.LocalPlayer

local function playCraft(pos: Vector3, partIds: { [string]: string }, rarity: string, value: number, ownerUserId: number)
	local center = pos + Vector3.new(0, CRAFT.HeightAbove, 0)
	local rarityColor = UI.RarityColor(rarity)
	local isMine = ownerUserId == localPlayer.UserId
	local folder = Instance.new("Folder")
	folder.Name = "CraftFx"
	folder.Parent = workspace

	-- 1. the five parts fly in one by one and snap together
	local slots = Economy.Crafting.Slots
	for i, slot in slots do
		local part = Parts[partIds[slot] or ""]
		local color = if part and part.set and Visual.SetColors[part.set]
			then Color3.fromHex(Visual.SetColors[part.set])
			else UI.RarityColor(part and part.rarity)
		local angle = (i / #slots) * math.pi * 2
		local startPos = center + Vector3.new(math.cos(angle) * CRAFT.Radius, 1, math.sin(angle) * CRAFT.Radius)
		local piece = UI.new("Part", {
			Size = Vector3.new(0.7, 0.4, 0.4),
			CFrame = CFrame.new(startPos),
			Color = color,
			Material = Enum.Material.Neon,
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			Parent = folder,
		})
		task.delay((i - 1) * CRAFT.PieceDelay, function()
			local tween = TweenService:Create(piece, TweenInfo.new(CRAFT.PieceSeconds, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
				CFrame = CFrame.new(center) * CFrame.Angles(0, angle, 0),
				Size = Vector3.new(0.2, 0.2, 0.2),
			})
			tween:Play()
			tween.Completed:Connect(function()
				piece:Destroy()
				Effects.Sparkles(center, color, 10)
			end)
		end)
	end

	-- 2. the weapon appears, spins and bursts in its rarity color
	task.wait(#slots * CRAFT.PieceDelay + CRAFT.PieceSeconds)
	local weapon = ModelFactory.Weapon(partIds, Parts, rarity, nil)
	weapon:PivotTo(CFrame.new(center))
	weapon.Parent = folder
	local rank = table.find(Economy.RarityOrder, rarity) or 1
	Effects.Sparkles(center, rarityColor, 20 + rank * 15)
	Effects.Sound(Effects.Sounds.Craft, center, 1 + rank * 0.1)
	Effects.FloatingText(center + Vector3.new(0, 1.5, 0), string.upper(rarity) .. "!", rarityColor, 24 + rank * 4)
	if isMine then
		task.delay(0.4, function()
			Effects.FloatingText(center, "Value " .. UI.Money(value), UI.Theme.Money, 22)
		end)
		if rank >= 4 then
			Effects.Flash(rarityColor, 0.5)
			Effects.CameraShake(0.3, 0.3)
		end
	end

	local started = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		if t > CRAFT.SpinSeconds or weapon.Parent == nil then
			conn:Disconnect()
			folder:Destroy()
			return
		end
		local bob = math.sin(t * 4) * 0.15
		weapon:PivotTo(CFrame.new(center + Vector3.new(0, bob, 0)) * CFrame.Angles(0, t * CRAFT.SpinSpeed, 0))
	end)
end

local function playSale(info: any)
	if type(info) ~= "table" or typeof(info.position) ~= "Vector3" then
		return
	end
	local pos = info.position :: Vector3
	Effects.Sparkles(pos + Vector3.new(0, 2, 0), UI.Theme.Money, 30)
	Effects.Sound(Effects.Sounds.Cash, pos)
	if info.ownerUserId ~= localPlayer.UserId then
		return
	end
	Effects.FloatingText(pos + Vector3.new(0, 3, 0), "+" .. UI.Money(info.total), UI.Theme.Money, 34)
	if type(info.combo) == "number" and info.combo > 1 then
		task.delay(0.25, function()
			Effects.FloatingText(pos + Vector3.new(0, 5, 0), ("COMBO x%.1f"):format(info.multiplier), UI.Theme.Warning, 28)
		end)
	end
	if type(info.tip) == "number" and info.tip > 0 then
		task.delay(0.5, function()
			Effects.FloatingText(pos + Vector3.new(0, 1.5, 0), "TIP +" .. UI.Money(info.tip), UI.Theme.Info, 22)
		end)
	end
	Effects.MoneyBurst(pos + Vector3.new(0, 2, 0), if info.big then 16 else nil)
	if info.big then
		Effects.CameraShake(0.6, 0.4)
		Effects.Flash(UI.Theme.Money, 0.5)
	end
end

local function playLevelUp(level: any)
	if type(level) ~= "number" then
		return
	end
	Notify.Show("LEVEL UP! You are now level " .. level, "success")
	Effects.Flash(UI.Theme.Accent, 0.6)
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		Effects.Sparkles(root.Position, UI.Theme.Accent, 60)
		Effects.FloatingText(root.Position + Vector3.new(0, 4, 0), "LEVEL " .. level, UI.Theme.Accent, 36)
	end
end

-- Other players' prompts: make them unreachable locally (the server never changes this property).
local OWNED_PROMPTS = { WorkbenchPrompt = true, DealPrompt = true }

local function ownerOf(inst: Instance): number?
	local node: Instance? = inst
	while node and node ~= workspace do
		local owner = node:GetAttribute("OwnerUserId")
		if type(owner) == "number" then
			return owner
		end
		node = node.Parent
	end
	return nil
end

local function filterPrompt(inst: Instance)
	if inst:IsA("ProximityPrompt") and OWNED_PROMPTS[inst.Name] then
		task.defer(function()
			local owner = ownerOf(inst)
			if owner ~= nil and owner ~= localPlayer.UserId then
				inst.MaxActivationDistance = 0
			end
		end)
	end
end

function FxController:Start()
	Net.GetEvent("CraftFx").OnClientEvent:Connect(function(pos: any, partIds: any, rarity: any, value: any, ownerUserId: any)
		if typeof(pos) == "Vector3" and type(partIds) == "table" and type(rarity) == "string" then
			task.spawn(playCraft, pos, partIds, rarity, tonumber(value) or 0, tonumber(ownerUserId) or 0)
		end
	end)
	Net.GetEvent("SaleFx").OnClientEvent:Connect(playSale)
	Net.GetEvent("LevelUp").OnClientEvent:Connect(playLevelUp)

	workspace.DescendantAdded:Connect(filterPrompt)
	for _, d in workspace:GetDescendants() do
		filterPrompt(d)
	end
end

return FxController

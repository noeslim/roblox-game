--!strict
-- NPC customers: spawn at the end of the street, walk into the stash, queue at the counter,
-- wait with a patience bar, then leave (happy or angry). Buying decisions live in Logic/Customer
-- and the deal itself in SaleService.
local PhysicsService = game:GetService("PhysicsService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Buildables = require(Shared.Config.Buildables)
local Messages = require(Shared.Config.Messages)
local Visual = require(Shared.Config.Visual)
local ComboTracker = require(Shared.Logic.ComboTracker)
local Customer = require(Shared.Logic.Customer)
local CustomerQueue = require(Shared.Logic.CustomerQueue)
local PlotUtil = require(Shared.Visual.PlotUtil)
local BuildService = require(script.Parent.BuildService)
local PlotService = require(script.Parent.PlotService)
local NpcMover = require(script.Parent.Parent.Lib.NpcMover)
local AnimServer = require(script.Parent.Parent.Lib.AnimServer)

local CustomerService = {}

local CFG = Economy.Customers
local CUSTOMER_GROUP = "Customers"
local PLAYER_GROUP = "Players"

export type Npc = {
	id: string,
	owner: Player,
	data: Customer.CustomerData,
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	state: "Arriving" | "Queued" | "Leaving",
	frontSince: number?, -- os.clock() when it reached the counter as first in line
	patienceLeft: number,
	pending: { weaponId: string, price: number }?,
	exit: Vector3,
	prompt: ProximityPrompt?,
	bar: Frame?,
	sayLabel: TextLabel?,
	sayToken: number,
	leaveDelay: number?, -- seconds to stay before walking away (deal scene)
}

type Stash = {
	owner: Player,
	plot: Instance,
	queue: CustomerQueue.CustomerQueue,
	npcs: { [string]: Npc },
	nextSpawnAt: number,
	combo: ComboTracker.ComboTracker,
	counter: Model?,
	alive: boolean,
}

local stashes: { [Player]: Stash } = {}
local npcsById: { [string]: Npc } = {}
local rng = Random.new()
local nextId = 0

local function hex(s: string): Color3
	return Color3.fromHex(s)
end

local function pickLine(key: string): string
	local lines = (Messages.CustomerLines :: any)[key] :: { string }
	return lines[rng:NextInteger(1, #lines)]
end

local function flatDistance(a: Vector3, b: Vector3): number
	return ((a - b) * Vector3.new(1, 0, 1)).Magnitude
end

local function customersFolder(): Instance
	local f = workspace:FindFirstChild("Customers")
	if f == nil then
		f = Instance.new("Folder")
		f.Name = "Customers"
		f.Parent = workspace
	end
	return f :: Instance
end

local function setupCollisionGroups()
	pcall(function()
		PhysicsService:RegisterCollisionGroup(CUSTOMER_GROUP)
	end)
	pcall(function()
		PhysicsService:RegisterCollisionGroup(PLAYER_GROUP)
	end)
	PhysicsService:CollisionGroupSetCollidable(CUSTOMER_GROUP, CUSTOMER_GROUP, false)
	PhysicsService:CollisionGroupSetCollidable(CUSTOMER_GROUP, PLAYER_GROUP, false)

	local function tagCharacter(character: Model)
		for _, d in character:GetDescendants() do
			if d:IsA("BasePart") then
				d.CollisionGroup = PLAYER_GROUP
			end
		end
		character.DescendantAdded:Connect(function(d)
			if d:IsA("BasePart") then
				d.CollisionGroup = PLAYER_GROUP
			end
		end)
	end
	local function watch(player: Player)
		if player.Character then
			tagCharacter(player.Character)
		end
		player.CharacterAdded:Connect(tagCharacter)
	end
	Players.PlayerAdded:Connect(watch)
	for _, p in Players:GetPlayers() do
		watch(p)
	end
end

-- Model ------------------------------------------------------------------------

local function blockyFallback(shirt: Color3, skin: Color3): Model
	local model = Instance.new("Model")
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Color = shirt
	root.Parent = model
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(1.4, 1.4, 1.4)
	head.Color = skin
	head.CFrame = root.CFrame * CFrame.new(0, 1.7, 0)
	head.Parent = model
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = head
	weld.Parent = root
	local humanoid = Instance.new("Humanoid")
	humanoid.HipHeight = 2
	humanoid.Parent = model
	model.PrimaryPart = root
	return model
end

local function makeCustomerModel(): Model
	local skin = hex(Visual.CustomerSkinColors[rng:NextInteger(1, #Visual.CustomerSkinColors)])
	local shirt = hex(Visual.CustomerShirtColors[rng:NextInteger(1, #Visual.CustomerShirtColors)])
	local pants = hex(Visual.CustomerPantsColors[rng:NextInteger(1, #Visual.CustomerPantsColors)])
	local desc = Instance.new("HumanoidDescription")
	desc.HeadColor = skin
	desc.LeftArmColor = skin
	desc.RightArmColor = skin
	desc.TorsoColor = shirt
	desc.LeftLegColor = pants
	desc.RightLegColor = pants
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if ok and model then
		return model
	end
	return blockyFallback(shirt, skin)
end

local function budgetHint(multiplier: number): string
	if multiplier < 0.95 then
		return "$"
	elseif multiplier < 1.25 then
		return "$$"
	end
	return "$$$"
end

local function wantsText(data: Customer.CustomerData): string
	if data.wantsContraband then
		return "Wants: contraband"
	elseif data.minRarity then
		return "Wants: " .. data.minRarity .. " or better"
	end
	return "Wants: any blaster"
end

local function label(parent: Instance, name: string, pos: UDim2, size: UDim2, text: string, color: Color3, textSize: number): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Position = pos
	l.Size = size
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextColor3 = color
	l.TextStrokeTransparency = 0.4
	l.Font = Enum.Font.GothamBold
	l.TextSize = textSize
	l.Parent = parent
	return l
end

local function buildBillboard(npc: Npc)
	local head = npc.model:FindFirstChild("Head") :: BasePart? or npc.root
	local gui = Instance.new("BillboardGui")
	gui.Name = "CustomerGui"
	gui.Size = UDim2.fromOffset(220, 96)
	gui.StudsOffset = Vector3.new(0, 3.4, 0)
	gui.MaxDistance = 80
	gui.Adornee = head
	gui.Parent = head

	local say = label(gui, "Say", UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 28), "", Color3.new(1, 1, 1), 16)
	say.BackgroundTransparency = 0.2
	say.BackgroundColor3 = hex("#141418")
	say.TextWrapped = true
	say.Visible = false
	Instance.new("UICorner", say).CornerRadius = UDim.new(0, 8)
	npc.sayLabel = say

	local personality = (Messages.PersonalityNames :: any)[npc.data.personality] or npc.data.personality
	label(gui, "Title", UDim2.fromOffset(0, 32), UDim2.new(1, 0, 0, 20), personality .. "  " .. budgetHint(npc.data.budgetMultiplier), hex("#FFB020"), 16)
	label(gui, "Wants", UDim2.fromOffset(0, 52), UDim2.new(1, 0, 0, 18), wantsText(npc.data), hex("#DDDDEE"), 14)

	local barBg = Instance.new("Frame")
	barBg.Name = "PatienceBg"
	barBg.Position = UDim2.new(0.15, 0, 0, 76)
	barBg.Size = UDim2.new(0.7, 0, 0, 8)
	barBg.BackgroundColor3 = hex("#141418")
	barBg.BorderSizePixel = 0
	barBg.Parent = gui
	Instance.new("UICorner", barBg).CornerRadius = UDim.new(1, 0)
	local bar = Instance.new("Frame")
	bar.Name = "Patience"
	bar.Size = UDim2.fromScale(1, 1)
	bar.BackgroundColor3 = hex("#39FF88")
	bar.BorderSizePixel = 0
	bar.Parent = barBg
	Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
	npc.bar = bar
end

-- Positions --------------------------------------------------------------------

-- Where the customer at `position` (1 = front) stands, or nil without a counter.
local function slotPosition(stash: Stash, position: number): Vector3?
	local counter = stash.counter
	if counter == nil or counter.Parent == nil then
		return nil
	end
	local def = Buildables.ById[counter:GetAttribute("BuildableId") :: string]
	if def == nil then
		return nil
	end
	local pivot = counter:GetPivot()
	local cf = pivot * CFrame.new(0, -def.size.y / 2, def.size.z / 2 + CFG.CounterGap + (position - 1) * CFG.QueueSpacing)
	return cf.Position
end

-- Path into the trap house: front door -> top of the stairs -> bottom of the stairs (plot Waypoints).
local function routeIn(stash: Stash): { Vector3 }
	local route = {}
	local waypoints = stash.plot:FindFirstChild("Waypoints")
	for _, name in { "Door", "StairsTop", "StairsBottom" } do
		local wp = waypoints and waypoints:FindFirstChild(name)
		if wp and wp:IsA("BasePart") then
			table.insert(route, wp.Position)
		end
	end
	if #route == 0 then -- plot without a house: walk to its street edge
		local origin = PlotUtil.GetOrigin(stash.plot)
		local _, sizeZ = PlotUtil.GetSize(stash.plot)
		table.insert(route, (origin * CFrame.new(0, 0, sizeZ / 2 + 3)).Position)
	end
	return route
end

-- One of the two customer spawns closest to the house door.
local function pickSpawn(stash: Stash): Vector3
	local door = routeIn(stash)[1]
	local city = workspace:FindFirstChild("City")
	local spawns = city and city:FindFirstChild("CustomerSpawns")
	local candidates = {}
	if spawns then
		for _, s in spawns:GetChildren() do
			if s:IsA("BasePart") then
				table.insert(candidates, s.Position)
			end
		end
	end
	if #candidates == 0 then
		return door + Vector3.new(rng:NextNumber(-40, 40), 0, 12)
	end
	table.sort(candidates, function(a, b)
		return (a - door).Magnitude < (b - door).Magnitude
	end)
	return candidates[rng:NextInteger(1, math.min(2, #candidates))]
end

-- Behaviour ----------------------------------------------------------------------

function CustomerService.Say(npc: Npc, text: string)
	local say = npc.sayLabel
	if say == nil then
		return
	end
	npc.sayToken += 1
	local token = npc.sayToken
	say.Text = text
	say.Visible = true
	task.delay(3.5, function()
		if npc.sayToken == token and say.Parent then
			say.Visible = false
		end
	end)
end

function CustomerService.SayLine(npc: Npc, key: string, ...: any)
	local line = pickLine(key)
	if select("#", ...) > 0 then
		line = string.format(line, ...)
	end
	CustomerService.Say(npc, line)
end

local function destroyNpc(npc: Npc)
	npcsById[npc.id] = nil
	local stash = stashes[npc.owner]
	if stash then
		stash.npcs[npc.id] = nil
		stash.queue:Leave(npc.id)
	end
	npc.model:Destroy()
end

-- Makes the customer leave. `lineKey` = a Messages.CustomerLines key, or nil to leave silently.
function CustomerService.Dismiss(npc: Npc, lineKey: string?, leaveDelay: number?)
	if npc.state == "Leaving" then
		return
	end
	npc.state = "Leaving"
	npc.pending = nil
	npc.leaveDelay = leaveDelay
	if lineKey == "Angry" then
		AnimServer.Play(npc.model, "ShakeHead")
	end
	-- after a deal the customer stays at the counter a while (leaveDelay): it keeps its place in the
	-- line until it walks away, so the next one does not walk into it
	local stash = stashes[npc.owner]
	if stash and leaveDelay == nil then
		stash.queue:Leave(npc.id)
	end
	if npc.prompt then
		npc.prompt.Enabled = false
	end
	if lineKey then
		CustomerService.SayLine(npc, lineKey)
	end
end

function CustomerService.GetCustomer(id: any): Npc?
	if type(id) ~= "string" then
		return nil
	end
	return npcsById[id]
end

-- True when the customer is first in line, standing at the counter and not leaving.
function CustomerService.IsReady(npc: Npc): boolean
	local stash = stashes[npc.owner]
	return npc.state == "Queued" and npc.frontSince ~= nil and stash ~= nil and stash.queue:Front() == npc.id
end

-- The middle of the top of the player's counter (the first-person sale lays things on it).
function CustomerService.CounterTop(owner: Player): Vector3?
	local stash = stashes[owner]
	local counter = stash and stash.counter
	if counter == nil or counter.Parent == nil then
		return nil
	end
	local def = Buildables.ById[counter:GetAttribute("BuildableId") :: string]
	if def == nil then
		return nil
	end
	return (counter:GetPivot() * CFrame.new(0, def.size.y / 2, 0)).Position
end

function CustomerService.WaitedSeconds(npc: Npc): number
	return if npc.frontSince then os.clock() - npc.frontSince else 0
end

function CustomerService.PenalizePatience(npc: Npc, seconds: number)
	npc.patienceLeft = math.max(0, npc.patienceLeft - seconds)
end

function CustomerService.GetCombo(owner: Player): ComboTracker.ComboTracker?
	local stash = stashes[owner]
	return stash and stash.combo
end

local function faceCounter(npc: Npc, stash: Stash)
	local counter = stash.counter
	if counter == nil then
		return
	end
	local target = counter:GetPivot().Position
	local pos = npc.root.Position
	npc.root.CFrame = CFrame.lookAt(pos, Vector3.new(target.X, pos.Y, target.Z))
end

local function runNpc(stash: Stash, npc: Npc)
	local function cancelled(): boolean
		return npc.state == "Leaving" or not stash.alive
	end

	-- 1. walk to the house, in through the front door and down to the basement
	for _, wp in routeIn(stash) do
		if cancelled() then
			break
		end
		NpcMover.WalkTo(npc.humanoid, npc.root, wp, CFG.MaxWalkSeconds, cancelled)
	end

	-- 2. queue: walk to the slot, move up when the line advances
	if not cancelled() then
		npc.state = "Queued"
	end
	local walkStarted = os.clock()
	while not cancelled() do
		local position = stash.queue:PositionOf(npc.id)
		local target = if position then slotPosition(stash, position) else nil
		if position == nil or target == nil then
			CustomerService.Dismiss(npc, nil)
			break
		end
		if flatDistance(npc.root.Position, target) > 2.5 then
			if npc.prompt then
				npc.prompt.Enabled = false
			end
			local reached = NpcMover.WalkTo(npc.humanoid, npc.root, target, 12, cancelled)
			if not reached and npc.frontSince == nil and os.clock() - walkStarted > CFG.MaxWalkSeconds then
				CustomerService.Dismiss(npc, nil) -- stuck (walled-in counter...)
			end
		else
			faceCounter(npc, stash)
			if position == 1 then
				if npc.frontSince == nil then
					npc.frontSince = os.clock()
					CustomerService.SayLine(npc, "Greet")
					AnimServer.Emote(npc.humanoid, "Wave")
				end
				if npc.prompt then
					npc.prompt.Enabled = true
				end
			end
			task.wait(0.3)
		end
	end

	-- 3. leave the way it came, then vanish
	if stash.alive and npc.model.Parent then
		task.wait(npc.leaveDelay or 1.5)
		stash.queue:Leave(npc.id) -- frees the counter for the next customer
		local function gone(): boolean
			return not stash.alive
		end
		local route = routeIn(stash)
		for i = #route, 1, -1 do -- back up the stairs and out of the door
			if gone() then
				break
			end
			NpcMover.WalkTo(npc.humanoid, npc.root, route[i], CFG.MaxWalkSeconds, gone)
		end
		NpcMover.WalkTo(npc.humanoid, npc.root, npc.exit, CFG.MaxWalkSeconds, gone)
	end
	destroyNpc(npc)
end

local function spawnCustomer(stash: Stash)
	nextId += 1
	local id = "c" .. nextId
	if stash.queue:Join(id) == nil then
		return
	end
	local isNight = ReplicatedStorage:GetAttribute("Phase") == "Night"
	local data = Customer.Generate(rng :: any, CFG, isNight)

	task.spawn(function()
		local model = makeCustomerModel()
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
		if humanoid == nil or root == nil or not stash.alive then
			stash.queue:Leave(id)
			model:Destroy()
			return
		end
		local spawnPos = pickSpawn(stash)
		model.Name = "Customer"
		humanoid.WalkSpeed = CFG.WalkSpeed
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.CollisionGroup = CUSTOMER_GROUP
			end
		end
		model:SetAttribute("CustomerId", id)
		CollectionService:AddTag(model, "Npc") -- body dynamics on the clients (BodyController)
		model:SetAttribute("OwnerUserId", stash.owner.UserId)
		model:SetAttribute("Personality", data.personality)
		model:PivotTo(CFrame.new(spawnPos + Vector3.new(0, 3, 0)))

		local npc: Npc = {
			id = id,
			owner = stash.owner,
			data = data,
			model = model,
			humanoid = humanoid,
			root = root,
			state = "Arriving",
			frontSince = nil,
			patienceLeft = data.patience,
			pending = nil,
			exit = spawnPos,
			sayToken = 0,
		}
		buildBillboard(npc)

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "DealPrompt"
		prompt.ActionText = "Deal"
		prompt.ObjectText = (Messages.PersonalityNames :: any)[data.personality] or data.personality
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.Enabled = false
		prompt.Parent = root
		npc.prompt = prompt

		model.Parent = customersFolder()
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
		local animate = model:FindFirstChild("Animate")
		if animate then
			animate:Destroy() -- LocalScripts don't run on NPCs: the server animates them
		end
		AnimServer.SetupNpc(humanoid)

		stash.npcs[id] = npc
		npcsById[id] = npc
		runNpc(stash, npc)
	end)
end

-- Main loop ----------------------------------------------------------------------

local function refreshCounter(player: Player)
	local stash = stashes[player]
	if stash then
		stash.counter = BuildService.GetModelsWithRole(player, "Counter")[1]
	end
end

local function tick(dt: number)
	local now = os.clock()
	for _, stash in stashes do
		if stash.counter == nil or stash.counter.Parent == nil then
			refreshCounter(stash.owner)
		end
		if stash.counter and now >= stash.nextSpawnAt and not stash.queue:IsFull() then
			stash.nextSpawnAt = now + rng:NextNumber(CFG.SpawnIntervalMin, CFG.SpawnIntervalMax)
			spawnCustomer(stash)
		end
		local frontId = stash.queue:Front()
		local front = frontId and stash.npcs[frontId]
		if front and CustomerService.IsReady(front) then
			front.patienceLeft -= dt
			local ratio = math.clamp(front.patienceLeft / front.data.patience, 0, 1)
			if front.bar then
				front.bar.Size = UDim2.fromScale(ratio, 1)
				front.bar.BackgroundColor3 = if ratio > 0.5
					then hex("#39FF88")
					elseif ratio > 0.25 then hex("#FFB020")
					else hex("#FF4D4D")
			end
			if front.patienceLeft <= 0 then
				CustomerService.Dismiss(front, "Angry")
			end
		end
	end
end

local function onPlotAssigned(player: Player, plot: Instance)
	stashes[player] = {
		owner = player,
		plot = plot,
		queue = CustomerQueue.new(CFG.MaxQueue),
		npcs = {},
		nextSpawnAt = os.clock() + 5,
		combo = ComboTracker.new(Economy.Combo),
		counter = nil,
		alive = true,
	}
	refreshCounter(player)
end

local function onPlotReleased(player: Player)
	local stash = stashes[player]
	stashes[player] = nil
	if stash then
		stash.alive = false
		for _, npc in stash.npcs do
			npcsById[npc.id] = nil
			npc.model:Destroy()
		end
	end
end

function CustomerService:Start()
	setupCollisionGroups()
	PlotService.OnPlotAssigned(onPlotAssigned)
	PlotService.OnPlotReleased(onPlotReleased)
	BuildService.OnStashChanged(refreshCounter)
	while true do
		local dt = task.wait(0.25)
		xpcall(tick, function(err)
			warn("[CustomerService] " .. tostring(err))
		end, dt)
	end
end

return CustomerService

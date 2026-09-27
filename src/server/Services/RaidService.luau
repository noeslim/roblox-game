--!strict
-- Heat and raids (GAME_DESIGN §8). Each stash has a saved heat gauge (Logic/Heat): contraband
-- sales, night sales, angry customers and contraband left in sight make it rise; time makes it
-- fall. At the Raid threshold: sirens and a countdown to hide the stock in secret compartments
-- (Logic/Raid), then inspectors come down and search; what they find is seized, plus a fine.
-- Published: player attributes Heat, HeatLevel, RaidPhase ("Warning" / "Search"), RaidEndsAt
-- (server time); plot attribute RaidPhase (police lights for everyone around).
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Parts = require(Shared.Config.Parts)
local Buildables = require(Shared.Config.Buildables)
local Messages = require(Shared.Config.Messages)
local RaidConfig = require(Shared.Config.Raid)
local Heat = require(Shared.Logic.Heat)
local Raid = require(Shared.Logic.Raid)
local WeaponCrafting = require(Shared.Logic.WeaponCrafting)
local DataService = require(script.Parent.DataService)
local BuildService = require(script.Parent.BuildService)
local PlotService = require(script.Parent.PlotService)
local CustomerService = require(script.Parent.CustomerService)
local ServerNet = require(script.Parent.Parent.Lib.ServerNet)
local AnimServer = require(script.Parent.Parent.Lib.AnimServer)
local NpcMover = require(script.Parent.Parent.Lib.NpcMover)

local RaidService = {}

local CFG = Economy.Heat
local LOOK = RaidConfig.Inspector
local rng = Random.new()

type ActiveRaid = { startedAt: number, plan: Raid.Plan, forced: boolean, inspectors: { Model } }
type State = { heat: Heat.HeatState, level: string, raid: ActiveRaid? }

local states: { [Player]: State } = {}

local function hex(s: string): Color3
	return Color3.fromHex(s)
end

local notify = ServerNet.Notify

-- Stash contents ---------------------------------------------------------------------

-- Hidden part counts can never be above what is left (parts are used by crafting).
local function clampHidden(data: any)
	for id, n in data.HiddenParts do
		local have = data.Parts[id] or 0
		if have <= 0 then
			data.HiddenParts[id] = nil
		elseif n > have then
			data.HiddenParts[id] = have
		end
	end
end

local function compartments(player: Player): { Raid.Compartment }
	local list: { Raid.Compartment } = {}
	local hideout = BuildService.GetHideout(player)
	if hideout then
		for _, o in hideout:GetObjects() do
			local def = Buildables.ById[o.buildableId]
			if def and def.hide then
				table.insert(list, { level = def.hide.level, capacity = def.hide.capacity })
			end
		end
	end
	return list
end

local function stashItems(player: Player, data: any): { Raid.Item }
	clampHidden(data)
	local brand = DataService.GetBrand(player)
	local weapons: { Raid.WeaponInfo } = {}
	for _, w in data.Weapons do
		local crafted = WeaponCrafting.Craft(w.parts, brand, Parts, Economy)
		if crafted then
			table.insert(weapons, { id = w.id, value = crafted.value, contraband = crafted.contraband, hidden = w.hidden })
		end
	end
	return Raid.Items(weapons, data.Parts, data.HiddenParts, Parts)
end

-- Gauge ------------------------------------------------------------------------------

local function publish(player: Player, state: State)
	player:SetAttribute("Heat", math.floor(state.heat.value + 0.5))
	player:SetAttribute("HeatLevel", state.level)
	local data = DataService.GetData(player)
	if data then
		data.Heat.Value = state.heat.value
	end
end

local startRaid: (Player, State, boolean) -> ()
local lookAtDoor: (Player) -> ()

-- Level changes: a word to the owner, a lone inspector at the door when they start watching.
local function refreshLevel(player: Player, state: State)
	local level = Heat.GetLevel(state.heat, CFG)
	local order: { [string]: number } = { Clear = 0, Patrol = 1, Investigation = 2, Raid = 3 }
	local rising = order[level] > order[state.level]
	state.level = level
	publish(player, state)
	if rising and state.raid == nil then
		if level == "Patrol" then
			notify(player, Messages.Raid.Patrol, "warning")
		elseif level == "Investigation" then
			notify(player, Messages.Raid.Investigation, "warning")
			task.spawn(lookAtDoor, player)
		end
	end
end

-- Adds heat for a reason of Economy.Heat.Gains (SaleService, customer complaints...).
function RaidService.AddHeat(player: Player, reason: string, count: number?)
	local state = states[player]
	if state == nil then
		return
	end
	Heat.Add(state.heat, reason, CFG, count)
	refreshLevel(player, state)
end

-- Inspectors -------------------------------------------------------------------------

local function inspectorsFolder(): Instance
	local f = workspace:FindFirstChild("Inspectors")
	if f == nil then
		f = Instance.new("Folder")
		f.Name = "Inspectors"
		f.Parent = workspace
	end
	return f :: Instance
end

local function makeInspector(): (Model?, Humanoid?, BasePart?)
	local skin = hex(LOOK.Skin[rng:NextInteger(1, #LOOK.Skin)])
	local model, humanoid, root = CustomerService.MakeNpc("Inspector", skin, hex(LOOK.Shirt), hex(LOOK.Pants), inspectorsFolder())
	if model == nil or humanoid == nil or root == nil then
		return nil, nil, nil
	end
	humanoid.WalkSpeed = LOOK.WalkSpeed
	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		local cap = Instance.new("Part")
		cap.Name = "Cap"
		cap.Size = Vector3.new(1.25, 0.35, 1.35)
		cap.Color = hex(LOOK.Cap)
		cap.Material = Enum.Material.Fabric
		cap.CanCollide = false
		cap.Massless = true
		cap.CFrame = head.CFrame * CFrame.new(0, head.Size.Y / 2 + 0.1, -0.05)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = head
		weld.Part1 = cap
		weld.Parent = cap
		cap.Parent = model
	end
	return model, humanoid, root
end

local function walkOut(humanoid: Humanoid, root: BasePart, route: { Vector3 }, model: Model)
	for i = #route, 1, -1 do
		if model.Parent == nil then
			return
		end
		NpcMover.WalkTo(humanoid, root, route[i], 8)
	end
	model:Destroy()
end

-- Level Investigation: one inspector comes to the front door, looks around, leaves.
lookAtDoor = function(player: Player)
	local route = CustomerService.RouteIn(player)
	if #route == 0 then
		return
	end
	local door = route[1]
	local model, humanoid, root = makeInspector()
	if model == nil or humanoid == nil or root == nil then
		return
	end
	model:PivotTo(CFrame.new(door + Vector3.new(rng:NextNumber(-10, 10), 3, 14)))
	NpcMover.WalkTo(humanoid, root, door, 12)
	AnimServer.Play(model, "LookAround")
	task.wait(LOOK.InvestigationLookSeconds)
	if model.Parent then
		NpcMover.WalkTo(humanoid, root, door + Vector3.new(0, 0, 18), 10)
		model:Destroy()
	end
end

-- Places to search: secret compartments, displays and storage first, then anything.
local function searchSpots(player: Player): { Vector3 }
	local spots = {}
	local hideout = BuildService.GetHideout(player)
	if hideout == nil then
		return spots
	end
	for _, o in hideout:GetObjects() do
		local def = Buildables.ById[o.buildableId]
		local model = BuildService.GetModel(player, o.id)
		if def and model and (def.hide or def.role == "Display" or def.role == "Storage" or def.role == "Workbench") then
			table.insert(spots, model:GetPivot().Position)
		end
	end
	for i = #spots, 2, -1 do -- shuffle
		local j = rng:NextInteger(1, i)
		spots[i], spots[j] = spots[j], spots[i]
	end
	return spots
end

local function sendInspectors(player: Player, raid: ActiveRaid)
	local route = CustomerService.RouteIn(player)
	if #route == 0 then
		return
	end
	local spots = searchSpots(player)
	for n = 1, CFG.InspectorCount do
		task.spawn(function()
			local model, humanoid, root = makeInspector()
			if model == nil or humanoid == nil or root == nil then
				return
			end
			table.insert(raid.inspectors, model)
			model:PivotTo(CFrame.new(route[1] + Vector3.new((n - 1.5) * 3, 3, 4)))
			local function over(): boolean
				local state = states[player]
				return model.Parent == nil or state == nil or state.raid ~= raid
			end
			for _, wp in route do
				if over() then
					break
				end
				NpcMover.WalkTo(humanoid, root, wp, 8)
			end
			local stops = 0
			local i = n
			while not over() and stops < LOOK.MaxStops and #spots > 0 do
				local spot = spots[(i - 1) % #spots + 1]
				i += CFG.InspectorCount
				stops += 1
				NpcMover.WalkTo(humanoid, root, spot + (root.Position - spot).Unit * 3, 6)
				AnimServer.Face(root, spot)
				AnimServer.Play(model, if stops % 2 == 0 then "Inspect" else "LookAround")
				task.wait(LOOK.LookSeconds)
			end
		end)
	end
end

local function clearInspectors(player: Player, raid: ActiveRaid)
	local route = CustomerService.RouteIn(player)
	for _, model in raid.inspectors do
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
		if humanoid and root and #route > 0 and player.Parent == Players then
			task.spawn(walkOut, humanoid, root, route, model)
			task.delay(30, function()
				if model.Parent then
					model:Destroy()
				end
			end)
		else
			model:Destroy()
		end
	end
	raid.inspectors = {}
end

-- Raids ------------------------------------------------------------------------------

local function setPhase(player: Player, phase: string?, endsAt: number?)
	player:SetAttribute("RaidPhase", phase)
	player:SetAttribute("RaidEndsAt", endsAt)
	local plot = PlotService.GetPlot(player)
	if plot then
		plot:SetAttribute("RaidPhase", phase)
	end
end

-- Seizes what the search finds, takes the fine, reports. `fled`: resolved at the next join.
local function resolve(player: Player, state: State, fled: boolean)
	local data = DataService.GetData(player)
	local ledger = DataService.GetLedger(player)
	if data == nil or ledger == nil then
		return
	end
	local items = Raid.Allocate(stashItems(player, data), compartments(player))
	local hiddenBefore = 0
	for _, item in items do
		if item.hidden then
			hiddenBefore += 1
		end
	end
	local result = Heat.ResolveRaid(state.heat, items :: any, rng :: any, os.time(), CFG)
	local seizedWeapons, seizedParts, seizedHidden = Raid.Group(result.seized)

	local lines = {}
	for i = #data.Weapons, 1, -1 do
		local w = data.Weapons[i]
		if seizedWeapons[w.id] then
			table.insert(lines, w.name or "Blaster")
			table.remove(data.Weapons, i)
		end
	end
	for id, n in seizedParts do
		data.Parts[id] = (data.Parts[id] or 0) - n
		if data.Parts[id] <= 0 then
			data.Parts[id] = nil
		end
		if data.HiddenParts[id] then
			data.HiddenParts[id] -= seizedHidden[id] or 0
		end
		local def = Parts[id]
		table.insert(lines, ("%s x%d"):format(if def then def.name else id, n))
	end
	clampHidden(data)
	local savedHidden = hiddenBefore
	for _, item in result.seized do
		if item.hidden then
			savedHidden -= 1
		end
	end
	local fine = if result.fine > 0 then ledger:TakeUpTo(result.fine, "raid:fine") else 0

	data.Heat.LastRaidAt = os.time()
	data.Heat.PendingRaid = false
	state.level = Heat.GetLevel(state.heat, CFG)
	publish(player, state)
	DataService.Sync(player)
	ServerNet.FireClient("RaidReport", player, {
		lines = lines,
		seizedValue = result.seizedValue,
		fine = fine,
		saved = savedHidden,
		fled = fled,
	})
	print(("[RaidService] raid on %s: %d seized ($%d), fine $%d, %d stayed hidden"):format(player.Name, #result.seized, result.seizedValue, fine, savedHidden))
end

startRaid = function(player: Player, state: State, forced: boolean)
	local data = DataService.GetData(player)
	if data == nil or state.raid ~= nil then
		return
	end
	local plan = Raid.Plan(CFG)
	local raid: ActiveRaid = { startedAt = os.clock(), plan = plan, forced = forced, inspectors = {} }
	state.raid = raid
	data.Heat.PendingRaid = true -- leaving now does not escape it
	local now = workspace:GetServerTimeNow()
	setPhase(player, "Warning", now + plan.search)
	CustomerService.DismissAll(player, "Cops")
	print(("[RaidService] raid on %s (heat %d)"):format(player.Name, math.floor(state.heat.value)))

	task.delay(plan.search, function()
		if state.raid ~= raid or player.Parent ~= Players then
			return
		end
		setPhase(player, "Search", workspace:GetServerTimeNow() + (plan.total - plan.search))
		sendInspectors(player, raid)
	end)
	task.delay(plan.total, function()
		if state.raid ~= raid or player.Parent ~= Players then
			return
		end
		resolve(player, state, false)
		state.raid = nil
		setPhase(player, nil, nil)
		clearInspectors(player, raid)
	end)
end

-- Hiding ----------------------------------------------------------------------------

local function hideStock(player: Player, compartmentName: string)
	local state = states[player]
	local data = DataService.GetData(player)
	if state == nil or data == nil then
		return
	end
	if state.raid and player:GetAttribute("RaidPhase") == "Search" then
		notify(player, Messages.Raid.TooLate, "error")
		return
	end
	local comps = compartments(player)
	local items = stashItems(player, data)
	local pick = Raid.PickToHide(items, comps)
	if #pick == 0 then
		local visible = Raid.CountVisible(items, comps)
		notify(player, if visible > 0 then Messages.Raid.NoRoom else Messages.Raid.NothingToHide, if visible > 0 then "warning" else "info")
		return
	end
	for _, item in pick do
		if item.kind == "weapon" then
			for _, w in data.Weapons do
				if w.id == item.ref then
					w.hidden = true
				end
			end
		else
			data.HiddenParts[item.ref] = (data.HiddenParts[item.ref] or 0) + 1
		end
	end
	clampHidden(data)
	notify(player, Messages.Raid.Hidden:format(#pick, compartmentName), "success")
	DataService.Sync(player)
end

local function onPrompt(prompt: ProximityPrompt, player: Player)
	if prompt.Name ~= "HidePrompt" then
		return
	end
	local model = prompt:FindFirstAncestorOfClass("Model")
	if model == nil or model:GetAttribute("OwnerUserId") ~= player.UserId then
		return
	end
	local root = model.PrimaryPart
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root == nil or hrp == nil or (hrp.Position - root.Position).Magnitude > prompt.MaxActivationDistance + 4 then
		return
	end
	hideStock(player, prompt.ObjectText)
end

-- Loop -------------------------------------------------------------------------------

local function tick(dt: number)
	local isNight = ReplicatedStorage:GetAttribute("Phase") == "Night"
	for player, state in states do
		local data = DataService.GetData(player)
		if data and BuildService.GetHideout(player) then
			if data.Heat.PendingRaid and state.raid == nil then
				notify(player, Messages.Raid.Fled, "error")
				resolve(player, state, true)
			elseif state.raid == nil then
				local visible = Raid.CountVisible(stashItems(player, data), compartments(player))
				Heat.Tick(state.heat, dt, { isNight = isNight, visibleContraband = visible }, CFG)
				refreshLevel(player, state)
				if Heat.CanRaid(state.heat, os.time(), data.Level, CFG) then
					startRaid(player, state, false)
				end
			end
		end
	end
end

-- Studio only, from the command bar (Server view):
--   game.Players.NAME:SetAttribute("DebugHeat", 70)   -- sets the gauge
--   game.Players.NAME:SetAttribute("DebugRaid", true) -- raid now (ignores protection and cooldown)
local function watchDebug(player: Player)
	if not RunService:IsStudio() then
		return
	end
	player:GetAttributeChangedSignal("DebugHeat"):Connect(function()
		local value = player:GetAttribute("DebugHeat")
		local state = states[player]
		if type(value) == "number" and state then
			state.heat.value = math.clamp(value, 0, CFG.Max)
			refreshLevel(player, state)
			player:SetAttribute("DebugHeat", nil)
		end
	end)
	player:GetAttributeChangedSignal("DebugRaid"):Connect(function()
		local state = states[player]
		if player:GetAttribute("DebugRaid") == true and state then
			player:SetAttribute("DebugRaid", nil)
			startRaid(player, state, true)
		end
	end)
end

local function onLoaded(player: Player)
	local data = DataService.GetData(player)
	if data == nil then
		return
	end
	local heat = Heat.new()
	heat.value = data.Heat.Value
	heat.lastRaidAt = if data.Heat.LastRaidAt > 0 then data.Heat.LastRaidAt else nil
	local state: State = { heat = heat, level = Heat.GetLevel(heat, CFG), raid = nil }
	states[player] = state
	publish(player, state)
	watchDebug(player)
end

function RaidService:Start()
	DataService.OnPlayerLoaded(onLoaded)
	Players.PlayerRemoving:Connect(function(player)
		local state = states[player]
		states[player] = nil
		if state and state.raid then
			-- PendingRaid stays saved: the raid is resolved at the next join
			for _, model in state.raid.inspectors do
				model:Destroy()
			end
		end
	end)
	PlotService.OnPlotReleased(function(_, plot)
		plot:SetAttribute("RaidPhase", nil)
	end)
	CustomerService.OnComplaint(function(owner)
		RaidService.AddHeat(owner, "CustomerComplaint")
	end)
	ProximityPromptService.PromptTriggered:Connect(onPrompt)
	task.spawn(function()
		while true do
			task.wait(CFG.TickSeconds)
			tick(CFG.TickSeconds)
		end
	end)
end

return RaidService

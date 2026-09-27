--!strict
-- Free building in the player's stash. The client only sends intentions; everything is checked
-- here with Logic/Hideout (plot bounds, collisions, object limit) and the player's Ledger.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Buildables = require(Shared.Config.Buildables)
local RaidConfig = require(Shared.Config.Raid)
local Hideout = require(Shared.Logic.Hideout)
local ModelFactory = require(Shared.Visual.ModelFactory)
local PlotUtil = require(Shared.Visual.PlotUtil)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local ServerNet = require(script.Parent.Parent.Lib.ServerNet)

local BuildService = {}

type Stash = {
	plot: Instance,
	hideout: Hideout.Hideout,
	models: { [string]: Model },
}

local stashes: { [Player]: Stash } = {}
local changedCallbacks: { (Player) -> () } = {}

local B = Economy.Building
local OPTIONS: Hideout.Options = {
	gridSize = B.GridSize,
	rotationStep = B.RotationStep,
	maxObjects = B.MaxObjects,
}

local function plotDims(plot: Instance)
	local sx, sz, h = PlotUtil.GetSize(plot)
	return { sizeX = sx, sizeZ = sz, maxHeight = h }
end

local function addPrompt(model: Model, name: string, actionText: string, objectText: string): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = model.PrimaryPart
	return prompt
end

local function spawnModel(player: Player, stash: Stash, obj: Hideout.Object)
	local def = Buildables.ById[obj.buildableId]
	local model = ModelFactory.Buildable(def)
	model:PivotTo(PlotUtil.ObjectCFrame(PlotUtil.GetOrigin(stash.plot), def.size.y, obj.x, obj.z, obj.rotation))
	model:SetAttribute("ObjectId", obj.id)
	model:SetAttribute("BuildableId", obj.buildableId)
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("X", obj.x)
	model:SetAttribute("Z", obj.z)
	model:SetAttribute("Rotation", obj.rotation)
	if def.role == "Workbench" then
		addPrompt(model, "WorkbenchPrompt", "Use Workbench", "Workbench")
	end
	if def.hide then -- RaidService hides the contraband in it
		local prompt = addPrompt(model, "HidePrompt", "Hide stock", def.name)
		prompt.HoldDuration = RaidConfig.HideHoldSeconds
	end
	model.Parent = stash.plot:WaitForChild("Objects")
	stash.models[obj.id] = model
end

local function save(player: Player, stash: Stash)
	local data = DataService.GetData(player)
	if data then
		data.Hideout.Objects = stash.hideout:Serialize()
	end
	for _, callback in changedCallbacks do
		task.spawn(callback, player)
	end
end

local function onPlotAssigned(player: Player, plot: Instance)
	local data = DataService.GetData(player)
	if data == nil then
		return
	end
	local hideout, dropped = Hideout.Load(data.Hideout.Objects, plotDims(plot), OPTIONS, Buildables.ById)
	local stash: Stash = { plot = plot, hideout = hideout, models = {} }
	stashes[player] = stash
	for _, obj in hideout:GetObjects() do
		spawnModel(player, stash, obj)
	end
	if dropped > 0 then
		warn(("[BuildService] dropped %d invalid objects from %s's stash"):format(dropped, player.Name))
		save(player, stash)
	else
		for _, callback in changedCallbacks do
			task.spawn(callback, player)
		end
	end
end

local function onPlotReleased(player: Player, plot: Instance)
	local stash = stashes[player]
	stashes[player] = nil
	if stash then
		for _, model in stash.models do
			model:Destroy()
		end
	end
	local objects = plot:FindFirstChild("Objects")
	if objects then
		objects:ClearAllChildren()
	end
end

local function getStash(player: Player): (Stash?, string?)
	if not DataService.IsLoaded(player) then
		return nil, "NotLoaded"
	end
	local stash = stashes[player]
	if stash == nil then
		return nil, "NoPlot"
	end
	return stash, nil
end

local function place(player: Player, buildableId: any, x: any, z: any, rotation: any): (boolean, any)
	local stash, err = getStash(player)
	if stash == nil then
		return false, err
	end
	local ok, placeErr = stash.hideout:Validate(buildableId, x, z, rotation)
	if not ok then
		return false, placeErr
	end
	local def = Buildables.ById[buildableId]
	local ledger = DataService.GetLedger(player)
	if ledger == nil then
		return false, "NotLoaded"
	end
	local paid, payErr = ledger:Withdraw(def.price, "build:" .. def.id)
	if not paid then
		return false, payErr
	end
	local obj = stash.hideout:Place(buildableId, x, z, rotation)
	if obj == nil then -- cannot happen after Validate, but never keep the money
		ledger:Deposit(def.price, "refund")
		return false, "ServerError"
	end
	spawnModel(player, stash, obj)
	save(player, stash)
	return true, obj.id
end

local function move(player: Player, objectId: any, x: any, z: any, rotation: any): (boolean, any)
	local stash, err = getStash(player)
	if stash == nil then
		return false, err
	end
	local obj, moveErr = stash.hideout:Move(objectId, x, z, rotation)
	if obj == nil then
		return false, moveErr
	end
	local model = stash.models[obj.id]
	if model then
		local def = Buildables.ById[obj.buildableId]
		model:PivotTo(PlotUtil.ObjectCFrame(PlotUtil.GetOrigin(stash.plot), def.size.y, obj.x, obj.z, obj.rotation))
		model:SetAttribute("X", obj.x)
		model:SetAttribute("Z", obj.z)
		model:SetAttribute("Rotation", obj.rotation)
	end
	save(player, stash)
	return true, obj.id
end

local function remove(player: Player, objectId: any): (boolean, any)
	local stash, err = getStash(player)
	if stash == nil then
		return false, err
	end
	local obj, removeErr = stash.hideout:Remove(objectId)
	if obj == nil then
		return false, removeErr
	end
	local model = stash.models[obj.id]
	stash.models[obj.id] = nil
	if model then
		model:Destroy()
	end
	local def = Buildables.ById[obj.buildableId]
	local refund = math.floor(def.price * B.SellRefundRate)
	local ledger = DataService.GetLedger(player)
	if refund > 0 and ledger then
		ledger:Deposit(refund, "sell:" .. def.id)
	end
	save(player, stash)
	return true, refund
end

function BuildService:Start()
	PlotService.OnPlotAssigned(onPlotAssigned)
	PlotService.OnPlotReleased(onPlotReleased)
	ServerNet.Handle("RequestPlace", place)
	ServerNet.Handle("RequestMove", move)
	ServerNet.Handle("RequestRemove", remove)
end

function BuildService.GetHideout(player: Player): Hideout.Hideout?
	local stash = stashes[player]
	return stash and stash.hideout
end

function BuildService.GetModel(player: Player, objectId: string): Model?
	local stash = stashes[player]
	return stash and stash.models[objectId]
end

-- Models of the player's objects with a given role ("Counter", "Workbench"...).
function BuildService.GetModelsWithRole(player: Player, role: string): { Model }
	local stash = stashes[player]
	local list = {}
	if stash then
		for _, obj in stash.hideout:FindByRole(role) do
			local model = stash.models[obj.id]
			if model then
				table.insert(list, model)
			end
		end
	end
	return list
end

-- callback(player) runs after the stash is loaded or changed.
function BuildService.OnStashChanged(callback: (Player) -> ())
	table.insert(changedCallbacks, callback)
end

return BuildService

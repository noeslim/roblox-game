--!strict
-- Shows the stock that is not hidden in the stash (Logic/StockLayout): weapons on wall racks and in
-- display cases, the rest piled on supply crates with boxes of contraband parts. What shows here is
-- exactly what the inspectors see and seize in a raid; what is hidden in a secret compartment
-- disappears. Models go in Plot.Stock, contraband ones carry the attribute Contraband = true.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Parts = require(Shared.Config.Parts)
local Buildables = require(Shared.Config.Buildables)
local RaidConfig = require(Shared.Config.Raid)
local StockLayout = require(Shared.Logic.StockLayout)
local WeaponCrafting = require(Shared.Logic.WeaponCrafting)
local ModelFactory = require(Shared.Visual.ModelFactory)
local DataService = require(script.Parent.DataService)
local BuildService = require(script.Parent.BuildService)
local PlotService = require(script.Parent.PlotService)

local StockService = {}

local S = RaidConfig.Stock
local WEAPON = Vector3.new(4, 1.6, 0.5) * S.WeaponScale -- the placeholder weapon's box at this scale
local BOX = Vector3.new(S.BoxSize.x, S.BoxSize.y, S.BoxSize.z)
local ORDER: { [string]: number } = { standing = 1, lying = 2, pile = 3 }

local signatures: { [Player]: string } = {}

type ShowItem = { ref: string, kind: string, contraband: boolean, parts: { [string]: string }?, rarity: string?, count: number? }

local function freeze(model: Model, contraband: boolean, ownerId: number)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	model:SetAttribute("Contraband", contraband)
	model:SetAttribute("OwnerUserId", ownerId)
end

local function partsBox(partId: string, count: number): Model
	local def = Parts[partId]
	local model = Instance.new("Model")
	model.Name = "PartsBox"
	local box = Instance.new("Part")
	box.Name = "Box"
	box.Size = BOX
	box.Color = Color3.fromHex(S.BoxColor)
	box.Material = Enum.Material.Cardboard
	box.Parent = model
	model.PrimaryPart = box
	if def and def.contraband then
		local tape = Instance.new("Part")
		tape.Name = "Tape"
		tape.Size = Vector3.new(BOX.X + 0.02, 0.12, BOX.Z + 0.02)
		tape.Color = Color3.fromHex(S.ContrabandTape)
		tape.Material = Enum.Material.SmoothPlastic
		tape.CFrame = box.CFrame
		tape.Parent = model
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.PixelsPerStud = 60
	gui.LightInfluence = 0.6
	gui.Parent = box
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = Color3.fromHex("#1A1410")
	label.Text = ("%s\nx%d"):format(string.upper(if def then def.name else partId), count)
	label.Parent = gui
	return model
end

-- Everything that shows, in order: contraband weapons, other weapons, then contraband parts.
local function showItems(player: Player, data: any): { ShowItem }
	local brand = DataService.GetBrand(player)
	local dirty: { ShowItem } = {}
	local clean: { ShowItem } = {}
	for _, w in data.Weapons do
		if not w.hidden then
			local crafted = WeaponCrafting.Craft(w.parts, brand, Parts, Economy)
			if crafted then
				local item: ShowItem = { ref = w.id, kind = "weapon", contraband = crafted.contraband, parts = w.parts, rarity = crafted.rarity }
				table.insert(if crafted.contraband then dirty else clean, item)
			end
		end
	end
	for _, item in clean do
		table.insert(dirty, item)
	end
	local ids = {}
	for id in data.Parts do
		table.insert(ids, id)
	end
	table.sort(ids)
	for _, id in ids do
		local def = Parts[id]
		local visible = (data.Parts[id] or 0) - (data.HiddenParts[id] or 0)
		if def and def.contraband and visible > 0 then
			table.insert(dirty, { ref = id, kind = "parts", contraband = true, count = visible })
		end
	end
	return dirty
end

type PlaceInfo = { kind: string, cf: CFrame, slots: { Vector3 } }

local function places(player: Player): { PlaceInfo }
	local list: { PlaceInfo } = {}
	local hideout = BuildService.GetHideout(player)
	if hideout == nil then
		return list
	end
	for _, o in hideout:GetObjects() do
		local def = Buildables.ById[o.buildableId]
		local model = BuildService.GetModel(player, o.id)
		if def and def.stock and model then
			local slots = {}
			for _, v in def.stock.slots do
				table.insert(slots, Vector3.new(v.x, v.y, v.z))
			end
			table.insert(list, { kind = def.stock.kind, cf = model:GetPivot(), slots = slots })
		end
	end
	table.sort(list, function(a, b)
		return (ORDER[a.kind] or 9) < (ORDER[b.kind] or 9)
	end)
	return list
end

function StockService.Refresh(player: Player)
	local data = DataService.GetData(player)
	local plot = PlotService.GetPlot(player)
	if data == nil or plot == nil then
		return
	end
	local items = showItems(player, data)
	local where = places(player)

	local sig = {}
	for _, item in items do
		table.insert(sig, item.ref .. ":" .. tostring(item.count or 1))
	end
	for _, p in where do
		table.insert(sig, tostring(p.cf.Position))
	end
	local signature = table.concat(sig, "|")
	local existing = plot:FindFirstChild("Stock")
	if signatures[player] == signature and existing then
		return
	end
	signatures[player] = signature
	local folder: Instance
	if existing then
		existing:ClearAllChildren()
		folder = existing
	else
		local f = Instance.new("Folder")
		f.Name = "Stock"
		f.Parent = plot
		folder = f
	end

	local layout: { StockLayout.Place } = {}
	for _, p in where do
		table.insert(layout, { kind = p.kind :: any, slots = #p.slots })
	end
	local spots = StockLayout.Assign(items :: any, layout, S.PileLayers)
	local heights: { [string]: number } = {} -- pile top so far, per place and slot
	for _, spot in spots do
		local item: ShowItem = spot.item :: any
		local place = where[spot.place]
		local base = place.cf * CFrame.new(place.slots[spot.slot])
		local model: Model
		if item.kind == "weapon" then
			model = ModelFactory.Weapon(item.parts or {}, Parts, item.rarity, nil)
			model:ScaleTo(S.WeaponScale)
		else
			model = partsBox(item.ref, item.count or 1)
		end
		local height = if item.kind == "weapon" then WEAPON.Z else BOX.Y
		local cf: CFrame
		if place.kind == "standing" then
			cf = base * CFrame.new(0, WEAPON.Y / 2, 0)
		elseif place.kind == "lying" then
			cf = base * CFrame.new(0, WEAPON.Z / 2, 0) * CFrame.Angles(math.rad(90), 0, 0)
		else
			local key = spot.place .. ":" .. spot.slot
			local bottom = heights[key] or 0
			heights[key] = bottom + height + 0.02
			local turn = CFrame.Angles(0, math.rad(S.LayerTurn * (spot.layer - 1)), 0)
			cf = base * CFrame.new(0, bottom + height / 2, 0) * turn
			if item.kind == "weapon" then
				cf *= CFrame.Angles(math.rad(90), 0, 0)
			end
		end
		freeze(model, item.contraband, player.UserId)
		model:PivotTo(cf)
		model.Parent = folder
	end
end

function StockService:Start()
	DataService.OnSynced(StockService.Refresh)
	BuildService.OnStashChanged(StockService.Refresh)
	PlotService.OnPlotAssigned(function(player)
		task.defer(StockService.Refresh, player)
	end)
	PlotService.OnPlotReleased(function(player, plot)
		signatures[player] = nil
		local folder = plot:FindFirstChild("Stock")
		if folder then
			folder:Destroy()
		end
	end)
end

return StockService

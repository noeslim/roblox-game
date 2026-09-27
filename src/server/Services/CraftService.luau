--!strict
-- Workbench: craft a weapon from 5 owned parts, buy parts from the legal supplier, set weapon prices.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Parts = require(Shared.Config.Parts)
local Inventory = require(Shared.Logic.Inventory)
local Shop = require(Shared.Logic.Shop)
local WeaponCrafting = require(Shared.Logic.WeaponCrafting)
local DataService = require(script.Parent.DataService)
local BuildService = require(script.Parent.BuildService)
local GoalsService = require(script.Parent.GoalsService)
local PoiService = require(script.Parent.PoiService)
local ServerNet = require(script.Parent.Parent.Lib.ServerNet)
local AnimServer = require(script.Parent.Parent.Lib.AnimServer)
local MarketService = require(script.Parent.MarketService)

local CraftService = {}

local function nearestWorkbench(player: Player): (Model?, string?)
	local benches = BuildService.GetModelsWithRole(player, "Workbench")
	if #benches == 0 then
		return nil, "NoWorkbench"
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root == nil then
		return nil, "NotNearWorkbench"
	end
	for _, bench in benches do
		if (bench:GetPivot().Position - root.Position).Magnitude <= Economy.Crafting.WorkbenchRange then
			return bench, nil
		end
	end
	return nil, "NotNearWorkbench"
end

local function craft(player: Player, partIds: any): (boolean, any)
	local data = DataService.GetData(player)
	if data == nil then
		return false, "NotLoaded"
	end
	if type(partIds) ~= "table" then
		return false, "InvalidInput"
	end
	-- copy only string -> string entries; WeaponCrafting rejects unknown slots and parts
	local clean: { [string]: string } = {}
	for slot, id in partIds do
		if type(slot) ~= "string" or type(id) ~= "string" then
			return false, "InvalidInput"
		end
		clean[slot] = id
	end
	local bench, benchErr = nearestWorkbench(player)
	if bench == nil then
		return false, benchErr
	end
	local weapon, craftErr = WeaponCrafting.Craft(clean, DataService.GetBrand(player), Parts, Economy)
	if weapon == nil then
		return false, craftErr
	end
	if #data.Weapons >= Economy.Profile.MaxWeapons then
		return false, "TooManyWeapons"
	end
	if not Inventory.RemoveAll(data.Parts, weapon.parts) then
		return false, "MissingParts"
	end

	data.Stats.Crafted += 1
	local saved = {
		id = HttpService:GenerateGUID(false),
		parts = weapon.parts,
		name = WeaponCrafting.DefaultName(weapon, data.Stats.Crafted),
	}
	table.insert(data.Weapons, saved)
	DataService.AddXp(player, Economy.Progression.XpPerCraft)
	DataService.Sync(player)
	GoalsService.Record(player, "craft", 1)
	if (table.find(Economy.RarityOrder, weapon.rarity) or 0) >= (table.find(Economy.RarityOrder, "Rare") or 99) then
		GoalsService.Record(player, "craftRare", 1)
	end

	AnimServer.Play(player.Character, "Assemble") -- the crafter sees the first-person scene
	ServerNet.FireAllClients("CraftFx", bench:GetPivot().Position, weapon.parts, weapon.rarity, weapon.value, player.UserId)
	return true, {
		id = saved.id,
		name = saved.name,
		rarity = weapon.rarity,
		value = weapon.value,
		suggestedPrice = weapon.suggestedPrice,
	}
end

local function isNight(): boolean
	return ReplicatedStorage:GetAttribute("Phase") == "Night"
end

-- source: "supplier" (default: on site, or by phone with the delivery fee) or "blackmarket"
-- (contraband, at night, at the black market only)
local function buyPart(player: Player, partId: any, amount: any, source: any): (boolean, any)
	local data = DataService.GetData(player)
	local ledger = DataService.GetLedger(player)
	if data == nil or ledger == nil then
		return false, "NotLoaded"
	end
	if type(partId) ~= "string" or type(amount) ~= "number" or amount ~= amount then
		return false, "InvalidInput"
	end
	local black = source == "blackmarket"
	local maxAmount = if black then Economy.BlackMarket.MaxBuyPerRequest else Economy.Supplier.MaxBuyPerRequest
	if amount < 1 or amount > maxAmount or math.floor(amount) ~= amount then
		return false, "InvalidAmount"
	end
	local unitPrice: number?
	if black then
		if not isNight() then
			return false, "MarketClosed"
		end
		if not PoiService.IsNear(player, "BlackMarket") then
			return false, "TooFarFromPoi"
		end
		local cost, err = MarketService.Quote(partId, amount)
		if cost == nil then
			return false, err
		end
		unitPrice = cost / amount
	else
		unitPrice = Shop.PartPrice(Parts[partId], Economy, PoiService.IsNear(player, "Supplier"))
	end
	if unitPrice == nil then
		return false, "NotSold"
	end
	if Inventory.Count(data.Parts, partId) + amount > Economy.Profile.MaxPartStack then
		return false, "StackFull"
	end
	local ok, err = ledger:Withdraw(unitPrice * amount, (if black then "blackmarket:" else "supplier:") .. partId)
	if not ok then
		return false, err
	end
	if black then
		MarketService.Record(partId, amount)
	end
	Inventory.Add(data.Parts, partId, amount, Economy.Profile.MaxPartStack)
	DataService.Sync(player)
	return true, Inventory.Count(data.Parts, partId)
end

local function setPrice(player: Player, weaponId: any, price: any): (boolean, any)
	local _, saved, weapon = DataService.FindWeapon(player, weaponId)
	if saved == nil or weapon == nil then
		return false, "UnknownWeapon"
	end
	local ok, err = Shop.ValidatePrice(price, weapon.value, Economy)
	if not ok then
		return false, err
	end
	saved.price = if price == weapon.suggestedPrice then nil else price
	DataService.Sync(player)
	return true, price
end

function CraftService:Start()
	ServerNet.Handle("RequestCraft", craft)
	ServerNet.Handle("RequestBuyPart", buyPart)
	ServerNet.Handle("RequestBlackMarket", function(player: Player)
		if not isNight() then
			return false, "MarketClosed"
		end
		if not PoiService.IsNear(player, "BlackMarket") then
			return false, "TooFarFromPoi"
		end
		return true, MarketService.Offers()
	end)
	ServerNet.Handle("RequestSetPrice", setPrice)
	ServerNet.Handle("RequestSnapshot", function(player: Player)
		return true, DataService.Snapshot(player)
	end)
end

return CraftService

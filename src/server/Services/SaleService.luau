--!strict
-- Selling a weapon to the customer at the counter. Validates everything (owner, distance,
-- weapon ownership, customer ready), applies Logic/Customer decisions, combo and tip.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Customer = require(Shared.Logic.Customer)
local DataService = require(script.Parent.DataService)
local CustomerService = require(script.Parent.CustomerService)
local GoalsService = require(script.Parent.GoalsService)
local RaidService = require(script.Parent.RaidService)
local MarketService = require(script.Parent.MarketService)
local ServerNet = require(script.Parent.Parent.Lib.ServerNet)
local AnimServer = require(script.Parent.Parent.Lib.AnimServer)
local Cinematics = require(Shared.Config.Cinematics)
local DealScene = require(Shared.Logic.DealScene)

local SaleService = {}

local CFG = Economy.Customers
local DEAL = Cinematics.Deal

local function checkCustomer(player: Player, customerId: any): (CustomerService.Npc?, string?)
	local npc = CustomerService.GetCustomer(customerId)
	if npc == nil then
		return nil, "UnknownCustomer"
	end
	if npc.owner ~= player then
		return nil, "NotYourCustomer"
	end
	if not CustomerService.IsReady(npc) then
		return nil, "NotReady"
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root == nil or (root.Position - npc.root.Position).Magnitude > CFG.MaxServeDistance then
		return nil, "TooFar"
	end
	return npc, nil
end

local function completeSale(player: Player, npc: CustomerService.Npc, weaponId: string, price: number): (boolean, any)
	local data = DataService.GetData(player)
	local ledger = DataService.GetLedger(player)
	local index, saved, weapon = DataService.FindWeapon(player, weaponId)
	if data == nil or ledger == nil or index == nil or saved == nil or weapon == nil then
		return false, "UnknownWeapon"
	end

	local tip = Customer.Tip(npc.data, price, CustomerService.WaitedSeconds(npc), CFG)
	local combo = CustomerService.GetCombo(player)
	local multiplier, comboCount = 1, 1
	if combo then
		multiplier, comboCount = combo:RegisterSale(os.clock())
	end
	-- the night street pays more for contraband and for tonight's wanted set (MarketService)
	local premium, premiumWhy = MarketService.SaleMultiplier(saved.parts, weapon.contraband)
	local total = math.floor(price * multiplier * premium + 0.5) + tip

	table.remove(data.Weapons, index)
	ledger:Deposit(total, "sale:" .. weapon.rarity)
	data.Stats.Sold += 1
	data.Stats.Earned += total
	DataService.AddXp(player, Economy.Progression.XpPerSale)
	DataService.Sync(player)
	GoalsService.Record(player, "sale", 1)
	GoalsService.Record(player, "earned", total)
	GoalsService.Record(player, "combo", comboCount)
	if tip > 0 then
		GoalsService.Record(player, "tip", 1)
	end
	if ReplicatedStorage:GetAttribute("Phase") == "Night" then
		GoalsService.Record(player, "saleNight", 1)
		RaidService.AddHeat(player, "NightSale")
	end
	if weapon.contraband then
		RaidService.AddHeat(player, "ContrabandSale")
	end

	-- deal scene, on the timeline of the owner's first-person view (Logic/DealScene): the dealer lays
	-- the weapon down, the customer takes it and inspects it, pays, handshake, the dealer counts
	local dealer = player.Character
	local dealerRoot = dealer and dealer:FindFirstChild("HumanoidRootPart") :: BasePart?
	if dealerRoot then
		AnimServer.Face(npc.root, dealerRoot.Position)
	end
	local parts = table.clone(saved.parts)
	local plan = DealScene.Plan(DEAL)
	local model = npc.model
	local function at(seconds: number, action: () -> ())
		task.delay(seconds, function()
			if model.Parent then
				action()
			end
		end)
	end
	AnimServer.Play(dealer, "HandOver")
	at(plan.inspect, function()
		AnimServer.Play(model, "Inspect")
	end)
	at(plan.inspect + DEAL.HandOffSeconds, function()
		AnimServer.AttachWeapon(model, parts, weapon.rarity)
	end)
	at(plan.pay, function()
		AnimServer.Play(model, "HandOver")
	end)
	at(plan.shake, function()
		AnimServer.Play(model, "Handshake")
		AnimServer.Play(dealer, "Handshake")
	end)
	at(plan.count, function()
		AnimServer.Play(dealer, "CountMoney")
	end)
	CustomerService.Dismiss(npc, "Thanks", plan.total)
	local counterTop = CustomerService.CounterTop(player)
	local info = {
		ownerUserId = player.UserId,
		position = npc.root.Position,
		weaponName = saved.name,
		rarity = weapon.rarity,
		parts = parts,
		customer = model,
		counterTop = counterTop,
		price = price,
		tip = tip,
		multiplier = multiplier,
		premium = premiumWhy, -- { night = x?, hot = x? }
		combo = comboCount,
		total = total,
		big = total >= CFG.BigSaleTotal,
	}
	ServerNet.FireAllClients("SaleFx", info)
	return true, info
end

local function sell(player: Player, customerId: any, weaponId: any): (boolean, any)
	local npc, err = checkCustomer(player, customerId)
	if npc == nil then
		return false, err
	end
	local _, saved, weapon = DataService.FindWeapon(player, weaponId)
	if saved == nil or weapon == nil then
		return false, "UnknownWeapon"
	end
	if not Customer.IsInterested(npc.data, weapon, Economy.RarityOrder) then
		CustomerService.SayLine(npc, "NotInterested")
		AnimServer.Play(npc.model, "ShakeHead")
		return true, { decision = "NotInterested" }
	end

	local price = saved.price or weapon.suggestedPrice
	local decision, counterPrice = Customer.EvaluateOffer(npc.data, price, weapon.suggestedPrice, CFG)
	if decision == "Accept" then
		npc.pending = nil
		local ok, result = completeSale(player, npc, saved.id, price)
		if not ok then
			return false, result
		end
		result.decision = "Accept"
		return true, result
	elseif decision == "Counter" and counterPrice then
		npc.pending = { weaponId = saved.id, price = counterPrice }
		CustomerService.SayLine(npc, "Counter", counterPrice)
		AnimServer.Play(npc.model, "Shrug")
		return true, { decision = "Counter", price = counterPrice }
	end
	npc.pending = nil
	CustomerService.PenalizePatience(npc, CFG.RefusePatiencePenalty)
	CustomerService.SayLine(npc, "Refuse")
	AnimServer.Play(npc.model, "ShakeHead")
	return true, { decision = "Refuse" }
end

local function acceptCounter(player: Player, customerId: any): (boolean, any)
	local npc, err = checkCustomer(player, customerId)
	if npc == nil then
		return false, err
	end
	local pending = npc.pending
	if pending == nil then
		return false, "NoCounterOffer"
	end
	npc.pending = nil
	local ok, result = completeSale(player, npc, pending.weaponId, pending.price)
	if not ok then
		return false, result
	end
	result.decision = "Accept"
	return true, result
end

local function decline(player: Player, customerId: any): (boolean, any)
	local npc = CustomerService.GetCustomer(customerId)
	if npc == nil or npc.owner ~= player then
		return false, "UnknownCustomer"
	end
	if npc.pending then
		npc.pending = nil
		CustomerService.SayLine(npc, "Declined")
	end
	return true, nil
end

function SaleService:Start()
	ServerNet.Handle("RequestSell", sell)
	ServerNet.Handle("RequestAcceptCounter", acceptCounter)
	ServerNet.Handle("RequestDecline", decline)
end

return SaleService

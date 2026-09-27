--!strict
-- Reasons to come back: the daily streak (Logic/DailyReward) and the daily contracts
-- (Logic/Contracts). Services report events with GoalsService.Record(player, event, amount);
-- completed contracts are paid at once. Rewards are in-game cash only.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Messages = require(Shared.Config.Messages)
local Contracts = require(Shared.Logic.Contracts)
local DailyReward = require(Shared.Logic.DailyReward)
local DataService = require(script.Parent.DataService)
local ServerNet = require(script.Parent.Parent.Lib.ServerNet)

local GoalsService = {}

local function today(): number
	return DailyReward.Day(os.time())
end

local function ensure(player: Player): boolean
	local data = DataService.GetData(player)
	if data == nil then
		return false
	end
	return Contracts.Ensure(data.Contracts, today(), player.UserId, Economy.Contracts)
end

-- What the client shows: streak card and contract list.
function GoalsService.Snapshot(player: Player): any
	local data = DataService.GetData(player)
	if data == nil then
		return nil
	end
	local canClaim, nextStreak = DailyReward.Status(data.Daily, today())
	local list = {}
	for _, e in data.Contracts.List do
		local def = Contracts.Find(Economy.Contracts, e.id)
		if def then
			table.insert(list, { id = e.id, text = def.text, progress = e.progress, target = def.target, reward = def.reward, done = e.done })
		end
	end
	return {
		daily = {
			canClaim = canClaim,
			streak = if canClaim then nextStreak else data.Daily.Streak,
			reward = DailyReward.RewardFor(nextStreak, Economy.Daily),
			rewards = Economy.Daily.Rewards,
		},
		contracts = list,
		allDone = Contracts.AllDone(data.Contracts),
		allDoneBonus = Economy.Contracts.AllDoneBonus,
	}
end

function GoalsService.Sync(player: Player)
	local snapshot = GoalsService.Snapshot(player)
	if snapshot then
		ServerNet.FireClient("GoalsSync", player, snapshot)
	end
end

local recordCallbacks: { (Player, string, number, any) -> () } = {}

-- Called for every recorded event (MissionService listens), with the optional info table.
function GoalsService.OnRecord(callback: (Player, string, number, any) -> ())
	table.insert(recordCallbacks, callback)
end

-- event: "sale" | "earned" | "craft" | "craftRare" | "saleNight" | "combo" | "tip" | "buy" | "warWin"
-- info (optional): { night, rarity, contraband } for the mission filters
function GoalsService.Record(player: Player, event: string, amount: number, info: any?)
	for _, callback in recordCallbacks do
		task.spawn(callback, player, event, amount, info)
	end
	local data = DataService.GetData(player)
	local ledger = DataService.GetLedger(player)
	if data == nil or ledger == nil then
		return
	end
	ensure(player)
	local completed, allDone = Contracts.Record(data.Contracts, event, amount, Economy.Contracts)
	for _, def in completed do
		ledger:Deposit(def.reward, "contract:" .. def.id)
		DataService.AddXp(player, def.xp)
		ServerNet.Notify(player, Messages.Goals.ContractDone:format(def.text, def.reward), "success")
	end
	if allDone then
		ledger:Deposit(Economy.Contracts.AllDoneBonus, "contracts:all")
		ServerNet.Notify(player, Messages.Goals.AllDone:format(Economy.Contracts.AllDoneBonus), "success")
	end
	if #completed > 0 then
		DataService.Sync(player)
	end
	GoalsService.Sync(player)
end

local function claimDaily(player: Player): (boolean, any)
	local data = DataService.GetData(player)
	local ledger = DataService.GetLedger(player)
	if data == nil or ledger == nil then
		return false, "NotLoaded"
	end
	local ok, cash, streak = DailyReward.Claim(data.Daily, today(), Economy.Daily)
	if not ok then
		return false, "AlreadyClaimed"
	end
	ledger:Deposit(cash, "daily")
	DataService.AddXp(player, Economy.Daily.XpPerClaim)
	DataService.Sync(player)
	GoalsService.Sync(player)
	ServerNet.Notify(player, Messages.Goals.DailyClaimed:format(streak, cash), "success")
	return true, { cash = cash, streak = streak }
end

function GoalsService:Start()
	ServerNet.Handle("RequestClaimDaily", claimDaily)
	DataService.OnPlayerLoaded(function(player: Player)
		ensure(player)
		GoalsService.Sync(player)
	end)
	-- new day while playing: new contracts, the streak can be claimed again
	task.spawn(function()
		local day = today()
		while true do
			task.wait(30)
			if today() ~= day then
				day = today()
				for _, player in Players:GetPlayers() do
					if DataService.IsLoaded(player) then
						ensure(player)
						GoalsService.Sync(player)
					end
				end
			end
		end
	end)
end

return GoalsService

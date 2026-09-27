--!strict
-- Night market of the server (Logic/Market, roadmap 2.3): tonight's black market stock with limited
-- quantities and prices pushed up by every purchase, and what the street pays at night (contraband
-- premium, tonight's wanted part set). Publishes ReplicatedStorage attribute HotSet.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Parts = require(Shared.Config.Parts)
local Messages = require(Shared.Config.Messages)
local BlackMarket = require(Shared.Logic.BlackMarket)
local Market = require(Shared.Logic.Market)
local WorldService = require(script.Parent.WorldService)
local ServerNet = require(script.Parent.Parent.Lib.ServerNet)

local MarketService = {}

local BM = Economy.BlackMarket
local SD = Economy.StreetDemand

local night = -1
local stock: { BlackMarket.Offer } = {}
local sold: { [string]: number } = {}

-- Switches to the current night's stock (and forgets what was bought the night before).
local function refresh()
	local n = BlackMarket.NightIndex(WorldService.Now(), Economy.DayNight)
	if n ~= night then
		night = n
		stock = BlackMarket.Stock(n, Parts, Economy)
		sold = {}
		ReplicatedStorage:SetAttribute("HotSet", Market.HotSet(n, Parts))
	end
end

function MarketService.Offers(): { Market.LiveOffer }
	refresh()
	return Market.Live(stock, sold, BM)
end

-- Price of `amount` units of `partId` tonight, or (nil, error).
function MarketService.Quote(partId: string, amount: number): (number?, string?)
	refresh()
	local offer = BlackMarket.Find(stock, partId)
	if offer == nil then
		return nil, "SoldOut"
	end
	local n = sold[partId] or 0
	if n + amount > offer.quantity then
		return nil, "SoldOut"
	end
	return Market.Cost(offer.price, n, amount, BM), nil
end

-- Call once the purchase is paid.
function MarketService.Record(partId: string, amount: number)
	sold[partId] = (sold[partId] or 0) + amount
end

local function isNight(): boolean
	return ReplicatedStorage:GetAttribute("Phase") == "Night"
end

-- What a sale is multiplied by right now, and why ({ night = x, hot = x }).
function MarketService.SaleMultiplier(partIds: { [string]: string }, contraband: boolean): (number, { [string]: number })
	refresh()
	return Market.SaleMultiplier(partIds, contraband, isNight(), ReplicatedStorage:GetAttribute("HotSet") :: string?, Parts, SD)
end

local function announce()
	refresh()
	if not isNight() then
		return
	end
	local hot = ReplicatedStorage:GetAttribute("HotSet")
	local text = Messages.Market.NightStart:format(SD.NightContrabandMultiplier, string.upper(tostring(hot)), math.floor(SD.HotSetBonus * 100 + 0.5))
	for _, player in Players:GetPlayers() do
		ServerNet.Notify(player, text, "warning")
	end
end

function MarketService:Start()
	refresh()
	ReplicatedStorage:GetAttributeChangedSignal("Phase"):Connect(announce)
end

return MarketService

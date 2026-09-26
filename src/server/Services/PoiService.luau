--!strict
-- Points of interest (Config/City.Poi): where they are (workspace.City.POI, built by MapBuilder),
-- the prompts players use there, and the gas station. Prompts are added at run time, so a city
-- saved in the place does not need to be rebuilt.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local City = require(Shared.Config.City)
local Economy = require(Shared.Config.Economy)
local Messages = require(Shared.Config.Messages)
local CityService = require(script.Parent.CityService)
local DataService = require(script.Parent.DataService)
local ServerNet = require(script.Parent.Parent.Lib.ServerNet)

local PoiService = {}

local lastMeal: { [Player]: number } = {}

local function poiFolder(): Instance?
	local city = workspace:FindFirstChild("City")
	return city and city:FindFirstChild("POI")
end

-- World position of a point of interest (nil if the city has none).
function PoiService.Position(name: string): Vector3?
	local folder = poiFolder()
	local part = folder and folder:FindFirstChild(name)
	return if part and part:IsA("BasePart") then part.Position else nil
end

function PoiService.IsNear(player: Player, name: string, radius: number?): boolean
	local pos = PoiService.Position(name)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if pos == nil or root == nil or not root:IsA("BasePart") then
		return false
	end
	return (root.Position - pos).Magnitude <= (radius or City.Poi.UseRadius)
end

local function prompt(part: BasePart, name: string, action: string, shop: string?): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.Name = name
	p.ActionText = action
	p.ObjectText = ""
	p.MaxActivationDistance = City.Poi.UseRadius - 4
	p.RequiresLineOfSight = false
	p.HoldDuration = 0
	if shop then
		p:SetAttribute("Shop", shop)
	end
	p.Parent = part
	return p
end

local function eat(player: Player)
	local now = os.clock()
	if now - (lastMeal[player] or -math.huge) < Economy.GasStation.CooldownSeconds then
		ServerNet.Notify(player, Messages.ForError("TooSoon"), "error")
		return
	end
	local ledger = DataService.GetLedger(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if ledger == nil or humanoid == nil or not PoiService.IsNear(player, "GasStation") then
		return
	end
	local ok, err = ledger:Withdraw(Economy.GasStation.Price, "gas:food")
	if not ok then
		ServerNet.Notify(player, Messages.ForError(err), "error")
		return
	end
	lastMeal[player] = now
	humanoid.Health = humanoid.MaxHealth
	ServerNet.FireClient("StaminaRefill", player)
	ServerNet.Notify(player, Messages.Poi.Refilled, "success")
	DataService.Sync(player)
end

function PoiService:Start()
	CityService.EnsureBuilt()
	Players.PlayerRemoving:Connect(function(player)
		lastMeal[player] = nil
	end)
	local folder = poiFolder()
	if folder == nil then
		warn("[PoiService] no workspace.City.POI: build the city (MapBuilder)")
		return
	end
	for _, part in folder:GetChildren() do
		if not part:IsA("BasePart") then
			continue
		end
		-- positions for the clients: with streaming, far POI parts do not exist on their side
		ReplicatedStorage:SetAttribute("Poi_" .. part.Name, part.Position)
		if part.Name == "Supplier" then
			prompt(part, "ShopPrompt", Messages.Poi.SupplierPrompt, "Supplier")
		elseif part.Name == "BlackMarket" then
			prompt(part, "ShopPrompt", Messages.Poi.BlackMarketPrompt, "BlackMarket")
		elseif part.Name == "GasStation" then
			local p = prompt(part, "GasPrompt", Messages.Poi.GasPrompt:format(Economy.GasStation.Price))
			p.Triggered:Connect(eat)
		end
	end
end

return PoiService

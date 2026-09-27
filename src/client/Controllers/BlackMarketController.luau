--!strict
-- The night black market (Chinatown alley): tonight's contraband stock, bought on the spot.
-- Opened by the "ShopPrompt" with Shop = "BlackMarket" (PoiService). The server checks everything.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Parts = require(Shared.Config.Parts)
local Economy = require(Shared.Config.Economy)
local Messages = require(Shared.Config.Messages)
local Net = require(Shared.Net)
local UI = require(script.Parent.Parent.UI)
local Notify = require(script.Parent.Parent.Notify)
local Effects = require(script.Parent.Parent.Effects)

local BlackMarketController = {}

local AUTO_CLOSE_DISTANCE = 24

local player = Players.LocalPlayer
local gui: ScreenGui
local list: ScrollingFrame
local hotLabel: TextLabel
local spot: BasePart? = nil

local function close()
	gui.Enabled = false
	spot = nil
end

local refresh: () -> ()

-- stock: MarketService offers { id, price (next unit), left }
local function render(stock: { any })
	UI.ClearChildren(list)
	local hot = ReplicatedStorage:GetAttribute("HotSet")
	hotLabel.Text = if hot then Messages.Market.Hot:format(string.upper(tostring(hot)), math.floor(Economy.StreetDemand.HotSetBonus * 100 + 0.5)) else ""
	for i, offer in stock do
		local part = Parts[offer.id]
		if part == nil then
			continue
		end
		local left = tonumber(offer.left) or 0
		local row = UI.Panel({ LayoutOrder = i, Size = UDim2.new(1, -8, 0, 46), BackgroundColor3 = UI.Theme.PanelLight, Parent = list })
		UI.Label({ Position = UDim2.fromOffset(10, 0), Size = UDim2.new(0.45, -10, 1, 0), Text = part.name, TextColor3 = UI.RarityColor(part.rarity), TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
		UI.Label({ Position = UDim2.fromScale(0.45, 0), Size = UDim2.new(0.2, 0, 0.5, 0), Text = part.rarity .. " " .. part.slot, TextColor3 = UI.Theme.SubText, TextSize = 12, Parent = row })
		UI.Label({
			Position = UDim2.fromScale(0.45, 0.5),
			Size = UDim2.new(0.2, 0, 0.5, 0),
			Text = if left > 0 then Messages.Market.Left:format(left) else Messages.Market.SoldOut,
			TextColor3 = if left > 2 then UI.Theme.SubText else UI.Theme.Warning,
			TextSize = 12,
			Parent = row,
		})
		UI.Button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -6, 0.5, 0),
			Size = UDim2.fromOffset(96, 34),
			Text = if left > 0 then UI.Money(offer.price) else Messages.Market.SoldOut,
			TextSize = 14,
			BackgroundColor3 = if left > 0 then UI.Theme.Danger else UI.Theme.Disabled,
			Parent = row,
		}, function()
			if left <= 0 then
				return
			end
			local ok, result = Net.Invoke("RequestBuyPart", offer.id, 1, "blackmarket")
			if ok then
				Effects.Sound(Effects.Sounds.Cash, nil, 0.9)
			else
				Notify.Show(Messages.ForError(result), "error")
			end
			refresh() -- prices went up, units went down
		end)
	end
end

local function open(part: BasePart?)
	local ok, result = Net.Invoke("RequestBlackMarket")
	if not ok then
		Notify.Show(Messages.ForError(result), "error")
		return
	end
	spot = part
	render(result)
	gui.Enabled = true
end

refresh = function()
	if not gui.Enabled then
		return
	end
	local ok, result = Net.Invoke("RequestBlackMarket")
	if ok then
		render(result)
	end
end

function BlackMarketController:Start()
	gui = UI.Screen("BlackMarket", 20)
	gui.Enabled = false
	local panel = UI.Panel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(460, 330), Parent = gui })
	UI.Stroke(panel, UI.Theme.Danger, 2)
	UI.Padding(panel, 12)
	UI.Label({ Size = UDim2.new(1, -50, 0, 28), Text = Messages.Poi.BlackMarketTitle, Font = UI.Theme.FontBlack, TextSize = 24, TextColor3 = UI.Theme.Danger, TextXAlignment = Enum.TextXAlignment.Left, Parent = panel })
	UI.Label({ Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 16), Text = Messages.Poi.BlackMarketNote, TextSize = 12, TextColor3 = UI.Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, Parent = panel })
	UI.Button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(36, 30), Text = "X", BackgroundColor3 = UI.Theme.Danger, Parent = panel }, close)
	hotLabel = UI.Label({ Position = UDim2.fromOffset(0, 48), Size = UDim2.new(1, 0, 0, 16), Text = "", TextSize = 13, TextColor3 = UI.Theme.Warning, TextXAlignment = Enum.TextXAlignment.Left, Parent = panel })
	list = UI.Scrolling({ Position = UDim2.fromOffset(0, 70), Size = UDim2.new(1, 0, 1, -70), Parent = panel })
	UI.List(list, 6)

	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who == player and prompt.Name == "ShopPrompt" and prompt:GetAttribute("Shop") == "BlackMarket" then
			local parent = prompt.Parent
			open(if parent and parent:IsA("BasePart") then parent else nil)
		end
	end)
	-- walking away or the night ending closes it
	RunService.Heartbeat:Connect(function()
		if not gui.Enabled then
			return
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local s = spot
		if ReplicatedStorage:GetAttribute("Phase") ~= "Night" or (s and root and root:IsA("BasePart") and (root.Position - s.Position).Magnitude > AUTO_CLOSE_DISTANCE) then
			close()
		end
	end)
end

return BlackMarketController

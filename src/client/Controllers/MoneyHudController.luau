--!strict
-- Money counter (top right) + dealer level and XP bar. Reads the attributes set by DataService.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local UI = require(script.Parent.Parent.UI)
local Effects = require(script.Parent.Parent.Effects)

local MoneyHudController = {}

local STYLE = {
	Width = 190,
	MoneyHeight = 40,
	LevelHeight = 22,
	CountSeconds = 0.5, -- the number rolls up to the new value
}

function MoneyHudController:Start()
	local player = Players.LocalPlayer
	local gui = UI.Screen("MoneyHud", 10)

	local holder = UI.new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromOffset(STYLE.Width, STYLE.MoneyHeight + STYLE.LevelHeight + 6),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local money = UI.Panel({
		Name = "MoneyPanel",
		Size = UDim2.new(1, 0, 0, STYLE.MoneyHeight),
		BackgroundColor3 = UI.Theme.Background,
		Parent = holder,
	})
	UI.Stroke(money, UI.Theme.Money, 2)
	local moneyLabel = UI.Label({
		Name = "MoneyLabel",
		Size = UDim2.fromScale(1, 1),
		Text = "...",
		TextColor3 = UI.Theme.Money,
		Font = UI.Theme.FontBlack,
		TextSize = 22,
		Parent = money,
	})

	local level = UI.Panel({
		Position = UDim2.new(0, 0, 0, STYLE.MoneyHeight + 6),
		Size = UDim2.new(1, 0, 0, STYLE.LevelHeight),
		BackgroundColor3 = UI.Theme.Background,
		Parent = holder,
	})
	local xpFill = UI.new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = UI.Theme.Accent,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		Parent = level,
	})
	UI.Corner(xpFill)
	local levelLabel = UI.Label({
		Size = UDim2.fromScale(1, 1),
		Text = "LV 1",
		TextSize = 14,
		ZIndex = 2,
		Parent = level,
	})

	local shown = 0
	local counter = Instance.new("NumberValue")
	counter.Changed:Connect(function(v)
		moneyLabel.Text = UI.Money(v)
	end)

	local function refreshMoney()
		local value = player:GetAttribute("Money")
		if type(value) ~= "number" then
			return
		end
		if value > shown and shown > 0 then
			Effects.Bounce(money, 1.1)
		elseif value < shown then
			moneyLabel.TextColor3 = UI.Theme.Danger
			task.delay(0.4, function()
				moneyLabel.TextColor3 = UI.Theme.Money
			end)
		end
		if shown == 0 then
			moneyLabel.Text = UI.Money(value)
		end
		shown = value
		TweenService:Create(counter, TweenInfo.new(STYLE.CountSeconds, Enum.EasingStyle.Quad), { Value = value }):Play()
	end

	local function refreshLevel()
		local lv = player:GetAttribute("Level")
		local xp = player:GetAttribute("Xp")
		local need = player:GetAttribute("XpToNext")
		if type(lv) == "number" then
			levelLabel.Text = "LV " .. lv
		end
		if type(xp) == "number" and type(need) == "number" and need > 0 then
			TweenService:Create(xpFill, TweenInfo.new(0.3), { Size = UDim2.fromScale(math.clamp(xp / need, 0, 1), 1) }):Play()
		end
	end

	player:GetAttributeChangedSignal("Money"):Connect(refreshMoney)
	player:GetAttributeChangedSignal("Level"):Connect(refreshLevel)
	player:GetAttributeChangedSignal("Xp"):Connect(refreshLevel)
	refreshMoney()
	refreshLevel()
end

return MoneyHudController

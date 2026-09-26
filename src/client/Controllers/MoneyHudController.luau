--!strict
-- Shows the player's money (read from the "Money" attribute set by DataService). Placeholder style.
local Players = game:GetService("Players")

local MoneyHudController = {}

local STYLE = {
	TextColor = Color3.fromRGB(120, 255, 140),
	Background = Color3.fromRGB(12, 10, 24),
}

local function formatMoney(n: number): string
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1 "):reverse()
	return "$ " .. formatted:gsub("^ ", "")
end

function MoneyHudController:Start()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "MoneyHud"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(1, 0)
	label.Position = UDim2.new(1, -12, 0, 12)
	label.Size = UDim2.fromOffset(180, 36)
	label.BackgroundColor3 = STYLE.Background
	label.BackgroundTransparency = 0.25
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 18
	label.TextColor3 = STYLE.TextColor
	label.Parent = gui
	Instance.new("UICorner", label).CornerRadius = UDim.new(0, 10)

	local function refresh()
		local money = player:GetAttribute("Money")
		label.Text = if type(money) == "number" then formatMoney(money) else "..."
	end

	player:GetAttributeChangedSignal("Money"):Connect(refresh)
	refresh()
end

return MoneyHudController

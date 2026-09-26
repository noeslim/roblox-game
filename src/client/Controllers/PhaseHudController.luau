--!strict
-- Tiny HUD showing DAY / NIGHT and the time left. Proof that Rojo sync + server attributes work.
-- The visual style is a placeholder: tweak sizes/colors directly here or rebuild it in Studio.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PhaseHudController = {}

local STYLE = {
	DayColor = Color3.fromRGB(255, 196, 64),
	NightColor = Color3.fromRGB(180, 92, 255),
	Background = Color3.fromRGB(12, 10, 24),
}

function PhaseHudController:Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "PhaseHud"
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0, 12)
	label.Size = UDim2.fromOffset(220, 36)
	label.BackgroundColor3 = STYLE.Background
	label.BackgroundTransparency = 0.25
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 18
	label.Parent = gui
	Instance.new("UICorner", label).CornerRadius = UDim.new(0, 10)
	local stroke = Instance.new("UIStroke", label)
	stroke.Thickness = 2

	local function refresh()
		local phase = ReplicatedStorage:GetAttribute("Phase") or "Day"
		local left = ReplicatedStorage:GetAttribute("PhaseSecondsLeft") or 0
		local color = if phase == "Night" then STYLE.NightColor else STYLE.DayColor
		label.Text = ("%s  %d:%02d"):format(if phase == "Night" then "🌙 NIGHT" else "☀️ DAY", left // 60, left % 60)
		label.TextColor3 = color
		stroke.Color = color
	end

	ReplicatedStorage:GetAttributeChangedSignal("Phase"):Connect(refresh)
	ReplicatedStorage:GetAttributeChangedSignal("PhaseSecondsLeft"):Connect(refresh)
	refresh()
end

return PhaseHudController

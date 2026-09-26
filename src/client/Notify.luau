--!strict
-- Toast messages under the day/night HUD. Notify.Show("Not enough cash.", "error")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UI = require(script.Parent.UI)
local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local Notify = {}

local SETTINGS = {
	Seconds = 2.8,
	MaxVisible = 4,
	Width = 360,
	Height = 36,
}

local COLORS = {
	info = UI.Theme.Info,
	success = UI.Theme.Money,
	money = UI.Theme.Money,
	error = UI.Theme.Danger,
	warning = UI.Theme.Warning,
}

local holder: Frame? = nil

local function getHolder(): Frame
	if holder and holder.Parent then
		return holder
	end
	local gui = UI.Screen("Notifications", 50)
	local frame = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 60),
		Size = UDim2.fromOffset(SETTINGS.Width, 200),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	UI.List(frame, 6)
	holder = frame
	return frame
end

function Notify.Show(text: string, kind: string?)
	local frame = getHolder()
	local items = {}
	for _, c in frame:GetChildren() do
		if c:IsA("Frame") then
			table.insert(items, c)
		end
	end
	if #items >= SETTINGS.MaxVisible then
		items[1]:Destroy()
	end

	local color = COLORS[kind or "info"] or UI.Theme.Info
	local toast = UI.Panel({
		Size = UDim2.new(1, 0, 0, SETTINGS.Height),
		BackgroundColor3 = UI.Theme.Background,
		LayoutOrder = math.floor(os.clock() * 1000) % 1e9,
		Parent = frame,
	})
	UI.Stroke(toast, color, 2)
	local label = UI.Label({
		Size = UDim2.fromScale(1, 1),
		Text = text,
		TextColor3 = color,
		TextSize = 16,
		TextWrapped = true,
		Parent = toast,
	})
	local scale = UI.new("UIScale", { Scale = 0.6, Parent = toast })
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(SETTINGS.Seconds, function()
		if toast.Parent then
			TweenService:Create(toast, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
			TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
			task.wait(0.3)
			toast:Destroy()
		end
	end)
end

Net.GetEvent("Notify").OnClientEvent:Connect(function(text: any, kind: any)
	if type(text) == "string" then
		Notify.Show(text, if type(kind) == "string" then kind else nil)
	end
end)

return Notify

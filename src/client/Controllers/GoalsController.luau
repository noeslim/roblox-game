--!strict
-- Contracts panel (left side) and the daily streak card, fed by GoalsSync. The streak card pops up
-- when today's reward can be claimed. Text: Config/Messages.Goals.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Messages = require(Shared.Config.Messages)
local Net = require(Shared.Net)
local UI = require(script.Parent.Parent.UI)
local Notify = require(script.Parent.Parent.Notify)

local GoalsController = {}

local T = UI.Theme
local M = Messages.Goals

local panel: Frame
local list: Frame
local title: TextLabel
local card: ScreenGui? = nil
local collapsed = false
local dismissedStreak = -1 -- "later" was pressed for this streak day

local function row(c: any, order: number)
	local frame = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, LayoutOrder = order, Parent = list })
	UI.Label({
		Size = UDim2.new(1, -60, 0, 16),
		Text = c.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 13,
		TextColor3 = if c.done then T.SubText else T.Text,
		Parent = frame,
	})
	UI.Label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 60, 0, 16),
		Text = if c.done then "DONE" else ("$" .. c.reward),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextSize = 13,
		TextColor3 = if c.done then T.SubText else T.Money,
		Parent = frame,
	})
	local track = UI.new("Frame", { Position = UDim2.new(0, 0, 0, 20), Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = T.PanelLight, BorderSizePixel = 0, Parent = frame })
	UI.Corner(track, 3)
	local fill = UI.new("Frame", { Size = UDim2.fromScale(math.clamp(c.progress / c.target, 0, 1), 1), BackgroundColor3 = if c.done then T.Money else T.Warning, BorderSizePixel = 0, Parent = track })
	UI.Corner(fill, 3)
	if not c.done and c.target > 1 then
		UI.Label({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 26),
			Size = UDim2.new(0, 80, 0, 10),
			Text = ("%d / %d"):format(c.progress, c.target),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextSize = 10,
			TextColor3 = T.SubText,
			Parent = frame,
		})
	end
end

local function renderContracts(snapshot: any)
	UI.ClearChildren(list, "UIListLayout")
	title.Text = if snapshot.allDone then M.AllDoneTitle else M.Title
	for i, c in snapshot.contracts do
		row(c, i)
	end
	list.Visible = not collapsed
end

local function closeCard()
	local c = card
	if c then
		card = nil
		c:Destroy()
	end
end

local function showCard(daily: any)
	closeCard()
	local gui = UI.Screen("DailyStreak", 20)
	local frame = UI.Panel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(460, 230), Parent = gui })
	UI.Stroke(frame, T.Warning, 2)
	UI.Label({ Position = UDim2.fromOffset(0, 14), Size = UDim2.new(1, 0, 0, 28), Text = M.DailyTitle, Font = T.FontBlack, TextSize = 26, TextColor3 = T.Warning, Parent = frame })
	UI.Label({ Position = UDim2.fromOffset(20, 44), Size = UDim2.new(1, -40, 0, 18), Text = M.DailySubtitle, TextSize = 12, TextColor3 = T.SubText, Parent = frame })
	local days = UI.new("Frame", { Position = UDim2.fromOffset(20, 72), Size = UDim2.new(1, -40, 0, 74), BackgroundTransparency = 1, Parent = frame })
	UI.List(days, 6, true)
	local n = #daily.rewards
	local current = (daily.streak - 1) % n + 1
	for i, cash in daily.rewards do
		local isToday = i == current
		local tile = UI.Panel({
			Size = UDim2.new(1 / n, -6, 1, 0),
			BackgroundColor3 = if isToday then T.Warning elseif i < current then T.PanelLight else T.Background,
			LayoutOrder = i,
			Parent = days,
		})
		local color = if isToday then T.Background else T.Text
		UI.Label({ Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 14), Text = M.Day:format(i), TextSize = 11, TextColor3 = color, Parent = tile })
		UI.Label({ Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, 0, 0, 20), Text = "$" .. cash, Font = T.FontBlack, TextSize = 15, TextColor3 = if isToday then T.Background else T.Money, Parent = tile })
		if i < current then
			UI.Label({ Position = UDim2.fromOffset(0, 54), Size = UDim2.new(1, 0, 0, 14), Text = "✓", TextSize = 13, TextColor3 = T.Money, Parent = tile })
		end
	end
	local button = UI.Button({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 164),
		Size = UDim2.fromOffset(220, 44),
		Text = M.Claim:format(daily.reward),
		BackgroundColor3 = T.Money,
		TextColor3 = T.Background,
		TextSize = 18,
		Parent = frame,
	})
	button.Activated:Connect(function()
		button.Active = false
		local ok, result = Net.Invoke("RequestClaimDaily")
		if not ok then
			Notify.Show(Messages.ForError(result), "error")
		end
		gui:Destroy()
		card = nil
	end)
	local later = UI.new("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 8),
		Size = UDim2.fromOffset(28, 28),
		BackgroundTransparency = 1,
		Text = "X",
		Font = T.FontBlack,
		TextSize = 18,
		TextColor3 = T.SubText,
		Parent = frame,
	})
	later.Activated:Connect(function()
		dismissedStreak = daily.streak
		closeCard()
	end)
	local scale = UI.new("UIScale", { Scale = 0.6, Parent = frame })
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	card = gui
end

function GoalsController:Start()
	local gui = UI.Screen("Contracts", 2)
	panel = UI.Panel({
		Position = UDim2.new(0, 12, 0, 70), -- top left, under Roblox's menu buttons (BUILD sits lower)
		Size = UDim2.fromOffset(240, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 0.25,
		Parent = gui,
	})
	UI.Padding(panel, 10)
	UI.List(panel, 6)
	local header = UI.new("TextButton", { Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, Text = "", LayoutOrder = 0, Parent = panel })
	title = UI.Label({ Size = UDim2.fromScale(1, 1), Text = M.Title, Font = T.FontBlack, TextSize = 14, TextColor3 = T.Warning, TextXAlignment = Enum.TextXAlignment.Left, Parent = header })
	list = UI.new("Frame", { Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 1, Parent = panel })
	UI.List(list, 4)
	header.Activated:Connect(function()
		collapsed = not collapsed
		list.Visible = not collapsed
	end)
	panel.Visible = false

	Net.GetEvent("GoalsSync").OnClientEvent:Connect(function(snapshot: any)
		if type(snapshot) ~= "table" then
			return
		end
		panel.Visible = true
		renderContracts(snapshot)
		if snapshot.daily.canClaim and card == nil and dismissedStreak ~= snapshot.daily.streak then
			showCard(snapshot.daily)
		elseif not snapshot.daily.canClaim then
			closeCard()
		end
	end)
end

return GoalsController

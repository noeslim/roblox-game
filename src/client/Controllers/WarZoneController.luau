--!strict
-- War Zone HUD, shown while the player is in a team (attribute WarTeam set by WarZoneService):
-- Red vs Blue score bar, time left (or the next round countdown) and the control points, colored
-- by owner and filled by capture progress. Reads the War_* attributes of ReplicatedStorage.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local War = require(Shared.Config.War)
local Messages = require(Shared.Config.Messages)
local UI = require(script.Parent.Parent.UI)

local WarZoneController = {}

local T = UI.Theme
local RED = Color3.fromHex(War.Teams.Red.color)
local BLUE = Color3.fromHex(War.Teams.Blue.color)
local NEUTRAL = Color3.fromHex("#8A8A90")

type Badge = { frame: Frame, fill: Frame, stroke: UIStroke }

local function attr(name: string, default: any): any
	local v = ReplicatedStorage:GetAttribute(name)
	return if v == nil then default else v
end

function WarZoneController:Start()
	local player = Players.LocalPlayer
	local gui = UI.Screen("WarZone", 3)
	gui.Enabled = false
	local panel = UI.Panel({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 58),
		Size = UDim2.fromOffset(360, 96),
		BackgroundTransparency = 0.2,
		Parent = gui,
	})
	UI.Padding(panel, 8)
	local title = UI.Label({ Size = UDim2.new(1, 0, 0, 16), Text = Messages.War.Title, Font = T.FontBlack, TextSize = 14, Parent = panel })
	local bar = UI.new("Frame", { Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 14), BackgroundColor3 = T.PanelLight, BorderSizePixel = 0, Parent = panel })
	UI.Corner(bar, 4)
	local redFill = UI.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = RED, BorderSizePixel = 0, Parent = bar })
	local blueFill = UI.new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromScale(0, 1), BackgroundColor3 = BLUE, BorderSizePixel = 0, Parent = bar })
	local redText = UI.Label({ Position = UDim2.fromOffset(4, 0), Size = UDim2.new(0.5, 0, 1, 0), Text = "0", TextSize = 12, Font = T.FontBlack, TextXAlignment = Enum.TextXAlignment.Left, Parent = bar })
	local blueText = UI.Label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 0), Size = UDim2.new(0.5, 0, 1, 0), Text = "0", TextSize = 12, Font = T.FontBlack, TextXAlignment = Enum.TextXAlignment.Right, Parent = bar })
	local timer = UI.Label({ Position = UDim2.fromOffset(0, 36), Size = UDim2.new(1, 0, 0, 14), Text = "", TextSize = 12, TextColor3 = T.SubText, Parent = panel })
	local row = UI.new("Frame", { Position = UDim2.fromOffset(0, 54), Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, Parent = panel })
	local layout = UI.List(row, 10, true)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	local badges: { [string]: Badge } = {}
	local function badge(label: string, order: number): Badge
		local frame = UI.new("Frame", { Size = UDim2.fromOffset(26, 26), BackgroundColor3 = T.Background, BorderSizePixel = 0, LayoutOrder = order, ClipsDescendants = true, Parent = row })
		UI.Corner(frame, 13)
		local fill = UI.new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0), BackgroundColor3 = NEUTRAL, BorderSizePixel = 0, Parent = frame })
		local stroke = UI.Stroke(frame, NEUTRAL, 2)
		UI.Label({ Size = UDim2.fromScale(1, 1), Text = label, Font = T.FontBlack, TextSize = 13, ZIndex = 2, Parent = frame })
		return { frame = frame, fill = fill, stroke = stroke }
	end

	task.spawn(function()
		while true do
			task.wait(0.2)
			local team = player:GetAttribute("WarTeam")
			gui.Enabled = team ~= nil
			if team == nil then
				continue
			end
			title.Text = ("%s  -  YOU ARE %s"):format(Messages.War.Title, string.upper(tostring(team)))
			title.TextColor3 = if team == "Red" then RED else BLUE
			local goal = math.max(1, attr("War_Goal", War.ScoreToWin))
			local red, blue = attr("War_Red", 0), attr("War_Blue", 0)
			redFill.Size = UDim2.fromScale(0.5 * red / goal, 1)
			blueFill.Size = UDim2.fromScale(0.5 * blue / goal, 1)
			redText.Text = tostring(red)
			blueText.Text = tostring(blue)
			local left = attr("War_TimeLeft", 0)
			timer.Text = if attr("War_Phase", "Playing") == "Intermission" then Messages.War.Intermission:format(left) else ("%d:%02d  -  first to %d"):format(left // 60, left % 60, goal)
			for i, label in string.split(attr("War_Points", ""), ",") do
				if label == "" then
					continue
				end
				local b = badges[label] or badge(label, i)
				badges[label] = b
				local owner = attr("War_" .. label .. "_Owner", "")
				local progress = attr("War_" .. label .. "_Progress", 0)
				b.stroke.Color = if owner == "Red" then RED elseif owner == "Blue" then BLUE else NEUTRAL
				b.fill.BackgroundColor3 = if progress >= 0 then RED else BLUE
				b.fill.Size = UDim2.fromScale(1, math.abs(progress))
			end
		end
	end)
end

return WarZoneController

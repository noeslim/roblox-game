--!strict
-- Missions on screen (server: MissionService): the tracker of the current job (step, progress,
-- time left, drop), a marker on the place to reach, and the JOBS board to take a street job.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Messages = require(Shared.Config.Messages)
local Missions = require(Shared.Config.Missions)
local Net = require(Shared.Net)
local UI = require(script.Parent.Parent.UI)
local Notify = require(script.Parent.Parent.Notify)

local MissionController = {}

local player = Players.LocalPlayer
local M = Messages.Missions

local current: any = nil -- last MissionSync payload
local markerPart: Part? = nil
local markerLabel: TextLabel? = nil

local function clock(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	return ("%d:%02d"):format(s // 60, s % 60)
end

local function setMarker(pos: Vector3?, text: string)
	if pos == nil then
		if markerPart then
			markerPart:Destroy()
			markerPart = nil
			markerLabel = nil
		end
		return
	end
	if markerPart == nil then
		local part = Instance.new("Part")
		part.Name = "MissionMarker"
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Transparency = 1
		part.Size = Vector3.new(0.2, 0.2, 0.2)
		part.Parent = workspace
		local gui = UI.new("BillboardGui", { Size = UDim2.fromOffset(220, 44), AlwaysOnTop = true, LightInfluence = 0, StudsOffset = Vector3.new(0, 6, 0), Parent = part })
		markerLabel = UI.Label({ Size = UDim2.fromScale(1, 1), TextSize = 15, TextColor3 = UI.Theme.Warning, TextStrokeTransparency = 0.3, Parent = gui })
		markerPart = part
	end
	local part = markerPart :: Part
	part.Position = pos
	part:SetAttribute("Text", text)
end

function MissionController:Start()
	-- tracker (right side, under the heat gauge)
	local gui = UI.Screen("MissionHud", 10)
	local tracker = UI.Panel({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 112), Size = UDim2.fromOffset(240, 78), Visible = false, Parent = gui })
	UI.Padding(tracker, 8)
	local title = UI.Label({ Size = UDim2.new(1, -56, 0, 18), TextSize = 15, Font = UI.Theme.FontBlack, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UI.Theme.Warning, Parent = tracker })
	local stepLabel = UI.Label({ Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, 30), TextSize = 13, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = tracker })
	local timer = UI.Label({ Position = UDim2.new(0, 0, 1, -14), Size = UDim2.new(1, 0, 0, 14), TextSize = 12, TextColor3 = UI.Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, Parent = tracker })
	UI.Button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(52, 22), Text = M.Drop, TextSize = 12, BackgroundColor3 = UI.Theme.Danger, Parent = tracker }, function()
		local ok, err = Net.Invoke("RequestAbandonMission")
		if not ok then
			Notify.Show(Messages.ForError(err), "error")
		end
	end)

	-- the JOBS board
	local board = UI.Panel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(440, 360), Visible = false, Parent = gui })
	UI.Padding(board, 12)
	UI.Label({ Size = UDim2.new(1, -50, 0, 26), Text = M.BoardTitle, Font = UI.Theme.FontBlack, TextSize = 22, TextColor3 = UI.Theme.Warning, TextXAlignment = Enum.TextXAlignment.Left, Parent = board })
	UI.Label({ Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 0, 16), Text = M.BoardNote, TextSize = 12, TextColor3 = UI.Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, Parent = board })
	UI.Button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(36, 30), Text = "X", BackgroundColor3 = UI.Theme.Danger, Parent = board }, function()
		board.Visible = false
	end)
	local list = UI.Scrolling({ Position = UDim2.fromOffset(0, 52), Size = UDim2.new(1, 0, 1, -52), Parent = board })
	UI.List(list, 6)

	local function renderBoard()
		UI.ClearChildren(list)
		local cooldowns = if current then current.cooldowns or {} else {}
		for i, job in Missions.Jobs do
			local row = UI.Panel({ LayoutOrder = i, Size = UDim2.new(1, -8, 0, 58), BackgroundColor3 = UI.Theme.PanelLight, Parent = list })
			UI.Label({ Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -120, 0, 18), Text = job.title, TextSize = 15, Font = UI.Theme.FontBlack, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
			UI.Label({ Position = UDim2.fromOffset(10, 22), Size = UDim2.new(1, -120, 0, 16), Text = job.text or "", TextSize = 12, TextColor3 = UI.Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
			UI.Label({ Position = UDim2.fromOffset(10, 38), Size = UDim2.new(1, -120, 0, 16), Text = M.Reward:format(job.reward.money, job.reward.xp), TextSize = 12, TextColor3 = UI.Theme.Money, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
			local wait = tonumber(cooldowns[job.id])
			UI.Button({
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
				Size = UDim2.fromOffset(100, 34),
				Text = if wait then M.Available:format(wait // 60, wait % 60) else M.Take,
				TextSize = if wait then 11 else 14,
				BackgroundColor3 = if wait then UI.Theme.Disabled else UI.Theme.Accent,
				Parent = row,
			}, function()
				if wait then
					return
				end
				local ok, err = Net.Invoke("RequestStartMission", job.id)
				if ok then
					board.Visible = false
				else
					Notify.Show(Messages.ForError(err), "error")
				end
			end)
		end
	end

	UI.Button({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -60, 1, -12), Size = UDim2.fromOffset(70, 40), Text = M.Board, TextSize = 14, BackgroundColor3 = UI.Theme.PanelLight, Parent = gui }, function()
		board.Visible = not board.Visible
		if board.Visible then
			renderBoard()
			Net.Invoke("RequestMissions") -- fresh cooldowns
		end
	end)

	local function render()
		local view = current and current.active
		tracker.Visible = view ~= nil
		if view == nil then
			setMarker(nil, "")
			return
		end
		title.Text = string.upper(tostring(view.title))
		local status = view.status
		if status == "done" then
			stepLabel.Text = "DONE"
			stepLabel.TextColor3 = UI.Theme.Money
		elseif status == "failed" then
			stepLabel.Text = "FAILED"
			stepLabel.TextColor3 = UI.Theme.Danger
		else
			local count = if (tonumber(view.goal) or 1) > 1 then (" (%d/%d)"):format(view.progress, view.goal) else ""
			stepLabel.Text = ("%d/%d  ·  %s%s"):format(view.step, view.steps, tostring(view.text), count)
			stepLabel.TextColor3 = UI.Theme.Text
		end
		timer.Text = if view.timeLeft then "Time left " .. clock(view.timeLeft) else ""
		local pos = if status == "active" and typeof(view.targetPosition) == "Vector3" then view.targetPosition else nil
		setMarker(pos, tostring(view.text))
	end

	Net.GetEvent("MissionSync").OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end
		current = payload
		render()
		if board.Visible then
			renderBoard()
		end
	end)
	-- the marker shows how far the place is
	RunService.Heartbeat:Connect(function()
		local part, label = markerPart, markerLabel
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if part and label and root and root:IsA("BasePart") then
			label.Text = ("%s\n%dm"):format(tostring(part:GetAttribute("Text")), math.floor((root.Position - part.Position).Magnitude))
		end
	end)
	task.defer(function()
		Net.Invoke("RequestMissions")
	end)
end

return MissionController

--!strict
-- Heat and raids on screen (server: RaidService). The heat gauge under the money counter; during a
-- raid on your stash, a countdown banner, red/blue screen edges and the siren; police lights at
-- any raided trap house; the raid report. Look and sounds: Config/Raid.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Buildables = require(Shared.Config.Buildables)
local Messages = require(Shared.Config.Messages)
local RaidConfig = require(Shared.Config.Raid)
local Net = require(Shared.Net)
local UI = require(script.Parent.Parent.UI)

local HeatController = {}

local player = Players.LocalPlayer
local GAUGE = RaidConfig.Gauge
local LIGHTS = RaidConfig.Lights
local SOUNDS = RaidConfig.Sounds

local function sound(id: string, parent: Instance, looped: boolean): Sound?
	if id == "" then
		return nil
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = SOUNDS.Volume
	s.Looped = looped
	s.RollOffMaxDistance = 160
	s.Parent = parent
	s:Play()
	if not looped then
		s.Ended:Connect(function()
			s:Destroy()
		end)
	end
	return s
end

-- Gauge ----------------------------------------------------------------------------------

local function buildGauge(): () -> ()
	local gui = UI.Screen("HeatHud", 10)
	local holder = UI.new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 86),
		Size = UDim2.fromOffset(190, 18),
		BackgroundColor3 = UI.Theme.Panel,
		BackgroundTransparency = UI.Theme.PanelTransparency,
		Parent = gui,
	})
	UI.Corner(holder, 9)
	local fill = UI.new("Frame", { Size = UDim2.fromScale(0, 1), BorderSizePixel = 0, Parent = holder })
	UI.Corner(fill, 9)
	local label = UI.Label({ Size = UDim2.fromScale(1, 1), TextSize = 12, Text = "HEAT", Parent = holder })

	return function()
		local value = tonumber(player:GetAttribute("Heat")) or 0
		local level = tostring(player:GetAttribute("HeatLevel") or "Clear")
		local color = Color3.fromHex((GAUGE.Colors :: any)[level] or GAUGE.Colors.Clear)
		TweenService:Create(fill, TweenInfo.new(0.4), { Size = UDim2.fromScale(math.clamp(value / Economy.Heat.Max, 0, 1), 1), BackgroundColor3 = color }):Play()
		local inSight = tonumber(player:GetAttribute("InSight")) or 0
		label.Text = "HEAT  ·  " .. ((GAUGE.Labels :: any)[level] or level) .. (if inSight > 0 then ("  ·  %d IN SIGHT"):format(inSight) else "")
	end
end

-- Red outline on your stock that the inspectors will seize (StockService marks it Contraband).
local outlines: { [Instance]: Highlight } = {}

local function myStock(): Instance?
	local hideouts = workspace:FindFirstChild("Hideouts")
	if hideouts == nil then
		return nil
	end
	for _, plot in hideouts:GetChildren() do
		if plot:GetAttribute("OwnerUserId") == player.UserId then
			return plot:FindFirstChild("Stock")
		end
	end
	return nil
end

local function setOutlines(on: boolean)
	local keep: { [Instance]: boolean } = {}
	local stock = if on then myStock() else nil
	if stock then
		for _, m in stock:GetChildren() do
			if m:IsA("Model") and m:GetAttribute("Contraband") == true then
				keep[m] = true
				if not outlines[m] then
					local h = Instance.new("Highlight")
					h.Adornee = m
					h.FillTransparency = 0.75
					h.FillColor = Color3.fromHex(RaidConfig.Stock.Highlight)
					h.OutlineColor = Color3.fromHex(RaidConfig.Stock.Highlight)
					h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
					h.Parent = m
					outlines[m] = h
				end
			end
		end
	end
	for m, h in outlines do
		if not keep[m] then
			h:Destroy()
			outlines[m] = nil
		end
	end
end

-- Your raid ------------------------------------------------------------------------------

local function hasCompartment(): boolean
	local hideouts = workspace:FindFirstChild("Hideouts")
	if hideouts == nil then
		return false
	end
	for _, plot in hideouts:GetChildren() do
		local objects = plot:FindFirstChild("Objects")
		if objects then
			for _, m in objects:GetChildren() do
				local def = Buildables.ById[m:GetAttribute("BuildableId") :: string]
				if m:GetAttribute("OwnerUserId") == player.UserId and def and def.hide then
					return true
				end
			end
		end
	end
	return false
end

local function buildRaidOverlay()
	local gui = UI.Screen("RaidHud", 35)
	gui.IgnoreGuiInset = true
	gui.Enabled = false
	local edges: { Frame } = {}
	local w = RaidConfig.ScreenPulse.Width
	for i, spec in {
		{ UDim2.fromScale(0, 0), UDim2.fromScale(w, 1) },
		{ UDim2.fromScale(1 - w, 0), UDim2.fromScale(w, 1) },
	} do
		local f = UI.new("Frame", { Position = spec[1], Size = spec[2], BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 0, 0), BackgroundTransparency = 1, Parent = gui })
		UI.new("UIGradient", {
			Transparency = NumberSequence.new(if i == 1 then 0 else 1, if i == 1 then 1 else 0),
			Parent = f,
		})
		table.insert(edges, f)
	end
	local banner = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 70), Size = UDim2.fromOffset(460, 84), BackgroundTransparency = 1, Parent = gui })
	local title = UI.Label({ Size = UDim2.new(1, 0, 0, 44), Font = UI.Theme.FontBlack, TextSize = 40, TextColor3 = UI.Theme.Danger, TextStrokeTransparency = 0.3, Parent = banner })
	local hint = UI.Label({ Position = UDim2.fromOffset(0, 48), Size = UDim2.new(1, 0, 0, 22), TextSize = 17, TextStrokeTransparency = 0.4, TextWrapped = true, Parent = banner })

	local siren: Sound? = nil
	local phaseShown: string? = nil
	local lastOutline = 0
	RunService.RenderStepped:Connect(function()
		local phase = player:GetAttribute("RaidPhase")
		if phase ~= phaseShown then
			phaseShown = phase :: string?
			gui.Enabled = phase ~= nil
			if phase == "Warning" then
				hint.Text = if hasCompartment() then Messages.Raid.Hint else Messages.Raid.NoCompartmentHint
				if siren == nil then
					siren = sound(SOUNDS.Siren, gui, true)
				end
			elseif phase == "Search" then
				hint.Text = Messages.Raid.Search
			end
			if phase == nil and siren then
				siren:Destroy()
				siren = nil
			end
		end
		local now = os.clock()
		if now - lastOutline > 0.5 then
			lastOutline = now
			setOutlines(phase ~= nil)
		end
		if phase == nil then
			return
		end
		local left = math.max(0, math.ceil((tonumber(player:GetAttribute("RaidEndsAt")) or 0) - workspace:GetServerTimeNow()))
		title.Text = if phase == "Warning" then ("%s  %d"):format(Messages.Raid.Warning, left) else ("SEARCH  %d"):format(left)
		local red = math.floor(os.clock() * LIGHTS.FlashHz) % 2 == 0
		for i, f in edges do
			local mine = if i == 1 then red else not red
			f.BackgroundColor3 = Color3.fromHex(if mine then LIGHTS.Red else LIGHTS.Blue)
			f.BackgroundTransparency = RaidConfig.ScreenPulse.Transparency
		end
	end)
end

-- Police lights at raided houses (everyone) ----------------------------------------------------

local active: { [Instance]: { lights: { PointLight }, holder: Instance, siren: Sound? } } = {}

local function lightAnchor(plot: Instance): BasePart?
	local waypoints = plot:FindFirstChild("Waypoints")
	local door = waypoints and waypoints:FindFirstChild("Door")
	if door and door:IsA("BasePart") then
		return door
	end
	local anchor = plot:FindFirstChild("Anchor")
	local floor = anchor and anchor:FindFirstChild("Floor")
	return if floor and floor:IsA("BasePart") then floor else nil
end

local function setLights(plot: Instance, on: boolean)
	local current = active[plot]
	if not on then
		if current then
			current.holder:Destroy()
			active[plot] = nil
		end
		return
	end
	if current then
		return
	end
	local anchor = lightAnchor(plot)
	if anchor == nil then
		return
	end
	local holder = Instance.new("Part")
	holder.Name = "PoliceLights"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.CFrame = anchor.CFrame * CFrame.new(0, 4, 0)
	holder.Parent = workspace
	local lights = {}
	for _, color in { LIGHTS.Red, LIGHTS.Blue } do
		local l = Instance.new("PointLight")
		l.Color = Color3.fromHex(color)
		l.Range = LIGHTS.Range
		l.Brightness = LIGHTS.Brightness
		l.Shadows = false
		l.Parent = holder
		table.insert(lights, l)
	end
	-- the owner hears the siren on their screen already
	local owner = plot:GetAttribute("OwnerUserId")
	local siren = if owner ~= player.UserId then sound(SOUNDS.Siren, holder, true) else nil
	active[plot] = { lights = lights, holder = holder, siren = siren }
end

local function watchPlot(plot: Instance)
	local function refresh()
		setLights(plot, plot:GetAttribute("RaidPhase") ~= nil)
	end
	plot:GetAttributeChangedSignal("RaidPhase"):Connect(refresh)
	refresh()
end

-- Report ------------------------------------------------------------------------------------

local function showReport(report: any)
	if type(report) ~= "table" then
		return
	end
	local gui = UI.Screen("RaidReport", 36)
	local panel = UI.Panel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(340, 300), Parent = gui })
	UI.Padding(panel, 14)
	UI.List(panel, 6)
	UI.Label({ LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 28), Text = Messages.Raid.ReportTitle, Font = UI.Theme.FontBlack, TextSize = 24, TextColor3 = UI.Theme.Danger, Parent = panel })
	local lines = if type(report.lines) == "table" then report.lines else {}
	local order = 2
	local function line(text: string, color: Color3?)
		UI.Label({ LayoutOrder = order, Size = UDim2.new(1, 0, 0, 18), Text = text, TextSize = 15, TextColor3 = color or UI.Theme.Text, TextXAlignment = Enum.TextXAlignment.Left, Parent = panel })
		order += 1
	end
	if #lines == 0 then
		line(Messages.Raid.Clean, UI.Theme.Money)
	else
		line(Messages.Raid.Seized .. " (" .. UI.Money(tonumber(report.seizedValue) or 0) .. "):", UI.Theme.Warning)
		for i, text in lines do
			if i > 8 then
				line(("... +%d more"):format(#lines - 8), UI.Theme.SubText)
				break
			end
			line("  " .. tostring(text))
		end
	end
	if (tonumber(report.fine) or 0) > 0 then
		line(Messages.Raid.Fine:format(UI.Money(report.fine)), UI.Theme.Danger)
	end
	if (tonumber(report.saved) or 0) > 0 then
		line(Messages.Raid.Saved:format(report.saved), UI.Theme.Money)
	end
	UI.Button({ LayoutOrder = 99, Size = UDim2.new(1, 0, 0, 34), Text = "OK", BackgroundColor3 = UI.Theme.PanelLight, Parent = panel }, function()
		gui:Destroy()
	end)
	sound(SOUNDS.Report, gui, false)
end

function HeatController:Start()
	local refreshGauge = buildGauge()
	player:GetAttributeChangedSignal("Heat"):Connect(refreshGauge)
	player:GetAttributeChangedSignal("HeatLevel"):Connect(refreshGauge)
	player:GetAttributeChangedSignal("InSight"):Connect(refreshGauge)
	refreshGauge()
	buildRaidOverlay()

	task.spawn(function()
		local hideouts = workspace:WaitForChild("Hideouts")
		hideouts.ChildAdded:Connect(watchPlot)
		for _, plot in hideouts:GetChildren() do
			watchPlot(plot)
		end
	end)
	RunService.Heartbeat:Connect(function()
		if next(active) == nil then
			return
		end
		local red = math.floor(os.clock() * LIGHTS.FlashHz) % 2 == 0
		for _, a in active do
			a.lights[1].Enabled = red
			a.lights[2].Enabled = not red
		end
	end)
	Net.GetEvent("RaidReport").OnClientEvent:Connect(showReport)
end

return HeatController

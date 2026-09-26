--!strict
-- Build mode: overhead camera over your plot, catalogue bar, green/red ghost preview.
-- PC: B toggle, click place, R rotate, M move, X sell, Esc exit. Mobile: on-screen buttons, tap to aim.
-- Only intentions are sent to the server (RequestPlace / RequestMove / RequestRemove).
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Buildables = require(Shared.Config.Buildables)
local Messages = require(Shared.Config.Messages)
local Hideout = require(Shared.Logic.Hideout)
local Net = require(Shared.Net)
local ModelFactory = require(Shared.Visual.ModelFactory)
local PlotUtil = require(Shared.Visual.PlotUtil)
local UI = require(script.Parent.Parent.UI)
local Effects = require(script.Parent.Parent.Effects)
local Notify = require(script.Parent.Parent.Notify)

local BuildController = {}

local SETTINGS = {
	CameraHeight = 55,
	CameraMinHeight = 20,
	CameraMaxHeight = 95,
	CameraBack = 0.75, -- camera distance behind the focus = height x this
	PanSpeed = 40, -- studs per second with WASD / arrows
	ZoomStep = 6,
	GhostTransparency = 0.45,
	ValidColor = Color3.fromHex("#39FF88"),
	InvalidColor = Color3.fromHex("#FF4D4D"),
	CardWidth = 120,
	BarHeight = 150,
}

local B = Economy.Building
local OPTIONS: Hideout.Options = { gridSize = B.GridSize, rotationStep = B.RotationStep, maxObjects = B.MaxObjects }

type Mode = "Place" | "Move" | "Sell"

local player = Players.LocalPlayer
local active = false
local mode: Mode = "Place"
local selectedId: string? = nil -- buildable being placed
local movingObjectId: string? = nil -- object being moved (Move mode)
local rotation = 0
local ghost: Model? = nil
local highlight: Highlight? = nil
local hoverHighlight: Highlight? = nil
local candidate: { x: number, z: number, valid: boolean }? = nil
local aimScreen: Vector2? = nil -- last touch position on mobile
local plot: Instance? = nil
local mirror: Hideout.Hideout? = nil
local mirrorDirty = true
local focus = Vector3.zero
local height = SETTINGS.CameraHeight
local busy = false

-- UI refs
local gui: ScreenGui
local toggleButton: TextButton
local bar: Frame
local itemsFrame: ScrollingFrame
local hintLabel: TextLabel
local modeButtons: { [string]: TextButton } = {}
local placeButton: TextButton
local currentCategory = Buildables.Categories[1]

local function isTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function getControls(): any
	local ok, controls = pcall(function()
		local module = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule") :: ModuleScript) :: any
		return module:GetControls()
	end)
	return if ok then controls else nil
end

-- Local copy of the stash, rebuilt from the replicated models, for instant green/red feedback.
local function getMirror(): Hideout.Hideout?
	local p = plot
	if p == nil then
		return nil
	end
	if mirror == nil or mirrorDirty then
		local objects = {}
		for _, model in (p:WaitForChild("Objects")):GetChildren() do
			local id = model:GetAttribute("ObjectId")
			local buildableId = model:GetAttribute("BuildableId")
			if type(id) == "string" and type(buildableId) == "string" then
				table.insert(objects, {
					id = id,
					buildableId = buildableId,
					x = model:GetAttribute("X") :: number,
					z = model:GetAttribute("Z") :: number,
					rotation = model:GetAttribute("Rotation") :: number,
				})
			end
		end
		local sx, sz, h = PlotUtil.GetSize(p)
		mirror = Hideout.FromObjects(objects, { sizeX = sx, sizeZ = sz, maxHeight = h }, OPTIONS, Buildables.ById)
		mirrorDirty = false
	end
	return mirror
end

local function watchPlot(p: Instance)
	local objects = p:WaitForChild("Objects")
	local function dirty()
		mirrorDirty = true
	end
	objects.ChildAdded:Connect(function(child)
		dirty()
		child.AttributeChanged:Connect(dirty)
	end)
	objects.ChildRemoved:Connect(dirty)
	for _, child in objects:GetChildren() do
		child.AttributeChanged:Connect(dirty)
	end
end

-- Ghost -----------------------------------------------------------------------------

local function clearGhost()
	if ghost then
		ghost:Destroy()
	end
	ghost = nil
	highlight = nil
	candidate = nil
end

local function makeGhost(buildableId: string)
	clearGhost()
	local def = Buildables.ById[buildableId]
	local model = ModelFactory.Buildable(def)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
			if d.Name ~= "Root" then
				d.Transparency = math.max(d.Transparency, SETTINGS.GhostTransparency)
			end
		elseif d:IsA("ProximityPrompt") or d:IsA("Light") then
			d:Destroy()
		end
	end
	local h = Instance.new("Highlight")
	h.FillTransparency = 0.65
	h.OutlineTransparency = 0
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = model
	model.Parent = workspace
	ghost = model
	highlight = h
end

-- Screen point -> plot-local (x, z) on the floor plane.
local function aimLocal(screen: Vector2): (number?, number?)
	local p = plot
	if p == nil then
		return nil, nil
	end
	local origin = PlotUtil.GetOrigin(p)
	local ray = workspace.CurrentCamera:ViewportPointToRay(screen.X, screen.Y)
	local up = origin.UpVector
	local denom = ray.Direction:Dot(up)
	if math.abs(denom) < 1e-4 then
		return nil, nil
	end
	local t = (origin.Position - ray.Origin):Dot(up) / denom
	if t < 0 then
		return nil, nil
	end
	return PlotUtil.ToLocal(origin, ray.Origin + ray.Direction * t)
end

local function currentAim(): Vector2?
	if isTouch() then
		return aimScreen
	end
	return UserInputService:GetMouseLocation()
end

local function updateGhost()
	local p = plot
	local id = selectedId
	if ghost == nil or p == nil or id == nil then
		return
	end
	local aim = currentAim()
	if aim == nil then
		return
	end
	local lx, lz = aimLocal(aim)
	if lx == nil or lz == nil then
		return
	end
	local def = Buildables.ById[id]
	local x, z = Hideout.Snap(def, lx, lz, rotation, B.GridSize)
	local h = getMirror()
	local valid = false
	if h then
		valid = h:Validate(id, x, z, rotation, movingObjectId)
	end
	if mode == "Place" then
		local money = player:GetAttribute("Money")
		valid = valid and type(money) == "number" and money >= def.price
	end
	candidate = { x = x, z = z, valid = valid }
	ghost:PivotTo(PlotUtil.ObjectCFrame(PlotUtil.GetOrigin(p), def.size.y, x, z, rotation))
	if highlight then
		highlight.FillColor = if valid then SETTINGS.ValidColor else SETTINGS.InvalidColor
		highlight.OutlineColor = highlight.FillColor
	end
end

-- Object under the cursor (Move / Sell modes).
local function objectAt(screen: Vector2): Model?
	local p = plot
	if p == nil then
		return nil
	end
	local ray = workspace.CurrentCamera:ViewportPointToRay(screen.X, screen.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { p:WaitForChild("Objects") }
	local result = workspace:Raycast(ray.Origin, ray.Direction * 600, params)
	local node: Instance? = result and result.Instance
	while node and node ~= p do
		if node:IsA("Model") and node:GetAttribute("ObjectId") then
			return node
		end
		node = node.Parent
	end
	return nil
end

-- Camera ------------------------------------------------------------------------------

local function clampFocus()
	local p = plot
	if p == nil then
		return
	end
	local origin = PlotUtil.GetOrigin(p)
	local sx, sz = PlotUtil.GetSize(p)
	local lx, lz = PlotUtil.ToLocal(origin, focus)
	lx = math.clamp(lx, -sx / 2, sx / 2)
	lz = math.clamp(lz, -sz / 2, sz / 2)
	focus = (origin * CFrame.new(lx, 0, lz)).Position
end

local function updateCamera(dt: number)
	local p = plot
	if p == nil then
		return
	end
	local origin = PlotUtil.GetOrigin(p)
	if not isTouch() and not UserInputService:GetFocusedTextBox() then
		local move = Vector3.zero
		if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) then
			move -= Vector3.zAxis
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) then
			move += Vector3.zAxis
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then
			move -= Vector3.xAxis
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then
			move += Vector3.xAxis
		end
		if move.Magnitude > 0 then
			focus += origin:VectorToWorldSpace(move.Unit * SETTINGS.PanSpeed * dt)
			clampFocus()
		end
	end
	-- camera sits on the street side of the plot (local +Z), looking down at the focus
	local back = origin:VectorToWorldSpace(Vector3.zAxis) * height * SETTINGS.CameraBack
	local camPos = focus + Vector3.new(0, height, 0) + back
	workspace.CurrentCamera.CFrame = CFrame.lookAt(camPos, focus)
end

-- Modes & selection ----------------------------------------------------------------------

local refreshItems: () -> ()

local function setHint()
	local text
	if mode == "Place" then
		text = if selectedId
			then (if isTouch() then "Tap to aim, then PLACE" else "Click to place · R rotate · M move · X sell · B exit")
			else "Pick an item below"
	elseif mode == "Move" then
		text = if movingObjectId
			then (if isTouch() then "Tap to aim, then PLACE" else "Click to drop · R rotate")
			else "Select an object to move"
	else
		text = "Select an object to sell (" .. math.floor(B.SellRefundRate * 100) .. "% refund)"
	end
	hintLabel.Text = text
	placeButton.Visible = isTouch() and (selectedId ~= nil)
	for name, button in modeButtons do
		button.BackgroundColor3 = if name == mode then UI.Theme.Accent else UI.Theme.PanelLight
	end
end

local function setMode(newMode: Mode)
	mode = newMode
	movingObjectId = nil
	if newMode ~= "Place" then
		selectedId = nil
		clearGhost()
	end
	if hoverHighlight then
		hoverHighlight.Adornee = nil
	end
	setHint()
	refreshItems()
end

local function select(buildableId: string)
	setMode("Place")
	selectedId = buildableId
	makeGhost(buildableId)
	setHint()
	refreshItems()
end

local function errorText(err: any)
	Notify.Show(Messages.ForError(err), "error")
end

local function confirm()
	local c = candidate
	local p = plot
	if busy or c == nil or p == nil then
		return
	end
	if not c.valid then
		local money = player:GetAttribute("Money")
		if mode == "Place" and selectedId and type(money) == "number" and money < Buildables.ById[selectedId].price then
			errorText("InsufficientFunds")
		else
			errorText("Collision")
		end
		return
	end
	busy = true
	local ok, result
	local def = Buildables.ById[selectedId :: string]
	if mode == "Move" and movingObjectId then
		ok, result = Net.Invoke("RequestMove", movingObjectId, c.x, c.z, rotation)
	else
		ok, result = Net.Invoke("RequestPlace", selectedId, c.x, c.z, rotation)
	end
	busy = false
	if not ok then
		errorText(result)
		return
	end
	local worldPos = PlotUtil.ObjectCFrame(PlotUtil.GetOrigin(p), def.size.y, c.x, c.z, rotation).Position
	Effects.Sparkles(worldPos, SETTINGS.ValidColor, 18)
	Effects.Sound(Effects.Sounds.Place, worldPos, 1.3)
	mirrorDirty = true
	if mode == "Move" then
		setMode("Move")
	end
end

local function pickObject(model: Model)
	local objectId = model:GetAttribute("ObjectId") :: string
	local buildableId = model:GetAttribute("BuildableId") :: string
	if mode == "Sell" then
		if busy then
			return
		end
		busy = true
		local ok, result = Net.Invoke("RequestRemove", objectId)
		busy = false
		if ok then
			Notify.Show("Sold for " .. UI.Money(tonumber(result) or 0), "money")
			mirrorDirty = true
		else
			errorText(result)
		end
	elseif mode == "Move" then
		movingObjectId = objectId
		selectedId = buildableId
		rotation = model:GetAttribute("Rotation") :: number
		makeGhost(buildableId)
		setHint()
	end
end

local function rotate()
	rotation = (rotation + B.RotationStep) % 360
end

-- Enter / exit ----------------------------------------------------------------------------

local function enter()
	plot = PlotUtil.FindPlotOf(player.UserId)
	if plot == nil then
		Notify.Show(Messages.Errors.NoPlot, "error")
		return
	end
	active = true
	mirrorDirty = true
	focus = PlotUtil.GetOrigin(plot :: Instance).Position
	height = SETTINGS.CameraHeight
	workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
	local controls = getControls()
	if controls then
		controls:Disable()
	end
	bar.Visible = true
	hintLabel.Visible = true
	toggleButton.Text = "EXIT"
	setMode("Place")
end

local function exit()
	active = false
	selectedId = nil
	movingObjectId = nil
	clearGhost()
	if hoverHighlight then
		hoverHighlight.Adornee = nil
	end
	workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
	local controls = getControls()
	if controls then
		controls:Enable()
	end
	bar.Visible = false
	hintLabel.Visible = false
	placeButton.Visible = false
	toggleButton.Text = "BUILD"
end

local function toggle()
	if active then
		exit()
	else
		enter()
	end
end

-- UI ------------------------------------------------------------------------------------------

local function buildUi()
	gui = UI.Screen("Build", 5)

	toggleButton = UI.Button({
		Name = "BuildToggle",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(110, 44),
		Text = "BUILD",
		Parent = gui,
	}, toggle)
	UI.Stroke(toggleButton, UI.Theme.Text, 1)

	hintLabel = UI.Label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 100),
		Size = UDim2.fromOffset(520, 30),
		BackgroundTransparency = 0.3,
		BackgroundColor3 = UI.Theme.Background,
		TextSize = 16,
		Visible = false,
		Parent = gui,
	})
	UI.Corner(hintLabel, 8)

	bar = UI.Panel({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.new(1, -20, 0, SETTINGS.BarHeight),
		Visible = false,
		Parent = gui,
	})
	UI.new("UISizeConstraint", { MaxSize = Vector2.new(1100, SETTINGS.BarHeight), Parent = bar })
	UI.Padding(bar, 8)

	-- top row: categories on the left, tools on the right
	local top = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, Parent = bar })
	local cats = UI.new("Frame", { Size = UDim2.new(0.55, 0, 1, 0), BackgroundTransparency = 1, Parent = top })
	UI.List(cats, 6, true)
	for i, cat in Buildables.Categories do
		UI.Button({
			Name = cat,
			LayoutOrder = i,
			Size = UDim2.fromOffset(100, 34),
			Text = string.upper(cat),
			TextSize = 14,
			BackgroundColor3 = UI.Theme.PanelLight,
			Parent = cats,
		}, function()
			currentCategory = cat
			refreshItems()
		end)
	end
	local tools = UI.new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.45, 0, 1, 0),
		BackgroundTransparency = 1,
		Parent = top,
	})
	local toolsLayout = UI.List(tools, 6, true)
	toolsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	local function tool(name: string, order: number, text: string, onClick: () -> ()): TextButton
		return UI.Button({
			Name = name,
			LayoutOrder = order,
			Size = UDim2.fromOffset(80, 34),
			Text = text,
			TextSize = 13,
			BackgroundColor3 = UI.Theme.PanelLight,
			Parent = tools,
		}, onClick)
	end
	tool("Rotate", 1, "ROTATE", rotate)
	modeButtons.Place = tool("Place", 2, "BUY", function()
		setMode("Place")
	end)
	modeButtons.Move = tool("Move", 3, "MOVE", function()
		setMode("Move")
	end)
	modeButtons.Sell = tool("Sell", 4, "SELL", function()
		setMode("Sell")
	end)

	itemsFrame = UI.Scrolling({
		Position = UDim2.fromOffset(0, 42),
		Size = UDim2.new(1, 0, 1, -42),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		Parent = bar,
	})
	UI.List(itemsFrame, 8, true)

	placeButton = UI.Button({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -(SETTINGS.BarHeight + 24)),
		Size = UDim2.fromOffset(120, 56),
		Text = "PLACE",
		TextSize = 20,
		BackgroundColor3 = UI.Theme.Money,
		TextColor3 = UI.Theme.Background,
		Visible = false,
		Parent = gui,
	}, confirm)

	hoverHighlight = UI.new("Highlight", {
		FillColor = UI.Theme.Danger,
		OutlineColor = UI.Theme.Danger,
		FillTransparency = 0.6,
		DepthMode = Enum.HighlightDepthMode.Occluded,
		Parent = workspace, -- client-only instance
	})
end

refreshItems = function()
	if not itemsFrame then
		return
	end
	UI.ClearChildren(itemsFrame)
	local money = player:GetAttribute("Money")
	for order, id in Buildables.Order do
		local def = Buildables.ById[id]
		if def.category == currentCategory then
			local affordable = type(money) == "number" and money >= def.price
			local card = UI.Button({
				Name = id,
				LayoutOrder = order,
				Size = UDim2.new(0, SETTINGS.CardWidth, 1, -4),
				Text = "",
				BackgroundColor3 = if selectedId == id then UI.Theme.Accent else UI.Theme.PanelLight,
				Parent = itemsFrame,
			}, function()
				select(id)
			end)
			UI.Label({
				Position = UDim2.fromOffset(6, 6),
				Size = UDim2.new(1, -12, 0.55, -6),
				Text = def.name,
				TextWrapped = true,
				TextSize = 15,
				Parent = card,
			})
			UI.Label({
				Position = UDim2.new(0, 6, 0.55, 0),
				Size = UDim2.new(1, -12, 0.2, 0),
				Text = UI.Money(def.price),
				TextColor3 = if affordable then UI.Theme.Money else UI.Theme.Danger,
				Font = UI.Theme.FontBlack,
				TextSize = 16,
				Parent = card,
			})
			UI.Label({
				Position = UDim2.new(0, 6, 0.75, 0),
				Size = UDim2.new(1, -12, 0.2, 0),
				Text = def.size.x .. "x" .. def.size.z .. (if def.role then "  " .. def.role else ""),
				TextColor3 = UI.Theme.SubText,
				TextSize = 12,
				Parent = card,
			})
		end
	end
end

-- Input ------------------------------------------------------------------------------------------

local function onPointer(screen: Vector2)
	if mode == "Place" or (mode == "Move" and movingObjectId) then
		if isTouch() then
			aimScreen = screen
		else
			confirm()
		end
	else
		local model = objectAt(screen)
		if model then
			pickObject(model)
		end
	end
end

function BuildController:Start()
	buildUi()
	task.spawn(function()
		while plot == nil do
			local p = PlotUtil.FindPlotOf(player.UserId)
			if p then
				plot = p
				watchPlot(p)
			end
			task.wait(1)
		end
	end)

	ContextActionService:BindAction("BM_ToggleBuild", function(_, state)
		if state == Enum.UserInputState.Begin then
			toggle()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.B)

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if not active or processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			onPointer(Vector2.new(input.Position.X, input.Position.Y))
		elseif input.KeyCode == Enum.KeyCode.R then
			rotate()
		elseif input.KeyCode == Enum.KeyCode.M then
			setMode("Move")
		elseif input.KeyCode == Enum.KeyCode.X then
			setMode("Sell")
		elseif input.KeyCode == Enum.KeyCode.Escape then
			exit()
		end
	end)

	UserInputService.InputChanged:Connect(function(input: InputObject, processed: boolean)
		if active and input.UserInputType == Enum.UserInputType.MouseWheel and not processed then
			height = math.clamp(height - input.Position.Z * SETTINGS.ZoomStep, SETTINGS.CameraMinHeight, SETTINGS.CameraMaxHeight)
		end
	end)

	player:GetAttributeChangedSignal("Money"):Connect(function()
		if active then
			refreshItems()
		end
	end)

	RunService.RenderStepped:Connect(function(dt: number)
		if not active then
			return
		end
		updateCamera(dt)
		updateGhost()
		if hoverHighlight and (mode == "Sell" or (mode == "Move" and movingObjectId == nil)) and not isTouch() then
			local model = objectAt(UserInputService:GetMouseLocation())
			hoverHighlight.Adornee = model
			hoverHighlight.FillColor = if mode == "Sell" then UI.Theme.Danger else UI.Theme.Info
			hoverHighlight.OutlineColor = hoverHighlight.FillColor
		end
	end)

	player.CharacterAdded:Connect(function()
		if active then
			exit()
		end
	end)
end

return BuildController

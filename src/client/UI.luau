--!strict
-- Tiny UI toolkit: theme + constructors. All look & feel values live in UI.Theme so the
-- authors can restyle everything from one place (or rebuild the screens in Studio later).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Economy = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Economy"))

local UI = {}

UI.Theme = {
	Background = Color3.fromHex("#0C0A18"),
	Panel = Color3.fromHex("#15122A"),
	PanelLight = Color3.fromHex("#221D3D"),
	Accent = Color3.fromHex("#B45CFF"),
	Money = Color3.fromHex("#39FF88"),
	Warning = Color3.fromHex("#FFB020"),
	Danger = Color3.fromHex("#FF4D4D"),
	Info = Color3.fromHex("#3FA9F5"),
	Text = Color3.fromHex("#F2ECFF"),
	SubText = Color3.fromHex("#A8A0C8"),
	Disabled = Color3.fromHex("#4A4560"),
	Font = Enum.Font.GothamBold,
	FontBlack = Enum.Font.GothamBlack,
	Corner = 10,
	PanelTransparency = 0.08,
}

-- Creates an instance, sets properties, parents children. `props.Parent` is applied last.
function UI.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className) :: any
	local parent = nil
	if props then
		for k, v in props do
			if k == "Parent" then
				parent = v
			else
				inst[k] = v
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = inst
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function UI.Corner(parent: Instance, radius: number?): UICorner
	return UI.new("UICorner", { CornerRadius = UDim.new(0, radius or UI.Theme.Corner), Parent = parent })
end

function UI.Stroke(parent: Instance, color: Color3, thickness: number?): UIStroke
	return UI.new("UIStroke", {
		Color = color,
		Thickness = thickness or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

function UI.Padding(parent: Instance, px: number): UIPadding
	return UI.new("UIPadding", {
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
		Parent = parent,
	})
end

function UI.List(parent: Instance, padding: number, horizontal: boolean?): UIListLayout
	return UI.new("UIListLayout", {
		Padding = UDim.new(0, padding),
		FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = parent,
	})
end

function UI.Screen(name: string, displayOrder: number?): ScreenGui
	local player = Players.LocalPlayer
	return UI.new("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		DisplayOrder = displayOrder or 0,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
end

function UI.Panel(props: { [string]: any }): Frame
	local p = table.clone(props)
	p.BackgroundColor3 = p.BackgroundColor3 or UI.Theme.Panel
	p.BackgroundTransparency = p.BackgroundTransparency or UI.Theme.PanelTransparency
	p.BorderSizePixel = 0
	local frame = UI.new("Frame", p)
	UI.Corner(frame)
	return frame
end

function UI.Label(props: { [string]: any }): TextLabel
	local p = table.clone(props)
	p.BackgroundTransparency = p.BackgroundTransparency or 1
	p.Font = p.Font or UI.Theme.Font
	p.TextColor3 = p.TextColor3 or UI.Theme.Text
	p.TextSize = p.TextSize or 16
	return UI.new("TextLabel", p)
end

-- Button with rounded corners and a little press animation. `onClick` is optional.
function UI.Button(props: { [string]: any }, onClick: (() -> ())?): TextButton
	local p = table.clone(props)
	p.BackgroundColor3 = p.BackgroundColor3 or UI.Theme.Accent
	p.BorderSizePixel = 0
	p.AutoButtonColor = true
	p.Font = p.Font or UI.Theme.FontBlack
	p.TextColor3 = p.TextColor3 or UI.Theme.Text
	p.TextSize = p.TextSize or 16
	local button = UI.new("TextButton", p)
	UI.Corner(button, 8)
	local scale = UI.new("UIScale", { Parent = button })
	button.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.06), { Scale = 0.94 }):Play()
	end)
	button.MouseButton1Up:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end)
	button.MouseLeave:Connect(function()
		scale.Scale = 1
	end)
	if onClick then
		button.Activated:Connect(onClick)
	end
	return button
end

function UI.Scrolling(props: { [string]: any }): ScrollingFrame
	local p = table.clone(props)
	p.BackgroundTransparency = p.BackgroundTransparency or 1
	p.BorderSizePixel = 0
	p.ScrollBarThickness = p.ScrollBarThickness or 6
	p.ScrollBarImageColor3 = UI.Theme.Accent
	p.CanvasSize = UDim2.new()
	p.AutomaticCanvasSize = p.AutomaticCanvasSize or Enum.AutomaticSize.Y
	return UI.new("ScrollingFrame", p)
end

function UI.RarityColor(rarity: string?): Color3
	local hex = rarity and Economy.RarityColor[rarity]
	return if hex then Color3.fromHex(hex) else UI.Theme.Text
end

-- 1234567 -> "$1,234,567"
function UI.Money(n: number): string
	local s = tostring(math.floor(math.abs(n)))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return (if n < 0 then "-$" else "$") .. out
end

function UI.ClearChildren(parent: Instance, keepClass: string?)
	for _, c in parent:GetChildren() do
		if not (keepClass and c:IsA(keepClass)) and not c:IsA("UIListLayout") and not c:IsA("UIGridLayout") and not c:IsA("UIPadding") then
			c:Destroy()
		end
	end
end

return UI

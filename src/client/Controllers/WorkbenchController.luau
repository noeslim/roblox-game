--!strict
-- Workbench screen, opened with the workbench prompt (E / tap). Three tabs:
-- CRAFT (pick a part per slot, live 3D preview + stats), SUPPLIER (buy parts), WEAPONS (set prices).
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local City = require(Shared.Config.City)
local Cinematics = require(Shared.Config.Cinematics)
local Parts = require(Shared.Config.Parts)
local Messages = require(Shared.Config.Messages)
local Inventory = require(Shared.Logic.Inventory)
local Shop = require(Shared.Logic.Shop)
local WeaponCrafting = require(Shared.Logic.WeaponCrafting)
local Net = require(Shared.Net)
local ModelFactory = require(Shared.Visual.ModelFactory)
local UI = require(script.Parent.Parent.UI)
local State = require(script.Parent.Parent.State)
local Notify = require(script.Parent.Parent.Notify)
local Effects = require(script.Parent.Parent.Effects)
local CraftCinematicController = require(script.Parent.CraftCinematicController)

local WorkbenchController = {}

local SETTINGS = {
	MaxSize = Vector2.new(820, 540),
	AutoCloseDistance = Economy.Crafting.WorkbenchRange + 6,
	PreviewSpin = 0.8, -- radians per second
}

local STAT_KEYS = { "Damage", "FireRate", "Range", "Accuracy", "Reload" }

local player = Players.LocalPlayer
local gui: ScreenGui
local content: Frame
local tabButtons: { [string]: TextButton } = {}
local currentTab = "Craft"
local benchPart: BasePart? = nil
local selection: { [string]: string? } = {} -- slot -> chosen part id
local busy = false

-- viewport preview
local viewport: ViewportFrame
local previewModel: Model? = nil
local previewAngle = 0

local render: () -> ()

local function errorText(err: any)
	Notify.Show(Messages.ForError(err), "error")
end

local function data(): any
	return State.Get()
end

-- CRAFT -------------------------------------------------------------------------------------------

local function ownedFor(slot: string): { string }
	local d = data()
	if d == nil then
		return {}
	end
	return Inventory.OwnedForSlot(d.Parts, Parts, slot, Economy.RarityOrder)
end

-- keeps the selection valid (drops parts no longer owned, picks the first owned one)
local function fixSelection()
	for _, slot in Economy.Crafting.Slots do
		local owned = ownedFor(slot)
		local current = selection[slot]
		if current == nil or not table.find(owned, current) then
			selection[slot] = owned[1]
		end
	end
end

local function cycle(slot: string, dir: number)
	local owned = ownedFor(slot)
	if #owned == 0 then
		return
	end
	local i = table.find(owned, selection[slot] or "") or 1
	i = ((i - 1 + dir) % #owned) + 1
	selection[slot] = owned[i]
	render()
end

local function currentRecipe(): { [string]: string }
	local recipe = {}
	for slot, id in selection do
		if id then
			recipe[slot] = id
		end
	end
	return recipe
end

local function updatePreviewModel(recipe: { [string]: string }, rarity: string?)
	if previewModel then
		previewModel:Destroy()
	end
	local model = ModelFactory.Weapon(recipe, Parts, rarity, nil)
	model:PivotTo(CFrame.identity)
	model.Parent = viewport
	previewModel = model
end

local function doCraft()
	if busy then
		return
	end
	busy = true
	local recipe = currentRecipe()
	local ok, result = Net.Invoke("RequestCraft", recipe)
	busy = false
	if ok then
		local bench = benchPart
		if Cinematics.Craft.Enabled and bench and bench.Parent and not CraftCinematicController.IsPlaying() then
			-- first-person assembly scene; the UI comes back when it ends
			gui.Enabled = false
			CraftCinematicController.Play(bench, recipe, result, function()
				if benchPart == bench then
					gui.Enabled = true
					render()
				end
			end)
		else
			Notify.Show(("Crafted %s (%s) - suggested price %s"):format(result.name, result.rarity, UI.Money(result.suggestedPrice)), "success")
		end
	else
		errorText(result)
	end
end

local function renderCraft()
	fixSelection()
	local recipe = currentRecipe()
	local weapon = WeaponCrafting.Craft(recipe, "", Parts, Economy)

	local left = UI.new("Frame", { Size = UDim2.new(0.5, -6, 1, 0), BackgroundTransparency = 1, Parent = content })
	UI.List(left, 6)
	for i, slot in Economy.Crafting.Slots do
		local id = selection[slot]
		local part = id and Parts[id]
		local d = data()
		local count = if d and id then Inventory.Count(d.Parts, id) else 0
		local row = UI.Panel({ LayoutOrder = i, Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = UI.Theme.PanelLight, Parent = left })
		UI.Label({ Position = UDim2.fromOffset(10, 0), Size = UDim2.new(0, 80, 1, 0), Text = string.upper(slot), TextSize = 13, TextColor3 = UI.Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
		UI.Button({ Position = UDim2.new(0, 88, 0.5, -16), Size = UDim2.fromOffset(32, 32), Text = "<", BackgroundColor3 = UI.Theme.Panel, Parent = row }, function()
			cycle(slot, -1)
		end)
		UI.Label({
			Position = UDim2.new(0, 124, 0, 0),
			Size = UDim2.new(1, -168, 1, 0),
			Text = if part then ("%s  x%d"):format(part.name, count) else "No part - buy some!",
			TextColor3 = if part then UI.RarityColor(part.rarity) else UI.Theme.Danger,
			TextWrapped = true,
			TextSize = 15,
			Parent = row,
		})
		UI.Button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0.5, -16), Size = UDim2.fromOffset(32, 32), Text = ">", BackgroundColor3 = UI.Theme.Panel, Parent = row }, function()
			cycle(slot, 1)
		end)
	end

	local right = UI.new("Frame", { Position = UDim2.new(0.5, 6, 0, 0), Size = UDim2.new(0.5, -6, 1, 0), BackgroundTransparency = 1, Parent = content })
	viewport = UI.new("ViewportFrame", {
		Size = UDim2.new(1, 0, 0.45, 0),
		BackgroundColor3 = UI.Theme.Background,
		BackgroundTransparency = 0.2,
		Ambient = Color3.fromRGB(200, 200, 220),
		LightColor = Color3.new(1, 1, 1),
		Parent = right,
	})
	UI.Corner(viewport)
	local camera = UI.new("Camera", { FieldOfView = 40, Parent = viewport })
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 1.2, 7), Vector3.zero)
	viewport.CurrentCamera = camera
	updatePreviewModel(recipe, weapon and weapon.rarity)

	local info = UI.new("Frame", { Position = UDim2.new(0, 0, 0.45, 8), Size = UDim2.new(1, 0, 0.55, -8), BackgroundTransparency = 1, Parent = right })
	UI.List(info, 2)
	local function line(order: number, text: string, color: Color3?, size: number?)
		UI.Label({ LayoutOrder = order, Size = UDim2.new(1, 0, 0, (size or 15) + 6), Text = text, TextColor3 = color or UI.Theme.Text, TextSize = size or 15, TextXAlignment = Enum.TextXAlignment.Left, Parent = info })
	end
	if weapon then
		line(1, string.upper(weapon.rarity) .. (if weapon.fullSet then "  ·  FULL " .. string.upper(weapon.fullSet) .. " SET +" .. math.floor(Economy.Crafting.FullSetBonus * 100) .. "%" else ""), UI.RarityColor(weapon.rarity), 18)
		line(2, ("Value %s   ·   Suggested %s"):format(UI.Money(weapon.value), UI.Money(weapon.suggestedPrice)), UI.Theme.Money)
		local stats = {}
		for _, key in STAT_KEYS do
			table.insert(stats, key .. " " .. (weapon.stats[key] or 0))
		end
		line(3, table.concat(stats, "  ·  "), UI.Theme.SubText, 13)
		if weapon.contraband then
			line(4, "CONTRABAND - attracts shady buyers (and the police, later)", UI.Theme.Danger, 13)
		end
	else
		line(1, "Pick one part for each slot.", UI.Theme.SubText)
	end
	UI.Button({
		LayoutOrder = 10,
		Size = UDim2.new(1, 0, 0, 46),
		Text = "CRAFT",
		TextSize = 22,
		BackgroundColor3 = if weapon then UI.Theme.Money else UI.Theme.Disabled,
		TextColor3 = UI.Theme.Background,
		Parent = info,
	}, function()
		if weapon then
			doCraft()
		else
			errorText("MissingSlot")
		end
	end)
end

-- SUPPLIER -------------------------------------------------------------------------------------------

local function buy(partId: string, amount: number)
	if busy then
		return
	end
	busy = true
	local ok, result = Net.Invoke("RequestBuyPart", partId, amount)
	busy = false
	if ok then
		Effects.Sound(Effects.Sounds.Cash, nil, 1.4)
	else
		errorText(result)
	end
end

-- Inside the supplier's warehouse there is no delivery fee (the server decides, this is for display).
local function atSupplier(): boolean
	local spot = ReplicatedStorage:GetAttribute("Poi_Supplier") -- published by PoiService
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if typeof(spot) == "Vector3" and root and root:IsA("BasePart") then
		return (spot - root.Position).Magnitude <= City.Poi.UseRadius
	end
	return false
end

local function renderSupplier()
	local onSite = atSupplier()
	UI.Label({
		Size = UDim2.new(1, 0, 0, 18),
		Text = if onSite then Messages.Poi.OnSiteNote else Messages.Poi.DeliveryNote:format(math.floor(Economy.Supplier.DeliveryFee * 100 + 0.5)),
		TextSize = 13,
		TextColor3 = if onSite then UI.Theme.Money else UI.Theme.Warning,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = content,
	})
	local list = UI.Scrolling({ Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 1, -24), Parent = content })
	UI.List(list, 6)
	local d = data()
	local money = player:GetAttribute("Money")
	for i, id in Shop.Catalogue(Parts, Economy) do
		local part = Parts[id]
		local price = Shop.PartPrice(part, Economy, onSite) :: number
		local row = UI.Panel({ LayoutOrder = i, Size = UDim2.new(1, -8, 0, 46), BackgroundColor3 = UI.Theme.PanelLight, Parent = list })
		UI.Label({ Position = UDim2.fromOffset(10, 0), Size = UDim2.new(0.4, -10, 1, 0), Text = part.name, TextColor3 = UI.RarityColor(part.rarity), TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
		UI.Label({ Position = UDim2.fromScale(0.4, 0), Size = UDim2.new(0.18, 0, 1, 0), Text = part.slot, TextColor3 = UI.Theme.SubText, TextSize = 13, Parent = row })
		UI.Label({ Position = UDim2.fromScale(0.58, 0), Size = UDim2.new(0.12, 0, 1, 0), Text = "owned " .. (if d then Inventory.Count(d.Parts, id) else 0), TextColor3 = UI.Theme.SubText, TextSize = 13, Parent = row })
		local affordable = type(money) == "number" and money >= price
		UI.Button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -96, 0.5, 0),
			Size = UDim2.fromOffset(84, 34),
			Text = UI.Money(price),
			TextSize = 14,
			BackgroundColor3 = if affordable then UI.Theme.Money else UI.Theme.Disabled,
			TextColor3 = UI.Theme.Background,
			Parent = row,
		}, function()
			buy(id, 1)
		end)
		UI.Button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -6, 0.5, 0),
			Size = UDim2.fromOffset(84, 34),
			Text = "x5 " .. UI.Money(price * 5),
			TextSize = 12,
			BackgroundColor3 = UI.Theme.Accent,
			Parent = row,
		}, function()
			buy(id, 5)
		end)
	end
end

-- WEAPONS ---------------------------------------------------------------------------------------------

local function setPrice(weapon: any, price: number)
	if busy then
		return
	end
	busy = true
	local ok, result = Net.Invoke("RequestSetPrice", weapon.id, price)
	busy = false
	if not ok then
		errorText(result)
	end
end

local function renderWeapons()
	local d = data()
	local weapons = if d then d.Weapons else {}
	if #weapons == 0 then
		UI.Label({ Size = UDim2.fromScale(1, 1), Text = "No weapons yet. Craft one in the CRAFT tab!", TextColor3 = UI.Theme.SubText, Parent = content })
		return
	end
	local list = UI.Scrolling({ Size = UDim2.fromScale(1, 1), Parent = content })
	UI.List(list, 6)
	for i, w in weapons do
		local row = UI.Panel({ LayoutOrder = i, Size = UDim2.new(1, -8, 0, 54), BackgroundColor3 = UI.Theme.PanelLight, Parent = list })
		UI.Label({ Position = UDim2.fromOffset(10, 4), Size = UDim2.new(0.45, -10, 0, 24), Text = w.name, TextColor3 = UI.RarityColor(w.rarity), TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
		UI.Label({
			Position = UDim2.fromOffset(10, 28),
			Size = UDim2.new(0.45, -10, 0, 20),
			Text = ("%s · value %s%s"):format(w.rarity, UI.Money(w.value), if w.contraband then " · CONTRABAND" else ""),
			TextColor3 = UI.Theme.SubText,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		UI.Button({ Position = UDim2.new(0.45, 0, 0.5, -15), Size = UDim2.fromOffset(30, 30), Text = "-", BackgroundColor3 = UI.Theme.Panel, Parent = row }, function()
			setPrice(w, Shop.StepPrice(w.price, -1, w.suggestedPrice, w.value, Economy))
		end)
		UI.Label({
			Position = UDim2.new(0.45, 34, 0, 0),
			Size = UDim2.new(0, 90, 1, 0),
			Text = UI.Money(w.price),
			TextColor3 = if w.price > w.suggestedPrice then UI.Theme.Warning else UI.Theme.Money,
			Font = UI.Theme.FontBlack,
			Parent = row,
		})
		UI.Button({ Position = UDim2.new(0.45, 128, 0.5, -15), Size = UDim2.fromOffset(30, 30), Text = "+", BackgroundColor3 = UI.Theme.Panel, Parent = row }, function()
			setPrice(w, Shop.StepPrice(w.price, 1, w.suggestedPrice, w.value, Economy))
		end)
		UI.Button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(110, 32),
			Text = "SUGGESTED",
			TextSize = 12,
			BackgroundColor3 = UI.Theme.Accent,
			Parent = row,
		}, function()
			setPrice(w, w.suggestedPrice)
		end)
	end
end

-- Frame ------------------------------------------------------------------------------------------------

render = function()
	if not gui.Enabled then
		return
	end
	UI.ClearChildren(content)
	previewModel = nil
	for name, button in tabButtons do
		button.BackgroundColor3 = if name == currentTab then UI.Theme.Accent else UI.Theme.PanelLight
	end
	if currentTab == "Craft" then
		renderCraft()
	elseif currentTab == "Supplier" then
		renderSupplier()
	else
		renderWeapons()
	end
end

local function close()
	gui.Enabled = false
	benchPart = nil
end

function WorkbenchController.Open(bench: BasePart?, tab: string?)
	benchPart = bench
	if tab then
		currentTab = tab
	end
	gui.Enabled = true
	render()
end

local function buildUi()
	gui = UI.Screen("Workbench", 20)
	gui.Enabled = false
	local panel = UI.Panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(0.92, 0.78),
		Parent = gui,
	})
	UI.new("UISizeConstraint", { MaxSize = SETTINGS.MaxSize, Parent = panel })
	UI.Stroke(panel, UI.Theme.Accent, 2)
	UI.Padding(panel, 12)

	UI.Label({ Size = UDim2.new(1, -50, 0, 30), Text = "WORKBENCH", Font = UI.Theme.FontBlack, TextSize = 24, TextXAlignment = Enum.TextXAlignment.Left, Parent = panel })
	UI.Button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(36, 30), Text = "X", BackgroundColor3 = UI.Theme.Danger, Parent = panel }, close)

	local tabs = UI.new("Frame", { Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, Parent = panel })
	UI.List(tabs, 6, true)
	for i, name in { "Craft", "Supplier", "Weapons" } do
		tabButtons[name] = UI.Button({ LayoutOrder = i, Size = UDim2.fromOffset(120, 34), Text = string.upper(name), TextSize = 14, Parent = tabs }, function()
			currentTab = name
			render()
		end)
	end

	content = UI.new("Frame", { Position = UDim2.fromOffset(0, 82), Size = UDim2.new(1, 0, 1, -82), BackgroundTransparency = 1, Parent = panel })
end

function WorkbenchController:Start()
	buildUi()

	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		local parent = prompt.Parent
		local part = if parent and parent:IsA("BasePart") then parent else nil
		if who == player and prompt.Name == "WorkbenchPrompt" then
			WorkbenchController.Open(part)
		elseif who == player and prompt.Name == "ShopPrompt" and prompt:GetAttribute("Shop") == "Supplier" then
			WorkbenchController.Open(part, "Supplier")
		end
	end)

	State.Changed:Connect(function()
		if gui.Enabled then
			render()
		end
	end)
	player:GetAttributeChangedSignal("Money"):Connect(function()
		if gui.Enabled and currentTab == "Supplier" then
			render()
		end
	end)

	RunService.RenderStepped:Connect(function(dt: number)
		if not gui.Enabled or CraftCinematicController.IsPlaying() then
			return
		end
		local model = previewModel
		if model and model.Parent then
			previewAngle += dt * SETTINGS.PreviewSpin
			model:PivotTo(CFrame.Angles(0.25, previewAngle, 0))
		end
		-- walked away from the bench: close
		local bench = benchPart
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if bench and root and (bench.Position - root.Position).Magnitude > SETTINGS.AutoCloseDistance then
			close()
		end
	end)
end

return WorkbenchController

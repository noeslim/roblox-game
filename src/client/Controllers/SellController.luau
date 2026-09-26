--!strict
-- Deal screen, opened with the "Deal" prompt on the customer at your counter.
-- Lists your weapons (the ones this customer wants first), shows counter-offers.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Messages = require(Shared.Config.Messages)
local Customer = require(Shared.Logic.Customer)
local Net = require(Shared.Net)
local UI = require(script.Parent.Parent.UI)
local State = require(script.Parent.Parent.State)
local Notify = require(script.Parent.Parent.Notify)

local SellController = {}

local SETTINGS = {
	MaxSize = Vector2.new(560, 460),
	AutoCloseDistance = Economy.Customers.MaxServeDistance + 4,
}

local player = Players.LocalPlayer
local gui: ScreenGui
local titleLabel: TextLabel
local wantsLabel: TextLabel
local list: ScrollingFrame
local counterBar: Frame
local counterLabel: TextLabel
local customerModel: Model? = nil
local busy = false

local render: () -> ()

-- What the customer wants, rebuilt from the shared config (budget stays secret).
local function profileOf(model: Model): any
	local personality = model:GetAttribute("Personality") :: string
	local p = Economy.Customers.Personalities[personality]
	if p == nil then
		return nil
	end
	return {
		personality = personality,
		budgetMultiplier = 1,
		patience = p.patience,
		tip = p.tip,
		negotiates = p.negotiates,
		minRarity = p.minRarity,
		wantsContraband = p.wantsContraband == true,
	}
end

local function close()
	gui.Enabled = false
	customerModel = nil
	counterBar.Visible = false
end

local function customerId(): string?
	local model = customerModel
	return if model then model:GetAttribute("CustomerId") :: string? else nil
end

local function offer(weapon: any)
	local id = customerId()
	if busy or id == nil then
		return
	end
	busy = true
	local ok, result = Net.Invoke("RequestSell", id, weapon.id)
	busy = false
	if not ok then
		Notify.Show(Messages.ForError(result), "error")
		if result == "UnknownCustomer" or result == "NotReady" then
			close()
		end
		return
	end
	if result.decision == "Accept" then
		close()
	elseif result.decision == "Counter" then
		counterLabel.Text = ("They offer %s for %s"):format(UI.Money(result.price), weapon.name)
		counterBar.Visible = true
	elseif result.decision == "Refuse" then
		Notify.Show("Too expensive for them. Lower the price at your workbench.", "warning")
	else
		Notify.Show("They don't want that one.", "warning")
	end
end

local function acceptCounter()
	local id = customerId()
	if busy or id == nil then
		return
	end
	busy = true
	local ok, result = Net.Invoke("RequestAcceptCounter", id)
	busy = false
	if ok then
		close()
	else
		Notify.Show(Messages.ForError(result), "error")
		counterBar.Visible = false
	end
end

local function declineCounter()
	local id = customerId()
	counterBar.Visible = false
	if id then
		Net.Invoke("RequestDecline", id)
	end
end

render = function()
	local model = customerModel
	if not gui.Enabled or model == nil then
		return
	end
	local profile = profileOf(model)
	local personality = model:GetAttribute("Personality") :: string
	titleLabel.Text = "DEAL · " .. string.upper((Messages.PersonalityNames :: any)[personality] or personality)
	wantsLabel.Text = if profile == nil
		then ""
		elseif profile.wantsContraband then "Wants contraband"
		elseif profile.minRarity then "Wants " .. profile.minRarity .. " or better"
		else "Wants any blaster"

	UI.ClearChildren(list)
	local d = State.Get()
	local weapons = if d then d.Weapons else {}
	if #weapons == 0 then
		UI.Label({ Size = UDim2.new(1, 0, 0, 60), Text = "No weapons to sell. Craft some at your workbench!", TextColor3 = UI.Theme.SubText, TextWrapped = true, Parent = list })
		return
	end
	for i, w in weapons do
		local interested = profile == nil or Customer.IsInterested(profile, w, Economy.RarityOrder)
		local row = UI.Panel({
			LayoutOrder = if interested then i else 1000 + i,
			Size = UDim2.new(1, -8, 0, 50),
			BackgroundColor3 = UI.Theme.PanelLight,
			BackgroundTransparency = if interested then 0.05 else 0.5,
			Parent = list,
		})
		UI.Label({ Position = UDim2.fromOffset(10, 4), Size = UDim2.new(0.6, -10, 0, 24), Text = w.name, TextColor3 = UI.RarityColor(w.rarity), TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
		UI.Label({
			Position = UDim2.fromOffset(10, 26),
			Size = UDim2.new(0.6, -10, 0, 20),
			Text = if interested then w.rarity .. (if w.contraband then " · contraband" else "") else "Not interested",
			TextColor3 = if interested then UI.Theme.SubText else UI.Theme.Danger,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		UI.Button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(150, 36),
			Text = "OFFER " .. UI.Money(w.price),
			TextSize = 14,
			BackgroundColor3 = if interested then UI.Theme.Money else UI.Theme.Disabled,
			TextColor3 = UI.Theme.Background,
			Parent = row,
		}, function()
			offer(w)
		end)
	end
end

function SellController.Open(model: Model)
	customerModel = model
	counterBar.Visible = false
	gui.Enabled = true
	render()
end

local function buildUi()
	gui = UI.Screen("Deal", 20)
	gui.Enabled = false
	local panel = UI.Panel({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.55, 0),
		Size = UDim2.fromScale(0.45, 0.62),
		Parent = gui,
	})
	UI.new("UISizeConstraint", { MaxSize = SETTINGS.MaxSize, MinSize = Vector2.new(300, 260), Parent = panel })
	UI.Stroke(panel, UI.Theme.Money, 2)
	UI.Padding(panel, 12)

	titleLabel = UI.Label({ Size = UDim2.new(1, -44, 0, 28), Text = "DEAL", Font = UI.Theme.FontBlack, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left, Parent = panel })
	UI.Button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(36, 28), Text = "X", BackgroundColor3 = UI.Theme.Danger, Parent = panel }, function()
		declineCounter()
		close()
	end)
	wantsLabel = UI.Label({ Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 22), TextColor3 = UI.Theme.Warning, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Parent = panel })

	list = UI.Scrolling({ Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 1, -58), Parent = panel })
	UI.List(list, 6)

	counterBar = UI.Panel({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.new(1, 0, 0, 96),
		BackgroundColor3 = UI.Theme.Background,
		BackgroundTransparency = 0,
		Visible = false,
		ZIndex = 5,
		Parent = panel,
	})
	UI.Stroke(counterBar, UI.Theme.Warning, 2)
	counterLabel = UI.Label({ Size = UDim2.new(1, 0, 0, 40), TextColor3 = UI.Theme.Warning, TextWrapped = true, ZIndex = 6, Parent = counterBar })
	UI.Button({ Position = UDim2.new(0, 10, 1, -46), Size = UDim2.new(0.5, -15, 0, 38), Text = "ACCEPT", BackgroundColor3 = UI.Theme.Money, TextColor3 = UI.Theme.Background, ZIndex = 6, Parent = counterBar }, acceptCounter)
	UI.Button({ Position = UDim2.new(0.5, 5, 1, -46), Size = UDim2.new(0.5, -15, 0, 38), Text = "DECLINE", BackgroundColor3 = UI.Theme.Danger, ZIndex = 6, Parent = counterBar }, declineCounter)
end

function SellController:Start()
	buildUi()

	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who ~= player or prompt.Name ~= "DealPrompt" then
			return
		end
		local model = prompt:FindFirstAncestorOfClass("Model")
		if model and model:GetAttribute("OwnerUserId") == player.UserId then
			SellController.Open(model)
		end
	end)

	State.Changed:Connect(function()
		if gui.Enabled then
			render()
		end
	end)

	RunService.Heartbeat:Connect(function()
		local model = customerModel
		if not gui.Enabled or model == nil then
			return
		end
		local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
		local character = player.Character
		local myRoot = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if model.Parent == nil or root == nil or myRoot == nil or (root.Position - myRoot.Position).Magnitude > SETTINGS.AutoCloseDistance then
			close()
		end
	end)
end

return SellController

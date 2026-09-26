--!strict
-- First-person sale (Config/Cinematics.Deal, timeline in Logic/DealScene, poses in Visual/DealPoses).
-- You lay the weapon on the counter, the customer takes it and inspects it, slides the cash to you,
-- you shake hands and count the bills while the total shows. The server plays the customer's
-- gestures on the same timeline (SaleService). Purely visual: the sale is already done.
-- Click / space / E skips.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cinematics = require(Shared.Config.Cinematics)
local Parts = require(Shared.Config.Parts)
local DealScene = require(Shared.Logic.DealScene)
local ModelFactory = require(Shared.Visual.ModelFactory)
local DealPoses = require(Shared.Visual.DealPoses)
local UI = require(script.Parent.Parent.UI)
local Freeze = require(script.Parent.Parent.Freeze)
local FirstPerson = require(script.Parent.Parent.FirstPerson)

local DealCinematicController = {}

local C = Cinematics.Deal
local player = Players.LocalPlayer
local playing = false
local restoreHud: (() -> ())? = nil
local Poses = DealPoses.new({ CFrame = CFrame, Vector3 = Vector3, DealScene = DealScene }, C)

local CASH_COLOR = Color3.fromHex("#4F6B4A")
local BAND_COLOR = Color3.fromHex("#C9B27A")
local BILL_SECONDS = 0.28

local function revealCard(info: any): ScreenGui
	local gui = UI.Screen("DealReveal", 30)
	gui.IgnoreGuiInset = true
	local frame = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -40), Size = UDim2.fromOffset(420, 78), BackgroundTransparency = 1, Parent = gui })
	UI.Label({ Size = UDim2.new(1, 0, 0, 32), Text = "SOLD  " .. UI.Money(tonumber(info.total) or 0), Font = UI.Theme.FontBlack, TextSize = 28, TextColor3 = UI.Theme.Money, TextStrokeTransparency = 0.5, Parent = frame })
	UI.Label({ Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 0, 20), Text = string.upper(tostring(info.weaponName or "")), Font = UI.Theme.FontBlack, TextSize = 16, TextColor3 = UI.RarityColor(tostring(info.rarity)), TextStrokeTransparency = 0.5, Parent = frame })
	local extra = {}
	if type(info.combo) == "number" and info.combo > 1 and type(info.multiplier) == "number" then
		table.insert(extra, ("streak x%.1f"):format(info.multiplier))
	end
	if type(info.tip) == "number" and info.tip > 0 then
		table.insert(extra, "tip " .. UI.Money(info.tip))
	end
	if #extra > 0 then
		UI.Label({ Position = UDim2.fromOffset(0, 56), Size = UDim2.new(1, 0, 0, 18), Text = table.concat(extra, "  ·  "), TextSize = 15, TextColor3 = UI.Theme.Warning, TextStrokeTransparency = 0.5, Parent = frame })
	end
	TweenService:Create(frame, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Position = UDim2.new(0.5, 0, 1, -60) }):Play()
	return gui
end

-- Last resort when the scene fails to start: give everything back to the player.
local function showHud()
	local restore = restoreHud
	restoreHud = nil
	if restore then
		restore()
	end
end

local function emergencyRestore()
	playing = false
	showHud()
	workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
	FirstPerson.SetCharacterHidden(false)
	Freeze.Set(false)
	local leftover = workspace:FindFirstChild("DealCinematic")
	if leftover then
		leftover:Destroy()
	end
	local gui = player:FindFirstChild("PlayerGui")
	for _, name in { "CraftLetterbox", "DealReveal" } do
		local g = gui and gui:FindFirstChild(name)
		if g then
			g:Destroy()
		end
	end
end

-- Where the counter top is between you and the customer: the server's counter, else a ray down.
local function counterPoint(info: any, eye: Vector3, chest: Vector3, exclude: { Instance }): Vector3
	local mid = (eye + chest) / 2
	local y: number? = if typeof(info.counterTop) == "Vector3" then (info.counterTop :: Vector3).Y else nil
	if y == nil then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = exclude
		local hit = workspace:Raycast(Vector3.new(mid.X, eye.Y, mid.Z), Vector3.new(0, -6, 0), params)
		y = if hit then hit.Position.Y else eye.Y - 1.6
	end
	-- a counter above the chest or at the feet would put everything out of view
	local top = math.clamp(y :: number, eye.Y - 2.6, eye.Y - 0.9)
	return Vector3.new(mid.X, top, mid.Z)
end

local function cashModel(parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = "Cash"
	local stack = FirstPerson.Piece("Stack", Poses.CashSize, CASH_COLOR, Enum.Material.Fabric, m)
	local band = FirstPerson.Piece("Band", Vector3.new(0.16, Poses.CashSize.Y + 0.02, Poses.CashSize.Z + 0.02), BAND_COLOR, Enum.Material.SmoothPlastic, m)
	band.CFrame = stack.CFrame
	m.PrimaryPart = stack
	m.Parent = parent
	return m
end

local play: (any) -> ()

-- info = the SaleFx payload (see SaleService). Never leaves the player stuck: any error ends the
-- scene and restores the camera and controls.
function DealCinematicController.Play(info: any)
	if playing then
		return
	end
	playing = true
	local ok = xpcall(play, function(err)
		warn("[DealCinematic] could not start: " .. tostring(err))
	end, info)
	if not ok then
		emergencyRestore()
	end
end

play = function(info: any)
	local camera = workspace.CurrentCamera
	local oldFov = camera.FieldOfView
	local startCF = camera.CFrame
	local character = player.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	assert(character and head, "no character")

	local customer: Model? = if typeof(info.customer) == "Instance" and (info.customer :: Instance):IsA("Model") then info.customer :: Model else nil
	local function customerPart(name: string): BasePart?
		local p = customer and customer:FindFirstChild(name)
		return if p and p:IsA("BasePart") then p else nil
	end
	local chestPart = customerPart("UpperTorso") or customerPart("Torso") or customerPart("HumanoidRootPart")
	local chest = if chestPart then chestPart.Position else (info.position :: Vector3) + Vector3.new(0, 1.5, 0)
	local eye = head.Position
	local exclude: { Instance } = { character }
	if customer then
		table.insert(exclude, customer)
	end
	local ctx = Poses.Context(eye, counterPoint(info, eye, chest, exclude), chest)
	local plan = ctx.plan

	local folder = Instance.new("Folder")
	folder.Name = "DealCinematic"
	folder.Parent = workspace
	local weapon: Model? = nil
	if type(info.parts) == "table" then
		local w = ModelFactory.Weapon(info.parts, Parts, info.rarity, nil)
		w:ScaleTo(C.WeaponScale)
		local root = w.PrimaryPart
		if root then
			root.Transparency = 1
		end
		w.Parent = folder
		weapon = w
	end
	local cash = cashModel(folder)
	local right = FirstPerson.MakeHand(1, folder, C.HandScale)
	local left = FirstPerson.MakeHand(-1, folder, C.HandScale)
	local barGui, fade = FirstPerson.Letterbox()

	-- everything is ready: take the camera and freeze the character
	Freeze.Set(true)
	restoreHud = FirstPerson.HideHud({ "CraftLetterbox" })
	FirstPerson.SetCharacterHidden(true)
	camera.CameraType = Enum.CameraType.Scriptable

	local reveal: ScreenGui? = nil
	local fired: { [string]: boolean } = {}
	local bills: { { part: Part, at: number } } = {}
	local counted = 0
	local started = os.clock()
	local last = started
	local skipTo: number? = nil
	local elapsedOffset = 0
	local finished = false
	local rightCF, leftCF = Poses.Rest(ctx, 1), Poses.Rest(ctx, -1)

	local function once(key: string, id: string, pitch: number?)
		if not fired[key] then
			fired[key] = true
			FirstPerson.Sound(id, pitch, C.Volume)
		end
	end
	local function customerHand(): CFrame?
		local hand = customerPart("RightHand") or customerPart("Right Arm")
		return hand and hand.CFrame
	end

	local SKIP_INPUTS = { [Enum.UserInputType.MouseButton1] = true, [Enum.UserInputType.Touch] = true }
	local SKIP_KEYS = { [Enum.KeyCode.Space] = true, [Enum.KeyCode.E] = true, [Enum.KeyCode.ButtonA] = true, [Enum.KeyCode.Escape] = true }
	local skipConn = UserInputService.InputBegan:Connect(function(input)
		if (SKIP_INPUTS[input.UserInputType] or SKIP_KEYS[input.KeyCode]) and os.clock() - started > C.SkipAfter then
			skipTo = plan.outro
		end
	end)

	local conn: RBXScriptConnection? = nil
	local function finish()
		if finished then
			return
		end
		finished = true
		playing = false
		if conn then
			conn:Disconnect()
		end
		skipConn:Disconnect()
		pcall(function()
			folder:Destroy()
		end)
		local card = reveal or revealCard(info) -- skipped before the count: still show the total
		task.delay(1.5, function()
			card:Destroy()
		end)
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = oldFov
		FirstPerson.SetCharacterHidden(false)
		Freeze.Set(false)
		showHud()
		TweenService:Create(fade, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
		task.delay(0.35, function()
			barGui:Destroy()
		end)
	end

	local function frame()
		local now = os.clock()
		local dt = math.min(0.1, now - last)
		last = now
		local t = now - started + elapsedOffset
		local skip = skipTo
		local hand = customerHand()
		if skip and t < skip then
			elapsedOffset += skip - t
			t = skip
			rightCF, leftCF = Poses.Hands(ctx, t, hand) -- jump: hands snap to their new place
		end
		skipTo = nil
		local phase = DealScene.Phase(plan, t)

		-- camera: from the normal view to your eyes, then a slow breathing sway
		local camCF = Poses.Camera(ctx, t)
		if t < C.IntroSeconds then
			local u = DealScene.Smooth(t / C.IntroSeconds)
			camCF = startCF:Lerp(camCF, u)
			camera.FieldOfView = oldFov + (C.Fov - oldFov) * u
		else
			camCF *= CFrame.new(math.sin(t * 1.3) * 0.01, math.sin(t * 2.1) * 0.012, 0)
			camera.FieldOfView = C.Fov
		end

		-- the weapon: ours until the server's copy shows up in the customer's hand
		if weapon then
			local handedOff = t >= plan.inspect + C.HandOffSeconds
			local serverCopy = handedOff and customer and customer:FindFirstChild("CarriedWeapon")
			weapon.Parent = if serverCopy then nil else folder
			weapon:PivotTo(Poses.Weapon(ctx, t, hand))
		end
		if t >= plan.inspect then
			once("place", C.Sounds.Place)
		end

		-- the cash: slid across the counter, taken, counted
		local cashCF = Poses.Cash(ctx, t)
		cash.Parent = if cashCF then folder else nil
		if cashCF then
			cash:PivotTo(cashCF)
			once("slide", C.Sounds.Slide)
		end
		local n = DealScene.BillsCounted(plan, t, C.Bills)
		while counted < n and cashCF do
			counted += 1
			local bill = FirstPerson.Piece("Bill", Vector3.new(Poses.CashSize.X * 0.95, 0.02, Poses.CashSize.Z * 0.95), CASH_COLOR, Enum.Material.Fabric, folder)
			table.insert(bills, { part = bill, at = t })
			FirstPerson.Sound(C.Sounds.Flick, 0.95 + (counted % 3) * 0.05, C.Volume)
		end
		for i = #bills, 1, -1 do
			local b = bills[i]
			local u = (t - b.at) / BILL_SECONDS
			if u >= 1 or cashCF == nil then
				b.part:Destroy()
				table.remove(bills, i)
			else
				-- flicked off the top of the stack towards the right hand
				local from = cashCF * CFrame.new(0, Poses.CashSize.Y / 2 + 0.02, 0)
				local to = CFrame.new(rightCF.Position) * cashCF.Rotation * CFrame.Angles(0, 0, math.rad(-35))
				b.part.CFrame = from:Lerp(to, DealScene.Smooth(u))
				b.part.Transparency = math.max(0, u - 0.6) / 0.4
			end
		end

		-- hands: follow their targets smoothly (no teleport between two moves)
		local targetR, targetL = Poses.Hands(ctx, t, hand)
		local k = 1 - math.exp(-dt * C.HandFollow)
		rightCF = rightCF:Lerp(targetR, k)
		leftCF = leftCF:Lerp(targetL, k)
		FirstPerson.SetHand(right, rightCF, (camCF * CFrame.new(0.95, -1.7, 0.2)).Position)
		FirstPerson.SetHand(left, leftCF, (camCF * CFrame.new(-0.95, -1.7, 0.2)).Position)

		if (phase == "count" or phase == "outro") and reveal == nil then
			reveal = revealCard(info)
		end

		camera.CFrame = camCF
		if phase == "outro" then
			fade.BackgroundTransparency = 1 - DealScene.Smooth((t - plan.outro) / C.OutroSeconds)
		elseif phase == "done" then
			finish()
		end
	end
	conn = RunService.RenderStepped:Connect(function()
		xpcall(frame, function(err)
			warn("[DealCinematic] " .. tostring(err))
			task.defer(finish)
		end)
	end)
	-- whatever happens, the player gets the controls back
	task.delay(plan.total + 3, finish)
end

function DealCinematicController.IsPlaying(): boolean
	return playing
end

function DealCinematicController:Start() end

return DealCinematicController

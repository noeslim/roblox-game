--!strict
-- Client-only juice: pop, bounce, floating text, flying bills, camera shake, sparkles, sounds.
-- Every tuning value is in Effects.Settings: tweak them live in Studio to taste.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local UI = require(script.Parent.UI)
local Visual = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Visual"))

local Effects = {}

Effects.Settings = {
	BounceScale = 1.25,
	BounceSeconds = 0.35,
	FloatRiseStuds = 4,
	FloatSeconds = 1.6,
	FloatTextSize = 30,
	BillCount = 8,
	BillSeconds = 0.75,
	BillSize = 26,
	ShakeIntensity = 0.5,
	ShakeSeconds = 0.35,
	SparkleCount = 24,
	SparkleLifetime = 0.8,
	SparkleSpeed = 12,
	FlashSeconds = 0.4,
	SoundVolume = 0.6,
}

local S = Effects.Settings
local fxFolder: Instance? = nil

local function folder(): Instance
	if fxFolder and fxFolder.Parent then
		return fxFolder
	end
	local f = Instance.new("Folder")
	f.Name = "ClientFx"
	f.Parent = workspace
	fxFolder = f
	return f
end

local function anchorPart(pos: Vector3): Part
	return UI.new("Part", {
		Name = "FxAnchor",
		Size = Vector3.new(0.2, 0.2, 0.2),
		CFrame = CFrame.new(pos),
		Transparency = 1,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = folder(),
	})
end

-- Scales a GUI object up then back (uses/creates a UIScale).
function Effects.Bounce(gui: GuiObject, scale: number?)
	local s = gui:FindFirstChildOfClass("UIScale") or UI.new("UIScale", { Parent = gui })
	s.Scale = scale or S.BounceScale
	TweenService:Create(s, TweenInfo.new(S.BounceSeconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

-- Text that rises and fades above a world position.
function Effects.FloatingText(pos: Vector3, text: string, color: Color3, size: number?)
	local anchor = anchorPart(pos)
	local gui = UI.new("BillboardGui", {
		Size = UDim2.fromOffset(300, 60),
		StudsOffset = Vector3.new(0, 0, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		Adornee = anchor,
		Parent = anchor,
	})
	local label = UI.Label({
		Size = UDim2.fromScale(1, 1),
		Text = text,
		TextColor3 = color,
		TextSize = size or S.FloatTextSize,
		Font = UI.Theme.FontBlack,
		TextStrokeTransparency = 0.2,
		Parent = gui,
	})
	local scale = UI.new("UIScale", { Scale = 0.3, Parent = label })
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	TweenService:Create(gui, TweenInfo.new(S.FloatSeconds, Enum.EasingStyle.Quad), { StudsOffset = Vector3.new(0, S.FloatRiseStuds, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(S.FloatSeconds * 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, S.FloatSeconds * 0.5), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	task.delay(S.FloatSeconds + 0.1, function()
		anchor:Destroy()
	end)
end

-- Burst of particles at a position.
function Effects.Sparkles(pos: Vector3, color: Color3, count: number?)
	local anchor = anchorPart(pos)
	local emitter = UI.new("ParticleEmitter", {
		Color = ColorSequence.new(color),
		LightEmission = 1,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(S.SparkleLifetime * 0.6, S.SparkleLifetime),
		Speed = NumberRange.new(S.SparkleSpeed * 0.5, S.SparkleSpeed),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 4,
		Rate = 0,
		Parent = anchor,
	})
	emitter:Emit(count or S.SparkleCount)
	task.delay(S.SparkleLifetime + 0.2, function()
		anchor:Destroy()
	end)
end

function Effects.Sound(soundId: string?, pos: Vector3?, pitch: number?)
	if soundId == nil or soundId == "" then
		return
	end
	local parent: Instance = if pos then anchorPart(pos) else folder()
	local sound = UI.new("Sound", {
		SoundId = soundId,
		Volume = S.SoundVolume,
		PlaybackSpeed = pitch or 1,
		RollOffMaxDistance = 80,
		Parent = parent,
	})
	sound:Play()
	sound.Ended:Connect(function()
		if parent ~= fxFolder then
			parent:Destroy()
		else
			sound:Destroy()
		end
	end)
end

function Effects.CameraShake(intensity: number?, seconds: number?)
	local strength = intensity or S.ShakeIntensity
	local duration = seconds or S.ShakeSeconds
	local started = os.clock()
	local name = "BMShake" .. tostring(started)
	RunService:BindToRenderStep(name, Enum.RenderPriority.Camera.Value + 1, function()
		local t = os.clock() - started
		if t >= duration then
			RunService:UnbindFromRenderStep(name)
			return
		end
		local k = strength * (1 - t / duration)
		local camera = workspace.CurrentCamera
		camera.CFrame *= CFrame.new(
			(math.random() - 0.5) * k,
			(math.random() - 0.5) * k,
			0
		) * CFrame.Angles(0, 0, (math.random() - 0.5) * k * 0.05)
	end)
end

local function screenGui(): ScreenGui
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	local existing = pg:FindFirstChild("FxScreen")
	if existing then
		return existing :: ScreenGui
	end
	local gui = UI.Screen("FxScreen", 40)
	gui.IgnoreGuiInset = true
	return gui
end

function Effects.Flash(color: Color3, seconds: number?)
	local frame = UI.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color,
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		Parent = screenGui(),
	})
	local tween = TweenService:Create(frame, TweenInfo.new(seconds or S.FlashSeconds), { BackgroundTransparency = 1 })
	tween:Play()
	tween.Completed:Connect(function()
		frame:Destroy()
	end)
end

-- Bills flying from a world position to the money counter (a GuiObject named "MoneyLabel").
function Effects.MoneyBurst(fromWorld: Vector3, count: number?)
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	local hud = pg:FindFirstChild("MoneyHud")
	local target = hud and hud:FindFirstChild("MoneyLabel", true) :: GuiObject?
	local camera = workspace.CurrentCamera
	local screenPos, onScreen = camera:WorldToViewportPoint(fromWorld)
	local gui = screenGui()
	local start = if onScreen then Vector2.new(screenPos.X, screenPos.Y) else camera.ViewportSize / 2
	local finish = if target
		then target.AbsolutePosition + target.AbsoluteSize / 2
		else Vector2.new(camera.ViewportSize.X - 80, 30)

	for i = 1, count or S.BillCount do
		task.delay((i - 1) * 0.05, function()
			local bill = UI.Label({
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(start.X + math.random(-30, 30), start.Y + math.random(-20, 20)),
				Size = UDim2.fromOffset(S.BillSize * 1.6, S.BillSize),
				BackgroundTransparency = 0,
				BackgroundColor3 = Color3.fromHex("#2E8B57"),
				Text = "$",
				TextColor3 = Color3.fromHex("#C8FFD8"),
				TextSize = S.BillSize * 0.8,
				Font = UI.Theme.FontBlack,
				Rotation = math.random(-25, 25),
				Parent = gui,
			})
			UI.Corner(bill, 3)
			local tween = TweenService:Create(bill, TweenInfo.new(S.BillSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.fromOffset(finish.X, finish.Y),
				Rotation = math.random(-90, 90),
				BackgroundTransparency = 0.4,
			})
			tween:Play()
			tween.Completed:Connect(function()
				bill:Destroy()
				if target then
					Effects.Bounce(target, 1.12)
				end
			end)
		end)
	end
end

Effects.Sounds = Visual.Sounds

return Effects

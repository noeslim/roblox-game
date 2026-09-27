--!strict
-- Music and ambience by zone (roadmap 2.4). Where you are (district, inside a trap house) and what
-- happens (your raid, day or night) pick the tracks (Logic/Soundscape); tracks crossfade, the
-- street is muffled inside the basements, the music ducks during the first-person scenes.
-- M (or the note button) mutes the music. Ids and volumes: Config/Soundscape.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local City = require(Shared.Config.City)
local World = require(Shared.Config.World)
local C = require(Shared.Config.Soundscape)
local Soundscape = require(Shared.Logic.Soundscape)
local UI = require(script.Parent.Parent.UI)
local CraftCinematicController = require(script.Parent.CraftCinematicController)
local DealCinematicController = require(script.Parent.DealCinematicController)

local SoundscapeController = {}

local player = Players.LocalPlayer
local CHECK_SECONDS = 0.5

type Channel = { group: SoundGroup, id: string, sound: Sound?, volume: number }

local function group(name: string, volume: number): SoundGroup
	local g = SoundService:FindFirstChild(name)
	if g == nil or not g:IsA("SoundGroup") then
		local new = Instance.new("SoundGroup")
		new.Name = name
		new.Parent = SoundService
		g = new
	end
	local sg = g :: SoundGroup
	sg.Volume = volume
	return sg
end

-- Fades the old track out and the new one in (an empty id = silence).
local function switch(channel: Channel, id: string)
	if channel.id == id then
		return
	end
	channel.id = id
	local old = channel.sound
	channel.sound = nil
	local fade = TweenInfo.new(C.FadeSeconds, Enum.EasingStyle.Sine)
	if old then
		local tween = TweenService:Create(old, fade, { Volume = 0 })
		tween:Play()
		tween.Completed:Connect(function()
			old:Destroy()
		end)
	end
	if id ~= "" then
		local s = Instance.new("Sound")
		s.SoundId = id
		s.Looped = true
		s.Volume = 0
		s.SoundGroup = channel.group
		s.Parent = channel.group
		s:Play()
		TweenService:Create(s, fade, { Volume = channel.volume }):Play()
		channel.sound = s
	end
end

-- Inside any trap house basement (plots are in workspace.Hideouts).
local function inHideout(pos: Vector3): boolean
	local hideouts = workspace:FindFirstChild("Hideouts")
	if hideouts == nil then
		return false
	end
	for _, plot in hideouts:GetChildren() do
		local floor = plot:FindFirstChild("Floor", true)
		local sx, sz, h = plot:GetAttribute("SizeX"), plot:GetAttribute("SizeZ"), plot:GetAttribute("MaxHeight")
		if floor and floor:IsA("BasePart") and type(sx) == "number" and type(sz) == "number" and type(h) == "number" then
			local p = (floor.CFrame * CFrame.new(0, floor.Size.Y / 2, 0)):PointToObjectSpace(pos)
			if Soundscape.InBasement(p.X, p.Y, p.Z, sx, sz, h) then
				return true
			end
		end
	end
	return false
end

function SoundscapeController:Start()
	local musicGroup = group("Music", C.MusicVolume)
	local ambienceGroup = group("Ambience", C.AmbienceVolume)
	local muffle = Instance.new("EqualizerSoundEffect")
	muffle.HighGain = C.Indoor.HighGain
	muffle.MidGain = C.Indoor.MidGain
	muffle.LowGain = C.Indoor.LowGain
	muffle.Enabled = false
	muffle.Parent = ambienceGroup

	local music: Channel = { group = musicGroup, id = "", sound = nil, volume = 1 }
	local ambience: Channel = { group = ambienceGroup, id = "", sound = nil, volume = 1 }
	local muted = false
	local ducked = false

	local function applyMusicVolume()
		local target = if muted then 0 elseif ducked then C.MusicVolume * C.SceneDuck else C.MusicVolume
		TweenService:Create(musicGroup, TweenInfo.new(0.6), { Volume = target }):Play()
	end

	-- the note button (bottom right) and the key
	local gui = UI.Screen("MusicToggle", 5)
	local button = UI.Button({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -12),
		Size = UDim2.fromOffset(40, 40),
		Text = "♪",
		TextSize = 20,
		BackgroundColor3 = UI.Theme.PanelLight,
		Parent = gui,
	})
	local function toggle()
		muted = not muted
		button.Text = if muted then "×" else "♪"
		button.TextColor3 = if muted then UI.Theme.SubText else UI.Theme.Text
		applyMusicVolume()
	end
	button.Activated:Connect(toggle)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == (Enum.KeyCode :: any)[C.ToggleKey] then
			toggle()
		end
	end)

	task.spawn(function()
		while true do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				local pos = root.Position
				local night = ReplicatedStorage:GetAttribute("Phase") == "Night"
				local pick = Soundscape.Pick({
					district = Soundscape.DistrictAt(City, pos.X, pos.Z),
					inHideout = inHideout(pos),
					raid = player:GetAttribute("RaidPhase") ~= nil,
					isNight = night,
				})
				switch(music, Soundscape.TrackId(C.Music, pick.music, night))
				-- the zone's ambience; without one, the street (heard through the walls in a basement)
				local ambienceId = Soundscape.TrackId(C.Ambience, pick.ambience, night)
				local throughWalls = false
				if ambienceId == "" then
					ambienceId = Soundscape.TrackId(C.Ambience, Soundscape.DistrictAt(City, pos.X, pos.Z), night)
					throughWalls = pick.muffled
				end
				if ambienceId == "" then
					ambienceId = World.Sounds.CityLoop
					throughWalls = pick.muffled
				end
				switch(ambience, ambienceId)
				muffle.Enabled = throughWalls
			end
			local scene = CraftCinematicController.IsPlaying() or DealCinematicController.IsPlaying()
			if scene ~= ducked then
				ducked = scene
				applyMusicVolume()
			end
			task.wait(CHECK_SECONDS)
		end
	end)
end

return SoundscapeController

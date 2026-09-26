--!strict
-- On-screen markers of the points of interest (Config/City.Poi.Markers): name + distance, always on
-- top, so the city is easy to find your way in. Night-only places show up at night.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local City = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("City"))
local UI = require(script.Parent.Parent.UI)

local PoiController = {}

local STUDS_TO_METERS = 0.28
local HIDE_CLOSER_THAN = 30 -- studs: the place is right there

type Marker = { gui: BillboardGui, label: TextLabel, part: BasePart, name: string, nightOnly: boolean }
local markers: { Marker } = {}

-- A local invisible anchor at the position published by PoiService (attribute Poi_<name>).
local function anchor(name: string, position: Vector3): BasePart
	local part = Instance.new("Part")
	part.Name = "PoiAnchor_" .. name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.one
	part.Position = position
	part.Parent = workspace.CurrentCamera -- client only, never streamed out
	return part
end

local function build(part: BasePart, info: { label: string, color: string, nightOnly: boolean? })
	local gui = Instance.new("BillboardGui")
	gui.Name = "PoiMarker"
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Size = UDim2.fromOffset(140, 36)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 14, 0)
	gui.MaxDistance = City.Poi.MarkerMaxDistance
	gui.Adornee = part
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local label = UI.Label({
		Size = UDim2.fromScale(1, 1),
		Text = info.label,
		Font = UI.Theme.FontBlack,
		TextSize = 13,
		TextColor3 = Color3.fromHex(info.color),
		TextStrokeTransparency = 0.4,
		Parent = gui,
	})
	table.insert(markers, { gui = gui, label = label, part = part, name = info.label, nightOnly = info.nightOnly == true })
end

function PoiController:Start()
	task.spawn(function()
		for name, info in City.Poi.Markers do
			local key = "Poi_" .. name
			local position = ReplicatedStorage:GetAttribute(key)
			local waited = 0
			while typeof(position) ~= "Vector3" and waited < 15 do -- the server publishes them at start
				task.wait(0.5)
				waited += 0.5
				position = ReplicatedStorage:GetAttribute(key)
			end
			if typeof(position) == "Vector3" then
				build(anchor(name, position), info)
			end
		end
		while true do
			local root = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			local night = ReplicatedStorage:GetAttribute("Phase") == "Night"
			for _, m in markers do
				local distance = if root and root:IsA("BasePart") then (m.part.Position - root.Position).Magnitude else 0
				m.gui.Enabled = (night or not m.nightOnly) and distance > HIDE_CLOSER_THAN
				m.label.Text = ("%s\n%dm"):format(m.name, math.floor(distance * STUDS_TO_METERS + 0.5))
			end
			task.wait(0.5)
		end
	end)
end

return PoiController

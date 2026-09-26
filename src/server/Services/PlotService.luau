--!strict
-- Gives each player a free plot when their data is loaded, frees it when they leave,
-- writes their name on the plot sign and brings their character to it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlotUtil = require(Shared.Visual.PlotUtil)
local DataService = require(script.Parent.DataService)
local CityService = require(script.Parent.CityService)
local ServerNet = require(script.Parent.Parent.Lib.ServerNet)

local PlotService = {}

local plotsByPlayer: { [Player]: Instance } = {}
local assignedCallbacks: { (Player, Instance) -> () } = {}
local releasedCallbacks: { (Player, Instance) -> () } = {}

local function setSignText(plot: Instance, text: string)
	local sign = plot:FindFirstChild("Sign")
	if sign == nil then
		return
	end
	for _, d in sign:GetDescendants() do
		if d:IsA("TextLabel") and d.Name == "SignText" then
			d.Text = text
		end
	end
end

local function sortedPlots(): { Instance }
	local hideouts = CityService.EnsureBuilt()
	local plots = {}
	for _, p in hideouts:GetChildren() do
		if p:GetAttribute("Index") ~= nil then
			table.insert(plots, p)
		end
	end
	table.sort(plots, function(a, b)
		return (a:GetAttribute("Index") :: number) < (b:GetAttribute("Index") :: number)
	end)
	return plots
end

-- Where a character appears: in the basement, behind the starter counter, facing the stairs side.
local SPAWN_LOCAL = Vector3.new(0, 3, 0)

function PlotService.GetSpawnCFrame(plot: Instance): CFrame
	local origin = PlotUtil.GetOrigin(plot)
	local _, sizeZ = PlotUtil.GetSize(plot)
	local pos = origin * CFrame.new(SPAWN_LOCAL)
	return CFrame.lookAt(pos.Position, (origin * CFrame.new(0, 3, sizeZ / 2)).Position)
end

local function bringCharacter(player: Player, plot: Instance)
	if player:GetAttribute("WarTeam") ~= nil then
		return -- in a War Zone round: WarZoneService respawns them in their bunker
	end
	local character = player.Character
	if character and character.PrimaryPart then
		character:PivotTo(PlotService.GetSpawnCFrame(plot))
	end
end

local function assign(player: Player)
	if plotsByPlayer[player] or player.Parent ~= Players then
		return
	end
	for _, plot in sortedPlots() do
		if plot:GetAttribute("OwnerUserId") == 0 then
			plot:SetAttribute("OwnerUserId", player.UserId)
			plot:SetAttribute("OwnerName", player.DisplayName)
			plotsByPlayer[player] = plot
			player:SetAttribute("PlotIndex", plot:GetAttribute("Index"))
			setSignText(plot, player.DisplayName .. "'s Shop")
			for _, callback in assignedCallbacks do
				task.spawn(callback, player, plot)
			end
			bringCharacter(player, plot)
			return
		end
	end
	ServerNet.Notify(player, "All trap houses are taken on this server. You can still fight in the War Zone, or join another server.", "error")
end

local function release(player: Player)
	local plot: Instance? = plotsByPlayer[player]
	if not plot then
		return
	end
	plotsByPlayer[player] = nil
	for _, callback in releasedCallbacks do
		xpcall(callback, function(err)
			warn("[PlotService] release callback failed: " .. tostring(err))
		end, player, plot)
	end
	plot:SetAttribute("OwnerUserId", 0)
	plot:SetAttribute("OwnerName", nil)
	setSignText(plot, "FOR RENT")
end

function PlotService:Start()
	sortedPlots()
	DataService.OnPlayerLoaded(assign)
	Players.PlayerRemoving:Connect(release)

	local function watchCharacter(player: Player)
		player.CharacterAdded:Connect(function(character)
			local plot = plotsByPlayer[player]
			if plot then
				character:WaitForChild("HumanoidRootPart", 5)
				task.wait() -- let the default spawn finish first
				bringCharacter(player, plot)
			end
		end)
	end
	Players.PlayerAdded:Connect(watchCharacter)
	for _, player in Players:GetPlayers() do
		watchCharacter(player)
	end
end

function PlotService.GetPlot(player: Player): Instance?
	return plotsByPlayer[player]
end

function PlotService.GetOwner(plot: Instance): Player?
	for player, p in plotsByPlayer do
		if p == plot then
			return player
		end
	end
	return nil
end

-- callback(player, plot) runs when a player receives a plot (after their data is loaded).
function PlotService.OnPlotAssigned(callback: (Player, Instance) -> ())
	table.insert(assignedCallbacks, callback)
	for player, plot in plotsByPlayer do
		task.spawn(callback, player, plot)
	end
end

-- callback(player, plot) runs when the owner leaves, before the plot is marked free.
function PlotService.OnPlotReleased(callback: (Player, Instance) -> ())
	table.insert(releasedCallbacks, callback)
end

return PlotService

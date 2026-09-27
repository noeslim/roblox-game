--!strict
-- Runs missions (Logic/Mission, Config/Missions): one active mission per player. Events come from
-- GoalsService.Record (sales, crafts, purchases...), angry customers and the day/night switch;
-- places ("poi:Supplier", "home", "district:Docks") are checked here every half second.
-- Remotes: RequestStartMission(id), RequestAbandonMission(); event MissionSync({ active, cooldowns }).
-- Other services start missions with MissionService.Begin(player, def) (recruits, R.2).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local City = require(Shared.Config.City)
local Economy = require(Shared.Config.Economy)
local Messages = require(Shared.Config.Messages)
local Missions = require(Shared.Config.Missions)
local Mission = require(Shared.Logic.Mission)
local Soundscape = require(Shared.Logic.Soundscape)
local DataService = require(script.Parent.DataService)
local GoalsService = require(script.Parent.GoalsService)
local CustomerService = require(script.Parent.CustomerService)
local PlotService = require(script.Parent.PlotService)
local PoiService = require(script.Parent.PoiService)
local ServerNet = require(script.Parent.Parent.Lib.ServerNet)

local MissionService = {}

local S = Missions.Settings
local TICK = 0.5

type Active = { def: Mission.Def, state: Mission.State, board: boolean }

local active: { [Player]: Active } = {}
local cooldowns: { [Player]: { [string]: number } } = {} -- job id -> os.clock() when it is offered again
local finishedCallbacks: { (Player, Mission.Def, boolean) -> () } = {}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- Where a target is (for the marker on the client), nil for a district.
local function targetPosition(player: Player, target: string): Vector3?
	local poi = string.match(target, "^poi:(.+)$")
	if poi then
		return PoiService.Position(poi)
	end
	if target == "home" then
		local plot = PlotService.GetPlot(player)
		local waypoints = plot and plot:FindFirstChild("Waypoints")
		local door = waypoints and waypoints:FindFirstChild("Door")
		if door and door:IsA("BasePart") then
			return door.Position
		end
	end
	return nil
end

local function isInside(player: Player, target: string): boolean
	local root = rootOf(player)
	if root == nil then
		return false
	end
	local pos = root.Position
	local district = string.match(target, "^district:(.+)$")
	if district then
		return Soundscape.DistrictAt(City, pos.X, pos.Z) == district
	end
	if target == "home" then
		local plot = PlotService.GetPlot(player)
		local floor = plot and plot:FindFirstChild("Floor", true)
		local sx, sz, h = plot and plot:GetAttribute("SizeX"), plot and plot:GetAttribute("SizeZ"), plot and plot:GetAttribute("MaxHeight")
		if floor and floor:IsA("BasePart") and type(sx) == "number" and type(sz) == "number" and type(h) == "number" then
			local p = (floor.CFrame * CFrame.new(0, floor.Size.Y / 2, 0)):PointToObjectSpace(pos)
			if Soundscape.InBasement(p.X, p.Y, p.Z, sx, sz, h) then
				return true
			end
		end
	end
	local at = targetPosition(player, target)
	return at ~= nil and Vector3.new(pos.X - at.X, 0, pos.Z - at.Z).Magnitude <= S.GotoRadius
end

local function cooldownsOf(player: Player): { [string]: number }
	local list = cooldowns[player]
	if list == nil then
		list = {}
		cooldowns[player] = list
	end
	return list
end

local function sync(player: Player)
	local a = active[player]
	local view: any = nil
	if a then
		view = Mission.Describe(a.state, a.def, os.clock())
		view.targetPosition = if view.target then targetPosition(player, view.target) else nil
	end
	local left = {}
	for id, readyAt in cooldownsOf(player) do
		local seconds = math.ceil(readyAt - os.clock())
		if seconds > 0 then
			left[id] = seconds
		end
	end
	ServerNet.FireClient("MissionSync", player, { active = view, cooldowns = left })
end

local function finish(player: Player, a: Active)
	local success = a.state.status == "done"
	if success then
		local ledger = DataService.GetLedger(player)
		if ledger and a.def.reward.money > 0 then
			ledger:Deposit(a.def.reward.money, "mission:" .. a.def.id)
		end
		DataService.AddXp(player, a.def.reward.xp)
		DataService.Sync(player)
		ServerNet.Notify(player, Messages.Missions.Done:format(a.def.title, a.def.reward.money), "success")
	else
		local why = (Messages.Missions.Reasons :: any)[a.state.reason or ""] or Messages.Missions.Reasons.default
		ServerNet.Notify(player, Messages.Missions.Failed:format(a.def.title, why), "error")
	end
	if a.board then
		cooldownsOf(player)[a.def.id] = os.clock() + S.CooldownSeconds
	end
	sync(player) -- shows the result for a moment
	for _, callback in finishedCallbacks do
		task.spawn(callback, player, a.def, success)
	end
	task.delay(S.ResultSeconds, function()
		if active[player] == a then
			active[player] = nil
			sync(player)
		end
	end)
end

local function changed(player: Player, a: Active)
	if a.state.status ~= "active" then
		finish(player, a)
	else
		sync(player)
	end
end

-- Starts a mission for a player (fails if one is already running). board: a street job (cooldown).
function MissionService.Begin(player: Player, def: Mission.Def, board: boolean?): (boolean, string?)
	local current = active[player]
	if current and current.state.status == "active" then
		return false, "MissionRunning"
	end
	active[player] = { def = def, state = Mission.Start(def, os.clock()), board = board == true }
	ServerNet.Notify(player, Messages.Missions.Started:format(def.title), "info")
	sync(player)
	return true, nil
end

-- An event for the player's mission (the services use GoalsService.Record, this is for the rest).
function MissionService.Record(player: Player, event: string, amount: number?, info: any?)
	local a = active[player]
	if a and Mission.Record(a.state, a.def, event, amount or 1, info, Economy.RarityOrder) then
		changed(player, a)
	end
end

-- Called with (player, def, success) when a mission ends.
function MissionService.OnFinished(callback: (Player, Mission.Def, boolean) -> ())
	table.insert(finishedCallbacks, callback)
end

local function startJob(player: Player, id: any): (boolean, any)
	if type(id) ~= "string" then
		return false, "InvalidInput"
	end
	local def = Missions.ById[id]
	if def == nil then
		return false, "UnknownMission"
	end
	if not DataService.IsLoaded(player) then
		return false, "NotLoaded"
	end
	local readyAt = cooldownsOf(player)[id]
	if readyAt and readyAt > os.clock() then
		return false, "MissionCooldown"
	end
	local ok, err = MissionService.Begin(player, def, true)
	if not ok then
		return false, err
	end
	return true, nil
end

local function abandon(player: Player): (boolean, any)
	local a = active[player]
	if a == nil or a.state.status ~= "active" then
		return false, "NoMission"
	end
	a.state.status = "failed"
	a.state.reason = "abandoned"
	finish(player, a)
	return true, nil
end

function MissionService:Start()
	ServerNet.Handle("RequestStartMission", startJob)
	ServerNet.Handle("RequestAbandonMission", abandon)
	ServerNet.Handle("RequestMissions", function(player: Player)
		sync(player)
		return true, nil
	end)
	GoalsService.OnRecord(function(player, event, amount, info)
		MissionService.Record(player, event, amount, info)
	end)
	CustomerService.OnComplaint(function(owner)
		MissionService.Record(owner, "customerLost", 1)
	end)
	ReplicatedStorage:GetAttributeChangedSignal("Phase"):Connect(function()
		local event = if ReplicatedStorage:GetAttribute("Phase") == "Night" then "nightStart" else "dayStart"
		for player in active do
			MissionService.Record(player, event, 1)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		active[player] = nil
		cooldowns[player] = nil
	end)
	DataService.OnPlayerLoaded(sync)

	-- Studio only: game.Players.NAME:SetAttribute("DebugMission", "night_shift")
	if RunService:IsStudio() then
		local function watch(player: Player)
			player:GetAttributeChangedSignal("DebugMission"):Connect(function()
				local id = player:GetAttribute("DebugMission")
				if type(id) == "string" and Missions.ById[id] then
					player:SetAttribute("DebugMission", nil)
					active[player] = nil
					MissionService.Begin(player, Missions.ById[id], false)
				end
			end)
		end
		Players.PlayerAdded:Connect(watch)
		for _, p in Players:GetPlayers() do
			watch(p)
		end
	end

	task.spawn(function()
		local lastSync = 0
		while true do
			task.wait(TICK)
			local now = os.clock()
			local resync = now - lastSync >= 1 -- the timer on the tracker
			if resync then
				lastSync = now
			end
			for player, a in active do
				if a.state.status == "active" then
					local step = Mission.Current(a.state, a.def)
					local inside = step ~= nil and step.target ~= nil and isInside(player, step.target)
					if Mission.Update(a.state, a.def, now, TICK, inside) then
						changed(player, a)
					elseif resync and a.def.timeLimit then
						sync(player)
					end
				end
			end
		end
	end)
end

return MissionService

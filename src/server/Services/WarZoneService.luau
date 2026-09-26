--!strict
-- War Zone rounds (Config/War): walking into the fenced zone puts you in the smaller team (Red / Blue),
-- standing on a control point captures it (Logic/CapturePoint), owned points score (Logic/WarRound).
-- The round state is published as ReplicatedStorage attributes for the HUD (WarZoneController):
-- War_Phase, War_Red, War_Blue, War_TimeLeft, War_<label>_Owner, War_<label>_Progress.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local City = require(Shared.Config.City)
local War = require(Shared.Config.War)
local Messages = require(Shared.Config.Messages)
local CityLayout = require(Shared.Logic.CityLayout)
local CapturePoint = require(Shared.Logic.CapturePoint)
local WarRound = require(Shared.Logic.WarRound)
local DataService = require(script.Parent.DataService)
local GoalsService = require(script.Parent.GoalsService)
local ServerNet = require(script.Parent.Parent.Lib.ServerNet)

local WarZoneService = {}

type Side = CapturePoint.Team
type Point = { label: string, position: Vector3, state: CapturePoint.State, ring: Part }
type Member = { team: Side, outsideSince: number? }

local STEP = 0.25

local zone: CityLayout.WarZone? = nil
local origin = Vector3.new(City.Origin.x, City.Origin.y, City.Origin.z)
local groundY = City.Origin.y + City.Grid.SidewalkHeight
local points: { Point } = {}
local members: { [Player]: Member } = {}
local round = WarRound.new()
local phase = "Playing"
local intermissionLeft = 0

local function teamColor(team: Side?): Color3
	if team == nil then
		return Color3.fromHex("#8A8A90")
	end
	return Color3.fromHex(War.Teams[team].color)
end

local function publish(name: string, value: any)
	if ReplicatedStorage:GetAttribute(name) ~= value then
		ReplicatedStorage:SetAttribute(name, value)
	end
end

local function notifyMembers(text: string, kind: string?)
	for player in members do
		ServerNet.Notify(player, text, kind)
	end
end

local function spawnCFrame(team: Side): CFrame?
	local z = zone
	if z == nil then
		return nil
	end
	local s = if team == "Red" then z.red else z.blue
	local center = origin + Vector3.new(0, 0, 0)
	return CFrame.new(center.X + s.x, groundY + 3, center.Z + s.z)
end

local function join(player: Player)
	local red, blue = 0, 0
	for _, m in members do
		if m.team == "Red" then
			red += 1
		else
			blue += 1
		end
	end
	local team: Side = WarRound.PickTeam(red, blue)
	members[player] = { team = team }
	(player :: any).Team = Teams:FindFirstChild(team)
	player.Neutral = false
	player:SetAttribute("WarTeam", team)
	ServerNet.Notify(player, Messages.War.Joined:format(string.upper(team)), "info")
end

local function leave(player: Player)
	members[player] = nil
	if player.Parent then
		(player :: any).Team = nil
		player.Neutral = true
		player:SetAttribute("WarTeam", nil)
		ServerNet.Notify(player, Messages.War.Left, "info")
	end
end

local function inside(pos: Vector3): boolean
	local z = zone
	return z ~= nil and CityLayout.Contains(z.rect, pos.X - origin.X, pos.Z - origin.Z)
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function endRound()
	local winner = round.winner
	notifyMembers(if winner then Messages.War.Won:format(string.upper(winner)) else Messages.War.Draw, "success")
	local counts = { Red = 0, Blue = 0 }
	for _, m in members do
		counts[m.team] += 1
	end
	local rewarded = counts.Red >= War.MinPlayersPerTeam and counts.Blue >= War.MinPlayersPerTeam
	if not rewarded then
		notifyMembers(Messages.War.NoRewards, "info")
	end
	for player, m in (if rewarded then members else {}) :: { [Player]: Member } do
		local ledger = DataService.GetLedger(player)
		if ledger then
			local won = winner == m.team
			ledger:Deposit(if won then War.WinReward else War.LossReward, "war:" .. (if won then "win" else "play"))
			DataService.AddXp(player, if won then War.XpWin else War.XpLoss)
			DataService.Sync(player)
			if won then
				GoalsService.Record(player, "warWin", 1)
			end
		end
	end
	phase = "Intermission"
	intermissionLeft = War.IntermissionSeconds
end

local function newRound()
	round = WarRound.new()
	for _, p in points do
		p.state = CapturePoint.new()
		p.ring.Color = teamColor(nil)
	end
	phase = "Playing"
	notifyMembers(Messages.War.RoundStart, "info")
end

local function tick(dt: number)
	local now = os.clock()
	-- who is in the zone
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		local m = members[player]
		if root then
			if inside(root.Position) then
				if m == nil then
					join(player)
				else
					m.outsideSince = nil
				end
			elseif m then
				m.outsideSince = m.outsideSince or now
				if now - (m.outsideSince :: number) > War.LeaveAfterSeconds then
					leave(player)
				end
			end
		end
	end

	if phase == "Intermission" then
		intermissionLeft -= dt
		if intermissionLeft <= 0 then
			newRound()
		end
	else
		local radius = City.WarZone.ControlPointRadius
		local owners: { Side? } = {}
		for i, p in points do
			local red, blue = 0, 0
			for player, m in members do
				local root = rootOf(player)
				if root then
					local d = (root.Position - p.position) * Vector3.new(1, 0, 1)
					if d.Magnitude <= radius then
						if m.team == "Red" then
							red += 1
						else
							blue += 1
						end
					end
				end
			end
			local event = CapturePoint.Step(p.state, red, blue, dt, War)
			if event == "captured" then
				notifyMembers(Messages.War.Captured:format(string.upper(tostring(p.state.owner)), p.label), "info")
			elseif event == "neutralized" then
				notifyMembers(Messages.War.Neutralized:format(p.label), "info")
			end
			if event then
				p.ring.Color = teamColor(p.state.owner)
			end
			owners[i] = p.state.owner
		end
		WarRound.Tick(round, owners, dt, War)
		if round.over then
			endRound()
		end
	end

	publish("War_Phase", phase)
	publish("War_Red", math.floor(round.scores.Red))
	publish("War_Blue", math.floor(round.scores.Blue))
	publish("War_Goal", War.ScoreToWin)
	publish("War_TimeLeft", math.floor(if phase == "Intermission" then intermissionLeft else WarRound.TimeLeft(round, War)))
	for _, p in points do
		publish("War_" .. p.label .. "_Owner", p.state.owner or "")
		publish("War_" .. p.label .. "_Progress", math.floor(p.state.progress * 20 + 0.5) / 20)
	end
end

local function setupTeams()
	for name, t in War.Teams do
		local team = Teams:FindFirstChild(name) :: Team?
		if team == nil then
			local created = Instance.new("Team")
			created.Name = name
			created.Parent = Teams
			team = created
		end
		local tm = team :: Team
		tm.TeamColor = BrickColor.new(Color3.fromHex(t.color))
		tm.AutoAssignable = false
	end
end

local function setupPoints()
	local z = zone :: CityLayout.WarZone
	local folder = Instance.new("Folder")
	folder.Name = "WarZoneRuntime"
	local labels = {}
	for _, cp in z.points do
		local position = Vector3.new(origin.X + cp.x, groundY, origin.Z + cp.z)
		local ring = Instance.new("Part")
		ring.Name = "Ring_" .. cp.label
		ring.Shape = Enum.PartType.Cylinder
		ring.Size = Vector3.new(War.RingHeight, City.WarZone.ControlPointRadius * 2, City.WarZone.ControlPointRadius * 2)
		ring.CFrame = CFrame.new(position + Vector3.new(0, War.RingHeight / 2 + 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90))
		ring.Anchored = true
		ring.CanCollide = false
		ring.CanQuery = false
		ring.CanTouch = false
		ring.CastShadow = false
		ring.Material = Enum.Material.Neon
		ring.Transparency = 0.6
		ring.Color = teamColor(nil)
		ring.Parent = folder
		table.insert(points, { label = cp.label, position = position, state = CapturePoint.new(), ring = ring })
		table.insert(labels, cp.label)
	end
	folder.Parent = workspace
	publish("War_Points", table.concat(labels, ","))
end

function WarZoneService:Start()
	zone = CityLayout.Build(City).warZone
	if zone == nil then
		warn("[WarZoneService] the city has no war zone")
		return
	end
	setupTeams()
	setupPoints()
	Players.PlayerRemoving:Connect(function(player)
		members[player] = nil
	end)
	-- dying in a round: back to your team's bunker (PlotService leaves War players alone)
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			local m = members[player]
			if m then
				character:WaitForChild("HumanoidRootPart", 5)
				task.wait()
				local cf = spawnCFrame(m.team)
				if cf and members[player] then
					character:PivotTo(cf)
				end
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(STEP)
			local now = os.clock()
			tick(math.min(1, now - last))
			last = now
		end
	end)
end

return WarZoneService

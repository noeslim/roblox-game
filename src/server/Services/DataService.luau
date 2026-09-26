--!strict
-- Loads / saves each player's profile with ProfileStore (session-locked, auto-saved).
-- Money goes ONLY through the player's Ledger (DataService.GetLedger); it writes back to the profile.
-- Other services: `local DataService = require(script.Parent.DataService)`.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Parts = require(Shared.Config.Parts)
local DataConfig = require(Shared.Config.Data)
local Ledger = require(Shared.Logic.Ledger)
local ProfileSchema = require(Shared.Logic.ProfileSchema)
local ProfileStore = require(script.Parent.Parent.Packages.ProfileStore) :: any

local SCHEMA_CONFIG: ProfileSchema.SchemaConfig = {
	startingMoney = Economy.StartingMoney,
	maxMoney = Economy.MaxMoney,
	starterParts = Economy.Profile.StarterParts,
	maxPartStack = Economy.Profile.MaxPartStack,
	maxWeapons = Economy.Profile.MaxWeapons,
	maxLevel = Economy.Profile.MaxLevel,
	maxWeaponNameLength = Economy.Profile.MaxWeaponNameLength,
	parts = Parts,
}

local KICK_LOAD_FAILED = "Impossible de charger tes données. Reviens dans une minute."
local KICK_SESSION_ENDED = "Ta session a été ouverte sur un autre serveur."
local KICK_FUTURE_VERSION = "Ce serveur est trop ancien pour ta sauvegarde. Rejoins un autre serveur."

local DataService = {}

-- Fires (player) once the profile is loaded and the Ledger is ready.
local loadedEvent = Instance.new("BindableEvent")
DataService.PlayerLoaded = loadedEvent.Event

type Session = { profile: any, ledger: Ledger.Ledger }
local sessions: { [Player]: Session } = {}

local store = ProfileStore.New(DataConfig.StoreName, ProfileSchema.Template(SCHEMA_CONFIG))
if RunService:IsStudio() and DataConfig.UseMockInStudio then
	store = store.Mock
end

local function publish(player: Player, data: ProfileSchema.ProfileData)
	player:SetAttribute("Money", data.Money)
	player:SetAttribute("Level", data.Level)
end

-- Studio only: from the command bar (Server view), `game.Players.NAME:SetAttribute("DebugGrant", 100)`.
local function watchDebugGrant(player: Player, ledger: Ledger.Ledger)
	if not RunService:IsStudio() then
		return
	end
	player:GetAttributeChangedSignal("DebugGrant"):Connect(function()
		local amount = player:GetAttribute("DebugGrant")
		if type(amount) == "number" and amount > 0 then
			ledger:Deposit(math.floor(amount), "debug")
			player:SetAttribute("DebugGrant", nil)
		end
	end)
end

local function onPlayerAdded(player: Player)
	local profile = store:StartSessionAsync(DataConfig.KeyPrefix .. player.UserId, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if profile == nil then
		if player.Parent == Players then
			player:Kick(KICK_LOAD_FAILED)
		end
		return
	end

	profile:AddUserId(player.UserId) -- GDPR
	-- no profile:Reconcile(): ProfileSchema.Sanitize fills missing fields itself, after migrations

	local ok, err = ProfileSchema.Prepare(profile.Data, SCHEMA_CONFIG)
	if not ok then
		warn(("[DataService] cannot load %s: %s"):format(player.Name, tostring(err)))
		-- FutureVersion: Prepare touched nothing, so ending the session saves the data unchanged
		profile:EndSession()
		player:Kick(if err == "FutureVersion" then KICK_FUTURE_VERSION else KICK_LOAD_FAILED)
		return
	end

	profile.OnSessionEnd:Connect(function()
		sessions[player] = nil
		player:Kick(KICK_SESSION_ENDED)
	end)

	if player.Parent ~= Players then -- left while loading
		profile:EndSession()
		return
	end

	local data = profile.Data :: ProfileSchema.ProfileData
	local ledger = Ledger.new(data.Money, Economy.MaxMoney)
	ledger:SetChangedCallback(function(balance)
		data.Money = balance
		player:SetAttribute("Money", balance)
	end)

	sessions[player] = { profile = profile, ledger = ledger }
	publish(player, data)
	watchDebugGrant(player, ledger)
	print(("[DataService] loaded %s ($%d, v%d)"):format(player.Name, data.Money, data.Version))
	loadedEvent:Fire(player)
end

local function onPlayerRemoving(player: Player)
	local session = sessions[player]
	if session then
		sessions[player] = nil
		session.profile:EndSession()
	end
end

function DataService:Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

function DataService.IsLoaded(player: Player): boolean
	return sessions[player] ~= nil
end

function DataService.GetLedger(player: Player): Ledger.Ledger?
	local session = sessions[player]
	return session and session.ledger
end

-- The live saved table. Mutate it only from server services, never trust client values.
function DataService.GetData(player: Player): ProfileSchema.ProfileData?
	local session = sessions[player]
	return session and session.profile.Data
end

return DataService

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
local Progression = require(Shared.Logic.Progression)
local WeaponCrafting = require(Shared.Logic.WeaponCrafting)
local ServerNet = require(script.Parent.Parent.Lib.ServerNet)
local ProfileStore = require(script.Parent.Parent.Packages.ProfileStore) :: any

local SCHEMA_CONFIG = ProfileSchema.ConfigFrom(Economy, Parts)

local KICK_LOAD_FAILED = "Could not load your data. Please come back in a minute."
local KICK_SESSION_ENDED = "Your session was opened on another server."
local KICK_FUTURE_VERSION = "This server is outdated. Please join another server."

local DataService = {}

type Session = { profile: any, ledger: Ledger.Ledger }
local sessions: { [Player]: Session } = {}
local loadedCallbacks: { (Player) -> () } = {}

local store = ProfileStore.New(DataConfig.StoreName, ProfileSchema.Template(SCHEMA_CONFIG))
if RunService:IsStudio() and DataConfig.UseMockInStudio then
	store = store.Mock
end

local function publish(player: Player, data: ProfileSchema.ProfileData)
	player:SetAttribute("Money", data.Money)
	player:SetAttribute("Level", data.Level)
	player:SetAttribute("Xp", data.Xp)
	player:SetAttribute("XpToNext", Progression.XpToNext(data.Level, Economy.Progression))
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
	DataService.Sync(player)
	for _, callback in loadedCallbacks do
		task.spawn(callback, player)
	end
end

local function onPlayerRemoving(player: Player)
	local session = sessions[player]
	if session then
		sessions[player] = nil
		session.profile:EndSession()
	end
end

function DataService:Start()
	ServerNet.Setup()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

-- Calls `callback(player)` for every player whose data is loaded, now and in the future.
function DataService.OnPlayerLoaded(callback: (Player) -> ())
	table.insert(loadedCallbacks, callback)
	for player in sessions do
		task.spawn(callback, player)
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

function DataService.GetBrand(player: Player): string
	return player.DisplayName
end

-- Finds a weapon by id. Returns (index, savedData, computedWeapon) or nil.
function DataService.FindWeapon(player: Player, weaponId: any): (number?, ProfileSchema.WeaponData?, WeaponCrafting.Weapon?)
	local data = DataService.GetData(player)
	if data == nil or type(weaponId) ~= "string" then
		return nil, nil, nil
	end
	for i, w in data.Weapons do
		if w.id == weaponId then
			local crafted = WeaponCrafting.Craft(w.parts, DataService.GetBrand(player), Parts, Economy)
			return i, w, crafted
		end
	end
	return nil, nil, nil
end

-- Adds XP, handles level ups (attributes + LevelUp event).
function DataService.AddXp(player: Player, amount: number)
	local data = DataService.GetData(player)
	if data == nil then
		return
	end
	local level, xp, gained = Progression.AddXp(data.Level, data.Xp, amount, Economy.Progression, Economy.Profile.MaxLevel)
	data.Level, data.Xp = level, xp
	publish(player, data)
	if gained > 0 then
		ServerNet.FireClient("LevelUp", player, level)
	end
end

-- Snapshot sent to the owner's client (UI only: the server never trusts it back).
function DataService.Snapshot(player: Player): any
	local data = DataService.GetData(player)
	if data == nil then
		return nil
	end
	local brand = DataService.GetBrand(player)
	local weapons = {}
	for _, w in data.Weapons do
		local crafted = WeaponCrafting.Craft(w.parts, brand, Parts, Economy)
		if crafted then
			table.insert(weapons, {
				id = w.id,
				name = w.name or "Blaster",
				parts = table.clone(w.parts),
				rarity = crafted.rarity,
				value = crafted.value,
				suggestedPrice = crafted.suggestedPrice,
				price = w.price or crafted.suggestedPrice,
				stats = crafted.stats,
				contraband = crafted.contraband,
				fullSet = crafted.fullSet,
			})
		end
	end
	return {
		Money = data.Money,
		Level = data.Level,
		Brand = brand,
		Parts = table.clone(data.Parts),
		Weapons = weapons,
		Stats = table.clone(data.Stats),
	}
end

function DataService.Sync(player: Player)
	local snapshot = DataService.Snapshot(player)
	if snapshot then
		ServerNet.FireClient("DataSync", player, snapshot)
	end
end

return DataService

--!strict
-- Server side of the remotes: creates them, rate-limits every request per player and never lets a
-- handler error leak to the client. Handlers return (ok: boolean, resultOrErrorCode: any).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local NetworkConfig = require(Shared.Config.Network)
local RateLimiter = require(Shared.Logic.RateLimiter)

local ServerNet = {}

local limiters: { [string]: RateLimiter.RateLimiter } = {}
local isSetup = false

function ServerNet.Setup()
	if isSetup then
		return
	end
	isSetup = true
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	local remotes = folder :: Instance
	for _, name in Net.Functions do
		if remotes:FindFirstChild(name) == nil then
			local rf = Instance.new("RemoteFunction")
			rf.Name = name
			rf.Parent = remotes
		end
	end
	for _, name in Net.Events do
		if remotes:FindFirstChild(name) == nil then
			local re = Instance.new("RemoteEvent")
			re.Name = name
			re.Parent = remotes
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		for _, limiter in limiters do
			limiter:Forget(player)
		end
	end)
end

function ServerNet.Handle(name: string, handler: (player: Player, ...any) -> (boolean, any))
	ServerNet.Setup()
	assert(table.find(Net.Functions, name), "unknown remote function " .. name)
	local rate = NetworkConfig.PerRemote[name] or NetworkConfig.Default
	local limiter = RateLimiter.new(rate.capacity, rate.refillPerSecond)
	limiters[name] = limiter

	Net.GetFunction(name).OnServerInvoke = function(player: Player, ...: any)
		if not limiter:Allow(player, os.clock()) then
			return false, "RateLimited"
		end
		local called, ok, result = pcall(handler, player, ...)
		if not called then
			warn(("[ServerNet] %s failed for %s: %s"):format(name, player.Name, tostring(ok)))
			return false, "ServerError"
		end
		return ok, result
	end
end

-- Client -> server RemoteEvent, rate-limited like the functions (extra calls are dropped).
function ServerNet.OnEvent(name: string, handler: (player: Player, ...any) -> ())
	ServerNet.Setup()
	assert(table.find(Net.Events, name), "unknown remote event " .. name)
	local rate = NetworkConfig.PerRemote[name] or NetworkConfig.Default
	local limiter = RateLimiter.new(rate.capacity, rate.refillPerSecond)
	limiters[name] = limiter
	Net.GetEvent(name).OnServerEvent:Connect(function(player: Player, ...: any)
		if not limiter:Allow(player, os.clock()) then
			return
		end
		local args = table.pack(...)
		xpcall(function()
			handler(player, table.unpack(args, 1, args.n))
		end, function(err)
			warn(("[ServerNet] %s failed for %s: %s"):format(name, player.Name, tostring(err)))
		end)
	end)
end

function ServerNet.FireClient(name: string, player: Player, ...: any)
	ServerNet.Setup()
	Net.GetEvent(name):FireClient(player, ...)
end

function ServerNet.FireAllClients(name: string, ...: any)
	ServerNet.Setup()
	Net.GetEvent(name):FireAllClients(...)
end

function ServerNet.Notify(player: Player, text: string, kind: string?)
	ServerNet.FireClient("Notify", player, text, kind or "info")
end

return ServerNet

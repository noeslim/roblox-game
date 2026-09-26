--!strict
-- Remote definitions. The server creates them in ReplicatedStorage.Remotes (ServerNet.Setup);
-- the client only waits for them. Requests are RemoteFunctions returning (ok, resultOrErrorCode).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = {}

Net.Functions = {
	"RequestSnapshot",
	"RequestPlace",
	"RequestMove",
	"RequestRemove",
	"RequestCraft",
	"RequestBuyPart",
	"RequestSetPrice",
	"RequestSell",
	"RequestAcceptCounter",
	"RequestDecline",
}

Net.Events = {
	"DataSync", -- server -> owner: snapshot of money, parts, weapons
	"Notify", -- server -> client: (text, kind)
	"CraftFx", -- server -> all: (position, partIds, rarity, value, ownerUserId)
	"SaleFx", -- server -> all: (info table)
	"LevelUp", -- server -> owner: (newLevel)
}

local function folder(): Instance
	return ReplicatedStorage:WaitForChild("Remotes")
end

function Net.GetFunction(name: string): RemoteFunction
	return folder():WaitForChild(name) :: RemoteFunction
end

function Net.GetEvent(name: string): RemoteEvent
	return folder():WaitForChild(name) :: RemoteEvent
end

-- Client helper: never throws. Returns (ok, resultOrErrorCode).
function Net.Invoke(name: string, ...: any): (boolean, any)
	local remote = Net.GetFunction(name)
	local called, ok, result = pcall(remote.InvokeServer, remote, ...)
	if not called then
		return false, "NetworkError"
	end
	return ok == true, result
end

return Net

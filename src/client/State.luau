--!strict
-- Latest snapshot of the local player's data (money, parts, weapons), sent by the server.
-- Display only: the server re-checks everything.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local State = {}

local changed = Instance.new("BindableEvent")
State.Changed = changed.Event -- fires (snapshot)

local current: any = nil

function State.Get(): any
	return current
end

local function set(snapshot: any)
	if type(snapshot) == "table" then
		current = snapshot
		changed:Fire(snapshot)
	end
end

Net.GetEvent("DataSync").OnClientEvent:Connect(set)

-- The first DataSync may be sent before this script runs: ask for it until it comes.
task.spawn(function()
	while current == nil do
		local ok, snapshot = Net.Invoke("RequestSnapshot")
		if ok and snapshot then
			if current == nil then
				set(snapshot)
			end
			break
		end
		task.wait(1)
	end
end)

return State

--!strict
-- Server entry point. Boots every service in Services/ (each ModuleScript returning a table with :Start()).
local servicesFolder = script:WaitForChild("Services")
local started = {}

for _, module in servicesFolder:GetChildren() do
	if module:IsA("ModuleScript") then
		local service = require(module) :: any
		if type(service.Start) == "function" then
			task.spawn(service.Start, service)
			table.insert(started, module.Name)
		end
	end
end

print(("[Server] started %d services: %s"):format(#started, table.concat(started, ", ")))

--!strict
-- Client entry point. Boots every controller in Controllers/.
local controllersFolder = script:WaitForChild("Controllers")

for _, module in controllersFolder:GetChildren() do
	if module:IsA("ModuleScript") then
		local controller = require(module) :: any
		if type(controller.Start) == "function" then
			task.spawn(controller.Start, controller)
		end
	end
end

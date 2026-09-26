--!strict
-- Walks a Humanoid to a point, using pathfinding around the dealers' walls when possible.
local PathfindingService = game:GetService("PathfindingService")

local NpcMover = {}

local AGENT = {
	AgentRadius = 1.5,
	AgentHeight = 5,
	AgentCanJump = false,
	WaypointSpacing = 4,
}

local function moveDirect(humanoid: Humanoid, target: Vector3, timeout: number): boolean
	humanoid:MoveTo(target)
	local reached = false
	local done = false
	local conn = humanoid.MoveToFinished:Connect(function(r)
		reached = r
		done = true
	end)
	local t0 = os.clock()
	while not done and os.clock() - t0 < timeout and humanoid.Parent do
		task.wait(0.1)
	end
	conn:Disconnect()
	return reached
end

-- Returns true when the target was reached before `maxSeconds`.
-- `isCancelled` is polled between waypoints (e.g. the customer was dismissed).
function NpcMover.WalkTo(humanoid: Humanoid, root: BasePart, target: Vector3, maxSeconds: number, isCancelled: (() -> boolean)?): boolean
	local started = os.clock()
	local path = PathfindingService:CreatePath(AGENT)
	local ok = pcall(function()
		path:ComputeAsync(root.Position, target)
	end)
	if ok and path.Status == Enum.PathStatus.Success then
		for _, wp in path:GetWaypoints() do
			if isCancelled and isCancelled() then
				return false
			end
			local left = maxSeconds - (os.clock() - started)
			if left <= 0 or humanoid.Parent == nil then
				return false
			end
			if not moveDirect(humanoid, wp.Position, math.min(left, 6)) then
				-- blocked (a player in the way...): try the rest in a straight line
				break
			end
		end
	end
	local left = maxSeconds - (os.clock() - started)
	if left <= 0 or (isCancelled and isCancelled()) then
		return false
	end
	moveDirect(humanoid, target, math.min(left, 8))
	return ((root.Position - target) * Vector3.new(1, 0, 1)).Magnitude < 2.5
end

return NpcMover

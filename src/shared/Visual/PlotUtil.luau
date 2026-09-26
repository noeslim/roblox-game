--!strict
-- Converts plot-local stash coordinates to world CFrames. Used by the server and the client.
-- A plot is a Folder in workspace.Hideouts (one per trap house) with a "Floor" part (inside the
-- plot's Anchor model): the plot origin is the center of the basement floor's top face, local +Z
-- points to the street.

local PlotUtil = {}

function PlotUtil.GetFloor(plot: Instance): BasePart
	local floor = plot:FindFirstChild("Floor", true)
	while floor == nil do
		task.wait(0.2) -- streaming in
		floor = plot:FindFirstChild("Floor", true)
	end
	return floor :: BasePart
end

function PlotUtil.GetOrigin(plot: Instance): CFrame
	local floor = PlotUtil.GetFloor(plot)
	return floor.CFrame * CFrame.new(0, floor.Size.Y / 2, 0)
end

function PlotUtil.GetSize(plot: Instance): (number, number, number)
	return plot:GetAttribute("SizeX") :: number, plot:GetAttribute("SizeZ") :: number, plot:GetAttribute("MaxHeight") :: number
end

-- CFrame of an object's center.
function PlotUtil.ObjectCFrame(origin: CFrame, sizeY: number, x: number, z: number, rotation: number): CFrame
	return origin * CFrame.new(x, sizeY / 2, z) * CFrame.Angles(0, math.rad(rotation), 0)
end

-- World point -> plot-local (x, z).
function PlotUtil.ToLocal(origin: CFrame, worldPos: Vector3): (number, number)
	local p = origin:PointToObjectSpace(worldPos)
	return p.X, p.Z
end

-- Plot owned by a user id, or nil.
function PlotUtil.FindPlotOf(userId: number): Instance?
	local hideouts = workspace:FindFirstChild("Hideouts")
	if hideouts == nil then
		return nil
	end
	for _, plot in hideouts:GetChildren() do
		if plot:GetAttribute("OwnerUserId") == userId then
			return plot
		end
	end
	return nil
end

return PlotUtil

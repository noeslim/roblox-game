--!strict
-- Placement validation for free building. Coordinates are LOCAL to the plot (plot origin = 0,0,0).
-- Pure math: no Vector3/CFrame so it runs in Lune. The server converts to CFrame when spawning.

local Grid = {}

export type Placed = {
	id: string, -- unique instance id inside the stash
	x: number, y: number, z: number, -- center of the object
	sizeX: number, sizeY: number, sizeZ: number,
	rotation: number, -- degrees around Y
	solid: boolean?, -- false = decoration you can overlap (rugs, lights). default true
}

export type Plot = {
	sizeX: number, sizeZ: number, -- plot spans [-sizeX/2, sizeX/2] x [-sizeZ/2, sizeZ/2]
	maxHeight: number, -- objects must stay within [0, maxHeight]
}

export type Bounds = {
	minX: number, maxX: number,
	minY: number, maxY: number,
	minZ: number, maxZ: number,
}

local EPS = 1e-4

local function isFiniteNumber(v: any): boolean
	return type(v) == "number" and v == v and v > -math.huge and v < math.huge
end

function Grid.Snap(value: number, step: number): number
	return math.floor(value / step + 0.5) * step
end

function Grid.SnapRotation(degrees: number, step: number): number
	return Grid.Snap(degrees, step) % 360
end

function Grid.IsOnGrid(value: number, step: number): boolean
	return math.abs(Grid.Snap(value, step) - value) < EPS
end

-- Axis-aligned bounding box of an object rotated around Y (conservative for non-90° angles).
function Grid.GetBounds(o: Placed): Bounds
	local r = math.rad(o.rotation)
	local c, s = math.abs(math.cos(r)), math.abs(math.sin(r))
	local halfX = (c * o.sizeX + s * o.sizeZ) / 2
	local halfZ = (s * o.sizeX + c * o.sizeZ) / 2
	local halfY = o.sizeY / 2
	return {
		minX = o.x - halfX, maxX = o.x + halfX,
		minY = o.y - halfY, maxY = o.y + halfY,
		minZ = o.z - halfZ, maxZ = o.z + halfZ,
	}
end

function Grid.Overlaps(a: Bounds, b: Bounds): boolean
	-- touching faces is allowed, only strict interpenetration counts
	return a.minX < b.maxX - EPS and a.maxX > b.minX + EPS
		and a.minY < b.maxY - EPS and a.maxY > b.minY + EPS
		and a.minZ < b.maxZ - EPS and a.maxZ > b.minZ + EPS
end

export type ValidateOptions = {
	gridSize: number,
	rotationStep: number,
	maxObjects: number,
	ignoreId: string?, -- when moving an existing object
}

-- Returns (true, nil) or (false, errorCode)
function Grid.ValidatePlacement(o: Placed, plot: Plot, existing: { Placed }, opts: ValidateOptions): (boolean, string?)
	for _, key in { "x", "y", "z", "sizeX", "sizeY", "sizeZ", "rotation" } do
		if not isFiniteNumber((o :: any)[key]) then
			return false, "InvalidNumber:" .. key
		end
	end
	if o.sizeX <= 0 or o.sizeY <= 0 or o.sizeZ <= 0 then
		return false, "InvalidSize"
	end
	if not Grid.IsOnGrid(o.rotation, opts.rotationStep) then
		return false, "BadRotation"
	end

	local b = Grid.GetBounds(o)

	-- The object's corner must sit on the grid (avoid half-stud offsets for odd sizes)
	if not (Grid.IsOnGrid(b.minX, opts.gridSize) and Grid.IsOnGrid(b.minZ, opts.gridSize)) then
		-- non-90° rotations produce irrational bounds, only enforce grid on the center then
		if o.rotation % 90 == 0 or not (Grid.IsOnGrid(o.x, opts.gridSize) and Grid.IsOnGrid(o.z, opts.gridSize)) then
			return false, "OffGrid"
		end
	end

	local hx, hz = plot.sizeX / 2, plot.sizeZ / 2
	if b.minX < -hx - EPS or b.maxX > hx + EPS or b.minZ < -hz - EPS or b.maxZ > hz + EPS then
		return false, "OutsidePlot"
	end
	if b.minY < -EPS or b.maxY > plot.maxHeight + EPS then
		return false, "OutsideHeight"
	end

	local count = 0
	for _, other in existing do
		if other.id ~= opts.ignoreId then
			count += 1
			if o.solid ~= false and other.solid ~= false and Grid.Overlaps(b, Grid.GetBounds(other)) then
				return false, "Collision:" .. other.id
			end
		end
	end

	if opts.ignoreId == nil and count >= opts.maxObjects then
		return false, "TooManyObjects"
	end

	return true, nil
end

return Grid

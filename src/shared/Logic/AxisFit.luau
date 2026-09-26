--!strict
-- Finds the 90-degree rotation (one of 24) that best maps a set of expected points onto measured
-- points, up to a translation. Used to undo a turn applied by the Studio FBX importer to the whole
-- mesh library (a half turn cannot be seen on the reference cube). Pure: plain {x, y, z} tables.

local AxisFit = {}

export type Vec = { x: number, y: number, z: number }
-- rotation = its X and Y axes (Z = X cross Y), like CFrame.fromMatrix(pos, right, up)
export type Rotation = { right: Vec, up: Vec }

local function v(x: number, y: number, z: number): Vec
	return { x = x, y = y, z = z }
end

local function cross(a: Vec, b: Vec): Vec
	return v(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
end

function AxisFit.Apply(r: Rotation, p: Vec): Vec
	local back = cross(r.right, r.up)
	return v(
		r.right.x * p.x + r.up.x * p.y + back.x * p.z,
		r.right.y * p.x + r.up.y * p.y + back.y * p.z,
		r.right.z * p.x + r.up.z * p.y + back.z * p.z
	)
end

function AxisFit.Candidates(): { Rotation }
	local axes = { v(1, 0, 0), v(-1, 0, 0), v(0, 1, 0), v(0, -1, 0), v(0, 0, 1), v(0, 0, -1) }
	local list: { Rotation } = {}
	for _, right in axes do
		for _, up in axes do
			if right.x * up.x + right.y * up.y + right.z * up.z == 0 then
				table.insert(list, { right = right, up = up })
			end
		end
	end
	return list
end

-- pairs: { measured, expected }. Returns the best rotation and the mean distance left after it.
function AxisFit.Best(pairs: { { measured: Vec, expected: Vec } }): (Rotation, number)
	local n = #pairs
	local identity = { right = v(1, 0, 0), up = v(0, 1, 0) }
	if n == 0 then
		return identity, 0
	end
	local mc, ec = v(0, 0, 0), v(0, 0, 0)
	for _, p in pairs do
		mc = v(mc.x + p.measured.x / n, mc.y + p.measured.y / n, mc.z + p.measured.z / n)
		ec = v(ec.x + p.expected.x / n, ec.y + p.expected.y / n, ec.z + p.expected.z / n)
	end
	local best, bestErr = identity, math.huge
	for _, r in AxisFit.Candidates() do
		local err = 0
		for _, p in pairs do
			local e = AxisFit.Apply(r, v(p.expected.x - ec.x, p.expected.y - ec.y, p.expected.z - ec.z))
			local dx, dy, dz = p.measured.x - mc.x - e.x, p.measured.y - mc.y - e.y, p.measured.z - mc.z - e.z
			err += math.sqrt(dx * dx + dy * dy + dz * dz)
		end
		if err < bestErr - 1e-9 then
			best, bestErr = r, err
		end
	end
	return best, bestErr / n
end

return AxisFit

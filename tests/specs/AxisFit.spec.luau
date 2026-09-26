local AxisFit = require("../../src/shared/Logic/AxisFit")

local function v(x, y, z)
	return { x = x, y = y, z = z }
end

local points = { v(0, 0, 0), v(140, 0, -160), v(280, 5, -160), v(20, 3, 40), v(60, 10, 80), v(-30, 2, 10) }

local function measuredWith(r, shift)
	local pairs = {}
	for _, p in points do
		local q = AxisFit.Apply(r, p)
		table.insert(pairs, { measured = v(q.x + shift.x, q.y + shift.y, q.z + shift.z), expected = p })
	end
	return pairs
end

return function(t)
	t.test("24 distinct rotations", function()
		t.eq(#AxisFit.Candidates(), 24)
	end)

	t.test("no turn: identity", function()
		local r, err = AxisFit.Best(measuredWith({ right = v(1, 0, 0), up = v(0, 1, 0) }, v(5, -3, 900)))
		t.eq(r.right.x, 1)
		t.eq(r.up.y, 1)
		t.near(err, 0, 1e-6)
	end)

	t.test("finds a half turn around Y, whatever the offset", function()
		local halfTurn = { right = v(-1, 0, 0), up = v(0, 1, 0) }
		local r, err = AxisFit.Best(measuredWith(halfTurn, v(-400, 12, 33)))
		t.eq(r.right.x, -1)
		t.eq(r.up.y, 1)
		t.near(err, 0, 1e-6)
		local back = AxisFit.Apply(r, v(0, 0, 1))
		t.eq(back.z, -1)
	end)

	t.test("finds a quarter turn", function()
		local quarter = { right = v(0, 0, -1), up = v(0, 1, 0) }
		local r = AxisFit.Best(measuredWith(quarter, v(1, 2, 3)))
		t.eq(r.right.z, -1)
	end)

	t.test("a mirrored set leaves a large error", function()
		local pairs = {}
		for _, p in points do
			table.insert(pairs, { measured = v(-p.x, p.y, p.z), expected = p })
		end
		local _, err = AxisFit.Best(pairs)
		t.truthy(err > 1)
	end)
end

local CityLayout = require("../../src/shared/Logic/CityLayout")
local City = require("../../src/shared/Config/City")

local layout = CityLayout.Build(City)

local function count(list, pred)
	local n = 0
	for _, v in list do
		if pred == nil or pred(v) then
			n += 1
		end
	end
	return n
end

return function(t)
	t.test("18 trap houses with unique indices", function()
		t.eq(#layout.houses, 18)
		for i, h in layout.houses do
			t.eq(h.index, i)
			t.eq(h.district, "Blocks")
		end
	end)

	t.test("deterministic for a seed", function()
		local again = CityLayout.Build(City)
		t.eq(#again.buildings, #layout.buildings)
		t.eq(#again.props, #layout.props)
		t.eq(again.buildings[10].x, layout.buildings[10].x)
		t.eq(again.buildings[10].color, layout.buildings[10].color)
	end)

	t.test("a reasonable number of buildings and props", function()
		t.truthy(#layout.buildings >= 100 and #layout.buildings <= 450, "buildings: " .. #layout.buildings)
		t.truthy(count(layout.props, function(p)
			return p.kind == "lamp"
		end) >= 100, "lamps")
	end)

	t.test("roads never overlap each other", function()
		for i, a in layout.roads do
			for j = i + 1, #layout.roads do
				t.falsy(CityLayout.Overlaps(a, layout.roads[j], 0.01), ("road %d overlaps road %d"):format(i, j))
			end
		end
	end)

	t.test("buildings stay off roads and off each other", function()
		for i, b in layout.buildings do
			for _, r in layout.roads do
				t.falsy(CityLayout.Overlaps(b.footprint, r, 0.01), ("building %d (%s) on a road"):format(i, b.archetype))
			end
			for j = i + 1, #layout.buildings do
				t.falsy(CityLayout.Overlaps(b.footprint, layout.buildings[j].footprint, 0.01), ("building %d overlaps %d"):format(i, j))
			end
		end
	end)

	t.test("houses fit their lot and face a street", function()
		local H = City.Houses
		for _, h in layout.houses do
			local house = { x0 = h.x - H.Depth / 2 - 1, z0 = h.z - H.Depth / 2 - 1, x1 = h.x - H.Depth / 2 + H.Width + 1, z1 = h.z + H.Depth / 2 + H.PorchDepth }
			t.truthy(house.x0 >= h.lot.x0 and house.x1 <= h.lot.x1 and house.z0 >= h.lot.z0 and house.z1 <= h.lot.z1, "house " .. h.index .. " fits")
			for _, r in layout.roads do
				t.falsy(CityLayout.Overlaps(house, r), "house " .. h.index .. " on a road")
			end
			for _, b in layout.buildings do
				t.falsy(CityLayout.Overlaps(house, b.footprint), "house " .. h.index .. " hits a building")
			end
			-- in front of the lot (sidewalk + a few studs) there is a road
			local ahead = h.lot.z1 + City.Grid.SidewalkWidth + 3
			local found = false
			for _, r in layout.roads do
				if CityLayout.Contains(r, h.x, ahead) then
					found = true
				end
			end
			t.truthy(found, "house " .. h.index .. " faces a road")
		end
	end)

	t.test("lamps and furniture are on sidewalks, not on roads", function()
		for _, p in layout.props do
			if p.kind == "lamp" or p.kind == "hydrant" or p.kind == "bench" then
				for _, r in layout.roads do
					t.falsy(CityLayout.Contains(r, p.x, p.z), p.kind .. " on a road")
				end
			end
		end
	end)

	t.test("utility poles are wired along the trap house streets", function()
		local poles = {}
		for _, p in layout.props do
			if p.kind == "utility_pole" then
				poles[p.x .. "," .. p.z] = true
				for _, r in layout.roads do
					t.falsy(CityLayout.Contains(r, p.x, p.z), "pole on a road")
				end
			end
		end
		t.truthy(#layout.wires > 0, "no wires")
		for _, w in layout.wires do
			t.truthy(poles[w.x0 .. "," .. w.z0] and poles[w.x1 .. "," .. w.z1], "wire not between two poles")
			local length = math.abs(w.x1 - w.x0) + math.abs(w.z1 - w.z0)
			t.truthy(length > 20 and length <= City.Props.PoleSpacing + 12, "wire length " .. length)
		end
	end)

	t.test("traffic lights stand on the corners of avenue intersections", function()
		local n = 0
		for _, p in layout.props do
			if p.kind == "traffic_light" then
				n += 1
				for _, r in layout.roads do
					t.falsy(CityLayout.Contains(r, p.x, p.z), "traffic light on a road")
				end
			end
		end
		-- 16 intersections, corners outside the city are skipped
		t.truthy(n >= 16 and n <= 64, "traffic lights: " .. n)
	end)

	t.test("billboards sit on building roofs with a valid ad", function()
		local n = 0
		for _, p in layout.props do
			if p.kind == "billboard" then
				n += 1
				t.truthy(p.ad and City.BillboardAds[p.ad], "billboard ad")
				local onRoof = false
				for _, b in layout.buildings do
					if b.x == p.x and b.z == p.z and City.Archetypes[b.archetype].h == p.y then
						onRoof = true
					end
				end
				t.truthy(onRoof, "billboard not on a roof")
			end
		end
		t.truthy(n > 5, "billboards: " .. n)
	end)

	t.test("war zone has 5 control points and both spawns inside its cell", function()
		local zone
		for _, c in layout.cells do
			if c.district == "WarZone" then
				zone = c.rect
			end
		end
		t.truthy(zone)
		local points, red, blue = 0, false, false
		for _, s in layout.specials do
			if s.kind == "control_point" then
				points += 1
				t.truthy(CityLayout.Contains(zone, s.x, s.z), "point " .. tostring(s.label))
			elseif s.kind == "spawn_red" then
				red = CityLayout.Contains(zone, s.x, s.z)
			elseif s.kind == "spawn_blue" then
				blue = CityLayout.Contains(zone, s.x, s.z)
			end
		end
		t.eq(points, 5)
		t.truthy(red and blue)
	end)

	t.test("points of interest exist", function()
		local names = {}
		for _, p in layout.pois do
			names[p.name] = true
		end
		for _, n in { "Spawn", "Police", "Bank", "Supplier", "Pier", "BlackMarket", "GasStation", "WarZone", "Bar" } do
			t.truthy(names[n], n)
		end
		t.truthy(#layout.customerSpawns >= 8)
	end)

	t.test("every building archetype is known", function()
		for _, b in layout.buildings do
			t.truthy(City.Archetypes[b.archetype], b.archetype)
		end
	end)
end

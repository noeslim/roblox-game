--!strict
-- Computes the whole city from Config/City: roads, sidewalks, lots, buildings, trap houses, props,
-- points of interest. Pure and deterministic (own PRNG), so it is tested with Lune and the same
-- data drives the Roblox MapBuilder and the 3D preview (tools/meshgen).
-- World studs: x = east, z = south. "rot" = degrees around Y; a building/house/prop faces its local
-- +Z (CFrame.Angles(0, math.rad(rot), 0)): rot 0 faces south, 180 north, 90 east, -90 west.

local CityLayout = {}

export type Rect = { x0: number, z0: number, x1: number, z1: number }
export type Slab = { kind: string, x0: number, z0: number, x1: number, z1: number, top: number, thickness: number }
export type Road = { kind: string, x0: number, z0: number, x1: number, z1: number }
export type Building = {
	archetype: string,
	x: number,
	z: number,
	rot: number,
	color: string,
	district: string,
	sign: string?,
	footprint: Rect,
}
export type House = { index: number, x: number, z: number, district: string, lot: Rect }
export type Prop = { kind: string, x: number, z: number, rot: number, y: number?, ad: number? }
export type Special = { kind: string, x: number, z: number, rot: number, sx: number?, sz: number?, label: string? }
export type Poi = { name: string, x: number, z: number }
-- overhead wires between two utility poles (rot = the poles' rotation, the crossarm runs along local Z)
export type Wire = { x0: number, z0: number, x1: number, z1: number, rot: number }
export type Layout = {
	half: number,
	cells: { { district: string, rect: Rect } },
	slabs: { Slab },
	roads: { Road },
	buildings: { Building },
	houses: { House },
	props: { Prop },
	specials: { Special },
	pois: { Poi },
	customerSpawns: { Poi },
	wires: { Wire },
}

-- Deterministic PRNG (Park-Miller). Random is not available in pure Lune code.
type Rng = { next: (self: Rng) -> number, int: (self: Rng, a: number, b: number) -> number, range: (self: Rng, a: number, b: number) -> number, state: number }

local function newRng(seed: number): Rng
	local r = {} :: any
	r.state = (seed % 2147483646) + 1
	function r.next(self: Rng): number
		self.state = (self.state * 48271) % 2147483647
		return self.state / 2147483647
	end
	function r.int(self: Rng, a: number, b: number): number
		return a + math.floor(self:next() * (b - a + 1))
	end
	function r.range(self: Rng, a: number, b: number): number
		return a + self:next() * (b - a)
	end
	return r
end

local function rect(x0: number, z0: number, x1: number, z1: number): Rect
	return { x0 = math.min(x0, x1), z0 = math.min(z0, z1), x1 = math.max(x0, x1), z1 = math.max(z0, z1) }
end

function CityLayout.Overlaps(a: Rect, b: Rect, margin: number?): boolean
	local m = margin or 0
	return a.x0 < b.x1 - m and a.x1 > b.x0 + m and a.z0 < b.z1 - m and a.z1 > b.z0 + m
end

function CityLayout.Contains(r: Rect, x: number, z: number): boolean
	return x >= r.x0 and x <= r.x1 and z >= r.z0 and z <= r.z1
end

-- Axis-aligned footprint of a W x D thing centered at (x, z) rotated by a multiple of 90 degrees.
function CityLayout.Footprint(x: number, z: number, w: number, d: number, rot: number): Rect
	local r = math.abs(rot) % 180
	local sx, sz = w, d
	if r == 90 then
		sx, sz = d, w
	end
	return rect(x - sx / 2, z - sz / 2, x + sx / 2, z + sz / 2)
end

local function weightedPick(rng: Rng, weights: { [string]: number }, allowed: ((string) -> boolean)?): string?
	local names = {}
	for name in weights do
		if allowed == nil or allowed(name) then
			table.insert(names, name)
		end
	end
	if #names == 0 then
		return nil
	end
	table.sort(names)
	local total = 0
	for _, n in names do
		total += weights[n]
	end
	local roll = rng:next() * total
	for _, n in names do
		roll -= weights[n]
		if roll <= 0 then
			return n
		end
	end
	return names[#names]
end

function CityLayout.Build(cfg: any): Layout
	local G = cfg.Grid
	local N, C, A, SW = G.Cells, G.CellSize, G.AvenueWidth, G.SidewalkWidth
	local half = (N * C + (N + 1) * A) / 2
	local ox, oz = cfg.Origin.x, cfg.Origin.z
	local rng = newRng(cfg.Seed)

	local layout: Layout = {
		half = half,
		cells = {},
		slabs = {},
		roads = {},
		buildings = {},
		houses = {},
		props = {},
		specials = {},
		pois = {},
		customerSpawns = {},
		wires = {},
	}

	local SIDEWALK_TOP = G.SidewalkHeight

	local function slab(kind: string, r: Rect, top: number, thickness: number)
		if r.x1 - r.x0 > 0.01 and r.z1 - r.z0 > 0.01 then
			table.insert(layout.slabs, { kind = kind, x0 = r.x0, z0 = r.z0, x1 = r.x1, z1 = r.z1, top = top, thickness = thickness })
		end
	end

	local function addRoad(kind: string, r: Rect)
		table.insert(layout.roads, { kind = kind, x0 = r.x0, z0 = r.z0, x1 = r.x1, z1 = r.z1 })
		slab("road", r, 0, 1)
		-- markings: double yellow line on avenues, white dashes elsewhere
		local cx, cz = (r.x0 + r.x1) / 2, (r.z0 + r.z1) / 2
		local horizontal = r.x1 - r.x0 > r.z1 - r.z0
		if kind == "avenue" then
			for _, o in { -0.45, 0.45 } do
				if horizontal then
					slab("line", rect(r.x0 + 2, cz + o - 0.2, r.x1 - 2, cz + o + 0.2), 0.03, 0.06)
				else
					slab("line", rect(cx + o - 0.2, r.z0 + 2, cx + o + 0.2, r.z1 - 2), 0.03, 0.06)
				end
			end
		else
			local length = if horizontal then r.x1 - r.x0 else r.z1 - r.z0
			local t = 4
			while t + 6 < length - 4 do
				if horizontal then
					slab("paint", rect(r.x0 + t, cz - 0.2, r.x0 + t + 6, cz + 0.2), 0.03, 0.06)
				else
					slab("paint", rect(cx - 0.2, r.z0 + t, cx + 0.2, r.z0 + t + 6), 0.03, 0.06)
				end
				t += 12
			end
		end
	end

	local function sidewalkRing(r: Rect)
		slab("sidewalk", rect(r.x0, r.z0, r.x1, r.z0 + SW), SIDEWALK_TOP, 1.5)
		slab("sidewalk", rect(r.x0, r.z1 - SW, r.x1, r.z1), SIDEWALK_TOP, 1.5)
		slab("sidewalk", rect(r.x0, r.z0 + SW, r.x0 + SW, r.z1 - SW), SIDEWALK_TOP, 1.5)
		slab("sidewalk", rect(r.x1 - SW, r.z0 + SW, r.x1, r.z1 - SW), SIDEWALK_TOP, 1.5)
	end

	local function shrink(r: Rect, m: number): Rect
		return rect(r.x0 + m, r.z0 + m, r.x1 - m, r.z1 - m)
	end

	local function addBuilding(archetype: string, x: number, z: number, rot: number, district: string, sign: string?): Building
		local a = cfg.Archetypes[archetype]
		local b: Building = {
			archetype = archetype,
			x = x,
			z = z,
			rot = rot,
			color = a.colors[rng:int(1, #a.colors)],
			district = district,
			sign = sign,
			footprint = CityLayout.Footprint(x, z, a.w, a.d, rot),
		}
		table.insert(layout.buildings, b)
		return b
	end

	local function signFor(district: string, archetype: string): string?
		local signs = cfg.ShopSigns[district]
		if signs and (archetype == "shop" or archetype == "chinatown") then
			return signs[rng:int(1, #signs)]
		end
		return nil
	end

	-- Places buildings along one side of a block interior. Returns the max depth used.
	local function placeRow(interior: Rect, side: string, district: string, from: number, to: number): number
		local weights = cfg.DistrictBuildings[district]
		local gap = cfg.BuildingGap[district] or 4
		local pos = from
		local maxDepth = 0
		while true do
			local left = to - pos
			local name = weightedPick(rng, weights, function(n)
				return cfg.Archetypes[n].w <= left
			end)
			if name == nil then
				break
			end
			local a = cfg.Archetypes[name]
			local c = pos + a.w / 2
			if side == "N" then
				addBuilding(name, c, interior.z0 + a.d / 2, 180, district, signFor(district, name))
			elseif side == "S" then
				addBuilding(name, c, interior.z1 - a.d / 2, 0, district, signFor(district, name))
			elseif side == "W" then
				addBuilding(name, interior.x0 + a.d / 2, c, -90, district, signFor(district, name))
			else
				addBuilding(name, interior.x1 - a.d / 2, c, 90, district, signFor(district, name))
			end
			maxDepth = math.max(maxDepth, a.d)
			pos += a.w + gap
		end
		return maxDepth
	end

	local function perimeter(interior: Rect, district: string, skip: { [string]: number }?)
		local dN = if skip and skip.N then skip.N else placeRow(interior, "N", district, interior.x0, interior.x1)
		local dS = if skip and skip.S then skip.S else placeRow(interior, "S", district, interior.x0, interior.x1)
		local gap = (cfg.BuildingGap[district] or 4) + 2
		placeRow(interior, "W", district, interior.z0 + dN + gap, interior.z1 - dS - gap)
		placeRow(interior, "E", district, interior.z0 + dN + gap, interior.z1 - dS - gap)
	end

	local function scatterTrees(area: Rect, count: number)
		local placed = 0
		local tries = 0
		while placed < count and tries < count * 20 do
			tries += 1
			local x, z = rng:range(area.x0 + 4, area.x1 - 4), rng:range(area.z0 + 4, area.z1 - 4)
			local spot = rect(x - 4, z - 4, x + 4, z + 4)
			local free = true
			for _, b in layout.buildings do
				if CityLayout.Overlaps(spot, b.footprint) then
					free = false
					break
				end
			end
			if free then
				table.insert(layout.props, { kind = "tree", x = x, z = z, rot = rng:range(0, 360) })
				placed += 1
			end
		end
	end

	-- District builders ---------------------------------------------------------------------------

	local function blockDistrict(cell: Rect, district: string)
		local alley = district == "Chinatown"
		local R = if alley then G.AlleyWidth else G.InnerRoadWidth
		local cx, cz = (cell.x0 + cell.x1) / 2, (cell.z0 + cell.z1) / 2
		local vertical = rect(cx - R / 2, cell.z0, cx + R / 2, cell.z1)
		local hLeft = rect(cell.x0, cz - R / 2, cx - R / 2, cz + R / 2)
		local hRight = rect(cx + R / 2, cz - R / 2, cell.x1, cz + R / 2)
		if alley then
			for _, r in { vertical, hLeft, hRight } do
				slab("alley", r, SIDEWALK_TOP, 1.5)
			end
			table.insert(layout.pois, { name = "BlackMarket", x = cx, z = cz })
			table.insert(layout.specials, { kind = "lanterns", x = cx, z = cz, rot = 0, sx = R, sz = cell.z1 - cell.z0 })
		else
			addRoad("inner", vertical)
			addRoad("inner", hLeft)
			addRoad("inner", hRight)
		end
		local blocks = {
			rect(cell.x0, cell.z0, cx - R / 2, cz - R / 2),
			rect(cx + R / 2, cell.z0, cell.x1, cz - R / 2),
			rect(cell.x0, cz + R / 2, cx - R / 2, cell.z1),
			rect(cx + R / 2, cz + R / 2, cell.x1, cell.z1),
		}
		for bi, b in blocks do
			sidewalkRing(b)
			local interior = shrink(b, SW)
			local ground = if district == "RichHills" then "grass" else "lot"
			if district == "Downtown" and bi == 4 then
				slab("plaza", interior, SIDEWALK_TOP, 1.5)
				local px, pz = (interior.x0 + interior.x1) / 2, (interior.z0 + interior.z1) / 2
				table.insert(layout.specials, { kind = "fountain", x = px, z = pz, rot = 0 })
				table.insert(layout.pois, { name = "Spawn", x = px, z = pz + 30 })
				table.insert(layout.specials, { kind = "court", x = interior.x1 - 32, z = interior.z1 - 24, rot = 90, sx = 30, sz = 50 })
				table.insert(layout.pois, { name = "Court", x = interior.x1 - 32, z = interior.z1 - 24 })
				for i = 0, 3 do
					for j = 0, 3 do
						local tx = interior.x0 + 20 + i * 40
						local tz = interior.z0 + 20 + j * 40
						if math.abs(tx - px) > 30 or math.abs(tz - pz) > 30 then
							table.insert(layout.props, { kind = "tree", x = tx, z = tz, rot = rng:range(0, 360) })
						end
					end
				end
				for i = 0, 7 do
					local a = i / 8 * math.pi * 2
					table.insert(layout.props, { kind = "bench", x = px + math.cos(a) * 24, z = pz + math.sin(a) * 24, rot = math.deg(math.atan2(math.cos(a), math.sin(a))) + 180 })
				end
				continue
			end
			slab(ground, interior, SIDEWALK_TOP, 1.5)
			local first = #layout.buildings + 1
			if district == "Strip" and bi == 3 then
				table.insert(layout.specials, { kind = "gas_station", x = interior.x0 + 40, z = interior.z1 - 26, rot = 0, sx = 64, sz = 44 })
				table.insert(layout.pois, { name = "GasStation", x = interior.x0 + 40, z = interior.z1 - 26 })
				local skipped = rect(interior.x0 + 80, interior.z0, interior.x1, interior.z1)
				placeRow(skipped, "S", district, skipped.x0, skipped.x1)
				perimeter(interior, district, { S = 50 })
			else
				perimeter(interior, district, nil)
			end
			if district == "Downtown" and (bi == 1 or bi == 2) and layout.buildings[first] then
				local landmark = layout.buildings[first]
				landmark.sign = if bi == 1 then "POLICE" else "BANK"
				table.insert(layout.pois, { name = if bi == 1 then "Police" else "Bank", x = landmark.x, z = landmark.z })
			end
			if district == "Strip" and bi == 2 and layout.buildings[first] then
				layout.buildings[first].sign = "BAR"
				table.insert(layout.pois, { name = "Bar", x = layout.buildings[first].x, z = layout.buildings[first].z })
			end
			if district == "RichHills" then
				scatterTrees(interior, 18)
			elseif district == "Industrial" then
				for _ = 1, 3 do
					table.insert(layout.props, { kind = "smokestack", x = rng:range(interior.x0 + 70, interior.x1 - 70), z = rng:range(interior.z0 + 70, interior.z1 - 70), rot = 0 })
				end
			end
		end
	end

	local function blocksDistrict(cell: Rect, district: string)
		local H = cfg.Houses
		local bandH = (cell.z1 - cell.z0) / H.Rows
		-- ring sidewalk, with openings where the house streets meet the avenues
		slab("sidewalk", rect(cell.x0, cell.z0, cell.x1, cell.z0 + SW), SIDEWALK_TOP, 1.5)
		slab("sidewalk", rect(cell.x0, cell.z1 - SW, cell.x1, cell.z1), SIDEWALK_TOP, 1.5)
		local segStart = cell.z0 + SW
		for row = 0, H.Rows - 2 do
			local streetZ1 = cell.z0 + (row + 1) * bandH
			local streetZ0 = streetZ1 - H.StreetWidth
			slab("sidewalk", rect(cell.x0, segStart, cell.x0 + SW, streetZ0), SIDEWALK_TOP, 1.5)
			slab("sidewalk", rect(cell.x1 - SW, segStart, cell.x1, streetZ0), SIDEWALK_TOP, 1.5)
			segStart = streetZ1
		end
		slab("sidewalk", rect(cell.x0, segStart, cell.x0 + SW, cell.z1 - SW), SIDEWALK_TOP, 1.5)
		slab("sidewalk", rect(cell.x1 - SW, segStart, cell.x1, cell.z1 - SW), SIDEWALK_TOP, 1.5)
		local lotWidth = (cell.x1 - cell.x0 - 2 * SW) / H.PerRow
		for row = 0, H.Rows - 1 do
			local bz0 = cell.z0 + row * bandH
			local bz1 = bz0 + bandH
			local last = row == H.Rows - 1
			local frontZ = if last then cell.z1 else bz1 - H.StreetWidth
			if not last then
				addRoad("street", rect(cell.x0, frontZ, cell.x1, bz1))
				slab("sidewalk", rect(cell.x0 + SW, frontZ - SW, cell.x1 - SW, frontZ), SIDEWALK_TOP, 1.5)
				slab("sidewalk", rect(cell.x0 + SW, bz1, cell.x1 - SW, bz1 + SW), SIDEWALK_TOP, 1.5)
			end
			local backZ = bz0 + SW
			local lotFront = frontZ - SW
			for k = 0, H.PerRow - 1 do
				local lx0 = cell.x0 + SW + k * lotWidth
				local lot = rect(lx0, backZ, lx0 + lotWidth, lotFront)
				local hx = (lot.x0 + lot.x1) / 2 - (H.Width / 2 - H.Depth / 2) -- house spans -24..+32 in x
				local hz = lotFront - H.YardDepth - H.PorchDepth - H.Depth / 2
				local index = #layout.houses + 1
				table.insert(layout.houses, { index = index, x = hx, z = hz, district = district, lot = lot })
				-- lawn around the basement hole (x -25..+33, z -25..+25 around the house origin)
				local hole = rect(hx - H.Depth / 2 - 1, hz - H.Depth / 2 - 1, hx - H.Depth / 2 + H.Width + 1, hz + H.Depth / 2 + 1)
				slab("grass", rect(lot.x0, lot.z0, lot.x1, hole.z0), SIDEWALK_TOP, 1.5)
				slab("grass", rect(lot.x0, hole.z1, lot.x1, lot.z1), SIDEWALK_TOP, 1.5)
				slab("grass", rect(lot.x0, hole.z0, hole.x0, hole.z1), SIDEWALK_TOP, 1.5)
				slab("grass", rect(hole.x1, hole.z0, lot.x1, hole.z1), SIDEWALK_TOP, 1.5)
				-- path from the sidewalk to the porch, in front of the door (above the stairwell)
				local doorX = hx + H.Depth / 2 + H.StairwellWidth / 2
				slab("path", rect(doorX - 2.5, hole.z1 + H.PorchDepth - 1, doorX + 2.5, lot.z1), SIDEWALK_TOP + 0.05, 1.5)
				table.insert(layout.props, { kind = "tree", x = hx - 10, z = hz - H.Depth / 2 - 22, rot = rng:range(0, 360) })
				table.insert(layout.props, { kind = "mailbox", x = doorX + 5, z = lot.z1 - 2, rot = 0 })
				table.insert(layout.props, { kind = "trashcan", x = hx - 20, z = lot.z1 - 3, rot = 0 })
			end
			-- utility poles on the back edge of the front sidewalk, wired together
			local P = cfg.Props
			local poleZ = frontZ - SW + 1.5
			local doors = {}
			for k = 0, H.PerRow - 1 do
				local lx0 = cell.x0 + SW + k * lotWidth
				local hx = (lx0 + lotWidth / 2) - (H.Width / 2 - H.Depth / 2)
				table.insert(doors, hx + H.Depth / 2 + H.StairwellWidth / 2)
			end
			local prevX: number? = nil
			local x = cell.x0 + SW + 6
			while x <= cell.x1 - SW - 6 do
				local px = x
				for _, dx in doors do
					if math.abs(px - dx) < 5 then
						px = dx + 5
					end
				end
				table.insert(layout.props, { kind = "utility_pole", x = px, z = poleZ, rot = 0 })
				if prevX then
					table.insert(layout.wires, { x0 = prevX, z0 = poleZ, x1 = px, z1 = poleZ, rot = 0 })
				end
				prevX = px
				x += P.PoleSpacing
			end
		end
		for _, corner in { { cell.x0 + 4, cell.z0 + 4 }, { cell.x1 - 4, cell.z0 + 4 }, { cell.x0 + 4, cell.z1 - 4 }, { cell.x1 - 4, cell.z1 - 4 } } do
			table.insert(layout.customerSpawns, { name = district, x = corner[1], z = corner[2] })
		end
	end

	local function docksDistrict(cell: Rect, district: string)
		sidewalkRing(cell)
		local interior = shrink(cell, SW)
		slab("concrete", interior, SIDEWALK_TOP, 1.5)
		local first = #layout.buildings + 1
		local dN = placeRow(interior, "N", district, interior.x0, interior.x1 - 120)
		local dS = placeRow(interior, "S", district, interior.x0, interior.x1 - 120)
		placeRow(interior, "W", district, interior.z0 + dN + 20, interior.z1 - dS - 20)
		if layout.buildings[first] then
			layout.buildings[first].sign = "SUPPLIER"
			table.insert(layout.pois, { name = "Supplier", x = layout.buildings[first].x, z = layout.buildings[first].z })
		end
		-- container yard
		for i = 0, 5 do
			for j = 0, 4 do
				if rng:next() < 0.75 then
					local x = interior.x0 + 120 + i * 50
					local z = interior.z0 + 110 + j * 60
					local stack = rng:int(1, 3)
					for s = 1, stack do
						table.insert(layout.props, { kind = "container", x = x, z = z, rot = 90, y = (s - 1) * 9 })
					end
				end
			end
		end
		local cz = (cell.z0 + cell.z1) / 2
		table.insert(layout.specials, { kind = "pier", x = ox + half + 45, z = cz, rot = 0, sx = 90, sz = 24 })
		table.insert(layout.pois, { name = "Pier", x = ox + half + 80, z = cz })
	end

	local function warZone(cell: Rect, district: string)
		local W = cfg.WarZone
		sidewalkRing(cell)
		local interior = shrink(cell, SW)
		slab("dirt", interior, SIDEWALK_TOP, 1.5)
		local w, h = interior.x1 - interior.x0, interior.z1 - interior.z0
		local function at(fx: number, fz: number): (number, number)
			return interior.x0 + fx * w, interior.z0 + fz * h
		end
		-- fence with two gates (north and west, facing the rest of the city)
		local gate = 30
		local mx, mz = (interior.x0 + interior.x1) / 2, (interior.z0 + interior.z1) / 2
		local fences = {
			{ interior.x0, interior.z0, mx - gate / 2, interior.z0 },
			{ mx + gate / 2, interior.z0, interior.x1, interior.z0 },
			{ interior.x0, interior.z1, interior.x1, interior.z1 },
			{ interior.x0, interior.z0, interior.x0, mz - gate / 2 },
			{ interior.x0, mz + gate / 2, interior.x0, interior.z1 },
			{ interior.x1, interior.z0, interior.x1, interior.z1 },
		}
		for _, f in fences do
			local len = math.max(math.abs(f[3] - f[1]), math.abs(f[4] - f[2]))
			local horizontal = math.abs(f[3] - f[1]) > math.abs(f[4] - f[2])
			table.insert(layout.specials, {
				kind = "fence",
				x = (f[1] + f[3]) / 2,
				z = (f[2] + f[4]) / 2,
				rot = if horizontal then 0 else 90,
				sx = len,
			})
		end
		local keepOut = {}
		for _, cp in W.ControlPoints do
			local x, z = at(cp.x, cp.z)
			table.insert(layout.specials, { kind = "control_point", x = x, z = z, rot = 0, label = cp.label })
			table.insert(keepOut, rect(x - 40, z - 40, x + 40, z + 40))
		end
		local rx, rz = at(W.RedSpawn.x, W.RedSpawn.z)
		local bx, bz = at(W.BlueSpawn.x, W.BlueSpawn.z)
		-- bunkers open towards the middle of the zone (red is north, blue is south)
		table.insert(layout.specials, { kind = "spawn_red", x = rx, z = rz, rot = 0 })
		table.insert(layout.specials, { kind = "spawn_blue", x = bx, z = bz, rot = 180 })
		table.insert(keepOut, rect(rx - 45, rz - 45, rx + 45, rz + 45))
		table.insert(keepOut, rect(bx - 45, bz - 45, bx + 45, bz + 45))
		table.insert(layout.pois, { name = "WarZone", x = mx, z = mz })

		local function free(r: Rect): boolean
			if r.x0 < interior.x0 + 6 or r.x1 > interior.x1 - 6 or r.z0 < interior.z0 + 6 or r.z1 > interior.z1 - 6 then
				return false
			end
			for _, k in keepOut do
				if CityLayout.Overlaps(r, k) then
					return false
				end
			end
			for _, b in layout.buildings do
				if CityLayout.Overlaps(r, b.footprint, -6) then
					return false
				end
			end
			return true
		end
		local ruins, tries = 0, 0
		local a = cfg.Archetypes.ruin
		while ruins < 8 and tries < 400 do
			tries += 1
			local x, z = rng:range(interior.x0, interior.x1), rng:range(interior.z0, interior.z1)
			local rot = rng:int(0, 3) * 90
			if free(CityLayout.Footprint(x, z, a.w, a.d, rot)) then
				addBuilding("ruin", x, z, rot, district, nil)
				ruins += 1
			end
		end
		local placed = 0
		tries = 0
		while placed < W.Cover and tries < W.Cover * 30 do
			tries += 1
			local x, z = rng:range(interior.x0, interior.x1), rng:range(interior.z0, interior.z1)
			local kind = if rng:next() < 0.45 then "container" else "barrier"
			local size = if kind == "container" then 20 else 8
			if free(rect(x - size / 2, z - size / 2, x + size / 2, z + size / 2)) then
				table.insert(layout.props, { kind = kind, x = x, z = z, rot = rng:int(0, 7) * 45 })
				table.insert(keepOut, rect(x - size / 2 - 3, z - size / 2 - 3, x + size / 2 + 3, z + size / 2 + 3))
				placed += 1
			end
		end
	end

	-- Avenues: vertical strips full length, horizontal strips between them (no overlaps) ---------
	for i = 0, N do
		local x0 = ox - half + i * (C + A)
		addRoad("avenue", rect(x0, oz - half, x0 + A, oz + half))
	end
	for j = 0, N do
		local z0 = oz - half + j * (C + A)
		for i = 0, N - 1 do
			local x0 = ox - half + A + i * (C + A)
			addRoad("avenue", rect(x0, z0, x0 + C, z0 + A))
		end
	end

	-- zebra crossings on the four sides of every avenue intersection
	for i = 0, N do
		for j = 0, N do
			local ix0 = ox - half + i * (C + A)
			local iz0 = oz - half + j * (C + A)
			local function zebra(x0: number, z0: number, x1: number, z1: number, alongX: boolean)
				if x0 < ox - half or x1 > ox + half or z0 < oz - half or z1 > oz + half then
					return
				end
				if alongX then -- stripes run along x, repeated across z
					local z = z0 + 2
					while z + 1.6 <= z1 - 2 do
						slab("paint", rect(x0, z, x1, z + 1.6), 0.03, 0.06)
						z += 3.4
					end
				else
					local x = x0 + 2
					while x + 1.6 <= x1 - 2 do
						slab("paint", rect(x, z0, x + 1.6, z1), 0.03, 0.06)
						x += 3.4
					end
				end
			end
			zebra(ix0 + A + 1, iz0, ix0 + A + 7, iz0 + A, true)
			zebra(ix0 - 7, iz0, ix0 - 1, iz0 + A, true)
			zebra(ix0, iz0 + A + 1, ix0 + A, iz0 + A + 7, false)
			zebra(ix0, iz0 - 7, ix0 + A, iz0 - 1, false)
		end
	end

	for row = 1, N do
		for col = 1, N do
			local district = cfg.Districts[row][col]
			local x0 = ox - half + A + (col - 1) * (C + A)
			local z0 = oz - half + A + (row - 1) * (C + A)
			local cell = rect(x0, z0, x0 + C, z0 + C)
			table.insert(layout.cells, { district = district, rect = cell })
			if district == "Blocks" then
				blocksDistrict(cell, district)
			elseif district == "Docks" then
				docksDistrict(cell, district)
			elseif district == "WarZone" then
				warZone(cell, district)
			else
				blockDistrict(cell, district)
			end
		end
	end

	-- Street furniture along every road ------------------------------------------------------------
	local P = cfg.Props
	local function onRoad(x: number, z: number): boolean
		for _, r in layout.roads do
			if CityLayout.Contains(r :: any, x, z) then
				return true
			end
		end
		return false
	end
	local function inside(x: number, z: number): boolean
		return math.abs(x - ox) < half - 1 and math.abs(z - oz) < half - 1
	end
	local function onWalkable(x: number, z: number): boolean
		-- a sidewalk/alley/plaza slab under the point
		for _, s in layout.slabs do
			if (s.kind == "sidewalk" or s.kind == "plaza" or s.kind == "alley") and x >= s.x0 and x <= s.x1 and z >= s.z0 and z <= s.z1 then
				return true
			end
		end
		return false
	end
	for _, r in layout.roads do
		local horizontal = r.x1 - r.x0 > r.z1 - r.z0
		local length = if horizontal then r.x1 - r.x0 else r.z1 - r.z0
		local n = math.floor((length - 30) / P.LampSpacing)
		for i = 0, n do
			local t = 15 + i * P.LampSpacing
			local sideA = i % 2 == 0
			local x, z, rot, carX, carZ, carRot
			if horizontal then
				x = r.x0 + t
				z = if sideA then r.z0 - 2.5 else r.z1 + 2.5
				rot = if sideA then 0 else 180
				carX, carZ, carRot = x + 8, if sideA then r.z0 + 4 else r.z1 - 4, 90
			else
				z = r.z0 + t
				x = if sideA then r.x0 - 2.5 else r.x1 + 2.5
				rot = if sideA then 90 else -90
				carX, carZ, carRot = if sideA then r.x0 + 4 else r.x1 - 4, z + 8, 0
			end
			if inside(x, z) and not onRoad(x, z) and onWalkable(x, z) then
				table.insert(layout.props, { kind = "lamp", x = x, z = z, rot = rot })
				if rng:next() < P.ParkedCarChance and CityLayout.Contains(r :: any, carX, carZ) then
					table.insert(layout.props, { kind = "car", x = carX, z = carZ, rot = carRot + (if rng:next() < 0.5 then 0 else 180) })
				end
			end
			-- small furniture between two lamps
			if rng:next() < 0.5 then
				local kinds = { "hydrant", "trashcan", "bench" }
				local kind = kinds[rng:int(1, 3)]
				local fx, fz = x, z
				if horizontal then
					fx = x + P.LampSpacing / 2
				else
					fz = z + P.LampSpacing / 2
				end
				if inside(fx, fz) and not onRoad(fx, fz) and onWalkable(fx, fz) then
					table.insert(layout.props, { kind = kind, x = fx, z = fz, rot = rot })
				end
			end
		end
	end

	-- Traffic lights on the four corners of every avenue intersection. The mast arm (local +Z) spans
	-- the approach road, the signal heads face the incoming traffic (local +X).
	if P.TrafficLights then
		for i = 0, N do
			for j = 0, N do
				local ix0 = ox - half + i * (C + A)
				local iz0 = oz - half + j * (C + A)
				local corners = {
					{ ix0 - 2, iz0 - 2, 90 }, -- NW corner, arm over the north road
					{ ix0 + A + 2, iz0 - 2, 0 }, -- NE, over the east road
					{ ix0 + A + 2, iz0 + A + 2, -90 }, -- SE, over the south road
					{ ix0 - 2, iz0 + A + 2, 180 }, -- SW, over the west road
				}
				for _, c in corners do
					if inside(c[1], c[2]) and not onRoad(c[1], c[2]) and onWalkable(c[1], c[2]) then
						table.insert(layout.props, { kind = "traffic_light", x = c[1], z = c[2], rot = c[3] })
					end
				end
			end
		end
	end

	-- Billboards on the roofs of low buildings
	for _, b in layout.buildings do
		local a = cfg.Archetypes[b.archetype]
		if P.BillboardDistricts[b.district] and (b.archetype == "shop" or b.archetype == "apartment" or b.archetype == "chinatown") then
			if rng:next() < P.BillboardChance then
				table.insert(layout.props, { kind = "billboard", x = b.x, z = b.z, rot = b.rot, y = a.h, ad = rng:int(1, #cfg.BillboardAds) })
			end
		end
	end

	-- Outside: ground ring (north, west, south) and the sea to the east -----------------------------
	local B = cfg.Boundary
	local outer = B.OuterGround
	slab("outer", rect(ox - half - outer, oz - half - outer, ox + half, oz - half), 0, 1)
	slab("outer", rect(ox - half - outer, oz + half, ox + half, oz + half + outer), 0, 1)
	slab("outer", rect(ox - half - outer, oz - half, ox - half, oz + half), 0, 1)
	table.insert(layout.specials, { kind = "sea", x = ox + half + B.SeaWidth / 2, z = oz, rot = 0, sx = B.SeaWidth, sz = 2 * (half + outer) })

	return layout
end

return CityLayout

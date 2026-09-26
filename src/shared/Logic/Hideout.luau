--!strict
-- A dealer's stash: the objects placed on their plot. Pure: wraps Grid validation + compact save format.
-- Coordinates are plot-local studs (plot center = 0,0; floor top = y 0). Objects rest on the floor,
-- so only x, z and the rotation are stored. Saved as strings "buildableId,x,z,rotation".

-- Roblox resolves the sibling through the instance tree, Lune through the file system.
local Grid = if script then require(script.Parent.Grid) else require("./Grid")

local Hideout = {}
Hideout.__index = Hideout

-- same shapes as Grid.Plot / Grid.Placed (redeclared: the conditional require hides Grid's types)
export type Plot = { sizeX: number, sizeZ: number, maxHeight: number }
type Placed = {
	id: string,
	x: number, y: number, z: number,
	sizeX: number, sizeY: number, sizeZ: number,
	rotation: number,
	solid: boolean?,
}

export type Object = {
	id: string, -- unique inside this stash for the session (not saved)
	buildableId: string,
	x: number,
	z: number,
	rotation: number,
}

export type Options = {
	gridSize: number,
	rotationStep: number,
	maxObjects: number,
}

export type Catalogue = { [string]: any } -- Config/Buildables .ById

export type Hideout = typeof(setmetatable(
	{} :: {
		_plot: Plot,
		_opts: Options,
		_catalogue: Catalogue,
		_objects: { Object },
		_nextId: number,
	},
	Hideout
))

local function isFiniteNumber(v: any): boolean
	return type(v) == "number" and v == v and v > -math.huge and v < math.huge
end

function Hideout.new(plot: Plot, opts: Options, catalogue: Catalogue): Hideout
	return setmetatable({
		_plot = plot,
		_opts = opts,
		_catalogue = catalogue,
		_objects = {},
		_nextId = 1,
	}, Hideout)
end

-- Grid representation of an object (y and sizes come from the catalogue).
function Hideout.ToPlaced(obj: Object, def: any): Placed
	return {
		id = obj.id,
		x = obj.x,
		y = def.size.y / 2,
		z = obj.z,
		sizeX = def.size.x,
		sizeY = def.size.y,
		sizeZ = def.size.z,
		rotation = obj.rotation,
		solid = def.solid ~= false,
	}
end

-- Snaps a wanted position so the object's corner lands on the grid (center only for 45° angles).
function Hideout.Snap(def: any, x: number, z: number, rotation: number, gridSize: number): (number, number)
	local rot = rotation % 360
	if rot % 90 ~= 0 then
		return Grid.Snap(x, gridSize), Grid.Snap(z, gridSize)
	end
	local sx, sz = def.size.x, def.size.z
	if rot % 180 == 90 then
		sx, sz = sz, sx
	end
	return Grid.Snap(x - sx / 2, gridSize) + sx / 2, Grid.Snap(z - sz / 2, gridSize) + sz / 2
end

function Hideout.GetObjects(self: Hideout): { Object }
	return table.clone(self._objects)
end

function Hideout.Count(self: Hideout): number
	return #self._objects
end

function Hideout.Get(self: Hideout, id: string): Object?
	for _, o in self._objects do
		if o.id == id then
			return o
		end
	end
	return nil
end

function Hideout.FindByRole(self: Hideout, role: string): { Object }
	local list = {}
	for _, o in self._objects do
		if self._catalogue[o.buildableId].role == role then
			table.insert(list, o)
		end
	end
	return list
end

function Hideout.SetMaxObjects(self: Hideout, maxObjects: number)
	self._opts = table.clone(self._opts)
	self._opts.maxObjects = maxObjects
end

-- Returns (ok, errorCode) without changing anything.
function Hideout.Validate(self: Hideout, buildableId: any, x: any, z: any, rotation: any, ignoreId: string?): (boolean, string?)
	if type(buildableId) ~= "string" then
		return false, "UnknownBuildable"
	end
	local def = self._catalogue[buildableId]
	if def == nil then
		return false, "UnknownBuildable"
	end
	if not (isFiniteNumber(x) and isFiniteNumber(z) and isFiniteNumber(rotation)) then
		return false, "InvalidNumber"
	end
	local candidate = Hideout.ToPlaced({ id = "?", buildableId = buildableId, x = x, z = z, rotation = rotation }, def)
	local existing = table.create(#self._objects)
	for _, o in self._objects do
		table.insert(existing, Hideout.ToPlaced(o, self._catalogue[o.buildableId]))
	end
	return Grid.ValidatePlacement(candidate, self._plot, existing, {
		gridSize = self._opts.gridSize,
		rotationStep = self._opts.rotationStep,
		maxObjects = self._opts.maxObjects,
		ignoreId = ignoreId,
	})
end

-- Returns (object, nil) or (nil, errorCode).
function Hideout.Place(self: Hideout, buildableId: any, x: any, z: any, rotation: any): (Object?, string?)
	local ok, err = self:Validate(buildableId, x, z, rotation, nil)
	if not ok then
		return nil, err
	end
	local obj: Object = {
		id = "o" .. self._nextId,
		buildableId = buildableId,
		x = x,
		z = z,
		rotation = rotation % 360,
	}
	self._nextId += 1
	table.insert(self._objects, obj)
	return obj, nil
end

function Hideout.Move(self: Hideout, id: any, x: any, z: any, rotation: any): (Object?, string?)
	local obj = if type(id) == "string" then self:Get(id) else nil
	if obj == nil then
		return nil, "UnknownObject"
	end
	local ok, err = self:Validate(obj.buildableId, x, z, rotation, obj.id)
	if not ok then
		return nil, err
	end
	obj.x, obj.z, obj.rotation = x, z, rotation % 360
	return obj, nil
end

function Hideout.Remove(self: Hideout, id: any): (Object?, string?)
	for i, o in self._objects do
		if o.id == id then
			table.remove(self._objects, i)
			return o, nil
		end
	end
	return nil, "UnknownObject"
end

-- Rebuilds a stash from objects that already have ids (the client mirrors the server's stash
-- to preview placements). No validation: the server stays the authority.
function Hideout.FromObjects(objects: { Object }, plot: Plot, opts: Options, catalogue: Catalogue): Hideout
	local h = Hideout.new(plot, opts, catalogue)
	for _, o in objects do
		if catalogue[o.buildableId] then
			table.insert(h._objects, table.clone(o))
		end
	end
	return h
end

-- Save format ---------------------------------------------------------------

local function fmt(n: number): string
	local r = math.floor(n * 100 + 0.5) / 100
	if r == math.floor(r) then
		return string.format("%d", r)
	end
	return tostring(r)
end

function Hideout.Encode(obj: Object): string
	return obj.buildableId .. "," .. fmt(obj.x) .. "," .. fmt(obj.z) .. "," .. fmt(obj.rotation)
end

-- Returns (buildableId, x, z, rotation) or nil.
function Hideout.Decode(s: any): (string?, number?, number?, number?)
	if type(s) ~= "string" then
		return nil
	end
	local id, xs, zs, rs = string.match(s, "^([%w_]+),([%-%d%.]+),([%-%d%.]+),([%-%d%.]+)$")
	if id == nil then
		return nil
	end
	local x, z, r = tonumber(xs), tonumber(zs), tonumber(rs)
	if x == nil or z == nil or r == nil then
		return nil
	end
	return id, x, z, r
end

function Hideout.Serialize(self: Hideout): { string }
	local list = table.create(#self._objects)
	for _, o in self._objects do
		table.insert(list, Hideout.Encode(o))
	end
	return list
end

-- Rebuilds a stash from saved strings. Invalid, unknown or colliding entries are dropped.
-- Returns (hideout, droppedCount).
function Hideout.Load(saved: any, plot: Plot, opts: Options, catalogue: Catalogue): (Hideout, number)
	local h = Hideout.new(plot, opts, catalogue)
	local dropped = 0
	if type(saved) ~= "table" then
		return h, 0
	end
	for _, s in ipairs(saved) do
		local id, x, z, r = Hideout.Decode(s)
		if id == nil or h:Place(id, x, z, r) == nil then
			dropped += 1
		end
	end
	return h, dropped
end

return Hideout

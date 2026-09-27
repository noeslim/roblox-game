--!strict
-- Cars (Logic/Vehicle, VehicleService, GARAGE button). Bought once with in-game cash, spawned next to
-- you (or in front of your trap house). One car out at a time. Speeds in studs per second (walk 13,
-- sprint 21). Models are procedural blocks; to use a real model, put it in
-- ReplicatedStorage.Assets.Vehicles.<id> (a Model with a VehicleSeat and a PrimaryPart, front = -Z).

export type Look = { body: string, cabin: string, glass: string, underglow: string? }
export type Vehicle = {
	id: string,
	name: string,
	price: number,
	level: number, -- dealer level needed to buy it
	maxSpeed: number,
	accel: number, -- studs/s gained per second
	brake: number,
	reverse: number, -- max speed backwards
	turn: number, -- degrees per second at cruising speed
	size: { x: number, y: number, z: number }, -- body width, height, length
	seats: number, -- passengers (the driver not counted)
	look: Look,
}

local Vehicles = {}

Vehicles.Settings = {
	RideHeight = 2.1, -- body center above the ground (curbs pass under it)
	HoverStiffness = 10, -- how fast it settles back to the ride height
	MaxFall = 80,
	Drag = 0.25, -- speed lost per second with no throttle (x speed)
	TurnFullAt = 0.35, -- turning is at full rate above this fraction of the max speed
	SpawnCooldown = 8,
	SpawnDistance = 9, -- beside you
	GarageOffset = 14, -- in front of your trap house door, towards the street
	MaxForce = 400, -- x mass
	-- players who own the best car for free: user ids (safest) or names, and the game's creator
	FreeFor = { "noeslim" } :: { any },
	FreeVehicle = "nightrider",
}

Vehicles.List = {
	{
		id = "beater", name = "Rusty Sedan", price = 1500, level = 1,
		maxSpeed = 45, accel = 14, brake = 40, reverse = 14, turn = 95, seats = 1,
		size = { x = 6, y = 1.6, z = 12 },
		look = { body = "#6B5B4B", cabin = "#5A4C40", glass = "#1C2228" },
	},
	{
		id = "hatch", name = "City Hatch", price = 4000, level = 3,
		maxSpeed = 55, accel = 20, brake = 50, reverse = 16, turn = 110, seats = 1,
		size = { x = 5.6, y = 1.6, z = 10 },
		look = { body = "#2E4A5C", cabin = "#24394A", glass = "#1C2228" },
	},
	{
		id = "muscle", name = "Street Muscle", price = 12000, level = 6,
		maxSpeed = 72, accel = 26, brake = 55, reverse = 18, turn = 100, seats = 1,
		size = { x = 6.4, y = 1.5, z = 13 },
		look = { body = "#7A1E1A", cabin = "#5C1612", glass = "#141418" },
	},
	{
		id = "suv", name = "Black SUV", price = 20000, level = 8,
		maxSpeed = 62, accel = 20, brake = 50, reverse = 18, turn = 90, seats = 3,
		size = { x = 7, y = 2.2, z = 14 },
		look = { body = "#15151A", cabin = "#1E1E24", glass = "#0C0C10" },
	},
	{
		id = "nightrider", name = "Night Rider", price = 60000, level = 12,
		maxSpeed = 110, accel = 40, brake = 75, reverse = 22, turn = 120, seats = 1,
		size = { x = 6.6, y = 1.3, z = 13 },
		look = { body = "#0E0E14", cabin = "#16161E", glass = "#10131A", underglow = "#B45CFF" },
	},
} :: { Vehicle }

Vehicles.ById = {} :: { [string]: Vehicle }
for _, v in Vehicles.List do
	Vehicles.ById[v.id] = v
end

return Vehicles

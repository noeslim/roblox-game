local Vehicle = require("../../src/shared/Logic/Vehicle")
local Vehicles = require("../../src/shared/Config/Vehicles")

local S = Vehicles.Settings
local car = Vehicles.ById.beater

local function drive(speed, throttle, steer, seconds)
	local yaw = 0
	for _ = 1, math.floor(seconds * 60) do
		speed, yaw = Vehicle.Step(speed, { throttle = throttle, steer = steer }, 1 / 60, car, S)
	end
	return speed, yaw
end

return function(t)
	t.test("full throttle reaches the top speed and not more", function()
		local s = drive(0, 1, 0, 30)
		t.near(s, car.maxSpeed, 1e-6)
	end)

	t.test("reverse is slower, braking stops the car before reversing", function()
		t.near(drive(0, -1, 0, 30), -car.reverse, 1e-6)
		local s = drive(car.maxSpeed, -1, 0, 0.5)
		t.truthy(s > 0 and s < car.maxSpeed)
	end)

	t.test("coasting slows down to a stop", function()
		t.eq(drive(20, 0, 0, 30), 0)
	end)

	t.test("no turning on the spot, full turn when moving, reversed backwards", function()
		local _, still = Vehicle.Step(0, { throttle = 0, steer = 1 }, 1 / 60, car, S)
		t.eq(still, 0)
		local _, fwd = Vehicle.Step(car.maxSpeed, { throttle = 1, steer = 1 }, 1 / 60, car, S)
		t.near(fwd, -math.rad(car.turn))
		local _, back = Vehicle.Step(-car.reverse, { throttle = -1, steer = 1 }, 1 / 60, car, S)
		t.truthy(back > 0)
	end)

	t.test("hover settles at the ride height and falls with no ground", function()
		t.truthy(Vehicle.Hover(0, 0, 0, 1 / 60, S) > 0) -- too low: goes up
		t.truthy(Vehicle.Hover(10, 0, 0, 1 / 60, S) < 0) -- too high: goes down
		t.near(Vehicle.Hover(S.RideHeight, 0, 0, 1 / 60, S), 0)
		t.truthy(Vehicle.Hover(10, 0, nil, 1 / 60, S) < 0)
	end)

	t.test("buying rules", function()
		t.eq(select(2, Vehicle.CanBuy({ "beater" }, car, 99, 1e9)), "AlreadyOwned")
		t.eq(select(2, Vehicle.CanBuy({}, Vehicles.ById.nightrider, 1, 1e9)), "LevelTooLow")
		t.eq(select(2, Vehicle.CanBuy({}, car, 1, 10)), "NotEnoughMoney")
		t.truthy(Vehicle.CanBuy({}, car, 1, car.price))
	end)

	t.test("the free car goes to the listed players and the creator", function()
		t.truthy(Vehicle.IsFreeFor(1, "NoeSlim", 0, { "noeslim" }))
		t.truthy(Vehicle.IsFreeFor(42, "someone", 0, { 42 }))
		t.truthy(Vehicle.IsFreeFor(7, "someone", 7, {}))
		t.falsy(Vehicle.IsFreeFor(8, "someone", 0, { "noeslim" }))
		t.falsy(Vehicle.IsFreeFor(8, "someone", 0, {}))
	end)

	t.test("the catalogue: the free car exists and is the fastest", function()
		local free = Vehicles.ById[S.FreeVehicle]
		t.truthy(free)
		for _, v in Vehicles.List do
			t.truthy(v.maxSpeed <= free.maxSpeed, v.id)
			t.truthy(v.price > 0 and v.level >= 1, v.id)
		end
	end)
end

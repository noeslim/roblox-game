--!strict
-- Arcade car handling and garage rules (Config/Vehicles). Pure: the client driving the car calls
-- Step every frame with the seat's throttle / steer; VehicleService checks purchases.

local Vehicle = {}

export type Stats = { maxSpeed: number, accel: number, brake: number, reverse: number, turn: number }
export type Input = { throttle: number, steer: number } -- -1..1 each (VehicleSeat.ThrottleFloat / SteerFloat)

-- New forward speed (studs/s, negative = backwards) and yaw rate (rad/s, positive = left).
function Vehicle.Step(speed: number, input: Input, dt: number, stats: Stats, settings: any): (number, number)
	local throttle = math.clamp(input.throttle, -1, 1)
	local s = speed
	if throttle > 0 then
		s += (if s < 0 then stats.brake else stats.accel) * throttle * dt
	elseif throttle < 0 then
		s += (if s > 0 then stats.brake else stats.accel) * throttle * dt
	else
		local drop = math.max(math.abs(s) * settings.Drag, 2) * dt
		s = if s > 0 then math.max(0, s - drop) else math.min(0, s + drop)
	end
	s = math.clamp(s, -stats.reverse, stats.maxSpeed)
	-- no turning on the spot; full turning rate once moving a bit; reversed steering backwards
	local grip = math.clamp(math.abs(s) / (stats.maxSpeed * settings.TurnFullAt), 0, 1)
	local yaw = -math.clamp(input.steer, -1, 1) * math.rad(stats.turn) * grip * (if s < 0 then -1 else 1)
	return s, yaw
end

-- Vertical speed that keeps the body at the ride height over the ground (groundY nil = falling).
function Vehicle.Hover(y: number, vy: number, groundY: number?, dt: number, settings: any): number
	if groundY == nil then
		return math.max(-settings.MaxFall, vy - 196.2 * dt)
	end
	local target = groundY + settings.RideHeight
	return math.clamp((target - y) * settings.HoverStiffness, -settings.MaxFall, 40)
end

-- Can this player buy this car? (ok, errorCode)
function Vehicle.CanBuy(owned: { string }, def: any, level: number, money: number): (boolean, string?)
	if table.find(owned, def.id) then
		return false, "AlreadyOwned"
	end
	if level < def.level then
		return false, "LevelTooLow"
	end
	if money < def.price then
		return false, "NotEnoughMoney"
	end
	return true, nil
end

-- True when the player gets the free car (listed by user id or name, or the game's creator).
function Vehicle.IsFreeFor(userId: number, name: string, creatorId: number, list: { any }): boolean
	if creatorId ~= 0 and userId == creatorId then
		return true
	end
	for _, entry in list do
		if entry == userId or (type(entry) == "string" and string.lower(entry) == string.lower(name)) then
			return true
		end
	end
	return false
end

return Vehicle

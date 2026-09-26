--!strict
-- Deterministic RNG with the same method names as Roblox's Random, for tests.
local Rng = {}
Rng.__index = Rng

function Rng.new(seed: number)
	return setmetatable({ _state = seed % 2147483647 }, Rng)
end

function Rng:_next(): number
	self._state = (self._state * 16807) % 2147483647
	return self._state / 2147483647
end

function Rng:NextNumber(min: number?, max: number?): number
	local lo, hi = min or 0, max or 1
	return lo + (hi - lo) * self:_next()
end

function Rng:NextInteger(min: number, max: number): number
	return min + math.floor(self:_next() * (max - min + 1))
end

-- Always returns the same value: handy to force outcomes.
function Rng.fixed(value: number)
	return {
		NextNumber = function(_, min: number?, max: number?)
			local lo, hi = min or 0, max or 1
			return lo + (hi - lo) * value
		end,
	}
end

return Rng

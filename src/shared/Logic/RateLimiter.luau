--!strict
-- Token bucket per key (usually a Player). Pure: time is injected.
-- Each key can do `capacity` calls in a burst, then `refillPerSecond` calls per second.

local RateLimiter = {}
RateLimiter.__index = RateLimiter

type Bucket = { tokens: number, at: number }

export type RateLimiter = typeof(setmetatable(
	{} :: {
		_capacity: number,
		_refill: number,
		_buckets: { [any]: Bucket },
	},
	RateLimiter
))

function RateLimiter.new(capacity: number, refillPerSecond: number): RateLimiter
	assert(capacity >= 1 and refillPerSecond > 0, "invalid rate limit")
	return setmetatable({
		_capacity = capacity,
		_refill = refillPerSecond,
		_buckets = {},
	}, RateLimiter)
end

function RateLimiter.Allow(self: RateLimiter, key: any, now: number): boolean
	local b = self._buckets[key]
	if b == nil then
		b = { tokens = self._capacity, at = now }
		self._buckets[key] = b
	else
		local elapsed = math.max(0, now - b.at)
		b.tokens = math.min(self._capacity, b.tokens + elapsed * self._refill)
		b.at = now
	end
	if b.tokens >= 1 then
		b.tokens -= 1
		return true
	end
	return false
end

function RateLimiter.Forget(self: RateLimiter, key: any)
	self._buckets[key] = nil
end

return RateLimiter

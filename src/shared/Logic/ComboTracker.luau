--!strict
-- Sale combo: chaining sales within a time window raises a multiplier. Time is injected.

local ComboTracker = {}
ComboTracker.__index = ComboTracker

export type ComboTracker = typeof(setmetatable(
	{} :: {
		_window: number,
		_step: number,
		_max: number,
		_count: number,
		_lastSaleAt: number?,
	},
	ComboTracker
))

function ComboTracker.new(comboConfig: { Window: number, StepPerSale: number, MaxMultiplier: number }): ComboTracker
	return setmetatable({
		_window = comboConfig.Window,
		_step = comboConfig.StepPerSale,
		_max = comboConfig.MaxMultiplier,
		_count = 0,
		_lastSaleAt = nil,
	}, ComboTracker)
end

function ComboTracker._multiplierFor(self: ComboTracker, count: number): number
	-- first sale = x1, each chained sale adds a step
	local m = 1 + math.max(0, count - 1) * self._step
	m = math.min(m, self._max)
	return math.floor(m * 100 + 0.5) / 100
end

-- Registers a sale at time `now`, returns (multiplier, comboCount)
function ComboTracker.RegisterSale(self: ComboTracker, now: number): (number, number)
	local last = self._lastSaleAt
	if last ~= nil and now - last <= self._window then
		self._count += 1
	else
		self._count = 1
	end
	self._lastSaleAt = now
	return self:_multiplierFor(self._count), self._count
end

function ComboTracker.GetMultiplier(self: ComboTracker, now: number): number
	local last = self._lastSaleAt
	if last == nil or now - last > self._window then
		return 1
	end
	return self:_multiplierFor(self._count)
end

function ComboTracker.Reset(self: ComboTracker)
	self._count = 0
	self._lastSaleAt = nil
end

return ComboTracker

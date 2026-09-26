--!strict
-- Waiting line in front of a counter. Position 1 is the customer being served.

local CustomerQueue = {}
CustomerQueue.__index = CustomerQueue

export type CustomerQueue = typeof(setmetatable(
	{} :: {
		_max: number,
		_ids: { string },
	},
	CustomerQueue
))

function CustomerQueue.new(maxSize: number): CustomerQueue
	return setmetatable({ _max = maxSize, _ids = {} }, CustomerQueue)
end

-- Returns the position (1 = front) or nil when the queue is full / id already queued.
function CustomerQueue.Join(self: CustomerQueue, id: string): number?
	if #self._ids >= self._max or table.find(self._ids, id) then
		return nil
	end
	table.insert(self._ids, id)
	return #self._ids
end

function CustomerQueue.Leave(self: CustomerQueue, id: string): boolean
	local i = table.find(self._ids, id)
	if i == nil then
		return false
	end
	table.remove(self._ids, i)
	return true
end

function CustomerQueue.PositionOf(self: CustomerQueue, id: string): number?
	return table.find(self._ids, id)
end

function CustomerQueue.Front(self: CustomerQueue): string?
	return self._ids[1]
end

function CustomerQueue.Size(self: CustomerQueue): number
	return #self._ids
end

function CustomerQueue.IsFull(self: CustomerQueue): boolean
	return #self._ids >= self._max
end

function CustomerQueue.GetAll(self: CustomerQueue): { string }
	return table.clone(self._ids)
end

return CustomerQueue

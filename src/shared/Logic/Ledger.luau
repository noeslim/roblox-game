--!strict
-- Money ledger for one player. Pure: no Roblox APIs. The server owns one Ledger per player.
-- Money is always a whole number of dollars.

local Ledger = {}
Ledger.__index = Ledger

export type Entry = { amount: number, reason: string }

export type Ledger = typeof(setmetatable(
	{} :: {
		_balance: number,
		_max: number,
		_history: { Entry },
		_historySize: number,
		_onChanged: ((balance: number) -> ())?,
	},
	Ledger
))

local HISTORY_SIZE = 50

local function isValidAmount(amount: any): boolean
	return type(amount) == "number"
		and amount == amount -- not NaN
		and amount > 0
		and amount < math.huge
		and math.floor(amount) == amount
end

function Ledger.new(startingBalance: number?, maxBalance: number?): Ledger
	local start = startingBalance or 0
	assert(start == 0 or isValidAmount(start), "invalid starting balance")
	local self = setmetatable({
		_balance = start,
		_max = maxBalance or math.huge,
		_history = {},
		_historySize = HISTORY_SIZE,
		_onChanged = nil,
	}, Ledger)
	return self
end

function Ledger.GetBalance(self: Ledger): number
	return self._balance
end

function Ledger.CanAfford(self: Ledger, amount: number): boolean
	return isValidAmount(amount) and self._balance >= amount
end

-- Called with the new balance after every change (the server uses it to write the save and the HUD).
function Ledger.SetChangedCallback(self: Ledger, callback: ((balance: number) -> ())?)
	self._onChanged = callback
end

function Ledger._record(self: Ledger, amount: number, reason: string)
	if self._onChanged then
		self._onChanged(self._balance)
	end
	table.insert(self._history, { amount = amount, reason = reason })
	if #self._history > self._historySize then
		table.remove(self._history, 1)
	end
end

-- Returns (ok, errorCode). Deposits are capped at the max balance.
function Ledger.Deposit(self: Ledger, amount: number, reason: string): (boolean, string?)
	if not isValidAmount(amount) then
		return false, "InvalidAmount"
	end
	local newBalance = math.min(self._balance + amount, self._max)
	local credited = newBalance - self._balance
	self._balance = newBalance
	self:_record(credited, reason)
	return true, nil
end

function Ledger.Withdraw(self: Ledger, amount: number, reason: string): (boolean, string?)
	if not isValidAmount(amount) then
		return false, "InvalidAmount"
	end
	if self._balance < amount then
		return false, "InsufficientFunds"
	end
	self._balance -= amount
	self:_record(-amount, reason)
	return true, nil
end

-- Takes up to `amount` (used for fines): never goes negative. Returns what was actually taken.
function Ledger.TakeUpTo(self: Ledger, amount: number, reason: string): number
	if not isValidAmount(amount) then
		return 0
	end
	local taken = math.min(amount, self._balance)
	if taken > 0 then
		self._balance -= taken
		self:_record(-taken, reason)
	end
	return taken
end

-- Atomic transfer between two ledgers (player-to-player sales).
function Ledger.Transfer(from: Ledger, to: Ledger, amount: number, reason: string): (boolean, string?)
	if not isValidAmount(amount) then
		return false, "InvalidAmount"
	end
	if from._balance < amount then
		return false, "InsufficientFunds"
	end
	if to._balance + amount > to._max then
		return false, "RecipientFull"
	end
	from._balance -= amount
	to._balance += amount
	from:_record(-amount, reason)
	to:_record(amount, reason)
	return true, nil
end

function Ledger.GetHistory(self: Ledger): { Entry }
	return table.clone(self._history)
end

function Ledger.Serialize(self: Ledger): number
	return self._balance
end

return Ledger

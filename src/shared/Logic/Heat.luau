--!strict
-- Heat gauge of a stash and raid resolution. Pure: time and randomness are injected.

local Heat = {}

export type HeatState = {
	value: number,
	lastRaidAt: number?,
}

export type StashItem = {
	id: string,
	value: number,
	contraband: boolean,
	hidden: boolean, -- stored inside a secret compartment
	hiddenLevel: number?, -- level of that compartment (1..5)
}

export type RaidResult = {
	seized: { StashItem },
	seizedValue: number,
	fine: number,
}

-- rng must expose NextNumber(min, max) like Roblox's Random
export type Rng = { NextNumber: (self: any, min: number, max: number) -> number }

export type TickContext = {
	isNight: boolean,
	visibleContraband: number,
}

function Heat.new(): HeatState
	return { value = 0, lastRaidAt = nil }
end

local function clamp(state: HeatState, cfg: any)
	state.value = math.clamp(state.value, 0, cfg.Max)
end

-- reason must be a key of cfg.Gains
function Heat.Add(state: HeatState, reason: string, cfg: any, count: number?)
	local gain = cfg.Gains[reason]
	assert(gain ~= nil, "unknown heat reason " .. tostring(reason))
	state.value += gain * (count or 1)
	clamp(state, cfg)
end

-- Called periodically by the server with the elapsed time dt (seconds).
function Heat.Tick(state: HeatState, dt: number, ctx: TickContext, cfg: any)
	if dt <= 0 then
		return
	end
	-- a huge stock is not hotter than cfg.MaxVisibleCounted things lying around
	local visible = math.min(ctx.visibleContraband, cfg.MaxVisibleCounted or math.huge)
	local gain = cfg.Gains.VisibleContraband * visible * dt

	local decay = cfg.DecayPerSecond * dt
	if ctx.isNight then
		decay *= cfg.NightDecayMultiplier
	end
	if ctx.visibleContraband == 0 then
		decay *= cfg.CleanDecayMultiplier
	end

	state.value += gain - decay
	clamp(state, cfg)
end

export type Level = "Clear" | "Patrol" | "Investigation" | "Raid"

function Heat.GetLevel(state: HeatState, cfg: any): Level
	local t = cfg.Thresholds
	if state.value >= t.Raid then
		return "Raid"
	elseif state.value >= t.Investigation then
		return "Investigation"
	elseif state.value >= t.Patrol then
		return "Patrol"
	end
	return "Clear"
end

function Heat.CanRaid(state: HeatState, now: number, playerLevel: number, cfg: any): (boolean, string?)
	if playerLevel < cfg.ProtectedBelowLevel then
		return false, "NewPlayerProtection"
	end
	if state.lastRaidAt ~= nil and now - state.lastRaidAt < cfg.RaidCooldown then
		return false, "Cooldown"
	end
	if Heat.GetLevel(state, cfg) ~= "Raid" then
		return false, "NotHotEnough"
	end
	return true, nil
end

-- Resolves a raid. Only contraband can be seized. Visible contraband is always found;
-- hidden contraband is found with a chance depending on its compartment level.
function Heat.ResolveRaid(state: HeatState, items: { StashItem }, rng: Rng, now: number, cfg: any): RaidResult
	local seized = {}
	local seizedValue = 0
	local chances = cfg.HiddenFindChance

	for _, item in items do
		if item.contraband then
			local found: boolean
			if not item.hidden then
				found = true
			else
				local level = math.clamp(item.hiddenLevel or 1, 1, #chances)
				found = rng:NextNumber(0, 1) < chances[level]
			end
			if found then
				table.insert(seized, item)
				seizedValue += item.value
			end
		end
	end

	state.lastRaidAt = now
	state.value = cfg.HeatAfterRaid

	return {
		seized = seized,
		seizedValue = seizedValue,
		fine = math.floor(seizedValue * cfg.FineRate),
	}
end

return Heat

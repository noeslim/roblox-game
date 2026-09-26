--!strict
-- Dealer level and XP. Pure.

local Progression = {}

export type ProgressionConfig = { XpBase: number, XpGrowth: number }

-- XP needed to go from `level` to `level + 1`.
function Progression.XpToNext(level: number, cfg: ProgressionConfig): number
	return math.floor(cfg.XpBase * cfg.XpGrowth ^ (level - 1) + 0.5)
end

-- Returns (newLevel, newXp, levelsGained). XP is kept at 0 once maxLevel is reached.
function Progression.AddXp(level: number, xp: number, amount: number, cfg: ProgressionConfig, maxLevel: number): (number, number, number)
	if amount <= 0 or level >= maxLevel then
		return level, if level >= maxLevel then 0 else xp, 0
	end
	local gained = 0
	xp += math.floor(amount)
	while level < maxLevel do
		local need = Progression.XpToNext(level, cfg)
		if xp < need then
			break
		end
		xp -= need
		level += 1
		gained += 1
	end
	if level >= maxLevel then
		xp = 0
	end
	return level, xp, gained
end

return Progression

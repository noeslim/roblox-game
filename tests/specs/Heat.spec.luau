local Heat = require("../../src/shared/Logic/Heat")
local Economy = require("../../src/shared/Config/Economy")
local Rng = require("../helpers/Rng")

local cfg = Economy.Heat

return function(t)
	t.test("gains clamp to max", function()
		local s = Heat.new()
		Heat.Add(s, "ContrabandSale", cfg, 100)
		t.eq(s.value, cfg.Max)
	end)

	t.test("unknown reason throws", function()
		t.throws(function()
			Heat.Add(Heat.new(), "Nope", cfg)
		end)
	end)

	t.test("levels follow thresholds", function()
		local s = Heat.new()
		t.eq(Heat.GetLevel(s, cfg), "Clear")
		s.value = 30
		t.eq(Heat.GetLevel(s, cfg), "Patrol")
		s.value = 60
		t.eq(Heat.GetLevel(s, cfg), "Investigation")
		s.value = 85
		t.eq(Heat.GetLevel(s, cfg), "Raid")
	end)

	t.test("clean stash cools down faster, night slower", function()
		local clean, dirty, night = Heat.new(), Heat.new(), Heat.new()
		clean.value, dirty.value, night.value = 50, 50, 50
		Heat.Tick(clean, 10, { isNight = false, visibleContraband = 0 }, cfg)
		Heat.Tick(night, 10, { isNight = true, visibleContraband = 0 }, cfg)
		Heat.Tick(dirty, 10, { isNight = false, visibleContraband = 3 }, cfg)
		t.near(clean.value, 50 - cfg.DecayPerSecond * 10 * cfg.CleanDecayMultiplier)
		t.near(night.value, 50 - cfg.DecayPerSecond * 10 * cfg.CleanDecayMultiplier * cfg.NightDecayMultiplier)
		t.near(dirty.value, 50 + cfg.Gains.VisibleContraband * 3 * 10 - cfg.DecayPerSecond * 10)
	end)

	t.test("a huge visible stock heats like MaxVisibleCounted items", function()
		local a, b = Heat.new(), Heat.new()
		Heat.Tick(a, 10, { isNight = false, visibleContraband = cfg.MaxVisibleCounted }, cfg)
		Heat.Tick(b, 10, { isNight = false, visibleContraband = 500 }, cfg)
		t.near(a.value, b.value)
	end)

	t.test("raid rules: protection, heat, cooldown", function()
		local s = Heat.new()
		s.value = 90
		t.eq(select(2, Heat.CanRaid(s, 0, 2, cfg)), "NewPlayerProtection")
		t.truthy(Heat.CanRaid(s, 0, 10, cfg))
		s.value = 50
		t.eq(select(2, Heat.CanRaid(s, 0, 10, cfg)), "NotHotEnough")
		s.value = 90
		s.lastRaidAt = 100
		t.eq(select(2, Heat.CanRaid(s, 300, 10, cfg)), "Cooldown")
		t.truthy(Heat.CanRaid(s, 100 + cfg.RaidCooldown, 10, cfg))
	end)

	t.test("raid seizes visible contraband only, never legal items", function()
		local s = Heat.new()
		s.value = 95
		local items = {
			{ id = "a", value = 100, contraband = true, hidden = false },
			{ id = "b", value = 200, contraband = false, hidden = false },
			{ id = "c", value = 300, contraband = true, hidden = true, hiddenLevel = 5 },
		}
		-- rng returns 0.99: hidden item never found
		local r = Heat.ResolveRaid(s, items, Rng.fixed(0.99), 1000, cfg)
		t.eq(#r.seized, 1)
		t.eq(r.seized[1].id, "a")
		t.eq(r.seizedValue, 100)
		t.eq(r.fine, 25)
		t.eq(s.value, cfg.HeatAfterRaid)
		t.eq(s.lastRaidAt, 1000)
	end)

	t.test("hidden items are found with the level's chance", function()
		local items = { { id = "c", value = 300, contraband = true, hidden = true, hiddenLevel = 1 } }
		local r = Heat.ResolveRaid(Heat.new(), items, Rng.fixed(0.1), 0, cfg)
		t.eq(#r.seized, 1) -- 0.1 < 0.5
		r = Heat.ResolveRaid(Heat.new(), items, Rng.fixed(0.6), 0, cfg)
		t.eq(#r.seized, 0)
	end)

	t.test("higher compartment level hides better over many raids", function()
		local rng = Rng.new(42)
		local function foundRate(level)
			local found = 0
			for _ = 1, 2000 do
				local r = Heat.ResolveRaid(Heat.new(), { { id = "x", value = 1, contraband = true, hidden = true, hiddenLevel = level } }, rng, 0, cfg)
				found += #r.seized
			end
			return found / 2000
		end
		local low, high = foundRate(1), foundRate(5)
		t.near(low, 0.5, 0.05)
		t.near(high, 0.02, 0.02)
	end)
end

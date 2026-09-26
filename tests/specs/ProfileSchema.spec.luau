local ProfileSchema = require("../../src/shared/Logic/ProfileSchema")
local Economy = require("../../src/shared/Config/Economy")
local Parts = require("../../src/shared/Config/Parts")

local cfg = ProfileSchema.ConfigFrom(Economy, Parts)

return function(t)
	t.test("template is a valid, current profile", function()
		local d = ProfileSchema.Template(cfg)
		t.eq(d.Version, ProfileSchema.VERSION)
		t.eq(d.Money, Economy.StartingMoney)
		t.eq(d.Level, 1)
		t.eq(d.Parts.street_body, 1)
		t.eq(#d.Weapons, 0)
		t.truthy(ProfileSchema.Prepare(d, cfg))
		t.eq(d.Money, Economy.StartingMoney)
	end)

	t.test("template does not share tables with the config", function()
		local d = ProfileSchema.Template(cfg)
		d.Parts.street_body = 50
		t.eq(Economy.Profile.StarterParts.street_body, 1)
	end)

	t.test("every starter part exists in the catalogue", function()
		for id in Economy.Profile.StarterParts do
			t.truthy(Parts[id], id)
		end
	end)

	t.test("every version below the current one has a migration", function()
		for v = 0, ProfileSchema.VERSION - 1 do
			t.truthy(ProfileSchema.Migrations[v], "missing migration from v" .. v)
		end
	end)

	t.test("unversioned (v0) profile is upgraded and filled", function()
		local d: any = { Money = 1234 }
		local ok, err = ProfileSchema.Prepare(d, cfg)
		t.truthy(ok, err)
		t.eq(d.Version, ProfileSchema.VERSION)
		t.eq(d.Money, 1234)
		t.eq(d.Level, 1)
		t.eq(d.Parts.street_body, 1, "missing inventory gets the starter parts")
		t.eq(type(d.Hideout.Objects), "table")
	end)

	t.test("migrations run in order up to the target", function()
		local calls = {}
		local migrations = {
			[1] = function(d)
				table.insert(calls, 1)
				d.Cash = nil
				d.Money = d.OldMoney * 10
			end,
			[2] = function(d)
				table.insert(calls, 2)
				d.Renamed = true
			end,
		}
		local d: any = { Version = 1, OldMoney = 7 }
		local ok = ProfileSchema.Migrate(d, cfg, migrations, 3)
		t.truthy(ok)
		t.eq(d.Version, 3)
		t.eq(d.Money, 70)
		t.truthy(d.Renamed)
		t.eq(#calls, 2)
		t.eq(calls[1], 1)
		t.eq(calls[2], 2)
	end)

	t.test("missing migration is reported", function()
		local d: any = { Version = 1 }
		local ok, err = ProfileSchema.Migrate(d, cfg, {}, 2)
		t.falsy(ok)
		t.eq(err, "MissingMigration")
	end)

	t.test("profile from a newer server is refused and left untouched", function()
		local d: any = { Version = ProfileSchema.VERSION + 1, Money = -5, Parts = { fake = 3 } }
		local ok, err = ProfileSchema.Prepare(d, cfg)
		t.falsy(ok)
		t.eq(err, "FutureVersion")
		t.eq(d.Money, -5)
		t.eq(d.Parts.fake, 3)
	end)

	t.test("invalid version is refused", function()
		for _, v in { -1, 1.5, 0 / 0, "1" :: any } do
			local ok, err = ProfileSchema.Migrate({ Version = v }, cfg)
			t.falsy(ok, tostring(v))
			t.eq(err, "InvalidVersion")
		end
		t.eq(select(2, ProfileSchema.Migrate(nil, cfg)), "NotATable")
	end)

	t.test("money is clamped to a whole number in range", function()
		local cases = {
			{ -50, 0 },
			{ 12.7, 12 },
			{ 0 / 0, Economy.StartingMoney },
			{ math.huge, Economy.StartingMoney },
			{ "999" :: any, Economy.StartingMoney },
			{ Economy.MaxMoney * 10, Economy.MaxMoney },
		}
		for _, c in cases do
			local d = ProfileSchema.Sanitize({ Version = 1, Money = c[1] }, cfg)
			t.eq(d.Money, c[2], "money " .. tostring(c[1]))
		end
	end)

	t.test("level and xp are clamped", function()
		local d = ProfileSchema.Sanitize({ Level = 9999, Xp = -3 }, cfg)
		t.eq(d.Level, Economy.Profile.MaxLevel)
		t.eq(d.Xp, 0)
		t.eq(ProfileSchema.Sanitize({ Level = 0 }, cfg).Level, 1)
	end)

	t.test("unknown parts and bad counts are dropped, stacks capped", function()
		local d = ProfileSchema.Sanitize({
			Parts = {
				street_body = 3,
				neon_mag = 0,
				ghost_body = -2,
				removed_part = 5,
				gold_stock = 1e9,
				neon_sight = 2.9,
			},
		}, cfg)
		t.eq(d.Parts.street_body, 3)
		t.eq(d.Parts.neon_mag, nil)
		t.eq(d.Parts.ghost_body, nil)
		t.eq(d.Parts.removed_part, nil)
		t.eq(d.Parts.gold_stock, Economy.Profile.MaxPartStack)
		t.eq(d.Parts.neon_sight, 2)
	end)

	t.test("an emptied inventory stays empty (no free starter parts)", function()
		local d = ProfileSchema.Sanitize({ Parts = {} }, cfg)
		t.eq(next(d.Parts), nil)
	end)

	t.test("invalid weapons are dropped, names truncated", function()
		local good = {
			id = "w1",
			name = string.rep("x", 100),
			parts = { Body = "street_body", Barrel = "neon_barrel" },
		}
		local d = ProfileSchema.Sanitize({
			Weapons = {
				good,
				{ id = "w2", parts = { Body = "street_barrel" } }, -- part in the wrong slot
				{ id = "w3", parts = { Body = "deleted_part" } },
				{ parts = {} }, -- no id
				"junk",
			},
		}, cfg)
		t.eq(#d.Weapons, 1)
		t.eq(d.Weapons[1].id, "w1")
		t.eq(#(d.Weapons[1].name :: string), Economy.Profile.MaxWeaponNameLength)
		t.eq(d.Weapons[1].parts.Barrel, "neon_barrel")
	end)

	t.test("weapon count is capped", function()
		local list = {}
		for i = 1, Economy.Profile.MaxWeapons + 10 do
			list[i] = { id = "w" .. i, parts = { Body = "street_body" } }
		end
		local d = ProfileSchema.Sanitize({ Weapons = list }, cfg)
		t.eq(#d.Weapons, Economy.Profile.MaxWeapons)
	end)

	t.test("broken hideout is reset", function()
		t.eq(type(ProfileSchema.Sanitize({ Hideout = "x" }, cfg).Hideout.Objects), "table")
		t.eq(type(ProfileSchema.Sanitize({ Hideout = {} }, cfg).Hideout.Objects), "table")
		local kept = ProfileSchema.Sanitize({ Hideout = { Objects = { "rug,0,0,0", { id = "junk" }, 5 } } }, cfg)
		t.eq(#kept.Hideout.Objects, 1)
		t.eq(kept.Hideout.Objects[1], "rug,0,0,0")
	end)

	t.test("sanitize works in place (ProfileStore keeps the same table)", function()
		local d: any = { Money = 10 }
		local out = ProfileSchema.Sanitize(d, cfg)
		t.eq(out, d)
	end)

	t.test("v1 profile gets the starter stash and keeps its data", function()
		local d: any = { Version = 1, Money = 900, Hideout = { Objects = {} }, Weapons = {} }
		t.truthy(ProfileSchema.Prepare(d, cfg))
		t.eq(d.Version, 2)
		t.eq(d.Money, 900)
		t.eq(#d.Hideout.Objects, #Economy.Profile.StarterHideout)
		t.eq(d.Stats.Crafted, 0)
	end)

	t.test("v1 migration never overwrites an existing stash", function()
		local d: any = { Version = 1, Hideout = { Objects = { "rug,0,0,0" } } }
		t.truthy(ProfileSchema.Prepare(d, cfg))
		t.eq(#d.Hideout.Objects, 1)
	end)

	t.test("weapon price is kept when valid", function()
		local d = ProfileSchema.Sanitize({
			Weapons = {
				{ id = "a", parts = { Body = "street_body" }, price = 250 },
				{ id = "b", parts = { Body = "street_body" }, price = -3 },
				{ id = "c", parts = { Body = "street_body" }, price = 0 / 0 },
			},
		}, cfg)
		t.eq(d.Weapons[1].price, 250)
		t.eq(d.Weapons[2].price, nil)
		t.eq(d.Weapons[3].price, nil)
	end)

	t.test("stats are sanitized", function()
		local d = ProfileSchema.Sanitize({ Stats = { Crafted = -1, Sold = 3.7, Earned = "x" } }, cfg)
		t.eq(d.Stats.Crafted, 0)
		t.eq(d.Stats.Sold, 3)
		t.eq(d.Stats.Earned, 0)
	end)
end

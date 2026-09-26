local Contracts = require("../../src/shared/Logic/Contracts")
local Economy = require("../../src/shared/Config/Economy")

local cfg = Economy.Contracts

return function(t)
	t.test("daily roll is distinct and stable", function()
		local a = Contracts.Roll(20000, 12345, cfg)
		local b = Contracts.Roll(20000, 12345, cfg)
		t.eq(#a, cfg.PerDay)
		local seen = {}
		for i, e in a do
			t.eq(e.id, b[i].id)
			t.falsy(seen[e.id])
			seen[e.id] = true
			t.truthy(Contracts.Find(cfg, e.id))
		end
	end)

	t.test("different days or players get different contracts", function()
		local function key(list)
			local ids = {}
			for _, e in list do
				table.insert(ids, e.id)
			end
			return table.concat(ids, ",")
		end
		local differ = 0
		for day = 1, 20 do
			if key(Contracts.Roll(day, 1, cfg)) ~= key(Contracts.Roll(day + 1, 1, cfg)) then
				differ += 1
			end
		end
		t.truthy(differ >= 15)
		t.truthy(key(Contracts.Roll(5, 1, cfg)) ~= key(Contracts.Roll(5, 999, cfg)) or key(Contracts.Roll(6, 1, cfg)) ~= key(Contracts.Roll(6, 999, cfg)))
	end)

	t.test("ensure rerolls only when the day changes", function()
		local s = { Day = 0, List = {} }
		t.truthy(Contracts.Ensure(s, 7, 1, cfg))
		s.List[1].progress = 1
		t.falsy(Contracts.Ensure(s, 7, 1, cfg))
		t.eq(s.List[1].progress, 1)
		t.truthy(Contracts.Ensure(s, 8, 1, cfg))
		t.eq(s.List[1].progress, 0)
	end)

	local small = {
		PerDay = 2,
		AllDoneBonus = 100,
		Pool = {
			{ id = "a", event = "sale", target = 2, reward = 10, xp = 1, text = "" },
			{ id = "b", event = "combo", target = 3, reward = 20, xp = 2, mode = "max", text = "" },
		},
	}

	t.test("events progress, complete once, and all done fires once", function()
		local s = { Day = 1, List = { { id = "a", progress = 0, done = false }, { id = "b", progress = 0, done = false } } }
		local done, all = Contracts.Record(s, "sale", 1, small)
		t.eq(#done, 0)
		t.falsy(all)
		done, all = Contracts.Record(s, "sale", 5, small)
		t.eq(#done, 1)
		t.eq(s.List[1].progress, 2)
		t.falsy(all)
		done = Contracts.Record(s, "sale", 1, small)
		t.eq(#done, 0)
		Contracts.Record(s, "combo", 2, small)
		t.eq(s.List[2].progress, 2)
		Contracts.Record(s, "combo", 1, small)
		t.eq(s.List[2].progress, 2) -- "max": a lower streak does not count
		done, all = Contracts.Record(s, "combo", 3, small)
		t.eq(#done, 1)
		t.truthy(all)
		local _, again = Contracts.Record(s, "combo", 4, small)
		t.falsy(again)
	end)
end

local Mission = require("../../src/shared/Logic/Mission")
local Missions = require("../../src/shared/Config/Missions")
local Economy = require("../../src/shared/Config/Economy")

local ORDER = Economy.RarityOrder

local def = {
	id = "t",
	title = "Test",
	timeLimit = 100,
	failOn = { "customerLost" },
	steps = {
		{ kind = "goto", target = "poi:Supplier", text = "go" },
		{ kind = "event", event = "sale", count = 2, filter = { night = true }, text = "sell" },
		{ kind = "stay", target = "home", seconds = 10, text = "stay" },
	},
	reward = { money = 1, xp = 1 },
}

return function(t)
	t.test("every job in the config is valid", function()
		for _, job in Missions.Jobs do
			t.eq(Mission.Validate(job, ORDER), nil, job.id)
		end
	end)

	t.test("a mission walks through its steps", function()
		local s = Mission.Start(def, 0)
		t.falsy(Mission.Update(s, def, 1, 1, false))
		t.truthy(Mission.Update(s, def, 2, 1, true))
		t.eq(s.step, 2)
		t.falsy(Mission.Record(s, def, "sale", 1, { night = false }, ORDER)) -- by day: does not count
		t.truthy(Mission.Record(s, def, "sale", 1, { night = true }, ORDER))
		t.eq(s.progress, 1)
		Mission.Record(s, def, "sale", 1, { night = true }, ORDER)
		t.eq(s.step, 3)
		for i = 1, 9 do
			Mission.Update(s, def, 10 + i, 1, true)
		end
		t.eq(s.status, "active")
		Mission.Update(s, def, 20, 1, false) -- stepping out does not count
		t.eq(s.status, "active")
		Mission.Update(s, def, 21, 1, true)
		t.eq(s.status, "done")
	end)

	t.test("fail events and the time limit end it", function()
		local a = Mission.Start(def, 0)
		t.truthy(Mission.Record(a, def, "customerLost", 1, nil, ORDER))
		t.eq(a.status, "failed")
		t.eq(a.reason, "customerLost")
		t.falsy(Mission.Record(a, def, "sale", 1, { night = true }, ORDER)) -- over
		local b = Mission.Start(def, 0)
		Mission.Update(b, def, 100, 1, false)
		t.eq(b.status, "failed")
		t.eq(b.reason, "timeout")
	end)

	t.test("rarity filter: at least the rarity asked", function()
		local d = { id = "r", title = "R", steps = { { kind = "event", event = "craft", count = 1, filter = { minRarity = "Rare" }, text = "x" } }, reward = { money = 0, xp = 0 } }
		local s = Mission.Start(d, 0)
		t.falsy(Mission.Record(s, d, "craft", 1, { rarity = ORDER[1] }, ORDER))
		t.truthy(Mission.Record(s, d, "craft", 1, { rarity = ORDER[#ORDER] }, ORDER))
		t.eq(s.status, "done")
	end)

	t.test("describe shows the current step, progress, time left and target", function()
		local s = Mission.Start(def, 0)
		local v = Mission.Describe(s, def, 30)
		t.eq(v.text, "go")
		t.eq(v.target, "poi:Supplier")
		t.eq(v.timeLeft, 70)
		Mission.Update(s, def, 31, 1, true)
		v = Mission.Describe(s, def, 31)
		t.eq(v.goal, 2)
		t.eq(v.target, nil)
	end)

	t.test("broken definitions are caught", function()
		t.truthy(Mission.Validate({ id = "x", title = "X", steps = {}, reward = { money = 0, xp = 0 } }, ORDER))
		t.truthy(Mission.Validate({ id = "x", title = "X", steps = { { kind = "fly", text = "?" } }, reward = { money = 0, xp = 0 } }, ORDER))
		t.truthy(Mission.Validate({ id = "x", title = "X", steps = { { kind = "stay", target = "home", text = "?" } }, reward = { money = 0, xp = 0 } }, ORDER))
	end)
end

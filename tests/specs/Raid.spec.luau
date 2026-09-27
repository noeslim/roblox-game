local Raid = require("../../src/shared/Logic/Raid")
local Heat = require("../../src/shared/Logic/Heat")
local Economy = require("../../src/shared/Config/Economy")
local Rng = require("../helpers/Rng")

local catalogue = {
	ghost = { value = 90, contraband = true },
	scope = { value = 65, contraband = true },
	grip = { value = 20 },
}

local function weapons()
	return {
		{ id = "a", value = 500, contraband = true },
		{ id = "b", value = 300, contraband = false },
		{ id = "c", value = 200, contraband = true, hidden = true },
	}
end

local function count(items, pred)
	local n = 0
	for _, i in items do
		if pred(i) then
			n += 1
		end
	end
	return n
end

return function(t)
	t.test("only contraband is listed, parts one unit per item", function()
		local items = Raid.Items(weapons(), { ghost = 2, grip = 5, scope = 1 }, { ghost = 1 }, catalogue)
		t.eq(#items, 2 + 2 + 1)
		t.eq(count(items, function(i)
			return i.hidden
		end), 2) -- weapon c + one ghost part
	end)

	t.test("hidden units never exceed the stack", function()
		local items = Raid.Items({}, { ghost = 1 }, { ghost = 9 }, catalogue)
		t.eq(#items, 1)
		t.truthy(items[1].hidden)
	end)

	t.test("no compartment: nothing stays hidden", function()
		local items = Raid.Allocate(Raid.Items(weapons(), {}, {}, catalogue), {})
		t.eq(count(items, function(i)
			return i.hidden
		end), 0)
	end)

	t.test("the most valuable hidden things go to the best compartment", function()
		local items = Raid.Items({
			{ id = "x", value = 900, contraband = true, hidden = true },
			{ id = "y", value = 100, contraband = true, hidden = true },
			{ id = "z", value = 50, contraband = true, hidden = true },
		}, {}, {}, catalogue)
		local out = Raid.Allocate(items, { { level = 1, capacity = 1 }, { level = 3, capacity = 1 } })
		local byRef = {}
		for _, i in out do
			byRef[i.ref] = i
		end
		t.eq(byRef.x.hiddenLevel, 3)
		t.eq(byRef.y.hiddenLevel, 1)
		t.falsy(byRef.z.hidden) -- no room left
	end)

	t.test("PickToHide fills the free room with the most valuable visible stuff", function()
		local items = Raid.Items(weapons(), { ghost = 3 }, {}, catalogue)
		local pick = Raid.PickToHide(items, { { level = 2, capacity = 3 } })
		t.eq(#pick, 2) -- weapon c already takes one place
		t.eq(pick[1].ref, "a")
		t.eq(pick[2].ref, "ghost")
		t.eq(Raid.CountVisible(items, { { level = 2, capacity = 3 } }), 4)
	end)

	t.test("a raid seizes visible stuff, hidden stuff survives a lucky search", function()
		local items = Raid.Allocate(Raid.Items(weapons(), { ghost = 1 }, {}, catalogue), { { level = 1, capacity = 1 } })
		local state = Heat.new()
		local result = Heat.ResolveRaid(state, items, Rng.fixed(0.99), 100, Economy.Heat)
		local w, p = Raid.Group(result.seized)
		t.truthy(w.a)
		t.falsy(w.c) -- hidden, and the search missed it
		t.eq(p.ghost, 1)
		t.eq(result.seizedValue, 500 + 90)
		t.eq(result.fine, math.floor(590 * Economy.Heat.FineRate))
	end)

	t.test("a failed hiding spot: the hidden units seized are counted apart", function()
		local items = Raid.Allocate(Raid.Items({}, { ghost = 3 }, { ghost = 2 }, catalogue), { { level = 5, capacity = 2 } })
		local result = Heat.ResolveRaid(Heat.new(), items, Rng.fixed(0), 100, Economy.Heat) -- the search finds everything
		local _, p, hp = Raid.Group(result.seized)
		t.eq(p.ghost, 3)
		t.eq(hp.ghost, 2)
	end)

	t.test("timeline: warning, search, done", function()
		local plan = Raid.Plan(Economy.Heat)
		t.eq(Raid.Phase(plan, 0), "Warning")
		t.eq(Raid.Phase(plan, Economy.Heat.RaidWarningSeconds + 0.1), "Search")
		t.eq(Raid.Phase(plan, plan.total), "Done")
	end)
end

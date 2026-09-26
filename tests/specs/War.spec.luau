local CapturePoint = require("../../src/shared/Logic/CapturePoint")
local WarRound = require("../../src/shared/Logic/WarRound")
local CityLayout = require("../../src/shared/Logic/CityLayout")
local City = require("../../src/shared/Config/City")

local cfg = { CaptureSeconds = 10, MaxCapturers = 3, RegenSeconds = 20, PointsPerSecond = 1, ScoreToWin = 100, RoundMaxSeconds = 300 }

return function(t)
	t.test("one player captures a neutral point in CaptureSeconds", function()
		local p = CapturePoint.new()
		local event
		for _ = 1, 9 do
			event = CapturePoint.Step(p, 1, 0, 1, cfg)
			t.falsy(event)
		end
		event = CapturePoint.Step(p, 1, 0, 1, cfg)
		t.eq(event, "captured")
		t.eq(p.owner, "Red")
	end)

	t.test("more players capture faster, capped", function()
		local p = CapturePoint.new()
		CapturePoint.Step(p, 10, 0, 1, cfg)
		t.near(p.progress, 0.3, 1e-9)
	end)

	t.test("contested points do not move", function()
		local p = { owner = nil, progress = 0.5 }
		t.falsy(CapturePoint.Step(p, 2, 1, 5, cfg))
		t.eq(p.progress, 0.5)
	end)

	t.test("taking an enemy point: neutralize first, then capture", function()
		local p = { owner = "Red", progress = 1 }
		local events = {}
		for _ = 1, 20 do
			local e = CapturePoint.Step(p, 0, 1, 1, cfg)
			if e then
				table.insert(events, e)
			end
		end
		t.eq(table.concat(events, ","), "neutralized,captured")
		t.eq(p.owner, "Blue")
	end)

	t.test("abandoned progress drifts back to the owner", function()
		local p = { owner = "Blue", progress = -0.4 }
		for _ = 1, 30 do
			CapturePoint.Step(p, 0, 0, 1, cfg)
		end
		t.eq(p.progress, -1)
		t.eq(p.owner, "Blue")
	end)

	t.test("owned points score; first to the target wins", function()
		local r = WarRound.new()
		for _ = 1, 49 do
			WarRound.Tick(r, { "Red", "Red", "Blue", nil, nil }, 1, cfg)
		end
		t.falsy(r.over)
		t.eq(r.scores.Red, 98)
		WarRound.Tick(r, { "Red", "Red", "Blue", nil, nil }, 1, cfg)
		t.truthy(r.over)
		t.eq(r.winner, "Red")
	end)

	t.test("time limit ends the round, ties have no winner", function()
		local r = WarRound.new()
		WarRound.Tick(r, { "Red", "Blue" }, 300, { PointsPerSecond = 0.1, ScoreToWin = 1000, RoundMaxSeconds = 300 })
		t.truthy(r.over)
		t.falsy(r.winner)
		t.eq(WarRound.TimeLeft(r, cfg), 0)
	end)

	t.test("new players join the smaller team", function()
		t.eq(WarRound.PickTeam(0, 0), "Red")
		t.eq(WarRound.PickTeam(3, 2), "Blue")
		t.eq(WarRound.PickTeam(2, 3), "Red")
	end)

	t.test("the layout describes the war zone", function()
		local zone = CityLayout.Build(City).warZone
		t.truthy(zone)
		t.eq(#zone.points, #City.WarZone.ControlPoints)
		for _, p in zone.points do
			t.truthy(CityLayout.Contains(zone.rect, p.x, p.z))
		end
		t.truthy(CityLayout.Contains(zone.rect, zone.red.x, zone.red.z))
		t.truthy(CityLayout.Contains(zone.rect, zone.blue.x, zone.blue.z))
	end)
end

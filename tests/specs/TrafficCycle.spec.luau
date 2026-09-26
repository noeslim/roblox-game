local TrafficCycle = require("../../src/shared/Logic/TrafficCycle")

local S = { GreenSeconds = 10, AmberSeconds = 3, AllRedSeconds = 2 }

return function(t)
	t.test("north-south starts green, east-west red", function()
		local ns, ew = TrafficCycle.State(0, S)
		t.eq(ns, "signal_green")
		t.eq(ew, "signal_red")
	end)

	t.test("amber then all red before the other axis", function()
		t.eq((TrafficCycle.State(11, S)), "signal_amber")
		local ns, ew = TrafficCycle.State(14, S)
		t.eq(ns, "signal_red")
		t.eq(ew, "signal_red")
		ns, ew = TrafficCycle.State(15, S)
		t.eq(ns, "signal_red")
		t.eq(ew, "signal_green")
	end)

	t.test("never green on both axes, repeats every period", function()
		local period = TrafficCycle.Period(S)
		t.eq(period, 30)
		for i = 0, 300 do
			local now = i * 0.25
			local ns, ew = TrafficCycle.State(now, S)
			t.falsy(ns ~= "signal_red" and ew ~= "signal_red", "both axes open at " .. now)
			local ns2, ew2 = TrafficCycle.State(now + period, S)
			t.eq(ns, ns2)
			t.eq(ew, ew2)
		end
	end)
end

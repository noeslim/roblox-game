local Pose = require("../../src/shared/Logic/Pose")
local Animations = require("../../src/shared/Config/Animations")

local def = {
	duration = 1,
	fade = 0.2,
	keys = {
		{ t = 0, joints = { Neck = { x = 0, y = 0, z = 0 } } },
		{ t = 1, joints = { Neck = { x = 10, y = -20, z = 0 }, Waist = { x = 4, y = 0, z = 0 } } },
	},
}

return function(t)
	t.test("samples keys and interpolates in between", function()
		t.near(Pose.Sample(def, 0).Neck.x, 0)
		t.near(Pose.Sample(def, 1).Neck.y, -20)
		local mid = Pose.Sample(def, 0.5)
		t.near(mid.Neck.x, 5) -- smoothstep(0.5) = 0.5
		t.near(mid.Waist.x, 2, 1e-6, "joint only in the next key blends from zero")
	end)

	t.test("time is clamped", function()
		t.near(Pose.Sample(def, 5).Neck.x, 10)
		t.near(Pose.Sample(def, -1).Neck.x, 0)
	end)

	t.test("weight fades in and out", function()
		t.eq(Pose.Weight(def, 0), 0)
		t.near(Pose.Weight(def, 0.1), 0.5)
		t.eq(Pose.Weight(def, 0.5), 1)
		t.near(Pose.Weight(def, 0.9), 0.5)
		t.eq(Pose.Weight(def, 1), 0)
	end)

	t.test("every procedural animation is well formed", function()
		for name, anim in Animations.Procedural do
			t.truthy(anim.duration > 0, name)
			t.truthy(#anim.keys >= 2, name)
			t.near(anim.keys[1].t, 0, 1e-9, name .. " starts at 0")
			t.near(anim.keys[#anim.keys].t, anim.duration, 1e-9, name .. " ends at duration")
			for i = 2, #anim.keys do
				t.truthy(anim.keys[i].t > anim.keys[i - 1].t, name .. " keys in order")
			end
			t.truthy(Animations.Custom[name] ~= nil, name .. " has a Custom slot")
		end
	end)
end

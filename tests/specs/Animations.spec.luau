local Animations = require("../../src/shared/Config/Animations")

local JOINTS = {
	Root = true, Waist = true, Neck = true,
	RightShoulder = true, RightElbow = true, RightWrist = true,
	LeftShoulder = true, LeftElbow = true, LeftWrist = true,
	RightHip = true, RightKnee = true, RightAnkle = true,
	LeftHip = true, LeftKnee = true, LeftAnkle = true,
}

return function(t)
	t.test("procedural animations are well formed", function()
		for name, def in Animations.Procedural do
			t.truthy(def.duration > 0 and def.fade >= 0 and def.fade * 2 <= def.duration, name .. " timing")
			local last = -1
			for _, key in def.keys do
				t.truthy(key.t > last, name .. " keys must be in order")
				t.truthy(key.t <= def.duration, name .. " key after the end")
				last = key.t
				for joint in key.joints do
					t.truthy(JOINTS[joint], name .. " unknown joint " .. joint)
				end
			end
			t.eq(def.keys[1].t, 0)
		end
	end)

	t.test("customer fidgets exist", function()
		for _, name in Animations.Npc.Fidgets do
			t.truthy(Animations.Procedural[name], name)
		end
		t.truthy(Animations.Npc.FidgetMinSeconds <= Animations.Npc.FidgetMaxSeconds)
	end)
end

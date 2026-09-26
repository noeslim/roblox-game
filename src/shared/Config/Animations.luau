--!strict
-- Animations. Three sources:
--  1. Locomotion / Emotes: Roblox's own R15 animations (usable in any experience).
--  2. Custom: animations YOU published (Animation Editor -> Publish). Paste "rbxassetid://..." here and
--     it replaces the procedural version of the same name.
--  3. Procedural: poses written in code, played by the client on the R15 joints (no upload needed).
--     Angles in degrees around the joint's X / Y / Z axes. On R15 arms: +X raises the arm forward,
--     elbows bend with +X. Neck: -X looks down, Y turns the head.

export type Angles = { x: number, y: number, z: number }
export type Key = { t: number, joints: { [string]: Angles } }
export type Procedural = {
	duration: number,
	fade: number, -- seconds to blend in / out
	prop: string?, -- "Cash" (bills in the left hand) or nil
	keys: { Key },
}

local function a(x: number, y: number?, z: number?): Angles
	return { x = x, y = y or 0, z = z or 0 }
end

local Animations = {}

Animations.Locomotion = {
	Idle = "rbxassetid://507766666",
	Walk = "rbxassetid://507777826",
	Run = "rbxassetid://507767714",
	WalkSpeedReference = 16, -- the walk animation is authored for this speed
}

Animations.Emotes = {
	Wave = "rbxassetid://507770239",
	Point = "rbxassetid://507770453",
	Cheer = "rbxassetid://507770677",
	Laugh = "rbxassetid://507770818",
}

Animations.Custom = {
	Handshake = "",
	CountMoney = "",
	HandOver = "",
	Hammer = "",
	Inspect = "",
	ShakeHead = "",
	Shrug = "",
	Nod = "",
	LookAround = "",
	CheckPhone = "",
	ArmsCrossed = "",
	ShiftWeight = "",
} :: { [string]: string }

-- Customers waiting in line play a random fidget now and then (AnimServer)
Animations.Npc = {
	Fidgets = { "LookAround", "CheckPhone", "ArmsCrossed", "ShiftWeight" },
	FidgetMinSeconds = 5,
	FidgetMaxSeconds = 11,
}

-- Timing of the deal scene (seconds)
Animations.Deal = {
	HandshakeSeconds = 1.6,
	CustomerLeaveDelay = 4, -- the customer inspects the weapon before walking away
}

Animations.Procedural = {
	Handshake = {
		duration = 1.6,
		fade = 0.2,
		keys = {
			{ t = 0.0, joints = { RightShoulder = a(0), RightElbow = a(0), Waist = a(0) } },
			{ t = 0.3, joints = { RightShoulder = a(72), RightElbow = a(18), Waist = a(-6) } },
			{ t = 0.5, joints = { RightShoulder = a(60), RightElbow = a(30), Waist = a(-6) } },
			{ t = 0.7, joints = { RightShoulder = a(74), RightElbow = a(16), Waist = a(-6) } },
			{ t = 0.9, joints = { RightShoulder = a(60), RightElbow = a(30), Waist = a(-6) } },
			{ t = 1.1, joints = { RightShoulder = a(72), RightElbow = a(18), Waist = a(-4) } },
			{ t = 1.6, joints = { RightShoulder = a(0), RightElbow = a(0), Waist = a(0) } },
		},
	},
	CountMoney = {
		duration = 2.2,
		fade = 0.25,
		prop = "Cash",
		keys = {
			{ t = 0.0, joints = { LeftShoulder = a(55), LeftElbow = a(55), RightShoulder = a(45, 0, -8), RightElbow = a(60), RightWrist = a(0), Neck = a(-18) } },
			{ t = 0.25, joints = { LeftShoulder = a(55), LeftElbow = a(55), RightShoulder = a(45, 0, -8), RightElbow = a(60), RightWrist = a(25), Neck = a(-18) } },
			{ t = 0.45, joints = { LeftShoulder = a(55), LeftElbow = a(55), RightShoulder = a(45, 0, -8), RightElbow = a(60), RightWrist = a(-20), Neck = a(-18) } },
			{ t = 0.65, joints = { LeftShoulder = a(55), LeftElbow = a(55), RightShoulder = a(45, 0, -8), RightElbow = a(60), RightWrist = a(25), Neck = a(-18) } },
			{ t = 0.85, joints = { LeftShoulder = a(55), LeftElbow = a(55), RightShoulder = a(45, 0, -8), RightElbow = a(60), RightWrist = a(-20), Neck = a(-18) } },
			{ t = 1.05, joints = { LeftShoulder = a(55), LeftElbow = a(55), RightShoulder = a(45, 0, -8), RightElbow = a(60), RightWrist = a(25), Neck = a(-18) } },
			{ t = 1.25, joints = { LeftShoulder = a(55), LeftElbow = a(55), RightShoulder = a(45, 0, -8), RightElbow = a(60), RightWrist = a(-20), Neck = a(-18) } },
			{ t = 1.45, joints = { LeftShoulder = a(55), LeftElbow = a(55), RightShoulder = a(45, 0, -8), RightElbow = a(60), RightWrist = a(25), Neck = a(-18) } },
			{ t = 1.7, joints = { LeftShoulder = a(55), LeftElbow = a(55), RightShoulder = a(30), RightElbow = a(40), RightWrist = a(0), Neck = a(-10) } },
			{ t = 2.2, joints = { LeftShoulder = a(0), LeftElbow = a(0), RightShoulder = a(0), RightElbow = a(0), RightWrist = a(0), Neck = a(0) } },
		},
	},
	HandOver = {
		duration = 1.0,
		fade = 0.15,
		keys = {
			{ t = 0.0, joints = { RightShoulder = a(0), RightElbow = a(0) } },
			{ t = 0.35, joints = { RightShoulder = a(80), RightElbow = a(6) } },
			{ t = 0.65, joints = { RightShoulder = a(80), RightElbow = a(6) } },
			{ t = 1.0, joints = { RightShoulder = a(0), RightElbow = a(0) } },
		},
	},
	Hammer = {
		duration = 1.8,
		fade = 0.2,
		keys = {
			{ t = 0.0, joints = { RightShoulder = a(40), RightElbow = a(20), LeftShoulder = a(40), LeftElbow = a(50), Neck = a(-22), Waist = a(-10) } },
			{ t = 0.25, joints = { RightShoulder = a(120), RightElbow = a(45), LeftShoulder = a(40), LeftElbow = a(50), Neck = a(-22), Waist = a(-10) } },
			{ t = 0.4, joints = { RightShoulder = a(35), RightElbow = a(10), LeftShoulder = a(40), LeftElbow = a(50), Neck = a(-22), Waist = a(-12) } },
			{ t = 0.65, joints = { RightShoulder = a(120), RightElbow = a(45), LeftShoulder = a(40), LeftElbow = a(50), Neck = a(-22), Waist = a(-10) } },
			{ t = 0.8, joints = { RightShoulder = a(35), RightElbow = a(10), LeftShoulder = a(40), LeftElbow = a(50), Neck = a(-22), Waist = a(-12) } },
			{ t = 1.05, joints = { RightShoulder = a(120), RightElbow = a(45), LeftShoulder = a(40), LeftElbow = a(50), Neck = a(-22), Waist = a(-10) } },
			{ t = 1.2, joints = { RightShoulder = a(35), RightElbow = a(10), LeftShoulder = a(40), LeftElbow = a(50), Neck = a(-22), Waist = a(-12) } },
			{ t = 1.8, joints = { RightShoulder = a(0), RightElbow = a(0), LeftShoulder = a(0), LeftElbow = a(0), Neck = a(0), Waist = a(0) } },
		},
	},
	Inspect = {
		duration = 2.4,
		fade = 0.3,
		keys = {
			{ t = 0.0, joints = { RightShoulder = a(0), RightElbow = a(0), LeftShoulder = a(0), LeftElbow = a(0), Neck = a(0) } },
			{ t = 0.4, joints = { RightShoulder = a(55), RightElbow = a(45), LeftShoulder = a(50, 0, 15), LeftElbow = a(55), Neck = a(-18) } },
			{ t = 1.2, joints = { RightShoulder = a(60), RightElbow = a(40), LeftShoulder = a(55, 0, 15), LeftElbow = a(50), Neck = a(-14, 15) } },
			{ t = 1.9, joints = { RightShoulder = a(55), RightElbow = a(45), LeftShoulder = a(50, 0, 15), LeftElbow = a(55), Neck = a(-14, -12) } },
			{ t = 2.4, joints = { RightShoulder = a(20), RightElbow = a(30), LeftShoulder = a(0), LeftElbow = a(0), Neck = a(0) } },
		},
	},
	ShakeHead = {
		duration = 1.1,
		fade = 0.15,
		keys = {
			{ t = 0.0, joints = { Neck = a(0, 0) } },
			{ t = 0.2, joints = { Neck = a(-5, 22) } },
			{ t = 0.4, joints = { Neck = a(-5, -22) } },
			{ t = 0.6, joints = { Neck = a(-5, 20) } },
			{ t = 0.8, joints = { Neck = a(-5, -18) } },
			{ t = 1.1, joints = { Neck = a(0, 0) } },
		},
	},
	Shrug = {
		duration = 1.0,
		fade = 0.15,
		keys = {
			{ t = 0.0, joints = { RightShoulder = a(0), LeftShoulder = a(0), RightElbow = a(0), LeftElbow = a(0), Neck = a(0) } },
			{ t = 0.3, joints = { RightShoulder = a(20, 0, 25), LeftShoulder = a(20, 0, -25), RightElbow = a(60), LeftElbow = a(60), Neck = a(0, 0, 12) } },
			{ t = 0.7, joints = { RightShoulder = a(20, 0, 25), LeftShoulder = a(20, 0, -25), RightElbow = a(60), LeftElbow = a(60), Neck = a(0, 0, 12) } },
			{ t = 1.0, joints = { RightShoulder = a(0), LeftShoulder = a(0), RightElbow = a(0), LeftElbow = a(0), Neck = a(0) } },
		},
	},
	-- Idle fidgets (customers waiting)
	LookAround = {
		duration = 3.2,
		fade = 0.4,
		keys = {
			{ t = 0.0, joints = { Neck = a(0, 0), Waist = a(0, 0) } },
			{ t = 0.8, joints = { Neck = a(-4, 38), Waist = a(0, 10) } },
			{ t = 1.5, joints = { Neck = a(-4, 36), Waist = a(0, 8) } },
			{ t = 2.3, joints = { Neck = a(-2, -34), Waist = a(0, -8) } },
			{ t = 3.2, joints = { Neck = a(0, 0), Waist = a(0, 0) } },
		},
	},
	CheckPhone = {
		duration = 4.0,
		fade = 0.35,
		keys = {
			{ t = 0.0, joints = { RightShoulder = a(0), RightElbow = a(0), RightWrist = a(0), Neck = a(0) } },
			{ t = 0.5, joints = { RightShoulder = a(38, 0, -12), RightElbow = a(95), RightWrist = a(-15), Neck = a(-26) } },
			{ t = 2.0, joints = { RightShoulder = a(40, 0, -12), RightElbow = a(92), RightWrist = a(-12), Neck = a(-24, 4) } },
			{ t = 3.4, joints = { RightShoulder = a(38, 0, -12), RightElbow = a(95), RightWrist = a(-15), Neck = a(-26, -3) } },
			{ t = 4.0, joints = { RightShoulder = a(0), RightElbow = a(0), RightWrist = a(0), Neck = a(0) } },
		},
	},
	ArmsCrossed = {
		duration = 4.5,
		fade = 0.4,
		keys = {
			{ t = 0.0, joints = { RightShoulder = a(0), LeftShoulder = a(0), RightElbow = a(0), LeftElbow = a(0), Neck = a(0) } },
			{ t = 0.5, joints = { RightShoulder = a(30, 0, -28), LeftShoulder = a(34, 0, 28), RightElbow = a(105), LeftElbow = a(100), Neck = a(-4) } },
			{ t = 4.0, joints = { RightShoulder = a(30, 0, -28), LeftShoulder = a(34, 0, 28), RightElbow = a(105), LeftElbow = a(100), Neck = a(-2, 8) } },
			{ t = 4.5, joints = { RightShoulder = a(0), LeftShoulder = a(0), RightElbow = a(0), LeftElbow = a(0), Neck = a(0) } },
		},
	},
	ShiftWeight = {
		duration = 2.6,
		fade = 0.4,
		keys = {
			{ t = 0.0, joints = { Root = a(0, 0, 0), Waist = a(0, 0, 0), Neck = a(0) } },
			{ t = 0.9, joints = { Root = a(0, 0, 4), Waist = a(0, 0, -5), Neck = a(0, 0, 3) } },
			{ t = 1.8, joints = { Root = a(0, 0, 4), Waist = a(0, 0, -5), Neck = a(0, 0, 3) } },
			{ t = 2.6, joints = { Root = a(0, 0, 0), Waist = a(0, 0, 0), Neck = a(0) } },
		},
	},
	Nod = {
		duration = 0.9,
		fade = 0.1,
		keys = {
			{ t = 0.0, joints = { Neck = a(0) } },
			{ t = 0.2, joints = { Neck = a(-16) } },
			{ t = 0.4, joints = { Neck = a(2) } },
			{ t = 0.6, joints = { Neck = a(-14) } },
			{ t = 0.9, joints = { Neck = a(0) } },
		},
	},
} :: { [string]: Procedural }

return Animations

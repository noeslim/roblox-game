--!strict
-- The feel of the street: dark desaturated grade (Criminality-like), vignette, film grain, low health
-- effects, stamina and camera motion. Visual/feel only, applied by the client (MoodController,
-- MovementController, BodyController). Tune freely in Studio.

return {
	-- Color grade, blended when the phase changes (ColorCorrectionEffect "BM_Mood", client side)
	Grade = {
		TweenSeconds = 6,
		Day = { Saturation = -0.18, Contrast = 0.14, Brightness = -0.02, Tint = "#EEF0F4" },
		Night = { Saturation = -0.25, Contrast = 0.12, Brightness = 0.03, Tint = "#DCE3F0" },
	},

	-- Dark screen edges (4 gradient frames, no texture needed)
	Vignette = {
		Color = "#000000",
		Size = 0.28, -- part of the screen covered from each edge
		Opacity = 0.55, -- 0 = invisible, 1 = black edges
	},

	-- Film grain: a tiling noise image (Toolbox > Images, search "film grain" / "noise texture").
	-- Empty = off.
	Grain = {
		Image = "",
		Opacity = 0.06,
		TileSize = 256, -- pixels
		FramesPerSecond = 18,
	},

	-- Hurt: the world loses its colors, the edges turn dark red and pulse, slight blur
	LowHealth = {
		Threshold = 0.4, -- fraction of MaxHealth where the effect starts
		Saturation = -0.85, -- at 0 health
		VignetteColor = "#3A0000",
		VignetteOpacity = 0.85,
		PulseSpeed = 1.3, -- beats per second at 0 health
		BlurSize = 6,
		HeartbeatSound = "", -- rbxassetid://... (Toolbox > Audio "heartbeat")
		Volume = 0.6,
	},

	-- Stamina (Logic/Stamina): sprint with Shift (button on phones), jumping costs a bit
	Stamina = {
		Max = 100,
		SprintDrain = 16, -- per second
		JumpCost = 10,
		Regen = 14, -- per second, after RegenDelay
		RegenDelay = 1.1,
		ExhaustedBelow = 1, -- empty: exhausted...
		RecoverAbove = 35, -- ...until it is back above this
		WalkSpeed = 13,
		SprintSpeed = 21,
		ExhaustedSpeed = 9,
		BreathSound = "", -- heavy breathing while exhausted (Toolbox > Audio "heavy breathing")
		BreathVolume = 0.5,
	},

	-- Camera motion (first and third person)
	Camera = {
		BobAmplitude = 0.12, -- studs, walking
		SprintBobMultiplier = 1.8,
		BobFrequency = 1.9, -- steps per second at walk speed
		IdleSway = 0.035, -- breathing, studs
		StrafeTilt = 2.2, -- degrees when strafing
		SprintFov = 78,
		Fov = 70,
		LandShake = 0.35, -- studs, after a fall
	},

	-- Body dynamics seen by everyone (BodyController, computed on each client)
	Body = {
		SprintLean = 9, -- degrees forward when running fast
		TurnLean = 7, -- degrees into turns
		HeadFollow = 0.7, -- how much the head follows where the player looks (0..1)
		MaxHeadYaw = 60,
		MaxHeadPitch = 40,
		LookSendRate = 5, -- per second, the look direction sent to the server
		Smoothing = 10,
	},
}

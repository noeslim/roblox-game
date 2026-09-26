--!strict
-- First-person crafting scene (CraftCinematicController, Logic/Assembly). Times in seconds, distances
-- in studs relative to the workbench (+Z = the side you stand on, top of the bench at TopY).
-- Sounds: paste ids from the Toolbox (Audio), e.g. "gun reload click", "ratchet", "metal clank".

return {
	Craft = {
		Enabled = true, -- false: crafting stays in the workbench window (no scene)
		IntroSeconds = 0.6, -- camera moves over the bench
		PickSeconds = 0.25, -- the hand reaches the part on the bench
		CarrySeconds = 0.45, -- carries it next to the frame
		SeatSeconds = 0.2, -- slides it in (click)
		SettleSeconds = 0.15,
		ScrewSeconds = 1.1, -- two screws
		LiftSeconds = 0.7, -- picks the weapon up from the bench
		LoadSeconds = 1.0, -- the magazine goes in from below
		RackSeconds = 0.7, -- pulls the action back and lets it go
		TestSeconds = 1.6, -- aims and dry-fires twice
		InspectSeconds = 2.2, -- turns it to look at it
		LoadSlot = "Magazine",
		OutroSeconds = 0.5,
		SkipAfter = 0.4, -- click / space / E skips after this

		TopY = 0.9, -- top of the workbench above its center
		CameraOffset = { x = 0, y = 2.9, z = 2.7 }, -- eye position
		LookAt = { x = 0, y = 0.9, z = -0.3 },
		Fov = 58,
		JigHeight = 0.62, -- the frame rests this high above the bench top (on two small blocks)
		TrayZ = 0.95, -- parts wait here, spread along X
		TraySpread = 4.4,
		CarryArc = 0.9, -- how high a part is lifted while carried
		SeatDistance = 0.8, -- a part stops this far before sliding in
		-- once lifted, the camera stands up and looks straight ahead; the weapon is held in front
		StandUp = 0.9, -- the eye rises this much
		HeldOffset = { x = -0.1, y = -0.3, z = -2.9 }, -- weapon in camera space
		AimOffset = { x = 0, y = -0.32, z = -1.7 }, -- aiming: sight on the view line
		LoadApproach = 0.35, -- the magazine comes from this far below
		RackPull = 0.35,
		Recoil = 0.08, -- studs back per dry fire
		InspectTurn = 28, -- degrees left and right
		ClickKick = 0.04, -- camera kick when a part clicks in
		HandFollow = 16, -- how fast the hands follow their target (higher = snappier)

		SkinColor = "#C68642", -- used when the character has no body colors
		AvatarHands = true, -- use the avatar's own hands (false: simple block hands)
		AvatarHandFlip = false, -- true if the avatar's palms show upwards instead of the back of the hands
		SleeveColor = "#1E1E24",

		Sounds = {
			Pick = "",
			Click = "",
			Ratchet = "",
			Rack = "", -- racking the action
			MagIn = "", -- magazine seated
			DryFire = "", -- trigger click
		},
		Volume = 0.8,
	},
}

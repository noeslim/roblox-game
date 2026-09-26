--!strict
-- First-person crafting scene (CraftCinematicController, Logic/Assembly). Times in seconds, distances
-- in studs relative to the workbench (+Z = the side you stand on, top of the bench at TopY).
-- Sounds: paste ids from the Toolbox (Audio), e.g. "gun reload click", "ratchet", "metal clank".

return {
	Craft = {
		IntroSeconds = 0.6, -- camera moves over the bench
		PickSeconds = 0.25, -- the hand reaches the part on the bench
		CarrySeconds = 0.45, -- carries it next to the frame
		SeatSeconds = 0.2, -- slides it in (click)
		SettleSeconds = 0.15,
		ScrewSeconds = 1.1, -- two screws
		InspectSeconds = 2.4, -- lifts the weapon and turns it
		OutroSeconds = 0.5,
		SkipAfter = 0.4, -- click / space / E skips after this

		TopY = 0.9, -- top of the workbench above its center
		CameraOffset = { x = 0, y = 2.9, z = 2.7 }, -- eye position
		LookAt = { x = 0, y = 0.9, z = -0.3 },
		Fov = 58,
		JigHeight = 0.75, -- the frame is held this high above the bench top
		TrayZ = 0.95, -- parts wait here, spread along X
		TraySpread = 4.4,
		CarryArc = 0.9, -- how high a part is lifted while carried
		SeatDistance = 0.8, -- a part stops this far before sliding in
		InspectDistance = 3.4, -- weapon in front of the camera during the inspection
		InspectTurn = 28, -- degrees left and right
		ClickKick = 0.04, -- camera kick when a part clicks in

		SkinColor = "#C68642", -- used when the character has no body colors
		SleeveColor = "#1E1E24",

		Sounds = {
			Pick = "",
			Click = "",
			Ratchet = "",
			Rack = "", -- at the end of the inspection
		},
		Volume = 0.8,
	},
}

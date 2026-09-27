--!strict
-- Music and ambience by zone (roadmap 2.4, Logic/Soundscape, SoundscapeController).
-- Every id is empty: put your own from the Creator Store (Toolbox > Audio), e.g. "rbxassetid://123".
-- A track is either one id, or { Day = id, Night = id }. An empty zone falls back to "Streets".
-- Priority of the music: your raid > inside a trap house > War Zone > the district you are in.
return {
	FadeSeconds = 2.5, -- crossfade between two tracks
	MusicVolume = 0.35,
	AmbienceVolume = 0.5,
	SceneDuck = 0.3, -- music volume x this during the first-person scenes (crafting, deals)
	-- inside a trap house the street is heard through the walls
	Indoor = { HighGain = -25, MidGain = -8, LowGain = 0 },
	ToggleKey = "N", -- mutes / unmutes the music (M is "move" in build mode)

	Music = {
		Raid = "", -- tense, fast (plays over everything during a raid on your stash)
		Hideout = { Day = "", Night = "" }, -- lo-fi / trap instrumental in the basements
		WarZone = "", -- drums, tension
		Streets = { Day = "", Night = "" }, -- avenues and any district without its own music
		RichHills = { Day = "", Night = "" }, -- smooth, jazzy
		Chinatown = { Day = "", Night = "" },
		Docks = { Day = "", Night = "" },
		Blocks = { Day = "", Night = "" }, -- boom bap
		Downtown = { Day = "", Night = "" },
		Industrial = { Day = "", Night = "" },
		Strip = { Day = "", Night = "" }, -- club music leaking out
	},
	Ambience = {
		Streets = "", -- traffic, distant voices (empty: World.Sounds.CityLoop)
		Hideout = "", -- room tone, a fridge humming
		RichHills = "", -- birds, sprinklers
		Chinatown = "", -- market crowd, sizzling woks
		Docks = "", -- seagulls, waves, ship horns
		Industrial = "", -- machines, metal
		Strip = "", -- bass through club walls
		WarZone = "", -- wind, far gunfire
	},
}

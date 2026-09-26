--!strict
-- Persistence settings (not balancing). Changing StoreName wipes everyone's progress: don't.

local Data = {
	StoreName = "PlayerData",
	KeyPrefix = "Player_",
	-- true: in Studio, use ProfileStore.Mock (nothing is written to the real DataStore)
	UseMockInStudio = false,
}

return Data

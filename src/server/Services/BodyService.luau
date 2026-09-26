--!strict
-- Relays where each player looks (LookAt remote) as attributes on their character, so every client
-- can turn that character's head (BodyController). Cosmetic only; values are clamped.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Mood = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Mood"))
local ServerNet = require(script.Parent.Parent.Lib.ServerNet)

local BodyService = {}

local function clean(v: any, limit: number): number?
	if type(v) ~= "number" or v ~= v or math.abs(v) == math.huge then
		return nil
	end
	return math.round(math.clamp(v, -limit, limit))
end

function BodyService:Start()
	local B = Mood.Body
	ServerNet.OnEvent("LookAt", function(player: Player, pitch: any, yaw: any)
		local character = player.Character
		local p, y = clean(pitch, B.MaxHeadPitch), clean(yaw, B.MaxHeadYaw)
		if character == nil or p == nil or y == nil then
			return
		end
		character:SetAttribute("LookPitch", p)
		character:SetAttribute("LookYaw", y)
	end)
end

return BodyService

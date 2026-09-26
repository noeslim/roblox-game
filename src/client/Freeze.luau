--!strict
-- Freezes the local character (crafting scene, build mode) without ever waiting: uses Roblox's
-- PlayerModule controls when they exist, and anchors the character's root locally in any case
-- (the client moves its own character, so this stops it everywhere).
local Players = game:GetService("Players")

local Freeze = {}

local function controls(): any
	local scripts = Players.LocalPlayer:FindFirstChild("PlayerScripts")
	local module = scripts and scripts:FindFirstChild("PlayerModule")
	if module == nil or not module:IsA("ModuleScript") then
		return nil
	end
	local ok, result = pcall(function()
		return (require(module) :: any):GetControls()
	end)
	return if ok then result else nil
end

function Freeze.Set(frozen: boolean)
	local c = controls()
	if c then
		pcall(function()
			if frozen then
				c:Disable()
			else
				c:Enable()
			end
		end)
	end
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.Anchored = frozen
	end
end

return Freeze

-- Frame-by-frame check of the crafting scene with real CFrame math (@lune/roblox): nothing goes
-- through the workbench, hands stay above it, everything held stays in view.
local roblox = require("@lune/roblox")
local CraftPoses = require("../../src/shared/Visual/CraftPoses")
local Assembly = require("../../src/shared/Logic/Assembly")
local Cinematics = require("../../src/shared/Config/Cinematics")
local Visual = require("../../src/shared/Config/Visual")
local Economy = require("../../src/shared/Config/Economy")

local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local C = Cinematics.Craft
local P = CraftPoses.new({ CFrame = CFrame, Vector3 = Vector3, Assembly = Assembly }, C, Visual.WeaponLayout, Economy.Crafting.Slots)
local ALL = { Body = true, Barrel = true, Stock = true, Sight = true, Magazine = true }

-- lowest point of a box of `size` placed at `cf`
local function lowest(cf, size)
	local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
	local ext = math.abs(r.Y) * size.X / 2 + math.abs(u.Y) * size.Y / 2 + math.abs(l.Y) * size.Z / 2
	return cf.Position.Y - ext
end

local function pieceCF(slot, pivot)
	return pivot * CFrame.new(P.offsetOf(slot))
end

local function inView(cam, pos, fov)
	local p = cam:PointToObjectSpace(pos)
	local halfV = math.rad(fov / 2)
	local halfH = math.atan(math.tan(halfV) * 16 / 9)
	return p.Z < -0.3 and math.atan2(math.abs(p.X), -p.Z) < halfH and math.atan2(math.abs(p.Y), -p.Z) < halfV
end

return function(t)
	for _, yaw in { 0, 90, 180, -90, 37 } do
		t.test(("nothing goes through the bench (bench turned %d)"):format(yaw), function()
			local bench = CFrame.new(40, 3, -12) * CFrame.Angles(0, math.rad(yaw), 0)
			local ctx = P.Context(bench, ALL)
			local topY = ctx.top.Position.Y
			local time = 0
			local worst, where = math.huge, ""
			while time <= ctx.plan.total do
				for slot, layout in Visual.WeaponLayout do
					local size = Vector3.new(layout.size.x, layout.size.y, layout.size.z)
					local low = lowest(pieceCF(slot, P.Part(ctx, slot, time)), size)
					if low - topY < worst then
						worst, where = low - topY, ("%s at t=%.2f"):format(slot, time)
					end
				end
				local r, l = P.Hands(ctx, time)
				for _, hand in { r, l } do
					if hand.Position.Y - topY < worst then
						worst, where = hand.Position.Y - topY, ("hand at t=%.2f"):format(time)
					end
				end
				time += 1 / 30
			end
			t.truthy(worst >= -0.02, ("%s is %.2f under the bench top"):format(where, -worst))
		end)
	end

	t.test("the weapon and the hands are in view once lifted", function()
		local ctx = P.Context(CFrame.new(0, 3, 0) * CFrame.Angles(0, math.rad(120), 0), ALL)
		local time = ctx.plan.loadStart
		while time < ctx.plan.outroStart do
			local cam = P.Camera(ctx, time)
			local w = P.Weapon(ctx, time)
			-- aiming: the stock comes to the shoulder, out of view; the barrel and body must show
			local aiming = time >= ctx.plan.testStart and time < ctx.plan.inspectStart
			for _, x in (if aiming then { 0.5, 2 } else { -1.5, 0, 2 }) do
				t.truthy(inView(cam, (w * CFrame.new(x, 0, 0)).Position, C.Fov), ("weapon x=%.1f out of view at t=%.2f"):format(x, time))
			end
			local r, l = P.Hands(ctx, time)
			t.truthy(inView(cam, r.Position, C.Fov), ("right hand out of view at t=%.2f"):format(time))
			-- the left hand may dip out of view while it takes the magazine from the bench
			local load = ctx.plan.load
			if not (load and time >= load.start and time < load.seat) then
				t.truthy(inView(cam, l.Position, C.Fov), ("left hand out of view at t=%.2f"):format(time))
			end
			time += 0.1
		end
	end)

	t.test("parts on the bench are in view while assembling", function()
		local ctx = P.Context(CFrame.new(0, 3, 0), ALL)
		for slot in Visual.WeaponLayout do
			t.truthy(inView(ctx.camBench, pieceCF(slot, ctx.trays[slot]).Position, C.Fov), slot .. " tray out of view")
		end
	end)

	t.test("the magazine is loaded in the hands, not on the bench", function()
		local ctx = P.Context(CFrame.new(0, 3, 0), ALL)
		for _, s in ctx.plan.steps do
			t.truthy(s.slot ~= "Magazine")
		end
		t.truthy(ctx.plan.load and ctx.plan.load.slot == "Magazine")
		-- fitted to the weapon at the end of the load
		local w = P.Weapon(ctx, ctx.plan.rackStart - 0.001)
		local m = P.Part(ctx, "Magazine", ctx.plan.rackStart - 0.001)
		t.truthy((w.Position - m.Position).Magnitude < 0.05)
	end)

	t.test("arms never cross", function()
		for _, yaw in { 0, 90, 200 } do
			local ctx = P.Context(CFrame.new(0, 3, 0) * CFrame.Angles(0, math.rad(yaw), 0), ALL)
			local time = 0
			while time < ctx.plan.outroStart do
				local aiming = time >= ctx.plan.testStart and time < ctx.plan.inspectStart
				if not aiming then
					local cam = P.Camera(ctx, time)
					local r, l = P.Hands(ctx, time)
					local rx, lx = cam:PointToObjectSpace(r.Position).X, cam:PointToObjectSpace(l.Position).X
					t.truthy(rx > lx, ("arms crossed at t=%.2f (bench %d)"):format(time, yaw))
				end
				time += 0.1
			end
		end
	end)
end

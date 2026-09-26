local roblox = require("@lune/roblox")
local DealPoses = require("../../src/shared/Visual/DealPoses")
local DealScene = require("../../src/shared/Logic/DealScene")
local Cinematics = require("../../src/shared/Config/Cinematics")

local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local C = Cinematics.Deal
local P = DealPoses.new({ CFrame = CFrame, Vector3 = Vector3, DealScene = DealScene }, C)

local function lowest(cf, size)
	local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
	return cf.Position.Y - (math.abs(r.Y) * size.X / 2 + math.abs(u.Y) * size.Y / 2 + math.abs(l.Y) * size.Z / 2)
end

local function inView(cam, pos, fov)
	local p = cam:PointToObjectSpace(pos)
	local halfV = math.rad(fov / 2)
	local halfH = math.atan(math.tan(halfV) * 16 / 9)
	return p.Z < -0.3 and math.atan2(math.abs(p.X), -p.Z) < halfH and math.atan2(math.abs(p.Y), -p.Z) < halfV
end

-- a dealer behind a counter, a customer in front (several directions)
local function scene(angle)
	local dir = Vector3.new(math.sin(math.rad(angle)), 0, -math.cos(math.rad(angle)))
	local base = Vector3.new(20, 0, 5)
	local eye = base + Vector3.new(0, 4.5, 0)
	local counter = base + dir * 2 + Vector3.new(0, 3, 0)
	local customer = base + dir * 4 + Vector3.new(0, 3.8, 0)
	local hand = CFrame.new(base + dir * 3.3 + Vector3.new(0.3, 3.9, 0))
	return P.Context(eye, counter, customer), hand
end

return function(t)
	for _, angle in { 0, 90, 180, 250 } do
		t.test(("nothing goes through the counter (facing %d)"):format(angle), function()
			for _, withHand in { true, false } do
				local ctx, hand = scene(angle)
				local h = if withHand then hand else nil
				local time = 0
				while time <= ctx.plan.total do
					-- the weapon: lying, it is WeaponThickness tall; upright (in hand) we check its center stays above
					local w = P.Weapon(ctx, time, h)
					local phase = DealScene.Phase(ctx.plan, time)
					if phase == "place" or (phase == "inspect" and time < ctx.plan.inspect + C.HandOffSeconds) then
						t.truthy(lowest(w, P.WeaponSize) >= ctx.topY - 0.02 or w.Position.Y - ctx.topY > 0.2,
							("weapon in the counter at t=%.2f"):format(time))
					end
					local cash = P.Cash(ctx, time)
					if cash then
						t.truthy(lowest(cash, P.CashSize) >= ctx.topY - 0.02, ("cash in the counter at t=%.2f"):format(time))
					end
					local r, l = P.Hands(ctx, time, h)
					t.truthy(r.Position.Y > ctx.topY and l.Position.Y > ctx.topY, ("hand in the counter at t=%.2f"):format(time))
					time += 1 / 30
				end
			end
		end)
	end

	t.test("the weapon lies flat on the counter, not floating", function()
		local ctx = scene(0)
		local w = P.Weapon(ctx, ctx.plan.inspect - 0.001)
		t.near(lowest(w, P.WeaponSize) - ctx.topY, C.CounterGap, 0.3)
	end)

	t.test("arms never cross, hands and cash in view", function()
		for _, angle in { 0, 130 } do
			local ctx, hand = scene(angle)
			local time = 0.6
			while time < ctx.plan.outro - 0.3 do -- then the screen fades to black
				local cam = P.Camera(ctx, time)
				local r, l = P.Hands(ctx, time, hand)
				local rx, lx = cam:PointToObjectSpace(r.Position).X, cam:PointToObjectSpace(l.Position).X
				t.truthy(rx > lx, ("arms crossed at t=%.2f"):format(time))
				t.truthy(inView(cam, r.Position, C.Fov) and inView(cam, l.Position, C.Fov), ("hand out of view at t=%.2f"):format(time))
				local cash = P.Cash(ctx, time)
				if cash then
					t.truthy(inView(cam, cash.Position, C.Fov), ("cash out of view at t=%.2f"):format(time))
				end
				time += 0.1
			end
		end
	end)
end

--!strict
-- Where everything is in the first-person crafting scene, at time t: camera, weapon, each part, both
-- hands and the screwdriver. Plain math over CFrame / Vector3 handed in by the caller (the game, or a
-- Lune test with @lune/roblox), so it can be checked frame by frame outside Studio.
-- Frames: benchCF = the workbench root (top at TopY). Weapon space: barrel +X, up +Y, the side facing
-- you +Z. A "palm" frame has the back of the hand up (+Y) and the fingers towards -Z.

local CraftPoses = {}

-- direction each bench part slides in along, in weapon space
local INSERT = {
	Body = { 0, 1, 0 },
	Barrel = { 1, 0, 0 },
	Stock = { -1, 0, 0 },
	Sight = { 0, 1, 0 },
	Magazine = { 0, -1, 0 },
} :: { [string]: { number } }

-- deps: CFrame and Vector3 (Roblox's, or @lune/roblox in tests) and the Logic/Assembly module
export type Deps = { CFrame: any, Vector3: any, Assembly: any }

function CraftPoses.new(deps: Deps, cfg: any, layout: { [string]: any }, slotOrder: { string })
	local CF, V3, Assembly = deps.CFrame, deps.Vector3, deps.Assembly
	local P = {}

	local function vec(t: { x: number, y: number, z: number }): any
		return V3.new(t.x, t.y, t.z)
	end
	local UP = V3.new(0, 1, 0)

	-- Roblox's CFrame.lookAt (rebuilt: Lune's differs), camera-style: looks along -Z
	local function lookAt(eye: any, target: any): any
		local f = (target - eye).Unit
		local r = f:Cross(UP)
		r = if r.Magnitude < 1e-4 then V3.new(1, 0, 0) else r.Unit
		return CF.fromMatrix(eye, r, r:Cross(f))
	end
	P.lookAt = lookAt

	local function offsetOf(slot: string): any
		local l = layout[slot]
		return if l then vec(l.pos) else V3.new(0, 0, 0)
	end
	local function halfHeight(slot: string): number
		local l = layout[slot]
		return if l then l.size.y / 2 else 0.25
	end
	P.offsetOf = offsetOf

	-- a palm at `pos`, fingers pointing away from `eye` (flat), back of the hand up
	local function palm(pos: any, eye: any): any
		local flat = (pos - eye) * V3.new(1, 0, 1)
		local dir = if flat.Magnitude > 0.01 then flat.Unit else V3.new(0, 0, -1)
		return lookAt(pos, pos + dir)
	end
	P.palm = palm

	function P.Context(benchCF: any, present: { [string]: boolean }): any
		local ctx: any = {}
		ctx.top = benchCF * CF.new(0, cfg.TopY, 0)
		ctx.jig = ctx.top * CF.new(0, cfg.JigHeight, 0)
		local eye = (benchCF * CF.new(vec(cfg.CameraOffset))).Position
		local look = (benchCF * CF.new(vec(cfg.LookAt))).Position
		ctx.eye = eye
		ctx.camBench = lookAt(eye, look)
		local stand = eye + V3.new(0, cfg.StandUp, 0)
		local flat = ((look - eye) * V3.new(1, 0, 1)).Unit
		ctx.camHeld = lookAt(stand, stand + flat + V3.new(0, -0.12, 0))
		ctx.plan = Assembly.Plan(present, slotOrder, cfg)
		-- parts wait flat on the bench, spread along X (the magazine too, until it is loaded)
		local order = {}
		for _, s in ctx.plan.steps do
			table.insert(order, s.slot)
		end
		if ctx.plan.load then
			table.insert(order, ctx.plan.load.slot)
		end
		ctx.trays = {}
		local n = #order
		for i, slot in order do
			local x = if n > 1 then -cfg.TraySpread / 2 + (i - 1) * cfg.TraySpread / (n - 1) else 0
			local l = layout[slot]
			local rest = (if l then l.size.z / 2 else 0.2) + 0.02 -- lying down, its Z becomes the height
			ctx.trays[slot] = ctx.top * CF.new(x, rest, cfg.TrayZ) * CF.Angles(math.rad(90), 0, 0) * CF.new(-offsetOf(slot))
		end
		-- two small blocks under the frame (the cradle)
		local gap = cfg.JigHeight - 0.35
		ctx.cradle = {
			{ cf = ctx.top * CF.new(-0.5, gap / 2, 0), size = V3.new(0.35, gap, 0.35) },
			{ cf = ctx.top * CF.new(0.5, gap / 2, 0), size = V3.new(0.35, gap, 0.35) },
		}
		return ctx
	end

	function P.Camera(ctx: any, t: number): any
		local plan = ctx.plan
		if t < plan.liftStart then
			return ctx.camBench
		end
		local u = Assembly.Smooth(Assembly.Progress(t, plan.liftStart, plan.loadStart))
		local cam = ctx.camBench:Lerp(ctx.camHeld, u)
		-- loading: the eyes drop a little to watch the magazine go in
		if t >= plan.loadStart and t < plan.rackStart then
			local lu = Assembly.Progress(t, plan.loadStart, plan.rackStart)
			cam = cam * CF.Angles(math.rad(-9 * math.sin(lu * math.pi)), 0, 0)
		end
		-- dry fire: the view kicks a little
		if t >= plan.testStart and t < plan.inspectStart then
			for _, shot in P.Shots(ctx) do
				local k = t - shot
				if k >= 0 and k < 0.15 then
					cam = cam * CF.Angles(math.rad(1.2 * (1 - k / 0.15)), 0, 0)
				end
			end
		end
		return cam
	end

	-- times of the two dry fires
	function P.Shots(ctx: any): { number }
		local plan = ctx.plan
		local d = plan.inspectStart - plan.testStart
		return { plan.testStart + d * 0.45, plan.testStart + d * 0.7 }
	end

	local function held(ctx: any): any
		return ctx.camHeld * CF.new(vec(cfg.HeldOffset)) * CF.Angles(0, math.rad(-15), 0)
	end

	-- the weapon frame (fitted parts follow it)
	function P.Weapon(ctx: any, t: number): any
		local plan = ctx.plan
		if t < plan.liftStart then
			return ctx.jig
		end
		local h = held(ctx)
		if t < plan.loadStart then
			local u = Assembly.Smooth(Assembly.Progress(t, plan.liftStart, plan.loadStart))
			-- up first, then towards the view: never through the bench
			local lifted = ctx.jig + V3.new(0, 0.9 * math.min(1, u * 2), 0)
			return lifted:Lerp(h, u)
		end
		if t < plan.rackStart then
			local l = plan.load
			if l and t >= l.done and t < l.done + 0.12 then
				return h + V3.new(0, 0.03, 0) -- the magazine clicks in
			end
			return h
		end
		if t < plan.testStart then
			local u = Assembly.Progress(t, plan.rackStart, plan.testStart)
			return h * CF.new(math.sin(u * math.pi) * 0.05, 0, 0)
		end
		if t < plan.inspectStart then
			local u = Assembly.Progress(t, plan.testStart, plan.inspectStart)
			local aim = ctx.camHeld * CF.new(vec(cfg.AimOffset)) * CF.Angles(0, math.rad(90), 0)
			local blend = Assembly.Smooth(math.min(1, u / 0.3)) * (1 - Assembly.Smooth(math.max(0, (u - 0.85) / 0.15)))
			local pose = h:Lerp(aim, blend)
			for _, shot in P.Shots(ctx) do
				local k = t - shot
				if k >= 0 and k < 0.15 then
					local kick = 1 - k / 0.15
					pose = pose * CF.new(-cfg.Recoil * kick, 0, 0) * CF.Angles(0, 0, math.rad(4 * kick))
				end
			end
			return pose
		end
		local u = Assembly.Progress(t, plan.inspectStart, plan.outroStart)
		return h * CF.Angles(math.rad(-6 * math.sin(u * math.pi)), math.rad(cfg.InspectTurn * math.sin(u * math.pi * 2)), math.rad(-5 * math.sin(u * math.pi)))
	end

	local function insertVec(slot: string): any
		local d = INSERT[slot] or { 0, 1, 0 }
		return V3.new(d[1], d[2], d[3])
	end

	-- pivot of a part's model (weapon space origin) at time t
	function P.Part(ctx: any, slot: string, t: number): any
		local plan = ctx.plan
		local tray = ctx.trays[slot]
		local l = plan.load
		if l and l.slot == slot then
			local state, u = Assembly.PartState(l, t)
			if state == "tray" or state == "pick" then
				return tray
			end
			local w = P.Weapon(ctx, t)
			local approach = w * CF.new(0, -cfg.LoadApproach, 0)
			if state == "carry" then
				-- lifted off the bench before it turns upright
				local k = Assembly.Smooth(u)
				return tray:Lerp(approach, k) + V3.new(0, math.sin(k * math.pi) * cfg.CarryArc, 0)
			elseif state == "seat" then
				return approach:Lerp(w, Assembly.Smooth(u))
			end
			return w
		end
		for _, s in plan.steps do
			if s.slot == slot then
				local state, u = Assembly.PartState(s, t)
				if state == "tray" or state == "pick" then
					return tray
				end
				local approach = ctx.jig * CF.new(insertVec(slot) * cfg.SeatDistance)
				if state == "carry" then
					local k = Assembly.Smooth(u)
					return tray:Lerp(approach, k) + V3.new(0, math.sin(k * math.pi) * cfg.CarryArc, 0)
				elseif state == "seat" then
					return approach:Lerp(ctx.jig, Assembly.Smooth(u))
				end
				return P.Weapon(ctx, t)
			end
		end
		return tray or P.Weapon(ctx, t)
	end

	-- palm above a part (grabbing it from the top)
	local function gripAbove(ctx: any, slot: string, pivot: any): any
		local center = (pivot * CF.new(offsetOf(slot))).Position
		return palm(center + V3.new(0, halfHeight(slot) + 0.2, 0.1), ctx.eye)
	end

	function P.Rest(ctx: any, side: number): any
		return palm((ctx.top * CF.new(1.7 * side, 0.35, 1.25)).Position, ctx.eye)
	end

	-- screwdriver frame (looks along -Z = the tip), nil outside the screw phase
	function P.Driver(ctx: any, t: number): any?
		local plan = ctx.plan
		if t < plan.screwStart or t >= plan.liftStart then
			return nil
		end
		local u = Assembly.Progress(t, plan.screwStart, plan.liftStart)
		local index = if u < 0.5 then 1 else 2
		local lu = (u - (index - 1) * 0.5) / 0.5
		local spot = ctx.jig * CF.new(if index == 1 then -0.35 else 0.35, 0, 0.21)
		local reach = Assembly.Smooth(math.min(1, lu / 0.3))
		local tip = spot * CF.new(0, 0, 0.55 - 0.3 * reach)
		return lookAt(tip.Position, spot.Position) * CF.Angles(0, 0, lu * math.pi * 6)
	end

	-- target palms (right, left) at time t
	function P.Hands(ctx: any, t: number): (any, any)
		local plan = ctx.plan
		local phase = Assembly.Phase(plan, t)
		local right, left = P.Rest(ctx, 1), P.Rest(ctx, -1)
		local w = P.Weapon(ctx, t)
		local function onWeapon(x: number, y: number, z: number): any
			return palm((w * CF.new(x, y, z)).Position, ctx.eye)
		end
		if phase == "intro" or phase == "assemble" or phase == "screw" then
			local s = Assembly.Current(plan, t)
			if s then
				local state, u = Assembly.PartState(s, t)
				local grip = gripAbove(ctx, s.slot, P.Part(ctx, s.slot, t))
				right = if state == "pick" then right:Lerp(grip, Assembly.Smooth(u)) else grip
			end
			if #plan.steps > 0 and t >= plan.steps[1].done then
				left = palm((ctx.jig * CF.new(-0.6, 0.55, 0.1)).Position, ctx.eye) -- holds the frame
			end
			local d = P.Driver(ctx, t)
			if d then
				right = palm((d * CF.new(0, 0.18, 0.35)).Position, ctx.eye)
			end
			return right, left
		end
		right = onWeapon(-0.35, -0.3, 0.3) -- on the grip
		left = onWeapon(1.0, 0.1, 0.3) -- under the barrel
		local l = plan.load
		if phase == "load" and l then
			local state, u = Assembly.PartState(l, t)
			local mag = P.Part(ctx, l.slot, t)
			-- the hand wraps the magazine from the side facing you and pushes it up
			local side = (mag * CF.new(offsetOf(l.slot)) * CF.new(0, -halfHeight(l.slot) * 0.4, 0.28)).Position
			local push = palm(side, ctx.eye) * CF.Angles(0, 0, math.rad(80))
			if state == "pick" then
				left = left:Lerp(gripAbove(ctx, l.slot, mag), Assembly.Smooth(u))
			elseif state == "carry" then
				-- from the top grip to the side grip while bringing it up
				left = gripAbove(ctx, l.slot, mag):Lerp(push, Assembly.Smooth(u))
			elseif state == "seat" then
				left = push -- wraps it from the side, pushing it in
			end
		elseif phase == "rack" then
			local u = Assembly.Progress(t, plan.rackStart, plan.testStart)
			local pull = math.sin(math.min(1, u / 0.7) * math.pi) * cfg.RackPull
			left = onWeapon(-0.45 - pull, 0.55, 0.15) -- charging handle on top
		end
		return right, left
	end

	return P
end

return CraftPoses

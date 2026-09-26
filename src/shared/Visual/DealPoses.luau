--!strict
-- Where everything is in the first-person sale at time t: camera, the weapon, the cash, your hands.
-- Plain math over CFrame / Vector3 handed in by the caller (the game, or @lune/roblox in tests).
-- The deal frame sits on the counter top, between you and the customer, looking at the customer (-Z).
-- Weapon space: barrel +X, up +Y. Palm frames: back of the hand up, fingers towards -Z.

local DealPoses = {}

export type Deps = { CFrame: any, Vector3: any, DealScene: any }

local WEAPON_SIZE = { 4, 1.6, 0.5 } -- the placeholder weapon at scale 1 (ModelFactory.Weapon)
local CASH_SIZE = { 0.9, 0.3, 0.45 }

function DealPoses.new(deps: Deps, cfg: any)
	local CF, V3, DealScene = deps.CFrame, deps.Vector3, deps.DealScene
	local P = {}
	local UP = V3.new(0, 1, 0)

	local function lookAt(eye: any, target: any): any
		local f = (target - eye).Unit
		local r = f:Cross(UP)
		r = if r.Magnitude < 1e-4 then V3.new(1, 0, 0) else r.Unit
		return CF.fromMatrix(eye, r, r:Cross(f))
	end
	P.lookAt = lookAt

	local function palm(pos: any, eye: any): any
		local flat = (pos - eye) * V3.new(1, 0, 1)
		local dir = if flat.Magnitude > 0.01 then flat.Unit else V3.new(0, 0, -1)
		return lookAt(pos, pos + dir)
	end
	local smooth = DealScene.Smooth

	local S = cfg.WeaponScale
	P.CashSize = V3.new(CASH_SIZE[1], CASH_SIZE[2], CASH_SIZE[3])
	P.WeaponSize = V3.new(WEAPON_SIZE[1], WEAPON_SIZE[2], WEAPON_SIZE[3]) * S
	local WEAPON_THICKNESS = WEAPON_SIZE[3] * S -- lying on its side, the weapon is this tall

	-- eye: your head; counter: a point on the counter top between you and the customer;
	-- customer: the customer's chest
	function P.Context(eye: any, counter: any, customer: any): any
		local ctx: any = {}
		ctx.plan = DealScene.Plan(cfg)
		ctx.eye = eye
		local flat = (customer - eye) * V3.new(1, 0, 1)
		local dir = if flat.Magnitude > 0.01 then flat.Unit else V3.new(0, 0, -1)
		ctx.frame = lookAt(counter, counter + dir) -- on the counter, facing the customer
		ctx.topY = counter.Y
		ctx.cam = lookAt(eye, customer - V3.new(0, 0.9, 0))
		local r = WEAPON_THICKNESS / 2 + cfg.CounterGap
		-- held low in the right hand, barrel to the left
		ctx.held = ctx.cam * CF.new(0.35, -0.7, -1.3) * CF.Angles(0, math.pi, 0)
		-- laid on its side on the counter, barrel to the left
		ctx.placed = ctx.frame * CF.new(cfg.PlaceSpot.x, r, cfg.PlaceSpot.z) * CF.Angles(0, math.pi, 0) * CF.Angles(math.rad(90), 0, 0)
		local c = CASH_SIZE[2] / 2 + cfg.CounterGap
		ctx.cashFrom = ctx.frame * CF.new(cfg.CashFrom.x, c, cfg.CashFrom.z)
		ctx.cashTo = ctx.frame * CF.new(cfg.CashTo.x, c, cfg.CashTo.z)
		ctx.countHold = ctx.cam * CF.new(cfg.CountHold.x, cfg.CountHold.y, cfg.CountHold.z) * CF.Angles(math.rad(35), 0, 0)
		return ctx
	end

	function P.Camera(ctx: any, t: number): any
		local plan = ctx.plan
		local cam = ctx.cam
		-- looking down at the cash while counting
		if t >= plan.take then
			local u = smooth(DealScene.Progress(t, plan.take, plan.shake)) * (1 - smooth(DealScene.Progress(t, plan.shake, plan.shake + 0.4)))
			local c = smooth(DealScene.Progress(t, plan.count, plan.count + 0.4)) * (1 - smooth(DealScene.Progress(t, plan.outro - 0.3, plan.outro)))
			cam = cam * CF.Angles(math.rad(-14 * math.max(u, c)), 0, 0)
		end
		return cam
	end

	-- the weapon: in your hand, laid on the counter, then in the customer's hand (customerHand: its
	-- right hand's CFrame, or nil to hold it in front of the customer)
	function P.Weapon(ctx: any, t: number, customerHand: any?): any
		local plan = ctx.plan
		if t < plan.place then
			return ctx.held
		end
		if t < plan.inspect then
			local u = DealScene.Progress(t, plan.place, plan.inspect)
			-- turn it on its side while it is still high, then lower it onto the counter
			local above = ctx.placed + V3.new(0, 0.9, 0)
			if u < 0.5 then
				return ctx.held:Lerp(above, smooth(u / 0.5))
			end
			return above:Lerp(ctx.placed, smooth((u - 0.5) / 0.5))
		end
		-- the same grip as AnimServer.AttachWeapon, so the server's copy takes over without a jump
		local g = cfg.CustomerGrip
		local inHand = if customerHand
			then customerHand * CF.new(0, g.y, g.z) * CF.Angles(0, math.rad(g.yaw), 0)
			else ctx.frame * CF.new(0, 1.6, -1.6) * CF.Angles(0, math.pi / 2, 0)
		local u = DealScene.Progress(t, plan.inspect, plan.inspect + cfg.HandOffSeconds)
		if u < 1 then
			-- picked straight up first, then into the customer's hands
			local lifted = ctx.placed + V3.new(0, 0.7, 0)
			if u < 0.4 then
				return ctx.placed:Lerp(lifted, smooth(u / 0.4))
			end
			return lifted:Lerp(inHand, smooth((u - 0.4) / 0.6))
		end
		return inHand
	end

	function P.Cash(ctx: any, t: number): any?
		local plan = ctx.plan
		if t < plan.pay then
			return nil
		end
		if t < plan.take then
			return ctx.cashFrom:Lerp(ctx.cashTo, smooth(DealScene.Progress(t, plan.pay, plan.take)))
		end
		if t < plan.shake then
			local u = DealScene.Progress(t, plan.take, plan.shake)
			if u < 0.4 then
				return ctx.cashTo
			end
			local lifted = ctx.cashTo + V3.new(0, 0.5, 0)
			return lifted:Lerp(ctx.countHold, smooth((u - 0.4) / 0.6))
		end
		return ctx.countHold
	end

	-- a free hand waits low, under the bottom of the screen (it only shows when it does something)
	function P.Rest(ctx: any, side: number): any
		local r = cfg.RestHand
		return palm((ctx.cam * CF.new(r.x * side, r.y, r.z)).Position, ctx.eye)
	end

	-- target palms (right, left). shakeAt: where the customer's hand is (or nil)
	function P.Hands(ctx: any, t: number, customerHand: any?): (any, any)
		local plan = ctx.plan
		local phase = DealScene.Phase(plan, t)
		local right, left = P.Rest(ctx, 1), P.Rest(ctx, -1)
		if phase == "intro" or phase == "place" then
			local w = P.Weapon(ctx, t, customerHand)
			right = palm((w * CF.new(-0.4 * S, 0.15 * S, 0)).Position + V3.new(0, 0.25, 0), ctx.eye) -- on the grip
			if phase == "place" and DealScene.Progress(t, plan.place, plan.inspect) > 0.85 then
				right = right:Lerp(P.Rest(ctx, 1), smooth((DealScene.Progress(t, plan.place, plan.inspect) - 0.85) / 0.15))
			end
		elseif phase == "take" then
			local cash = P.Cash(ctx, t) :: any -- present from the payment on
			local grab = palm(cash.Position + V3.new(0, 0.3, 0.1), ctx.eye)
			local u = DealScene.Progress(t, plan.take, plan.shake)
			left = if u < 0.4 then left:Lerp(grab, smooth(u / 0.4)) else grab
		elseif phase == "shake" then
			local meet = if customerHand then customerHand.Position else (ctx.frame * CF.new(0.15, 1.0, -0.7)).Position
			local u = DealScene.Progress(t, plan.shake, plan.count)
			local reach = smooth(math.min(1, u / 0.3)) * (1 - smooth(math.max(0, (u - 0.8) / 0.2)))
			local pump = math.sin(u * math.pi * 6) * 0.08 * reach
			local target = palm(meet + V3.new(0, pump, 0), ctx.eye) * CF.Angles(0, 0, math.rad(80))
			right = P.Rest(ctx, 1):Lerp(target, reach)
			left = palm((P.Cash(ctx, t) :: any).Position + V3.new(0, 0.25, 0), ctx.eye)
		elseif phase == "count" or phase == "outro" then
			local cash = P.Cash(ctx, t) :: any -- present from the payment on
			left = palm((cash * CF.new(0, -0.25, 0)).Position, ctx.eye)
			local flick = math.abs(math.sin(DealScene.Progress(t, plan.count, plan.outro) * math.pi * cfg.Bills))
			right = palm((cash * CF.new(0.55, 0.15 + 0.12 * flick, 0)).Position, ctx.eye)
		end
		return right, left
	end

	return P
end

return DealPoses

--!strict
-- Samples a procedural animation (Config/Animations.Procedural) at time t. Pure math:
-- the client turns the angles into Motor6D.Transform.

local Pose = {}

export type Angles = { x: number, y: number, z: number }

local function smooth(u: number): number
	return u * u * (3 - 2 * u)
end

-- Returns { [jointName]: Angles } at time t (clamped to the animation).
function Pose.Sample(def: any, t: number): { [string]: Angles }
	local keys = def.keys
	local out: { [string]: Angles } = {}
	if #keys == 0 then
		return out
	end
	t = math.clamp(t, 0, def.duration)
	local prev, nextKey = keys[1], keys[#keys]
	for i = 1, #keys - 1 do
		if t >= keys[i].t and t <= keys[i + 1].t then
			prev, nextKey = keys[i], keys[i + 1]
			break
		end
	end
	local span = nextKey.t - prev.t
	local u = if span > 0 then smooth((t - prev.t) / span) else 1
	for joint, a in prev.joints do
		local b = nextKey.joints[joint] or a
		out[joint] = {
			x = a.x + (b.x - a.x) * u,
			y = a.y + (b.y - a.y) * u,
			z = a.z + (b.z - a.z) * u,
		}
	end
	for joint, b in nextKey.joints do
		if out[joint] == nil then
			out[joint] = { x = b.x * u, y = b.y * u, z = b.z * u }
		end
	end
	return out
end

-- Blend weight 0..1: fades in at the start and out at the end.
function Pose.Weight(def: any, t: number): number
	if t <= 0 or t >= def.duration then
		return 0
	end
	local fade = def.fade or 0
	if fade <= 0 then
		return 1
	end
	return math.clamp(math.min(t / fade, (def.duration - t) / fade), 0, 1)
end

return Pose

--!strict
-- Throw math shared by the server (authoritative launch) and the client (aim
-- preview), so the preview arc matches what the server actually does.

local Config = require(script.Parent.Config)

local Ballistics = {}

-- Gravity felt by debris (see Config.DEBRIS_GRAVITY_SCALE).
function Ballistics.debrisGravity(): number
	return workspace.Gravity * Config.DEBRIS_GRAVITY_SCALE
end

-- Launch velocity of magnitude `speed` from `origin` that lands on `target`,
-- preferring the flatter arc. Returns (velocity, reachable). When the target is
-- out of range it aims toward it at Config.THROW_FALLBACK_PITCH.
function Ballistics.solve(origin: Vector3, target: Vector3, speed: number): (Vector3, boolean)
	local g = Ballistics.debrisGravity()
	local delta = target - origin
	local flat = Vector3.new(delta.X, 0, delta.Z)
	local x = flat.Magnitude
	if x < 0.05 then
		local dir = if delta.Magnitude > 0.05 then delta.Unit else Vector3.yAxis
		return dir * speed, true
	end
	local y = delta.Y
	local v2 = speed * speed
	local disc = v2 * v2 - g * (g * x * x + 2 * y * v2)
	local pitch
	local reachable = true
	if g <= 0 then
		pitch = math.atan2(y, x)
	elseif disc >= 0 then
		pitch = math.atan((v2 - math.sqrt(disc)) / (g * x))
	else
		pitch = Config.THROW_FALLBACK_PITCH
		reachable = false
	end
	return flat.Unit * (speed * math.cos(pitch)) + Vector3.yAxis * (speed * math.sin(pitch)), reachable
end

function Ballistics.positionAt(origin: Vector3, velocity: Vector3, t: number): Vector3
	return origin + velocity * t - Vector3.yAxis * (0.5 * Ballistics.debrisGravity() * t * t)
end

return Ballistics

--!strict
-- Regular hexagon math. Hexes are "pointy along local X": vertex i sits at
-- angle i * 60 degrees in the platform's local XZ plane.

local HexGeometry = {}

local SQRT3 = math.sqrt(3)

-- Local-space (X, Z) corners of a hexagon with circumradius `radius`.
function HexGeometry.corners(radius: number): { Vector2 }
	local out = {}
	for i = 0, 5 do
		local a = math.rad(60 * i)
		table.insert(out, Vector2.new(math.cos(a) * radius, math.sin(a) * radius))
	end
	return out
end

function HexGeometry.apothem(radius: number): number
	return radius * SQRT3 / 2
end

-- Is the local-space point (x, z) inside the hex?
function HexGeometry.containsLocal(radius: number, x: number, z: number): boolean
	local ax, az = math.abs(x), math.abs(z)
	return az <= radius * SQRT3 / 2 and SQRT3 * ax + az <= SQRT3 * radius
end

-- Is a world position over the hex whose center/orientation is `cf`?
-- Returns (inside, heightAboveCenter).
function HexGeometry.containsWorld(cf: CFrame, radius: number, worldPos: Vector3): (boolean, number)
	local p = cf:PointToObjectSpace(worldPos)
	return HexGeometry.containsLocal(radius, p.X, p.Z), p.Y
end

-- Uniform-ish random point inside the inscribed circle, scaled by `margin`.
function HexGeometry.randomLocalPoint(radius: number, margin: number, rng: Random): Vector2
	local r = HexGeometry.apothem(radius) * margin * math.sqrt(rng:NextNumber())
	local a = rng:NextNumber() * math.pi * 2
	return Vector2.new(math.cos(a) * r, math.sin(a) * r)
end

return HexGeometry

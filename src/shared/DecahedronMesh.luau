--!strict
-- Pentagonal trapezohedron (the d10 die shape) built with EditableMesh.
--
-- Geometry: two apexes at +/-h on the Y axis and a zig-zag belt of 10 vertices,
-- 5 "upper" at height +z (every 72 degrees) and 5 "lower" at -z (offset 36
-- degrees). All 10 faces are planar kites when h = z * (1 + cos36) / (1 - cos36).

local AssetService = game:GetService("AssetService")

local Config = require(script.Parent.Config)

local DecahedronMesh = {}

export type Kite = { Vector3 } -- 4 corners, outward-facing CCW order

-- Returns the 10 kite faces for a d10 of the given width (belt diameter).
function DecahedronMesh.kites(size: number): { Kite }
	local r = size / 2
	local c = math.cos(math.rad(36))
	local h = r -- apex height == belt radius gives a die about as tall as it is wide
	local z = h * (1 - c) / (1 + c)

	local top = Vector3.new(0, h, 0)
	local bottom = Vector3.new(0, -h, 0)
	local upper, lower = {}, {}
	for k = 0, 4 do
		local au = math.rad(72 * k)
		local al = math.rad(72 * k + 36)
		upper[k] = Vector3.new(math.cos(au) * r, z, math.sin(au) * r)
		lower[k] = Vector3.new(math.cos(al) * r, -z, math.sin(al) * r)
	end

	local kites: { Kite } = {}
	for k = 0, 4 do
		local k1 = (k + 1) % 5
		table.insert(kites, { top, upper[k], lower[k], upper[k1] })
		table.insert(kites, { bottom, lower[k], upper[k1], lower[k1] })
	end

	-- Normalise winding so (b - a) x (c - a) points away from the origin, which is
	-- the front face for Roblox's right-handed, counter-clockwise convention.
	for _, kite in kites do
		local n = (kite[2] - kite[1]):Cross(kite[3] - kite[1])
		local centroid = (kite[1] + kite[2] + kite[3] + kite[4]) / 4
		local outward = n:Dot(centroid) > 0
		if outward == Config.DEBRIS_FLIP_WINDING then
			kite[2], kite[4] = kite[4], kite[2]
		end
	end

	return kites
end

-- Builds a MeshPart from an EditableMesh. Returns nil (and warns) if
-- EditableMesh isn't available in this context, e.g. the place owner isn't
-- eligible or the memory budget is exhausted.
function DecahedronMesh.createMeshPart(size: number): MeshPart?
	local ok, result = pcall(function()
		local em = AssetService:CreateEditableMesh()
		for _, kite in DecahedronMesh.kites(size) do
			local ids = {}
			for i, v in kite do
				ids[i] = em:AddVertex(v)
			end
			local normal = (kite[2] - kite[1]):Cross(kite[3] - kite[1]).Unit
			local f1 = em:AddTriangle(ids[1], ids[2], ids[3])
			local f2 = em:AddTriangle(ids[1], ids[3], ids[4])
			-- Flat shading: give every corner of the kite the kite's normal.
			-- Wrapped separately so older EditableMesh APIs still produce a mesh.
			pcall(function()
				local nid = em:AddNormal(normal)
				em:SetFaceNormals(f1, { nid, nid, nid })
				em:SetFaceNormals(f2, { nid, nid, nid })
			end)
		end
		return AssetService:CreateMeshPartAsync(Content.fromObject(em), {
			CollisionFidelity = Enum.CollisionFidelity.Hull, -- d10 is convex, so the hull is exact
		})
	end)
	if not ok then
		warn(`[DebrisClear] EditableMesh d10 unavailable, using fallback shape: {result}`)
		return nil
	end
	-- EditableMesh vertices are already in studs, so leave Size at its natural bounds.
	return result :: MeshPart
end

-- Builds a MeshPart from an uploaded mesh asset id ("rbxassetid://...").
function DecahedronMesh.createFromAsset(assetId: string, size: number): MeshPart?
	local ok, result = pcall(function()
		return AssetService:CreateMeshPartAsync(Content.fromUri(assetId), {
			CollisionFidelity = Enum.CollisionFidelity.Hull,
		})
	end)
	if not ok then
		warn(`[DebrisClear] Could not load DEBRIS_MESH_ID {assetId}: {result}`)
		return nil
	end
	local part = result :: MeshPart
	part.Size = Vector3.new(size, size, size)
	return part
end

return DecahedronMesh

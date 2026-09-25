--!strict
-- Local rendering for every part tagged DebrisClearDebris:
--   * Visual = "Client": EditableMesh geometry doesn't replicate, so the
--     server's physics part is invisible and each client draws a d10 over it.
--   * Landing shadow: a warning disc on whatever is under a falling piece
--     (State "Loose"/"Thrown", unanchored), growing and darkening as it drops.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("DebrisClear")
local Config = require(Shared.Config)
local DecahedronMesh = require(Shared.DecahedronMesh)

type Entry = { visual: BasePart? }

local DEBRIS_TAG = "DebrisClearDebris"

-- Shadow disc: radius/transparency at LAND_SHADOW_HEIGHT (far) -> at the
-- surface (near). Height is measured from the piece's underside, so a resting
-- piece (height < SHADOW_REST_HEIGHT) shows nothing.
local MAX_SHADOWS = 40
local SHADOW_RAY_MARGIN = 5 -- studs of raycast beyond LAND_SHADOW_HEIGHT
local SHADOW_MIN_RADIUS = 0.35
local SHADOW_FAR_TRANSPARENCY = 0.75
local SHADOW_NEAR_TRANSPARENCY = 0.15
local SHADOW_REST_HEIGHT = 0.4
local SHADOW_THICKNESS = 0.1
local SHADOW_LIFT = 0.06 -- studs off the hit surface, along its normal

local DebrisVisuals = {}

local template: BasePart? = nil
local tracked: { [BasePart]: Entry } = {}
local offsets: { [BasePart]: CFrame? } = {}
local folder: Folder
local shadowPool: { BasePart } = {}
local shadowParams = RaycastParams.new()
local arenaDebris: Instance? = nil

local function getTemplate(): BasePart
	if template then
		return template
	end
	local part: BasePart? = DecahedronMesh.createMeshPart(Config.DEBRIS_SIZE)
	if not part then
		local ball = Instance.new("Part")
		ball.Shape = Enum.PartType.Ball
		ball.Size = Vector3.one * Config.DEBRIS_SIZE
		part = ball
	end
	local p = part :: BasePart
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = true
	p.Color = Config.DEBRIS_COLOR
	p.Material = Config.DEBRIS_MATERIAL
	template = p
	return p
end

local function track(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local debris = instance :: BasePart
	if tracked[debris] then
		return
	end
	local visual: BasePart? = nil
	if debris:GetAttribute("Visual") == "Client" then
		local clone = getTemplate():Clone()
		clone.CFrame = debris.CFrame
		clone.Parent = folder
		visual = clone
	end
	tracked[debris] = { visual = visual }
end

local function untrack(instance: Instance)
	local debris = instance :: BasePart
	local entry = tracked[debris]
	if entry then
		if entry.visual then
			entry.visual:Destroy()
		end
		tracked[debris] = nil
	end
	offsets[debris] = nil
end

---------------------------------------------------------------------------
-- Landing shadows
---------------------------------------------------------------------------
local function shadowDisc(index: number): BasePart
	local disc = shadowPool[index]
	if disc then
		return disc
	end
	local part = Instance.new("Part")
	part.Name = "LandShadow"
	part.Shape = Enum.PartType.Cylinder
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = Config.LAND_SHADOW_COLOR
	part.Transparency = 1
	part.Parent = folder
	shadowPool[index] = part
	return part
end

-- Only pieces in the air can cast a warning; the showcase piece is anchored.
local function wantsShadow(debris: BasePart): boolean
	if debris.Anchored then
		return false
	end
	local state = debris:GetAttribute("State")
	return state == nil or state == "Loose" or state == "Thrown"
end

-- Exclude debris (physics parts and our d10s) and every character so the ray
-- finds the surface the piece will actually land on.
local function refreshShadowFilter()
	local ignore: { Instance } = { folder }
	if not arenaDebris or not arenaDebris.Parent then
		local arena = workspace:FindFirstChild("DebrisClearArena")
		arenaDebris = arena and arena:FindFirstChild("Debris")
	end
	if arenaDebris then
		table.insert(ignore, arenaDebris)
	end
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	shadowParams.FilterDescendantsInstances = ignore
end

-- Cylinder parts lie along X; point that axis down the surface normal.
local function surfaceFrame(position: Vector3, normal: Vector3): CFrame
	local reference = if math.abs(normal.Y) < 0.9 then Vector3.yAxis else Vector3.zAxis
	return CFrame.fromMatrix(position, normal, reference:Cross(normal).Unit)
end

-- Places disc `index` under `debris`; false when there is nothing to show.
local function placeShadow(debris: BasePart, index: number): boolean
	local origin = debris.Position
	local reach = Config.LAND_SHADOW_HEIGHT + SHADOW_RAY_MARGIN
	local hit = workspace:Raycast(origin, Vector3.new(0, -reach, 0), shadowParams)
	if not hit then
		return false
	end
	local height = math.max(0, hit.Distance - debris.Size.Y / 2)
	if height < SHADOW_REST_HEIGHT then
		return false
	end
	-- t = 1 far away, 0 about to land.
	local t = math.clamp(height / Config.LAND_SHADOW_HEIGHT, 0, 1)
	local radius = Config.LAND_SHADOW_MAX_RADIUS + (SHADOW_MIN_RADIUS - Config.LAND_SHADOW_MAX_RADIUS) * t
	local disc = shadowDisc(index)
	disc.Size = Vector3.new(SHADOW_THICKNESS, radius * 2, radius * 2)
	disc.Transparency = SHADOW_NEAR_TRANSPARENCY + (SHADOW_FAR_TRANSPARENCY - SHADOW_NEAR_TRANSPARENCY) * t
	disc.CFrame = surfaceFrame(hit.Position + hit.Normal * SHADOW_LIFT, hit.Normal)
	return true
end

local function hideShadows(fromIndex: number)
	for i = fromIndex, #shadowPool do
		shadowPool[i].Transparency = 1
	end
end

---------------------------------------------------------------------------
-- Public
---------------------------------------------------------------------------
-- The locally rendered d10 for a server debris part, if it has one.
function DebrisVisuals.visualFor(debris: BasePart): BasePart?
	local entry = tracked[debris]
	return entry and entry.visual
end

-- Cosmetic offset applied to a piece's local visual (throw wind-up etc.).
-- nil clears it.
function DebrisVisuals.setOffset(debris: BasePart, offset: CFrame?)
	offsets[debris] = offset
end

function DebrisVisuals.start()
	folder = Instance.new("Folder")
	folder.Name = "DebrisClearLocalVisuals"
	folder.Parent = workspace
	shadowParams.FilterType = Enum.RaycastFilterType.Exclude
	getTemplate() -- build once up front; CreateMeshPartAsync yields

	CollectionService:GetInstanceAddedSignal(DEBRIS_TAG):Connect(track)
	CollectionService:GetInstanceRemovedSignal(DEBRIS_TAG):Connect(untrack)
	for _, instance in CollectionService:GetTagged(DEBRIS_TAG) do
		track(instance)
	end

	RunService.RenderStepped:Connect(function()
		local shadows = 0
		local filterReady = false
		for debris, entry in tracked do
			if not debris.Parent then
				untrack(debris)
				continue
			end
			local visual = entry.visual
			if visual then
				local offset = offsets[debris]
				visual.CFrame = if offset then debris.CFrame * offset else debris.CFrame
			end
			if Config.LAND_SHADOW_ENABLED and shadows < MAX_SHADOWS and wantsShadow(debris) then
				if not filterReady then
					refreshShadowFilter()
					filterReady = true
				end
				if placeShadow(debris, shadows + 1) then
					shadows += 1
				end
			end
		end
		hideShadows(shadows + 1)
	end)
end

return DebrisVisuals

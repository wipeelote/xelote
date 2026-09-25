--!strict
-- Spawns d10 debris over each live platform, owns their physics, and decides
-- which platform (if any) each piece has landed on.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("DebrisClear")
local Config = require(Shared.Config)
local DecahedronMesh = require(Shared.DecahedronMesh)
local HexGeometry = require(Shared.HexGeometry)
local Arena = require(script.Parent.Arena)
local LoadService = require(script.Parent.LoadService)

type Platform = Arena.Platform

export type DebrisRecord = {
	part: BasePart,
	prompt: ProximityPrompt,
	antiGravity: VectorForce,
	landedOn: Platform?,
	heldBy: Player?,
	thrownBy: Player?,
	thrownAt: number,
	throwVelocity: Vector3,
	hitDone: boolean,
}

local DEBRIS_TAG = "DebrisClearDebris"

local DebrisService = {}

local records: { [BasePart]: DebrisRecord } = {}
local template: BasePart? = nil
local rng = Random.new()
local roundId = 0
local scanAccumulator = 0

-- Set by ThrowService so this module doesn't need to require it.
DebrisService.onPromptTriggered = nil :: ((player: Player, part: BasePart) -> ())?
DebrisService.onDebrisTouched = nil :: ((record: DebrisRecord, hit: BasePart) -> ())?

local function buildTemplate(): BasePart
	local size = Config.DEBRIS_SIZE
	local part: BasePart? = nil
	local visual = "Server"

	if Config.DEBRIS_MESH_ID ~= "" then
		part = DecahedronMesh.createFromAsset(Config.DEBRIS_MESH_ID, size)
	end
	if not part then
		part = DecahedronMesh.createMeshPart(size)
		if part then
			-- EditableMesh geometry doesn't replicate, so the server part only
			-- supplies physics; each client draws its own d10 on top of it.
			visual = "Client"
		end
	end
	if not part then
		local ball = Instance.new("Part")
		ball.Shape = Enum.PartType.Ball
		ball.Size = Vector3.new(size, size, size)
		part = ball
		visual = "Client"
	end

	local p = part :: BasePart
	p.Name = "Debris"
	p.Color = Config.DEBRIS_COLOR
	p.Material = Config.DEBRIS_MATERIAL
	p.Transparency = if visual == "Client" then 1 else 0
	p.CustomPhysicalProperties = PhysicalProperties.new(
		Config.DEBRIS_DENSITY,
		Config.DEBRIS_FRICTION,
		Config.DEBRIS_ELASTICITY
	)
	p.Anchored = false
	p:SetAttribute("Visual", visual)

	local attachment = Instance.new("Attachment")
	attachment.Name = "Center"
	attachment.Parent = p

	-- Partial gravity cancel so a 60 stud/s throw can reach rival platforms.
	local force = Instance.new("VectorForce")
	force.Name = "AntiGravity"
	force.RelativeTo = Enum.ActuatorRelativeTo.World
	force.ApplyAtCenterOfMass = true
	force.Attachment0 = attachment
	force.Parent = p

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PickupPrompt"
	prompt.ActionText = "Pick up"
	prompt.ObjectText = "Debris"
	prompt.KeyboardKeyCode = Config.PICKUP_KEY
	prompt.GamepadKeyCode = Config.PICKUP_GAMEPAD_KEY
	-- Custom style: the engine still handles key/gamepad input and picks the
	-- closest prompt in range, but the client draws its own Grab button and
	-- highlight (see client InteractionController).
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.MaxActivationDistance = Config.PICKUP_RANGE
	prompt.HoldDuration = Config.PICKUP_HOLD_DURATION
	prompt.RequiresLineOfSight = false
	prompt.Parent = p
	return p
end

function DebrisService.init()
	template = buildTemplate()

	RunService.Heartbeat:Connect(function(dt)
		scanAccumulator += dt
		if scanAccumulator >= Config.LAND_SCAN_INTERVAL then
			scanAccumulator = 0
			DebrisService.scan()
		end
	end)
end

function DebrisService.get(part: BasePart): DebrisRecord?
	return records[part]
end

function DebrisService.count(): number
	local n = 0
	for _ in records do
		n += 1
	end
	return n
end

local function setLanded(record: DebrisRecord, platform: Platform?)
	if record.landedOn == platform then
		return
	end
	if record.landedOn then
		LoadService.addLoad(record.landedOn, -Config.LOAD_PER_DEBRIS)
	end
	record.landedOn = platform
	if platform then
		LoadService.addLoad(platform, Config.LOAD_PER_DEBRIS)
	end
end

function DebrisService.destroy(part: BasePart)
	local record = records[part]
	if record then
		setLanded(record, nil)
		records[part] = nil
	end
	part:Destroy()
end

local function updateAntiGravity(record: DebrisRecord)
	local part = record.part
	local lift = if record.heldBy then 0 else part:GetMass() * workspace.Gravity * (1 - Config.DEBRIS_GRAVITY_SCALE)
	record.antiGravity.Force = Vector3.new(0, lift, 0)
end

function DebrisService.spawnAt(position: Vector3): BasePart?
	if not template or DebrisService.count() >= Config.MAX_DEBRIS_TOTAL then
		return nil
	end
	local part = (template :: BasePart):Clone()
	part.CFrame = CFrame.new(position)
		* CFrame.Angles(rng:NextNumber() * math.pi * 2, rng:NextNumber() * math.pi * 2, rng:NextNumber() * math.pi * 2)
	part.Parent = Arena.debrisFolder()
	part:SetNetworkOwner(nil) -- server-authoritative physics
	part.AssemblyAngularVelocity = rng:NextUnitVector() * 3

	local record: DebrisRecord = {
		part = part,
		prompt = part:FindFirstChild("PickupPrompt") :: ProximityPrompt,
		antiGravity = part:FindFirstChild("AntiGravity") :: VectorForce,
		landedOn = nil,
		heldBy = nil,
		thrownBy = nil,
		thrownAt = 0,
		throwVelocity = Vector3.zero,
		hitDone = true,
	}
	records[part] = record
	updateAntiGravity(record)
	CollectionService:AddTag(part, DEBRIS_TAG)

	record.prompt.Triggered:Connect(function(player)
		local handler = DebrisService.onPromptTriggered
		if handler then
			handler(player, part)
		end
	end)
	part.Touched:Connect(function(hit)
		local handler = DebrisService.onDebrisTouched
		if handler and record.thrownBy and not record.hitDone then
			handler(record, hit)
		end
	end)
	return part
end

-- Called by ThrowService when a player grabs a piece. Removes it from any
-- platform's load immediately.
function DebrisService.markHeld(record: DebrisRecord, player: Player)
	setLanded(record, nil)
	record.heldBy = player
	record.thrownBy = nil
	record.hitDone = true
	record.prompt.Enabled = false
	record.part.CanCollide = false
	record.part.Massless = true
	updateAntiGravity(record)
end

function DebrisService.markReleased(record: DebrisRecord, thrower: Player?, velocity: Vector3?)
	record.heldBy = nil
	record.prompt.Enabled = true
	record.part.CanCollide = true
	record.part.Massless = false
	updateAntiGravity(record)
	if thrower and velocity then
		record.thrownBy = thrower
		record.thrownAt = os.clock()
		record.throwVelocity = velocity
		record.hitDone = false
	end
end

-- Which live platform is this position resting on, if any?
local function platformUnder(position: Vector3): Platform?
	for _, platform in Arena.platforms do
		if not platform.dropped and LoadService.isActive(platform) then
			local inside, height = Arena.isOver(platform, position)
			if inside and height >= -1 and height <= Config.LAND_HEIGHT_BAND then
				return platform
			end
		end
	end
	return nil
end

function DebrisService.scan()
	local killY = Arena.killY()
	local now = os.clock()
	for part, record in records do
		if not part.Parent then
			setLanded(record, nil)
			records[part] = nil
			continue
		end
		if record.heldBy then
			continue
		end
		local position = part.Position
		if position.Y < killY then
			DebrisService.destroy(part)
			continue
		end
		if record.thrownBy and now - record.thrownAt > Config.THROW_HIT_WINDOW then
			record.hitDone = true
		end

		local under = platformUnder(position)
		if record.landedOn and under ~= record.landedOn then
			-- Slid, rolled or got knocked off.
			setLanded(record, nil)
		end
		if not record.landedOn and under and part.AssemblyLinearVelocity.Magnitude <= Config.LAND_MAX_SPEED then
			record.thrownBy = nil
			record.hitDone = true
			setLanded(record, under)
		end
	end
end

local function spawnLoop(platform: Platform, myRound: number)
	while roundId == myRound and LoadService.isActive(platform) do
		task.wait(rng:NextNumber(Config.SPAWN_INTERVAL_MIN, Config.SPAWN_INTERVAL_MAX))
		if roundId ~= myRound or not LoadService.isActive(platform) then
			break
		end
		local offset = HexGeometry.randomLocalPoint(Config.PLATFORM_RADIUS, Config.SPAWN_EDGE_MARGIN, rng)
		local position = platform.topCFrame:PointToWorldSpace(Vector3.new(offset.X, Config.SPAWN_HEIGHT, offset.Y))
		DebrisService.spawnAt(position)
	end
end

function DebrisService.startRound(platforms: { Platform })
	roundId += 1
	for _, platform in platforms do
		task.spawn(spawnLoop, platform, roundId)
	end
end

-- Destroys every loose piece over a crushed platform's footprint.
function DebrisService.crushPlatform(platform: Platform)
	for part, record in records do
		if record.heldBy then
			continue
		end
		local inside = HexGeometry.containsWorld(platform.topCFrame, Config.PLATFORM_RADIUS, part.Position)
		if record.landedOn == platform or inside then
			DebrisService.destroy(part)
		end
	end
end

function DebrisService.stopRound()
	roundId += 1
	for part in records do
		DebrisService.destroy(part)
	end
end

return DebrisService

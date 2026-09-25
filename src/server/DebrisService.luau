--!strict
-- Spawns d10 debris over each live platform, owns their physics, and decides
-- which platform (if any) each piece has landed on.
--
-- Every piece carries a replicated "State" attribute for client visuals:
--   "Loose"   falling, or resting somewhere that doesn't count
--   "Held"    welded to a player
--   "Thrown"  in flight after a throw, until it settles
--   "Landed"  counting toward a platform's load

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("DebrisClear")
local Config = require(Shared.Config)
local DecahedronMesh = require(Shared.DecahedronMesh)
local HexGeometry = require(Shared.HexGeometry)
local Remotes = require(Shared.Remotes)
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
	-- Landing hysteresis: the platform the piece has been resting over since
	-- settleSince, and when a landed piece was first seen off its platform.
	settleOn: Platform?,
	settleSince: number,
	unsettleSince: number?,
	trail: Trail?,
	-- Flung off a crushed platform; never counts again.
	doomed: boolean,
}

local DEBRIS_TAG = "DebrisClearDebris"
local TRAIL_HALF_WIDTH = 0.8 -- studs from the piece center to each trail attachment
local CRUSH_SCATTER_SPREAD = 0.35 -- horizontal jitter per unit of downward fling
local CRUSH_SCATTER_SPIN = 10 -- rad/s of random tumble on a flung piece

local DebrisService = {}

local records: { [BasePart]: DebrisRecord } = {}
local template: BasePart? = nil
local rng = Random.new()
local roundId = 0
local roundStartedAt = 0
local scanAccumulator = 0
local effectsRemote: RemoteEvent

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
	effectsRemote = Remotes.get("Effects")

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

local function setState(record: DebrisRecord, state: string)
	record.part:SetAttribute("State", state)
end

local function clearTrail(record: DebrisRecord)
	local trail = record.trail
	if not trail then
		return
	end
	record.trail = nil
	local a0, a1 = trail.Attachment0, trail.Attachment1
	trail:Destroy()
	if a0 then
		a0:Destroy()
	end
	if a1 then
		a1:Destroy()
	end
end

-- Default ribbon (no texture) fading from the debris color to white.
local function attachTrail(record: DebrisRecord)
	clearTrail(record)
	local part = record.part
	local a0 = Instance.new("Attachment")
	a0.Name = "TrailLeft"
	a0.Position = Vector3.new(TRAIL_HALF_WIDTH, 0, 0)
	a0.Parent = part
	local a1 = Instance.new("Attachment")
	a1.Name = "TrailRight"
	a1.Position = Vector3.new(-TRAIL_HALF_WIDTH, 0, 0)
	a1.Parent = part

	local trail = Instance.new("Trail")
	trail.Name = "ThrowTrail"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = Config.THROW_TRAIL_LIFETIME
	trail.Color = ColorSequence.new(Config.DEBRIS_COLOR, Color3.new(1, 1, 1))
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.WidthScale = NumberSequence.new(1, 0)
	trail.LightEmission = 0.5
	trail.FaceCamera = true
	trail.Parent = part
	record.trail = trail

	-- Safety net: a piece that never settles still loses its trail.
	task.delay(Config.THROW_HIT_WINDOW * 2, function()
		if record.trail == trail then
			clearTrail(record)
		end
	end)
end

-- Moves the piece's load between platforms. Callers set the "State" attribute.
local function setLanded(record: DebrisRecord, platform: Platform?)
	if record.landedOn == platform then
		return
	end
	if record.landedOn then
		LoadService.addLoad(record.landedOn, -Config.LOAD_PER_DEBRIS)
	end
	record.landedOn = platform
	record.unsettleSince = nil
	if platform then
		LoadService.addLoad(platform, Config.LOAD_PER_DEBRIS)
	end
end

-- The piece has sat still on a live platform long enough: count it.
local function land(record: DebrisRecord, platform: Platform)
	record.thrownBy = nil
	record.hitDone = true
	clearTrail(record)
	setLanded(record, platform)
	setState(record, "Landed")
	effectsRemote:FireAllClients("Land", record.part.Position, platform.slot)
end

function DebrisService.destroy(part: BasePart)
	local record = records[part]
	if record then
		clearTrail(record)
		setLanded(record, nil)
		records[part] = nil
	end
	part:Destroy()
end

local function updateAntiGravity(record: DebrisRecord)
	local part = record.part
	local lift = if record.heldBy or record.doomed
		then 0
		else part:GetMass() * workspace.Gravity * (1 - Config.DEBRIS_GRAVITY_SCALE)
	record.antiGravity.Force = Vector3.new(0, lift, 0)
end

function DebrisService.spawnAt(position: Vector3): BasePart?
	if not template or DebrisService.count() >= Config.MAX_DEBRIS_TOTAL then
		return nil
	end
	local part = (template :: BasePart):Clone()
	part.CFrame = CFrame.new(position)
		* CFrame.Angles(rng:NextNumber() * math.pi * 2, rng:NextNumber() * math.pi * 2, rng:NextNumber() * math.pi * 2)
	part:SetAttribute("State", "Loose")
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
		settleOn = nil,
		settleSince = 0,
		unsettleSince = nil,
		trail = nil,
		doomed = false,
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
	record.settleOn = nil
	clearTrail(record)
	record.prompt.Enabled = false
	record.part.CanCollide = false
	record.part.Massless = true
	updateAntiGravity(record)
	setState(record, "Held")
end

function DebrisService.markReleased(record: DebrisRecord, thrower: Player?, velocity: Vector3?)
	record.heldBy = nil
	record.settleOn = nil
	record.prompt.Enabled = true
	record.part.CanCollide = true
	record.part.Massless = false
	updateAntiGravity(record)
	if thrower and velocity then
		record.thrownBy = thrower
		record.thrownAt = os.clock()
		record.throwVelocity = velocity
		record.hitDone = false
		attachTrail(record)
		setState(record, "Thrown")
	else
		setState(record, "Loose")
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
			clearTrail(record)
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
		if record.doomed then
			continue
		end
		if record.thrownBy and now - record.thrownAt > Config.THROW_HIT_WINDOW then
			-- Too late to hit anyone.
			record.hitDone = true
		end
		-- "Thrown" lasts until the piece actually slows (or the trail's safety
		-- net expires), not just until the hit window closes.
		if part:GetAttribute("State") == "Thrown"
			and (part.AssemblyLinearVelocity.Magnitude <= Config.LAND_MAX_SPEED
				or now - record.thrownAt > Config.THROW_HIT_WINDOW * 2) then
			setState(record, "Loose")
		end

		-- Settle timer: how long the piece has sat still over one platform.
		local under = platformUnder(position)
		local resting = under ~= nil and part.AssemblyLinearVelocity.Magnitude <= Config.LAND_MAX_SPEED
		if not resting then
			record.settleOn = nil
		elseif under ~= record.settleOn then
			record.settleOn = under
			record.settleSince = now
		end

		-- Unsettle timer: how long a landed piece has been off its platform.
		local landedOn = record.landedOn
		if landedOn then
			if under == landedOn then
				record.unsettleSince = nil
			else
				local since = record.unsettleSince or now
				record.unsettleSince = since
				if now - since >= Config.LAND_UNSETTLE_TIME then
					-- Slid, rolled or got knocked off.
					setLanded(record, nil)
					setState(record, "Loose")
				end
			end
		end

		local settleOn = record.settleOn
		if not record.landedOn and settleOn and now - record.settleSince >= Config.LAND_SETTLE_TIME then
			land(record, settleOn)
		end
	end
end

-- Pressure curve: spawn gaps shrink from the start values to the *_END values
-- over SPAWN_RAMP_TIME, then hold.
local function nextSpawnInterval(): number
	local ramp = Config.SPAWN_RAMP_TIME
	local t = if ramp > 0 then math.clamp((os.clock() - roundStartedAt) / ramp, 0, 1) else 1
	local min = Config.SPAWN_INTERVAL_MIN + (Config.SPAWN_INTERVAL_MIN_END - Config.SPAWN_INTERVAL_MIN) * t
	local max = Config.SPAWN_INTERVAL_MAX + (Config.SPAWN_INTERVAL_MAX_END - Config.SPAWN_INTERVAL_MAX) * t
	return rng:NextNumber(min, max)
end

local function spawnLoop(platform: Platform, myRound: number)
	while roundId == myRound and LoadService.isActive(platform) do
		task.wait(nextSpawnInterval())
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
	roundStartedAt = os.clock()
	for _, platform in platforms do
		task.spawn(spawnLoop, platform, roundId)
	end
end

-- Flings a piece off a crushed platform into the lava. It never counts again;
-- the kill-line check in scan() destroys it once it drops below killY.
local function doom(record: DebrisRecord)
	setLanded(record, nil)
	record.doomed = true
	record.thrownBy = nil
	record.hitDone = true
	record.settleOn = nil
	clearTrail(record)
	setState(record, "Loose")
	record.prompt.Enabled = false
	updateAntiGravity(record)

	local part = record.part
	part.CanTouch = false
	local direction = Vector3.new(
		rng:NextNumber(-CRUSH_SCATTER_SPREAD, CRUSH_SCATTER_SPREAD),
		-1,
		rng:NextNumber(-CRUSH_SCATTER_SPREAD, CRUSH_SCATTER_SPREAD)
	).Unit
	part.AssemblyLinearVelocity = direction * Config.CRUSH_SCATTER_SPEED
	part.AssemblyAngularVelocity = rng:NextUnitVector() * CRUSH_SCATTER_SPIN
end

-- Scatters every loose piece over a crushed platform's footprint into the pit.
function DebrisService.crushPlatform(platform: Platform)
	for part, record in records do
		if record.heldBy or record.doomed then
			continue
		end
		local inside = HexGeometry.containsWorld(platform.topCFrame, Config.PLATFORM_RADIUS, part.Position)
		if record.landedOn == platform or inside then
			doom(record)
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

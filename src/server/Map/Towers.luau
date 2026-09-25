--!strict
-- Nine tall towers fanning around the stage behind the pit, "made of ball":
-- every part reads Config.DEBRIS_COLOR at build time. Also the overhead truss
-- rig (16-gon of trusses, a colored spot and a white key on every deck) and
-- the PIT CAM jib hanging over the lava. Builds models "Towers" and "Rig"
-- under `parent`; the rig lives here because it only needs Config.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("DebrisClear")
local Config = require(Shared.Config)
local MapKit = require(script.Parent.MapKit)

local Towers = {}

type TowerSpec = { name: string, x: number, z: number, height: number }
type SpotSpec = { angle: number, brightness: number, range: number }

-- X/Z are relative to the pit center (Config.ARENA_CENTER); Y values are world.
local TUNING = {
	-- Stage top the towers stand on (Pit's StageGround).
	STAGE_TOP_Y = 36, -- PLACEHOLDER
	-- Base center and body height per tower. The fan rises toward the back of
	-- the set (T8 tallest, dead center behind the pit); the 90-degree slot
	-- between hub and pit stays empty. Bodies must stay outside |X| <= 32 near
	-- the hub (sight fan) and outside radius 40 (hex columns).
	TOWERS = { -- PLACEHOLDER
		{ name = "T1", x = 78, z = 0, height = 85 },
		{ name = "T2", x = 67.5, z = 39, height = 75 },
		{ name = "T3", x = 44, z = 70, height = 65 },
		{ name = "T4", x = -44, z = 70, height = 65 },
		{ name = "T5", x = -67.5, z = 39, height = 75 },
		{ name = "T6", x = -78, z = 0, height = 85 },
		{ name = "T7", x = -58, z = -58, height = 95 },
		{ name = "T8", x = 0, z = -78, height = 110 },
		{ name = "T9", x = 58, z = -58, height = 95 },
	},
	PLINTH_RADIUS = 6, -- PLACEHOLDER
	PLINTH_HEIGHT = 2, -- PLACEHOLDER: top at 38, under the kill line (40)
	BODY_RADIUS = 4, -- PLACEHOLDER
	RING_RADIUS = 4.5, -- PLACEHOLDER
	RING_THICKNESS = 0.7, -- PLACEHOLDER
	RING_SPACING = 20, -- PLACEHOLDER: first ring this far above the plinth, then one per spacing below the top
	CAP_RADIUS = 4.6, -- PLACEHOLDER
	CAP_THICKNESS = 1.6, -- PLACEHOLDER
	PLINTH_LIGHT = { brightness = 1.5, range = 30 }, -- PLACEHOLDER: magenta pool on the stage
	-- No cap PointLight: the Neon cap and the searchlight Beam (LightEmission 1)
	-- carry the glow, keeping the module at 18 lights and magenta off the hub.
	SEARCHLIGHT = { height = 140, width0 = 7, width1 = 0.5 }, -- PLACEHOLDER: beam rising from each cap

	-- Truss ring over the arena.
	RIG_RADIUS = 51, -- PLACEHOLDER: clears the hex columns (r <= 40)
	RIG_Y = 104, -- PLACEHOLDER: ring bottom 103, above the throw apex (~94) and every hub sight line
	RIG_SEGMENTS = 16, -- PLACEHOLDER
	TRUSS_SIZE = Vector3.new(2, 2, 20), -- PLACEHOLDER: Z ~ chord length; every axis a multiple of 2
	JOINT_SIZE = 1.6, -- PLACEHOLDER: neon cube hiding each segment overlap
	FIXTURE_Y = 102.2, -- PLACEHOLDER: fixtures hang under the odd vertices
	FIXTURE_SIZE = Vector3.new(1.4, 1.4, 2.2), -- PLACEHOLDER
	FIXTURE_OFFSET_DEG = 22.5, -- PLACEHOLDER: color spot at slot angle - this, key spot at slot angle + this
	COLOR_SPOT = { angle = 38, brightness = 5, range = 60 }, -- PLACEHOLDER
	KEY_SPOT = { angle = 48, brightness = 3, range = 60 }, -- PLACEHOLDER

	-- PIT CAM jib: arm from the 270-degree joint inward over the pit, head
	-- hanging under its end, aimed at the LavaHeart.
	JIB_ARM_CENTER = Vector3.new(0, 104, -35), -- PLACEHOLDER: spans Z -51..-19; |X| <= 1 clears the hex corners at 8.2
	JIB_ARM_SIZE = Vector3.new(2, 2, 32), -- PLACEHOLDER
	JIB_HEAD_POSITION = Vector3.new(0, 102.5, -18), -- PLACEHOLDER
	JIB_HEAD_SIZE = Vector3.new(3, 2.5, 4), -- PLACEHOLDER
	JIB_TARGET_Y = 15.65, -- PLACEHOLDER: LavaHeart top (Pit P3); the head looks at it
	LENS_RADIUS = 1.2, -- PLACEHOLDER
	LENS_LENGTH = 2.5, -- PLACEHOLDER
	LENS_OFFSET = 3, -- PLACEHOLDER: lens center ahead of the head center, along the look
	TALLY_SIZE = 0.6, -- PLACEHOLDER
	TALLY_OFFSET = Vector3.new(0, 1.55, 0.5), -- PLACEHOLDER: head-local, on the head top
	-- The head is ~89 studs from the heart, beyond a light's 60-stud Range cap,
	-- so the spot itself sits on an invisible emitter straight above the heart
	-- (top of the LavaHeart + 56 studs), pointing down. At Angle 22 the pool
	-- radius is ~11.7 studs, matching the 12-stud heart.
	PITCAM_EMITTER_Y = 72, -- PLACEHOLDER: world Y of the invisible spot emitter over the pit center
	PITCAM_SPOT = { angle = 22, brightness = 2, range = 60 }, -- PLACEHOLDER: Range 60 is the Roblox maximum
	TALLY_BLINK = { period = 1.2, maxT = 0.7 }, -- PLACEHOLDER
}

-- Trim nothing may rest on (rings, caps, joints, tally): never collidable,
-- never queried, never touched, no shadow.
local function trim(props: MapKit.Props): MapKit.Props
	props.CanCollide = false
	props.CanQuery = false
	props.CanTouch = false
	props.CastShadow = false
	return props
end

local function towerProps(name: string, material: Enum.Material): MapKit.Props
	return { Name = name, Color = Config.DEBRIS_COLOR, Material = material }
end

local function housing(name: string): MapKit.Props
	return { Name = name, Color = Config.MAP.FIXTURE_GREY, Material = Enum.Material.SmoothPlastic }
end

local function trussProps(name: string, size: Vector3, cf: CFrame): MapKit.Props
	return {
		Name = name,
		Size = size,
		CFrame = cf,
		Style = Enum.Style.BridgeStyleSupports,
		Color = Config.MAP.STUDIO_GREY,
		Material = Enum.Material.SmoothPlastic,
	}
end

-- Plinth, body, rings, cap (+ plinth/cap lights and the searchlight beam).
local function buildTower(spec: TowerSpec, parent: Instance)
	local c = Config.ARENA_CENTER
	local trimMaterial = if Config.TOWER_NEON_TRIM then Enum.Material.Neon else Config.DEBRIS_MATERIAL
	local tower = MapKit.model(spec.name, parent)
	local x, z = c.X + spec.x, c.Z + spec.z
	local base = Vector3.new(x, TUNING.STAGE_TOP_Y, z)
	local bodyBase = base + Vector3.new(0, TUNING.PLINTH_HEIGHT, 0)
	local top = bodyBase.Y + spec.height

	local plinth = MapKit.column(base, TUNING.PLINTH_HEIGHT, TUNING.PLINTH_RADIUS, towerProps("Plinth", Config.DEBRIS_MATERIAL))
	plinth.Parent = tower
	MapKit.pointLight(plinth, Config.DEBRIS_COLOR, TUNING.PLINTH_LIGHT.brightness, TUNING.PLINTH_LIGHT.range)

	-- The body collides: stray debris bounces off and dies below the kill line.
	MapKit.column(bodyBase, spec.height, TUNING.BODY_RADIUS, towerProps("Body", Config.DEBRIS_MATERIAL)).Parent = tower

	-- Rings up the body, stopping short of the cap.
	local y = bodyBase.Y + TUNING.RING_SPACING
	while y < top do
		MapKit.disc(CFrame.new(x, y, z), TUNING.RING_RADIUS, TUNING.RING_THICKNESS, trim(towerProps("Ring", trimMaterial))).Parent = tower
		y += TUNING.RING_SPACING
	end

	local cap = MapKit.disc(
		CFrame.new(x, top + TUNING.CAP_THICKNESS / 2, z),
		TUNING.CAP_RADIUS,
		TUNING.CAP_THICKNESS,
		trim(towerProps("Cap", trimMaterial))
	)
	cap.Parent = tower
	-- After parenting: the beam's top attachment is placed in world space.
	MapKit.beamUp(cap, TUNING.SEARCHLIGHT.height, TUNING.SEARCHLIGHT.width0, TUNING.SEARCHLIGHT.width1, Config.DEBRIS_COLOR)
end

-- Truss ring with its joints and spot fixtures, plus the PIT CAM jib.
local function buildRig(parent: Instance)
	local c = Config.ARENA_CENTER
	local flat = Vector3.new(c.X, 0, c.Z)
	local model = MapKit.model("Rig", parent)

	local function onRing(angleDeg: number, y: number): Vector3
		local a = math.rad(angleDeg)
		return Vector3.new(c.X + math.cos(a) * TUNING.RIG_RADIUS, y, c.Z + math.sin(a) * TUNING.RIG_RADIUS)
	end

	-- Polygon of trusses, each running along its chord; a neon joint cube at
	-- every vertex hides where the segments overlap.
	local step = 360 / TUNING.RIG_SEGMENTS
	for k = 0, TUNING.RIG_SEGMENTS - 1 do
		local a, b = onRing(k * step, TUNING.RIG_Y), onRing((k + 1) * step, TUNING.RIG_Y)
		MapKit.truss(trussProps("TrussRing", TUNING.TRUSS_SIZE, CFrame.lookAt((a + b) / 2, b))).Parent = model
		MapKit.block(CFrame.new(a), Vector3.one * TUNING.JOINT_SIZE, trim({
			Name = "TrussJoint",
			Color = Config.MAP.ELECTRIC_CYAN,
			Material = Enum.Material.Neon,
		})).Parent = model
	end

	local function spotFixture(angleDeg: number, target: Vector3, color: Color3, spot: SpotSpec)
		local fixture = MapKit.block(CFrame.lookAt(onRing(angleDeg, TUNING.FIXTURE_Y), target), TUNING.FIXTURE_SIZE, housing("SpotFixture"))
		fixture.Parent = model
		MapKit.spotLight(fixture, Enum.NormalId.Front, color, spot.angle, spot.brightness, spot.range)
	end

	-- A colored spot and a white key on every deck, from the odd vertices either
	-- side of the slot angle (same slot math as Arena.buildPlatform).
	for slot = 1, Config.MAX_PLAYERS do
		local slotAngle = 45 + 90 * (slot - 1)
		local a = math.rad(slotAngle)
		local deck = c + Vector3.new(math.cos(a), 0, math.sin(a)) * Config.ARENA_RADIUS
		spotFixture(slotAngle - TUNING.FIXTURE_OFFSET_DEG, deck, Config.PLATFORM_COLORS[slot], TUNING.COLOR_SPOT)
		spotFixture(slotAngle + TUNING.FIXTURE_OFFSET_DEG, deck, Config.MAP.KEY_WHITE, TUNING.KEY_SPOT)
	end

	-- PIT CAM: the head/lens/tally hang under the jib looking at the LavaHeart;
	-- the spot that pools on the heart is emitted from closer in (see below).
	local jib = MapKit.model("PitCam", model)
	MapKit.truss(trussProps("PitCamArm", TUNING.JIB_ARM_SIZE, CFrame.new(flat + TUNING.JIB_ARM_CENTER))).Parent = jib

	local target = flat + Vector3.new(0, TUNING.JIB_TARGET_Y, 0)
	local headCF = CFrame.lookAt(flat + TUNING.JIB_HEAD_POSITION, target)
	local head = MapKit.block(headCF, TUNING.JIB_HEAD_SIZE, housing("PitCamHead"))
	head.Parent = jib
	MapKit.surfaceText(head, Enum.NormalId.Right, "PIT CAM", {
		Font = Enum.Font.Gotham,
		TextColor3 = Config.MAP.ELECTRIC_CYAN,
	})

	-- Lens barrel along the look (the cylinder axis is local Y; tip it onto -Z).
	MapKit.cylinder(
		headCF * CFrame.new(0, 0, -TUNING.LENS_OFFSET) * CFrame.Angles(-math.pi / 2, 0, 0),
		TUNING.LENS_LENGTH,
		TUNING.LENS_RADIUS,
		housing("PitCamLens")
	).Parent = jib

	local tally = MapKit.block(headCF * CFrame.new(TUNING.TALLY_OFFSET), Vector3.one * TUNING.TALLY_SIZE, trim({
		Name = "PitCamTally",
		Color = Config.DEBRIS_COLOR,
		Material = Enum.Material.Neon,
	}))
	tally.Parent = jib
	MapKit.blink(tally, TUNING.TALLY_BLINK.period, TUNING.TALLY_BLINK.maxT)

	-- The spot's real source: an invisible, untouchable 1-stud part in the open
	-- pit column, within Range of the heart. Nothing plays there (debris falls
	-- over the decks, players drop through the pit), so it never gets in the way.
	local emitter = MapKit.block(CFrame.new(flat + Vector3.new(0, TUNING.PITCAM_EMITTER_Y, 0)), Vector3.one, trim({
		Name = "PitCamSpot",
		Transparency = 1,
	}))
	emitter.Parent = jib
	MapKit.spotLight(emitter, Enum.NormalId.Bottom, Config.MAP.KEY_WHITE, TUNING.PITCAM_SPOT.angle, TUNING.PITCAM_SPOT.brightness, TUNING.PITCAM_SPOT.range)
end

function Towers.build(parent: Instance)
	local towers = MapKit.model("Towers", parent)
	for _, spec in TUNING.TOWERS do
		buildTower(spec, towers)
	end
	buildRig(parent)
end

return Towers

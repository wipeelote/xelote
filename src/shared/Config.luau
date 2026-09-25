--!strict
-- Every tunable number for Debris Clear lives here.
-- Values marked PLACEHOLDER are first guesses meant to be tuned in playtests.

local Config = {}

---------------------------------------------------------------------------
-- Round flow
---------------------------------------------------------------------------
Config.MAX_PLAYERS = 4
Config.MIN_PLAYERS = 2 -- PLACEHOLDER: set to 1 for solo Studio testing
Config.INTERMISSION_TIME = 10 -- PLACEHOLDER: seconds between rounds
Config.PRE_ROUND_COUNTDOWN = 3 -- PLACEHOLDER: seconds frozen on platform before debris starts
Config.POST_ROUND_TIME = 5 -- PLACEHOLDER: seconds to show the winner
Config.RESPAWN_DELAY = 3 -- PLACEHOLDER: lobby respawn delay after elimination

---------------------------------------------------------------------------
-- Arena layout
---------------------------------------------------------------------------
Config.ARENA_CENTER = Vector3.new(0, 60, 0) -- PLACEHOLDER: top surface height of platforms = Y
Config.ARENA_RADIUS = 28 -- PLACEHOLDER: pit center -> platform center distance
Config.PLATFORM_RADIUS = 12 -- hex circumradius (center -> corner), per spec
Config.PLATFORM_THICKNESS = 2 -- PLACEHOLDER
Config.PIT_DEPTH = 45 -- PLACEHOLDER: pit floor sits this far below platform tops
Config.KILL_DEPTH = 20 -- PLACEHOLDER: inside the arena, anything this far below platform tops is dead/destroyed
-- The kill line only applies inside this horizontal radius around the pit, so
-- the spectator hub (and anything else outside the arena) is always safe.
Config.ARENA_KILL_RADIUS = 65 -- PLACEHOLDER

---------------------------------------------------------------------------
-- Spawn hub (raised overlook facing the arena)
---------------------------------------------------------------------------
Config.HUB_OFFSET = Vector3.new(0, 28, 95) -- PLACEHOLDER: hub floor center relative to ARENA_CENTER
Config.HUB_SIZE = Vector3.new(64, 2, 40) -- PLACEHOLDER: floor size (X wide, Z deep)
Config.HUB_RAIL_HEIGHT = 4 -- PLACEHOLDER
-- Falling this far below the hub floor (outside the arena) teleports you back
-- to the hub instead of killing you.
Config.HUB_RESCUE_DEPTH = 30 -- PLACEHOLDER
Config.TELEPORT_COOLDOWN = 1.5 -- PLACEHOLDER: seconds between pad teleports per player
-- Showcase gallery floor center relative to ARENA_CENTER. Kept at hub height
-- and far outside the arena so the kill line and rescue logic ignore it.
Config.SHOWCASE_OFFSET = Vector3.new(180, 28, 95) -- PLACEHOLDER
Config.PLATFORM_COLORS = { -- PLACEHOLDER: one per platform slot
	Color3.fromRGB(255, 89, 89),
	Color3.fromRGB(89, 170, 255),
	Color3.fromRGB(110, 230, 110),
	Color3.fromRGB(255, 205, 70),
}

---------------------------------------------------------------------------
-- Load / elimination
---------------------------------------------------------------------------
Config.LOAD_PER_DEBRIS = 15 -- per spec
Config.PLATFORM_CAPACITY = 100 -- per spec
Config.PISTON_DROP_TIME = 0.3 -- per spec (~0.3s)
Config.PISTON_DROP_DISTANCE = 38 -- PLACEHOLDER: how far the platform piston falls into the pit
Config.PISTON_RESET_TIME = 1.5 -- PLACEHOLDER: raise time between rounds

---------------------------------------------------------------------------
-- Debris
---------------------------------------------------------------------------
Config.DEBRIS_SIZE = 2 -- studs across, per spec (~2)
Config.SPAWN_INTERVAL_MIN = 2 -- per spec
Config.SPAWN_INTERVAL_MAX = 4 -- per spec
Config.SPAWN_HEIGHT = 30 -- PLACEHOLDER: studs above platform top
Config.SPAWN_EDGE_MARGIN = 0.8 -- PLACEHOLDER: spawn within this fraction of the hex apothem
-- Fraction of workspace.Gravity that debris actually feels. Default Roblox gravity
-- (196.2) caps a 60 stud/s throw at ~18 studs of range, which can't reach a rival
-- platform. 0.3 gives ~61 studs of max range. Only debris is affected; players
-- keep normal gravity.
Config.DEBRIS_GRAVITY_SCALE = 0.3 -- PLACEHOLDER: the biggest "feel" knob
Config.DEBRIS_DENSITY = 2 -- PLACEHOLDER
Config.DEBRIS_FRICTION = 0.8 -- PLACEHOLDER
Config.DEBRIS_ELASTICITY = 0.1 -- PLACEHOLDER
Config.DEBRIS_COLOR = Color3.fromRGB(150, 150, 160) -- PLACEHOLDER
Config.DEBRIS_MATERIAL = Enum.Material.Metal -- PLACEHOLDER
-- Debris counts as "landed" on a platform when it is over the hex footprint, its
-- center is within this band above the top surface, and it has slowed down.
Config.LAND_HEIGHT_BAND = 3 -- PLACEHOLDER
Config.LAND_MAX_SPEED = 6 -- PLACEHOLDER: studs/s
Config.LAND_SCAN_INTERVAL = 0.1 -- PLACEHOLDER: seconds between server landing scans
Config.MAX_DEBRIS_TOTAL = 80 -- PLACEHOLDER: safety cap across the whole arena

-- Optional imported mesh. Leave "" to build the d10 at runtime with EditableMesh.
-- To use an import: upload assets/decahedron.obj via the Asset Manager and paste
-- "rbxassetid://<id>" here. An imported mesh replicates normally and skips the
-- client-side EditableMesh visuals entirely.
Config.DEBRIS_MESH_ID = ""
-- Flip this if the EditableMesh d10 renders inside-out.
Config.DEBRIS_FLIP_WINDING = false

---------------------------------------------------------------------------
-- Pickup / throw
---------------------------------------------------------------------------
Config.PICKUP_RANGE = 5 -- per spec
Config.PICKUP_RANGE_TOLERANCE = 2 -- PLACEHOLDER: server-side slack for latency
Config.PICKUP_HOLD_DURATION = 0 -- PLACEHOLDER: ProximityPrompt hold time
Config.PICKUP_KEY = Enum.KeyCode.E
Config.PICKUP_GAMEPAD_KEY = Enum.KeyCode.ButtonX
Config.THROW_GAMEPAD_KEY = Enum.KeyCode.ButtonR2
Config.HOLD_OFFSET = CFrame.new(0, 3.2, 0) -- PLACEHOLDER: held debris position relative to HumanoidRootPart
Config.THROW_SPEED = 60 -- per spec
Config.THROW_BOOST_TIME = 0.1 -- PLACEHOLDER: seconds LinearVelocity drives the throw before gravity takes over
Config.THROW_COOLDOWN = 0.35 -- PLACEHOLDER: minimum seconds between throw requests
Config.THROW_MAX_AIM_DISTANCE = 500 -- PLACEHOLDER: aim point is clamped to this range
Config.THROW_FALLBACK_PITCH = math.rad(45) -- PLACEHOLDER: launch angle when the target is out of range (45 = max range)
Config.THROW_HIT_WINDOW = 1.5 -- PLACEHOLDER: seconds after a throw that a body hit still counts
Config.KNOCKBACK_SPEED = 40 -- per spec, horizontal studs/s
Config.KNOCKBACK_UP = 18 -- PLACEHOLDER: small vertical pop so the hit breaks floor friction
Config.KNOCKBACK_STUN = 0.45 -- PLACEHOLDER: seconds of PlatformStand after a hit
Config.AIM_ARC_POINTS = 14 -- PLACEHOLDER: dots in the client-side throw preview arc
Config.AIM_ARC_MAX_TIME = 2 -- PLACEHOLDER: seconds of flight the preview arc covers at most

---------------------------------------------------------------------------
-- Networking / validation
---------------------------------------------------------------------------
Config.PICKUP_COOLDOWN = 0.25 -- PLACEHOLDER
Config.MAX_REMOTE_RATE = 10 -- PLACEHOLDER: remote calls per second before requests are dropped

---------------------------------------------------------------------------
-- Ring meter
---------------------------------------------------------------------------
-- Optional ring texture (a white ring on transparent background). Leave "" to
-- draw the ring with a UIStroke instead, so no asset is needed.
Config.RING_IMAGE_ID = ""
Config.RING_THICKNESS = 0.09 -- PLACEHOLDER: fraction of gui size (UIStroke mode)
Config.RING_PIXELS_PER_STUD = 20 -- PLACEHOLDER: SurfaceGui resolution
Config.RING_TWEEN_TIME = 0.25 -- PLACEHOLDER
Config.RING_COLOR_SAFE = Color3.fromRGB(90, 230, 120)
Config.RING_COLOR_DANGER = Color3.fromRGB(255, 60, 60)

return Config

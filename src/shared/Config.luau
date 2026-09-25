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
-- Identity color per platform slot: neon rim, under-glow, collar ring and the
-- rig's colored spot. Decks themselves are near-black, tinted toward it.
Config.PLATFORM_COLORS = { -- PLACEHOLDER
	Color3.fromRGB(120, 255, 60), -- P1 Lime (front-right from the hub)
	Color3.fromRGB(255, 230, 60), -- P2 Sun Yellow (front-left)
	Color3.fromRGB(60, 140, 255), -- P3 Sky Blue (back-left)
	Color3.fromRGB(240, 240, 255), -- P4 Ice White (back-right)
}
Config.PLATFORM_DECK_TINTS = { -- PLACEHOLDER
	Color3.fromRGB(18, 34, 14),
	Color3.fromRGB(36, 34, 10),
	Color3.fromRGB(12, 22, 40),
	Color3.fromRGB(34, 34, 40),
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
-- Hot magenta: the d10, its trail, and every part of the towers ("made of
-- ball"). Nothing else in the map may use it (see Config.MAP notes).
Config.DEBRIS_COLOR = Color3.fromRGB(255, 40, 170) -- PLACEHOLDER
Config.DEBRIS_MATERIAL = Enum.Material.SmoothPlastic -- PLACEHOLDER: Neon would hide the d10 facets
-- Debris counts as "landed" on a platform when it is over the hex footprint, its
-- center is within this band above the top surface, and it has slowed down.
Config.LAND_HEIGHT_BAND = 3 -- PLACEHOLDER
Config.LAND_MAX_SPEED = 6 -- PLACEHOLDER: studs/s
Config.LAND_SCAN_INTERVAL = 0.1 -- PLACEHOLDER: seconds between server landing scans
Config.MAX_DEBRIS_TOTAL = 80 -- PLACEHOLDER: safety cap across the whole arena
-- Pressure curve: spawn intervals shrink linearly from the values above to
-- the *_END values over SPAWN_RAMP_TIME seconds of the round, then hold.
Config.SPAWN_RAMP_TIME = 60 -- PLACEHOLDER
Config.SPAWN_INTERVAL_MIN_END = 1.0 -- PLACEHOLDER
Config.SPAWN_INTERVAL_MAX_END = 1.8 -- PLACEHOLDER
-- Landing hysteresis: a piece must sit still on a deck this long before it
-- counts, and be off/moving this long before it stops counting.
Config.LAND_SETTLE_TIME = 0.3 -- PLACEHOLDER
Config.LAND_UNSETTLE_TIME = 0.3 -- PLACEHOLDER
-- Crushed platforms fling their debris into the lava at this speed.
Config.CRUSH_SCATTER_SPEED = 45 -- PLACEHOLDER

-- Optional imported mesh. Leave "" to build the d10 at runtime with EditableMesh.
-- To use an import: upload assets/decahedron.obj via the Asset Manager and paste
-- "rbxassetid://<id>" here. An imported mesh replicates normally and skips the
-- client-side EditableMesh visuals entirely.
Config.DEBRIS_MESH_ID = ""
-- Flip this if the EditableMesh d10 renders inside-out.
Config.DEBRIS_FLIP_WINDING = false

---------------------------------------------------------------------------
-- Map look ("NEON PIT": a game-show set over a lava crater)
---------------------------------------------------------------------------
-- false = tower rings/caps are SmoothPlastic for dead-flat mono-colored towers.
Config.TOWER_NEON_TRIM = true -- PLACEHOLDER
-- Palette used by the Map/ modules. Magenta is reserved for DEBRIS_COLOR
-- things (d10, towers, show logo, spawn ring, tallies, return gate); red is
-- reserved for the lava.
Config.MAP = {
	VOID_BLACK = Color3.fromRGB(12, 12, 20), -- stage, crater wall, monolith, gates, plaques
	BACKDROP_BLACK = Color3.fromRGB(10, 10, 18), -- backdrop wall panels
	PANEL_BLACK = Color3.fromRGB(14, 14, 22), -- walkable floors (hub, showcase)
	PEDESTAL_BLACK = Color3.fromRGB(16, 16, 24), -- pedestal bases, spawn pad, rod sleeves
	DEEP_NAVY = Color3.fromRGB(10, 12, 30), -- hub back wall, showcase walls
	BOARD_NAVY = Color3.fromRGB(8, 9, 22), -- scoreboard face
	AUDIENCE_NAVY = Color3.fromRGB(18, 18, 28), -- audience tiers
	STUDIO_GREY = Color3.fromRGB(30, 30, 40), -- truss ring, light bars, jib arm, rail caps
	FIXTURE_GREY = Color3.fromRGB(20, 20, 28), -- light fixture and camera housings
	PAD_BASE = Color3.fromRGB(20, 20, 30), -- teleport pad bases
	COLLAR_IRON = Color3.fromRGB(24, 24, 34), -- piston collars (Metal)
	ROD_STEEL = Color3.fromRGB(36, 38, 50), -- piston rods (Metal)
	ELECTRIC_CYAN = Color3.fromRGB(0, 220, 255), -- primary neon trim
	GRID_CYAN = Color3.fromRGB(0, 170, 210), -- dimmer neon: floor frames, lines, strips
	LAVA_BASE = Color3.fromRGB(140, 18, 4), -- full-pit lava disc (dim so bloom never whites out)
	LAVA_CORE = Color3.fromRGB(255, 70, 15), -- core disc, heat rings
	LAVA_LIGHT = Color3.fromRGB(255, 80, 20), -- lava point lights
	LAVA_FLOW = Color3.fromRGB(255, 120, 30), -- hot-spot discs
	LAVA_HEART = Color3.fromRGB(255, 160, 60), -- center heart disc
	LAVA_CRUST = Color3.fromRGB(28, 6, 4), -- cooled crust plates
	RAIL_GLASS = Color3.fromRGB(200, 220, 255), -- Glass rails, Transparency 0.7
	KEY_WHITE = Color3.fromRGB(230, 235, 255), -- key spots
	ROOM_WHITE = Color3.fromRGB(200, 230, 255), -- showcase corner-post lights
}
Config.RAIL_GLASS_TRANSPARENCY = 0.7 -- PLACEHOLDER

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
Config.HOLD_MAX_TIME = 4 -- PLACEHOLDER: seconds a piece can be held before it drops at your feet
Config.THROW_WINDUP = 0.15 -- PLACEHOLDER: seconds between the throw input and the launch
Config.THROW_TRAIL_LIFETIME = 0.35 -- PLACEHOLDER: seconds the trail behind a thrown piece lingers
Config.ARM_RAISE = true -- PLACEHOLDER: procedural right-arm raise/swing while holding and throwing (client)
Config.KNOCKBACK_SPEED = 40 -- per spec, horizontal studs/s
Config.KNOCKBACK_UP = 18 -- PLACEHOLDER: small vertical pop so the hit breaks floor friction
Config.KNOCKBACK_STUN = 0.45 -- PLACEHOLDER: seconds of PlatformStand after a hit
Config.AIM_ARC_POINTS = 14 -- PLACEHOLDER: dots in the client-side throw preview arc
Config.AIM_ARC_MAX_TIME = 2 -- PLACEHOLDER: seconds of flight the preview arc covers at most

---------------------------------------------------------------------------
-- Client feedback / effects
---------------------------------------------------------------------------
Config.LAND_SHADOW_ENABLED = true -- warning disc on the deck under every falling piece
Config.LAND_SHADOW_HEIGHT = 30 -- PLACEHOLDER: shadow starts showing when the piece is this high above the surface
Config.LAND_SHADOW_MAX_RADIUS = 1.6 -- PLACEHOLDER: disc radius when the piece is about to land
Config.LAND_SHADOW_COLOR = Color3.fromRGB(255, 40, 40)
Config.SHAKE_LAND = 0.35 -- PLACEHOLDER: camera shake for the owner when a piece lands on their platform
Config.SHAKE_CRUSH = 1.2 -- PLACEHOLDER: camera shake at a crushed platform, falls off with distance
Config.SHAKE_FALLOFF_RANGE = 120 -- PLACEHOLDER: studs at which crush shake fades to zero
Config.WIN_CAMERA_TIME = 3 -- PLACEHOLDER: seconds every camera focuses on the winner's platform (0 disables)
Config.BILLBOARD_ENABLED = true -- floating load bar above each rival platform
Config.BILLBOARD_HEIGHT = 14 -- PLACEHOLDER: studs above the deck
Config.BILLBOARD_MAX_DISTANCE = 250 -- PLACEHOLDER

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

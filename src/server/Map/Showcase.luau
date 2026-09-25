--!strict
-- Backstage gallery (brief section 5): a navy room on a black column east of
-- the hub at hub height, its west side open behind glass toward the towers
-- and lava. Seven pedestals on an arc all face the arrival point, each with a
-- tilted plaque and a spot head over it: the hero d10, a live half-scale hex
-- podium, a tower, a pumping piston, a lava puddle, a PIT CAM and a truss
-- rig. A magenta return gate and pad lead back to the hub, linked to the hub
-- gate by a thin cyan data beam. 105 parts.
-- Contract: returns where teleported players are placed (the arrival point).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("DebrisClear")
local Config = require(Shared.Config)
local HexGeometry = require(Shared.HexGeometry)
local MapKit = require(script.Parent.MapKit)

local Showcase = {}

export type Result = {
	spawnCFrame: CFrame,
}

type ExhibitSpec = { key: string, angle: number, title: string, caption: string, hero: boolean? }

-- Pedestal handed to the exhibit builders.
type Pedestal = {
	floorCF: CFrame, -- floor top under the pedestal center, local -Z toward the arrival
	discTop: Vector3, -- center of the disc's top face; exhibits stand here
}

-- Same tag Arena puts on the real platforms; the client ring controller
-- animates every model carrying it.
local PLATFORM_TAG = "DebrisClearPlatform"

-- Offsets are from S = ARENA_CENTER + SHOWCASE_OFFSET = (180, 88, 95), the
-- center of the floor top. Room Y values are studs above the floor top;
-- exhibit Y values are studs above their pedestal's disc top (world 90.9).
local TUNING = {
	-- Room shell.
	ROOM = 60, -- PLACEHOLDER: floor side (world X 150..210, Z 65..125)
	FLOOR_THICKNESS = 2, -- PLACEHOLDER
	COLUMN_SIZE = Vector3.new(24, 50, 24), -- PLACEHOLDER: black column under the floor, standing on the stage (Y 36..86)
	COLUMN_STRIP = { size = 0.5, out = 0.1 }, -- PLACEHOLDER: neon line on each column edge, centered 0.1 outside the corner
	LINE_HEIGHT = 0.16, -- PLACEHOLDER: floor lines, bottoms flush with the floor top
	LINE_WIDTH = 0.3, -- PLACEHOLDER
	BORDER_INSET = 2, -- PLACEHOLDER: border lines this far in from the floor edge
	LANE = { length = 30, centerX = 1, halfGap = 4 }, -- PLACEHOLDER: two strips from the arrival to the hero
	WALL_HEIGHT = 16, -- PLACEHOLDER
	WALL_THICKNESS = 1, -- PLACEHOLDER
	TOP_STRIP = { height = 0.5, width = 1.2 }, -- PLACEHOLDER: magenta strip along each wall top
	CORNER_POST = 1.2, -- PLACEHOLDER: neon post in each floor corner, full wall height
	CORNER_LIGHT = { brightness = 1.2, range = 45 }, -- PLACEHOLDER: room ambient
	RAIL = { glassHeight = 3.6, glassThickness = 0.3, capHeight = 0.4, capWidth = 0.6 }, -- PLACEHOLDER: open west edge
	LIGHT_BAR_X = { 4, 20 }, -- PLACEHOLDER: truss bars across the room at S.X + these (world 184, 200)
	LIGHT_BAR_Y = 15, -- PLACEHOLDER: bar center (world 103; bottom 102)
	LIGHT_BAR_SIZE = Vector3.new(2, 2, 58), -- PLACEHOLDER: touches both side walls; every axis a multiple of 2
	SPOT_HEAD = { y = 13.4, size = Vector3.new(1.4, 1.4, 2.2), angle = 45, brightness = 3, range = 20 }, -- PLACEHOLDER: one under a bar over every pedestal

	-- Arrival and the pedestal arc.
	ARRIVAL = Vector3.new(-13, 0, 0), -- PLACEHOLDER: world (167, 88, 95), 6 clear of the return pad's edge; also the arc center
	STAND_HEIGHT = 3.5, -- PLACEHOLDER: HumanoidRootPart above the floor
	ARRIVAL_MARKER = { radius = 3, thickness = 0.15, lift = 0.08 }, -- PLACEHOLDER
	ARC_RADIUS = 29, -- PLACEHOLDER: pedestal centers from the arrival point
	-- Angle on the arc (0 = straight ahead of the arrival, + toward north/+Z)
	-- and plaque text per exhibit. Order is build order.
	EXHIBITS = {
		{ key = "Debris", angle = 0, title = "D10 DEBRIS", caption = "15 load each. Grab it (E), throw it (click).", hero = true },
		{ key = "Platform", angle = -21, title = "HEX PLATFORM", caption = "Your podium. The ring drains as load climbs; 100 drops the piston." },
		{ key = "Tower", angle = 21, title = "TOWER", caption = "Nine of these ring the set, every part in debris pink." },
		{ key = "Lava", angle = -42, title = "LAVA", caption = "The pit. Below Y 40 nothing comes back." },
		{ key = "PitCam", angle = 42, title = "PIT CAM", caption = "The jib over the pit. Every crush, live." },
		{ key = "Piston", angle = -60, title = "PISTON", caption = "Load 100: 38 studs down in 0.3 s. You go with it." },
		{ key = "Rig", angle = 60, title = "THE RIG", caption = "One color spot and one key spot on every podium." },
	} :: { ExhibitSpec }, -- PLACEHOLDER
	PEDESTAL = { -- PLACEHOLDER: the six standard pedestals
		base = Vector3.new(6, 2.6, 6),
		discRadius = 3.2,
		discThickness = 0.3,
		plaque = Vector3.new(6, 1.6, 0.3),
		plaqueOffset = Vector3.new(0, 0.5, -3.45), -- from the base center, toward the arrival
	},
	HERO = { -- PLACEHOLDER: the d10 pedestal
		base = Vector3.new(8, 4, 8),
		discRadius = 4.2,
		discThickness = 0.3,
		plaque = Vector3.new(8, 1.8, 0.3),
		plaqueOffset = Vector3.new(0, 1.2, -4.45),
	},
	PLAQUE_TILT = 28, -- PLACEHOLDER: degrees the plaque leans back (top edge level with the base top)
	PLAQUE_PIXELS_PER_STUD = 40, -- PLACEHOLDER
	DISC_LIGHT = { brightness = 1, range = 10 }, -- PLACEHOLDER: cyan pool on each standard pedestal

	-- Exhibits.
	D10 = { lift = 5.2, scale = 3, spin = 30, bob = 0.6, bobPeriod = 3, light = { brightness = 3, range = 24 } }, -- PLACEHOLDER: center world Y 97.5, 6 studs across
	HEX = { -- PLACEHOLDER: half-scale podium (real decks: R 12, T 2)
		radius = 6,
		thickness = 1,
		topLift = 4.6, -- deck top above the disc top (world 95.5)
		rim = Vector3.new(6, 0.3, 0.15), -- X along the side; half the depth stands proud
		rodRadius = 1.5, -- rod from the disc top to the deck bottom
		collar = { radius = 2.5, height = 1 }, -- top flush with the deck bottom
		underDisc = { radius = 4.75, thickness = 0.15, gap = 0.05 },
		underLight = { brightness = 1.5, range = 10 },
		loadCycle = { rise = 8, hold = 1.5, rest = 1 }, -- seconds: Load 0 -> capacity, hold, back to 0, rest
	},
	TOWER = { -- PLACEHOLDER: 1/5 scale
		plinth = { radius = 1.2, height = 0.4 },
		body = { radius = 0.8, height = 12 },
		ring = { radius = 0.9, thickness = 0.15, first = 3.4, spacing = 4 }, -- first ring this far above the disc top
		cap = { radius = 0.95, thickness = 0.3 },
		capLight = { brightness = 1.5, range = 12 },
		searchlight = { height = 8, width0 = 1.2, width1 = 0.1 },
	},
	PISTON = { -- PLACEHOLDER
		sleeve = { radius = 2.2, height = 2 },
		rod = { radius = 1.5, height = 6 },
		collar = { radius = 2.5, height = 1.5 }, -- top flush with the rod top
		ring = { radius = 2.7, thickness = 0.3, y = 5.25 }, -- center above the disc top
		cap = { radius = 4, thickness = 0.6 }, -- sits on the rod top
		rim = { radius = 4.2, thickness = 0.3, y = 6.3 },
		drop = 4, -- studs the moving parts fall
		dropTime = 0.3,
		downHold = 1.2,
		riseTime = 1.5,
		upHold = 1.5,
	},
	LAVA = { -- PLACEHOLDER
		disc = { radius = 2.8, thickness = 0.3 },
		plateThickness = 0.2,
		plateY = 0.4, -- plate center above the disc top; the plates rest on the puddle
		-- {x, z, yawDeg, sizeX, sizeZ}: crust plates floating on the puddle
		plates = { { 0.6, 0.5, 20, 1.6, 2.4 }, { -1.0, -0.6, 75, 2.2, 1.4 }, { 0.4, -1.5, 130, 1.2, 1.2 } },
		emberRate = 6,
		emberSize = NumberSequence.new(0.15, 0.35),
		light = { brightness = 1.5, range = 10 },
	},
	PITCAM = { -- PLACEHOLDER: offsets are pedestal-local from the floor top
		postSize = Vector3.new(2, 8, 2), -- truss standing on the disc
		armSize = Vector3.new(0.6, 0.6, 5), -- from the post top toward the arrival
		armOffset = Vector3.new(0, 9.9, -2.5),
		headSize = Vector3.new(1.2, 1, 1.6),
		headOffset = Vector3.new(0, 9.1, -5), -- hanging 0.8 under the arm end, aimed at the disc
		lens = { radius = 0.45, length = 1, offset = 1.1 },
		tally = 0.3,
		spot = { angle = 35, brightness = 3, range = 12 },
		blink = { period = 1.2, maxT = 0.7 },
	},
	RIG = { -- PLACEHOLDER: pedestal-local offsets from the floor top
		postSize = Vector3.new(0.4, 5, 0.4),
		postX = 2.5,
		trussSize = Vector3.new(2, 2, 6), -- long axis turned onto pedestal-local X
		trussY = 8.9,
		fixtureSize = Vector3.new(1.2, 1.2, 1.6),
		fixtureX = 1.5,
		fixtureY = 7.7, -- hanging under the truss
		colorSpot = { angle = 35, brightness = 4, range = 12 },
		keySpot = { angle = 45, brightness = 2.5, range = 12 },
	},

	-- Return gate and pad (players walk -X through the arch onto the pad).
	PAD_OFFSET = Vector3.new(-23, 0.3, 0), -- PLACEHOLDER: world (157, 88.3, 95); pad X 153..161
	GATE = { -- PLACEHOLDER: straddles the pad along Z
		x = -23,
		pillar = Vector3.new(1.5, 9, 1.5),
		pillarZ = 5.75, -- either side of the pad center
		lintel = Vector3.new(1.5, 1.5, 13),
		neonPillar = Vector3.new(0.3, 9, 0.3), -- on the pillars' inner faces
		neonLintel = Vector3.new(0.3, 0.3, 11), -- under the lintel
	},
	LINK_BEAM = { width = 0.5, transparency = 0.55 }, -- PLACEHOLDER: data line to the hub gate's LinkA
}

local WALL_TEXT = {
	title = "SHOWCASE",
	subtitle = "THE PIECES OF DEBRIS CLEAR",
	howToPlay = {
		"E or X: grab debris within 5 studs",
		"Click or R2: throw at the cursor",
		"Off the edge, or onto a rival",
	},
	rules = {
		"15 load per piece. 100 crushes your piston.",
		"Last podium standing wins.",
	},
}

local PLAQUE_STROKE = Color3.fromRGB(0, 90, 120)
local EMBER_HOT = Color3.fromRGB(255, 140, 50)
local EMBER_COOL = Color3.fromRGB(255, 40, 10)

---------------------------------------------------------------------------
-- Prop and text helpers
---------------------------------------------------------------------------

-- Solid set piece (SmoothPlastic unless told otherwise).
local function solid(name: string, color: Color3, material: Enum.Material?): MapKit.Props
	return { Name = name, Color = color, Material = material or Enum.Material.SmoothPlastic }
end

-- Nothing may rest on, ray-hit or touch these (thin dressing, moving parts).
local function ghost(props: MapKit.Props): MapKit.Props
	props.CanCollide = false
	props.CanQuery = false
	props.CanTouch = false
	return props
end

-- Neon trim (strips, rings, discs, posts): never collidable, no shadow.
-- Neon unless told otherwise (the tower trim follows TOWER_NEON_TRIM).
local function neon(name: string, color: Color3, material: Enum.Material?): MapKit.Props
	local props = ghost(solid(name, color, material or Enum.Material.Neon))
	props.CastShadow = false
	return props
end

-- Light fixture / camera housing.
local function housing(name: string): MapKit.Props
	return solid(name, Config.MAP.FIXTURE_GREY)
end

local function trussProps(name: string, size: Vector3, cf: CFrame, color: Color3): MapKit.Props
	return {
		Name = name,
		Size = size,
		CFrame = cf,
		Style = Enum.Style.BridgeStyleSupports,
		Color = color,
		Material = Enum.Material.SmoothPlastic,
	}
end

local function set(instance: Instance, props: MapKit.Props)
	for k, v in props do
		(instance :: any)[k] = v
	end
end

-- Another line on a face that already has a surfaceText gui.
local function addLabel(gui: SurfaceGui, text: string, props: MapKit.Props): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.TextStrokeTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = text
	set(label, props)
	label.Parent = gui
	return label
end

local function captionStyle(size: UDim2, position: UDim2): MapKit.Props
	return { Size = size, Position = position, Font = Enum.Font.Gotham, TextColor3 = Config.MAP.ELECTRIC_CYAN }
end

-- Show logo style: magenta GothamBlack with a cyan outline.
local function logoStyle(label: TextLabel)
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = Config.DEBRIS_COLOR
	label.TextStrokeTransparency = 1
	local stroke = Instance.new("UIStroke")
	stroke.Color = Config.MAP.ELECTRIC_CYAN
	stroke.Thickness = 4
	stroke.Parent = label
end

-- Cyan header over white GothamMedium lines on a wall face.
local function poster(wall: BasePart, face: Enum.NormalId, header: string, lines: { string })
	local gui = MapKit.surfaceText(wall, face, header, {
		Size = UDim2.fromScale(0.9, 0.2),
		Position = UDim2.fromScale(0.05, 0.05),
		TextColor3 = Config.MAP.ELECTRIC_CYAN,
	})
	local stride = 0.6 / #lines
	for i, line in lines do
		addLabel(gui, line, {
			Size = UDim2.fromScale(0.9, 0.16),
			Position = UDim2.fromScale(0.05, 0.3 + (i - 1) * stride),
			Font = Enum.Font.GothamMedium,
		})
	end
end

-- Title over caption on the plaque's tilted front face.
local function plaqueText(plaque: BasePart, title: string, caption: string)
	local gui = MapKit.surfaceText(plaque, Enum.NormalId.Front, title, {
		Size = UDim2.fromScale(0.94, 0.5),
		Position = UDim2.fromScale(0.03, 0.04),
		TextStrokeTransparency = 0,
		TextStrokeColor3 = PLAQUE_STROKE,
	})
	gui.PixelsPerStud = TUNING.PLAQUE_PIXELS_PER_STUD
	addLabel(gui, caption, captionStyle(UDim2.fromScale(0.94, 0.42), UDim2.fromScale(0.03, 0.55)))
end

-- Discs are cylinders rotated about Z, so their local +X (Right) is world up.
local function embers(disc: BasePart, rate: number, size: NumberSequence): ParticleEmitter
	return MapKit.emitter(disc, {
		Name = "Embers",
		Color = ColorSequence.new(EMBER_HOT, EMBER_COOL),
		Size = size,
		Lifetime = NumberRange.new(2, 4),
		Speed = NumberRange.new(5, 10),
		Rate = rate,
		SpreadAngle = Vector2.new(12, 12),
		Acceleration = Vector3.new(0, 1.5, 0),
		LightEmission = 1,
		LightInfluence = 0,
		Transparency = NumberSequence.new(0.1, 1),
		EmissionDirection = Enum.NormalId.Right,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
	})
end

---------------------------------------------------------------------------
-- Room: column, floor, lines, walls, posts, rail, light bars (26 parts;
-- the 7 spot heads under the bars are hung per pedestal, below)
---------------------------------------------------------------------------

local function buildRoom(model: Model, S: Vector3)
	local room, floorT = TUNING.ROOM, TUNING.FLOOR_THICKNESS
	local wallH, wallT = TUNING.WALL_HEIGHT, TUNING.WALL_THICKNESS
	local inset = room / 2 - wallT / 2 -- wall centers, corner posts and the rail sit here

	-- Black column standing on the stage, a neon line down each edge.
	local column = TUNING.COLUMN_SIZE
	local columnCenter = S + Vector3.new(0, -floorT - column.Y / 2, 0)
	MapKit.block(CFrame.new(columnCenter), column, solid("BaseColumn", Config.MAP.VOID_BLACK)).Parent = model
	local edge = column.X / 2 + TUNING.COLUMN_STRIP.out
	local stripSize = Vector3.new(TUNING.COLUMN_STRIP.size, column.Y, TUNING.COLUMN_STRIP.size)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			MapKit.block(CFrame.new(columnCenter + Vector3.new(sx * edge, 0, sz * edge)), stripSize, neon("ColumnStrip", Config.MAP.GRID_CYAN)).Parent =
				model
		end
	end

	-- Floor and its neon lines: a border and two lanes from the arrival to the hero.
	MapKit.block(CFrame.new(S - Vector3.new(0, floorT / 2, 0)), Vector3.new(room, floorT, room), solid("Floor", Config.MAP.PANEL_BLACK)).Parent =
		model
	local lineY = TUNING.LINE_HEIGHT / 2
	local border = room / 2 - TUNING.BORDER_INSET
	local borderLength = room - 2 * TUNING.BORDER_INSET
	local lane = TUNING.LANE
	for _, s in { -1, 1 } do
		MapKit.block(
			CFrame.new(S + Vector3.new(0, lineY, s * border)),
			Vector3.new(borderLength, TUNING.LINE_HEIGHT, TUNING.LINE_WIDTH),
			neon("FloorLine", Config.MAP.GRID_CYAN)
		).Parent = model
		MapKit.block(
			CFrame.new(S + Vector3.new(s * border, lineY, 0)),
			Vector3.new(TUNING.LINE_WIDTH, TUNING.LINE_HEIGHT, borderLength),
			neon("FloorLine", Config.MAP.GRID_CYAN)
		).Parent = model
		MapKit.block(
			CFrame.new(S + Vector3.new(lane.centerX, lineY, s * lane.halfGap)),
			Vector3.new(lane.length, TUNING.LINE_HEIGHT, TUNING.LINE_WIDTH),
			neon("FloorLane", Config.MAP.GRID_CYAN)
		).Parent = model
	end

	-- Three navy walls (the west side stays open), each with a magenta top strip.
	local function wall(name: string, offset: Vector3, size: Vector3): Part
		local part = MapKit.block(CFrame.new(S + offset + Vector3.new(0, wallH / 2, 0)), size, solid(name, Config.MAP.DEEP_NAVY))
		part.Parent = model
		local strip = TUNING.TOP_STRIP
		local stripSize = if size.X > size.Z then Vector3.new(size.X, strip.height, strip.width) else Vector3.new(strip.width, strip.height, size.Z)
		MapKit.block(CFrame.new(S + offset + Vector3.new(0, wallH + strip.height / 2, 0)), stripSize, neon("WallTopStrip", Config.DEBRIS_COLOR)).Parent =
			model
		return part
	end
	local back = wall("BackWall", Vector3.new(inset, 0, 0), Vector3.new(wallT, wallH, room))
	local south = wall("SouthWall", Vector3.new(0, 0, -inset), Vector3.new(room, wallH, wallT))
	local north = wall("NorthWall", Vector3.new(0, 0, inset), Vector3.new(room, wallH, wallT))

	-- Room-facing texts: title on the back wall, how-to and rules on the sides.
	local gui, title = MapKit.surfaceText(back, Enum.NormalId.Left, WALL_TEXT.title, {
		Size = UDim2.fromScale(0.9, 0.28),
		Position = UDim2.fromScale(0.05, 0.06),
	})
	logoStyle(title)
	addLabel(gui, WALL_TEXT.subtitle, captionStyle(UDim2.fromScale(0.9, 0.12), UDim2.fromScale(0.05, 0.36)))
	poster(south, Enum.NormalId.Back, "HOW TO PLAY", WALL_TEXT.howToPlay)
	poster(north, Enum.NormalId.Front, "THE RULES", WALL_TEXT.rules)

	-- Cyan corner posts carry the room's ambient light.
	local postSize = Vector3.new(TUNING.CORNER_POST, wallH, TUNING.CORNER_POST)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local post = MapKit.block(CFrame.new(S + Vector3.new(sx * inset, wallH / 2, sz * inset)), postSize, neon("CornerPost", Config.MAP.ELECTRIC_CYAN))
			post.Parent = model
			MapKit.pointLight(post, Config.MAP.ROOM_WHITE, TUNING.CORNER_LIGHT.brightness, TUNING.CORNER_LIGHT.range)
		end
	end

	-- Glass rail along the open west edge, looking back at the set.
	local rail = TUNING.RAIL
	MapKit.block(CFrame.new(S + Vector3.new(-inset, rail.glassHeight / 2, 0)), Vector3.new(rail.glassThickness, rail.glassHeight, room), {
		Name = "WestRail",
		Color = Config.MAP.RAIL_GLASS,
		Material = Enum.Material.Glass,
		Transparency = Config.RAIL_GLASS_TRANSPARENCY,
	}).Parent = model
	MapKit.block(
		CFrame.new(S + Vector3.new(-inset, rail.glassHeight + rail.capHeight / 2, 0)),
		Vector3.new(rail.capWidth, rail.capHeight, room),
		neon("WestRailCap", Config.MAP.GRID_CYAN)
	).Parent = model

	-- Two truss bars across the room; the spot heads hang under them.
	for _, x in TUNING.LIGHT_BAR_X do
		MapKit.truss(trussProps("LightBar", TUNING.LIGHT_BAR_SIZE, CFrame.new(S + Vector3.new(x, TUNING.LIGHT_BAR_Y, 0)), Config.MAP.STUDIO_GREY)).Parent =
			model
	end
end

-- Key spot under the nearest light bar, aimed at the pedestal's disc.
local function hangSpotHead(model: Model, S: Vector3, discTop: Vector3)
	local head = TUNING.SPOT_HEAD
	local barX = TUNING.LIGHT_BAR_X[1]
	for _, x in TUNING.LIGHT_BAR_X do
		if math.abs(S.X + x - discTop.X) < math.abs(S.X + barX - discTop.X) then
			barX = x
		end
	end
	local pos = Vector3.new(S.X + barX, S.Y + head.y, discTop.Z)
	local fixture = MapKit.block(CFrame.lookAt(pos, discTop), head.size, housing("SpotHead"))
	fixture.Parent = model
	MapKit.spotLight(fixture, Enum.NormalId.Front, Config.MAP.KEY_WHITE, head.angle, head.brightness, head.range)
end

---------------------------------------------------------------------------
-- Pedestals (3 parts each)
---------------------------------------------------------------------------

-- Base, neon disc and tilted plaque on the arc around the arrival point.
local function buildPedestal(model: Model, arrival: Vector3, spec: ExhibitSpec): Pedestal
	local hero = spec.hero == true
	local dims = if hero then TUNING.HERO else TUNING.PEDESTAL
	local a = math.rad(spec.angle)
	local pos = arrival + Vector3.new(math.cos(a), 0, math.sin(a)) * TUNING.ARC_RADIUS
	local floorCF = CFrame.lookAt(pos, Vector3.new(arrival.X, pos.Y, arrival.Z))

	local baseCF = floorCF * CFrame.new(0, dims.base.Y / 2, 0)
	MapKit.block(baseCF, dims.base, solid("PedestalBase", Config.MAP.PEDESTAL_BLACK)).Parent = model

	local discColor = if hero then Config.DEBRIS_COLOR else Config.MAP.ELECTRIC_CYAN
	local disc = MapKit.disc(
		floorCF * CFrame.new(0, dims.base.Y + dims.discThickness / 2, 0),
		dims.discRadius,
		dims.discThickness,
		neon("PedestalDisc", discColor)
	)
	disc.Parent = model
	if not hero then
		MapKit.pointLight(disc, Config.MAP.ELECTRIC_CYAN, TUNING.DISC_LIGHT.brightness, TUNING.DISC_LIGHT.range)
	end

	-- Plaque on the arrival-facing side, leaning back so its face looks up at the visitor.
	local plaqueCF = baseCF * CFrame.new(dims.plaqueOffset) * CFrame.Angles(math.rad(TUNING.PLAQUE_TILT), 0, 0)
	local plaque = MapKit.block(plaqueCF, dims.plaque, solid("Plaque", Config.MAP.VOID_BLACK))
	plaque.Parent = model
	plaqueText(plaque, spec.title, spec.caption)

	return {
		floorCF = floorCF,
		discTop = pos + Vector3.new(0, dims.base.Y + dims.discThickness, 0),
	}
end

---------------------------------------------------------------------------
-- Exhibits
---------------------------------------------------------------------------

-- Hero d10: clients render it over the anchor, 3x scale, spinning and bobbing.
local function buildDebris(model: Model, ped: Pedestal, _arrival: Vector3)
	local d = TUNING.D10
	local anchor = MapKit.showcaseDebris(model, CFrame.new(ped.discTop + Vector3.new(0, d.lift, 0)), d.scale)
	MapKit.pointLight(anchor, Config.DEBRIS_COLOR, d.light.brightness, d.light.range)
	MapKit.spinBob(anchor, d.spin, d.bob, d.bobPeriod)
end

-- Half-scale podium with a live ring meter: the same deck/rim/collar/under-disc
-- recipe as PlatformDressing, tagged like a platform, with Load cycling.
local function buildPlatform(model: Model, ped: Pedestal, arrival: Vector3)
	local h = TUNING.HEX
	local color = Config.PLATFORM_COLORS[1]
	local exhibit = MapKit.model("ExhibitPlatform", model)
	local topPos = ped.discTop + Vector3.new(0, h.topLift, 0)
	-- A flat edge faces the arrival, as the real decks face the pit.
	local top = CFrame.lookAt(topPos, Vector3.new(arrival.X, topPos.Y, arrival.Z))

	MapKit.hexDeck(top, h.radius, h.thickness, exhibit, {
		Name = "Deck",
		Color = Config.PLATFORM_DECK_TINTS[1],
		Material = Enum.Material.SmoothPlastic,
	})

	-- Rim strips centered on the side midpoints at deck mid-height.
	local apothem = HexGeometry.apothem(h.radius)
	local rimY = -h.thickness / 2
	local rimCenter = (top * CFrame.new(0, rimY, 0)).Position
	for k = 0, 5 do
		local t = math.rad(30 + 60 * k)
		local mid = (top * CFrame.new(apothem * math.cos(t), rimY, apothem * math.sin(t))).Position
		MapKit.block(CFrame.lookAt(mid, rimCenter), h.rim, neon("RimStrip", color)).Parent = exhibit
	end

	-- Rod from the disc top to the deck bottom, collar at its top, under-disc just below the deck.
	local rodLength = h.topLift - h.thickness
	MapKit.cylinder(top * CFrame.new(0, -h.thickness - rodLength / 2, 0), rodLength, h.rodRadius, solid("PistonRod", Config.MAP.ROD_STEEL, Enum.Material.Metal)).Parent =
		exhibit
	MapKit.cylinder(
		top * CFrame.new(0, -h.thickness - h.collar.height / 2, 0),
		h.collar.height,
		h.collar.radius,
		solid("Collar", Config.MAP.COLLAR_IRON, Enum.Material.Metal)
	).Parent = exhibit
	local under = MapKit.disc(
		top * CFrame.new(0, -h.thickness - h.underDisc.gap - h.underDisc.thickness / 2, 0),
		h.underDisc.radius,
		h.underDisc.thickness,
		neon("UnderDisc", color)
	)
	under.Parent = exhibit
	MapKit.pointLight(under, color, h.underLight.brightness, h.underLight.range)

	MapKit.ringMeter(top, h.radius, exhibit)

	-- Same attributes and tag as a real platform so the client animates the
	-- ring; Slot 0 and an empty OwnerName keep the rival billboard off.
	exhibit:SetAttribute("Slot", 0)
	exhibit:SetAttribute("Load", 0)
	exhibit:SetAttribute("Capacity", Config.PLATFORM_CAPACITY)
	exhibit:SetAttribute("OwnerName", "")
	exhibit:SetAttribute("Eliminated", false)
	CollectionService:AddTag(exhibit, PLATFORM_TAG)

	-- Load climbs to capacity, holds, resets, rests: attribute writes only.
	local cycle = h.loadCycle
	task.spawn(function()
		while exhibit.Parent do
			local t = 0
			while t < cycle.rise do
				t += RunService.Heartbeat:Wait()
				exhibit:SetAttribute("Load", math.floor(Config.PLATFORM_CAPACITY * math.min(t / cycle.rise, 1)))
			end
			task.wait(cycle.hold)
			exhibit:SetAttribute("Load", 0)
			task.wait(cycle.rest)
		end
	end)
end

-- 1/5-scale tower, every part in DEBRIS_COLOR like the real ones.
local function buildTower(model: Model, ped: Pedestal, _arrival: Vector3)
	local t = TUNING.TOWER
	local trimMaterial = if Config.TOWER_NEON_TRIM then Enum.Material.Neon else Config.DEBRIS_MATERIAL
	local function towerProps(name: string, material: Enum.Material): MapKit.Props
		return solid(name, Config.DEBRIS_COLOR, material)
	end
	local base = ped.discTop

	MapKit.column(base, t.plinth.height, t.plinth.radius, towerProps("Plinth", Config.DEBRIS_MATERIAL)).Parent = model
	local bodyBase = base + Vector3.new(0, t.plinth.height, 0)
	MapKit.column(bodyBase, t.body.height, t.body.radius, towerProps("Body", Config.DEBRIS_MATERIAL)).Parent = model

	local top = bodyBase.Y + t.body.height
	local y = base.Y + t.ring.first
	while y < top do
		MapKit.disc(CFrame.new(base.X, y, base.Z), t.ring.radius, t.ring.thickness, neon("Ring", Config.DEBRIS_COLOR, trimMaterial)).Parent = model
		y += t.ring.spacing
	end

	local cap = MapKit.disc(CFrame.new(base.X, top + t.cap.thickness / 2, base.Z), t.cap.radius, t.cap.thickness, neon("Cap", Config.DEBRIS_COLOR, trimMaterial))
	cap.Parent = model
	MapKit.pointLight(cap, Config.DEBRIS_COLOR, t.capLight.brightness, t.capLight.range)
	-- After parenting: the beam's top attachment is placed in world space.
	MapKit.beamUp(cap, t.searchlight.height, t.searchlight.width0, t.searchlight.width1, Config.DEBRIS_COLOR)
end

-- Piston in P2 yellow: the rod, collar, ring and cap pump; the sleeve stays.
local function buildPiston(model: Model, ped: Pedestal, _arrival: Vector3)
	local p = TUNING.PISTON
	local base = ped.discTop
	local yellow = Config.PLATFORM_COLORS[2]

	local sleeve = MapKit.column(base, p.sleeve.height, p.sleeve.radius, solid("PistonSleeve", Config.MAP.PEDESTAL_BLACK))
	sleeve.Parent = model

	-- Moving parts never collide: a player standing on them would be dropped.
	local moving = {
		MapKit.column(base, p.rod.height, p.rod.radius, ghost(solid("PistonRod", Config.MAP.ROD_STEEL, Enum.Material.Metal))),
		MapKit.column(
			base + Vector3.new(0, p.rod.height - p.collar.height, 0),
			p.collar.height,
			p.collar.radius,
			ghost(solid("Collar", Config.MAP.COLLAR_IRON, Enum.Material.Metal))
		),
		MapKit.disc(CFrame.new(base + Vector3.new(0, p.ring.y, 0)), p.ring.radius, p.ring.thickness, neon("CollarRing", yellow)),
		MapKit.column(base + Vector3.new(0, p.rod.height, 0), p.cap.thickness, p.cap.radius, ghost(solid("PistonCap", Config.PLATFORM_DECK_TINTS[2]))),
		MapKit.disc(CFrame.new(base + Vector3.new(0, p.rim.y, 0)), p.rim.radius, p.rim.thickness, neon("CapRim", yellow)),
	}
	local rest: { [BasePart]: CFrame } = {}
	for _, part in moving do
		part.Parent = model
		rest[part] = part.CFrame
	end

	-- Slide every moving part to `offset` below rest and wait for it.
	local function slide(offset: number, info: TweenInfo)
		local last: Tween? = nil
		for _, part in moving do
			local tween = TweenService:Create(part, info, { CFrame = rest[part] - Vector3.new(0, offset, 0) })
			tween:Play()
			last = tween
		end
		if last then
			last.Completed:Wait()
		end
	end
	local dropInfo = TweenInfo.new(p.dropTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local riseInfo = TweenInfo.new(p.riseTime, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	task.spawn(function()
		while sleeve.Parent do
			task.wait(p.upHold)
			slide(p.drop, dropInfo)
			task.wait(p.downHold)
			slide(0, riseInfo)
		end
	end)
end

-- Lava puddle with crust plates and a few embers.
local function buildLava(model: Model, ped: Pedestal, _arrival: Vector3)
	local l = TUNING.LAVA
	local base = ped.discTop

	local disc = MapKit.disc(CFrame.new(base + Vector3.new(0, l.disc.thickness / 2, 0)), l.disc.radius, l.disc.thickness, neon("LavaDisc", Config.MAP.LAVA_CORE))
	disc.Parent = model
	MapKit.pointLight(disc, Config.MAP.LAVA_LIGHT, l.light.brightness, l.light.range)
	embers(disc, l.emberRate, l.emberSize)

	for _, plate in l.plates do
		local x, z, yaw, sizeX, sizeZ = plate[1], plate[2], plate[3], plate[4], plate[5]
		MapKit.block(
			CFrame.new(base + Vector3.new(x, l.plateY, z)) * CFrame.Angles(0, math.rad(yaw), 0),
			Vector3.new(sizeX, l.plateThickness, sizeZ),
			ghost(solid("CrustPlate", Config.MAP.LAVA_CRUST))
		).Parent = model
	end
end

-- Mini jib: truss post, arm toward the arrival, camera head spotting its own disc.
local function buildPitCam(model: Model, ped: Pedestal, _arrival: Vector3)
	local c = TUNING.PITCAM
	local floorCF = ped.floorCF
	local discLift = ped.discTop.Y - floorCF.Position.Y

	MapKit.truss(trussProps("PitCamPost", c.postSize, floorCF * CFrame.new(0, discLift + c.postSize.Y / 2, 0), Config.MAP.FIXTURE_GREY)).Parent = model
	MapKit.block(floorCF * CFrame.new(c.armOffset), c.armSize, housing("PitCamArm")).Parent = model

	local headCF = CFrame.lookAt((floorCF * CFrame.new(c.headOffset)).Position, ped.discTop)
	local head = MapKit.block(headCF, c.headSize, housing("PitCamHead"))
	head.Parent = model
	MapKit.spotLight(head, Enum.NormalId.Front, Config.MAP.KEY_WHITE, c.spot.angle, c.spot.brightness, c.spot.range)

	-- Lens barrel along the look (the cylinder axis is local Y; tip it onto -Z).
	MapKit.cylinder(headCF * CFrame.new(0, 0, -c.lens.offset) * CFrame.Angles(-math.pi / 2, 0, 0), c.lens.length, c.lens.radius, housing("PitCamLens")).Parent =
		model

	local tally = MapKit.block(headCF * CFrame.new(0, c.headSize.Y / 2 + c.tally / 2, 0), Vector3.one * c.tally, neon("PitCamTally", Config.DEBRIS_COLOR))
	tally.Parent = model
	MapKit.blink(tally, c.blink.period, c.blink.maxT)
end

-- Mini truss rig: a color spot and a key spot pooling on the disc.
local function buildRig(model: Model, ped: Pedestal, _arrival: Vector3)
	local r = TUNING.RIG
	local floorCF = ped.floorCF
	local discLift = ped.discTop.Y - floorCF.Position.Y

	for _, s in { -1, 1 } do
		MapKit.block(floorCF * CFrame.new(s * r.postX, discLift + r.postSize.Y / 2, 0), r.postSize, solid("RigPost", Config.MAP.STUDIO_GREY)).Parent = model
	end
	-- Truss long axis is Z; turn it onto the pedestal's X.
	MapKit.truss(trussProps("RigTruss", r.trussSize, floorCF * CFrame.new(0, r.trussY, 0) * CFrame.Angles(0, math.pi / 2, 0), Config.MAP.STUDIO_GREY)).Parent =
		model

	local fixtures = {
		{ x = -r.fixtureX, color = Config.PLATFORM_COLORS[1], spot = r.colorSpot },
		{ x = r.fixtureX, color = Config.MAP.KEY_WHITE, spot = r.keySpot },
	}
	for _, f in fixtures do
		local pos = (floorCF * CFrame.new(f.x, r.fixtureY, 0)).Position
		local fixture = MapKit.block(CFrame.lookAt(pos, ped.discTop), r.fixtureSize, housing("SpotFixture"))
		fixture.Parent = model
		MapKit.spotLight(fixture, Enum.NormalId.Front, f.color, f.spot.angle, f.spot.brightness, f.spot.range)
	end
end

local EXHIBIT_BUILDERS: { [string]: (Model, Pedestal, Vector3) -> () } = {
	Debris = buildDebris,
	Platform = buildPlatform,
	Tower = buildTower,
	Lava = buildLava,
	PitCam = buildPitCam,
	Piston = buildPiston,
	Rig = buildRig,
}

---------------------------------------------------------------------------
-- Return gate, pad and the data line to the hub (8 parts)
---------------------------------------------------------------------------

local function buildReturn(model: Model, S: Vector3, parent: Instance)
	MapKit.teleportPad(model, CFrame.new(S + TUNING.PAD_OFFSET), "BACK TO HUB", "Hub", Config.DEBRIS_COLOR)

	local g = TUNING.GATE
	local gateX = S.X + g.x
	local pillarY = S.Y + g.pillar.Y / 2
	for _, s in { -1, 1 } do
		MapKit.block(CFrame.new(gateX, pillarY, S.Z + s * g.pillarZ), g.pillar, solid("GatePillar", Config.MAP.VOID_BLACK)).Parent = model
		-- Neon on the pillar's inner face.
		local innerZ = S.Z + s * (g.pillarZ - g.pillar.Z / 2 - g.neonPillar.Z / 2)
		MapKit.block(CFrame.new(gateX, pillarY, innerZ), g.neonPillar, neon("GateNeon", Config.DEBRIS_COLOR)).Parent = model
	end

	local lintel = MapKit.block(CFrame.new(gateX, S.Y + g.pillar.Y + g.lintel.Y / 2, S.Z), g.lintel, solid("GateLintel", Config.MAP.VOID_BLACK))
	lintel.Parent = model
	-- +X faces the room, where visitors read it on their way out.
	MapKit.surfaceText(lintel, Enum.NormalId.Right, "BACK TO HUB", { TextColor3 = Config.DEBRIS_COLOR })
	MapKit.block(CFrame.new(gateX, S.Y + g.pillar.Y - g.neonLintel.Y / 2, S.Z), g.neonLintel, neon("GateNeon", Config.DEBRIS_COLOR)).Parent = model

	-- Data line to the hub gate. Hub.build runs first and leaves its LinkA
	-- attachment under `parent`; without it there is simply no beam.
	local linkB = Instance.new("Attachment")
	linkB.Name = "LinkB"
	linkB.Parent = lintel
	local linkA = parent:FindFirstChild("LinkA", true)
	if linkA and linkA:IsA("Attachment") then
		local beam = Instance.new("Beam")
		beam.Name = "LinkBeam"
		beam.Attachment0 = linkB
		beam.Attachment1 = linkA
		beam.Color = ColorSequence.new(Config.MAP.ELECTRIC_CYAN)
		beam.Width0 = TUNING.LINK_BEAM.width
		beam.Width1 = TUNING.LINK_BEAM.width
		beam.Transparency = NumberSequence.new(TUNING.LINK_BEAM.transparency)
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.FaceCamera = true
		beam.Segments = 1
		beam.Parent = lintel
	end
end

---------------------------------------------------------------------------

function Showcase.build(parent: Instance): Result
	local S = Config.ARENA_CENTER + Config.SHOWCASE_OFFSET
	local arrival = S + TUNING.ARRIVAL
	local model = MapKit.model("Showcase", parent)

	buildRoom(model, S)

	for _, spec in TUNING.EXHIBITS do
		local pedestal = buildPedestal(model, arrival, spec)
		hangSpotHead(model, S, pedestal.discTop)
		local build = EXHIBIT_BUILDERS[spec.key]
		if build then
			build(model, pedestal, arrival)
		end
	end

	buildReturn(model, S, parent)

	-- Arrival marker: a dim ring on the floor, not a pad.
	local marker = TUNING.ARRIVAL_MARKER
	MapKit.disc(CFrame.new(arrival + Vector3.new(0, marker.lift, 0)), marker.radius, marker.thickness, neon("ArrivalMarker", Config.MAP.GRID_CYAN)).Parent =
		model

	-- Visitors arrive facing the hero pedestal straight ahead (+X).
	local stand = arrival + Vector3.new(0, TUNING.STAND_HEIGHT, 0)
	return { spawnCFrame = CFrame.lookAt(stand, stand + Vector3.new(TUNING.ARC_RADIUS, 0, 0)) }
end

return Showcase

--!strict
-- The audience balcony over the pit: a glossy black deck with a cyan floor
-- frame and glass rails, standing on a 50-stud black monolith that carries the
-- show logo on its pit-facing wall. Back wall: framed scoreboard, blinking
-- ON AIR tally, magenta spawn ring, a neon gate around the SHOWCASE pad and
-- two white key spots. Builds model "SpawnHub" under `parent`.
-- Contract: returns the SpawnLocation, the "Status" TextLabel the server
-- writes round status into, and the hub floor's top Y.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("DebrisClear")
local Config = require(Shared.Config)
local MapKit = require(script.Parent.MapKit)

local Hub = {}

export type Result = {
	spawn: SpawnLocation,
	statusLabel: TextLabel?,
	floorY: number,
}

-- Hub-local studs: origin at the floor's top center, +X to the right when
-- facing the pit, -Z toward the pit. The floor is Config.HUB_SIZE (64 x 2 x 40)
-- and the rail edges derive from it; everything else is listed here.
local TUNING = {
	MONOLITH_HEIGHT = 50, -- PLACEHOLDER: floor bottom (world 86) down to the stage top (36)
	MONOLITH_LINE_YS = { -48, -42, -12, -6 }, -- PLACEHOLDER: neon lines on the pit face; the logo sits between the pairs
	MONOLITH_LINE_THICKNESS = 0.3, -- PLACEHOLDER
	MONOLITH_LOGO = { size = UDim2.fromScale(0.9, 0.3), position = UDim2.fromScale(0.05, 0.3), brightness = 1.5 }, -- PLACEHOLDER
	LOGO_STROKE = 4, -- PLACEHOLDER: cyan UIStroke thickness on the monolith logo
	BOARD_LOGO_STROKE = 3, -- PLACEHOLDER: same on the scoreboard title

	FRAME_INSET = 2, -- PLACEHOLDER: floor frame border this far in from every floor edge
	FRAME_RUNWAY_X = 8, -- PLACEHOLDER: two extra lines flanking the spawn toward the front rail
	FRAME_STRIP = { height = 0.16, width = 0.3 }, -- PLACEHOLDER: bottom flush with the floor top

	RAIL_GLASS = { height = 3.6, thickness = 0.3 }, -- PLACEHOLDER: outer face flush with the floor edge
	RAIL_CAP = { width = 0.6, height = 0.4 }, -- PLACEHOLDER: top at HUB_RAIL_HEIGHT (4)
	RAIL_STRIP = { height = 0.25, depth = 0.15 }, -- PLACEHOLDER: cyan line on the front cap's OUTER face only

	BACK_WALL = { height = 20, thickness = 1 }, -- PLACEHOLDER: world Y 88..108, flush with the floor's back edge
	WALL_TOP_TRIM = { height = 0.5, depth = 1.2 }, -- PLACEHOLDER
	WALL_POST = { size = Vector3.new(0.5, 20, 0.5), inset = 0.25, z = 18.9 }, -- PLACEHOLDER: verticals 0.35 proud of the wall
	WALL_POST_LIGHT = { brightness = 1, range = 25 }, -- PLACEHOLDER
	-- Both labels keep clear of the scoreboard frame (|x| <= 19, y <= 16.55),
	-- which stands proud of the wall and would hide anything behind it.
	ON_AIR_LABEL = { size = UDim2.fromScale(0.15, 0.14), position = UDim2.fromScale(0.05, 0.16) }, -- PLACEHOLDER: x +19.2..+28.8
	CONTROLS_LABEL = { size = UDim2.fromScale(0.4, 0.1), position = UDim2.fromScale(0.3, 0.02) }, -- PLACEHOLDER: centered above the board, y 17.6..19.6
	CONTROLS_TEXT = "E = GRAB   CLICK = THROW", -- PLACEHOLDER
	-- A Front-face gui runs from the part's +X edge toward -X (facing the back
	-- wall, +X is the viewer's left), so the ON AIR label (gui x 0.05..0.20)
	-- lands at x +19.2..+28.8 and the tally hangs centered over it at x 24.
	TALLY = { position = Vector3.new(24, 18.2, 18.9), size = Vector3.new(8, 1, 0.4) }, -- PLACEHOLDER
	TALLY_BLINK = { period = 1.0, maxT = 0.7 }, -- PLACEHOLDER

	BOARD = { position = Vector3.new(0, 9, 18.8), size = Vector3.new(36, 14, 0.6) }, -- PLACEHOLDER: world Y 90..104, 0.1 into the wall
	BOARD_TITLE = { size = UDim2.fromScale(1, 0.45), position = UDim2.fromScale(0, 0) }, -- PLACEHOLDER
	BOARD_STATUS = { size = UDim2.fromScale(0.9, 0.35), position = UDim2.fromScale(0.05, 0.5) }, -- PLACEHOLDER
	BOARD_FRAME = { z = 18.7, bar = 0.5, depth = 0.8, wide = 38, tall = 15, topY = 16.3, bottomY = 1.7, sideX = 18.75 }, -- PLACEHOLDER

	SPAWN = { position = Vector3.new(0, 0.15, 10), size = Vector3.new(12, 0.3, 12) }, -- PLACEHOLDER: HubSpawn
	SPAWN_STRIP = { offset = 6.05, length = 12.6, width = 0.5, height = 0.25 }, -- PLACEHOLDER: magenta ring straddling the pad edge
	SPAWN_LIGHT = { brightness = 1.5, range = 18 }, -- PLACEHOLDER

	PAD_CFRAME = CFrame.new(25, 0.3, 11.5), -- PLACEHOLDER: pad X 21..29, clear of the spawn (X +-6) and the side rail
	PAD_TEXT_COLOR = Color3.fromRGB(8, 10, 20), -- PLACEHOLDER: label on the cyan pad

	GATE = { x = 25, z = 16.5, span = 11.5 }, -- PLACEHOLDER: pillar centers +-span/2; 2 studs in front of the back wall
	GATE_PILLAR = Vector3.new(1.5, 9, 1.5), -- PLACEHOLDER: world Y 88..97
	GATE_LINTEL = Vector3.new(13, 1.5, 1.5), -- PLACEHOLDER: center world (25, 97.75, 111.5) = LinkA
	GATE_NEON = { thickness = 0.3, lintelLength = 11 }, -- PLACEHOLDER: on the pillars' inner faces and under the lintel

	KEY_LIGHT = { x = 16, y = 19, z = 18.4, size = Vector3.new(1.4, 1.4, 2), aim = Vector3.new(0, -1, -1.1) }, -- PLACEHOLDER
	KEY_SPOT = { angle = 60, brightness = 2.5, range = 45 }, -- PLACEHOLDER
}

-- Neon trim nothing may rest on, bump into or click: never collidable,
-- never queried, never touched, no shadow.
local function trim(props: MapKit.Props): MapKit.Props
	props.CanCollide = false
	props.CanQuery = false
	props.CanTouch = false
	props.CastShadow = false
	return props
end

local function neon(name: string, color: Color3): MapKit.Props
	return trim({ Name = name, Color = color, Material = Enum.Material.Neon })
end

local function plastic(name: string, color: Color3): MapKit.Props
	return { Name = name, Color = color, Material = Enum.Material.SmoothPlastic }
end

local function glass(name: string): MapKit.Props
	return {
		Name = name,
		Color = Config.MAP.RAIL_GLASS,
		Material = Enum.Material.Glass,
		Transparency = Config.RAIL_GLASS_TRANSPARENCY,
	}
end

-- Show logo: GothamBlack in the debris magenta with a cyan UIStroke. The
-- label's own faint dark stroke is turned off so the cyan outline stays clean.
local function logoText(part: BasePart, face: Enum.NormalId, text: string, strokeThickness: number, size: UDim2, position: UDim2): (SurfaceGui, TextLabel)
	local gui, label = MapKit.surfaceText(part, face, text, {
		Size = size,
		Position = position,
		Font = Enum.Font.GothamBlack,
		TextColor3 = Config.DEBRIS_COLOR,
		TextStrokeTransparency = 1,
	})
	local stroke = Instance.new("UIStroke")
	stroke.Color = Config.MAP.ELECTRIC_CYAN
	stroke.Thickness = strokeThickness
	stroke.Parent = label
	return gui, label
end

local function captionProps(): MapKit.Props
	return { Font = Enum.Font.Gotham, TextColor3 = Config.MAP.ELECTRIC_CYAN }
end

function Hub.build(parent: Instance): Result
	local c = Config.ARENA_CENTER
	local top = c + Config.HUB_OFFSET
	-- -Z faces the arena, so "front" is the edge overlooking the pit.
	local hubCFrame = CFrame.lookAt(top, Vector3.new(c.X, top.Y, c.Z))
	local function h(x: number, y: number, z: number): CFrame
		return hubCFrame * CFrame.new(x, y, z)
	end

	local W, floorT, D = Config.HUB_SIZE.X, Config.HUB_SIZE.Y, Config.HUB_SIZE.Z
	local hw, hd = W / 2, D / 2
	local railTop = Config.HUB_RAIL_HEIGHT

	local model = MapKit.model("SpawnHub")

	-- Deck and the monolith it stands on, logo on the pit face between two
	-- pairs of neon lines.
	MapKit.block(h(0, -floorT / 2, 0), Config.HUB_SIZE, plastic("HubFloor", Config.MAP.PANEL_BLACK)).Parent = model

	local monolithH = TUNING.MONOLITH_HEIGHT
	local monolith = MapKit.block(h(0, -floorT - monolithH / 2, 0), Vector3.new(W, monolithH, D), plastic("Monolith", Config.MAP.VOID_BLACK))
	monolith.Parent = model
	local logo = TUNING.MONOLITH_LOGO
	local logoGui = logoText(monolith, Enum.NormalId.Front, "DEBRIS CLEAR", TUNING.LOGO_STROKE, logo.size, logo.position)
	logoGui.Brightness = logo.brightness

	local lineT = TUNING.MONOLITH_LINE_THICKNESS
	for _, y in TUNING.MONOLITH_LINE_YS do
		MapKit.block(h(0, y, -(hd + lineT / 2)), Vector3.new(W, lineT, lineT), neon("MonolithLine", Config.MAP.GRID_CYAN)).Parent = model
	end

	-- Floor frame: a border inset from the edges plus a runway flanking the
	-- spawn toward the front rail. Bottom flush with the floor top.
	local strip = TUNING.FRAME_STRIP
	local frameW, frameD = W - 2 * TUNING.FRAME_INSET, D - 2 * TUNING.FRAME_INSET
	local function frameLine(cf: CFrame, size: Vector3)
		MapKit.block(cf, size, neon("FloorFrame", Config.MAP.GRID_CYAN)).Parent = model
	end
	for _, sz in { -1, 1 } do
		frameLine(h(0, strip.height / 2, sz * frameD / 2), Vector3.new(frameW, strip.height, strip.width))
	end
	for _, x in { -frameW / 2, frameW / 2, -TUNING.FRAME_RUNWAY_X, TUNING.FRAME_RUNWAY_X } do
		frameLine(h(x, strip.height / 2, 0), Vector3.new(strip.width, strip.height, frameD))
	end

	-- Front rail: glass, a matte grey cap, and the cyan line on the cap's OUTER
	-- face only, so nothing blooms at the bottom of the play view.
	local rg, cap, rs = TUNING.RAIL_GLASS, TUNING.RAIL_CAP, TUNING.RAIL_STRIP
	local capY = railTop - cap.height / 2
	local frontZ = -(hd - rg.thickness / 2)
	MapKit.block(h(0, rg.height / 2, frontZ), Vector3.new(W, rg.height, rg.thickness), glass("FrontRail")).Parent = model
	MapKit.block(h(0, capY, frontZ), Vector3.new(W, cap.height, cap.width), plastic("FrontRailCap", Config.MAP.STUDIO_GREY)).Parent = model
	MapKit.block(
		h(0, capY, -(hd + cap.width / 2 - rg.thickness / 2 + rs.depth / 2)),
		Vector3.new(W, rs.height, rs.depth),
		neon("FrontRailStrip", Config.MAP.ELECTRIC_CYAN)
	).Parent = model

	-- Side rails with dim cyan caps.
	for _, sx in { -1, 1 } do
		local x = sx * (hw - rg.thickness / 2)
		MapKit.block(h(x, rg.height / 2, 0), Vector3.new(rg.thickness, rg.height, D), glass("SideRail")).Parent = model
		MapKit.block(h(x, capY, 0), Vector3.new(cap.width, cap.height, D), neon("SideRailCap", Config.MAP.GRID_CYAN)).Parent = model
	end

	-- Back wall with ON AIR (viewer's left) and the controls caption centered
	-- above the scoreboard.
	local wall = TUNING.BACK_WALL
	local wallZ = hd - wall.thickness / 2
	local backWall = MapKit.block(h(0, wall.height / 2, wallZ), Vector3.new(W, wall.height, wall.thickness), plastic("BackWall", Config.MAP.DEEP_NAVY))
	backWall.Parent = model
	local onAirLabel = TUNING.ON_AIR_LABEL
	local wallGui, onAir = MapKit.surfaceText(backWall, Enum.NormalId.Front, "ON AIR", {
		Name = "OnAir",
		Size = onAirLabel.size,
		Position = onAirLabel.position,
		TextColor3 = Config.DEBRIS_COLOR,
	})
	local controls = onAir:Clone()
	controls.Name = "Controls"
	controls.Text = TUNING.CONTROLS_TEXT
	controls.Size = TUNING.CONTROLS_LABEL.size
	controls.Position = TUNING.CONTROLS_LABEL.position
	controls.Font = Enum.Font.Gotham
	controls.TextColor3 = Config.MAP.ELECTRIC_CYAN
	controls.Parent = wallGui

	-- Wall trim: dim strip along the top, bright posts at both ends (lit).
	local topTrim = TUNING.WALL_TOP_TRIM
	MapKit.block(h(0, wall.height + topTrim.height / 2, wallZ), Vector3.new(W, topTrim.height, topTrim.depth), neon("BackWallTrim", Config.MAP.GRID_CYAN)).Parent = model
	local post = TUNING.WALL_POST
	for _, sx in { -1, 1 } do
		local vertical = MapKit.block(h(sx * (hw - post.inset), wall.height / 2, post.z), post.size, neon("BackWallTrim", Config.MAP.ELECTRIC_CYAN))
		vertical.Parent = model
		MapKit.pointLight(vertical, Config.MAP.ELECTRIC_CYAN, TUNING.WALL_POST_LIGHT.brightness, TUNING.WALL_POST_LIGHT.range)
	end

	-- Blinking tally over the ON AIR text.
	local tally = MapKit.block(h(TUNING.TALLY.position.X, TUNING.TALLY.position.Y, TUNING.TALLY.position.Z), TUNING.TALLY.size, neon("OnAirTally", Config.DEBRIS_COLOR))
	tally.Parent = model
	MapKit.blink(tally, TUNING.TALLY_BLINK.period, TUNING.TALLY_BLINK.maxT)

	-- Scoreboard: logo title over the "Status" line the server writes into.
	local bp = TUNING.BOARD.position
	local board = MapKit.block(h(bp.X, bp.Y, bp.Z), TUNING.BOARD.size, plastic("StatusBoard", Config.MAP.BOARD_NAVY))
	board.Parent = model
	local boardGui = logoText(board, Enum.NormalId.Front, "DEBRIS CLEAR", TUNING.BOARD_LOGO_STROKE, TUNING.BOARD_TITLE.size, TUNING.BOARD_TITLE.position)
	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "Status"
	statusLabel.BackgroundTransparency = 1
	statusLabel.Size = TUNING.BOARD_STATUS.size
	statusLabel.Position = TUNING.BOARD_STATUS.position
	statusLabel.Font = Enum.Font.GothamBold
	statusLabel.TextScaled = true
	statusLabel.TextColor3 = Color3.new(1, 1, 1)
	statusLabel.TextStrokeTransparency = 0.6
	statusLabel.Text = ""
	statusLabel.Parent = boardGui

	local bf = TUNING.BOARD_FRAME
	local function frameBar(x: number, y: number, size: Vector3)
		MapKit.block(h(x, y, bf.z), size, neon("BoardFrame", Config.MAP.ELECTRIC_CYAN)).Parent = model
	end
	frameBar(0, bf.topY, Vector3.new(bf.wide, bf.bar, bf.depth))
	frameBar(0, bf.bottomY, Vector3.new(bf.wide, bf.bar, bf.depth))
	frameBar(-bf.sideX, bp.Y, Vector3.new(bf.bar, bf.tall, bf.depth))
	frameBar(bf.sideX, bp.Y, Vector3.new(bf.bar, bf.tall, bf.depth))

	-- Spawn pad ringed in magenta: the only enabled spawn in the place (Arena
	-- disables every other SpawnLocation before building the hub).
	local sp = TUNING.SPAWN
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Enabled = true
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.BottomSurface = Enum.SurfaceType.Smooth
	spawn.Size = sp.size
	spawn.Color = Config.MAP.PEDESTAL_BLACK
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.CFrame = h(sp.position.X, sp.position.Y, sp.position.Z)
	spawn.Parent = model
	MapKit.pointLight(spawn, Config.DEBRIS_COLOR, TUNING.SPAWN_LIGHT.brightness, TUNING.SPAWN_LIGHT.range)

	local ss = TUNING.SPAWN_STRIP
	for _, s in { -1, 1 } do
		MapKit.block(
			h(sp.position.X, ss.height / 2, sp.position.Z + s * ss.offset),
			Vector3.new(ss.length, ss.height, ss.width),
			neon("SpawnStrip", Config.DEBRIS_COLOR)
		).Parent = model
		MapKit.block(
			h(sp.position.X + s * ss.offset, ss.height / 2, sp.position.Z),
			Vector3.new(ss.width, ss.height, ss.length),
			neon("SpawnStrip", Config.DEBRIS_COLOR)
		).Parent = model
	end

	-- SHOWCASE pad in front of its gate. The helper's label is white-ish;
	-- darken it against the cyan neon.
	local pad = MapKit.teleportPad(model, hubCFrame * TUNING.PAD_CFRAME, "SHOWCASE", "Showcase", Config.MAP.ELECTRIC_CYAN)
	local padText = pad:FindFirstChild("Text")
	local padLabel = if padText then padText:FindFirstChild("Label") else nil
	if padLabel and padLabel:IsA("TextLabel") then
		padLabel.TextColor3 = TUNING.PAD_TEXT_COLOR
	end

	-- Gate: two black pillars, a lintel captioned SHOWCASE, cyan neon on the
	-- inner faces and under the lintel. LinkA at the lintel center is where
	-- the showcase's return-gate LinkBeam ends.
	local gate, pillar, lintel, gn = TUNING.GATE, TUNING.GATE_PILLAR, TUNING.GATE_LINTEL, TUNING.GATE_NEON
	for _, s in { -1, 1 } do
		local px = gate.x + s * gate.span / 2
		MapKit.block(h(px, pillar.Y / 2, gate.z), pillar, plastic("GatePillar", Config.MAP.VOID_BLACK)).Parent = model
		-- Inner face of the pillar, half the neon thickness proud.
		local nx = px - s * (pillar.X / 2 + gn.thickness / 2)
		MapKit.block(h(nx, pillar.Y / 2, gate.z), Vector3.new(gn.thickness, pillar.Y, gn.thickness), neon("GateNeon", Config.MAP.ELECTRIC_CYAN)).Parent = model
	end
	local lintelPart = MapKit.block(h(gate.x, pillar.Y + lintel.Y / 2, gate.z), lintel, plastic("GateLintel", Config.MAP.VOID_BLACK))
	lintelPart.Parent = model
	MapKit.surfaceText(lintelPart, Enum.NormalId.Front, "SHOWCASE", captionProps())
	local linkA = Instance.new("Attachment")
	linkA.Name = "LinkA"
	linkA.Parent = lintelPart
	MapKit.block(
		h(gate.x, pillar.Y - gn.thickness / 2, gate.z),
		Vector3.new(gn.lintelLength, gn.thickness, gn.thickness),
		neon("GateNeon", Config.MAP.ELECTRIC_CYAN)
	).Parent = model

	-- Two white key spots high on the back wall, looking down across the floor.
	local key = TUNING.KEY_LIGHT
	local aim = hubCFrame:VectorToWorldSpace(key.aim)
	for _, sx in { -1, 1 } do
		local pos = h(sx * key.x, key.y, key.z).Position
		local fixture = MapKit.block(CFrame.lookAt(pos, pos + aim), key.size, plastic("KeyLight", Config.MAP.FIXTURE_GREY))
		fixture.Parent = model
		MapKit.spotLight(fixture, Enum.NormalId.Front, Config.MAP.KEY_WHITE, TUNING.KEY_SPOT.angle, TUNING.KEY_SPOT.brightness, TUNING.KEY_SPOT.range)
	end

	model.Parent = parent
	return { spawn = spawn, statusLabel = statusLabel, floorY = top.Y }
end

return Hub

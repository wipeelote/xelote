--!strict
-- The crater under the podiums: a lava lake with a hot core and heart, cooled
-- crust plates, the visual-only piston sleeves, an octagonal black crater wall
-- rising to the glossy stage at Y 36, a 12-sided backdrop skyline carrying the
-- show logo, and two audience banks flashing cameras from the wings.
-- 109 parts. LavaBase is the pit floor and the only collidable part inside the
-- crater; the other lava layers, crust, sleeves, every neon trim and the
-- audience tiers are CanCollide/CanQuery false so nothing rests above the kill line.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("DebrisClear")
local Config = require(Shared.Config)
local MapKit = require(script.Parent.MapKit)

local Pit = {}

local TUNING = {
	-- Lava. Heights are offsets above the pit floor (ARENA_CENTER.Y - PIT_DEPTH = 15).
	LAVA_BASE_RADIUS = 100, -- PLACEHOLDER: runs on under the stage, out of sight
	LAVA_BASE_THICKNESS = 2, -- PLACEHOLDER
	LAVA_CORE_RADIUS = 44, -- PLACEHOLDER: bright core under the podiums
	LAVA_HEART_RADIUS = 12, -- PLACEHOLDER: where the PIT CAM spot pools
	HOT_SPOT_RADIUS = 14, -- PLACEHOLDER
	HOT_SPOTS = { Vector2.new(30, -18), Vector2.new(-26, 28) }, -- PLACEHOLDER: XZ centers
	EMBER_RATE = 15, -- PLACEHOLDER: embers per second rising off the core (2-4 s lifetime keeps ~45 aloft)
	-- Crust plates floating on the core: {x, z, yawDeg, sizeX, sizeZ}. Every plate
	-- clears the sleeves by at least a stud and stays inside the crater (r < 67.8).
	CRUST_THICKNESS = 0.4, -- PLACEHOLDER
	CRUST_PLATES = { -- PLACEHOLDER
		{ 4, -10, 15, 16, 11 },
		{ -33, 26, 70, 12, 9 },
		{ 33, 30, 40, 10, 14 },
		{ -29, -34, 110, 18, 8 },
		{ 33, -29, 30, 9, 9 },
		{ -36, 12, 160, 14, 10 },
		{ 4, 36, 5, 12, 12 },
		{ -6, -38, 80, 16, 9 },
		{ 44, 30, 125, 11, 7 },
		{ -48, -30, 20, 13, 10 },
		{ 46, -36, 95, 15, 9 },
		{ -46, 34, 50, 10, 12 },
		{ 18, 54, 140, 9, 6 },
		{ -24, -54, 35, 12, 8 },
	},
	-- Piston sleeve and heat ring at the foot of each rod.
	SLEEVE_RADIUS = 5.5, -- PLACEHOLDER
	SLEEVE_HEIGHT = 4.2, -- PLACEHOLDER: top (Y 19.4) sits 0.1 under the crushed deck's under-disc
	HEAT_RING_RADIUS = 6.5, -- PLACEHOLDER
	-- Crater wall and stage.
	STAGE_TOP = 36, -- PLACEHOLDER: world Y of the stage surface
	STAGE_HOLE = 68, -- PLACEHOLDER: apothem of the octagonal hole; the wall stands 0.2 inside it
	STAGE_REACH = 220, -- PLACEHOLDER: stage half-width
	WALL_THICKNESS = 1.5, -- PLACEHOLDER
	SIDE_LENGTH = 56.8, -- PLACEHOLDER: wall and rim-strip block length (octagon side is 56.2 inside, 57.4 outside)
	RIM_POST_HEIGHT = 8, -- PLACEHOLDER
	-- Backdrop.
	BACKDROP_APOTHEM = 140, -- PLACEHOLDER: inner face of the 12-gon
	BACKDROP_HEIGHTS = { 46, 40 }, -- PLACEHOLDER: tall and short panels alternate
	PANEL_LENGTH = 75.6, -- PLACEHOLDER: 12-gon side is 75.0 inside, 76.1 outside
	LOGO_PANELS = { [9] = "DEBRIS", [11] = "CLEAR" }, -- panel index (1 = angle 0, +30 deg each): left and right of T8 from the hub
	LOGO_PIXELS_PER_STUD = 4, -- PLACEHOLDER: low so TextScaled's 100 px ceiling still fills the panel
	-- Audience banks.
	AUDIENCE_TIERS = 6, -- PLACEHOLDER
	AUDIENCE_INNER_X = 101, -- PLACEHOLDER: center X of the lowest tier (tiers step out 6 per row)
	AUDIENCE_LENGTH = 80, -- PLACEHOLDER
	FLASH_CENTER = Vector2.new(116, 57), -- PLACEHOLDER: (X, Y) of the flash slab, 3.5 above the treads
	FLASH_RATE = 1.2, -- PLACEHOLDER: camera pops per second per bank
}

local SEAT_LIGHT = Color3.fromRGB(26, 26, 40)
local SEAT_DARK = Color3.fromRGB(12, 12, 20)
local POST_LIGHT = Color3.fromRGB(0, 200, 255)

-- Props for a set piece (collidable; all of these sit below the kill line).
local function solid(name: string, color: Color3): MapKit.Props
	return { Name = name, Color = color, Material = Enum.Material.SmoothPlastic }
end

-- Props for a part nothing may rest on or ray-hit: lava layers, crust,
-- sleeves, neon trim, audience tiers.
local function ghost(name: string, color: Color3, material: Enum.Material): MapKit.Props
	return {
		Name = name,
		Color = color,
		Material = material,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = material ~= Enum.Material.Neon,
	}
end

-- Discs are cylinders rotated 90 degrees about Z, so their local +X (Right)
-- is world up; emitters on them must emit out of Right, not Top.
local function embers(part: BasePart, rate: number): ParticleEmitter
	return MapKit.emitter(part, {
		Name = "Embers",
		Color = ColorSequence.new(Color3.fromRGB(255, 140, 50), Color3.fromRGB(255, 40, 10)),
		Size = NumberSequence.new(0.25, 0.7),
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

local function haze(part: BasePart): ParticleEmitter
	return MapKit.emitter(part, {
		Name = "Haze",
		Color = ColorSequence.new(Color3.fromRGB(140, 30, 12)),
		Size = NumberSequence.new(10, 16),
		Transparency = NumberSequence.new(0.88, 1),
		Lifetime = NumberRange.new(5, 7),
		Speed = NumberRange.new(1.5),
		Rate = 3,
		LightEmission = 0.3,
		EmissionDirection = Enum.NormalId.Right,
	})
end

-- Random white pops across the slab: an audience taking pictures.
local function cameraFlash(part: BasePart): ParticleEmitter
	return MapKit.emitter(part, {
		Name = "CameraFlash",
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Rate = TUNING.FLASH_RATE,
		Lifetime = NumberRange.new(0.12),
		Speed = NumberRange.new(0),
		Size = NumberSequence.new(2.2),
		Color = ColorSequence.new(Color3.new(1, 1, 1)),
		Transparency = NumberSequence.new(0, 1),
		LightEmission = 1,
		LightInfluence = 0,
		Brightness = 3,
	})
end

-- Show logo on a backdrop panel: magenta GothamBlack with a cyan outline.
local function logoText(panel: BasePart, text: string)
	local gui, label = MapKit.surfaceText(panel, Enum.NormalId.Front, text, {
		Size = UDim2.fromScale(0.9, 0.5),
		Position = UDim2.fromScale(0.05, 0.05),
		TextColor3 = Config.DEBRIS_COLOR,
		TextStrokeTransparency = 1,
	})
	gui.PixelsPerStud = TUNING.LOGO_PIXELS_PER_STUD
	local stroke = Instance.new("UIStroke")
	stroke.Color = Config.MAP.ELECTRIC_CYAN
	stroke.Thickness = 4
	stroke.Parent = label
end

-- Zero-part seat rows: ten alternating shade blocks down each tier's tread.
local function seatRows(tier: BasePart)
	local keypoints = {}
	for k = 0, 9 do
		local shade = if k % 2 == 0 then SEAT_LIGHT else SEAT_DARK
		table.insert(keypoints, ColorSequenceKeypoint.new(k / 10, shade))
		-- Hard edge just before the next block; a sequence has to end at 1.
		table.insert(keypoints, ColorSequenceKeypoint.new(if k == 9 then 1 else (k + 1) / 10 - 0.0001, shade))
	end

	local gui = Instance.new("SurfaceGui")
	gui.Name = "Seats"
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 4
	gui.LightInfluence = 1
	gui.Parent = tier

	-- White base so the gradient's colors show exactly (UIGradient multiplies).
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = gui

	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(keypoints)
	gradient.Parent = frame
end

-- Deck centers, laid out exactly as Arena.buildPlatform does.
local function platformCenters(): { Vector3 }
	local centers = {}
	for slot = 1, Config.MAX_PLAYERS do
		local a = math.rad(45 + 90 * (slot - 1))
		table.insert(centers, Config.ARENA_CENTER + Vector3.new(math.cos(a), 0, math.sin(a)) * Config.ARENA_RADIUS)
	end
	return centers
end

function Pit.build(parent: Instance)
	local c = Config.ARENA_CENTER
	local floorY = c.Y - Config.PIT_DEPTH -- lava top
	local stageTop = TUNING.STAGE_TOP
	local model = MapKit.model("Pit")

	-- P1-P4 lava layers, each at its own height so none z-fight
	-- (tops at 15.0 / 15.4 / 15.65 and 15.7 for the hot spots).
	local base = MapKit.disc(
		CFrame.new(c.X, floorY - TUNING.LAVA_BASE_THICKNESS / 2, c.Z),
		TUNING.LAVA_BASE_RADIUS,
		TUNING.LAVA_BASE_THICKNESS,
		{ Name = "LavaBase", Color = Config.MAP.LAVA_BASE, Material = Enum.Material.Neon }
	)
	base.Parent = model
	MapKit.pointLight(base, Config.MAP.LAVA_CORE, 3, 60)

	local core = MapKit.disc(
		CFrame.new(c.X, floorY + 0.2, c.Z),
		TUNING.LAVA_CORE_RADIUS,
		0.4,
		ghost("LavaCore", Config.MAP.LAVA_CORE, Enum.Material.Neon)
	)
	core.Parent = model
	embers(core, TUNING.EMBER_RATE)
	haze(core)

	MapKit.disc(
		CFrame.new(c.X, floorY + 0.525, c.Z),
		TUNING.LAVA_HEART_RADIUS,
		0.25,
		ghost("LavaHeart", Config.MAP.LAVA_HEART, Enum.Material.Neon)
	).Parent = model

	for _, spot in TUNING.HOT_SPOTS do
		MapKit.disc(
			CFrame.new(c.X + spot.X, floorY + 0.5, c.Z + spot.Y),
			TUNING.HOT_SPOT_RADIUS,
			0.4,
			ghost("HotSpot", Config.MAP.LAVA_FLOW, Enum.Material.Neon)
		).Parent = model
	end

	-- P5 crust plates, 0.7 above the lava top.
	for _, plate in TUNING.CRUST_PLATES do
		local x, z, yaw, w, d = plate[1], plate[2], plate[3], plate[4], plate[5]
		MapKit.block(
			CFrame.new(c.X + x, floorY + 0.7 + TUNING.CRUST_THICKNESS / 2, c.Z + z) * CFrame.Angles(0, math.rad(yaw), 0),
			Vector3.new(w, TUNING.CRUST_THICKNESS, d),
			ghost("CrustPlate", Config.MAP.LAVA_CRUST, Enum.Material.SmoothPlastic)
		).Parent = model
	end

	-- P6/P7 sleeve and heat ring at the foot of each piston rod. Visual only:
	-- the crushed deck's under-disc stops 0.1 above the sleeve top.
	for _, center in platformCenters() do
		MapKit.column(
			Vector3.new(center.X, floorY + 0.2, center.Z),
			TUNING.SLEEVE_HEIGHT,
			TUNING.SLEEVE_RADIUS,
			ghost("PistonSleeve", Config.MAP.PEDESTAL_BLACK, Enum.Material.SmoothPlastic)
		).Parent = model
		local ring = MapKit.disc(
			CFrame.new(center.X, floorY + 0.65, center.Z),
			TUNING.HEAT_RING_RADIUS,
			0.4,
			ghost("HeatRing", Config.MAP.LAVA_CORE, Enum.Material.Neon)
		)
		ring.Parent = model
		MapKit.pointLight(ring, Config.MAP.LAVA_LIGHT, 1.5, 40)
	end

	-- P8 crater wall: eight sides from the lava up to the stage. The inner face
	-- stands 0.2 proud of the stage hole so the two never z-fight; the outer
	-- face is buried in the stage.
	local hole = TUNING.STAGE_HOLE
	local wallApothem = hole - 0.2
	local wallHeight = stageTop - floorY
	MapKit.ring(Vector3.new(c.X, floorY + wallHeight / 2, c.Z), wallApothem + TUNING.WALL_THICKNESS / 2, 8, 0, function(_, cf)
		MapKit.block(
			cf,
			Vector3.new(TUNING.SIDE_LENGTH, wallHeight, TUNING.WALL_THICKNESS),
			solid("CraterWall", Config.MAP.VOID_BLACK)
		).Parent = model
	end)

	-- P9 cyan rim strip over the wall/stage seam.
	MapKit.ring(Vector3.new(c.X, stageTop + 0.25, c.Z), wallApothem + 0.3, 8, 0, function(_, cf)
		MapKit.block(
			cf,
			Vector3.new(TUNING.SIDE_LENGTH, 0.5, 0.6),
			ghost("CraterRimStrip", Config.MAP.ELECTRIC_CYAN, Enum.Material.Neon)
		).Parent = model
	end)

	-- P10 rim posts on the octagon vertices; every other one carries a light
	-- (the pit's light budget is 12: lava 1, heat rings 4, rim 4, backdrop 3).
	local vertexRadius = hole / math.cos(math.rad(22.5))
	for k = 0, 7 do
		local a = math.rad(22.5 + 45 * k)
		local post = MapKit.block(
			CFrame.new(c.X + vertexRadius * math.cos(a), stageTop + TUNING.RIM_POST_HEIGHT / 2, c.Z + vertexRadius * math.sin(a)),
			Vector3.new(1.2, TUNING.RIM_POST_HEIGHT, 1.2),
			ghost("RimPost", Config.MAP.ELECTRIC_CYAN, Enum.Material.Neon)
		)
		post.Parent = model
		if k % 2 == 0 then
			MapKit.pointLight(post, Config.MAP.ELECTRIC_CYAN, 1.5, 25)
		end
	end

	-- P11 stage: four slabs around a square hole, plus one wedge per corner
	-- that cuts the hole down to the octagon (hypotenuse on the crater apothem).
	local reach = TUNING.STAGE_REACH
	local stageY = stageTop - 1
	local stageProps = solid("StageGround", Config.MAP.VOID_BLACK)
	local mid = (reach + hole) / 2
	local span = reach - hole
	MapKit.block(CFrame.new(c.X, stageY, c.Z + mid), Vector3.new(2 * reach, 2, span), stageProps).Parent = model
	MapKit.block(CFrame.new(c.X, stageY, c.Z - mid), Vector3.new(2 * reach, 2, span), stageProps).Parent = model
	MapKit.block(CFrame.new(c.X + mid, stageY, c.Z), Vector3.new(span, 2, 2 * hole), stageProps).Parent = model
	MapKit.block(CFrame.new(c.X - mid, stageY, c.Z), Vector3.new(span, 2, 2 * hole), stageProps).Parent = model

	local leg = hole - hole * math.tan(math.rad(22.5)) -- square corner to the octagon vertex
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local wedge = MapKit.wedge(stageProps)
			wedge.Size = Vector3.new(2, leg, leg)
			-- Thickness along world Y; the right angle sits on the square corner.
			wedge.CFrame = CFrame.fromMatrix(
				Vector3.new(c.X + (hole - leg / 2) * sx, stageY, c.Z + (hole - leg / 2) * sz),
				Vector3.new(0, sx * sz, 0),
				Vector3.new(-sx, 0, 0),
				Vector3.new(0, 0, sz)
			)
			wedge.Parent = model
		end
	end

	-- P12/P13 backdrop: twelve panels of alternating height, a dim cyan strip
	-- on each top, and the show logo on the two panels flanking T8 from the hub.
	local panelRadius = TUNING.BACKDROP_APOTHEM + 1
	MapKit.ring(Vector3.new(c.X, 0, c.Z), panelRadius, 12, 0, function(i, cf)
		local h = TUNING.BACKDROP_HEIGHTS[if i % 2 == 1 then 1 else 2]
		local panel = MapKit.block(
			cf * CFrame.new(0, stageTop + h / 2, 0),
			Vector3.new(TUNING.PANEL_LENGTH, h, 2),
			solid("BackdropWall", Config.MAP.BACKDROP_BLACK)
		)
		panel.Parent = model
		local text = TUNING.LOGO_PANELS[i]
		if text then
			logoText(panel, text)
		end
		MapKit.block(
			cf * CFrame.new(0, stageTop + h + 0.25, 0),
			Vector3.new(TUNING.PANEL_LENGTH, 0.5, 2.4),
			ghost("BackdropTopStrip", Config.MAP.GRID_CYAN, Enum.Material.Neon)
		).Parent = model
	end)

	-- P14 corner posts, all full height so the skyline steps between them;
	-- every fourth one carries a light.
	local postRadius = TUNING.BACKDROP_APOTHEM / math.cos(math.rad(15))
	local postHeight = math.max(TUNING.BACKDROP_HEIGHTS[1], TUNING.BACKDROP_HEIGHTS[2])
	for k = 0, 11 do
		local a = math.rad(15 + 30 * k)
		local post = MapKit.block(
			CFrame.new(c.X + postRadius * math.cos(a), stageTop + postHeight / 2, c.Z + postRadius * math.sin(a)),
			Vector3.new(0.8, postHeight, 0.8),
			ghost("BackdropCornerPost", Config.MAP.ELECTRIC_CYAN, Enum.Material.Neon)
		)
		post.Parent = model
		if k % 4 == 0 then
			MapKit.pointLight(post, POST_LIGHT, 1, 40)
		end
	end

	-- P15/P16 audience banks in the wings: six tiers each, with an invisible
	-- slab lying along the tread slope that pops camera flashes.
	local slope = math.atan(5 / 6) -- each tier rises 5 over a 6-stud tread
	for _, side in { 1, -1 } do
		for k = 0, TUNING.AUDIENCE_TIERS - 1 do
			local tierHeight = 5 * (k + 1)
			local tier = MapKit.block(
				CFrame.new(c.X + side * (TUNING.AUDIENCE_INNER_X + 6 * k), stageTop + tierHeight / 2, c.Z),
				Vector3.new(6, tierHeight, TUNING.AUDIENCE_LENGTH),
				ghost("AudienceBank", Config.MAP.AUDIENCE_NAVY, Enum.Material.SmoothPlastic)
			)
			tier.Parent = model
			seatRows(tier)
		end

		local slab = MapKit.block(
			CFrame.new(c.X + side * TUNING.FLASH_CENTER.X, TUNING.FLASH_CENTER.Y, c.Z) * CFrame.Angles(0, 0, side * slope),
			Vector3.new(40, 3, TUNING.AUDIENCE_LENGTH - 4),
			{
				Name = "AudienceFlash",
				Color = Config.MAP.AUDIENCE_NAVY,
				Material = Enum.Material.SmoothPlastic,
				Transparency = 1,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				CastShadow = false,
			}
		)
		slab.Parent = model
		cameraFlash(slab)
	end

	model.Parent = parent
end

return Pit

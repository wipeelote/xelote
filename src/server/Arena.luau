--!strict
-- Builds the arena: 4 hexagonal platforms on piston rods around a central pit,
-- a ring-meter SurfaceGui on each deck, and a raised spawn hub overlooking it all.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("DebrisClear")
local Config = require(Shared.Config)
local HexGeometry = require(Shared.HexGeometry)

local Arena = {}

export type Platform = {
	slot: number,
	model: Model,
	topCFrame: CFrame, -- center of the top surface, oriented with the hex
	restPivots: { [BasePart]: CFrame },
	dropped: boolean,
}

Arena.platforms = {} :: { Platform }
Arena.folder = nil :: Folder?
Arena.hubSpawn = nil :: SpawnLocation?
Arena.hubFloorY = 0
Arena.boardStatus = nil :: TextLabel?

local PLATFORM_TAG = "DebrisClearPlatform"

local function anchoredPart(className: string, props: { [string]: any }): BasePart
	local part = Instance.new(className) :: BasePart
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(part :: any)[k] = v
	end
	return part
end

-- Two right-angle WedgeParts that fill triangle (a, b, c), `thickness` thick,
-- centered on the triangle's plane.
local function triangleWedges(a: Vector3, b: Vector3, c: Vector3, thickness: number, props: { [string]: any }): (BasePart, BasePart)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	-- Rotate the labels so the longest edge is b -> c.
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b

	local right = ac:Cross(ab).Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))

	local w1 = anchoredPart("WedgePart", props)
	w1.Size = Vector3.new(thickness, height, math.abs(ab:Dot(back)))
	w1.CFrame = CFrame.fromMatrix((a + b) / 2, right, up, back)

	local w2 = anchoredPart("WedgePart", props)
	w2.Size = Vector3.new(thickness, height, math.abs(ac:Dot(back)))
	w2.CFrame = CFrame.fromMatrix((a + c) / 2, -right, up, -back)
	return w1, w2
end

-- Flat regular hexagon = a center block plus two end triangles (4 wedges).
-- An exact hexagon can't be made from 6 right-angle wedges; this is the
-- fewest-part equivalent.
local function buildHexDeck(topCFrame: CFrame, color: Color3, parent: Instance)
	local R = Config.PLATFORM_RADIUS
	local T = Config.PLATFORM_THICKNESS
	local a = HexGeometry.apothem(R)
	local mid = topCFrame * CFrame.new(0, -T / 2, 0)
	local props = {
		Color = color,
		Material = Enum.Material.DiamondPlate,
		Name = "Deck",
	}

	local block = anchoredPart("Part", props)
	block.Size = Vector3.new(R, T, 2 * a)
	block.CFrame = mid
	block.Parent = parent

	local corners = HexGeometry.corners(R)
	local function world(i: number): Vector3
		local v = corners[i + 1]
		return mid:PointToWorldSpace(Vector3.new(v.X, 0, v.Y))
	end
	for _, tri in { { 5, 0, 1 }, { 2, 3, 4 } } do
		local w1, w2 = triangleWedges(world(tri[1]), world(tri[2]), world(tri[3]), T, props)
		w1.Parent = parent
		w2.Parent = parent
	end
	return block
end

-- The ring is drawn in two clipped halves. Each half holds a full ring whose
-- UIGradient is opaque on one side of a line through the center. Rotating
-- that gradient sweeps the visible arc (see client RingMeterController).
local function ringElement(pixelSize: number, color: Color3, zIndex: number): (GuiObject, UIGradient)
	local gradient = Instance.new("UIGradient")
	gradient.Name = "Sweep"

	if Config.RING_IMAGE_ID ~= "" then
		local image = Instance.new("ImageLabel")
		image.BackgroundTransparency = 1
		image.Image = Config.RING_IMAGE_ID
		image.ImageColor3 = color
		image.ZIndex = zIndex
		gradient.Parent = image
		return image, gradient
	end

	local stroke = math.floor(pixelSize * Config.RING_THICKNESS)
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.ZIndex = zIndex
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
	local uiStroke = Instance.new("UIStroke")
	uiStroke.Thickness = stroke
	uiStroke.Color = color
	uiStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	uiStroke.Parent = frame
	gradient.Parent = uiStroke
	return frame, gradient
end

local function buildRingMeter(topCFrame: CFrame, parent: Instance)
	local a = HexGeometry.apothem(Config.PLATFORM_RADIUS)
	local side = 2 * a * 0.92

	local meterPart = anchoredPart("Part", {
		Name = "Meter",
		Size = Vector3.new(side, 0.1, side),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	meterPart.CFrame = topCFrame * CFrame.new(0, 0.06, 0)
	meterPart.Parent = parent

	local gui = Instance.new("SurfaceGui")
	gui.Name = "RingMeter"
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = Config.RING_PIXELS_PER_STUD
	gui.LightInfluence = 0
	gui.Brightness = 1.5
	gui.Parent = meterPart

	local pixelSize = side * Config.RING_PIXELS_PER_STUD
	local strokePx = if Config.RING_IMAGE_ID == "" then math.floor(pixelSize * Config.RING_THICKNESS) else 0

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = gui

	-- Dim full ring behind the fill.
	local track = ringElement(pixelSize, Color3.fromRGB(30, 30, 35), 1)
	track.Name = "Track"
	track.Size = UDim2.new(1, -2 * strokePx, 1, -2 * strokePx)
	track.Position = UDim2.fromOffset(strokePx, strokePx)
	track.Parent = root
	local trackGradient = track:FindFirstChild("Sweep", true)
	if trackGradient then
		trackGradient:Destroy()
	end

	local halves = {
		{ name = "Left", clipX = 0, ringX = 0 },
		{ name = "Right", clipX = 0.5, ringX = -1 },
	}
	for _, h in halves do
		local clip = Instance.new("Frame")
		clip.Name = h.name
		clip.BackgroundTransparency = 1
		clip.ClipsDescendants = true
		clip.Size = UDim2.fromScale(0.5, 1)
		clip.Position = UDim2.fromScale(h.clipX, 0)
		clip.Parent = root

		local fill, gradient = ringElement(pixelSize, Config.RING_COLOR_SAFE, 2)
		fill.Name = "Fill"
		fill.Size = UDim2.new(2, -2 * strokePx, 1, -2 * strokePx)
		fill.Position = UDim2.new(h.ringX, strokePx, 0, strokePx)
		fill.Parent = clip
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.4999, 0),
			NumberSequenceKeypoint.new(0.5, 1),
			NumberSequenceKeypoint.new(1, 1),
		})
		-- Full ring at spawn: Left = 360 degrees, Right = 180 degrees.
		gradient.Rotation = if h.name == "Left" then 360 else 180
	end

	local label = Instance.new("TextLabel")
	label.Name = "Value"
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(0.5, 0.18)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Text = `0 / {Config.PLATFORM_CAPACITY}`
	label.ZIndex = 3
	label.Parent = root

	local owner = label:Clone()
	owner.Name = "Owner"
	owner.Position = UDim2.fromScale(0.5, 0.66)
	owner.Size = UDim2.fromScale(0.45, 0.09)
	owner.Font = Enum.Font.GothamBold
	owner.Text = ""
	owner.Parent = root
end

local function buildPlatform(slot: number, parent: Instance): Platform
	local angle = math.rad(45 + 90 * (slot - 1))
	local center = Config.ARENA_CENTER + Vector3.new(math.cos(angle), 0, math.sin(angle)) * Config.ARENA_RADIUS
	local flatCenter = Vector3.new(Config.ARENA_CENTER.X, center.Y, Config.ARENA_CENTER.Z)
	-- -Z faces the pit, so one flat hex edge faces inward.
	local topCFrame = CFrame.lookAt(center, flatCenter)
	local color = Config.PLATFORM_COLORS[slot] or Color3.new(0.7, 0.7, 0.7)

	local model = Instance.new("Model")
	model.Name = `Platform{slot}`

	local block = buildHexDeck(topCFrame, color, model)
	model.PrimaryPart = block

	-- Piston rod the deck rides on, reaching down to the pit floor.
	local rodLength = Config.PIT_DEPTH - Config.PLATFORM_THICKNESS
	local rod = anchoredPart("Part", {
		Name = "PistonRod",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(rodLength, 6, 6),
		Color = Color3.fromRGB(70, 70, 78),
		Material = Enum.Material.Metal,
	})
	rod.CFrame = topCFrame * CFrame.new(0, -Config.PLATFORM_THICKNESS - rodLength / 2, 0) * CFrame.Angles(0, 0, math.rad(90))
	rod.Parent = model

	buildRingMeter(topCFrame, model)

	model:SetAttribute("Slot", slot)
	model:SetAttribute("Load", 0)
	model:SetAttribute("Capacity", Config.PLATFORM_CAPACITY)
	model:SetAttribute("OwnerName", "")
	model:SetAttribute("Eliminated", false)
	model.Parent = parent
	CollectionService:AddTag(model, PLATFORM_TAG)

	local restPivots = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			restPivots[d] = d.CFrame
		end
	end

	return {
		slot = slot,
		model = model,
		topCFrame = topCFrame,
		restPivots = restPivots,
		dropped = false,
	}
end

local function buildPit(parent: Instance)
	local c = Config.ARENA_CENTER
	local floor = anchoredPart("Part", {
		Name = "PitFloor",
		Size = Vector3.new(4 * Config.ARENA_RADIUS + 60, 2, 4 * Config.ARENA_RADIUS + 60),
		Color = Color3.fromRGB(25, 20, 20),
		Material = Enum.Material.CorrodedMetal,
	})
	floor.CFrame = CFrame.new(c.X, c.Y - Config.PIT_DEPTH - 1, c.Z)
	floor.Parent = parent

	local glow = anchoredPart("Part", {
		Name = "PitGlow",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, Config.ARENA_RADIUS * 1.2, Config.ARENA_RADIUS * 1.2),
		Color = Color3.fromRGB(255, 90, 30),
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanQuery = false,
	})
	glow.CFrame = CFrame.new(c.X, c.Y - Config.PIT_DEPTH + 0.1, c.Z) * CFrame.Angles(0, 0, math.rad(90))
	glow.Parent = parent

end

-- Raised overlook hub facing the pit: the only enabled SpawnLocation, well
-- outside the arena kill column, with a glass front rail and a status board.
local function buildHub(parent: Instance)
	local c = Config.ARENA_CENTER
	local top = c + Config.HUB_OFFSET
	-- -Z faces the arena, so "front" is the edge overlooking the pit.
	local hubCFrame = CFrame.lookAt(top, Vector3.new(c.X, top.Y, c.Z))
	local W, D, H = Config.HUB_SIZE.X, Config.HUB_SIZE.Z, Config.HUB_RAIL_HEIGHT

	local model = Instance.new("Model")
	model.Name = "SpawnHub"

	local floor = anchoredPart("Part", {
		Name = "HubFloor",
		Size = Config.HUB_SIZE,
		Color = Color3.fromRGB(58, 60, 68),
		Material = Enum.Material.Concrete,
	})
	floor.CFrame = hubCFrame * CFrame.new(0, -Config.HUB_SIZE.Y / 2, 0)
	floor.Parent = model

	local function rail(name: string, size: Vector3, offset: CFrame, glass: boolean)
		local part = anchoredPart("Part", {
			Name = name,
			Size = size,
			Color = if glass then Color3.fromRGB(170, 210, 255) else Color3.fromRGB(80, 82, 92),
			Material = if glass then Enum.Material.Glass else Enum.Material.Metal,
			Transparency = if glass then 0.7 else 0,
		})
		part.CFrame = hubCFrame * offset
		part.Parent = model
		return part
	end
	rail("FrontRail", Vector3.new(W, H, 0.5), CFrame.new(0, H / 2, -D / 2 + 0.25), true)
	rail("LeftRail", Vector3.new(0.5, H, D), CFrame.new(-W / 2 + 0.25, H / 2, 0), false)
	rail("RightRail", Vector3.new(0.5, H, D), CFrame.new(W / 2 - 0.25, H / 2, 0), false)

	-- Neon trim along the overlook edge.
	local trim = anchoredPart("Part", {
		Name = "EdgeTrim",
		Size = Vector3.new(W, 0.3, 0.6),
		Color = Color3.fromRGB(255, 120, 40),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	trim.CFrame = hubCFrame * CFrame.new(0, H + 0.15, -D / 2 + 0.25)
	trim.Parent = model

	-- Back wall doubles as a scoreboard, readable from the hub and the platforms.
	local boardHeight = 16
	local board = anchoredPart("Part", {
		Name = "StatusBoard",
		Size = Vector3.new(W, boardHeight, 1),
		Color = Color3.fromRGB(28, 28, 34),
		Material = Enum.Material.SmoothPlastic,
	})
	board.CFrame = hubCFrame * CFrame.new(0, boardHeight / 2, D / 2 - 0.5)
	board.Parent = model
	local boardGui = Instance.new("SurfaceGui")
	boardGui.Name = "Board"
	boardGui.Face = Enum.NormalId.Front
	boardGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	boardGui.PixelsPerStud = 20
	boardGui.LightInfluence = 0
	boardGui.Parent = board
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 0.45)
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 140, 50)
	title.Text = "DEBRIS CLEAR"
	title.Parent = boardGui
	local statusText = title:Clone()
	statusText.Name = "Status"
	statusText.Position = UDim2.fromScale(0.05, 0.5)
	statusText.Size = UDim2.fromScale(0.9, 0.35)
	statusText.Font = Enum.Font.GothamBold
	statusText.TextColor3 = Color3.new(1, 1, 1)
	statusText.Text = ""
	statusText.Parent = boardGui
	Arena.boardStatus = statusText

	-- Support pillars down to the ground, purely visual.
	for _, x in { -W / 3, W / 3 } do
		local pillarHeight = top.Y
		local pillar = anchoredPart("Part", {
			Name = "Pillar",
			Size = Vector3.new(4, pillarHeight, 4),
			Color = Color3.fromRGB(70, 70, 78),
			Material = Enum.Material.Metal,
		})
		pillar.CFrame = hubCFrame * CFrame.new(x, -Config.HUB_SIZE.Y - pillarHeight / 2, 0)
		pillar.Parent = model
	end

	-- Ours is the only enabled spawn, so nobody spawns inside the pit.
	for _, d in workspace:GetDescendants() do
		if d:IsA("SpawnLocation") then
			d.Enabled = false
		end
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.Color = Color3.fromRGB(255, 140, 50)
	spawn.Material = Enum.Material.SmoothPlastic
	-- Facing the arena, so players spawn looking out over the pit.
	spawn.CFrame = hubCFrame * CFrame.new(0, 0.5, D / 4)
	spawn.Parent = model

	model.Parent = parent
	Arena.hubSpawn = spawn
	Arena.hubFloorY = top.Y
end

function Arena.build()
	local folder = Instance.new("Folder")
	folder.Name = "DebrisClearArena"
	buildPit(folder)
	buildHub(folder)
	for slot = 1, Config.MAX_PLAYERS do
		table.insert(Arena.platforms, buildPlatform(slot, folder))
	end
	local debris = Instance.new("Folder")
	debris.Name = "Debris"
	debris.Parent = folder
	folder.Parent = workspace
	Arena.folder = folder
end

function Arena.debrisFolder(): Folder
	return (Arena.folder :: Folder):FindFirstChild("Debris") :: Folder
end

function Arena.killY(): number
	return Config.ARENA_CENTER.Y - Config.KILL_DEPTH
end

-- Is this position horizontally inside the pit area, where the kill line applies?
function Arena.inArenaColumn(position: Vector3): boolean
	local c = Config.ARENA_CENTER
	local dx, dz = position.X - c.X, position.Z - c.Z
	return dx * dx + dz * dz <= Config.ARENA_KILL_RADIUS * Config.ARENA_KILL_RADIUS
end

-- Where to put someone who wandered off the hub.
function Arena.hubReturnCFrame(): CFrame
	local spawn = Arena.hubSpawn :: SpawnLocation
	return spawn.CFrame * CFrame.new(0, 3.5, 0)
end

function Arena.setBoardStatus(text: string)
	local label = Arena.boardStatus
	if label then
		label.Text = text
	end
end

-- Standing spot for a player on a platform (slightly above the deck).
function Arena.standCFrame(platform: Platform): CFrame
	return platform.topCFrame * CFrame.new(0, 3.5, 0)
end

function Arena.isOver(platform: Platform, worldPos: Vector3): (boolean, number)
	return HexGeometry.containsWorld(platform.topCFrame, Config.PLATFORM_RADIUS, worldPos)
end

local function tweenModel(platform: Platform, offset: Vector3, info: TweenInfo)
	local last: Tween? = nil
	for part, rest in platform.restPivots do
		local tween = TweenService:Create(part, info, { CFrame = rest + offset })
		tween:Play()
		last = tween
	end
	if last then
		last.Completed:Wait()
	end
end

-- Piston drop (~0.3s by default). Yields until the drop finishes.
function Arena.dropPlatform(platform: Platform)
	if platform.dropped then
		return
	end
	platform.dropped = true
	local info = TweenInfo.new(Config.PISTON_DROP_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	tweenModel(platform, Vector3.new(0, -Config.PISTON_DROP_DISTANCE, 0), info)
end

function Arena.resetPlatform(platform: Platform)
	platform.model:SetAttribute("Load", 0)
	platform.model:SetAttribute("OwnerName", "")
	platform.model:SetAttribute("Eliminated", false)
	if platform.dropped then
		platform.dropped = false
		local info = TweenInfo.new(Config.PISTON_RESET_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
		tweenModel(platform, Vector3.zero, info)
	end
end

return Arena

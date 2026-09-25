--!strict
-- Shared helpers for the map modules (Pit, Towers, Hub, Showcase, ...).
-- Everything here makes anchored primitive parts; no asset ids anywhere.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("DebrisClear")
local Config = require(Shared.Config)
local DecahedronMesh = require(Shared.DecahedronMesh)
local HexGeometry = require(Shared.HexGeometry)

local MapKit = {}

-- Teleport pads carry this tag and a "Destination" attribute ("Hub" | "Showcase").
MapKit.TELEPORT_TAG = "DebrisClearTeleport"
-- Parts with this tag and attribute Visual = "Client" get a locally rendered d10.
MapKit.DEBRIS_TAG = "DebrisClearDebris"

export type Props = { [string]: any }

local function apply(instance: Instance, props: Props?)
	if props then
		for k, v in props do
			(instance :: any)[k] = v
		end
	end
end

-- Anchored, smooth-surfaced Part. Shape/Size/CFrame/Color/etc. come from props.
function MapKit.part(props: Props?): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CastShadow = true
	apply(part, props)
	return part
end

function MapKit.wedge(props: Props?): WedgePart
	local part = Instance.new("WedgePart")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	apply(part, props)
	return part
end

function MapKit.cornerWedge(props: Props?): CornerWedgePart
	local part = Instance.new("CornerWedgePart")
	part.Anchored = true
	apply(part, props)
	return part
end

function MapKit.truss(props: Props?): TrussPart
	local part = Instance.new("TrussPart")
	part.Anchored = true
	apply(part, props)
	return part
end

-- Block with its CENTER at `cf`.
function MapKit.block(cf: CFrame, size: Vector3, props: Props?): Part
	local part = MapKit.part(props)
	part.Size = size
	part.CFrame = cf
	return part
end

-- Cylinder whose axis runs along the local Y of `cf`, centered on `cf`.
-- (Roblox cylinders run along their X axis; this hides that.)
function MapKit.cylinder(cf: CFrame, length: number, radius: number, props: Props?): Part
	local part = MapKit.part(props)
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(length, radius * 2, radius * 2)
	part.CFrame = cf * CFrame.Angles(0, 0, math.rad(90))
	return part
end

-- Flat disc lying in the XZ plane of `cf` (top face points along local +Y).
function MapKit.disc(cf: CFrame, radius: number, thickness: number, props: Props?): Part
	return MapKit.cylinder(cf, thickness, radius, props)
end

-- Cylinder standing on `base` (world position), growing straight up.
function MapKit.column(base: Vector3, height: number, radius: number, props: Props?): Part
	return MapKit.cylinder(CFrame.new(base + Vector3.new(0, height / 2, 0)), height, radius, props)
end

function MapKit.ball(position: Vector3, diameter: number, props: Props?): Part
	local part = MapKit.part(props)
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.one * diameter
	part.CFrame = CFrame.new(position)
	return part
end

-- Calls fn(i, cf) for `count` evenly spaced points on a horizontal circle.
-- Each cf sits on the circle, at `center`'s height, with -Z facing the center.
function MapKit.ring(center: Vector3, radius: number, count: number, startAngle: number, fn: (i: number, cf: CFrame) -> ())
	for i = 1, count do
		local a = startAngle + (i - 1) * (2 * math.pi / count)
		local p = center + Vector3.new(math.cos(a), 0, math.sin(a)) * radius
		fn(i, CFrame.lookAt(p, Vector3.new(center.X, p.Y, center.Z)))
	end
end

-- Straight beam of parts between two world points (for girders, rails, cables).
function MapKit.beam(a: Vector3, b: Vector3, thickness: number, props: Props?): Part
	local length = (b - a).Magnitude
	local part = MapKit.part(props)
	part.Size = Vector3.new(thickness, thickness, length)
	part.CFrame = CFrame.lookAt((a + b) / 2, b)
	return part
end

function MapKit.model(name: string, parent: Instance?): Model
	local model = Instance.new("Model")
	model.Name = name
	if parent then
		model.Parent = parent
	end
	return model
end

-- Text on one face of a part. Returns the gui and label for later edits.
function MapKit.surfaceText(part: BasePart, face: Enum.NormalId, text: string, props: Props?): (SurfaceGui, TextLabel)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Text"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.LightInfluence = 0
	gui.Brightness = 1.2
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(0.9, 0.8)
	label.Position = UDim2.fromScale(0.05, 0.1)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.6
	label.Text = text
	apply(label, props)
	label.Parent = gui
	return gui, label
end

function MapKit.pointLight(part: BasePart, color: Color3, brightness: number, range: number): PointLight
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Shadows = false
	light.Parent = part
	return light
end

function MapKit.emitter(part: BasePart, props: Props?): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	apply(emitter, props)
	emitter.Parent = part
	return emitter
end

-- Glowing floor pad that teleports whoever steps on it (handled in Main).
-- `destination` is "Hub" or "Showcase".
function MapKit.teleportPad(parent: Instance, cf: CFrame, label: string, destination: string, color: Color3): Part
	local pad = MapKit.part({
		Name = `TeleportPad_{destination}`,
		Size = Vector3.new(8, 0.6, 8),
		Color = color,
		Material = Enum.Material.Neon,
		CanQuery = false,
	})
	pad.CFrame = cf
	pad:SetAttribute("Destination", destination)
	CollectionService:AddTag(pad, MapKit.TELEPORT_TAG)

	local base = MapKit.part({
		Name = "PadBase",
		Size = Vector3.new(9.5, 0.4, 9.5),
		Color = Config.MAP.PAD_BASE,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		CanQuery = false,
	})
	base.CFrame = cf * CFrame.new(0, -0.45, 0)
	base.Parent = pad

	local _, text = MapKit.surfaceText(pad, Enum.NormalId.Top, label)
	text.TextColor3 = Color3.new(0.1, 0.1, 0.12)
	text.TextStrokeTransparency = 1

	local light = MapKit.pointLight(pad, color, 2, 14)
	light.Parent = pad
	pad.Parent = parent
	return pad
end

-- A display d10 for the showcase (no physics). With an imported mesh it is a
-- real MeshPart; otherwise clients render the EditableMesh d10 over an
-- invisible anchor, exactly like live debris.
function MapKit.showcaseDebris(parent: Instance, cf: CFrame, scale: number?): BasePart
	local size = Config.DEBRIS_SIZE * (scale or 1)
	local part: BasePart? = nil
	if Config.DEBRIS_MESH_ID ~= "" then
		part = DecahedronMesh.createFromAsset(Config.DEBRIS_MESH_ID, size)
	end
	if part then
		part.Color = Config.DEBRIS_COLOR
		part.Material = Config.DEBRIS_MATERIAL
	else
		local anchor = MapKit.part({ Transparency = 1, Size = Vector3.one * size })
		anchor:SetAttribute("Visual", "Client")
		anchor:SetAttribute("VisualScale", scale or 1) -- DebrisVisuals scales its d10 by this
		CollectionService:AddTag(anchor, MapKit.DEBRIS_TAG)
		part = anchor
	end
	local p = part :: BasePart
	p.Name = "ShowcaseDebris"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CFrame = cf
	p.Parent = parent
	return p
end

-- Slowly spins an anchored part in place around world Y (display pieces).
function MapKit.spin(part: BasePart, degreesPerSecond: number)
	local origin = part.CFrame
	local angle = 0
	RunService.Heartbeat:Connect(function(dt)
		if not part.Parent then
			return
		end
		angle += math.rad(degreesPerSecond) * dt
		part.CFrame = CFrame.new(origin.Position) * CFrame.Angles(0, angle, 0) * origin.Rotation
	end)
end

-- Gentle up/down bob for display pieces.
function MapKit.bob(part: BasePart, amplitude: number, period: number)
	local origin = part.CFrame
	local t = 0
	RunService.Heartbeat:Connect(function(dt)
		if not part.Parent then
			return
		end
		t += dt
		part.CFrame = origin + Vector3.new(0, math.sin(t * 2 * math.pi / period) * amplitude, 0)
	end)
end

-- Spin and bob in one Heartbeat (spin() and bob() each overwrite CFrame, so
-- they can't be combined).
function MapKit.spinBob(part: BasePart, degreesPerSecond: number, amplitude: number, period: number)
	local origin = part.CFrame
	local angle, t = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		if not part.Parent then
			return
		end
		angle += math.rad(degreesPerSecond) * dt
		t += dt
		local lift = math.sin(t * 2 * math.pi / period) * amplitude
		part.CFrame = CFrame.new(origin.Position + Vector3.new(0, lift, 0)) * CFrame.Angles(0, angle, 0) * origin.Rotation
	end)
end

-- Endless transparency pulse (tally lights, beacons). Runs from the part's
-- current Transparency up to maxT and back every `period` seconds.
function MapKit.blink(part: BasePart, period: number, maxT: number): Tween
	local info = TweenInfo.new(period / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	local tween = TweenService:Create(part, info, { Transparency = maxT })
	tween:Play()
	return tween
end

-- SpotLight out of one face of a part. Shadows are always off (cost).
function MapKit.spotLight(part: BasePart, face: Enum.NormalId, color: Color3, angle: number, brightness: number, range: number): SpotLight
	local light = Instance.new("SpotLight")
	light.Face = face
	light.Color = color
	light.Angle = angle
	light.Brightness = brightness
	light.Range = range
	light.Shadows = false
	light.Parent = part
	return light
end

-- Vertical searchlight beam rising `height` studs from the part's center.
-- Call after the part is parented (Attachment1 uses a world position).
function MapKit.beamUp(part: BasePart, height: number, width0: number, width1: number, color: Color3): Beam
	local a0 = Instance.new("Attachment")
	a0.Name = "BeamBase"
	a0.Parent = part
	local a1 = Instance.new("Attachment")
	a1.Name = "BeamTop"
	a1.Parent = part
	a1.WorldPosition = part.Position + Vector3.new(0, height, 0)

	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Color = ColorSequence.new(color)
	beam.Width0 = width0
	beam.Width1 = width1
	beam.Transparency = NumberSequence.new(0.6, 1)
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Brightness = 2
	beam.FaceCamera = true
	beam.Segments = 1
	beam.Parent = part
	return beam
end

---------------------------------------------------------------------------
-- Hex platform pieces (shared by Arena and the showcase exhibit)
---------------------------------------------------------------------------

-- Two right-angle WedgeParts that fill triangle (a, b, c), `thickness` thick,
-- centered on the triangle's plane.
local function triangleWedges(a: Vector3, b: Vector3, c: Vector3, thickness: number, props: Props): (BasePart, BasePart)
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

	local w1 = MapKit.wedge(props)
	w1.Size = Vector3.new(thickness, height, math.abs(ab:Dot(back)))
	w1.CFrame = CFrame.fromMatrix((a + b) / 2, right, up, back)

	local w2 = MapKit.wedge(props)
	w2.Size = Vector3.new(thickness, height, math.abs(ac:Dot(back)))
	w2.CFrame = CFrame.fromMatrix((a + c) / 2, -right, up, -back)
	return w1, w2
end

-- Flat regular hexagon (circumradius `radius`, corners on local +-X of
-- `topCFrame`, whose position is the center of the TOP surface) = a center
-- block plus two end triangles (4 wedges). Parts are parented to `parent`.
-- Returns the center block and every part.
function MapKit.hexDeck(topCFrame: CFrame, radius: number, thickness: number, parent: Instance, props: Props): (Part, { BasePart })
	local a = HexGeometry.apothem(radius)
	local mid = topCFrame * CFrame.new(0, -thickness / 2, 0)

	local block = MapKit.part(props)
	block.Size = Vector3.new(radius, thickness, 2 * a)
	block.CFrame = mid
	block.Parent = parent
	local parts: { BasePart } = { block }

	local corners = HexGeometry.corners(radius)
	local function world(i: number): Vector3
		local v = corners[i + 1]
		return mid:PointToWorldSpace(Vector3.new(v.X, 0, v.Y))
	end
	for _, tri in { { 5, 0, 1 }, { 2, 3, 4 } } do
		local w1, w2 = triangleWedges(world(tri[1]), world(tri[2]), world(tri[3]), thickness, props)
		w1.Parent = parent
		w2.Parent = parent
		table.insert(parts, w1)
		table.insert(parts, w2)
	end
	return block, parts
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

-- Ring meter SurfaceGui on an invisible "Meter" part just above the deck.
-- The GUI tree (Meter > RingMeter > Root > Left/Right > Fill + Sweep, Value,
-- Owner) is what RingMeterController binds to; keep it intact.
function MapKit.ringMeter(topCFrame: CFrame, radius: number, parent: Instance): Part
	local a = HexGeometry.apothem(radius)
	local side = 2 * a * 0.92

	local meterPart = MapKit.part({
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
	local track = ringElement(pixelSize, Color3.fromRGB(20, 22, 34), 1)
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
	return meterPart
end

return MapKit

--!strict
-- Shared helpers for the map modules (Pit, Towers, Hub, Showcase, ...).
-- Everything here makes anchored primitive parts; no asset ids anywhere.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("DebrisClear")
local Config = require(Shared.Config)
local DecahedronMesh = require(Shared.DecahedronMesh)

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
		Color = Color3.fromRGB(35, 35, 42),
		Material = Enum.Material.Metal,
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

return MapKit

--!strict
-- Visual dressing for one hex platform (brief section 3). The deck Arena
-- built becomes a near-black glossy podium; the slot identity lives in a neon
-- rim at the side midpoints, a neon ring around a steel collar under the deck,
-- and a neon under-disc whose light paints the rod, collar, sleeve and pit.
-- Every new part is parented to the platform model before Arena collects
-- restPivots, so it rides the piston drop. Nothing here rises above the deck
-- top (Arena adds the Meter part there afterwards).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("DebrisClear")
local Config = require(Shared.Config)
local HexGeometry = require(Shared.HexGeometry)
local MapKit = require(script.Parent.MapKit)

local PlatformDressing = {}

-- Offsets are in the platform frame (topCFrame): Y 0 is the deck top and the
-- deck fills Y -PLATFORM_THICKNESS..0 (world 58..60).
local TUNING = {
	-- Six strips, one per hex side: X runs along the side (side = circumradius),
	-- Z is the depth, half of which stands proud of the deck face.
	RIM_SIZE = Vector3.new(Config.PLATFORM_RADIUS, 0.6, 0.3), -- PLACEHOLDER
	-- Steel collar hugging the rod, its top flush with the deck bottom.
	COLLAR_RADIUS = 5, -- PLACEHOLDER
	COLLAR_HEIGHT = 3, -- PLACEHOLDER: world Y 55..58
	COLLAR_RING_RADIUS = 5.4, -- PLACEHOLDER: neon ring at the collar's mid-height
	COLLAR_RING_THICKNESS = 0.5, -- PLACEHOLDER
	-- Under-disc: inside the hex footprint (apothem 10.39), just below the deck.
	UNDER_DISC_RADIUS = 9.5, -- PLACEHOLDER
	UNDER_DISC_THICKNESS = 0.3, -- PLACEHOLDER
	UNDER_DISC_GAP = 0.2, -- PLACEHOLDER: air between the deck bottom and the disc top (z-fight guard)
	UNDER_LIGHT = { brightness = 2, range = 30 }, -- PLACEHOLDER: slot-colored glow on rod, collar, sleeve and pit
}

-- Neon trim nothing may rest on: never collidable, queried or touched.
local function neon(name: string, color: Color3): MapKit.Props
	return {
		Name = name,
		Material = Enum.Material.Neon,
		Color = color,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	}
end

function PlatformDressing.dress(model: Model, topCFrame: CFrame, color: Color3, slot: number)
	local thickness = Config.PLATFORM_THICKNESS

	-- Restyle what Arena already built: glossy near-black deck, steel rod.
	local tint = Config.PLATFORM_DECK_TINTS[slot] or Config.MAP.VOID_BLACK
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and child.Name == "Deck" then
			child.Material = Enum.Material.SmoothPlastic
			child.Color = tint
		end
	end
	local rod = model:FindFirstChild("PistonRod")
	if rod and rod:IsA("BasePart") then
		rod.Material = Enum.Material.Metal
		rod.Color = Config.MAP.ROD_STEEL
	end

	-- Rim: a strip centered on each side midpoint at deck mid-height, looking
	-- at the deck center so Size.X runs along the side. Corners sit on local
	-- +-X, so the side midpoints are at 30 + 60k degrees, apothem out.
	local apothem = HexGeometry.apothem(Config.PLATFORM_RADIUS)
	local rimY = -thickness / 2
	local rimCenter = (topCFrame * CFrame.new(0, rimY, 0)).Position
	for k = 0, 5 do
		local t = math.rad(30 + 60 * k)
		local mid = (topCFrame * CFrame.new(apothem * math.cos(t), rimY, apothem * math.sin(t))).Position
		local strip = MapKit.block(CFrame.lookAt(mid, rimCenter), TUNING.RIM_SIZE, neon("RimStrip", color))
		strip.Parent = model
	end

	-- Collar under the deck with the slot-colored ring around its waist.
	local collarCF = topCFrame * CFrame.new(0, -thickness - TUNING.COLLAR_HEIGHT / 2, 0)
	local collar = MapKit.cylinder(collarCF, TUNING.COLLAR_HEIGHT, TUNING.COLLAR_RADIUS, {
		Name = "Collar",
		Material = Enum.Material.Metal,
		Color = Config.MAP.COLLAR_IRON,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	collar.Parent = model
	local collarRing = MapKit.disc(collarCF, TUNING.COLLAR_RING_RADIUS, TUNING.COLLAR_RING_THICKNESS, neon("CollarRing", color))
	collarRing.Parent = model

	-- Under-disc just below the deck bottom. On a drop it bottoms out 0.1 above
	-- the Pit's sleeve top, so the crushed deck visibly lands on something.
	local discY = -thickness - TUNING.UNDER_DISC_GAP - TUNING.UNDER_DISC_THICKNESS / 2
	local underDisc = MapKit.disc(
		topCFrame * CFrame.new(0, discY, 0),
		TUNING.UNDER_DISC_RADIUS,
		TUNING.UNDER_DISC_THICKNESS,
		neon("UnderDisc", color)
	)
	underDisc.Parent = model
	MapKit.pointLight(underDisc, color, TUNING.UNDER_LIGHT.brightness, TUNING.UNDER_LIGHT.range)
end

return PlatformDressing

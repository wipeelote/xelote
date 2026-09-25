--!strict
-- Builds the arena: 4 hexagonal platforms on piston rods around a central pit,
-- with a ring-meter SurfaceGui on each deck. The surroundings (pit, towers,
-- spawn hub, showcase, lighting) are built by the modules in Map/.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("DebrisClear")
local Config = require(Shared.Config)
local HexGeometry = require(Shared.HexGeometry)
local Map = script.Parent.Map
local MapKit = require(Map.MapKit)
local Pit = require(Map.Pit)
local Towers = require(Map.Towers)
local Hub = require(Map.Hub)
local Showcase = require(Map.Showcase)
local MapLighting = require(Map.Lighting)
local PlatformDressing = require(Map.PlatformDressing)

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
Arena.showcaseSpawnCFrame = nil :: CFrame?

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

local function buildPlatform(slot: number, parent: Instance): Platform
	local angle = math.rad(45 + 90 * (slot - 1))
	local center = Config.ARENA_CENTER + Vector3.new(math.cos(angle), 0, math.sin(angle)) * Config.ARENA_RADIUS
	local flatCenter = Vector3.new(Config.ARENA_CENTER.X, center.Y, Config.ARENA_CENTER.Z)
	-- -Z faces the pit, so one flat hex edge faces inward.
	local topCFrame = CFrame.lookAt(center, flatCenter)
	local color = Config.PLATFORM_COLORS[slot] or Color3.new(0.7, 0.7, 0.7)

	local model = Instance.new("Model")
	model.Name = `Platform{slot}`

	local block = MapKit.hexDeck(topCFrame, Config.PLATFORM_RADIUS, Config.PLATFORM_THICKNESS, model, {
		Name = "Deck",
		Color = color,
		Material = Enum.Material.DiamondPlate,
	})
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

	-- Visual dressing (rim, lights, slot number). Added before restPivots is
	-- collected so it rides the piston drop with the deck.
	PlatformDressing.dress(model, topCFrame, color, slot)

	MapKit.ringMeter(topCFrame, Config.PLATFORM_RADIUS, model)

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

function Arena.build()
	local folder = Instance.new("Folder")
	folder.Name = "DebrisClearArena"

	-- Ours is the only enabled spawn, so nobody spawns inside the pit.
	for _, d in workspace:GetDescendants() do
		if d:IsA("SpawnLocation") then
			d.Enabled = false
		end
	end

	MapLighting.apply()
	Pit.build(folder)
	Towers.build(folder)

	local hub = Hub.build(folder)
	Arena.hubSpawn = hub.spawn
	Arena.boardStatus = hub.statusLabel
	Arena.hubFloorY = hub.floorY

	local showcase = Showcase.build(folder)
	Arena.showcaseSpawnCFrame = showcase.spawnCFrame

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

-- Teleport pad destinations, by the pad's "Destination" attribute.
function Arena.destinationCFrame(name: string): CFrame?
	if name == "Hub" then
		return Arena.hubReturnCFrame()
	elseif name == "Showcase" then
		return Arena.showcaseSpawnCFrame
	end
	return nil
end

-- Closest safe spot (hub or showcase) to put a fallen spectator back on.
function Arena.nearestSafeCFrame(position: Vector3): CFrame
	local best = Arena.hubReturnCFrame()
	local showcase = Arena.showcaseSpawnCFrame
	if showcase then
		local function flatDistance(cf: CFrame): number
			return (Vector3.new(cf.X, 0, cf.Z) - Vector3.new(position.X, 0, position.Z)).Magnitude
		end
		if flatDistance(showcase) < flatDistance(best) then
			best = showcase
		end
	end
	return best
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

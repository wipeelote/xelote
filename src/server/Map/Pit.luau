--!strict
-- The central pit: what players see below the platforms. Interim version.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("DebrisClear")
local Config = require(Shared.Config)
local MapKit = require(script.Parent.MapKit)

local Pit = {}

function Pit.build(parent: Instance)
	local c = Config.ARENA_CENTER
	local model = MapKit.model("Pit", parent)
	local floor = MapKit.block(
		CFrame.new(c.X, c.Y - Config.PIT_DEPTH - 1, c.Z),
		Vector3.new(4 * Config.ARENA_RADIUS + 60, 2, 4 * Config.ARENA_RADIUS + 60),
		{ Name = "PitFloor", Color = Color3.fromRGB(25, 20, 20), Material = Enum.Material.CorrodedMetal }
	)
	floor.Parent = model
	local glow = MapKit.disc(CFrame.new(c.X, c.Y - Config.PIT_DEPTH + 0.1, c.Z), Config.ARENA_RADIUS * 0.6, 0.2, {
		Name = "PitGlow",
		Color = Color3.fromRGB(255, 90, 30),
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanQuery = false,
	})
	glow.Parent = model
end

return Pit

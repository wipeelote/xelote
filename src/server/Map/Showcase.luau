--!strict
-- Showcase gallery of the game's models, reached by teleport pad. Interim version.
-- Contract: returns where teleported players stand. Must include a return pad.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("DebrisClear")
local Config = require(Shared.Config)
local MapKit = require(script.Parent.MapKit)

local Showcase = {}

export type Result = {
	spawnCFrame: CFrame,
}

function Showcase.build(parent: Instance): Result
	local origin = Config.ARENA_CENTER + Config.SHOWCASE_OFFSET
	local model = MapKit.model("Showcase", parent)
	MapKit.block(CFrame.new(origin - Vector3.new(0, 1, 0)), Vector3.new(60, 2, 60), {
		Name = "ShowcaseFloor",
		Color = Color3.fromRGB(40, 40, 48),
		Material = Enum.Material.SmoothPlastic,
	}).Parent = model
	MapKit.teleportPad(model, CFrame.new(origin + Vector3.new(0, 0.3, 22)), "BACK TO HUB", "Hub", Color3.fromRGB(255, 140, 50))
	local piece = MapKit.showcaseDebris(model, CFrame.new(origin + Vector3.new(0, 4, 0)), 3)
	MapKit.spin(piece, 30)
	return { spawnCFrame = CFrame.new(origin + Vector3.new(0, 3.5, 10)) }
end

return Showcase

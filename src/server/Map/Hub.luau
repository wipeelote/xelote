--!strict
-- Raised spawn hub overlooking the pit. Interim version (ported from Arena).
-- Contract: returns the SpawnLocation, the status TextLabel (or nil) and the
-- hub floor's top Y. Must include a teleport pad to the showcase.

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

function Hub.build(parent: Instance): Result
	local c = Config.ARENA_CENTER
	local top = c + Config.HUB_OFFSET
	-- -Z faces the arena, so "front" is the edge overlooking the pit.
	local hubCFrame = CFrame.lookAt(top, Vector3.new(c.X, top.Y, c.Z))
	local W, D, H = Config.HUB_SIZE.X, Config.HUB_SIZE.Z, Config.HUB_RAIL_HEIGHT

	local model = MapKit.model("SpawnHub")

	MapKit.block(hubCFrame * CFrame.new(0, -Config.HUB_SIZE.Y / 2, 0), Config.HUB_SIZE, {
		Name = "HubFloor",
		Color = Color3.fromRGB(58, 60, 68),
		Material = Enum.Material.Concrete,
	}).Parent = model

	MapKit.block(hubCFrame * CFrame.new(0, H / 2, -D / 2 + 0.25), Vector3.new(W, H, 0.5), {
		Name = "FrontRail",
		Color = Color3.fromRGB(170, 210, 255),
		Material = Enum.Material.Glass,
		Transparency = 0.7,
	}).Parent = model
	for _, x in { -W / 2 + 0.25, W / 2 - 0.25 } do
		MapKit.block(hubCFrame * CFrame.new(x, H / 2, 0), Vector3.new(0.5, H, D), {
			Name = "SideRail",
			Color = Color3.fromRGB(80, 82, 92),
			Material = Enum.Material.Metal,
		}).Parent = model
	end

	local boardHeight = 16
	local board = MapKit.block(hubCFrame * CFrame.new(0, boardHeight / 2, D / 2 - 0.5), Vector3.new(W, boardHeight, 1), {
		Name = "StatusBoard",
		Color = Color3.fromRGB(28, 28, 34),
		Material = Enum.Material.SmoothPlastic,
	})
	board.Parent = model
	local _, title = MapKit.surfaceText(board, Enum.NormalId.Front, "DEBRIS CLEAR", {
		Size = UDim2.fromScale(1, 0.45),
		Position = UDim2.fromScale(0, 0),
		TextColor3 = Color3.fromRGB(255, 140, 50),
	})
	local statusLabel = title:Clone()
	statusLabel.Name = "Status"
	statusLabel.Position = UDim2.fromScale(0.05, 0.5)
	statusLabel.Size = UDim2.fromScale(0.9, 0.35)
	statusLabel.Font = Enum.Font.GothamBold
	statusLabel.TextColor3 = Color3.new(1, 1, 1)
	statusLabel.Text = ""
	statusLabel.Parent = title.Parent

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.Color = Color3.fromRGB(255, 140, 50)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.CFrame = hubCFrame * CFrame.new(0, 0.5, D / 4)
	spawn.Parent = model

	MapKit.teleportPad(model, hubCFrame * CFrame.new(W / 2 - 8, 0.3, D / 4), "SHOWCASE", "Showcase", Color3.fromRGB(90, 200, 255))

	model.Parent = parent
	return { spawn = spawn, statusLabel = statusLabel, floorY = top.Y }
end

return Hub

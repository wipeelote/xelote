--!strict
-- EditableMesh geometry doesn't replicate, so when the server marks debris
-- Visual = "Client" its physics part is invisible and each client renders a
-- local d10 that follows it.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("DebrisClear")
local Config = require(Shared.Config)
local DecahedronMesh = require(Shared.DecahedronMesh)

local DEBRIS_TAG = "DebrisClearDebris"

local DebrisVisuals = {}

local template: BasePart? = nil
local tracked: { [BasePart]: BasePart } = {}
local folder: Folder

local function getTemplate(): BasePart
	if template then
		return template
	end
	local part: BasePart? = DecahedronMesh.createMeshPart(Config.DEBRIS_SIZE)
	if not part then
		local ball = Instance.new("Part")
		ball.Shape = Enum.PartType.Ball
		ball.Size = Vector3.one * Config.DEBRIS_SIZE
		part = ball
	end
	local p = part :: BasePart
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = true
	p.Color = Config.DEBRIS_COLOR
	p.Material = Config.DEBRIS_MATERIAL
	template = p
	return p
end

local function track(instance: Instance)
	if not instance:IsA("BasePart") or instance:GetAttribute("Visual") ~= "Client" then
		return
	end
	local debris = instance :: BasePart
	if tracked[debris] then
		return
	end
	local visual = getTemplate():Clone()
	visual.CFrame = debris.CFrame
	visual.Parent = folder
	tracked[debris] = visual
end

local function untrack(instance: Instance)
	local debris = instance :: BasePart
	local visual = tracked[debris]
	if visual then
		visual:Destroy()
		tracked[debris] = nil
	end
end

-- The locally rendered d10 for a server debris part, if it has one.
function DebrisVisuals.visualFor(debris: BasePart): BasePart?
	return tracked[debris]
end

function DebrisVisuals.start()
	folder = Instance.new("Folder")
	folder.Name = "DebrisClearLocalVisuals"
	folder.Parent = workspace
	getTemplate() -- build once up front; CreateMeshPartAsync yields

	CollectionService:GetInstanceAddedSignal(DEBRIS_TAG):Connect(track)
	CollectionService:GetInstanceRemovedSignal(DEBRIS_TAG):Connect(untrack)
	for _, instance in CollectionService:GetTagged(DEBRIS_TAG) do
		track(instance)
	end

	RunService.RenderStepped:Connect(function()
		for debris, visual in tracked do
			if debris.Parent then
				visual.CFrame = debris.CFrame
			else
				untrack(debris)
			end
		end
	end)
end

return DebrisVisuals

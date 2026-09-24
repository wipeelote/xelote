--!strict
-- Client side of throwing. While holding debris, click / R2 / the touch
-- button sends only an aim point (camera raycast) to the server. Also applies
-- server-issued knockback to our own character, since we own its physics.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("DebrisClear")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local ACTION = "DebrisClearThrow"

local ThrowController = {}

local player = Players.LocalPlayer
local throwRemote: RemoteEvent
local stunToken = 0

local function aimPoint(input: InputObject?): Vector3
	local camera = workspace.CurrentCamera
	local viewport = camera.ViewportSize
	local screen = Vector2.new(viewport.X / 2, viewport.Y / 2)
	if input and input.UserInputType == Enum.UserInputType.MouseButton1 then
		screen = UserInputService:GetMouseLocation()
	end
	local ray = camera:ViewportPointToRay(screen.X, screen.Y)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = {}
	if player.Character then
		table.insert(ignore, player.Character)
	end
	local visuals = workspace:FindFirstChild("DebrisClearLocalVisuals")
	if visuals then
		table.insert(ignore, visuals)
	end
	params.FilterDescendantsInstances = ignore

	local result = workspace:Raycast(ray.Origin, ray.Direction * Config.THROW_MAX_AIM_DISTANCE, params)
	return if result then result.Position else ray.Origin + ray.Direction * Config.THROW_MAX_AIM_DISTANCE
end

local function onAction(_: string, state: Enum.UserInputState, input: InputObject): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		throwRemote:FireServer(aimPoint(input))
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end

local function onHoldingChanged()
	if player:GetAttribute("HoldingDebris") then
		ContextActionService:BindAction(ACTION, onAction, true, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
		ContextActionService:SetTitle(ACTION, "Throw")
		ContextActionService:SetPosition(ACTION, UDim2.new(1, -170, 1, -170))
	else
		ContextActionService:UnbindAction(ACTION)
	end
end

local function onKnockback(velocity: unknown, stun: unknown)
	if typeof(velocity) ~= "Vector3" or typeof(stun) ~= "number" then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end
	-- PlatformStand stops the Humanoid from immediately cancelling the push.
	stunToken += 1
	local token = stunToken
	humanoid.PlatformStand = true
	root.AssemblyLinearVelocity = velocity :: Vector3
	task.delay(stun :: number, function()
		if token == stunToken and humanoid.Parent then
			humanoid.PlatformStand = false
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
end

function ThrowController.start()
	throwRemote = Remotes.get("ThrowDebris")
	Remotes.get("Knockback").OnClientEvent:Connect(onKnockback)
	player:GetAttributeChangedSignal("HoldingDebris"):Connect(onHoldingChanged)
	onHoldingChanged()
end

return ThrowController

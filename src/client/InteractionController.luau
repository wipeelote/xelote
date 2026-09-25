--!strict
-- Pickup + throw on every input type, with one contextual action button.
--
--   Grab:  E (keyboard) | X (gamepad) | tap/click the action button
--          Uses the debris ProximityPrompts (Style = Custom): the engine picks
--          the closest prompt in range and handles E/X itself; the button
--          drives the same prompt via InputHoldBegin/End.
--   Throw: left click (aims at cursor) | R2 (aims at screen center)
--          | tap/click the action button (aims at screen center)
--
-- While holding, a dotted arc previews the exact server trajectory (shared
-- Ballistics module). Green = reachable, orange = out of range.
-- Also applies server-issued knockback to our own character.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("DebrisClear")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Ballistics = require(Shared.Ballistics)
local DebrisVisuals = require(script.Parent.DebrisVisuals)

type InputMode = "Mouse" | "Touch" | "Gamepad"

local InteractionController = {}

local player = Players.LocalPlayer
local throwRemote: RemoteEvent

local holding = false
local targetPrompt: ProximityPrompt? = nil
local inputMode: InputMode = "Mouse"
local lastThrowRequest = 0
local stunToken = 0

-- UI / world objects created in start()
local actionButton: TextButton
local actionTitle: TextLabel
local actionKey: TextLabel
local crosshair: Frame
local highlight: Highlight
local arcFolder: Folder
local arcDots: { BasePart } = {}
local landingMarker: BasePart

local COLOR_GRAB = Color3.fromRGB(70, 160, 255)
local COLOR_THROW = Color3.fromRGB(255, 120, 40)
local COLOR_REACHABLE = Color3.fromRGB(90, 230, 120)
local COLOR_OUT_OF_RANGE = Color3.fromRGB(255, 150, 40)

---------------------------------------------------------------------------
-- Input mode
---------------------------------------------------------------------------
local function modeFor(inputType: Enum.UserInputType): InputMode?
	if inputType == Enum.UserInputType.Touch then
		return "Touch"
	elseif inputType.Name:find("Gamepad") then
		return "Gamepad"
	elseif
		inputType == Enum.UserInputType.Keyboard
		or inputType == Enum.UserInputType.MouseButton1
		or inputType == Enum.UserInputType.MouseButton2
		or inputType == Enum.UserInputType.MouseMovement
	then
		return "Mouse"
	end
	return nil
end

---------------------------------------------------------------------------
-- Aiming
---------------------------------------------------------------------------
local function aimScreenPoint(useCursor: boolean): Vector2
	if useCursor then
		return UserInputService:GetMouseLocation()
	end
	local viewport = workspace.CurrentCamera.ViewportSize
	return Vector2.new(viewport.X / 2, viewport.Y / 2)
end

local function aimWorldPoint(screen: Vector2): Vector3
	local camera = workspace.CurrentCamera
	local ray = camera:ViewportPointToRay(screen.X, screen.Y)
	local ignore: { Instance } = { arcFolder }
	if player.Character then
		table.insert(ignore, player.Character)
	end
	for _, name in { "DebrisClearLocalVisuals" } do
		local folder = workspace:FindFirstChild(name)
		if folder then
			table.insert(ignore, folder)
		end
	end
	local arena = workspace:FindFirstChild("DebrisClearArena")
	local debrisFolder = arena and arena:FindFirstChild("Debris")
	if debrisFolder then
		table.insert(ignore, debrisFolder)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local result = workspace:Raycast(ray.Origin, ray.Direction * Config.THROW_MAX_AIM_DISTANCE, params)
	return if result then result.Position else ray.Origin + ray.Direction * Config.THROW_MAX_AIM_DISTANCE
end

local function holdOrigin(): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root and (root.CFrame * Config.HOLD_OFFSET).Position
end

---------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------
local function requestThrow(useCursor: boolean)
	if not holding then
		return
	end
	local now = os.clock()
	if now - lastThrowRequest < Config.THROW_COOLDOWN then
		return
	end
	lastThrowRequest = now
	throwRemote:FireServer(aimWorldPoint(aimScreenPoint(useCursor)))
end

local function beginGrab()
	local prompt = targetPrompt
	if prompt and not holding then
		prompt:InputHoldBegin()
	end
end

local function endGrab()
	local prompt = targetPrompt
	if prompt then
		prompt:InputHoldEnd()
	end
end

---------------------------------------------------------------------------
-- UI state
---------------------------------------------------------------------------
local function keyLabel(forThrow: boolean): string
	if inputMode == "Touch" then
		return "TAP"
	elseif inputMode == "Gamepad" then
		return if forThrow then "R2" else "X"
	end
	return if forThrow then "CLICK" else Config.PICKUP_KEY.Name
end

local function refresh()
	if holding then
		actionButton.Visible = true
		actionButton.BackgroundColor3 = COLOR_THROW
		actionTitle.Text = "THROW"
		actionKey.Text = keyLabel(true)
		highlight.Adornee = nil
	elseif targetPrompt then
		local part = targetPrompt.Parent :: BasePart
		actionButton.Visible = true
		actionButton.BackgroundColor3 = COLOR_GRAB
		actionTitle.Text = "GRAB"
		actionKey.Text = keyLabel(false)
		highlight.Adornee = DebrisVisuals.visualFor(part) or part
	else
		actionButton.Visible = false
		highlight.Adornee = nil
	end
	-- Mouse throws aim at the cursor; everything else aims at screen center.
	crosshair.Visible = holding and inputMode ~= "Mouse"
	arcFolder.Parent = if holding then workspace else nil
end

local function onHoldingChanged()
	holding = player:GetAttribute("HoldingDebris") == true
	-- Hide every pickup prompt while our hands are full.
	ProximityPromptService.Enabled = not holding
	if holding then
		targetPrompt = nil
	end
	refresh()
end

---------------------------------------------------------------------------
-- Aim preview
---------------------------------------------------------------------------
local function updateArc()
	if not holding then
		return
	end
	local origin = holdOrigin()
	if not origin then
		return
	end
	local target = aimWorldPoint(aimScreenPoint(inputMode == "Mouse"))
	local velocity, reachable = Ballistics.solve(origin, target, Config.THROW_SPEED)

	local flatSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local flatDistance = Vector3.new(target.X - origin.X, 0, target.Z - origin.Z).Magnitude
	local duration = Config.AIM_ARC_MAX_TIME
	if reachable and flatSpeed > 0.01 then
		duration = math.min(flatDistance / flatSpeed, Config.AIM_ARC_MAX_TIME)
	end

	local color = if reachable then COLOR_REACHABLE else COLOR_OUT_OF_RANGE
	for i, dot in arcDots do
		dot.Position = Ballistics.positionAt(origin, velocity, duration * i / #arcDots)
		dot.Color = color
	end
	landingMarker.Transparency = if reachable then 0.2 else 1
	landingMarker.Color = color
	landingMarker.CFrame = CFrame.new(target + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90))
end

---------------------------------------------------------------------------
-- Knockback (server decides, we apply because we own our character)
---------------------------------------------------------------------------
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

---------------------------------------------------------------------------
-- Construction
---------------------------------------------------------------------------
local function buildUi()
	local gui = Instance.new("ScreenGui")
	gui.Name = "DebrisClearActions"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true

	actionButton = Instance.new("TextButton")
	actionButton.Name = "ActionButton"
	actionButton.AnchorPoint = Vector2.new(1, 1)
	-- Sits above the mobile jump button.
	actionButton.Position = UDim2.new(1, -24, 1, -170)
	actionButton.Size = UDim2.fromOffset(110, 110)
	actionButton.Text = ""
	actionButton.AutoButtonColor = true
	actionButton.BackgroundColor3 = COLOR_GRAB
	actionButton.BackgroundTransparency = 0.1
	actionButton.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = actionButton
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.new(1, 1, 1)
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = actionButton

	actionTitle = Instance.new("TextLabel")
	actionTitle.Name = "Title"
	actionTitle.BackgroundTransparency = 1
	actionTitle.Position = UDim2.fromScale(0.1, 0.22)
	actionTitle.Size = UDim2.fromScale(0.8, 0.34)
	actionTitle.Font = Enum.Font.GothamBlack
	actionTitle.TextScaled = true
	actionTitle.TextColor3 = Color3.new(1, 1, 1)
	actionTitle.Parent = actionButton

	actionKey = actionTitle:Clone()
	actionKey.Name = "Key"
	actionKey.Position = UDim2.fromScale(0.2, 0.6)
	actionKey.Size = UDim2.fromScale(0.6, 0.2)
	actionKey.Font = Enum.Font.GothamBold
	actionKey.TextTransparency = 0.15
	actionKey.Parent = actionButton

	crosshair = Instance.new("Frame")
	crosshair.Name = "Crosshair"
	crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
	crosshair.Position = UDim2.fromScale(0.5, 0.5)
	crosshair.Size = UDim2.fromOffset(10, 10)
	crosshair.BackgroundColor3 = Color3.new(1, 1, 1)
	crosshair.Visible = false
	local dotCorner = Instance.new("UICorner")
	dotCorner.CornerRadius = UDim.new(0.5, 0)
	dotCorner.Parent = crosshair
	local dotStroke = Instance.new("UIStroke")
	dotStroke.Thickness = 1.5
	dotStroke.Parent = crosshair
	crosshair.Parent = gui

	actionButton.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")

	-- The button both grabs and throws. Pressing it sinks the input, so the
	-- world-click throw handler below won't also fire.
	actionButton.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		if holding then
			requestThrow(false)
		else
			beginGrab()
		end
	end)
	actionButton.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			endGrab()
		end
	end)
end

local function buildWorldHelpers()
	highlight = Instance.new("Highlight")
	highlight.Name = "DebrisTargetHighlight"
	highlight.FillColor = COLOR_GRAB
	highlight.FillTransparency = 0.6
	highlight.OutlineColor = Color3.new(1, 1, 1)
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = workspace

	arcFolder = Instance.new("Folder")
	arcFolder.Name = "DebrisClearAimArc"
	local function helperPart(shape: Enum.PartType, size: Vector3): Part
		local part = Instance.new("Part")
		part.Shape = shape
		part.Size = size
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.Neon
		part.Parent = arcFolder
		return part
	end
	for _ = 1, Config.AIM_ARC_POINTS do
		table.insert(arcDots, helperPart(Enum.PartType.Ball, Vector3.one * 0.4))
	end
	landingMarker = helperPart(Enum.PartType.Cylinder, Vector3.new(0.2, 4, 4))
	landingMarker.Name = "LandingMarker"
end

function InteractionController.start()
	throwRemote = Remotes.get("ThrowDebris")
	Remotes.get("Knockback").OnClientEvent:Connect(onKnockback)

	buildUi()
	buildWorldHelpers()

	local fallback: InputMode = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		then "Touch"
		else "Mouse"
	inputMode = modeFor(UserInputService:GetLastInputType()) or fallback
	UserInputService.LastInputTypeChanged:Connect(function(inputType)
		local mode: InputMode? = modeFor(inputType)
		if mode and mode ~= inputMode then
			inputMode = mode :: InputMode
			refresh()
		end
	end)

	-- World throw inputs. gameProcessed is true for clicks on GUI (including
	-- our own button), so those never double-throw.
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or not holding then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			requestThrow(true)
		elseif input.KeyCode == Config.THROW_GAMEPAD_KEY then
			requestThrow(false)
		end
	end)

	ProximityPromptService.PromptShown:Connect(function(prompt)
		if prompt.Name == "PickupPrompt" and not holding then
			targetPrompt = prompt
			refresh()
		end
	end)
	ProximityPromptService.PromptHidden:Connect(function(prompt)
		if prompt == targetPrompt then
			targetPrompt = nil
			refresh()
		end
	end)

	player:GetAttributeChangedSignal("HoldingDebris"):Connect(onHoldingChanged)
	onHoldingChanged()

	RunService.RenderStepped:Connect(updateArc)
end

return InteractionController

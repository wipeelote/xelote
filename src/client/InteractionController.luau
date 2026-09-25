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
-- Ballistics module). Green = reachable, orange = out of range. A bar on the
-- button counts down the server's hold limit ("HoldUntil").
-- The server's "Throwing" attribute drives a local wind-up: the held d10's
-- visual pulls back then snaps forward, and the right arm (raised while
-- holding) swings with it. All of that is cosmetic and local.
-- Also applies server-issued knockback to our own character.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("DebrisClear")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Ballistics = require(Shared.Ballistics)
local DebrisVisuals = require(script.Parent.DebrisVisuals)

type InputMode = "Mouse" | "Touch" | "Gamepad"
type Windup = { part: BasePart?, startedAt: number, snapped: boolean }

local InteractionController = {}

local player = Players.LocalPlayer
local throwRemote: RemoteEvent

local holding = false
local heldPart: BasePart? = nil
local holdUntil: number? = nil
local windup: Windup? = nil
local targetPrompt: ProximityPrompt? = nil
local inputMode: InputMode = "Mouse"
local lastThrowRequest = 0
local stunToken = 0

-- UI / world objects created in start()
local actionButton: TextButton
local actionTitle: TextLabel
local actionKey: TextLabel
local holdBar: Frame
local holdFill: Frame
local crosshair: Frame
local highlight: Highlight
local arcFolder: Folder
local arcDots: { BasePart } = {}
local landingMarker: BasePart

local COLOR_GRAB = Color3.fromRGB(70, 160, 255)
local COLOR_THROW = Color3.fromRGB(255, 120, 40)
local COLOR_REACHABLE = Color3.fromRGB(90, 230, 120)
local COLOR_OUT_OF_RANGE = Color3.fromRGB(255, 150, 40)
local COLOR_HOLD = Color3.new(1, 1, 1)
local COLOR_HOLD_LOW = Color3.fromRGB(255, 60, 60)
local HOLD_WARN_TIME = 1 -- seconds left when the countdown turns red

-- Wind-up: the held visual eases to PULLBACK over THROW_WINDUP, then sits at
-- SNAP for SNAP_TIME as the piece leaves. Offsets are in the piece's frame,
-- which matches the character's while welded (+X right, +Y up, -Z forward).
local WINDUP_PULLBACK = CFrame.new(0.6, 0.6, 0.9)
local WINDUP_SNAP = CFrame.new(0, 0, -1.2)
local WINDUP_SNAP_TIME = 0.08

-- Arm raise. Angles are the shoulder swing forward/up from the hanging pose:
-- 90 = straight ahead, 180 = straight up (the piece sits directly overhead).
local ARM_HOLD_ANGLE = math.rad(165)
local ARM_WINDUP_ANGLE = math.rad(200) -- cocked back past vertical
local ARM_THROW_ANGLE = math.rad(60) -- follow-through
local ARM_TWEEN_TIME = 0.12 -- raise on pickup / settle back after a throw

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
local function debrisFolder(): Instance?
	local arena = workspace:FindFirstChild("DebrisClearArena")
	return arena and arena:FindFirstChild("Debris")
end

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
	local debris = debrisFolder()
	if debris then
		table.insert(ignore, debris)
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

-- The piece the server welded to us: the debris whose WeldConstraint hangs
-- off our root. May lag the attribute by a frame, so callers retry.
local function findHeldPart(): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local debris = debrisFolder()
	if not root or not debris then
		return nil
	end
	for _, child in debris:GetChildren() do
		local weld = child:FindFirstChildOfClass("WeldConstraint")
		if weld and weld.Part0 == root and child:IsA("BasePart") then
			return child
		end
	end
	return nil
end

---------------------------------------------------------------------------
-- Arm raise (cosmetic, local). Motor6D.C0 edits compose with the animation
-- Transform, so idle/walk animations keep playing on top of the pose.
---------------------------------------------------------------------------
local armJoint: Motor6D? = nil
local armOriginalC0: CFrame? = nil
local armTween: Tween? = nil

-- The right shoulder of the current rig and the C0 rotation that swings the
-- arm forward/up by `angle` around it.
--   R15: RightShoulder.C0 has no rotation, so C0 * Angles(angle, 0, 0) pitches
--        about the torso's +X (right) axis. Right-hand rule: +X rotation takes
--        -Y (hanging) toward -Z (forward), so positive angles swing the arm
--        forward and up.
--   R6:  "Right Shoulder".C0 is rotated 90 about Y, which points the joint's
--        local Z along the torso's +X. The same forward/up swing is therefore
--        a rotation about local Z (the axis Motor6D.DesiredAngle turns on;
--        it's why the classic tool pose used a positive DesiredAngle).
local function shoulderPose(angle: number): (Motor6D?, CFrame?)
	local character = player.Character
	if not character then
		return nil, nil
	end
	local upperArm = character:FindFirstChild("RightUpperArm")
	local r15 = upperArm and upperArm:FindFirstChild("RightShoulder")
	if r15 and r15:IsA("Motor6D") then
		return r15, CFrame.Angles(angle, 0, 0)
	end
	local torso = character:FindFirstChild("Torso")
	local r6 = torso and torso:FindFirstChild("Right Shoulder")
	if r6 and r6:IsA("Motor6D") then
		return r6, CFrame.Angles(0, 0, angle)
	end
	return nil, nil
end

local function armStopTween()
	if armTween then
		armTween:Cancel()
		armTween = nil
	end
end

-- Put the rig's own C0 back exactly (hold ended, died, respawned).
local function armRestore()
	if not Config.ARM_RAISE then
		return
	end
	pcall(function()
		armStopTween()
		local joint, original = armJoint, armOriginalC0
		if joint and original then
			joint.C0 = original
		end
	end)
end

-- Tween the shoulder to `angle` over `duration` seconds.
local function armSwing(angle: number, duration: number)
	if not Config.ARM_RAISE then
		return
	end
	pcall(function()
		local joint, rotation = shoulderPose(angle)
		if joint ~= armJoint then
			-- New rig: hand the old one back and remember this one's untouched C0.
			armRestore()
			armJoint = joint
			armOriginalC0 = if joint then joint.C0 else nil
		end
		local original = armOriginalC0
		if not joint or not rotation or not original then
			return
		end
		armStopTween()
		local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local tween = TweenService:Create(joint, info, { C0 = original * rotation })
		armTween = tween
		tween:Play()
	end)
end

local function armForget()
	armStopTween()
	armJoint = nil
	armOriginalC0 = nil
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
	holdBar.Visible = holding
	-- Mouse throws aim at the cursor; everything else aims at screen center.
	crosshair.Visible = holding and inputMode ~= "Mouse"
	arcFolder.Parent = if holding then workspace else nil
end

---------------------------------------------------------------------------
-- Throw wind-up (server "Throwing" attribute -> local animation)
---------------------------------------------------------------------------
local function endWindup()
	local current = windup
	if not current then
		return
	end
	windup = nil
	if current.part then
		DebrisVisuals.setOffset(current.part, nil)
	end
	if holding then
		armSwing(ARM_HOLD_ANGLE, ARM_TWEEN_TIME)
	else
		armRestore()
	end
end

local function beginWindup()
	endWindup()
	windup = { part = heldPart, startedAt = os.clock(), snapped = false }
	armSwing(ARM_WINDUP_ANGLE, Config.THROW_WINDUP)
end

local function updateWindup()
	local current = windup
	if not current then
		return
	end
	local elapsed = os.clock() - current.startedAt
	if elapsed >= Config.THROW_WINDUP + WINDUP_SNAP_TIME then
		endWindup()
		return
	end
	if elapsed >= Config.THROW_WINDUP and not current.snapped then
		current.snapped = true
		armSwing(ARM_THROW_ANGLE, WINDUP_SNAP_TIME)
	end
	-- Imported-mesh debris has no local visual; then only the arm animates.
	local part = current.part
	if part and part.Parent and DebrisVisuals.visualFor(part) then
		local offset = if current.snapped
			then WINDUP_SNAP
			else CFrame.identity:Lerp(WINDUP_PULLBACK, elapsed / Config.THROW_WINDUP)
		DebrisVisuals.setOffset(part, offset)
	end
end

local function onThrowingChanged()
	if player:GetAttribute("Throwing") == true then
		beginWindup()
	elseif windup and not windup.snapped then
		-- On a launch HoldingDebris and Throwing clear together (in either
		-- order); a wind-up that ends with the hold still on was cancelled.
		task.defer(function()
			local current = windup
			if current and not current.snapped and holding then
				endWindup()
			end
		end)
	end
end

local function onHoldingChanged()
	holding = player:GetAttribute("HoldingDebris") == true
	-- Hide every pickup prompt while our hands are full.
	ProximityPromptService.Enabled = not holding
	if holding then
		targetPrompt = nil
		heldPart = findHeldPart()
		armSwing(ARM_HOLD_ANGLE, ARM_TWEEN_TIME)
	else
		heldPart = nil
		if not windup then
			armRestore() -- a throw in flight restores when its swing ends
		end
	end
	refresh()
end

local function onHoldUntilChanged()
	local value = player:GetAttribute("HoldUntil")
	holdUntil = if typeof(value) == "number" then value else nil
end

---------------------------------------------------------------------------
-- Per-frame: aim preview and hold countdown
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

-- Bar under the THROW label: full at pickup, empty at HoldUntil, red near the end.
local function updateHoldBar()
	if not holding then
		return
	end
	local deadline = holdUntil
	local remaining = if deadline then deadline - workspace:GetServerTimeNow() else Config.HOLD_MAX_TIME
	holdFill.Size = UDim2.fromScale(math.clamp(remaining / Config.HOLD_MAX_TIME, 0, 1), 1)
	holdFill.BackgroundColor3 = if remaining <= HOLD_WARN_TIME then COLOR_HOLD_LOW else COLOR_HOLD
end

local function onRenderStepped()
	if holding then
		local part = heldPart
		if not part or not part.Parent then
			heldPart = findHeldPart()
		end
	end
	updateArc()
	updateHoldBar()
	updateWindup()
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

	-- Hold countdown: a thin track under the key label whose fill shrinks
	-- toward the middle.
	holdBar = Instance.new("Frame")
	holdBar.Name = "HoldBar"
	holdBar.AnchorPoint = Vector2.new(0.5, 0)
	holdBar.Position = UDim2.fromScale(0.5, 0.82)
	holdBar.Size = UDim2.fromScale(0.5, 0.05)
	holdBar.BackgroundColor3 = Color3.new(0, 0, 0)
	holdBar.BackgroundTransparency = 0.5
	holdBar.BorderSizePixel = 0
	holdBar.Visible = false
	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0.5, 0)
	barCorner.Parent = holdBar
	holdFill = Instance.new("Frame")
	holdFill.Name = "Fill"
	holdFill.AnchorPoint = Vector2.new(0.5, 0)
	holdFill.Position = UDim2.fromScale(0.5, 0)
	holdFill.Size = UDim2.fromScale(1, 1)
	holdFill.BackgroundColor3 = COLOR_HOLD
	holdFill.BorderSizePixel = 0
	barCorner:Clone().Parent = holdFill
	holdFill.Parent = holdBar
	holdBar.Parent = actionButton

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

-- A fresh rig has untouched joints; a dying one gets its shoulder back.
local function onCharacterAdded(character: Model)
	armForget()
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Died:Connect(armRestore)
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

	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end

	player:GetAttributeChangedSignal("HoldUntil"):Connect(onHoldUntilChanged)
	player:GetAttributeChangedSignal("Throwing"):Connect(onThrowingChanged)
	player:GetAttributeChangedSignal("HoldingDebris"):Connect(onHoldingChanged)
	onHoldUntilChanged()
	onHoldingChanged()

	RunService.RenderStepped:Connect(onRenderStepped)
end

return InteractionController

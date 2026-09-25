--!strict
-- Camera shake, impact puffs and the winner focus, driven by the server's
-- "Effects" remote (see Remotes.luau for the kinds). Purely cosmetic: every
-- argument is type-checked and a malformed event is ignored.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("DebrisClear")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

type PuffSpec = { count: number, scale: number, color: Color3 }

local EffectsController = {}

local player = Players.LocalPlayer
local rng = Random.new()
local effectsFolder: Folder

-- Shake intensity is in "units": each unit adds a random +-SHAKE_DEGREES of
-- pitch and yaw per frame. A burst decays to zero SHAKE_DECAY_TIME after its peak.
local SHAKE_DEGREES = 0.6
local SHAKE_DECAY_TIME = 0.4
local shakeIntensity = 0
local shakePeak = 0
local lastShakeOffset = CFrame.identity -- rotation applied to the camera last frame

-- Dust puffs (Land uses scale 1; Crush is bigger and darker).
local PUFF_PART_LIFETIME = 1.5
local PUFF_SIZE = NumberRange.new(0.6, 2) -- start -> end of a particle's life
local PUFF_TRANSPARENCY = NumberRange.new(0.3, 1)
local PUFF_LIFETIME = 0.5
local PUFF_SPEED = 6
local PUFF_SPREAD = 60
local PUFF_GRAVITY = -4
local LAND_PUFF: PuffSpec = { count = 12, scale = 1, color = Color3.fromRGB(170, 170, 175) }
local CRUSH_PUFF: PuffSpec = { count = 30, scale = 2.2, color = Color3.fromRGB(70, 70, 78) }

-- Winner celebration.
local CONFETTI = {
	height = 12, -- studs above the deck
	count = 60, -- per emitter
	partLifetime = 5,
	lifetime = NumberRange.new(1.5, 2.5),
	speed = NumberRange.new(20, 35),
	spread = 75,
	gravity = -25,
	drag = 1.5,
	colors = {
		{ Color3.fromRGB(255, 220, 60), Color3.fromRGB(255, 80, 120) },
		{ Color3.fromRGB(80, 220, 255), Color3.fromRGB(150, 90, 255) },
	},
}
local WIN_CAMERA = {
	distance = 45, -- horizontal studs from the platform center, toward the arena center
	height = 25,
	tweenTime = 1,
}
local endFocus: (() -> ())? = nil

---------------------------------------------------------------------------
-- Camera shake
---------------------------------------------------------------------------
local function shake(magnitude: number)
	if magnitude <= 0 then
		return
	end
	shakeIntensity += magnitude
	shakePeak = math.max(shakePeak, shakeIntensity)
end

local function stepShake(dt: number)
	local camera = workspace.CurrentCamera
	if not camera or camera.CameraType == Enum.CameraType.Scriptable then
		-- A Scriptable camera (winner focus) is ours alone: leave it untouched.
		lastShakeOffset = CFrame.identity
	else
		local offset = CFrame.identity
		if shakeIntensity > 0 then
			local amplitude = math.rad(SHAKE_DEGREES) * shakeIntensity
			local pitch = rng:NextNumber(-amplitude, amplitude)
			local yaw = rng:NextNumber(-amplitude, amplitude)
			offset = CFrame.Angles(pitch, yaw, 0)
		end
		-- The default camera scripts derive each frame's look direction from
		-- the previous frame's CFrame, so undo last frame's offset before
		-- applying this one or the shake random-walks the view. Runs once more
		-- after the intensity hits zero so the final offset is removed too.
		if offset ~= lastShakeOffset then
			camera.CFrame = camera.CFrame * lastShakeOffset:Inverse() * offset
		end
		lastShakeOffset = offset
	end
	if shakeIntensity > 0 then
		shakeIntensity = math.max(0, shakeIntensity - shakePeak * dt / SHAKE_DECAY_TIME)
		if shakeIntensity == 0 then
			shakePeak = 0
		end
	end
end

---------------------------------------------------------------------------
-- Particles
---------------------------------------------------------------------------
local function effectPart(position: Vector3, lifetime: number): Part
	local part = Instance.new("Part")
	part.Name = "Effect"
	part.Size = Vector3.one
	part.CFrame = CFrame.new(position)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Parent = effectsFolder
	task.delay(lifetime, function()
		part:Destroy()
	end)
	return part
end

local function puff(position: Vector3, spec: PuffSpec)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 0
	emitter.Color = ColorSequence.new(spec.color)
	emitter.Size = NumberSequence.new(PUFF_SIZE.Min * spec.scale, PUFF_SIZE.Max * spec.scale)
	emitter.Transparency = NumberSequence.new(PUFF_TRANSPARENCY.Min, PUFF_TRANSPARENCY.Max)
	emitter.Lifetime = NumberRange.new(PUFF_LIFETIME)
	emitter.Speed = NumberRange.new(PUFF_SPEED * spec.scale)
	emitter.SpreadAngle = Vector2.new(PUFF_SPREAD, PUFF_SPREAD)
	emitter.Acceleration = Vector3.new(0, PUFF_GRAVITY, 0)
	emitter.Parent = effectPart(position, PUFF_PART_LIFETIME)
	emitter:Emit(spec.count)
end

local function confetti(position: Vector3)
	local part = effectPart(position + Vector3.new(0, CONFETTI.height, 0), CONFETTI.partLifetime)
	for _, colors in CONFETTI.colors do
		local emitter = Instance.new("ParticleEmitter")
		emitter.Rate = 0
		emitter.Color = ColorSequence.new(colors[1], colors[2])
		emitter.LightEmission = 0.6
		emitter.Size = NumberSequence.new(0.5, 0.25)
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.7, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		emitter.Lifetime = CONFETTI.lifetime
		emitter.Speed = CONFETTI.speed
		emitter.SpreadAngle = Vector2.new(CONFETTI.spread, CONFETTI.spread)
		emitter.Rotation = NumberRange.new(0, 360)
		emitter.RotSpeed = NumberRange.new(-360, 360)
		emitter.Acceleration = Vector3.new(0, CONFETTI.gravity, 0)
		emitter.Drag = CONFETTI.drag
		emitter.EmissionDirection = Enum.NormalId.Top
		emitter.Parent = part
		emitter:Emit(CONFETTI.count)
	end
end

---------------------------------------------------------------------------
-- Winner focus
---------------------------------------------------------------------------
local function restoreCamera()
	pcall(function()
		local camera = workspace.CurrentCamera
		camera.CameraType = Enum.CameraType.Custom
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end)
end

-- Scriptable camera on the arena-center side of the platform, looking at it,
-- for WIN_CAMERA_TIME. Handed back early only if our character respawns: a
-- death alone (the crush that ended the round) needs nothing restored, and
-- the respawn is what needs CameraType Custom plus the new Humanoid as subject.
local function focusWinner(position: Vector3)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	if endFocus then
		endFocus()
	end

	local toCenter = Vector3.new(Config.ARENA_CENTER.X - position.X, 0, Config.ARENA_CENTER.Z - position.Z)
	local side = if toCenter.Magnitude > 0.01 then toCenter.Unit else Vector3.zAxis
	local eye = position + side * WIN_CAMERA.distance + Vector3.new(0, WIN_CAMERA.height, 0)

	camera.CameraType = Enum.CameraType.Scriptable
	local tween = TweenService:Create(
		camera,
		TweenInfo.new(math.min(WIN_CAMERA.tweenTime, Config.WIN_CAMERA_TIME), Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{ CFrame = CFrame.lookAt(eye, position) }
	)
	tween:Play()

	local respawned: RBXScriptConnection? = nil
	local done = false
	local function finish()
		if done then
			return
		end
		done = true
		endFocus = nil
		if respawned then
			respawned:Disconnect()
		end
		pcall(tween.Cancel, tween)
		restoreCamera()
	end
	endFocus = finish

	respawned = player.CharacterAdded:Connect(finish)
	task.delay(Config.WIN_CAMERA_TIME, finish)
end

---------------------------------------------------------------------------
-- Event handlers
---------------------------------------------------------------------------
local function isOurSlot(slot: number): boolean
	return player:GetAttribute("PlatformSlot") == slot
end

local function onLand(position: Vector3, slot: number)
	puff(position, LAND_PUFF)
	if isOurSlot(slot) then
		shake(Config.SHAKE_LAND)
	end
end

local function onCrush(position: Vector3, slot: number)
	puff(position, CRUSH_PUFF)
	if isOurSlot(slot) then
		shake(Config.SHAKE_CRUSH)
		return
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local distance = (camera.CFrame.Position - position).Magnitude
	local falloff = 1 - math.clamp(distance / Config.SHAKE_FALLOFF_RANGE, 0, 1)
	shake(Config.SHAKE_CRUSH * falloff)
end

local function onWin(position: Vector3, slot: number)
	if slot <= 0 then
		shake(Config.SHAKE_LAND)
		return
	end
	confetti(position)
	if Config.WIN_CAMERA_TIME > 0 then
		focusWinner(position)
	end
end

local function onEffect(kind: unknown, position: unknown, slot: unknown)
	if typeof(kind) ~= "string" or typeof(position) ~= "Vector3" or typeof(slot) ~= "number" then
		return
	end
	local at = position :: Vector3
	local slotNumber = slot :: number
	if kind == "Land" then
		onLand(at, slotNumber)
	elseif kind == "Crush" then
		onCrush(at, slotNumber)
	elseif kind == "Win" then
		onWin(at, slotNumber)
	end
end

function EffectsController.start()
	effectsFolder = Instance.new("Folder")
	effectsFolder.Name = "DebrisClearEffects"
	effectsFolder.Parent = workspace

	RunService:BindToRenderStep("DebrisClearShake", Enum.RenderPriority.Camera.Value + 1, stepShake)
	Remotes.get("Effects").OnClientEvent:Connect(onEffect)
end

return EffectsController

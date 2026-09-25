--!strict
-- Pickup (ProximityPrompt) and throw (RemoteEvent). The client only sends an
-- aim point. Everything else (who holds what, where it launches from, how
-- fast, what it hits) is decided here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("DebrisClear")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Ballistics = require(Shared.Ballistics)
local DebrisService = require(script.Parent.DebrisService)
local LoadService = require(script.Parent.LoadService)
local RateLimiter = require(script.Parent.RateLimiter)

type DebrisRecord = DebrisService.DebrisRecord

local ThrowService = {}

local holding: { [Player]: BasePart? } = {}
local holdWelds: { [Player]: WeldConstraint } = {}
local lastPickup: { [Player]: number } = {}
local lastThrow: { [Player]: number } = {}
local throwLimiter = RateLimiter.new(Config.MAX_REMOTE_RATE)

local throwRemote: RemoteEvent
local knockbackRemote: RemoteEvent

local function livingRoot(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	if not character then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or humanoid.Health <= 0 or not root then
		return nil, nil
	end
	return root, humanoid
end

local function isFiniteVector(v: Vector3): boolean
	for _, n in { v.X, v.Y, v.Z } do
		if n ~= n or math.abs(n) > 1e6 then
			return false
		end
	end
	return true
end

local function setHolding(player: Player, part: BasePart?)
	holding[player] = part
	player:SetAttribute("HoldingDebris", part ~= nil)
end

-- Drop whatever the player is holding in place (death, elimination, leaving).
function ThrowService.release(player: Player)
	local part = holding[player]
	local weld = holdWelds[player]
	holdWelds[player] = nil
	setHolding(player, nil)
	if weld then
		weld:Destroy()
	end
	if part and part.Parent then
		local record = DebrisService.get(part)
		if record then
			DebrisService.markReleased(record, nil, nil)
		end
		pcall(part.SetNetworkOwner, part, nil)
	end
end

function ThrowService.releaseAll()
	for player in holding do
		ThrowService.release(player)
	end
end

local function tryPickup(player: Player, part: BasePart)
	if not LoadService.isAlive(player) or holding[player] then
		return
	end
	local now = os.clock()
	if now - (lastPickup[player] or 0) < Config.PICKUP_COOLDOWN then
		return
	end
	local record = DebrisService.get(part)
	if not record or record.heldBy then
		return
	end
	local root = livingRoot(player)
	if not root then
		return
	end
	-- The prompt enforces range on the client; re-check with latency slack.
	if (root.Position - part.Position).Magnitude > Config.PICKUP_RANGE + Config.PICKUP_RANGE_TOLERANCE then
		return
	end
	lastPickup[player] = now

	DebrisService.markHeld(record, player)
	part.AssemblyLinearVelocity = Vector3.zero
	part.AssemblyAngularVelocity = Vector3.zero
	part.CFrame = root.CFrame * Config.HOLD_OFFSET
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
	holdWelds[player] = weld
	setHolding(player, part)
end

local function onThrowRequest(player: Player, aimPoint: unknown)
	-- Validation: type, rate, state, then geometry.
	if typeof(aimPoint) ~= "Vector3" then
		return
	end
	local aim = aimPoint :: Vector3
	if not isFiniteVector(aim) or not throwLimiter:allow(player) then
		return
	end
	local now = os.clock()
	if now - (lastThrow[player] or 0) < Config.THROW_COOLDOWN then
		return
	end
	local part = holding[player]
	if not part or not LoadService.isAlive(player) then
		return
	end
	local record = DebrisService.get(part)
	local root = livingRoot(player)
	if not record or record.heldBy ~= player or not root then
		return
	end
	lastThrow[player] = now

	-- Launch from the server's view of the hold position, never a client value.
	local origin = (root.CFrame * Config.HOLD_OFFSET).Position
	local toAim = aim - origin
	if toAim.Magnitude > Config.THROW_MAX_AIM_DISTANCE then
		aim = origin + toAim.Unit * Config.THROW_MAX_AIM_DISTANCE
	end
	local velocity = Ballistics.solve(origin, aim, Config.THROW_SPEED)

	local weld = holdWelds[player]
	holdWelds[player] = nil
	setHolding(player, nil)
	if weld then
		weld:Destroy()
	end
	part.CFrame = CFrame.new(origin) * part.CFrame.Rotation
	DebrisService.markReleased(record, player, velocity)
	pcall(part.SetNetworkOwner, part, nil)
	part.AssemblyLinearVelocity = velocity

	-- LinearVelocity drives the launch briefly, then gravity takes over.
	local attachment = part:FindFirstChild("Center") :: Attachment
	local drive = Instance.new("LinearVelocity")
	drive.Attachment0 = attachment
	drive.RelativeTo = Enum.ActuatorRelativeTo.World
	drive.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	drive.VectorVelocity = velocity
	drive.MaxForce = math.huge
	drive.Parent = part
	task.delay(Config.THROW_BOOST_TIME, function()
		drive:Destroy()
	end)
end

-- Body hit: knock the victim along the throw direction. No load moves here;
-- only debris that comes to rest on a platform counts.
local function onDebrisTouched(record: DebrisRecord, hit: BasePart)
	local character = hit:FindFirstAncestorOfClass("Model")
	local victim = character and Players:GetPlayerFromCharacter(character)
	if not victim or victim == record.thrownBy then
		return
	end
	if os.clock() - record.thrownAt > Config.THROW_HIT_WINDOW then
		record.hitDone = true
		return
	end
	local root = livingRoot(victim)
	if not root then
		return
	end
	record.hitDone = true

	local flat = Vector3.new(record.throwVelocity.X, 0, record.throwVelocity.Z)
	if flat.Magnitude < 0.01 then
		flat = Vector3.new(root.Position.X - record.part.Position.X, 0, root.Position.Z - record.part.Position.Z)
	end
	local direction = if flat.Magnitude > 0.01 then flat.Unit else Vector3.xAxis
	local knockback = direction * Config.KNOCKBACK_SPEED + Vector3.yAxis * Config.KNOCKBACK_UP
	-- The victim's client owns its character physics, so it applies the impulse.
	knockbackRemote:FireClient(victim, knockback, Config.KNOCKBACK_STUN)
end

function ThrowService.init()
	throwRemote = Remotes.get("ThrowDebris")
	knockbackRemote = Remotes.get("Knockback")

	throwRemote.OnServerEvent:Connect(onThrowRequest)
	DebrisService.onPromptTriggered = tryPickup
	DebrisService.onDebrisTouched = onDebrisTouched

	LoadService.onEliminated(function(player)
		ThrowService.release(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		ThrowService.release(player)
		lastPickup[player] = nil
		lastThrow[player] = nil
		throwLimiter:forget(player)
	end)
end

return ThrowService

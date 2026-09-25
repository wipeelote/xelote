--!strict
-- Authoritative per-platform load tracking and elimination.
--
-- platformLoads[player] is the source of truth. It is mirrored onto the
-- platform model's "Load" attribute purely so clients can draw the ring.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("DebrisClear")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Arena = require(script.Parent.Arena)

type Platform = Arena.Platform
type EliminatedListener = (player: Player, platform: Platform, reason: string) -> ()

local LoadService = {}

local effectsRemote = Remotes.get("Effects")

LoadService.platformLoads = {} :: { [Player]: number }
local platformOf: { [Player]: Platform } = {}
local ownerOf: { [Platform]: Player } = {}
local alive: { [Player]: boolean } = {}
local listeners: { EliminatedListener } = {}

function LoadService.onEliminated(listener: EliminatedListener)
	table.insert(listeners, listener)
end

function LoadService.startRound(assignments: { [Player]: Platform })
	LoadService.reset()
	for player, platform in assignments do
		platformOf[player] = platform
		ownerOf[platform] = player
		alive[player] = true
		LoadService.platformLoads[player] = 0
		platform.model:SetAttribute("Load", 0)
		platform.model:SetAttribute("OwnerName", player.DisplayName)
		platform.model:SetAttribute("Eliminated", false)
		player:SetAttribute("PlatformSlot", platform.slot)
	end
end

function LoadService.reset()
	for player in platformOf do
		player:SetAttribute("PlatformSlot", nil)
	end
	table.clear(LoadService.platformLoads)
	table.clear(platformOf)
	table.clear(ownerOf)
	table.clear(alive)
end

function LoadService.isAlive(player: Player): boolean
	return alive[player] == true
end

function LoadService.aliveCount(): number
	local n = 0
	for _, isAlive in alive do
		if isAlive then
			n += 1
		end
	end
	return n
end

function LoadService.alivePlayers(): { Player }
	local out = {}
	for player, isAlive in alive do
		if isAlive then
			table.insert(out, player)
		end
	end
	return out
end

function LoadService.platformOf(player: Player): Platform?
	return platformOf[player]
end

function LoadService.ownerOf(platform: Platform): Player?
	return ownerOf[platform]
end

-- A platform accepts load only while its owner is still in the round.
function LoadService.isActive(platform: Platform): boolean
	local owner: Player? = ownerOf[platform]
	return owner ~= nil and alive[owner] == true
end

function LoadService.addLoad(platform: Platform, delta: number)
	local owner = ownerOf[platform]
	if not owner or not alive[owner] then
		return
	end
	local load = math.max(0, (LoadService.platformLoads[owner] or 0) + delta)
	LoadService.platformLoads[owner] = load
	platform.model:SetAttribute("Load", load)
	if load >= Config.PLATFORM_CAPACITY then
		LoadService.eliminate(owner, "Overloaded")
	end
end

-- Idempotent. Marks the player out immediately, then runs the piston drop and
-- crush without blocking the caller.
function LoadService.eliminate(player: Player, reason: string)
	if not alive[player] then
		return
	end
	alive[player] = false
	local platform = platformOf[player]
	if not platform then
		return
	end
	platform.model:SetAttribute("Eliminated", true)

	task.spawn(function()
		-- Clients shake and puff the moment the piston starts moving.
		effectsRemote:FireAllClients("Crush", platform.topCFrame.Position, platform.slot)
		Arena.dropPlatform(platform)
		-- Crushed along with their own debris, Machine Party style.
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			humanoid.Health = 0
		end
		for _, listener in listeners do
			task.spawn(listener, player, platform, reason)
		end
	end)
end

return LoadService

--!strict
-- Debris Clear server entry point and round loop.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("DebrisClear")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Arena = require(script.Parent.Arena)
local MapKit = require(script.Parent.Map.MapKit)
local LoadService = require(script.Parent.LoadService)
local DebrisService = require(script.Parent.DebrisService)
local ThrowService = require(script.Parent.ThrowService)

Players.CharacterAutoLoads = false

Remotes.get("ThrowDebris") -- create the remotes before any client asks
local effectsRemote = Remotes.get("Effects")
Arena.build()
DebrisService.init()
ThrowService.init()

local roundActive = false

local function setStatus(text: string)
	ReplicatedStorage:SetAttribute("DebrisClearStatus", text)
	Arena.setBoardStatus(text)
end

---------------------------------------------------------------------------
-- Spawning: everyone lives on the hub unless a round puts them on a platform.
---------------------------------------------------------------------------
local function spawnInHub(player: Player)
	if player.Parent ~= Players then
		return
	end
	player:LoadCharacterAsync()
end

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Died:Connect(function()
		ThrowService.release(player)
		if roundActive then
			LoadService.eliminate(player, "Fell")
		end
		task.delay(Config.RESPAWN_DELAY, function()
			-- Only respawn if this is still the current character.
			if player.Character == character and not (roundActive and LoadService.isAlive(player)) then
				spawnInHub(player)
			end
		end)
	end)
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	spawnInHub(player)
end)
for _, player in Players:GetPlayers() do
	task.spawn(function()
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
		spawnInHub(player)
	end)
end

Players.PlayerRemoving:Connect(function(player)
	if roundActive then
		LoadService.eliminate(player, "Left")
	end
end)

LoadService.onEliminated(function(player, platform, reason)
	DebrisService.crushPlatform(platform)
	if roundActive then
		local verb = if reason == "Overloaded" then "was crushed" elseif reason == "Left" then "left" else "fell"
		setStatus(`{player.DisplayName} {verb}! {LoadService.aliveCount()} left`)
	end
end)

-- Only the pit kills. Below the kill line is death for anyone in the round or
-- anyone inside the arena column. Spectators who fall off the hub anywhere
-- else are put back on the hub instead.
RunService.Heartbeat:Connect(function()
	local killY = Arena.killY()
	local rescueY = Arena.hubFloorY - Config.HUB_RESCUE_DEPTH
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not (character and root and humanoid) or humanoid.Health <= 0 then
			continue
		end
		local position = root.Position
		local competing = roundActive and LoadService.isAlive(player)
		if position.Y < killY and (competing or Arena.inArenaColumn(position)) then
			humanoid.Health = 0
		elseif not competing and position.Y < rescueY and not Arena.inArenaColumn(position) then
			root.AssemblyLinearVelocity = Vector3.zero
			character:PivotTo(Arena.nearestSafeCFrame(position))
		end
	end
end)

---------------------------------------------------------------------------
-- Teleport pads (hub <-> showcase). Spectators only; competitors stay put.
---------------------------------------------------------------------------
local lastTeleport: { [Player]: number } = {}

local function bindTeleportPad(pad: Instance)
	if not pad:IsA("BasePart") then
		return
	end
	pad.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player or not character then
			return
		end
		if roundActive and LoadService.isAlive(player) then
			return
		end
		local now = os.clock()
		if now - (lastTeleport[player] or 0) < Config.TELEPORT_COOLDOWN then
			return
		end
		local destination = Arena.destinationCFrame(tostring(pad:GetAttribute("Destination")))
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not destination or not root then
			return
		end
		lastTeleport[player] = now
		root.AssemblyLinearVelocity = Vector3.zero
		character:PivotTo(destination)
	end)
end

CollectionService:GetInstanceAddedSignal(MapKit.TELEPORT_TAG):Connect(bindTeleportPad)
for _, pad in CollectionService:GetTagged(MapKit.TELEPORT_TAG) do
	bindTeleportPad(pad)
end
Players.PlayerRemoving:Connect(function(player)
	lastTeleport[player] = nil
end)

---------------------------------------------------------------------------
-- Round loop
---------------------------------------------------------------------------
local function readyPlayers(): { Player }
	local out = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			table.insert(out, player)
		end
	end
	return out
end

local function intermission(): boolean
	for t = Config.INTERMISSION_TIME, 1, -1 do
		local count = #readyPlayers()
		if count < Config.MIN_PLAYERS then
			setStatus(`Waiting for players ({count}/{Config.MIN_PLAYERS})`)
			return false
		end
		setStatus(`Round starts in {t}`)
		task.wait(1)
	end
	return #readyPlayers() >= Config.MIN_PLAYERS
end

local function shuffle<T>(list: { T }): { T }
	local rng = Random.new()
	for i = #list, 2, -1 do
		local j = rng:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

local function setFrozen(players: { Player }, frozen: boolean)
	for _, player in players do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			root.Anchored = frozen
		end
	end
end

local function runRound()
	local participants = shuffle(readyPlayers())
	while #participants > Config.MAX_PLAYERS do
		table.remove(participants)
	end

	local assignments = {}
	local activePlatforms = {}
	for i, player in participants do
		local platform = Arena.platforms[i]
		assignments[player] = platform
		table.insert(activePlatforms, platform)
		local character = player.Character :: Model
		character:PivotTo(Arena.standCFrame(platform))
	end
	-- Unused platforms stay down for the round.
	for i = #participants + 1, #Arena.platforms do
		task.spawn(Arena.dropPlatform, Arena.platforms[i])
	end

	LoadService.startRound(assignments)
	roundActive = true
	setFrozen(participants, true)
	for t = Config.PRE_ROUND_COUNTDOWN, 1, -1 do
		setStatus(`Clear your platform! {t}`)
		task.wait(1)
	end
	setFrozen(participants, false)
	setStatus("GO!")
	DebrisService.startRound(activePlatforms)

	-- Solo test rounds end when the lone player is out; otherwise last one standing.
	local endAt = if #participants > 1 then 1 else 0
	while LoadService.aliveCount() > endAt do
		task.wait(0.2)
	end
	roundActive = false

	local winner = LoadService.alivePlayers()[1]
	setStatus(if winner then `{winner.DisplayName} wins!` else "Nobody survived!")
	-- Confetti + winner camera on every client; a slot of 0 means nobody won.
	local winnerPlatform = winner and LoadService.platformOf(winner)
	if winner and winnerPlatform then
		effectsRemote:FireAllClients("Win", winnerPlatform.topCFrame.Position, winnerPlatform.slot, winner.DisplayName)
	else
		effectsRemote:FireAllClients("Win", Config.ARENA_CENTER, 0, "")
	end
	ThrowService.releaseAll()
	DebrisService.stopRound()
	task.wait(Config.POST_ROUND_TIME)

	LoadService.reset()
	for _, platform in Arena.platforms do
		task.spawn(Arena.resetPlatform, platform)
	end
	for _, player in participants do
		if player.Parent == Players then
			task.spawn(spawnInHub, player)
		end
	end
end

while true do
	if intermission() then
		runRound()
	else
		task.wait(1)
	end
end

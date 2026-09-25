--!strict
-- Single place that defines every RemoteEvent. The server creates them; clients
-- wait for them.
--
--   ThrowDebris  client -> server  (aimPoint: Vector3)
--   Knockback    server -> client  (velocity: Vector3, stunTime: number)
--   Effects      server -> all     (kind: string, position: Vector3, slot: number, extra: any?)
--                kinds: "Land"  a piece started counting on platform `slot`
--                       "Crush" platform `slot` was crushed
--                       "Win"   round over; extra = winner display name ("" if nobody)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "DebrisClearRemotes"
local NAMES = { "ThrowDebris", "Knockback", "Effects" }

local Remotes = {}

local function getFolder(): Folder
	if RunService:IsServer() then
		local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME) :: Folder?
		if not folder then
			local created = Instance.new("Folder")
			created.Name = FOLDER_NAME
			for _, name in NAMES do
				local remote = Instance.new("RemoteEvent")
				remote.Name = name
				remote.Parent = created
			end
			created.Parent = ReplicatedStorage
			folder = created
		end
		return folder :: Folder
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
end

function Remotes.get(name: string): RemoteEvent
	return getFolder():WaitForChild(name) :: RemoteEvent
end

return Remotes

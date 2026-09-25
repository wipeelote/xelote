--!strict
-- Round status banner. Pickup/throw UI lives in InteractionController.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Hud = {}

function Hud.start()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "DebrisClearHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.AnchorPoint = Vector2.new(0.5, 0)
	status.Position = UDim2.new(0.5, 0, 0, 48)
	status.Size = UDim2.new(0.6, 0, 0, 40)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.GothamBlack
	status.TextScaled = true
	status.TextColor3 = Color3.new(1, 1, 1)
	status.TextStrokeTransparency = 0.3
	status.Parent = gui

	gui.Parent = player:WaitForChild("PlayerGui")

	local function refreshStatus()
		status.Text = (ReplicatedStorage:GetAttribute("DebrisClearStatus") :: string?) or ""
	end
	ReplicatedStorage:GetAttributeChangedSignal("DebrisClearStatus"):Connect(refreshStatus)
	refreshStatus()
end

return Hud

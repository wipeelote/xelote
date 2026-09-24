--!strict
-- Round status banner, throw hint, and a crosshair for non-mouse aiming.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

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

	local hint = status:Clone()
	hint.Name = "Hint"
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -40)
	hint.Size = UDim2.new(0.5, 0, 0, 28)
	hint.Font = Enum.Font.GothamBold
	hint.Text = "Holding debris: click / R2 to throw"
	hint.Visible = false
	hint.Parent = gui

	local crosshair = Instance.new("Frame")
	crosshair.Name = "Crosshair"
	crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
	crosshair.Position = UDim2.fromScale(0.5, 0.5)
	crosshair.Size = UDim2.fromOffset(8, 8)
	crosshair.BackgroundColor3 = Color3.new(1, 1, 1)
	crosshair.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = crosshair
	crosshair.Parent = gui

	gui.Parent = player:WaitForChild("PlayerGui")

	local function refreshStatus()
		status.Text = (ReplicatedStorage:GetAttribute("DebrisClearStatus") :: string?) or ""
	end
	local function refreshHolding()
		local holdingDebris = player:GetAttribute("HoldingDebris") == true
		hint.Visible = holdingDebris
		-- Mouse throws aim at the cursor; touch and gamepad aim at screen center.
		crosshair.Visible = holdingDebris and not UserInputService.MouseEnabled
	end
	ReplicatedStorage:GetAttributeChangedSignal("DebrisClearStatus"):Connect(refreshStatus)
	player:GetAttributeChangedSignal("HoldingDebris"):Connect(refreshHolding)
	refreshStatus()
	refreshHolding()
end

return Hud

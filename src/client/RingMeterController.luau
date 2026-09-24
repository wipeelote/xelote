--!strict
-- Animates each platform's ring meter from the server-replicated "Load"
-- attribute. The ring shows remaining capacity and drains as load rises.
--
-- Each half of the ring is a full ring clipped to half the circle, with a
-- UIGradient that is opaque on one side of a line through the center. For a
-- displayed fraction p (1 = full, 0 = empty, clockwise from 12 o'clock):
--   Right half rotation = clamp(p, 0, 0.5) * 360
--   Left  half rotation = clamp(p, 0.5, 1) * 360

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("DebrisClear")
local Config = require(Shared.Config)

local PLATFORM_TAG = "DebrisClearPlatform"

local RingMeterController = {}

local function colorOf(guiObject: GuiObject): (Color3) -> ()
	local stroke = guiObject:FindFirstChildOfClass("UIStroke")
	if stroke then
		return function(c)
			stroke.Color = c
		end
	end
	return function(c)
		(guiObject :: ImageLabel).ImageColor3 = c
	end
end

local function bind(model: Instance)
	local meter = model:WaitForChild("Meter", 10)
	local gui = meter and meter:WaitForChild("RingMeter", 10)
	local root = gui and gui:WaitForChild("Root", 10)
	if not root then
		return
	end
	local leftFill = root:WaitForChild("Left"):WaitForChild("Fill") :: GuiObject
	local rightFill = root:WaitForChild("Right"):WaitForChild("Fill") :: GuiObject
	local leftSweep = leftFill:FindFirstChild("Sweep", true) :: UIGradient
	local rightSweep = rightFill:FindFirstChild("Sweep", true) :: UIGradient
	local valueLabel = root:WaitForChild("Value") :: TextLabel
	local ownerLabel = root:WaitForChild("Owner") :: TextLabel
	local setLeftColor, setRightColor = colorOf(leftFill), colorOf(rightFill)

	local shown = Instance.new("NumberValue")
	shown.Value = 1

	local function render(p: number)
		rightSweep.Rotation = math.clamp(p, 0, 0.5) * 360
		leftSweep.Rotation = math.clamp(p, 0.5, 1) * 360
		local color = Config.RING_COLOR_DANGER:Lerp(Config.RING_COLOR_SAFE, p)
		setLeftColor(color)
		setRightColor(color)
	end
	shown.Changed:Connect(render)

	local function refresh()
		local load = (model:GetAttribute("Load") :: number?) or 0
		local capacity = (model:GetAttribute("Capacity") :: number?) or Config.PLATFORM_CAPACITY
		local remaining = 1 - math.clamp(load / capacity, 0, 1)
		valueLabel.Text = `{load} / {capacity}`
		TweenService:Create(
			shown,
			TweenInfo.new(Config.RING_TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Value = remaining }
		):Play()
	end
	local function refreshOwner()
		local name = (model:GetAttribute("OwnerName") :: string?) or ""
		if model:GetAttribute("Eliminated") then
			name = if name ~= "" then `{name} - OUT` else "OUT"
		end
		ownerLabel.Text = name
	end

	model:GetAttributeChangedSignal("Load"):Connect(refresh)
	model:GetAttributeChangedSignal("Capacity"):Connect(refresh)
	model:GetAttributeChangedSignal("OwnerName"):Connect(refreshOwner)
	model:GetAttributeChangedSignal("Eliminated"):Connect(refreshOwner)
	render(1)
	refresh()
	refreshOwner()
end

function RingMeterController.start()
	CollectionService:GetInstanceAddedSignal(PLATFORM_TAG):Connect(function(model)
		task.spawn(bind, model)
	end)
	for _, model in CollectionService:GetTagged(PLATFORM_TAG) do
		task.spawn(bind, model)
	end
end

return RingMeterController

--!strict
-- Animates each platform's ring meter from the server-replicated "Load"
-- attribute. The ring shows remaining capacity and drains as load rises.
--
-- Each half of the ring is a full ring clipped to half the circle, with a
-- UIGradient that is opaque on one side of a line through the center. For a
-- displayed fraction p (1 = full, 0 = empty, clockwise from 12 o'clock):
--   Right half rotation = clamp(p, 0, 0.5) * 360
--   Left  half rotation = clamp(p, 0.5, 1) * 360
--
-- Rival platforms also get a local BillboardGui above the deck (owner name and
-- a load-used bar) driven by the same tween, hidden for our own platform.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("DebrisClear")
local Config = require(Shared.Config)

type Billboard = { gui: BillboardGui, owner: TextLabel, fill: Frame, value: TextLabel }

local PLATFORM_TAG = "DebrisClearPlatform"
local BILLBOARD_SIZE = UDim2.fromOffset(180, 52)
local BILLBOARD_NAME_HEIGHT = 24 -- px; the bar takes the rest
local BILLBOARD_BAR_HEIGHT = 18
local BILLBOARD_BAR_INSET = 10 -- px each side
local BILLBOARD_TRACK_COLOR = Color3.fromRGB(30, 30, 35)

local RingMeterController = {}

local player = Players.LocalPlayer

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

local function roundedCorner(parent: Instance)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = parent
end

-- Owner name over a "load used" bar, parented to PlayerGui so it is local.
local function buildBillboard(meter: Instance, slot: number): Billboard
	local gui = Instance.new("BillboardGui")
	gui.Name = `LoadBillboard{slot}`
	gui.Adornee = meter
	gui.Size = BILLBOARD_SIZE
	gui.StudsOffsetWorldSpace = Vector3.new(0, Config.BILLBOARD_HEIGHT, 0)
	gui.MaxDistance = Config.BILLBOARD_MAX_DISTANCE
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	gui.Enabled = false

	local owner = Instance.new("TextLabel")
	owner.Name = "Owner"
	owner.BackgroundTransparency = 1
	owner.Size = UDim2.new(1, 0, 0, BILLBOARD_NAME_HEIGHT)
	owner.Font = Enum.Font.GothamBold
	owner.TextScaled = true
	owner.TextColor3 = Color3.new(1, 1, 1)
	owner.TextStrokeTransparency = 0.4
	owner.Text = ""
	owner.Parent = gui

	-- Bar centered in the space under the name.
	local gap = (BILLBOARD_SIZE.Y.Offset - BILLBOARD_NAME_HEIGHT - BILLBOARD_BAR_HEIGHT) / 2
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -gap)
	bar.Size = UDim2.new(1, -2 * BILLBOARD_BAR_INSET, 0, BILLBOARD_BAR_HEIGHT)
	bar.BackgroundColor3 = BILLBOARD_TRACK_COLOR
	bar.BackgroundTransparency = 0.2
	bar.BorderSizePixel = 0
	roundedCorner(bar)
	bar.Parent = gui

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Config.RING_COLOR_SAFE
	fill.BorderSizePixel = 0
	roundedCorner(fill)
	fill.Parent = bar

	local value = Instance.new("TextLabel")
	value.Name = "Value"
	value.BackgroundTransparency = 1
	value.Size = UDim2.fromScale(1, 1)
	value.Font = Enum.Font.GothamBlack
	value.TextScaled = true
	value.TextColor3 = Color3.new(1, 1, 1)
	value.TextStrokeTransparency = 0.4
	value.ZIndex = 2
	value.Parent = bar

	gui.Parent = player:WaitForChild("PlayerGui")
	return { gui = gui, owner = owner, fill = fill, value = value }
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

	local slot = (model:GetAttribute("Slot") :: number?) or 0
	local billboard: Billboard? = if Config.BILLBOARD_ENABLED then buildBillboard(meter :: Instance, slot) else nil

	local shown = Instance.new("NumberValue")
	shown.Value = 1

	local function render(p: number)
		rightSweep.Rotation = math.clamp(p, 0, 0.5) * 360
		leftSweep.Rotation = math.clamp(p, 0.5, 1) * 360
		local color = Config.RING_COLOR_DANGER:Lerp(Config.RING_COLOR_SAFE, p)
		setLeftColor(color)
		setRightColor(color)
		if billboard then
			-- The bar fills as the ring drains.
			billboard.fill.Size = UDim2.fromScale(1 - p, 1)
			billboard.fill.BackgroundColor3 = color
		end
	end
	shown.Changed:Connect(render)

	local function refresh()
		local load = (model:GetAttribute("Load") :: number?) or 0
		local capacity = (model:GetAttribute("Capacity") :: number?) or Config.PLATFORM_CAPACITY
		local remaining = 1 - math.clamp(load / capacity, 0, 1)
		valueLabel.Text = `{load} / {capacity}`
		if billboard then
			billboard.value.Text = string.format("%d / %d", math.round(load), math.round(capacity))
		end
		TweenService:Create(
			shown,
			TweenInfo.new(Config.RING_TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Value = remaining }
		):Play()
	end
	local function refreshOwner()
		local name = (model:GetAttribute("OwnerName") :: string?) or ""
		local eliminated = model:GetAttribute("Eliminated") == true
		if billboard then
			-- Rivals only: an owned, live platform that isn't ours.
			billboard.owner.Text = name
			billboard.gui.Enabled = name ~= "" and not eliminated and player:GetAttribute("PlatformSlot") ~= slot
		end
		if eliminated then
			name = if name ~= "" then `{name} - OUT` else "OUT"
		end
		ownerLabel.Text = name
	end

	model:GetAttributeChangedSignal("Load"):Connect(refresh)
	model:GetAttributeChangedSignal("Capacity"):Connect(refresh)
	model:GetAttributeChangedSignal("OwnerName"):Connect(refreshOwner)
	model:GetAttributeChangedSignal("Eliminated"):Connect(refreshOwner)
	if billboard then
		player:GetAttributeChangedSignal("PlatformSlot"):Connect(refreshOwner)
	end
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

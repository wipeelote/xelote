--!strict
-- Visual dressing for a hex platform (rim, lights, slot number). Interim: none.
-- Everything added here is parented to `model` and rides the piston drop.

local PlatformDressing = {}

function PlatformDressing.dress(model: Model, topCFrame: CFrame, color: Color3, slot: number)
	local _unused = { model :: any, topCFrame :: any, color :: any, slot :: any }
end

return PlatformDressing

--!strict
-- Debris Clear client entry point.

local Hud = require(script.Parent.Hud)
local RingMeterController = require(script.Parent.RingMeterController)
local ThrowController = require(script.Parent.ThrowController)
local DebrisVisuals = require(script.Parent.DebrisVisuals)

Hud.start()
RingMeterController.start()
ThrowController.start()
task.spawn(DebrisVisuals.start) -- may yield while building the mesh

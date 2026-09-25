--!strict
-- Debris Clear client entry point.

local Hud = require(script.Parent.Hud)
local RingMeterController = require(script.Parent.RingMeterController)
local InteractionController = require(script.Parent.InteractionController)
local DebrisVisuals = require(script.Parent.DebrisVisuals)

Hud.start()
RingMeterController.start()
InteractionController.start()
task.spawn(DebrisVisuals.start) -- may yield while building the mesh

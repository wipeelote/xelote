--!strict
-- Lighting service settings for the NEON PIT set: a midnight sky, violet
-- ambient so rivals never turn into silhouettes, a violet Atmosphere for
-- depth, and post-processing that lets only Neon and lava bloom. No parts.
--
-- Lighting.Technology cannot be set from a script: set it to Future by hand
-- in Studio (ShadowMap is an acceptable fallback; the rig spots still light
-- the decks, only the glossy specular pools on the black surfaces are lost).
-- No Sky instance is created (a skybox needs asset ids); the default
-- procedural night sky with stars and a moon is the intended look.

local LightingService = game:GetService("Lighting")

local Lighting = {}

type Props = { [string]: any }

local TUNING = {
	-- Lighting service properties (brief 6.1).
	LIGHTING = { -- PLACEHOLDER
		ClockTime = 1.5, -- midnight; default procedural night sky with stars
		GeographicLatitude = 41,
		Brightness = 0.6,
		Ambient = Color3.fromRGB(30, 22, 55),
		OutdoorAmbient = Color3.fromRGB(56, 44, 96), -- raised so rivals read on ShadowMap too
		ColorShift_Top = Color3.fromRGB(80, 40, 140),
		ColorShift_Bottom = Color3.fromRGB(20, 10, 40),
		EnvironmentDiffuseScale = 0.25,
		EnvironmentSpecularScale = 0.75,
		GlobalShadows = true,
		ShadowSoftness = 0.2,
		ExposureCompensation = 0.15,
		FogEnd = 100000, -- fog off; the Atmosphere handles depth
	} :: Props,
	-- Violet horizon glow; the backdrop at 140 studs stays crisp.
	ATMOSPHERE_NAME = "DebrisClearAtmosphere",
	ATMOSPHERE = { -- PLACEHOLDER
		Density = 0.3,
		Offset = 0.2,
		Color = Color3.fromRGB(120, 40, 170),
		Decay = Color3.fromRGB(30, 10, 70),
		Glare = 0.3,
		Haze = 2.2,
	} :: Props,
	-- Threshold 1.0: only Neon and the lava bloom; the dim LavaBase never
	-- whites out. If the lava core still blows out at graphics 10, darken
	-- LavaBase first, then raise Threshold to 1.05.
	BLOOM_NAME = "DebrisClearBloom",
	BLOOM = { -- PLACEHOLDER
		Enabled = true,
		Intensity = 0.7,
		Size = 28,
		Threshold = 1.0,
	} :: Props,
	COLOR_CORRECTION_NAME = "DebrisClearColorCorrection",
	COLOR_CORRECTION = { -- PLACEHOLDER
		Enabled = true,
		Brightness = 0.02,
		Contrast = 0.15,
		Saturation = 0.25,
		TintColor = Color3.fromRGB(250, 240, 255),
	} :: Props,
	-- The brief wants no SunRays and no DepthOfField. Any other post effect
	-- already sitting in Lighting (Studio's defaults, an older build) is
	-- switched off rather than destroyed, so the look is the same every run.
	DISABLE_OTHER_POST_EFFECTS = true, -- PLACEHOLDER
}

local function apply(instance: Instance, props: Props)
	for k, v in props do
		(instance :: any)[k] = v
	end
end

-- Child of Lighting with this name and class, created if missing (so apply()
-- can run again in Studio without stacking duplicate effects).
local function findOrCreate(className: string, name: string): Instance
	local existing = LightingService:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end
	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = LightingService
	return instance
end

function Lighting.apply()
	apply(LightingService, TUNING.LIGHTING)

	local atmosphere = findOrCreate("Atmosphere", TUNING.ATMOSPHERE_NAME)
	apply(atmosphere, TUNING.ATMOSPHERE)

	local bloom = findOrCreate("BloomEffect", TUNING.BLOOM_NAME)
	apply(bloom, TUNING.BLOOM)

	local colorCorrection = findOrCreate("ColorCorrectionEffect", TUNING.COLOR_CORRECTION_NAME)
	apply(colorCorrection, TUNING.COLOR_CORRECTION)

	if TUNING.DISABLE_OTHER_POST_EFFECTS then
		for _, child in LightingService:GetChildren() do
			if child:IsA("PostEffect") and child ~= bloom and child ~= colorCorrection then
				child.Enabled = false
			end
		end
	end
end

return Lighting

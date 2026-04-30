--!strict
--
-- Pure calculation module for wave spawn timing.
-- No services, no Workspace access, no globals -- safe to require from any script.
--
-- This turn's responsibility: grunt spawn interval resolution + evaluation.
-- Elite / boss / enemy-type rules are future slots (see WaveService for call sites
-- that still live inline).

local SpawnRules = {}

-- Hard fallbacks -- used ONLY when neither the per-stage spawnProfile nor the
-- global GameConfig provides a positive value. These match the defaults that
-- used to live inline in WaveService.init so behavior is preserved bit-for-bit
-- when GameConfig is missing the ramp keys.
local DEFAULT_RAMP_EVERY_SECONDS = 30
local DEFAULT_RAMP_MULTIPLIER = 1.3
local DEFAULT_RAMP_AFTER_MIN = 0.2

export type GruntTuning = {
	intervalStart: number,
	intervalEnd: number,
	rampEvery: number,
	rampMult: number,
	rampAfterMin: number,
}

local function pickPositive(primary: any, secondary: any, fallback: number): number
	if type(primary) == "number" and primary > 0 then
		return primary
	end
	if type(secondary) == "number" and secondary > 0 then
		return secondary
	end
	return fallback
end

--- Resolve the five grunt-tuning numbers from (per-stage spawnProfile) > (GameConfig) > (module default).
--- spawnProfile may be nil. All returned numbers are guaranteed positive.
function SpawnRules.resolveGruntTuning(gameConfig, spawnProfile): GruntTuning
	local prof = spawnProfile

	local intervalStart = pickPositive(
		prof and prof.GruntIntervalStart,
		gameConfig.WaveGruntSpawnIntervalStart,
		0
	)
	local intervalEnd = pickPositive(
		prof and prof.GruntIntervalEnd,
		gameConfig.WaveGruntSpawnIntervalEnd,
		0
	)

	-- Ramp keys accept a stage-level override slot (prof.Ramp*) even though
	-- StageData doesn't currently emit them -- forward compatible, no-op today.
	local rampEvery = pickPositive(
		prof and prof.RampEverySeconds,
		gameConfig.WaveGruntSpawnIntervalRampEverySeconds,
		DEFAULT_RAMP_EVERY_SECONDS
	)
	local rampMult = pickPositive(
		prof and prof.RampMultiplier,
		gameConfig.WaveGruntSpawnIntervalRampMultiplier,
		DEFAULT_RAMP_MULTIPLIER
	)
	local rampAfterMin = pickPositive(
		prof and prof.RampAfterMin,
		gameConfig.WaveGruntSpawnIntervalAfterRampMin,
		DEFAULT_RAMP_AFTER_MIN
	)

	return {
		intervalStart = intervalStart,
		intervalEnd = intervalEnd,
		rampEvery = rampEvery,
		rampMult = rampMult,
		rampAfterMin = rampAfterMin,
	}
end

--- Compute effective grunt spawn interval (seconds) for the current session time.
--- Formula mirrors the inline math that used to live in WaveService Heartbeat:
---   t = min(elapsed / sessionLength, 1)
---   base = intervalStart - t * (intervalStart - intervalEnd)
---   periods = floor(elapsed / rampEvery)
---   effective = max(base / (rampMult ^ periods), rampAfterMin)
function SpawnRules.computeGruntIntervalSeconds(
	elapsed: number,
	sessionLength: number,
	tuning: GruntTuning
): number
	local t = 0
	if sessionLength > 0 then
		t = elapsed / sessionLength
	end
	if t > 1 then
		t = 1
	end

	local base = tuning.intervalStart - t * (tuning.intervalStart - tuning.intervalEnd)

	local periods = 0
	if tuning.rampEvery > 0 then
		periods = math.floor(elapsed / tuning.rampEvery)
	end

	local eff = base / (tuning.rampMult ^ periods)
	if eff < tuning.rampAfterMin then
		eff = tuning.rampAfterMin
	end

	return eff
end

return SpawnRules

-- Applies baseline class modifiers after relic modifiers. Does not touch BuildTag detection.

local ClassEffectData = require(script.Parent:WaitForChild("ClassEffectData"))

local ClassEffectApplicator = {}

local MIN_ATTACK_INTERVAL_SECONDS = 0.12

local function isActiveClass(detectedClass: any, expected: string): boolean
	return type(detectedClass) == "string" and detectedClass == expected
end

local function clampAttackIntervalSeconds(interval: number): number
	if type(interval) ~= "number" or interval <= 0 then
		return MIN_ATTACK_INTERVAL_SECONDS
	end
	return math.max(MIN_ATTACK_INTERVAL_SECONDS, interval)
end

local function shallowCopyTwoHandedEffective(effective: any): any
	if type(effective) ~= "table" then
		return effective
	end
	local out = {
		AttackIntervalSeconds = effective.AttackIntervalSeconds,
		Meta = effective.Meta,
	}
	local sweep = effective.Sweep
	if type(sweep) == "table" then
		out.Sweep = {
			BaseDamage = sweep.BaseDamage,
			RangeStuds = sweep.RangeStuds,
			AngleDeg = sweep.AngleDeg,
			TargetLimit = sweep.TargetLimit,
		}
	else
		out.Sweep = sweep
	end
	return out
end

local function shallowCopySpearEffective(effective: any): any
	if type(effective) ~= "table" then
		return effective
	end
	local out = {
		AttackIntervalSeconds = effective.AttackIntervalSeconds,
		Meta = effective.Meta,
	}
	local thrust = effective.Thrust
	if type(thrust) == "table" then
		out.Thrust = {
			BaseDamage = thrust.BaseDamage,
			RangeStuds = thrust.RangeStuds,
			WidthStuds = thrust.WidthStuds,
			TargetLimit = thrust.TargetLimit,
		}
	else
		out.Thrust = thrust
	end
	return out
end

local function shallowCopySwordShieldEffective(effective: any): any
	if type(effective) ~= "table" then
		return effective
	end
	local out = {
		AttackIntervalSeconds = effective.AttackIntervalSeconds,
	}
	local sweep = effective.Sweep
	if type(sweep) == "table" then
		out.Sweep = {
			RangeStuds = sweep.RangeStuds,
			AngleDeg = sweep.AngleDeg,
			BaseDamage = sweep.BaseDamage,
		}
	else
		out.Sweep = sweep
	end
	local thrust = effective.Thrust
	if type(thrust) == "table" then
		out.Thrust = {
			RangeStuds = thrust.RangeStuds,
			WidthStuds = thrust.WidthStuds,
			AngleDeg = thrust.AngleDeg,
			BaseDamage = thrust.BaseDamage,
		}
	else
		out.Thrust = thrust
	end
	return out
end

function ClassEffectApplicator.buildHudClassEffects(detectedClass: string?): {
	ActiveClass: string,
	damageTakenMultiplier: number,
	sweepBaseDamageMul: number,
	attackIntervalSecondsMul: number,
}
	local activeClass = "none"
	local damageTaken = ClassEffectData.DefaultDamageTakenMultiplier
	local sweepMul = ClassEffectData.DefaultSweepBaseDamageMultiplier
	local intervalMul = ClassEffectData.DefaultAttackIntervalSecondsMultiplier

	if detectedClass == "Guardian" then
		activeClass = "Guardian"
		damageTaken = ClassEffectData.GuardianDamageTakenMultiplier
	elseif detectedClass == "Slayer" then
		activeClass = "Slayer"
		sweepMul = ClassEffectData.SlayerSweepBaseDamageMultiplier
	elseif detectedClass == "Lancer" then
		activeClass = "Lancer"
		intervalMul = ClassEffectData.LancerAttackIntervalSecondsMultiplier
	end

	return {
		ActiveClass = activeClass,
		damageTakenMultiplier = damageTaken,
		sweepBaseDamageMul = sweepMul,
		attackIntervalSecondsMul = intervalMul,
	}
end

function ClassEffectApplicator.applyToSpearEffective(effective: any, detectedClass: string?): any
	if not isActiveClass(detectedClass, "Lancer") or type(effective) ~= "table" then
		return effective
	end
	local out = shallowCopySpearEffective(effective)
	local interval = out.AttackIntervalSeconds
	if type(interval) == "number" and interval > 0 then
		out.AttackIntervalSeconds = clampAttackIntervalSeconds(
			interval * ClassEffectData.LancerAttackIntervalSecondsMultiplier
		)
	end
	return out
end

function ClassEffectApplicator.applyToTwoHandedSwordEffective(effective: any, detectedClass: string?): any
	if not isActiveClass(detectedClass, "Slayer") or type(effective) ~= "table" then
		return effective
	end
	local out = shallowCopyTwoHandedEffective(effective)
	local sweep = out.Sweep
	if type(sweep) == "table" and type(sweep.BaseDamage) == "number" and sweep.BaseDamage > 0 then
		sweep.BaseDamage = sweep.BaseDamage * ClassEffectData.SlayerSweepBaseDamageMultiplier
	end
	return out
end

function ClassEffectApplicator.applyToSwordShieldEffective(effective: any, detectedClass: string?): any
	if not isActiveClass(detectedClass, "Slayer") or type(effective) ~= "table" then
		return effective
	end
	local out = shallowCopySwordShieldEffective(effective)
	local sweep = out.Sweep
	if type(sweep) == "table" and type(sweep.BaseDamage) == "number" and sweep.BaseDamage > 0 then
		sweep.BaseDamage = sweep.BaseDamage * ClassEffectData.SlayerSweepBaseDamageMultiplier
	end
	return out
end

return ClassEffectApplicator
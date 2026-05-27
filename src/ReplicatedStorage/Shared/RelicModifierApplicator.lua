-- Applies RelicDefinitions modifiers to effective combat stats (Phase 3).
-- Does not apply combat by itself; no ProgressionService / RelicData dependency.

local RelicDefinitions = require(script.Parent:WaitForChild("RelicDefinitions"))

local RelicModifierApplicator = {}

local TH_WEAPON_TAG = "th"
local TH_ATTACK_TAG = "sweep"

local SPEAR_WEAPON_TAG = "sp"
local SPEAR_ATTACK_TAG = "thrust"

local SS_WEAPON_TAG = "ss"
local SS_ATTACK_TAG_SWEEP = "sweep"
local SS_ATTACK_TAG_THRUST = "thrust"

local STAT_FIELD_TH = {
	sweepBaseDamage = { sweep = true, key = "BaseDamage" },
	attackIntervalSeconds = { sweep = false, key = "AttackIntervalSeconds" },
}

local STAT_FIELD_SPEAR = {
	thrustBaseDamage = { thrust = true, key = "BaseDamage" },
	attackIntervalSeconds = { thrust = false, key = "AttackIntervalSeconds" },
}

local STAT_FIELD_SS = {
	sweepBaseDamage = { sweep = true, key = "BaseDamage" },
	thrustBaseDamage = { thrust = true, key = "BaseDamage" },
	attackIntervalSeconds = { weapon = true, key = "AttackIntervalSeconds" },
}

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
			BaseDamage = sweep.BaseDamage,
			RangeStuds = sweep.RangeStuds,
			AngleDeg = sweep.AngleDeg,
		}
	else
		out.Sweep = sweep
	end
	local thrust = effective.Thrust
	if type(thrust) == "table" then
		out.Thrust = {
			BaseDamage = thrust.BaseDamage,
			RangeStuds = thrust.RangeStuds,
			WidthStuds = thrust.WidthStuds,
			AngleDeg = thrust.AngleDeg,
		}
	else
		out.Thrust = thrust
	end
	return out
end

local function targetTagsMatch(modTarget: any, weaponTag: string, attackTag: string): boolean
	if type(modTarget) ~= "table" then
		return false
	end
	if modTarget.weaponTag ~= nil and modTarget.weaponTag ~= weaponTag then
		return false
	end
	if modTarget.attackTag ~= nil and modTarget.attackTag ~= attackTag then
		return false
	end
	return true
end

local function applyMulAdd(current: number, operation: string, value: number): number
	if operation == "mul" then
		return current * value
	end
	if operation == "add" then
		return current + value
	end
	return current
end

local function applyStatToTwoHandedEffective(effective: any, stat: string, operation: string, value: number): boolean
	local mapping = STAT_FIELD_TH[stat]
	if mapping == nil then
		warn(string.format("[RelicModifierApplicator] unknown stat %q (skipped)", stat))
		return false
	end

	if mapping.sweep then
		if type(effective.Sweep) ~= "table" then
			warn("[RelicModifierApplicator] effective.Sweep missing (skipped)")
			return false
		end
		local cur = effective.Sweep[mapping.key]
		if type(cur) ~= "number" then
			warn(string.format("[RelicModifierApplicator] effective.Sweep.%s not a number (skipped)", mapping.key))
			return false
		end
		effective.Sweep[mapping.key] = applyMulAdd(cur, operation, value)
		return true
	end

	local cur = effective[mapping.key]
	if type(cur) ~= "number" then
		warn(string.format("[RelicModifierApplicator] effective.%s not a number (skipped)", mapping.key))
		return false
	end
	effective[mapping.key] = applyMulAdd(cur, operation, value)
	return true
end

local function applyStatToSpearEffective(effective: any, stat: string, operation: string, value: number): boolean
	local mapping = STAT_FIELD_SPEAR[stat]
	if mapping == nil then
		warn(string.format("[RelicModifierApplicator] unknown stat %q (skipped)", stat))
		return false
	end

	if mapping.thrust then
		if type(effective.Thrust) ~= "table" then
			warn("[RelicModifierApplicator] effective.Thrust missing (skipped)")
			return false
		end
		local cur = effective.Thrust[mapping.key]
		if type(cur) ~= "number" then
			warn(string.format("[RelicModifierApplicator] effective.Thrust.%s not a number (skipped)", mapping.key))
			return false
		end
		effective.Thrust[mapping.key] = applyMulAdd(cur, operation, value)
		return true
	end

	local cur = effective[mapping.key]
	if type(cur) ~= "number" then
		warn(string.format("[RelicModifierApplicator] effective.%s not a number (skipped)", mapping.key))
		return false
	end
	effective[mapping.key] = applyMulAdd(cur, operation, value)
	return true
end

local function applyStatToSwordShieldEffective(effective: any, stat: string, operation: string, value: number): boolean
	local mapping = STAT_FIELD_SS[stat]
	if mapping == nil then
		warn(string.format("[RelicModifierApplicator] unknown stat %q (skipped)", stat))
		return false
	end

	if mapping.sweep then
		if type(effective.Sweep) ~= "table" then
			warn("[RelicModifierApplicator] effective.Sweep missing (skipped)")
			return false
		end
		local cur = effective.Sweep[mapping.key]
		if type(cur) ~= "number" then
			warn(string.format("[RelicModifierApplicator] effective.Sweep.%s not a number (skipped)", mapping.key))
			return false
		end
		effective.Sweep[mapping.key] = applyMulAdd(cur, operation, value)
		return true
	end

	if mapping.thrust then
		if type(effective.Thrust) ~= "table" then
			warn("[RelicModifierApplicator] effective.Thrust missing (skipped)")
			return false
		end
		local cur = effective.Thrust[mapping.key]
		if type(cur) ~= "number" then
			warn(string.format("[RelicModifierApplicator] effective.Thrust.%s not a number (skipped)", mapping.key))
			return false
		end
		effective.Thrust[mapping.key] = applyMulAdd(cur, operation, value)
		return true
	end

	local cur = effective[mapping.key]
	if type(cur) ~= "number" then
		warn(string.format("[RelicModifierApplicator] effective.%s not a number (skipped)", mapping.key))
		return false
	end
	effective[mapping.key] = applyMulAdd(cur, operation, value)
	return true
end

local function shouldApplySwordShieldModifier(mod: any, stat: string): (boolean, string?)
	if type(mod) ~= "table" or type(mod.targetTags) ~= "table" then
		return false, nil
	end
	local modAttackTag = mod.targetTags.attackTag
	if stat == "attackIntervalSeconds" then
		if modAttackTag ~= nil then
			return false, nil
		end
		if mod.targetTags.weaponTag ~= nil and mod.targetTags.weaponTag ~= SS_WEAPON_TAG then
			return false, nil
		end
		return true, ""
	end
	if stat == "sweepBaseDamage" then
		return modAttackTag == nil or modAttackTag == SS_ATTACK_TAG_SWEEP, SS_ATTACK_TAG_SWEEP
	end
	if stat == "thrustBaseDamage" then
		return modAttackTag == nil or modAttackTag == SS_ATTACK_TAG_THRUST, SS_ATTACK_TAG_THRUST
	end
	return false, nil
end

--- Applies Phase 3 relic modifiers for TwoHandedSword sweep.
--- activeRelicIds nil or empty → no-op (shallow copy, same numeric values).
function RelicModifierApplicator.applyToTwoHandedSwordEffective(
	effective: any,
	activeRelicIds: { string }?,
	ctx: any?
): any
	if type(effective) ~= "table" then
		return effective
	end
	if type(activeRelicIds) ~= "table" or #activeRelicIds == 0 then
		return shallowCopyTwoHandedEffective(effective)
	end

	local weaponTag = TH_WEAPON_TAG
	local attackTag = TH_ATTACK_TAG
	if type(ctx) == "table" then
		if type(ctx.weaponTag) == "string" and ctx.weaponTag ~= "" then
			weaponTag = ctx.weaponTag
		end
		if type(ctx.attackTag) == "string" and ctx.attackTag ~= "" then
			attackTag = ctx.attackTag
		end
	end

	local out = shallowCopyTwoHandedEffective(effective)

	for _, relicId in ipairs(activeRelicIds) do
		if type(relicId) ~= "string" or relicId == "" then
			continue
		end
		local def = RelicDefinitions.getDefinition(relicId)
		if type(def) ~= "table" then
			warn(string.format("[RelicModifierApplicator] unknown relic id %q (skipped)", relicId))
			continue
		end
		local modifiers = def.modifiers
		if type(modifiers) ~= "table" then
			continue
		end
		for _, mod in ipairs(modifiers) do
			if type(mod) ~= "table" then
				continue
			end
			if mod.requiresTuning == true then
				warn(string.format("[RelicModifierApplicator] %s: modifier requires tuning (skipped)", relicId))
				continue
			end
			if type(mod.value) ~= "number" then
				warn(string.format("[RelicModifierApplicator] %s: modifier value not a number (skipped)", relicId))
				continue
			end
			if not targetTagsMatch(mod.targetTags, weaponTag, attackTag) then
				continue
			end
			local stat = mod.stat
			local op = mod.operation
			if type(stat) ~= "string" or RelicDefinitions.ALLOWED_STATS[stat] ~= true then
				warn(string.format("[RelicModifierApplicator] %s: invalid stat %s (skipped)", relicId, tostring(stat)))
				continue
			end
			if type(op) ~= "string" or RelicDefinitions.ALLOWED_OPERATIONS[op] ~= true then
				warn(
					string.format(
						"[RelicModifierApplicator] %s: invalid operation %s (skipped)",
						relicId,
						tostring(op)
					)
				)
				continue
			end
			applyStatToTwoHandedEffective(out, stat, op, mod.value)
		end
	end

	return out
end

--- Applies Phase 3 relic modifiers for Spear thrust.
--- activeRelicIds nil or empty → no-op (shallow copy, same numeric values).
function RelicModifierApplicator.applyToSpearEffective(
	effective: any,
	activeRelicIds: { string }?,
	ctx: any?
): any
	if type(effective) ~= "table" then
		return effective
	end
	if type(activeRelicIds) ~= "table" or #activeRelicIds == 0 then
		return shallowCopySpearEffective(effective)
	end

	local weaponTag = SPEAR_WEAPON_TAG
	local attackTag = SPEAR_ATTACK_TAG
	if type(ctx) == "table" then
		if type(ctx.weaponTag) == "string" and ctx.weaponTag ~= "" then
			weaponTag = ctx.weaponTag
		end
		if type(ctx.attackTag) == "string" and ctx.attackTag ~= "" then
			attackTag = ctx.attackTag
		end
	end

	local out = shallowCopySpearEffective(effective)

	for _, relicId in ipairs(activeRelicIds) do
		if type(relicId) ~= "string" or relicId == "" then
			continue
		end
		local def = RelicDefinitions.getDefinition(relicId)
		if type(def) ~= "table" then
			warn(string.format("[RelicModifierApplicator] unknown relic id %q (skipped)", relicId))
			continue
		end
		local modifiers = def.modifiers
		if type(modifiers) ~= "table" then
			continue
		end
		for _, mod in ipairs(modifiers) do
			if type(mod) ~= "table" then
				continue
			end
			if mod.requiresTuning == true then
				warn(string.format("[RelicModifierApplicator] %s: modifier requires tuning (skipped)", relicId))
				continue
			end
			if type(mod.value) ~= "number" then
				warn(string.format("[RelicModifierApplicator] %s: modifier value not a number (skipped)", relicId))
				continue
			end
			if not targetTagsMatch(mod.targetTags, weaponTag, attackTag) then
				continue
			end
			local stat = mod.stat
			local op = mod.operation
			if type(stat) ~= "string" or RelicDefinitions.ALLOWED_STATS[stat] ~= true then
				warn(string.format("[RelicModifierApplicator] %s: invalid stat %s (skipped)", relicId, tostring(stat)))
				continue
			end
			if type(op) ~= "string" or RelicDefinitions.ALLOWED_OPERATIONS[op] ~= true then
				warn(
					string.format(
						"[RelicModifierApplicator] %s: invalid operation %s (skipped)",
						relicId,
						tostring(op)
					)
				)
				continue
			end
			applyStatToSpearEffective(out, stat, op, mod.value)
		end
	end

	return out
end

--- Applies Phase 3 relic modifiers for SwordShield sweep/thrust and weapon-wide interval.
--- activeRelicIds nil or empty → no-op (shallow copy, same numeric values).
function RelicModifierApplicator.applyToSwordShieldEffective(
	effective: any,
	activeRelicIds: { string }?,
	ctx: any?
): any
	if type(effective) ~= "table" then
		return effective
	end
	if type(activeRelicIds) ~= "table" or #activeRelicIds == 0 then
		return shallowCopySwordShieldEffective(effective)
	end

	local weaponTag = SS_WEAPON_TAG
	if type(ctx) == "table" and type(ctx.weaponTag) == "string" and ctx.weaponTag ~= "" then
		weaponTag = ctx.weaponTag
	end

	local out = shallowCopySwordShieldEffective(effective)

	for _, relicId in ipairs(activeRelicIds) do
		if type(relicId) ~= "string" or relicId == "" then
			continue
		end
		local def = RelicDefinitions.getDefinition(relicId)
		if type(def) ~= "table" then
			warn(string.format("[RelicModifierApplicator] unknown relic id %q (skipped)", relicId))
			continue
		end
		local modifiers = def.modifiers
		if type(modifiers) ~= "table" then
			continue
		end
		for _, mod in ipairs(modifiers) do
			if type(mod) ~= "table" then
				continue
			end
			if mod.requiresTuning == true then
				warn(string.format("[RelicModifierApplicator] %s: modifier requires tuning (skipped)", relicId))
				continue
			end
			if type(mod.value) ~= "number" then
				warn(string.format("[RelicModifierApplicator] %s: modifier value not a number (skipped)", relicId))
				continue
			end
			local stat = mod.stat
			local op = mod.operation
			if type(stat) ~= "string" or RelicDefinitions.ALLOWED_STATS[stat] ~= true then
				warn(string.format("[RelicModifierApplicator] %s: invalid stat %s (skipped)", relicId, tostring(stat)))
				continue
			end
			if type(op) ~= "string" or RelicDefinitions.ALLOWED_OPERATIONS[op] ~= true then
				warn(
					string.format(
						"[RelicModifierApplicator] %s: invalid operation %s (skipped)",
						relicId,
						tostring(op)
					)
				)
				continue
			end
			local ok, passAttackTag = shouldApplySwordShieldModifier(mod, stat)
			if not ok or passAttackTag == nil then
				continue
			end
			if not targetTagsMatch(mod.targetTags, weaponTag, passAttackTag) then
				continue
			end
			applyStatToSwordShieldEffective(out, stat, op, mod.value)
		end
	end

	return out
end

return RelicModifierApplicator

local RelicData = require(script.Parent:WaitForChild("RelicData"))

local UpgradeData = {

	Effects = {
		damage_up = {

			DamageBonusPerStack = 5,
		},
		attack_interval_down = {

			IntervalMultiplierPerStack = 0.95,
			MinAttackIntervalSeconds = 0.12,
		},
		attack_size_up = {
			RangeBonusStudsPerStack = 2,
		},
	},

	--- BasicMagic 레벨업 풀 (getEffectiveCombatStats 전용 Id)
	Choices = {
		{
			Id = "damage_up",
			Label = "공격 피해량 증가 (+5/스택)",
		},
		{
			Id = "attack_interval_down",
			Label = "공격 속도 5% 증가 (스택당)",
		},
		{
			Id = "attack_size_up",
			Label = "사거리 +2 스터드 (스택당)",
		},
	},

	--- SwordShield 전용 레벨업 풀 (BasicMagic 계산과 분리). 총 7개.
	SwordShieldChoices = {
		{ Id = "ss_common_damage", Label = "Attack Damage +10%" },
		{ Id = "ss_common_cooldown", Label = "Cooldown -8%" },
		{ Id = "ss_sweep_angle", Label = "Shield Sweep Angle +20°" },
		{ Id = "ss_sweep_damage", Label = "Shield Sweep Damage +15%" },
		{ Id = "ss_sweep_range", Label = "Shield Sweep Range +15%" },
		{ Id = "ss_thrust_damage", Label = "Sword Thrust Damage +20%" },
		{ Id = "ss_thrust_range", Label = "Sword Thrust Range +20%" },
	},
}

local function stackCount(upgrades, key: string): number
	local v = upgrades[key]
	if type(v) ~= "number" or v < 0 then
		return 0
	end
	return math.max(0, math.floor(v + 0.5))
end

function UpgradeData.getEffectiveCombatStats(gameConfig, upgrades)
	local fx = UpgradeData.Effects
	local damageStacks = upgrades.damage_up or 0
	local intervalStacks = upgrades.attack_interval_down or 0
	local rangeStacks = upgrades.attack_size_up or 0

	local damagePerHit = gameConfig.PlayerDamagePerHit + damageStacks * fx.damage_up.DamageBonusPerStack

	local intervalFx = fx.attack_interval_down
	local attackIntervalSeconds = gameConfig.PlayerBaseAttackIntervalSeconds
		* (intervalFx.IntervalMultiplierPerStack ^ intervalStacks)
	if attackIntervalSeconds < intervalFx.MinAttackIntervalSeconds then
		attackIntervalSeconds = intervalFx.MinAttackIntervalSeconds
	end

	local attackRangeStuds = gameConfig.PlayerAttackRangeStuds
		+ rangeStacks * fx.attack_size_up.RangeBonusStudsPerStack

	return {
		damagePerHit = damagePerHit,
		attackIntervalSeconds = attackIntervalSeconds,
		attackRangeStuds = attackRangeStuds,
	}
end

--- SwordShield 실효 전투 수치 (ss_* 스택만 사용). BasicMagic 과 혼합하지 않음.
--- startingRelicId / droppedRelicId: RelicData 기반 배율 곱 (nil 이면 1.0).
--- weaponGrade: WeaponProfiles.SwordShield.GradeMultipliers 적용 (nil 이면 Normal).
function UpgradeData.getSwordShieldEffectiveCombat(
	gameConfig,
	weaponProfile,
	upgrades,
	startingRelicId: string?,
	droppedRelicId: string?,
	weaponGrade: string?
)
	local minInterval = UpgradeData.Effects.attack_interval_down.MinAttackIntervalSeconds

	local baseInterval = weaponProfile.AttackIntervalSeconds or gameConfig.PlayerBaseAttackIntervalSeconds

	local cdStacks = stackCount(upgrades, "ss_common_cooldown")
	local intervalMul = math.max(0.05, 1 - 0.08 * cdStacks)
	local attackIntervalSeconds = math.max(minInterval, baseInterval * intervalMul)

	local sweepBase = weaponProfile.Sweep
	local thrustBase = weaponProfile.Thrust

	local commonDmgStacks = stackCount(upgrades, "ss_common_damage")
	local commonDamageMul = 1 + 0.10 * commonDmgStacks

	local sweepDmgStacks = stackCount(upgrades, "ss_sweep_damage")
	local sweepDamageMul = 1 + 0.15 * sweepDmgStacks

	local thrustDmgStacks = stackCount(upgrades, "ss_thrust_damage")
	local thrustDamageMul = 1 + 0.20 * thrustDmgStacks

	local sweepAngleStacks = stackCount(upgrades, "ss_sweep_angle")
	local sweepAngle = math.min(270, sweepBase.AngleDeg + 20 * sweepAngleStacks)

	local sweepRangeStacks = stackCount(upgrades, "ss_sweep_range")
	local sweepRangeStuds = sweepBase.RangeStuds * (1 + 0.15 * sweepRangeStacks)

	local thrustRangeStacks = stackCount(upgrades, "ss_thrust_range")
	local thrustRangeStuds = thrustBase.RangeStuds * (1 + 0.20 * thrustRangeStacks)

	local thrustWidthStuds = type(thrustBase.WidthStuds) == "number" and thrustBase.WidthStuds > 0 and thrustBase.WidthStuds or 3

	local sweepBaseDamage = sweepBase.BaseDamage * commonDamageMul * sweepDamageMul
	local thrustBaseDamage = thrustBase.BaseDamage * commonDamageMul * thrustDamageMul

	local m = RelicData.getCombatMultipliers(startingRelicId, droppedRelicId)
	sweepBaseDamage *= m.SweepDamageMul
	thrustBaseDamage *= m.ThrustDamageMul
	attackIntervalSeconds *= m.AttackIntervalMul
	attackIntervalSeconds = math.max(minInterval, attackIntervalSeconds)

	local gradeRow = nil
	local gm = weaponProfile.GradeMultipliers
	if type(gm) == "table" then
		local gKey = weaponGrade
		if type(gKey) ~= "string" or gKey == "" then
			gKey = "Normal"
		end
		gradeRow = gm[gKey] or gm.Normal
	end
	if type(gradeRow) == "table" then
		sweepBaseDamage *= (gradeRow.SweepDamageMul or 1)
		thrustBaseDamage *= (gradeRow.ThrustDamageMul or 1)
		attackIntervalSeconds *= (gradeRow.AttackIntervalMul or 1)
	end
	attackIntervalSeconds = math.max(minInterval, attackIntervalSeconds)

	return {
		AttackIntervalSeconds = attackIntervalSeconds,
		Sweep = {
			RangeStuds = sweepRangeStuds,
			AngleDeg = sweepAngle,
			BaseDamage = sweepBaseDamage,
		},
		Thrust = {
			RangeStuds = thrustRangeStuds,
			WidthStuds = thrustWidthStuds,
			--- 호환/표시용. Thrust 스트립 판정에는 미사용.
			AngleDeg = thrustBase.AngleDeg,
			BaseDamage = thrustBaseDamage,
		},
	}
end

local function sanitizeStackFromUpgrades(upgrades, key: string): number
	if type(upgrades) ~= "table" then
		return 0
	end
	local raw = upgrades[key]
	if type(raw) ~= "number" or raw < 0 then
		return 0
	end
	return math.max(0, math.floor(raw + 0.5))
end

local function sanitizePositiveNumber(v: any, fallback: number): number
	if type(v) ~= "number" or v <= 0 then
		return fallback
	end
	return v
end

local function resolveMultiplierFromDefinition(definition, stackCountValue: number): number
	if type(definition) ~= "table" then
		return 1
	end
	local op = definition.Operation
	if op ~= "Multiplier" then
		return 1
	end

	local stack = stackCountValue
	local maxStackRaw = definition.MaxStack
	if type(maxStackRaw) == "number" and maxStackRaw >= 0 then
		stack = math.min(stack, math.max(0, math.floor(maxStackRaw + 0.5)))
	end

	local valuePerStack = definition.ValuePerStack
	if type(valuePerStack) ~= "number" or valuePerStack < 0 then
		return 1
	end
	return 1 + valuePerStack * stack
end

function UpgradeData.getSpearEffectiveCombat(gameConfig, weaponProfile, upgrades, weaponGrade: string?)
	local profile = type(weaponProfile) == "table" and weaponProfile or {}
	local thrustBase = type(profile.Thrust) == "table" and profile.Thrust or {}

	local baseInterval = sanitizePositiveNumber(profile.AttackIntervalSeconds, 1.1)
	local baseDamage = sanitizePositiveNumber(profile.BaseDamage, 30)
	local baseRange = sanitizePositiveNumber(thrustBase.RangeStuds, 12)
	local baseWidth = sanitizePositiveNumber(thrustBase.WidthStuds, 3)
	local baseTargetLimit = sanitizePositiveNumber(thrustBase.TargetLimit, 1)
	local targetLimit = math.max(1, math.floor(baseTargetLimit + 0.5))

	local damageStack = sanitizeStackFromUpgrades(upgrades, "sp_thrust_damage")
	local rangeStack = sanitizeStackFromUpgrades(upgrades, "sp_thrust_range")

	local damageDef = UpgradeData.getUpgradeDefinition("sp_thrust_damage")
	local rangeDef = UpgradeData.getUpgradeDefinition("sp_thrust_range")
	local damageMul = resolveMultiplierFromDefinition(damageDef, damageStack)
	local rangeMul = resolveMultiplierFromDefinition(rangeDef, rangeStack)

	local gradeMul = 1
	local gm = profile.GradeMultipliers
	if type(gm) == "table" then
		local gKey = weaponGrade
		if type(gKey) ~= "string" or gKey == "" then
			gKey = "Normal"
		end
		local row = gm[gKey] or gm.Normal
		if type(row) == "table" and type(row.ThrustDamageMul) == "number" and row.ThrustDamageMul > 0 then
			gradeMul = row.ThrustDamageMul
		end
	end

	return {
		AttackIntervalSeconds = baseInterval,
		Thrust = {
			BaseDamage = baseDamage * damageMul * gradeMul,
			RangeStuds = baseRange * rangeMul,
			WidthStuds = baseWidth,
			TargetLimit = targetLimit,
		},
		Meta = {
			WeaponGrade = type(weaponGrade) == "string" and weaponGrade or "Normal",
			sp_thrust_damage = damageStack,
			sp_thrust_range = rangeStack,
		},
	}
end

--[[
Legacy relation note:
- Choices / SwordShieldChoices are legacy Phase 1 runtime offer pools.
- UpgradeDefinitions is for Phase 2 schema preparation only.
- From Phase 2C, OfferBuilder is expected to optionally consume UpgradeDefinitions with activeWeapons context.
]]
UpgradeData.UpgradeDefinitions = {
	-- WeaponSpecific examples
	sp_thrust_damage = {
		Id = "sp_thrust_damage",
		Label = "Spear Thrust Damage",
		Layer = "WeaponSpecific",
		WeaponId = "Spear",
		AttackType = "Thrust",
		Stat = "Damage",
		Operation = "Multiplier",
		ValuePerStack = 0.15,
		MaxStack = 5,
	},
	sp_thrust_range = {
		Id = "sp_thrust_range",
		Label = "Spear Thrust Range",
		Layer = "WeaponSpecific",
		WeaponId = "Spear",
		AttackType = "Thrust",
		Stat = "Range",
		Operation = "Multiplier",
		ValuePerStack = 0.12,
		MaxStack = 5,
	},
	th_sweep_damage = {
		Id = "th_sweep_damage",
		Label = "Two-Handed Sweep Damage",
		Layer = "WeaponSpecific",
		WeaponId = "TwoHandedSword",
		AttackType = "Sweep",
		Stat = "Damage",
		Operation = "Multiplier",
		ValuePerStack = 0.15,
		MaxStack = 5,
	},
	th_sweep_range = {
		Id = "th_sweep_range",
		Label = "Two-Handed Sweep Range",
		Layer = "WeaponSpecific",
		WeaponId = "TwoHandedSword",
		AttackType = "Sweep",
		Stat = "Range",
		Operation = "Multiplier",
		ValuePerStack = 0.12,
		MaxStack = 5,
	},

	-- AttackTypeCommon examples
	co_thrust_damage = {
		Id = "co_thrust_damage",
		Label = "Thrust Damage",
		Layer = "AttackTypeCommon",
		AttackType = "Thrust",
		Stat = "Damage",
		Operation = "Multiplier",
		ValuePerStack = 0.10,
		MaxStack = 5,
	},
	co_sweep_damage = {
		Id = "co_sweep_damage",
		Label = "Sweep Damage",
		Layer = "AttackTypeCommon",
		AttackType = "Sweep",
		Stat = "Damage",
		Operation = "Multiplier",
		ValuePerStack = 0.10,
		MaxStack = 5,
	},

	-- PlayerSystem example
	ab_xp_increase = {
		Id = "ab_xp_increase",
		Label = "XP Gain Increase",
		Layer = "PlayerSystem",
		AttackType = "Any",
		Stat = "XP",
		Operation = "Multiplier",
		ValuePerStack = 0.10,
		MaxStack = 5,
	},
}

local VALID_LAYERS = {
	WeaponSpecific = true,
	AttackTypeCommon = true,
	PlayerSystem = true,
}

local VALID_OPERATIONS = {
	Multiplier = true,
	Additive = true,
	IntegerAdditive = true,
	Unlock = true,
}

local REQUIRED_DEFINITION_FIELDS = {
	"Id",
	"Label",
	"Layer",
	"Stat",
	"Operation",
	"ValuePerStack",
	"MaxStack",
}

function UpgradeData.getUpgradeDefinition(upgradeId: string)
	if type(upgradeId) ~= "string" or upgradeId == "" then
		return nil
	end
	local defs = UpgradeData.UpgradeDefinitions
	if type(defs) ~= "table" then
		return nil
	end
	local row = defs[upgradeId]
	if type(row) ~= "table" then
		return nil
	end
	return row
end

function UpgradeData.getUpgradeDefinitionsByLayer(layer: string)
	local out = {}
	if type(layer) ~= "string" or layer == "" then
		return out
	end
	local defs = UpgradeData.UpgradeDefinitions
	if type(defs) ~= "table" then
		return out
	end
	for _, row in pairs(defs) do
		if type(row) == "table" and row.Layer == layer then
			table.insert(out, row)
		end
	end
	return out
end

function UpgradeData.getUpgradeDefinitionsForWeapon(weaponId: string)
	local out = {}
	if type(weaponId) ~= "string" or weaponId == "" then
		return out
	end
	local defs = UpgradeData.UpgradeDefinitions
	if type(defs) ~= "table" then
		return out
	end
	for _, row in pairs(defs) do
		if type(row) == "table" and row.WeaponId == weaponId then
			table.insert(out, row)
		end
	end
	return out
end

function UpgradeData.getUpgradeDefinitionsForAttackType(attackType: string)
	local out = {}
	if type(attackType) ~= "string" or attackType == "" then
		return out
	end
	local defs = UpgradeData.UpgradeDefinitions
	if type(defs) ~= "table" then
		return out
	end
	for _, row in pairs(defs) do
		if type(row) == "table" and row.AttackType == attackType then
			table.insert(out, row)
		end
	end
	return out
end

function UpgradeData.getChoiceForDefinition(upgradeId: string)
	local row = UpgradeData.getUpgradeDefinition(upgradeId)
	if type(row) ~= "table" then
		return nil
	end
	if type(row.Id) ~= "string" or row.Id == "" then
		return nil
	end
	if type(row.Label) ~= "string" or row.Label == "" then
		return nil
	end
	return {
		Id = row.Id,
		Label = row.Label,
	}
end

function UpgradeData.validateUpgradeDefinitions()
	local issues = {}
	local defs = UpgradeData.UpgradeDefinitions
	if type(defs) ~= "table" then
		table.insert(issues, "UpgradeDefinitions is not a table")
		return issues
	end

	local seenIds = {}
	for key, row in pairs(defs) do
		if type(row) ~= "table" then
			table.insert(issues, string.format("%s: definition row is not a table", tostring(key)))
		else
			for _, fieldName in ipairs(REQUIRED_DEFINITION_FIELDS) do
				if row[fieldName] == nil then
					table.insert(issues, string.format("%s: missing required field '%s'", tostring(key), fieldName))
				end
			end

			if type(row.Id) ~= "string" or row.Id == "" then
				table.insert(issues, string.format("%s: invalid Id", tostring(key)))
			else
				if seenIds[row.Id] then
					table.insert(issues, string.format("%s: duplicated Id '%s'", tostring(key), row.Id))
				end
				seenIds[row.Id] = true
				if row.Id ~= key then
					table.insert(issues, string.format("%s: key and Id mismatch (Id=%s)", tostring(key), row.Id))
				end
			end

			if type(row.Layer) ~= "string" or not VALID_LAYERS[row.Layer] then
				table.insert(issues, string.format("%s: invalid Layer '%s'", tostring(key), tostring(row.Layer)))
			end

			if type(row.Operation) ~= "string" or not VALID_OPERATIONS[row.Operation] then
				table.insert(issues, string.format("%s: invalid Operation '%s'", tostring(key), tostring(row.Operation)))
			end
		end
	end

	return issues
end

return UpgradeData

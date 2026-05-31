local RelicModifierApplicator = require(script.Parent:WaitForChild("RelicModifierApplicator"))

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

	Choices = {
		{
			Id = "damage_up",
			Label = "怨듦꺽 ?쇳빐??利앷? (+5/?ㅽ깮)",
		},
		{
			Id = "attack_interval_down",
			Label = "怨듦꺽 ?띾룄 5% 利앷? (?ㅽ깮??",
		},
		{
			Id = "attack_size_up",
			Label = "?ш굅由?+2 ?ㅽ꽣??(?ㅽ깮??",
		},
	},

	SwordShieldChoices = {
		{ Id = "ss_common_damage", Label = "Sword & Shield Attack Damage +10%" },
		{ Id = "ss_common_cooldown", Label = "Sword & Shield Attack Cooldown -8%" },
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

function UpgradeData.getAllKnownUpgradeIds(): { string }
	local out = {}
	local seen = {}

	local function pushId(id)
		if type(id) ~= "string" or id == "" then
			return
		end
		if seen[id] == true then
			return
		end
		seen[id] = true
		table.insert(out, id)
	end

	for _, choice in ipairs(UpgradeData.Choices or {}) do
		if type(choice) == "table" then
			pushId(choice.Id)
		end
	end
	for _, choice in ipairs(UpgradeData.SwordShieldChoices or {}) do
		if type(choice) == "table" then
			pushId(choice.Id)
		end
	end

	local defs = UpgradeData.UpgradeDefinitions
	if type(defs) == "table" then
		for id, row in pairs(defs) do
			if type(row) == "table" and type(row.Id) == "string" and row.Id ~= "" then
				pushId(row.Id)
			else
				pushId(id)
			end
		end
	end

	return out
end

function UpgradeData.createZeroUpgradeTable(): { [string]: number }
	local t = {}
	for _, id in ipairs(UpgradeData.getAllKnownUpgradeIds()) do
		t[id] = 0
	end
	return t
end

function UpgradeData.fillMissingUpgradeKeys(upgrades)
	if type(upgrades) ~= "table" then
		return UpgradeData.createZeroUpgradeTable()
	end
	for _, id in ipairs(UpgradeData.getAllKnownUpgradeIds()) do
		if upgrades[id] == nil then
			upgrades[id] = 0
		end
	end
	return upgrades
end

local MIN_ATTACK_INTERVAL_SECONDS = 0.25

local function clampAttackIntervalSeconds(value)
	if type(value) ~= "number" then
		return value
	end

	if value < MIN_ATTACK_INTERVAL_SECONDS then
		return MIN_ATTACK_INTERVAL_SECONDS
	end

	return value
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
	local cooldownApplied = UpgradeData.applyUpgradeDefinitionsToStats({
		AttackIntervalSeconds = attackIntervalSeconds,
	}, {
		WeaponId = "BasicMagic",
		System = "CombatAttack",
		LayerAllowList = {
			AttackTypeCommon = true,
		},
	}, upgrades)
	if type(cooldownApplied) == "table"
		and type(cooldownApplied.AttackIntervalSeconds) == "number"
		and cooldownApplied.AttackIntervalSeconds > 0
	then
		attackIntervalSeconds = cooldownApplied.AttackIntervalSeconds
	end

	local attackRangeStuds = gameConfig.PlayerAttackRangeStuds
		+ rangeStacks * fx.attack_size_up.RangeBonusStudsPerStack

	return {
		damagePerHit = damagePerHit,
		attackIntervalSeconds = clampAttackIntervalSeconds(attackIntervalSeconds),
		attackRangeStuds = attackRangeStuds,
	}
end

--- SwordShield effective stats: upgrades + phase3RelicIds (RelicModifierApplicator). No RelicData (7C-2).
function UpgradeData.getSwordShieldEffectiveCombat(
	gameConfig,
	weaponProfile,
	upgrades,
	weaponGrade: string?,
	phase3RelicIds: { string }?
)
	local minInterval = UpgradeData.Effects.attack_interval_down.MinAttackIntervalSeconds

	local baseInterval = weaponProfile.AttackIntervalSeconds or gameConfig.PlayerBaseAttackIntervalSeconds
	local baseAttackIntervalSeconds = baseInterval

	local sweepBase = weaponProfile.Sweep
	local thrustBase = weaponProfile.Thrust

	local sweepAngle = sweepBase.AngleDeg
	local sweepRangeStuds = sweepBase.RangeStuds
	local thrustRangeStuds = thrustBase.RangeStuds

	local thrustWidthStuds = type(thrustBase.WidthStuds) == "number" and thrustBase.WidthStuds > 0 and thrustBase.WidthStuds or 3

	local sweepBaseDamage = sweepBase.BaseDamage
	local thrustBaseDamage = thrustBase.BaseDamage

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
		baseAttackIntervalSeconds *= (gradeRow.AttackIntervalMul or 1)
	end
	baseAttackIntervalSeconds = math.max(minInterval, baseAttackIntervalSeconds)

	-- Phase 2G-3: move SwordShield cooldown (ss_common_cooldown + co_common_cooldown)
	-- to a generic applicator path.
	local cooldownApplied = UpgradeData.applyUpgradeDefinitionsToStats({
		AttackIntervalSeconds = baseAttackIntervalSeconds,
	}, {
		WeaponId = "SwordShield",
		AttackId = "Common",
		AttackType = "Common",
		WeaponTags = weaponProfile.Tags,
		System = "CombatAttack",
		LayerAllowList = {
			WeaponSpecific = true,
			AttackTypeCommon = true,
		},
	}, upgrades)
	local attackIntervalSeconds = baseAttackIntervalSeconds
	if type(cooldownApplied) == "table"
		and type(cooldownApplied.AttackIntervalSeconds) == "number"
		and cooldownApplied.AttackIntervalSeconds > 0
	then
		attackIntervalSeconds = cooldownApplied.AttackIntervalSeconds
	end
	attackIntervalSeconds = math.max(minInterval, attackIntervalSeconds)

	-- Phase 2G-1/2: SwordShield Sweep/Thrust damage/range/angle are on generic applicator paths.
	local attacks = type(weaponProfile.Attacks) == "table" and weaponProfile.Attacks or nil
	local sweepAttack = type(attacks) == "table" and attacks.Sweep or nil
	local thrustAttack = type(attacks) == "table" and attacks.Thrust or nil

	local sweepApplied = UpgradeData.applyUpgradeDefinitionsToStats({
		BaseDamage = sweepBaseDamage,
		RangeStuds = sweepRangeStuds,
		AngleDeg = sweepAngle,
		TargetLimit = nil,
	}, {
		WeaponId = "SwordShield",
		AttackId = "Sweep",
		AttackType = "Sweep",
		WeaponTags = weaponProfile.Tags,
		AttackTags = type(sweepAttack) == "table" and sweepAttack.Tags or nil,
		LayerAllowList = {
			WeaponSpecific = true,
			AttackTypeCommon = true,
		},
	}, upgrades)

	local thrustApplied = UpgradeData.applyUpgradeDefinitionsToStats({
		BaseDamage = thrustBaseDamage,
		RangeStuds = thrustRangeStuds,
		WidthStuds = thrustWidthStuds,
		TargetLimit = nil,
	}, {
		WeaponId = "SwordShield",
		AttackId = "Thrust",
		AttackType = "Thrust",
		WeaponTags = weaponProfile.Tags,
		AttackTags = type(thrustAttack) == "table" and thrustAttack.Tags or nil,
		LayerAllowList = {
			WeaponSpecific = true,
			AttackTypeCommon = true,
		},
	}, upgrades)

	if type(sweepApplied) == "table" and type(sweepApplied.BaseDamage) == "number" and sweepApplied.BaseDamage > 0 then
		sweepBaseDamage = sweepApplied.BaseDamage
	end
	if type(thrustApplied) == "table" and type(thrustApplied.BaseDamage) == "number" and thrustApplied.BaseDamage > 0 then
		thrustBaseDamage = thrustApplied.BaseDamage
	end
	if type(sweepApplied) == "table" and type(sweepApplied.RangeStuds) == "number" and sweepApplied.RangeStuds > 0 then
		sweepRangeStuds = sweepApplied.RangeStuds
	end
	if type(sweepApplied) == "table" and type(sweepApplied.AngleDeg) == "number" then
		sweepAngle = math.min(270, sweepApplied.AngleDeg)
	end
	if type(thrustApplied) == "table" and type(thrustApplied.RangeStuds) == "number" and thrustApplied.RangeStuds > 0 then
		thrustRangeStuds = thrustApplied.RangeStuds
	end

	local effective = {
		AttackIntervalSeconds = clampAttackIntervalSeconds(attackIntervalSeconds),
		Sweep = {
			RangeStuds = sweepRangeStuds,
			AngleDeg = sweepAngle,
			BaseDamage = sweepBaseDamage,
		},
		Thrust = {
			RangeStuds = thrustRangeStuds,
			WidthStuds = thrustWidthStuds,
			AngleDeg = thrustBase.AngleDeg,
			BaseDamage = thrustBaseDamage,
		},
	}
	return RelicModifierApplicator.applyToSwordShieldEffective(effective, phase3RelicIds)
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

function UpgradeData.getSpearEffectiveCombat(
	gameConfig,
	weaponProfile,
	upgrades,
	weaponGrade: string?,
	phase3RelicIds: { string }?
)
	local profile = type(weaponProfile) == "table" and weaponProfile or {}
	local thrustBase = type(profile.Thrust) == "table" and profile.Thrust or {}

	local baseInterval = sanitizePositiveNumber(profile.AttackIntervalSeconds, 0.7)
	local baseDamage = sanitizePositiveNumber(profile.BaseDamage, 40)
	local baseRange = sanitizePositiveNumber(thrustBase.RangeStuds, 12)
	local baseWidth = sanitizePositiveNumber(thrustBase.WidthStuds, 3)
	local baseTargetLimit = sanitizePositiveNumber(thrustBase.TargetLimit, 1)
	local targetLimit = math.max(1, math.floor(baseTargetLimit + 0.5))

	local damageStack = sanitizeStackFromUpgrades(upgrades, "sp_thrust_damage")
	local rangeStack = sanitizeStackFromUpgrades(upgrades, "sp_thrust_range")

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

	-- Phase 2E-0C: migrate spear sp_* application to generic applicator (WeaponSpecific only).
	local baseStats = {
		BaseDamage = baseDamage * gradeMul,
		RangeStuds = baseRange,
		WidthStuds = baseWidth,
		TargetLimit = targetLimit,
		AttackIntervalSeconds = baseInterval,
	}
	local context = {
		WeaponId = "Spear",
		AttackId = "Thrust",
		AttackType = "Thrust",
		System = "CombatAttack",
		WeaponTags = profile.Tags,
		AttackTags = thrustBase.Tags,
		LayerAllowList = {
			WeaponSpecific = true,
			AttackTypeCommon = true,
		},
	}
	local applied = UpgradeData.applyUpgradeDefinitionsToStats(baseStats, context, upgrades)

	local effective = {
		AttackIntervalSeconds = clampAttackIntervalSeconds(applied.AttackIntervalSeconds or baseInterval),
		Thrust = {
			BaseDamage = applied.BaseDamage or baseStats.BaseDamage,
			RangeStuds = applied.RangeStuds or baseStats.RangeStuds,
			WidthStuds = applied.WidthStuds or baseStats.WidthStuds,
			TargetLimit = applied.TargetLimit ~= nil and applied.TargetLimit or baseStats.TargetLimit,
		},
		Meta = {
			WeaponGrade = type(weaponGrade) == "string" and weaponGrade or "Normal",
			sp_thrust_damage = damageStack,
			sp_thrust_range = rangeStack,
			GenericApplied = type(applied) == "table" and applied._GenericMeta or nil,
		},
	}

	return RelicModifierApplicator.applyToSpearEffective(effective, phase3RelicIds)
end

function UpgradeData.getTwoHandedSwordEffectiveCombat(
	gameConfig,
	weaponProfile,
	upgrades,
	weaponGrade: string?,
	phase3RelicIds: { string }?
)
	local profile = type(weaponProfile) == "table" and weaponProfile or {}
	local sweepBase = type(profile.Sweep) == "table" and profile.Sweep or {}

	local baseInterval = sanitizePositiveNumber(profile.AttackIntervalSeconds, 1.6)
	local baseDamage = sanitizePositiveNumber(profile.BaseDamage, 45)
	local baseRange = sanitizePositiveNumber(sweepBase.RangeStuds, 12)
	local baseAngle = sanitizePositiveNumber(sweepBase.AngleDeg, 180)

	local targetLimit = nil
	if type(sweepBase.TargetLimit) == "number" then
		local rawTargetLimit = math.floor(sweepBase.TargetLimit + 0.5)
		targetLimit = math.max(1, rawTargetLimit)
	end

	local damageStack = sanitizeStackFromUpgrades(upgrades, "th_sweep_damage")
	local rangeStack = sanitizeStackFromUpgrades(upgrades, "th_sweep_range")

	local gradeMul = 1
	local gm = profile.GradeMultipliers
	if type(gm) == "table" then
		local gKey = weaponGrade
		if type(gKey) ~= "string" or gKey == "" then
			gKey = "Normal"
		end
		local row = gm[gKey] or gm.Normal
		if type(row) == "table" and type(row.SweepDamageMul) == "number" and row.SweepDamageMul > 0 then
			gradeMul = row.SweepDamageMul
		end
	end

	-- Phase 2E-0D: migrate TwoHandedSword th_* application to generic applicator (WeaponSpecific only).
	local attacks = type(profile.Attacks) == "table" and profile.Attacks or nil
	local sweepAttack = attacks and attacks.Sweep or nil
	local baseStats = {
		BaseDamage = baseDamage * gradeMul,
		RangeStuds = baseRange,
		AngleDeg = baseAngle,
		TargetLimit = targetLimit,
		AttackIntervalSeconds = baseInterval,
	}
	local context = {
		WeaponId = "TwoHandedSword",
		AttackId = "Sweep",
		AttackType = "Sweep",
		System = "CombatAttack",
		WeaponTags = profile.Tags,
		AttackTags = type(sweepAttack) == "table" and sweepAttack.Tags or nil,
		LayerAllowList = {
			WeaponSpecific = true,
			AttackTypeCommon = true,
		},
	}
	local applied = UpgradeData.applyUpgradeDefinitionsToStats(baseStats, context, upgrades)

	local effective = {
		AttackIntervalSeconds = clampAttackIntervalSeconds(applied.AttackIntervalSeconds or baseInterval),
		Sweep = {
			BaseDamage = applied.BaseDamage or baseStats.BaseDamage,
			RangeStuds = applied.RangeStuds or baseStats.RangeStuds,
			AngleDeg = applied.AngleDeg or baseStats.AngleDeg,
			TargetLimit = applied.TargetLimit ~= nil and applied.TargetLimit or baseStats.TargetLimit,
		},
		Meta = {
			WeaponGrade = type(weaponGrade) == "string" and weaponGrade or "Normal",
			th_sweep_damage = damageStack,
			th_sweep_range = rangeStack,
			GenericApplied = type(applied) == "table" and applied._GenericMeta or nil,
		},
	}

	return RelicModifierApplicator.applyToTwoHandedSwordEffective(effective, phase3RelicIds)
end

--[[
Legacy relation note:
- Choices / SwordShieldChoices are legacy Phase 1 runtime offer pools.
- UpgradeDefinitions is for Phase 2 schema preparation only.
- From Phase 2C, OfferBuilder is expected to optionally consume UpgradeDefinitions with activeWeapons context.
]]
UpgradeData.UpgradeDefinitions = {
	-- WeaponSpecific examples
	-- SwordShield (legacy runtime parity definitions; calculation path remains manual for now)
	ss_common_damage = {
		Id = "ss_common_damage",
		Label = "Sword & Shield Attack Damage +10%",
		Layer = "WeaponSpecific",
		WeaponId = "SwordShield",
		AppliesTo = {
			WeaponId = "SwordShield",
			AnyTags = { "Sweep", "Thrust" },
		},
		Stat = "Damage",
		Operation = "Multiplier",
		ValuePerStack = 0.10,
		MaxStack = 5,
	},
	ss_common_cooldown = {
		Id = "ss_common_cooldown",
		Label = "Sword & Shield Attack Cooldown -8%",
		Layer = "WeaponSpecific",
		WeaponId = "SwordShield",
		AppliesTo = {
			WeaponId = "SwordShield",
			System = "CombatAttack",
		},
		Stat = "Cooldown",
		Operation = "Multiplier",
		ValuePerStack = -0.08,
		MaxStack = 5,
	},
	ss_sweep_angle = {
		Id = "ss_sweep_angle",
		Label = "Shield Sweep Angle +20°",
		Layer = "WeaponSpecific",
		WeaponId = "SwordShield",
		AttackType = "Sweep",
		AppliesTo = {
			WeaponId = "SwordShield",
			AttackType = "Sweep",
		},
		Stat = "Angle",
		Operation = "Additive",
		ValuePerStack = 20,
		MaxStack = 5,
	},
	ss_sweep_damage = {
		Id = "ss_sweep_damage",
		Label = "Shield Sweep Damage +15%",
		Layer = "WeaponSpecific",
		WeaponId = "SwordShield",
		AttackType = "Sweep",
		AppliesTo = {
			WeaponId = "SwordShield",
			AttackType = "Sweep",
		},
		Stat = "Damage",
		Operation = "Multiplier",
		ValuePerStack = 0.15,
		MaxStack = 5,
	},
	ss_sweep_range = {
		Id = "ss_sweep_range",
		Label = "Shield Sweep Range +15%",
		Layer = "WeaponSpecific",
		WeaponId = "SwordShield",
		AttackType = "Sweep",
		AppliesTo = {
			WeaponId = "SwordShield",
			AttackType = "Sweep",
		},
		Stat = "Range",
		Operation = "Multiplier",
		ValuePerStack = 0.15,
		MaxStack = 5,
	},
	ss_thrust_damage = {
		Id = "ss_thrust_damage",
		Label = "Sword Thrust Damage +20%",
		Layer = "WeaponSpecific",
		WeaponId = "SwordShield",
		AttackType = "Thrust",
		AppliesTo = {
			WeaponId = "SwordShield",
			AttackType = "Thrust",
		},
		Stat = "Damage",
		Operation = "Multiplier",
		ValuePerStack = 0.20,
		MaxStack = 5,
	},
	ss_thrust_range = {
		Id = "ss_thrust_range",
		Label = "Sword Thrust Range +20%",
		Layer = "WeaponSpecific",
		WeaponId = "SwordShield",
		AttackType = "Thrust",
		AppliesTo = {
			WeaponId = "SwordShield",
			AttackType = "Thrust",
		},
		Stat = "Range",
		Operation = "Multiplier",
		ValuePerStack = 0.20,
		MaxStack = 5,
	},

	sp_thrust_damage = {
		Id = "sp_thrust_damage",
		Label = "Spear Thrust Damage",
		Layer = "WeaponSpecific",
		WeaponId = "Spear",
		AttackType = "Thrust",
		-- UpgradeDefinitions.AppliesTo is reserved for the future generic upgrade applicator.
		-- Current runtime helpers may still read WeaponId / AttackType directly during migration.
		AppliesTo = {
			WeaponId = "Spear",
			AttackType = "Thrust",
		},
		Stat = "Damage",
		Operation = "Multiplier",
		ValuePerStack = 0.15,
		MaxStack = 5,
	},
	sp_thrust_range = {
		Id = "sp_thrust_range",
		Label = "Spear Thrust Range +25%",
		Layer = "WeaponSpecific",
		WeaponId = "Spear",
		AttackType = "Thrust",
		AppliesTo = {
			WeaponId = "Spear",
			AttackType = "Thrust",
		},
		Stat = "Range",
		Operation = "Multiplier",
		ValuePerStack = 0.25,
		MaxStack = 5,
	},
	sp_common_cooldown = {
		Id = "sp_common_cooldown",
		Label = "Spear Attack Cooldown -5%",
		Layer = "WeaponSpecific",
		WeaponId = "Spear",
		AppliesTo = {
			WeaponId = "Spear",
		},
		Stat = "Cooldown",
		Operation = "Multiplier",
		ValuePerStack = -0.05,
		MaxStack = 5,
	},
	th_sweep_damage = {
		Id = "th_sweep_damage",
		Label = "Two-Handed Sweep Damage",
		Layer = "WeaponSpecific",
		WeaponId = "TwoHandedSword",
		AttackType = "Sweep",
		AppliesTo = {
			WeaponId = "TwoHandedSword",
			AttackType = "Sweep",
		},
		Stat = "Damage",
		Operation = "Multiplier",
		ValuePerStack = 0.15,
		MaxStack = 5,
	},
	th_sweep_range = {
		Id = "th_sweep_range",
		Label = "Sword Sweep Range +20%",
		Layer = "WeaponSpecific",
		WeaponId = "TwoHandedSword",
		AttackType = "Sweep",
		AppliesTo = {
			WeaponId = "TwoHandedSword",
			AttackType = "Sweep",
		},
		Stat = "Range",
		Operation = "Multiplier",
		ValuePerStack = 0.20,
		MaxStack = 5,
	},
	th_sweep_angle = {
		Id = "th_sweep_angle",
		Label = "Sword Sweep Angle +15°",
		Layer = "WeaponSpecific",
		WeaponId = "TwoHandedSword",
		AttackType = "Sweep",
		AppliesTo = {
			WeaponId = "TwoHandedSword",
			AttackType = "Sweep",
		},
		Stat = "Angle",
		Operation = "Additive",
		ValuePerStack = 15,
		MaxStack = 5,
	},
	th_common_cooldown = {
		Id = "th_common_cooldown",
		Label = "TwoHandedSword Attack Cooldown -6%",
		Layer = "WeaponSpecific",
		WeaponId = "TwoHandedSword",
		AppliesTo = {
			WeaponId = "TwoHandedSword",
		},
		Stat = "Cooldown",
		Operation = "Multiplier",
		ValuePerStack = -0.06,
		MaxStack = 5,
	},

	-- AttackTypeCommon examples
	co_thrust_damage = {
		Id = "co_thrust_damage",
		Label = "Thrust Damage +12%",
		Layer = "AttackTypeCommon",
		AttackType = "Thrust",
		AppliesTo = {
			AttackType = "Thrust",
		},
		Stat = "Damage",
		Operation = "Multiplier",
		ValuePerStack = 0.12,
		MaxStack = 5,
	},
	co_sweep_damage = {
		Id = "co_sweep_damage",
		Label = "Sweep Damage +12%",
		Layer = "AttackTypeCommon",
		AttackType = "Sweep",
		AppliesTo = {
			AttackType = "Sweep",
		},
		Stat = "Damage",
		Operation = "Multiplier",
		ValuePerStack = 0.12,
		MaxStack = 5,
	},
	co_thrust_range = {
		Id = "co_thrust_range",
		Label = "Thrust Range",
		Layer = "AttackTypeCommon",
		AttackType = "Thrust",
		AppliesTo = {
			AttackType = "Thrust",
		},
		Stat = "Range",
		Operation = "Multiplier",
		ValuePerStack = 0.10,
		MaxStack = 5,
	},
	co_sweep_range = {
		Id = "co_sweep_range",
		Label = "Sweep Range",
		Layer = "AttackTypeCommon",
		AttackType = "Sweep",
		AppliesTo = {
			AttackType = "Sweep",
		},
		Stat = "Range",
		Operation = "Multiplier",
		ValuePerStack = 0.10,
		MaxStack = 5,
	},
	co_common_cooldown = {
		Id = "co_common_cooldown",
		Label = "Common Attack Cooldown -5%",
		Layer = "AttackTypeCommon",
		AppliesTo = {
			System = "CombatAttack",
		},
		Stat = "Cooldown",
		Operation = "Multiplier",
		ValuePerStack = -0.05,
		MaxStack = 5,
	},

	-- PlayerSystem example
	ab_xp_increase = {
		Id = "ab_xp_increase",
		Label = "Exp Gain +5%",
		Layer = "PlayerSystem",
		AttackType = "Any",
		AppliesTo = {
			System = "XP",
		},
		Stat = "XP",
		Operation = "Multiplier",
		ValuePerStack = 0.05,
		MaxStack = 5,
	},
	ab_Health_increase = {
		Id = "ab_Health_increase",
		Label = "Max HP +20",
		Layer = "PlayerSystem",
		AppliesTo = {
			System = "PlayerHealth",
		},
		Stat = "MaxHealth",
		Operation = "Additive",
		ValuePerStack = 20,
		MaxStack = 5,
	},
	ab_Speed_increase = {
		Id = "ab_Speed_increase",
		Label = "Speed +3%",
		Layer = "PlayerSystem",
		AppliesTo = {
			System = "PlayerMovement",
		},
		Stat = "MoveSpeed",
		Operation = "Multiplier",
		ValuePerStack = 0.03,
		MaxStack = 5,
	},
	mg_Range_increase = {
		Id = "mg_Range_increase",
		Label = "Magnet Range +20%",
		Layer = "PlayerSystem",
		AppliesTo = {
			System = "PickupMagnet",
		},
		Stat = "MagnetRange",
		Operation = "Multiplier",
		ValuePerStack = 0.20,
		MaxStack = 5,
	},
	ho_Amount_increase = {
		Id = "ho_Amount_increase",
		Label = "Health Orb Recovery Up +20%",
		Layer = "PlayerSystem",
		AppliesTo = {
			System = "HealthPickup",
		},
		Stat = "HealAmount",
		Operation = "Multiplier",
		ValuePerStack = 0.20,
		MaxStack = 5,
	},
	ho_Chance_increase = {
		Id = "ho_Chance_increase",
		Label = "Health Orb Drop Chance +0.5%",
		Layer = "PlayerSystem",
		AppliesTo = {
			System = "HealthPickup",
		},
		Stat = "DropChance",
		Operation = "Additive",
		ValuePerStack = 0.005,
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

			-- AppliesTo is reserved for future generic upgrade applicator metadata.
			-- Validation here is intentionally permissive to avoid breaking current runtime.
			if row.AppliesTo ~= nil and type(row.AppliesTo) ~= "table" then
				table.insert(issues, string.format("%s: AppliesTo must be a table when present", tostring(key)))
			end
		end
	end

	return issues
end

-- Generic upgrade applicator (reserved for future migration).
-- This does NOT change current runtime combat calculations; helpers may still read WeaponId/AttackType directly.
local function cloneShallow(t)
	if type(t) ~= "table" then
		return {}
	end
	local out = {}
	for k, v in pairs(t) do
		out[k] = v
	end
	return out
end

local function buildTagSet(weaponTags, attackTags)
	local set = {}
	local function ingest(list)
		if type(list) ~= "table" then
			return
		end
		for _, raw in ipairs(list) do
			if type(raw) == "string" and raw ~= "" then
				set[raw] = true
			end
		end
	end
	ingest(weaponTags)
	ingest(attackTags)
	return set
end

local function sanitizeStackForDefinition(upgrades, def)
	if type(upgrades) ~= "table" or type(def) ~= "table" then
		return 0, 0
	end
	local id = def.Id
	if type(id) ~= "string" or id == "" then
		return 0, 0
	end
	local raw = upgrades[id]
	if type(raw) ~= "number" or raw < 0 then
		return 0, 0
	end
	local stack = math.max(0, math.floor(raw + 0.5))
	local maxStackRaw = def.MaxStack
	if type(maxStackRaw) == "number" and maxStackRaw >= 0 then
		local maxStack = math.max(0, math.floor(maxStackRaw + 0.5))
		local applied = math.min(stack, maxStack)
		return stack, applied
	end
	return stack, stack
end

local function layerAllowed(def, context)
	if type(context) ~= "table" then
		return true
	end
	local allow = context.LayerAllowList
	if allow == nil then
		return true
	end
	if type(allow) ~= "table" then
		return true
	end
	local layer = type(def) == "table" and def.Layer or nil
	if type(layer) ~= "string" or layer == "" then
		return false
	end
	return allow[layer] == true
end

local function hasAllRequiredTags(set, required)
	if type(required) ~= "table" then
		return true
	end
	for _, tag in ipairs(required) do
		if type(tag) == "string" and tag ~= "" then
			if set[tag] ~= true then
				return false
			end
		end
	end
	return true
end

local function hasAnyTags(set, anyTags)
	if type(anyTags) ~= "table" then
		return true
	end
	for _, tag in ipairs(anyTags) do
		if type(tag) == "string" and tag ~= "" then
			if set[tag] == true then
				return true
			end
		end
	end
	return false
end

local function definitionAppliesToContext(def, context)
	if type(def) ~= "table" then
		return false
	end
	if type(context) ~= "table" then
		return true
	end
	if not layerAllowed(def, context) then
		return false
	end

	local weaponId = context.WeaponId
	local attackId = context.AttackId
	local attackType = context.AttackType
	local system = context.System
	local tags = buildTagSet(context.WeaponTags, context.AttackTags)

	local applies = def.AppliesTo
	local aWeaponId = nil
	local aAttackId = nil
	local aAttackType = nil
	local aReqTags = nil
	local aAnyTags = nil
	local aSystem = nil
	if type(applies) == "table" then
		aWeaponId = applies.WeaponId
		aAttackId = applies.AttackId
		aAttackType = applies.AttackType
		aReqTags = applies.RequiredTags
		aAnyTags = applies.AnyTags
		aSystem = applies.System
	else
		-- Migration fallback for older definitions.
		aWeaponId = def.WeaponId
		aAttackType = def.AttackType
	end

	if type(aWeaponId) == "string" and aWeaponId ~= "" then
		if type(weaponId) ~= "string" or weaponId ~= aWeaponId then
			return false
		end
	end
	if type(aAttackId) == "string" and aAttackId ~= "" then
		if type(attackId) ~= "string" or attackId ~= aAttackId then
			return false
		end
	end
	if type(aAttackType) == "string" and aAttackType ~= "" then
		if type(attackType) ~= "string" or attackType ~= aAttackType then
			return false
		end
	end
	if type(aSystem) == "string" and aSystem ~= "" then
		if type(system) ~= "string" or system ~= aSystem then
			return false
		end
	end
	if not hasAllRequiredTags(tags, aReqTags) then
		return false
	end
	if type(aAnyTags) == "table" and not hasAnyTags(tags, aAnyTags) then
		return false
	end
	return true
end

local STAT_ALIASES = {
	Damage = { "Damage", "BaseDamage" },
	Range = { "Range", "RangeStuds" },
	Width = { "Width", "WidthStuds" },
	Angle = { "Angle", "AngleDeg" },
	Cooldown = { "Cooldown", "AttackIntervalSeconds" },
	AttackIntervalSeconds = { "AttackIntervalSeconds", "Cooldown" },
	TargetLimit = { "TargetLimit" },
	Pierce = { "Pierce" },
}

local function resolveStatKey(baseStats, statName)
	if type(baseStats) ~= "table" or type(statName) ~= "string" or statName == "" then
		return nil
	end
	local keys = STAT_ALIASES[statName] or { statName }
	for _, k in ipairs(keys) do
		if baseStats[k] ~= nil then
			return k
		end
	end
	for _, k in ipairs(keys) do
		if baseStats[k] == nil then
			return k
		end
	end
	return nil
end

local function applyOperationToValue(op, currentValue, valuePerStack, appliedStack, statName)
	if appliedStack <= 0 then
		return currentValue
	end
	if type(valuePerStack) ~= "number" or valuePerStack < 0 then
		return currentValue
	end
	if op == "Multiplier" then
		if type(currentValue) ~= "number" then
			return currentValue
		end
		return currentValue * (1 + valuePerStack * appliedStack)
	end
	if op == "Additive" then
		if type(currentValue) ~= "number" then
			return currentValue
		end
		return currentValue + valuePerStack * appliedStack
	end
	if op == "IntegerAdditive" then
		-- TargetLimit nil may mean unlimited; keep nil unchanged.
		if statName == "TargetLimit" and currentValue == nil then
			return currentValue
		end
		local baseInt = 0
		if type(currentValue) == "number" then
			baseInt = math.floor(currentValue + 0.5)
		end
		local addInt = math.floor(valuePerStack * appliedStack + 0.5)
		return baseInt + addInt
	end
	-- Unlock or unknown: no stat mutation at this phase.
	return currentValue
end

function UpgradeData.applyUpgradeDefinitionsToStats(baseStats, context, upgrades)
	local result = cloneShallow(baseStats)
	if type(context) ~= "table" then
		return result
	end
	if type(upgrades) ~= "table" then
		upgrades = {}
	end

	local defs = UpgradeData.UpgradeDefinitions
	if type(defs) ~= "table" then
		return result
	end

	local applied = {}
	for _, def in pairs(defs) do
		if type(def) ~= "table" then
			continue
		end
		if not definitionAppliesToContext(def, context) then
			continue
		end

		local statName = def.Stat
		if type(statName) ~= "string" or statName == "" then
			continue
		end

		local op = def.Operation
		if op ~= "Multiplier" and op ~= "Additive" and op ~= "IntegerAdditive" and op ~= "Unlock" then
			continue
		end

		local rawStack, appliedStack = sanitizeStackForDefinition(upgrades, def)
		if appliedStack <= 0 and op ~= "Unlock" then
			continue
		end

		local key = resolveStatKey(result, statName)
		if key == nil then
			continue
		end

		if op ~= "Unlock" then
			local cur = result[key]
			result[key] = applyOperationToValue(op, cur, def.ValuePerStack, appliedStack, statName)
		end

		table.insert(applied, {
			Id = def.Id,
			Stack = rawStack,
			AppliedStack = appliedStack,
			Stat = statName,
			Operation = op,
		})
	end

	if #applied > 0 then
		result._GenericMeta = {
			AppliedUpgrades = applied,
		}
	end

	return result
end

return UpgradeData

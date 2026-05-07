
local WeaponProfiles = {}

WeaponProfiles.BasicMagic = {
	Id = "BasicMagic",
	Description = "기존 플레이어 구형 근처 전체 타격; 수치는 getEffectiveCombatStats",
	-- Attacks metadata is for generic upgrade calculation and future weapon scaling.
	-- Existing legacy fields are kept for current CombatService compatibility.
	Tags = { "Magic", "Area" },
	Attacks = {
		MagicArea = {
			AttackId = "MagicArea",
			AttackType = "Magic",
			Tags = { "Magic", "Area" },
		},
	},
}

WeaponProfiles.SwordShield = {
	Id = "SwordShield",
	GradeMultipliers = {
		Normal = {
			SweepDamageMul = 1,
			ThrustDamageMul = 1,
			AttackIntervalMul = 1,
		},
		Rare = {
			SweepDamageMul = 1.10,
			ThrustDamageMul = 1.10,
			AttackIntervalMul = 0.95,
		},
	},
	AttackIntervalSeconds = 1,
	TargetSearchRangeStuds = 14,
	Sweep = {
		AngleDeg = 180,
		RangeStuds = 10,
		BaseDamage = 15,
		Tags = { "Melee", "Shield", "Sweep", "Frontal", "AoE" },
		KnockbackHintStuds = 0,
	},
	Thrust = {
		AngleDeg = 15,
		RangeStuds = 6,
		WidthStuds = 3,
		BaseDamage = 30,
		PierceExtraTargets = 0,
		Tags = { "Melee", "Sword", "Thrust", "Frontal", "Pierce" },
	},
	-- Attacks metadata is for generic upgrade calculation and future weapon scaling.
	-- Existing legacy fields are kept for current CombatService compatibility.
	Tags = { "Melee", "Physical", "Hybrid" },
	Attacks = {
		Sweep = {
			AttackId = "Sweep",
			AttackType = "Sweep",
			Tags = { "Sweep", "Melee", "Area" },
			BaseDamage = 15,
			AttackIntervalSeconds = 1,
			RangeStuds = 10,
			AngleDeg = 180,
		},
		Thrust = {
			AttackId = "Thrust",
			AttackType = "Thrust",
			Tags = { "Thrust", "Melee", "Line" },
			BaseDamage = 30,
			AttackIntervalSeconds = 1,
			RangeStuds = 6,
			WidthStuds = 3,
		},
	},
}

WeaponProfiles.Spear = {
	Id = "Spear",
	Label = "Spear",
	AttackType = "Thrust",
	BaseDamage = 30,
	AttackIntervalSeconds = 1.1,
	Thrust = {
		RangeStuds = WeaponProfiles.SwordShield.Thrust.RangeStuds * 2,
		WidthStuds = WeaponProfiles.SwordShield.Thrust.WidthStuds,
		TargetLimit = 1,
	},
	-- Attacks metadata is for generic upgrade calculation and future weapon scaling.
	-- Existing legacy fields are kept for current CombatService compatibility.
	Tags = { "Melee", "Physical", "Polearm" },
	Attacks = {
		Thrust = {
			AttackId = "Thrust",
			AttackType = "Thrust",
			Tags = { "Thrust", "Melee", "Line", "SingleTarget" },
			BaseDamage = 30,
			AttackIntervalSeconds = 1.1,
			RangeStuds = WeaponProfiles.SwordShield.Thrust.RangeStuds * 2,
			WidthStuds = WeaponProfiles.SwordShield.Thrust.WidthStuds,
			TargetLimit = 1,
		},
	},
}

WeaponProfiles.TwoHandedSword = {
	Id = "TwoHandedSword",
	Label = "Two-Handed Sword",
	AttackType = "Sweep",
	BaseDamage = 45,
	AttackIntervalSeconds = 1.6,
	Sweep = {
		RangeStuds = WeaponProfiles.SwordShield.Sweep.RangeStuds * 1.4,
		AngleDeg = WeaponProfiles.SwordShield.Sweep.AngleDeg + 15,
		TargetLimit = nil,
	},
	-- Attacks metadata is for generic upgrade calculation and future weapon scaling.
	-- Existing legacy fields are kept for current CombatService compatibility.
	Tags = { "Melee", "Physical", "Heavy" },
	Attacks = {
		Sweep = {
			AttackId = "Sweep",
			AttackType = "Sweep",
			Tags = { "Sweep", "Melee", "Area", "Heavy" },
			BaseDamage = 45,
			AttackIntervalSeconds = 1.6,
			RangeStuds = WeaponProfiles.SwordShield.Sweep.RangeStuds * 1.4,
			AngleDeg = WeaponProfiles.SwordShield.Sweep.AngleDeg + 15,
			TargetLimit = nil,
		},
	},
}

return WeaponProfiles
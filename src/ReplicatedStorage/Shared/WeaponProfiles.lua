--- WeaponProfiles — Phase 2 Step 1: SwordShield + BasicMagic (임시 마법 근거리 기본 무기 프로파일)
--- BasicMagic 의 실전 수치는 GameConfig + UpgradeData.getEffectiveCombatStats 가 단일 근거다.
--- 이 테이블의 BasicMagic 블록은 식별/문서 목적이다.

local WeaponProfiles = {}

--- 임시 마법 근처 전체범위 무기 — CombatService 에서 UpgradeData 호출 브랜치와 매칭된다.
WeaponProfiles.BasicMagic = {
	Id = "BasicMagic",
	Description = "기존 플레이어 구형 근처 전체 타격; 수치는 getEffectiveCombatStats",
}

WeaponProfiles.SwordShield = {
	Id = "SwordShield",
	--- Step 5-1: 등급 전투 배율 (getSwordShieldEffectiveCombat 에서만 적용).
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
	--- UpgradeData 미사용. 감각 검증용 고정 간격.
	AttackIntervalSeconds = 1,
	--- SwordShield 자동 타겟: HRP 로부터 이내에 있는 적 후보 검색 거리 (없으면 Thrust.RangeStuds 폴백).
	TargetSearchRangeStuds = 14,
	Sweep = {
		AngleDeg = 180,
		RangeStuds = 10,
		BaseDamage = 15,
		Tags = { "Melee", "Shield", "Sweep", "Frontal", "AoE" },
		--- Knockback 은 Enemy Anchored 시 미적용 가능; 향후용 힌트만.
		KnockbackHintStuds = 0,
	},
	Thrust = {
		--- Deprecated (Thrust 판정 미사용): 과거 Cone 각도. 스트립 판정에서는 무시.
		AngleDeg = 15,
		RangeStuds = 6,
		WidthStuds = 3,
		BaseDamage = 30,
		--- Deprecated (Thrust 판정 미사용): 과거 관통 스택. 스트립은 범위 내 전원 타격.
		PierceExtraTargets = 0,
		Tags = { "Melee", "Sword", "Thrust", "Frontal", "Pierce" },
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
		TargetLimit = nil, -- nil 이면 무제한 타격
	},
}

return WeaponProfiles

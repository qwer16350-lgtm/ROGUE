return {
	------------------------------------------------------------
	-- Session
	------------------------------------------------------------
	SessionDurationSeconds = 180,

	------------------------------------------------------------
	-- Player combat (baseline)
	------------------------------------------------------------
	PlayerBaseHealth = 100,
	PlayerBaseAttackIntervalSeconds = 1,
	PlayerAttackRangeStuds = 6,
	-- If ATTACK prefab has no VfxReferenceRadius: k=1 matches hit radius (override via Attribute).
	PlayerAttackVfxReferenceRadiusStuds = 6,
	-- Multiplier on final VFX range scale (1 = off). Use ~1.05 if VFX looks smaller than hitbox.
	PlayerAttackVfxRangeVisualMul = 1,
	PlayerDamagePerHit = 10,

	------------------------------------------------------------
	-- Player damage (enemy part proximity, server)
	------------------------------------------------------------
	EnemyContactDamagePerTick = 8,
	EnemyContactDamageCooldownSeconds = 0.5,
	-- HRP to enemy center: enemy radius (estimate) + this
	EnemyContactReachStuds = 0.6,
	-- If boss is in range during contact tick, multiply damage (1 if grunts only)
	EnemyContactDamageBossMultiplier = 2,
	-- Per-tier 접촉 데미지 sphere 반지름 배수.
	-- threshold = (halfExtent + EnemyContactReachStuds) * 이 표의 티어 값.
	-- 새 티어 추가 시 표만 늘리면 자동 반영. 누락된 티어는 1로 폴백 (서버 측 안전장치).
	-- 티어 키 enum 은 Shared/Config/EnemyTier 참조.
	EnemyContactRadiusMultiplierByTier = {
		Basic   = 1.2,
		Elite   = 1,
		MidBoss = 1,
		Boss    = 1,
	},

	------------------------------------------------------------
	-- Enemy spawn / stats
	------------------------------------------------------------
	EnemyBaseHealth = 40,
	EnemyBaseSpeed = 14,
	EnemySpawnRadiusMin = 35,
	EnemySpawnRadiusMax = 55,
	EnemyGruntSpawnHeight = 3,
	EnemyBossSpawnHeight = 4,
	EnemyBossHealthMultiplier = 5,
	EnemyGruntSize = Vector3.new(2, 2, 2),
	EnemyBossSize = Vector3.new(6, 6, 6),
	-- Enemy body collides with player (set same on prefab after spawn if needed)
	EnemyPartCanCollide = true,
	-- 한 스폰 사이클당 그런트/엘리트 호출 횟수 (=동시 스폰 위치 개수). 보스에는 적용되지 않음.
	EnemyGruntSpawnsPerTick = 2,

	------------------------------------------------------------
	-- Wave (grunt interval lerps Start -> End over session)
	------------------------------------------------------------
	WaveGruntSpawnIntervalStart = 2,
	WaveGruntSpawnIntervalEnd = 0.9,
	-- Ramp: every N seconds the current interval is divided by Multiplier,
	-- then clamped to AfterRampMin. Multiplier = 1 disables the ramp.
	WaveGruntSpawnIntervalRampEverySeconds = 30,
	WaveGruntSpawnIntervalRampMultiplier = 1.3,
	WaveGruntSpawnIntervalAfterRampMin = 0.2,

	------------------------------------------------------------
	-- XP orbs
	------------------------------------------------------------
	XpOrbPerKill = 18,
	-- Tight absorb: orbs usually enter magnet range first, then pull in before XP (not wide instant pickup).
	XpPickupRadiusStuds = 2,
	-- Must be > XpPickupRadiusStuds. Orb uses nearest player HRP only (magnet + pickup).
	XpMagnetRadiusStuds = 8,
	XpMagnetSpeedStudsPerSecond = 28,
	-- Idle only: vertical bob around idleAnchorPosition (XZ fixed). Off during magnet.
	XpOrbBobAmplitudeStuds = 0.375,
	XpOrbBobAngularSpeed = 2.5,
	XpOrbPartDiameter = 1.2,

	------------------------------------------------------------
	-- Health orbs (drops on enemy kill)
	-- 시각·자석·idle bob 파라미터는 XP orb 의 키(XpOrbPartDiameter, XpOrbBob*,
	-- Xp*RadiusStuds, XpMagnetSpeedStudsPerSecond) 를 그대로 공유한다 — 사용자 명시
	-- "XP 와 동일한 외형/움직임" 요구사항. 차등이 필요해지면 Health 전용 키를 분기.
	------------------------------------------------------------
	HealthOrbDropChance = 1 / 30,
	HealthOrbHealPercentOfMaxHp = 0.05,
	HealthOrbColor = Color3.fromRGB(255, 60, 60),

	------------------------------------------------------------
	-- Leveling (XP to next for level L = this * L)
	------------------------------------------------------------
	XpRequiredPerLevelBase = 100,

	------------------------------------------------------------
	-- HUD sync interval
	------------------------------------------------------------
	HudSyncIntervalSeconds = 0.2,
}

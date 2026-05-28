return {
	------------------------------------------------------------
	-- Session
	------------------------------------------------------------
	SessionDurationSeconds = 180,

	------------------------------------------------------------
	------------------------------------------------------------
	Run = {
		DefaultWeaponId = "SwordShield",
	},

	------------------------------------------------------------
	-- Player combat (baseline)
	------------------------------------------------------------
	PlayerBaseHealth = 100,
	PlayerBaseWalkSpeed = 16,
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
	------------------------------------------------------------
	HealthOrbDropChance = 1 / 30,
	HealthOrbHealPercentOfMaxHp = 0.05,
	HealthOrbColor = Color3.fromRGB(255, 60, 60),

	------------------------------------------------------------
	-- Leveling (XP to next for level L = this * L)
	------------------------------------------------------------
	XpRequiredPerLevelBase = 100,

	------------------------------------------------------------
	------------------------------------------------------------
	WeaponDropChance = 0.01,
	Phase3RelicChestDropChance = 0.01,
	RelicStartingSlotMax = 1,

	------------------------------------------------------------
	-- HUD sync interval
	------------------------------------------------------------
	HudSyncIntervalSeconds = 0.2,

	------------------------------------------------------------
	------------------------------------------------------------
	Debug = {
		ShowDevCombatPanel = true,
		ShowAttackRanges = true,
		WeaponDropChanceOverride = nil,
		Phase3RelicChestDropChanceOverride = nil,
		ForcePhase3RelicChestOnKill = false,
		OverrideWeaponId = nil,
		Phase3TestRelicIds = nil,
		Phase3FakeOwnedRelicIds = nil,
		Phase3FakeEquippedStartingRelicIds = {},
		ProgressionVerbose = false,
		-- Lobby RelicProfileService session seed (Studio). nil = empty profile on join.
		RelicProfileTestSeed = nil,
	},
}
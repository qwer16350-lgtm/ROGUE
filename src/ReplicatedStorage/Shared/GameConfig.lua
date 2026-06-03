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
	--- Blueprint discovery drop on enemy kill (minimum).
	BlueprintDropChanceBySourceKind = {
		Normal = 1 / 10000,
		Elite = 1 / 1000,
		Boss = 1 / 10,
	},
	RelicStartingSlotMax = 1,
	------------------------------------------------------------
	-- Lobby relic profile persistence (Step 5A)
	------------------------------------------------------------

	------------------------------------------------------------
	-- Stage run-end RewardBudget (minimum)
	------------------------------------------------------------
	RewardBudget = {
		Enabled = true,
		SuccessBase = 5,
		FailureBase = 2,
		NormalKillsPerBudget = 5,
		EliteKillBudget = 2,
		BossKillBudget = 15,
		FailureBudgetCap = 20,
		BossTargetKillSeconds = 45,
		MaxBossSpeedBonusWindowSeconds = 30,
		SecondsPerBossSpeedPoint = 5,
		BossSpeedMultiplierPerPoint = 0.05,
		CleanBonusMax = 10,
		CorruptedGearGuaranteeCost = 12,
		AncientShardPerMaterialCostValue = 10,
	},
	RelicProfilePersistence = {
		Enabled = true,
		DataStoreName = "PlayerRelicProfile",
		AutosaveIntervalSeconds = 60,
		EquipSaveDebounceSeconds = 5,
		LoadRetryCount = 3,
		SaveRetryCount = 3,
	},

	------------------------------------------------------------
	-- Block defense MVP (enemy contact damage only)
	------------------------------------------------------------
	BlockDefense = {
		BaseBlockChance = 0,
		BlockCooldownSeconds = 3,
	},

	------------------------------------------------------------
	-- Knockback combat (generic effective.Sweep.KnockbackPower)
	------------------------------------------------------------
	KnockbackCombat = {
		DefaultDurationSeconds = 0.20,
	},

	------------------------------------------------------------
	-- HUD sync interval
	------------------------------------------------------------
	HudSyncIntervalSeconds = 0.2,

	------------------------------------------------------------
	------------------------------------------------------------
	Debug = {
		-- Publish-safe defaults. Studio: set true / uncomment seed only for local smoke.
		ShowDevCombatPanel = true,
		ShowAttackRanges = true,
		WeaponDropChanceOverride = nil,
		Phase3RelicChestDropChanceOverride = nil,
		--- nil = tier table. number in [0,1] = uniform override for blueprint drop rolls (Studio smoke).
		BlueprintDropChanceOverride = nil,
		--- nil = policy. number >= 0 = fixed final RewardBudget (Studio smoke).
		RewardBudgetOverride = nil,
		ForcePhase3RelicChestOnKill = false,
		OverrideWeaponId = nil,
		--- Studio block smoke: active at run start (set nil before publish).
		Phase3TestRelicIds = {},
		Phase3FakeOwnedRelicIds = nil,
		Phase3FakeEquippedStartingRelicIds = {},
		ProgressionVerbose = false,
		LogBlockDefense = false,
		LogKnockback = false,
		-- Lobby craft: false = enforce blueprint + materials (Publish). Studio smoke: true.
		RelicCraftSkipRequirements = false,
		-- nil = no merge after DataStore load (Publish). Studio example (uncomment):
		-- RelicProfileTestSeed = { blueprintProgress = { needle_edge = 1 }, ownedRelics = {} },
		RelicProfileTestSeed = nil,
	},
}

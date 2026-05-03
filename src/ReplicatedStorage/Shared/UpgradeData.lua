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

return UpgradeData

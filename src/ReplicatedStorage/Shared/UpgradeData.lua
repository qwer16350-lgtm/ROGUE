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
}

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

return UpgradeData

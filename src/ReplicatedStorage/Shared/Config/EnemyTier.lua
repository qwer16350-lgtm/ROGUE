
local EnemyTier = {}

EnemyTier.Basic   = "Basic"
EnemyTier.Elite   = "Elite"
EnemyTier.MidBoss = "MidBoss"
EnemyTier.Boss    = "Boss"

EnemyTier.Order = { EnemyTier.Basic, EnemyTier.Elite, EnemyTier.MidBoss, EnemyTier.Boss }

function EnemyTier.isValid(t)
	return t == EnemyTier.Basic
		or t == EnemyTier.Elite
		or t == EnemyTier.MidBoss
		or t == EnemyTier.Boss
end

function EnemyTier.isBossFamily(t)
	return t == EnemyTier.MidBoss or t == EnemyTier.Boss
end

return EnemyTier
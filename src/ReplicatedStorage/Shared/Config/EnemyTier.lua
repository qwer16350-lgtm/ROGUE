--- 적 티어 enum + 헬퍼.
--- 정책(데미지 배수 등) 은 이 모듈이 갖지 않는다 — GameConfig 의 By*Tier 표가 정책 소유.
--- 이 모듈은 "어떤 티어가 존재하는지" 와 "한 티어가 보스 계열인지" 만 책임진다.
--- 향후 새 티어 추가 시: 상수 + Order 한 줄 + (필요하면) isBossFamily 갱신 + GameConfig 표만 늘리면 됨.

local EnemyTier = {}

EnemyTier.Basic   = "Basic"
EnemyTier.Elite   = "Elite"
EnemyTier.MidBoss = "MidBoss"
EnemyTier.Boss    = "Boss"

-- 외부 도구 / UI / 가중치 표가 4티어 순서를 안정적으로 알 수 있게 노출.
EnemyTier.Order = { EnemyTier.Basic, EnemyTier.Elite, EnemyTier.MidBoss, EnemyTier.Boss }

function EnemyTier.isValid(t)
	return t == EnemyTier.Basic
		or t == EnemyTier.Elite
		or t == EnemyTier.MidBoss
		or t == EnemyTier.Boss
end

--- 보스 계열(중간보스 / 보스) 여부.
--- 콘택트 데미지 보스 멀티플라이어 등 "보스급" 분기에 사용.
function EnemyTier.isBossFamily(t)
	return t == EnemyTier.MidBoss or t == EnemyTier.Boss
end

return EnemyTier

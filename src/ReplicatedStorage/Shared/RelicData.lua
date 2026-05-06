local RelicData = {}

--- 정적 정의: 수치는 이 모듈에만 둔다.
local DEFINITIONS = {
	old_shield_emblem = {
		Id = "old_shield_emblem",
		Label = "Old Shield Emblem",
		SweepDamageMul = 1.10,
		ThrustDamageMul = 1,
		AttackIntervalMul = 1,
	},
	cracked_sword_tip = {
		Id = "cracked_sword_tip",
		Label = "Cracked Sword Tip",
		SweepDamageMul = 1,
		ThrustDamageMul = 1.10,
		AttackIntervalMul = 1,
	},
	knights_belt = {
		Id = "knights_belt",
		Label = "Knight's Belt",
		SweepDamageMul = 1,
		ThrustDamageMul = 1,
		AttackIntervalMul = 0.80,
	},
}

local OFFER_IDS = { "old_shield_emblem", "cracked_sword_tip", "knights_belt" }

--- Step 4-1: 월드 드롭 없이 Lv6 1회 3택. 수치는 이 테이블에만 둔다.
local DROPPED_DEFINITIONS = {
	reinforced_shield_rim = {
		Id = "reinforced_shield_rim",
		Label = "Reinforced Shield Rim",
		SweepDamageMul = 1.15,
		ThrustDamageMul = 1,
		AttackIntervalMul = 1,
	},
	needle_edge = {
		Id = "needle_edge",
		Label = "Needle Edge",
		SweepDamageMul = 1,
		ThrustDamageMul = 1.15,
		AttackIntervalMul = 1,
	},
	rhythm_strap = {
		Id = "rhythm_strap",
		Label = "Rhythm Strap",
		SweepDamageMul = 1,
		ThrustDamageMul = 1,
		AttackIntervalMul = 0.90,
	},
	shield_spike = {
		Id = "shield_spike",
		Label = "Shield Spike",
		SweepDamageMul = 1,
		ThrustDamageMul = 1,
		AttackIntervalMul = 1,
		Effect = {
			sweepKnockback = true,
			knockbackDistance = 10,
			knockbackForce = 60,
		},
	},
}

local DROPPED_OFFER_IDS = { "reinforced_shield_rim", "needle_edge", "rhythm_strap", "shield_spike" }

-- Dropped Relic offer weight: 슬롯별 "샘플링 가중치" (최종 등장 확률이 아님).
-- 예) 4종 모두 weight=25이고, 중복 없이 3개를 뽑으면 각 relic이 3택에 포함될 확률은 대략 75%.
local DROPPED_OFFER_WEIGHTS = {
	reinforced_shield_rim = 25,
	needle_edge = 25,
	rhythm_strap = 25,
	shield_spike = 25,
}

local function pickWeightedWithoutReplacement(
	ids: { string },
	weightsById: { [string]: number },
	k: number
): { string }
	local pool = {}
	for _, id in ipairs(ids) do
		if type(id) == "string" then
			table.insert(pool, id)
		end
	end

	local out = {}
	k = math.max(0, math.floor(k or 0))
	while #out < k and #pool > 0 do
		local total = 0
		for _, id in ipairs(pool) do
			local w = weightsById[id]
			if type(w) ~= "number" or w <= 0 then
				w = 1
			end
			total += w
		end
		if total <= 0 then
			break
		end
		local r = math.random() * total
		local pickIndex = nil
		for i, id in ipairs(pool) do
			local w = weightsById[id]
			if type(w) ~= "number" or w <= 0 then
				w = 1
			end
			r -= w
			if r <= 0 then
				pickIndex = i
				break
			end
		end
		if not pickIndex then
			pickIndex = #pool
		end
		table.insert(out, pool[pickIndex])
		table.remove(pool, pickIndex)
	end
	return out
end

local function onesMul(): { SweepDamageMul: number, ThrustDamageMul: number, AttackIntervalMul: number }
	return {
		SweepDamageMul = 1,
		ThrustDamageMul = 1,
		AttackIntervalMul = 1,
	}
end

local function mulFromStartingDef(def): { SweepDamageMul: number, ThrustDamageMul: number, AttackIntervalMul: number }
	if not def then
		return onesMul()
	end
	return {
		SweepDamageMul = def.SweepDamageMul,
		ThrustDamageMul = def.ThrustDamageMul,
		AttackIntervalMul = def.AttackIntervalMul,
	}
end

--- SwordShield 레벨업 3택 가중치(Step 3-2). 명시 없는 Id는 Progression 에서 1 취급.
local SWORD_SHIELD_PICK_WEIGHTS_BY_RELIC: { [string]: { [string]: number } } = {
	old_shield_emblem = {
		ss_sweep_angle = 2,
		ss_sweep_damage = 2,
		ss_sweep_range = 2,
	},
	cracked_sword_tip = {
		ss_thrust_damage = 2,
		ss_thrust_range = 2,
	},
	knights_belt = {
		ss_common_cooldown = 2,
	},
}

function RelicData.getSwordShieldUpgradePickWeights(startingRelicId: string?): { [string]: number }
	if type(startingRelicId) ~= "string" then
		return {}
	end
	local t = SWORD_SHIELD_PICK_WEIGHTS_BY_RELIC[startingRelicId]
	if type(t) ~= "table" then
		return {}
	end
	return t
end

function RelicData.getStartingRelicChoices(): { { Id: string, Label: string } }
	local out = {}
	for _, id in ipairs(OFFER_IDS) do
		local def = DEFINITIONS[id]
		if def then
			table.insert(out, { Id = def.Id, Label = def.Label })
		end
	end
	return out
end

function RelicData.getDroppedRelicChoices(): { { Id: string, Label: string } }
	local out = {}
	local pickedIds = pickWeightedWithoutReplacement(DROPPED_OFFER_IDS, DROPPED_OFFER_WEIGHTS, 3)
	if #pickedIds <= 0 then
		pickedIds = DROPPED_OFFER_IDS
	end
	for _, id in ipairs(pickedIds) do
		local def = DROPPED_DEFINITIONS[id]
		if def then
			table.insert(out, { Id = def.Id, Label = def.Label })
		end
	end
	return out
end

function RelicData.getDroppedRelicEffect(droppedRelicId: string?): any
	if type(droppedRelicId) ~= "string" then
		return nil
	end
	local d = DROPPED_DEFINITIONS[droppedRelicId]
	if type(d) ~= "table" then
		return nil
	end
	local eff = d.Effect
	if type(eff) ~= "table" then
		return nil
	end
	return eff
end

--- Starting + Dropped 유물 배율을 곱해 반환. nil/알 수 없는 id 는 1.0.
function RelicData.getCombatMultipliers(
	startingRelicId: string?,
	droppedRelicId: string?
): { SweepDamageMul: number, ThrustDamageMul: number, AttackIntervalMul: number }
	local s = onesMul()
	if type(startingRelicId) == "string" then
		local a = mulFromStartingDef(DEFINITIONS[startingRelicId])
		s.SweepDamageMul *= a.SweepDamageMul
		s.ThrustDamageMul *= a.ThrustDamageMul
		s.AttackIntervalMul *= a.AttackIntervalMul
	end
	if type(droppedRelicId) == "string" then
		local d = DROPPED_DEFINITIONS[droppedRelicId]
		local b = mulFromStartingDef(d)
		s.SweepDamageMul *= b.SweepDamageMul
		s.ThrustDamageMul *= b.ThrustDamageMul
		s.AttackIntervalMul *= b.AttackIntervalMul
	end
	return s
end

return RelicData

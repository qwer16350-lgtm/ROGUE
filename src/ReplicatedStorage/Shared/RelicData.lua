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
}

local DROPPED_OFFER_IDS = { "reinforced_shield_rim", "needle_edge", "rhythm_strap" }

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
	for _, id in ipairs(DROPPED_OFFER_IDS) do
		local def = DROPPED_DEFINITIONS[id]
		if def then
			table.insert(out, { Id = def.Id, Label = def.Label })
		end
	end
	return out
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

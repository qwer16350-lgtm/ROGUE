-- StartingRelic SSOT for SwordShield (Lobby pick → startingRelicId).
-- Run-time relic acquisition uses Phase3RelicChest / RelicDefinitions, not this module.

local RelicData = {}

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

function RelicData.getCombatMultipliers(
	startingRelicId: string?
): { SweepDamageMul: number, ThrustDamageMul: number, AttackIntervalMul: number }
	local s = onesMul()
	if type(startingRelicId) == "string" then
		local a = mulFromStartingDef(DEFINITIONS[startingRelicId])
		s.SweepDamageMul *= a.SweepDamageMul
		s.ThrustDamageMul *= a.ThrustDamageMul
		s.AttackIntervalMul *= a.AttackIntervalMul
	end
	return s
end

return RelicData

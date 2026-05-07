
local UpgradeOfferBuilder = {}

local SPEAR_CHOICE_IDS = {
	"sp_thrust_damage",
	"sp_thrust_range",
	"sp_common_cooldown",
}
local TWO_HANDED_SWORD_CHOICE_IDS = {
	"th_sweep_damage",
	"th_sweep_range",
	"th_common_cooldown",
	"th_sweep_angle",
}
local ATTACK_TYPE_COMMON_CHOICE_IDS = {
	co_thrust_damage = true,
	co_sweep_damage = true,
	co_thrust_range = true,
	co_sweep_range = true,
	co_common_cooldown = true,
}
local PLAYER_SYSTEM_COMMON_CHOICE_IDS = {
	"ab_xp_increase",
	"ab_Health_increase",
	"ab_Speed_increase",
	"mg_Range_increase",
	"ho_Amount_increase",
	"ho_Chance_increase",
}

local function hasActiveSpear(activeWeapons): boolean
	if type(activeWeapons) ~= "table" then
		return false
	end
	return type(activeWeapons.Spear) == "table"
end

local function hasActiveTwoHandedSword(activeWeapons): boolean
	if type(activeWeapons) ~= "table" then
		return false
	end
	return type(activeWeapons.TwoHandedSword) == "table"
end

local function hasActiveSwordShield(activeWeapons): boolean
	if type(activeWeapons) ~= "table" then
		return false
	end
	return type(activeWeapons.SwordShield) == "table"
end

local function hasActiveBasicMagic(activeWeapons): boolean
	if type(activeWeapons) ~= "table" then
		return false
	end
	return type(activeWeapons.BasicMagic) == "table"
end

local function appendSpearChoicesIfOwned(pool, upgradeData, activeWeapons)
	if not hasActiveSpear(activeWeapons) then
		return
	end
	if type(upgradeData) ~= "table" then
		return
	end
	if type(upgradeData.getChoiceForDefinition) ~= "function" then
		return
	end
	local exists = {}
	for _, row in ipairs(pool) do
		if type(row) == "table" and type(row.Id) == "string" then
			exists[row.Id] = true
		end
	end
	for _, choiceId in ipairs(SPEAR_CHOICE_IDS) do
		if not exists[choiceId] then
			local row = upgradeData.getChoiceForDefinition(choiceId)
			if type(row) == "table" and type(row.Id) == "string" and type(row.Label) == "string" then
				table.insert(pool, { Id = row.Id, Label = row.Label })
				exists[row.Id] = true
			end
		end
	end
end

local function appendTwoHandedSwordChoicesIfOwned(pool, upgradeData, activeWeapons)
	if not hasActiveTwoHandedSword(activeWeapons) then
		return
	end
	if type(upgradeData) ~= "table" then
		return
	end
	if type(upgradeData.getChoiceForDefinition) ~= "function" then
		return
	end
	local exists = {}
	for _, row in ipairs(pool) do
		if type(row) == "table" and type(row.Id) == "string" then
			exists[row.Id] = true
		end
	end
	for _, choiceId in ipairs(TWO_HANDED_SWORD_CHOICE_IDS) do
		if not exists[choiceId] then
			local row = upgradeData.getChoiceForDefinition(choiceId)
			if type(row) == "table" and type(row.Id) == "string" and type(row.Label) == "string" then
				table.insert(pool, { Id = row.Id, Label = row.Label })
				exists[row.Id] = true
			end
		end
	end
end

-- AttackTypeCommon damage/range choices are appended together by active weapon eligibility.
local function appendAttackTypeCommonChoicesIfEligible(pool, upgradeData, activeWeapons)
	if type(upgradeData) ~= "table" then
		return
	end
	if type(upgradeData.getChoiceForDefinition) ~= "function" then
		return
	end

	local hasThrustAttack = hasActiveSpear(activeWeapons) or hasActiveSwordShield(activeWeapons)
	local hasSweepAttack = hasActiveTwoHandedSword(activeWeapons) or hasActiveSwordShield(activeWeapons)
	local hasAnyAttackWeapon = hasThrustAttack or hasSweepAttack or hasActiveBasicMagic(activeWeapons)

	if not hasAnyAttackWeapon then
		return
	end

	local exists = {}
	for _, row in ipairs(pool) do
		if type(row) == "table" and type(row.Id) == "string" then
			exists[row.Id] = true
		end
	end

	if hasThrustAttack and not exists["co_thrust_damage"] then
		local row = upgradeData.getChoiceForDefinition("co_thrust_damage")
		if type(row) == "table" and type(row.Id) == "string" and type(row.Label) == "string" then
			if ATTACK_TYPE_COMMON_CHOICE_IDS[row.Id] == true then
				table.insert(pool, { Id = row.Id, Label = row.Label })
				exists[row.Id] = true
			end
		end
	end
	if hasThrustAttack and not exists["co_thrust_range"] then
		local row = upgradeData.getChoiceForDefinition("co_thrust_range")
		if type(row) == "table" and type(row.Id) == "string" and type(row.Label) == "string" then
			if ATTACK_TYPE_COMMON_CHOICE_IDS[row.Id] == true then
				table.insert(pool, { Id = row.Id, Label = row.Label })
				exists[row.Id] = true
			end
		end
	end

	if hasSweepAttack and not exists["co_sweep_damage"] then
		local row = upgradeData.getChoiceForDefinition("co_sweep_damage")
		if type(row) == "table" and type(row.Id) == "string" and type(row.Label) == "string" then
			if ATTACK_TYPE_COMMON_CHOICE_IDS[row.Id] == true then
				table.insert(pool, { Id = row.Id, Label = row.Label })
				exists[row.Id] = true
			end
		end
	end
	if hasSweepAttack and not exists["co_sweep_range"] then
		local row = upgradeData.getChoiceForDefinition("co_sweep_range")
		if type(row) == "table" and type(row.Id) == "string" and type(row.Label) == "string" then
			if ATTACK_TYPE_COMMON_CHOICE_IDS[row.Id] == true then
				table.insert(pool, { Id = row.Id, Label = row.Label })
				exists[row.Id] = true
			end
		end
	end

	if hasAnyAttackWeapon and not exists["co_common_cooldown"] then
		local row = upgradeData.getChoiceForDefinition("co_common_cooldown")
		if type(row) == "table" and type(row.Id) == "string" and type(row.Label) == "string" then
			if ATTACK_TYPE_COMMON_CHOICE_IDS[row.Id] == true then
				table.insert(pool, { Id = row.Id, Label = row.Label })
				exists[row.Id] = true
			end
		end
	end
end

local function appendPlayerSystemCommonChoices(pool, upgradeData)
	if type(upgradeData) ~= "table" then
		return
	end
	if type(upgradeData.getChoiceForDefinition) ~= "function" then
		return
	end
	local exists = {}
	for _, row in ipairs(pool) do
		if type(row) == "table" and type(row.Id) == "string" then
			exists[row.Id] = true
		end
	end
	for _, choiceId in ipairs(PLAYER_SYSTEM_COMMON_CHOICE_IDS) do
		if not exists[choiceId] then
			local row = upgradeData.getChoiceForDefinition(choiceId)
			if type(row) == "table" and type(row.Id) == "string" and type(row.Label) == "string" then
				table.insert(pool, { Id = row.Id, Label = row.Label })
				exists[row.Id] = true
			end
		end
	end
end

local function weightForChoice(choice: { Id: string, Label: string }, weightsMap: { [string]: number }): number
	local w = weightsMap[choice.Id]
	if type(w) == "number" and w > 0 then
		return w
	end
	return 1
end

function UpgradeOfferBuilder.weightedPickThreeSwordShieldChoices(
	pool: { { Id: string, Label: string } },
	startingRelicId: string?,
	relicDataModule: { getSwordShieldUpgradePickWeights: (string?) -> { [string]: number } }?
): { { Id: string, Label: string } }
	local n = #pool
	if n < 3 then
		error("[UpgradeOfferBuilder] level-up choice pool must have at least 3 entries")
	end
	local weightsMap: { [string]: number } = {}
	if relicDataModule then
		weightsMap = relicDataModule.getSwordShieldUpgradePickWeights(startingRelicId)
	end
	if type(weightsMap) ~= "table" then
		weightsMap = {}
	end

	local remaining = {}
	for i = 1, n do
		remaining[i] = pool[i]
	end

	local picked: { { Id: string, Label: string } } = {}
	for _ = 1, 3 do
		local total = 0
		local effW: { number } = {}
		for i, choice in ipairs(remaining) do
			local w = weightForChoice(choice, weightsMap)
			effW[i] = w
			total += w
		end
		if total <= 0 then
			total = 0
			for i = 1, #remaining do
				effW[i] = 1
				total += 1
			end
		end

		local r = math.random() * total
		local acc = 0
		local pickIdx = #remaining
		for i = 1, #remaining do
			acc += effW[i]
			if r < acc then
				pickIdx = i
				break
			end
		end

		local ch = remaining[pickIdx]
		table.insert(picked, { Id = ch.Id, Label = ch.Label })
		table.remove(remaining, pickIdx)
	end
	return picked
end

function UpgradeOfferBuilder.buildUpgradeOffer(
	poolWeaponId: string,
	startingRelicId: string?,
	upgradeData: any,
	relicDataModule: { getSwordShieldUpgradePickWeights: (string?) -> { [string]: number } }?,
	options: any?
): ({ { Id: string, Label: string } }, { [string]: boolean })
	local activeWeapons = nil
	if type(options) == "table" then
		activeWeapons = options.activeWeapons
	end

	if poolWeaponId == "SwordShield" then
		local pool = {}
		for _, choice in ipairs(upgradeData.SwordShieldChoices) do
			table.insert(pool, { Id = choice.Id, Label = choice.Label })
		end
		appendSpearChoicesIfOwned(pool, upgradeData, activeWeapons)
		appendTwoHandedSwordChoicesIfOwned(pool, upgradeData, activeWeapons)
		appendAttackTypeCommonChoicesIfEligible(pool, upgradeData, activeWeapons)
		appendPlayerSystemCommonChoices(pool, upgradeData)
		local picked = UpgradeOfferBuilder.weightedPickThreeSwordShieldChoices(
			pool,
			startingRelicId,
			relicDataModule
		)
		local allowed = {}
		for _, row in ipairs(picked) do
			allowed[row.Id] = true
		end
		return picked, allowed
	end

	local picked = {}
	for _, choice in ipairs(upgradeData.Choices) do
		table.insert(picked, { Id = choice.Id, Label = choice.Label })
	end
	appendSpearChoicesIfOwned(picked, upgradeData, activeWeapons)
	appendTwoHandedSwordChoicesIfOwned(picked, upgradeData, activeWeapons)
	appendAttackTypeCommonChoicesIfEligible(picked, upgradeData, activeWeapons)
	appendPlayerSystemCommonChoices(picked, upgradeData)
	local allowed = {}
	for _, row in ipairs(picked) do
		allowed[row.Id] = true
	end
	return picked, allowed
end

return UpgradeOfferBuilder
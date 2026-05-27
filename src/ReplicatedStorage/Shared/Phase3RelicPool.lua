-- Phase 3 relic offer pool (RelicDefinitions). Not RelicData.

local RelicDefinitions = require(script.Parent:WaitForChild("RelicDefinitions"))

local Phase3RelicPool = {}

local POOL_BY_WEAPON_ID: { [string]: { string } } = {
	TwoHandedSword = {
		"mercenarys_baldric",
		"shattering_light",
		"last_giants_claw",
	},
	Spear = {
		"needle_edge",
	},
	SwordShield = {
		"run_reinforced_rim",
		"run_rhythm_harness",
	},
	BasicMagic = {},
}

local function ownedSet(alreadyOwnedIds: { string }?): { [string]: boolean }
	local set: { [string]: boolean } = {}
	if type(alreadyOwnedIds) ~= "table" then
		return set
	end
	for _, relicId in ipairs(alreadyOwnedIds) do
		if type(relicId) == "string" and relicId ~= "" then
			set[relicId] = true
		end
	end
	return set
end

local function sortWeaponIds(weaponIds: { string }?): { string }
	local out: { string } = {}
	if type(weaponIds) ~= "table" then
		return out
	end
	for _, weaponId in ipairs(weaponIds) do
		if type(weaponId) == "string" and weaponId ~= "" then
			table.insert(out, weaponId)
		end
	end
	table.sort(out)
	return out
end

local function choiceFromRelicId(relicId: string): { Id: string, Label: string, Description: string }?
	local def = RelicDefinitions.getDefinition(relicId)
	if type(def) ~= "table" then
		return nil
	end
	local label = def.label
	if type(label) ~= "string" or label == "" then
		label = relicId
	end
	local description = def.description
	if type(description) ~= "string" then
		description = ""
	end
	return {
		Id = relicId,
		Label = label,
		Description = description,
	}
end

local function buildPerWeaponQueues(
	sortedWeaponIds: { string },
	owned: { [string]: boolean }
): { { string } }
	local queues: { { string } } = {}
	for _, weaponId in ipairs(sortedWeaponIds) do
		local q: { string } = {}
		for _, relicId in ipairs(Phase3RelicPool.getRelicIdsForWeapon(weaponId)) do
			if not owned[relicId] and choiceFromRelicId(relicId) ~= nil then
				table.insert(q, relicId)
			end
		end
		if #q > 0 then
			table.insert(queues, q)
		end
	end
	return queues
end

local function pickRelicIdsRoundRobin(queues: { { string } }, limit: number): { string }
	local out: { string } = {}
	if limit <= 0 or #queues == 0 then
		return out
	end
	local indices: { number } = {}
	for i = 1, #queues do
		indices[i] = 1
	end
	while #out < limit do
		local progressed = false
		for i, q in ipairs(queues) do
			local idx = indices[i]
			if idx <= #q then
				table.insert(out, q[idx])
				indices[i] = idx + 1
				progressed = true
				if #out >= limit then
					break
				end
			end
		end
		if not progressed then
			break
		end
	end
	return out
end

function Phase3RelicPool.getRelicIdsForWeapon(weaponId: string?): { string }
	if type(weaponId) ~= "string" or weaponId == "" then
		return {}
	end
	local pool = POOL_BY_WEAPON_ID[weaponId]
	if type(pool) ~= "table" then
		return {}
	end
	local out: { string } = {}
	for _, relicId in ipairs(pool) do
		if type(relicId) == "string" and relicId ~= "" then
			table.insert(out, relicId)
		end
	end
	return out
end

function Phase3RelicPool.getRelicIdsForWeapons(weaponIds: { string }?): { string }
	local sorted = sortWeaponIds(weaponIds)
	local seen: { [string]: boolean } = {}
	local out: { string } = {}
	for _, weaponId in ipairs(sorted) do
		for _, relicId in ipairs(Phase3RelicPool.getRelicIdsForWeapon(weaponId)) do
			if not seen[relicId] then
				seen[relicId] = true
				table.insert(out, relicId)
			end
		end
	end
	return out
end

function Phase3RelicPool.buildOfferChoicesForWeapons(
	weaponIds: { string }?,
	alreadyOwnedIds: { string }?,
	maxCount: number?
): { { Id: string, Label: string, Description: string } }
	local limit = 3
	if type(maxCount) == "number" and maxCount > 0 then
		limit = math.floor(maxCount + 0.5)
	end

	local sorted = sortWeaponIds(weaponIds)
	if #sorted == 0 then
		return {}
	end

	local owned = ownedSet(alreadyOwnedIds)
	local queues = buildPerWeaponQueues(sorted, owned)
	local pickedIds = pickRelicIdsRoundRobin(queues, limit)

	local out: { { Id: string, Label: string, Description: string } } = {}
	local seen: { [string]: boolean } = {}
	for _, relicId in ipairs(pickedIds) do
		if not seen[relicId] then
			seen[relicId] = true
			local choice = choiceFromRelicId(relicId)
			if choice ~= nil then
				table.insert(out, choice)
			end
		end
	end
	return out
end

function Phase3RelicPool.buildOfferChoices(
	weaponId: string?,
	alreadyOwnedIds: { string }?,
	maxCount: number?
): { { Id: string, Label: string, Description: string } }
	local ids: { string } = {}
	if type(weaponId) == "string" and weaponId ~= "" then
		table.insert(ids, weaponId)
	end
	return Phase3RelicPool.buildOfferChoicesForWeapons(ids, alreadyOwnedIds, maxCount)
end

function Phase3RelicPool.hasAvailableChoicesForWeapons(weaponIds: { string }?, alreadyOwnedIds: { string }?): boolean
	return #Phase3RelicPool.buildOfferChoicesForWeapons(weaponIds, alreadyOwnedIds, 3) > 0
end

function Phase3RelicPool.hasAvailableChoicesForWeapon(weaponId: string?, alreadyOwnedIds: { string }?): boolean
	local ids: { string } = {}
	if type(weaponId) == "string" and weaponId ~= "" then
		table.insert(ids, weaponId)
	end
	return Phase3RelicPool.hasAvailableChoicesForWeapons(ids, alreadyOwnedIds)
end

return Phase3RelicPool

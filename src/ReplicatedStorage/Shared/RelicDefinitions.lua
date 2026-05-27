-- Phase 3 MVP relic definition SSOT draft.
-- This module does not apply combat effects by itself.
-- Existing RelicData remains the Phase 2 runtime relic path.
-- Only schema-safe candidates are registered here.
-- Combat/Progression integration is a later milestone.

local RelicDefinitions = {}

RelicDefinitions.ALLOWED_STATS = {
	sweepBaseDamage = true,
	thrustBaseDamage = true,
	attackIntervalSeconds = true,
	blockChance = true,
	attackHitCount = true,
}

RelicDefinitions.ALLOWED_OPERATIONS = {
	mul = true,
	add = true,
}

RelicDefinitions.ALLOWED_IMPLEMENTATION_TIERS = {
	A = true,
	B = true,
	C = true,
	D = true,
	E = true,
}

RelicDefinitions.ALLOWED_MVP_PRIORITIES = {
	High = true,
	Medium = true,
	Low = true,
	Hold = true,
}

local TAG_ARRAY_KEYS = {
	"classTags",
	"effectTargetTags",
	"modifierTags",
	"triggerTags",
	"obtainTags",
	"unlockTags",
}

local FORBIDDEN_TAG_LITERALS = {
	none = true,
	["-"] = true,
}

RelicDefinitions.DefinitionsById = {
	mercenarys_baldric = {
		id = "mercenarys_baldric",
		sourceRow = 9,
		label = "mercenary's baldric",
		relicGroup = "Weapon-based relic (무기 유물)",
		description = "Sweep 계열 가중치 증가\nSweep 피해 ×1.10",
		classTags = { "Slayer" },
		effectTargetTags = { "th" },
		modifierTags = { "Damage" },
		triggerTags = {},
		obtainTags = { "Crafted" },
		unlockTags = { "Blueprint" },
		stackTags = "Upgradeable",
		requiredMaterials = "",
		classTagMatch = "TRUE",
		implementationTier = "A",
		mvpPriority = "High",
		modifiers = {
			{
				kind = "stat",
				targetTags = {
					weaponTag = "th",
					attackTag = "sweep",
				},
				stat = "sweepBaseDamage",
				operation = "mul",
				value = 1.10,
				requiresTuning = false,
				notes = "",
			},
		},
		notes = "",
	},
	shattering_light = {
		id = "shattering_light",
		sourceRow = 7,
		label = "Shattering Light",
		sourceLabel = "TwoHandedSword",
		relicGroup = "Weapon-based relic (무기 유물)",
		description = "TwoHandedSword Sweep 공격 대미지 50%감소 (현재 기준)\nTwoHandedSword AttackCooldown 30% 감소 (현재 기준)",
		classTags = { "Slayer" },
		effectTargetTags = { "th" },
		modifierTags = { "Damage", "Cooldown" },
		triggerTags = {},
		obtainTags = { "Crafted" },
		unlockTags = { "Blueprint" },
		stackTags = "Stackable",
		requiredMaterials = "",
		classTagMatch = "TRUE",
		implementationTier = "A",
		mvpPriority = "High",
		modifiers = {
			{
				kind = "stat",
				targetTags = {
					weaponTag = "th",
					attackTag = "sweep",
				},
				stat = "sweepBaseDamage",
				operation = "mul",
				value = 0.5,
				requiresTuning = false,
				notes = "Sweep 대미지 50% 감소",
			},
			{
				kind = "stat",
				targetTags = {
					weaponTag = "th",
					attackTag = "sweep",
				},
				stat = "attackIntervalSeconds",
				operation = "mul",
				value = 0.7,
				requiresTuning = false,
				notes = "AttackCooldown 30% 감소",
			},
		},
		notes = "RL.TAGS row #7; display label renamed from excel placeholder TwoHandedSword.",
	},
	last_giants_claw = {
		id = "last_giants_claw",
		sourceRow = 8,
		label = "Last Giant's Claw",
		sourceLabel = "TwoHandedSword",
		relicGroup = "Weapon-based relic (무기 유물)",
		description = "TwoHandedSword Sweep 공격 대미지 40% 증가 (현재 기준)\nTwoHandedSword AttackCooldown 30% 증가 (현재 기준)",
		classTags = { "Slayer" },
		effectTargetTags = { "th" },
		modifierTags = { "Damage", "Cooldown" },
		triggerTags = {},
		obtainTags = { "Crafted" },
		unlockTags = { "Blueprint" },
		stackTags = "Stackable",
		requiredMaterials = "",
		classTagMatch = "TRUE",
		implementationTier = "A",
		mvpPriority = "Medium",
		modifiers = {
			{
				kind = "stat",
				targetTags = {
					weaponTag = "th",
					attackTag = "sweep",
				},
				stat = "sweepBaseDamage",
				operation = "mul",
				value = 1.4,
				requiresTuning = false,
				notes = "RL.TAGS row 8: Sweep damage +40%",
			},
			{
				kind = "stat",
				targetTags = {
					weaponTag = "th",
					attackTag = "sweep",
				},
				stat = "attackIntervalSeconds",
				operation = "mul",
				value = 1.3,
				requiresTuning = false,
				notes = "RL.TAGS row 8: AttackCooldown +30%",
			},
		},
		notes = "RL.TAGS row #8; label is Last Giant's Claw (not excel placeholder TwoHandedSword).",
	},
	needle_edge = {
		id = "needle_edge",
		sourceRow = 27,
		label = "Needle Edge",
		relicGroup = "Ability/tag-based relic (능력 유물)",
		description = "Thrust 계열 가중치 증가\nThrust 피해 ×1.10",
		classTags = { "Lancer" },
		effectTargetTags = { "thrust" },
		modifierTags = { "Damage" },
		triggerTags = {},
		obtainTags = { "Crafted" },
		unlockTags = { "Blueprint" },
		stackTags = "Stackable",
		requiredMaterials = "",
		classTagMatch = "TRUE",
		implementationTier = "A",
		mvpPriority = "Medium",
		modifiers = {
			{
				kind = "stat",
				targetTags = {
					weaponTag = "sp",
					attackTag = "thrust",
				},
				stat = "thrustBaseDamage",
				operation = "mul",
				value = 1.10,
				requiresTuning = false,
				notes = "Excel ×1.10; RelicData ThrustDamageMul 1.15 is legacy, not Phase 3 SSOT.",
			},
		},
		notes = "RL.TAGS row #27; Spear-only via weaponTag sp.",
	},
	run_reinforced_rim = {
		id = "run_reinforced_rim",
		sourceRow = 13,
		label = "Reinforced Rim",
		relicGroup = "Weapon-based relic (무기 유물)",
		description = "SwordShield Sweep 피해 ×1.15 (런 획득)",
		classTags = { "Guardian" },
		effectTargetTags = { "ss", "sweep" },
		modifierTags = { "Damage" },
		triggerTags = {},
		obtainTags = { "Crafted" },
		unlockTags = { "Blueprint" },
		stackTags = "Stackable",
		requiredMaterials = "",
		classTagMatch = "TRUE",
		implementationTier = "A",
		mvpPriority = "Medium",
		modifiers = {
			{
				kind = "stat",
				targetTags = {
					weaponTag = "ss",
					attackTag = "sweep",
				},
				stat = "sweepBaseDamage",
				operation = "mul",
				value = 1.15,
				requiresTuning = false,
				notes = "Phase3 run relic; not StartingRelic reinforced_shield_rim id.",
			},
		},
		notes = "Phase3RelicChest; legacy dropped concept via new id.",
	},
	run_rhythm_harness = {
		id = "run_rhythm_harness",
		sourceRow = 11,
		label = "Rhythm Harness",
		relicGroup = "Weapon-based relic (무기 유물)",
		description = "SwordShield 공격 간격 ×0.90 (런 획득)",
		classTags = { "Guardian" },
		effectTargetTags = { "ss" },
		modifierTags = { "Cooldown" },
		triggerTags = {},
		obtainTags = { "Crafted" },
		unlockTags = { "Blueprint" },
		stackTags = "Unique",
		requiredMaterials = "",
		classTagMatch = "TRUE",
		implementationTier = "A",
		mvpPriority = "Medium",
		modifiers = {
			{
				kind = "stat",
				targetTags = {
					weaponTag = "ss",
				},
				stat = "attackIntervalSeconds",
				operation = "mul",
				value = 0.90,
				requiresTuning = false,
				notes = "Weapon-wide interval; attackTag omitted.",
			},
		},
		notes = "Phase3RelicChest; legacy rhythm_strap concept via new id.",
	},
}

local function isStringArray(t: any): boolean
	if type(t) ~= "table" then
		return false
	end
	for _, v in ipairs(t) do
		if type(v) ~= "string" or v == "" then
			return false
		end
	end
	return true
end

local function warnForbiddenTagLiterals(warnings: { string }, relicId: string, fieldName: string, arr: any)
	if type(arr) ~= "table" then
		return
	end
	for _, v in ipairs(arr) do
		if type(v) == "string" and FORBIDDEN_TAG_LITERALS[v:lower()] then
			table.insert(
				warnings,
				string.format(
					"[RelicDefinitions] %s: %s contains forbidden tag literal %q",
					relicId,
					fieldName,
					v
				)
			)
		end
	end
end

local function validateTargetTags(warnings: { string }, relicId: string, modIndex: number, targetTags: any): boolean
	if type(targetTags) ~= "table" then
		table.insert(
			warnings,
			string.format("[RelicDefinitions] %s: modifiers[%d].targetTags must be a table", relicId, modIndex)
		)
		return false
	end
	return true
end

local function validateModifier(warnings: { string }, relicId: string, modIndex: number, mod: any): boolean
	if type(mod) ~= "table" then
		table.insert(warnings, string.format("[RelicDefinitions] %s: modifiers[%d] must be a table", relicId, modIndex))
		return false
	end

	if not validateTargetTags(warnings, relicId, modIndex, mod.targetTags) then
		return false
	end

	local stat = mod.stat
	if type(stat) ~= "string" or RelicDefinitions.ALLOWED_STATS[stat] ~= true then
		table.insert(
			warnings,
			string.format("[RelicDefinitions] %s: modifiers[%d].stat invalid %s", relicId, modIndex, tostring(stat))
		)
	end

	local op = mod.operation
	if type(op) ~= "string" or RelicDefinitions.ALLOWED_OPERATIONS[op] ~= true then
		table.insert(
			warnings,
			string.format(
				"[RelicDefinitions] %s: modifiers[%d].operation invalid %s",
				relicId,
				modIndex,
				tostring(op)
			)
		)
	end

	local value = mod.value
	if value ~= nil and type(value) ~= "number" then
		table.insert(
			warnings,
			string.format("[RelicDefinitions] %s: modifiers[%d].value must be nil or number", relicId, modIndex)
		)
	end

	if type(mod.requiresTuning) ~= "boolean" then
		table.insert(
			warnings,
			string.format("[RelicDefinitions] %s: modifiers[%d].requiresTuning must be boolean", relicId, modIndex)
		)
	end

	return true
end

function RelicDefinitions.getDefinition(id: string): any
	if type(id) ~= "string" or id == "" then
		return nil
	end
	return RelicDefinitions.DefinitionsById[id]
end

function RelicDefinitions.hasDefinition(id: string): boolean
	return RelicDefinitions.getDefinition(id) ~= nil
end

--- Returns ok, list of warning strings (empty when ok). Does not error on require.
function RelicDefinitions.validate(): (boolean, { string })
	local warnings: { string } = {}

	for key, row in pairs(RelicDefinitions.DefinitionsById) do
		if type(row) ~= "table" then
			table.insert(warnings, string.format("[RelicDefinitions] DefinitionsById[%s] is not a table", tostring(key)))
			continue
		end

		if row.id ~= key then
			table.insert(
				warnings,
				string.format("[RelicDefinitions] key %s ~= row.id %s", tostring(key), tostring(row.id))
			)
		end

		if type(row.sourceRow) ~= "number" then
			table.insert(warnings, string.format("[RelicDefinitions] %s: sourceRow must be a number", tostring(key)))
		end

		if type(row.label) ~= "string" or row.label == "" then
			table.insert(warnings, string.format("[RelicDefinitions] %s: label must be a non-empty string", tostring(key)))
		end

		if row.sourceLabel ~= nil and type(row.sourceLabel) ~= "string" then
			table.insert(warnings, string.format("[RelicDefinitions] %s: sourceLabel must be a string", tostring(key)))
		end

		if row.originalExcelLabel ~= nil and type(row.originalExcelLabel) ~= "string" then
			table.insert(
				warnings,
				string.format("[RelicDefinitions] %s: originalExcelLabel must be a string", tostring(key))
			)
		end

		local tier = row.implementationTier
		if type(tier) ~= "string" or RelicDefinitions.ALLOWED_IMPLEMENTATION_TIERS[tier] ~= true then
			table.insert(
				warnings,
				string.format("[RelicDefinitions] %s: invalid implementationTier %s", tostring(key), tostring(tier))
			)
		end

		local mvp = row.mvpPriority
		if type(mvp) ~= "string" or RelicDefinitions.ALLOWED_MVP_PRIORITIES[mvp] ~= true then
			table.insert(
				warnings,
				string.format("[RelicDefinitions] %s: invalid mvpPriority %s", tostring(key), tostring(mvp))
			)
		end

		for _, arrKey in ipairs(TAG_ARRAY_KEYS) do
			local arr = row[arrKey]
			if arr == nil then
				table.insert(warnings, string.format("[RelicDefinitions] %s: missing %s", tostring(key), arrKey))
			elseif not isStringArray(arr) then
				table.insert(
					warnings,
					string.format(
						"[RelicDefinitions] %s: %s must be array of non-empty strings",
						tostring(key),
						arrKey
					)
				)
			else
				warnForbiddenTagLiterals(warnings, tostring(key), arrKey, arr)
			end
		end

		if type(row.modifiers) ~= "table" then
			table.insert(warnings, string.format("[RelicDefinitions] %s: modifiers must be a table", tostring(key)))
		else
			for i, mod in ipairs(row.modifiers) do
				validateModifier(warnings, tostring(key), i, mod)
			end
		end
	end

	local ok = #warnings == 0
	return ok, warnings
end

return RelicDefinitions

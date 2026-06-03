-- Phase 3 MVP relic definition SSOT draft.
-- This module does not apply combat effects by itself.
-- Run combat: RelicModifierApplicator + phase3ActiveRelicIds (RelicData removed 7C-3).
-- Only schema-safe candidates are registered here.
-- Combat/Progression integration is a later milestone.
-- Meta progression fields (blueprintId, craftCost, is*Eligible) are dead until Step 3+.
-- RelicModifierApplicator / Phase3RelicPool / ProgressionService do not read them yet.

local RelicDefinitions = {}

RelicDefinitions.ALLOWED_STATS = {
	sweepBaseDamage = true,
	thrustBaseDamage = true,
	thrustRangeStuds = true,
	attackIntervalSeconds = true,
	blockChance = true,
	attackHitCount = true,
	knockbackPower = true,
}

RelicDefinitions.ALLOWED_OPERATIONS = {
	mul = true,
	add = true,
	openOrAdd = true,
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
		relicGroup = "Weapon-based relic (Weapon relic)",
		description = "Sweep ??????????????\nSweep ???? ??.10",
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
		blueprintId = "mercenarys_baldric",
		craftCost = {
			blueprintProgressMin = 1,
			materials = {},
		},
		isCraftable = true,
		isStartingEligible = false,
		isRunChestEligible = true,
		isPermanentUnlockable = true,
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
		relicGroup = "Weapon-based relic (Weapon relic)",
		description = "TwoHandedSword Sweep ?????????? 50%????(??? ???)\nTwoHandedSword AttackCooldown 30% ????(??? ???)",
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
		blueprintId = "shattering_light",
		craftCost = {
			blueprintProgressMin = 1,
			materials = {},
		},
		isCraftable = true,
		isStartingEligible = false,
		isRunChestEligible = true,
		isPermanentUnlockable = true,
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
				notes = "Sweep damage mul 0.5.",
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
				notes = "Attack interval mul 0.7.",
			},
		},
		notes = "RL.TAGS row #7; display label renamed from excel placeholder TwoHandedSword.",
	},
	last_giants_claw = {
		id = "last_giants_claw",
		sourceRow = 8,
		label = "Last Giant's Claw",
		sourceLabel = "TwoHandedSword",
		relicGroup = "Weapon-based relic (Weapon relic)",
		description = "TwoHandedSword Sweep ?????????? 40% ??? (??? ???)\nTwoHandedSword AttackCooldown 30% ??? (??? ???)",
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
		blueprintId = "last_giants_claw",
		craftCost = {
			blueprintProgressMin = 1,
			materials = {},
		},
		isCraftable = true,
		isStartingEligible = false,
		isRunChestEligible = true,
		isPermanentUnlockable = true,
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
		relicGroup = "Ability/tag-based relic (Ability relic)",
		description = "Thrust ??????????????\nThrust ???? ??.10",
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
		blueprintId = "needle_edge",
		craftCost = {
			blueprintProgressMin = 1,
			materials = {},
		},
		isCraftable = true,
		isStartingEligible = false,
		isRunChestEligible = true,
		isPermanentUnlockable = true,
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
				notes = "Excel ??.10; RelicData ThrustDamageMul 1.15 is legacy, not Phase 3 SSOT.",
			},
		},
		notes = "RL.TAGS row #27; Spear-only via weaponTag sp.",
	},
	giants_pike = {
		id = "giants_pike",
		sourceRow = 16,
		label = "Giant's Pike",
		relicGroup = "Weapon-based relic (Weapon relic)",
		description = "Spear Thrust ???????.0",
		classTags = { "Lancer" },
		effectTargetTags = { "sp", "thrust" },
		modifierTags = { "Range" },
		triggerTags = {},
		obtainTags = { "Crafted" },
		unlockTags = { "Blueprint" },
		stackTags = "Stackable",
		requiredMaterials = "",
		classTagMatch = "TRUE",
		implementationTier = "B",
		mvpPriority = "Medium",
		blueprintId = "giants_pike",
		craftCost = {
			blueprintProgressMin = 1,
			materials = {},
		},
		isCraftable = true,
		isStartingEligible = false,
		isRunChestEligible = true,
		isPermanentUnlockable = true,
		modifiers = {
			{
				kind = "stat",
				targetTags = {
					weaponTag = "sp",
					attackTag = "thrust",
				},
				stat = "thrustRangeStuds",
				operation = "mul",
				value = 2.0,
				requiresTuning = false,
				notes = "Spear thrust range x2.0",
			},
		},
		notes = "RL.TAGS row #16; Phase3 post-apply on Thrust.RangeStuds (not snapshot).",
	},
	run_reinforced_rim = {
		id = "run_reinforced_rim",
		sourceRow = 13,
		label = "Reinforced Shield Rim",
		relicGroup = "Weapon-based relic (Weapon relic)",
		description = "Block chance increase",
		classTags = { "Guardian" },
		effectTargetTags = { "block" },
		modifierTags = { "Block_chance" },
		triggerTags = {},
		obtainTags = { "Crafted" },
		unlockTags = { "Blueprint" },
		stackTags = "Stackable",
		requiredMaterials = "",
		classTagMatch = "TRUE",
		implementationTier = "A",
		mvpPriority = "Medium",
		blueprintId = "run_reinforced_rim",
		craftCost = {
			blueprintProgressMin = 1,
			materials = {},
		},
		isCraftable = true,
		isStartingEligible = false,
		isRunChestEligible = true,
		isPermanentUnlockable = true,
		modifiers = {
			{
				kind = "stat",
				targetTags = {},
				stat = "blockChance",
				operation = "openOrAdd",
				openValue = 0.05,
				addValue = 0.10,
				requiresTuning = false,
				notes = "Excel RL.TAGS #13; 0% -> open 5%, else +10%p via BlockChanceResolver.",
			},
		},
		notes = "Excel RL.TAGS row #13; generic blockChance sample; run chest id unchanged.",
	},
	run_shield_spike = {
		id = "run_shield_spike",
		sourceRow = 18,
		label = "Shield Spike",
		relicGroup = "Weapon-based relic (Weapon relic)",
		description = "ss_sweep: add Knockback Power (generic stat pipeline)",
		classTags = { "Guardian" },
		effectTargetTags = { "ss", "sweep" },
		modifierTags = { "Knockback_Power" },
		triggerTags = {},
		obtainTags = { "Crafted" },
		unlockTags = { "Blueprint" },
		stackTags = "Stackable",
		requiredMaterials = "",
		classTagMatch = "TRUE",
		implementationTier = "A",
		mvpPriority = "Medium",
		blueprintId = "run_shield_spike",
		craftCost = {
			blueprintProgressMin = 1,
			materials = {},
		},
		isCraftable = true,
		isStartingEligible = false,
		isRunChestEligible = true,
		isPermanentUnlockable = true,
		modifiers = {
			{
				kind = "stat",
				targetTags = {
					weaponTag = "ss",
					attackTag = "sweep",
				},
				stat = "knockbackPower",
				operation = "add",
				value = 60,
				requiresTuning = false,
				notes = "Excel RL.TAGS #18 Knockback_Power; initial 60 (Phase 2 legacy, subject to tuning).",
			},
		},
		notes = "Excel sourceName Shield Spike; Paladin class tag mapped to Guardian metadata; ss+sweep knockback sample.",
	},
	run_rhythm_harness = {
		id = "run_rhythm_harness",
		sourceRow = 11,
		label = "Rhythm Harness",
		relicGroup = "Weapon-based relic (Weapon relic)",
		description = "SwordShield ???????????.90 (??????)",
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
		blueprintId = "run_rhythm_harness",
		craftCost = {
			blueprintProgressMin = 1,
			materials = {},
		},
		isCraftable = true,
		isStartingEligible = false,
		isRunChestEligible = true,
		isPermanentUnlockable = true,
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
	old_shield_emblem = {
		id = "old_shield_emblem",
		sourceRow = 29,
		label = "Old Shield Emblem",
		relicGroup = "Ability/tag-based relic (Ability relic)",
		description = "SwordShield Sweep ???? ??.10 (RelicData 7C-1 migrate)",
		classTags = { "Guardian" },
		effectTargetTags = { "ss", "sweep" },
		modifierTags = { "Damage" },
		triggerTags = {},
		obtainTags = { "Crafted" },
		unlockTags = { "Blueprint" },
		stackTags = "Upgradeable",
		requiredMaterials = "",
		classTagMatch = "TRUE",
		implementationTier = "A",
		mvpPriority = "Medium",
		blueprintId = "old_shield_emblem",
		craftCost = {
			blueprintProgressMin = 1,
			materials = {},
		},
		isCraftable = true,
		isStartingEligible = false,
		isRunChestEligible = false,
		isPermanentUnlockable = true,
		modifiers = {
			{
				kind = "stat",
				targetTags = {
					weaponTag = "ss",
					attackTag = "sweep",
				},
				stat = "sweepBaseDamage",
				operation = "mul",
				value = 1.10,
				requiresTuning = false,
				notes = "7C-1: RelicData SweepDamageMul 1.10 parity.",
			},
		},
		notes = "7C-1 migrated from RelicData; not in Phase3RelicPool (starting loadout only).",
	},
	knights_belt = {
		id = "knights_belt",
		sourceRow = 19,
		label = "Knight's Belt",
		relicGroup = "Weapon-based relic (Weapon relic)",
		description = "SwordShield ???????????.80 (RelicData 7C-1 migrate)",
		classTags = { "Guardian" },
		effectTargetTags = { "ss" },
		modifierTags = { "Cooldown" },
		triggerTags = {},
		obtainTags = { "Crafted" },
		unlockTags = { "Blueprint" },
		stackTags = "Upgradeable",
		requiredMaterials = "",
		classTagMatch = "TRUE",
		implementationTier = "A",
		mvpPriority = "Medium",
		blueprintId = "knights_belt",
		craftCost = {
			blueprintProgressMin = 1,
			materials = {},
		},
		isCraftable = true,
		isStartingEligible = false,
		isRunChestEligible = false,
		isPermanentUnlockable = true,
		modifiers = {
			{
				kind = "stat",
				targetTags = {
					weaponTag = "ss",
				},
				stat = "attackIntervalSeconds",
				operation = "mul",
				value = 0.80,
				requiresTuning = false,
				notes = "7C-1: RelicData AttackIntervalMul 0.80 parity.",
			},
		},
		notes = "7C-1 migrated from RelicData; not in Phase3RelicPool (starting loadout only).",
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

	if op == "openOrAdd" then
		if stat ~= "blockChance" then
			table.insert(
				warnings,
				string.format(
					"[RelicDefinitions] %s: modifiers[%d].openOrAdd only allowed for blockChance",
					relicId,
					modIndex
				)
			)
		end
		if type(mod.openValue) ~= "number" or type(mod.addValue) ~= "number" then
			table.insert(
				warnings,
				string.format(
					"[RelicDefinitions] %s: modifiers[%d].openOrAdd requires openValue and addValue numbers",
					relicId,
					modIndex
				)
			)
		end
	elseif op == "add" or op == "mul" then
		if type(value) ~= "number" then
			table.insert(
				warnings,
				string.format("[RelicDefinitions] %s: modifiers[%d].value must be number for %s", relicId, modIndex, op)
			)
		end
	end

	if type(mod.requiresTuning) ~= "boolean" then
		table.insert(
			warnings,
			string.format("[RelicDefinitions] %s: modifiers[%d].requiresTuning must be boolean", relicId, modIndex)
		)
	end

	return true
end

local META_PROGRESSION_BOOL_KEYS = {
	"isCraftable",
	"isStartingEligible",
	"isRunChestEligible",
	"isPermanentUnlockable",
}

local function validateMetaProgression(warnings: { string }, relicId: string, row: any)
	if type(row) ~= "table" then
		return
	end

	local blueprintId = row.blueprintId
	if blueprintId ~= nil then
		if type(blueprintId) ~= "string" or blueprintId == "" then
			table.insert(
				warnings,
				string.format("[RelicDefinitions] %s: blueprintId must be a non-empty string", relicId)
			)
		end
	end

	local craftCost = row.craftCost
	if craftCost ~= nil then
		if type(craftCost) ~= "table" then
			table.insert(warnings, string.format("[RelicDefinitions] %s: craftCost must be a table", relicId))
		else
			local bpm = craftCost.blueprintProgressMin
			if bpm ~= nil and type(bpm) ~= "number" then
				table.insert(
					warnings,
					string.format(
						"[RelicDefinitions] %s: craftCost.blueprintProgressMin must be nil or number",
						relicId
					)
				)
			end
			local materials = craftCost.materials
			if materials ~= nil then
				if type(materials) ~= "table" then
					table.insert(
						warnings,
						string.format("[RelicDefinitions] %s: craftCost.materials must be nil or table", relicId)
					)
				else
					for matKey, amount in pairs(materials) do
						if type(matKey) ~= "string" or matKey == "" then
							table.insert(
								warnings,
								string.format(
									"[RelicDefinitions] %s: craftCost.materials keys must be non-empty strings",
									relicId
								)
							)
						elseif type(amount) ~= "number" then
							table.insert(
								warnings,
								string.format(
									"[RelicDefinitions] %s: craftCost.materials[%s] must be number",
									relicId,
									tostring(matKey)
								)
							)
						end
					end
				end
			end
		end
	end

	for _, key in ipairs(META_PROGRESSION_BOOL_KEYS) do
		local v = row[key]
		if v ~= nil and type(v) ~= "boolean" then
			table.insert(
				warnings,
				string.format("[RelicDefinitions] %s: %s must be nil or boolean", relicId, key)
			)
		end
	end
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

--- Retired ids: not blueprint drop candidates (may still exist in saved profiles).
function RelicDefinitions.isRetiredRelicId(relicId: string): boolean
	return relicId == "cracked_sword_tip"
end

function RelicDefinitions.resolveBlueprintId(def: any, relicId: string): string?
	if type(def) ~= "table" then
		return nil
	end
	local bp = def.blueprintId
	if type(bp) == "string" and bp ~= "" then
		return bp
	end
	if type(relicId) == "string" and relicId ~= "" then
		return relicId
	end
	return nil
end

--- craftable + permanentUnlockable; excludes retired and owned relic ids (real profile set).
function RelicDefinitions.listBlueprintDropCandidateIds(ownedRelicSet: { [string]: boolean }?): { string }
	local owned = ownedRelicSet or {}
	local out: { string } = {}
	for relicId, row in pairs(RelicDefinitions.DefinitionsById) do
		if type(row) == "table" and row.isCraftable == true and row.isPermanentUnlockable == true then
			if not RelicDefinitions.isRetiredRelicId(relicId) then
				local blueprintId = RelicDefinitions.resolveBlueprintId(row, relicId)
				if blueprintId and owned[relicId] ~= true then
					table.insert(out, blueprintId)
				end
			end
		end
	end
	table.sort(out)
	return out
end

function RelicDefinitions.getDisplayLabelForBlueprintId(blueprintId: string): string
	if type(blueprintId) ~= "string" or blueprintId == "" then
		return "Blueprint"
	end
	for relicId, row in pairs(RelicDefinitions.DefinitionsById) do
		if type(row) == "table" then
			local bp = RelicDefinitions.resolveBlueprintId(row, relicId)
			if bp == blueprintId and type(row.label) == "string" and row.label ~= "" then
				return row.label
			end
		end
	end
	local def = RelicDefinitions.getDefinition(blueprintId)
	if def and type(def.label) == "string" and def.label ~= "" then
		return def.label
	end
	return blueprintId
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

		validateMetaProgression(warnings, tostring(key), row)
	end

	local ok = #warnings == 0
	return ok, warnings
end

return RelicDefinitions

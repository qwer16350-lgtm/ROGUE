-- Build tag aggregation and base class detection (read-only; no class effects).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClassRuleData = require(Shared:WaitForChild("ClassRuleData"))
local RelicDefinitions = require(Shared:WaitForChild("RelicDefinitions"))
local WeaponTagData = require(Shared:WaitForChild("WeaponTagData"))

local BuildTagService = {}

local function normalizeTag(raw: any): string?
	if type(raw) ~= "string" or raw == "" then
		return nil
	end
	local tag = raw:lower()
	if ClassRuleData.isForbiddenTagLiteral(tag) then
		return nil
	end
	return tag
end

local function emptyClassScores(): { [string]: number }
	local scores: { [string]: number } = {}
	for _, className in ipairs(ClassRuleData.AllowedClasses) do
		scores[className] = 0
	end
	return scores
end

local function addClassScoreDelta(classScores: { [string]: number }, scoreRow: any)
	if type(scoreRow) ~= "table" then
		return
	end
	for className, delta in pairs(scoreRow) do
		if ClassRuleData.isAllowedClass(className) and type(delta) == "number" then
			classScores[className] = (classScores[className] or 0) + delta
		end
	end
end

local function bumpTagCount(tagCounts: { [string]: number }, raw: any)
	local tag = normalizeTag(raw)
	if tag == nil then
		return
	end
	tagCounts[tag] = (tagCounts[tag] or 0) + 1
end

local function bumpTagArray(tagCounts: { [string]: number }, arr: any)
	if type(arr) ~= "table" then
		return
	end
	for _, raw in ipairs(arr) do
		bumpTagCount(tagCounts, raw)
	end
end

local function applyWeaponTagClassScores(classScores: { [string]: number }, weaponTag: string?)
	if type(weaponTag) ~= "string" or weaponTag == "" then
		return
	end
	addClassScoreDelta(classScores, ClassRuleData.WeaponTagScores[weaponTag])
end

local function applyEffectTargetClassScores(classScores: { [string]: number }, effectTag: string?)
	if type(effectTag) ~= "string" or effectTag == "" then
		return
	end
	addClassScoreDelta(classScores, ClassRuleData.EffectTargetTagScores[effectTag])
end

local function ingestWeaponRow(tagCounts: { [string]: number }, classScores: { [string]: number }, weaponId: string)
	local row = WeaponTagData.getWeaponTagRow(weaponId)
	if type(row) ~= "table" then
		return
	end

	local weaponTag = normalizeTag(row.weaponTag)
	if weaponTag ~= nil then
		bumpTagCount(tagCounts, weaponTag)
		applyWeaponTagClassScores(classScores, weaponTag)
	end

	bumpTagArray(tagCounts, row.typeTags)
	bumpTagArray(tagCounts, row.attackTags)
	bumpTagArray(tagCounts, row.rangeTags)
	bumpTagArray(tagCounts, row.tempoTags)
end

local function ingestRelicDefinition(
	tagCounts: { [string]: number },
	classScores: { [string]: number },
	relicId: string
)
	local def = RelicDefinitions.getDefinition(relicId)
	if type(def) ~= "table" then
		return
	end

	if type(def.classTags) == "table" then
		for _, raw in ipairs(def.classTags) do
			bumpTagCount(tagCounts, raw)
			if type(raw) == "string" and ClassRuleData.isAllowedClass(raw) then
				addClassScoreDelta(classScores, ClassRuleData.ClassTagScores[raw])
			end
		end
	end

	if type(def.effectTargetTags) == "table" then
		for _, raw in ipairs(def.effectTargetTags) do
			local tag = normalizeTag(raw)
			if tag ~= nil then
				bumpTagCount(tagCounts, tag)
				applyEffectTargetClassScores(classScores, tag)
			end
		end
	end

	if type(def.modifierTags) == "table" then
		for _, raw in ipairs(def.modifierTags) do
			bumpTagCount(tagCounts, raw)
		end
	end
end

local function copyPhase3RelicIds(src: any): { string }
	local out: { string } = {}
	if type(src) ~= "table" then
		return out
	end
	for _, relicId in ipairs(src) do
		if type(relicId) == "string" and relicId ~= "" then
			table.insert(out, relicId)
		end
	end
	return out
end

local function collectActiveWeaponIds(snapshot: any): { string }
	local ids: { string } = {}
	local seen: { [string]: boolean } = {}

	local activeWeapons = type(snapshot) == "table" and snapshot.activeWeapons
	if type(activeWeapons) == "table" then
		for weaponId, _ in pairs(activeWeapons) do
			if type(weaponId) == "string" and weaponId ~= "" and not seen[weaponId] then
				seen[weaponId] = true
				table.insert(ids, weaponId)
			end
		end
	end

	if #ids == 0 then
		local primary = type(snapshot) == "table" and snapshot.primaryWeaponId
		if type(primary) == "string" and primary ~= "" then
			table.insert(ids, primary)
		end
	end

	table.sort(ids)
	return ids
end

local function resolveDetectedClass(classScores: { [string]: number }): (string?, string?)
	local bestClass: string? = nil
	local bestScore = 0
	local tieCount = 0

	for _, className in ipairs(ClassRuleData.AllowedClasses) do
		local score = classScores[className] or 0
		if score > bestScore then
			bestScore = score
			bestClass = className
			tieCount = 1
		elseif score == bestScore and score > 0 then
			tieCount += 1
		end
	end

	if bestScore <= 0 then
		return nil, nil
	end
	if tieCount > 1 then
		return nil, "ambiguous"
	end
	return bestClass, nil
end

function BuildTagService.computeBuildSnapshot(snapshot: any): {
	TagCounts: { [string]: number },
	ClassScores: { [string]: number },
	DetectedClass: string?,
	TieBreakNote: string?,
	PrimaryWeaponId: string?,
	Phase3RelicIds: { string },
}
	local tagCounts: { [string]: number } = {}
	local classScores = emptyClassScores()

	local weaponIds = collectActiveWeaponIds(snapshot)
	for _, weaponId in ipairs(weaponIds) do
		ingestWeaponRow(tagCounts, classScores, weaponId)
	end

	local phase3RelicIds = copyPhase3RelicIds(type(snapshot) == "table" and snapshot.phase3RelicIds)
	for _, relicId in ipairs(phase3RelicIds) do
		ingestRelicDefinition(tagCounts, classScores, relicId)
	end

	local primaryWeaponId: string? = nil
	if type(snapshot) == "table" and type(snapshot.primaryWeaponId) == "string" and snapshot.primaryWeaponId ~= "" then
		primaryWeaponId = snapshot.primaryWeaponId
	end

	local detectedClass, tieBreakNote = resolveDetectedClass(classScores)

	return {
		TagCounts = tagCounts,
		ClassScores = classScores,
		DetectedClass = detectedClass,
		TieBreakNote = tieBreakNote,
		PrimaryWeaponId = primaryWeaponId,
		Phase3RelicIds = phase3RelicIds,
	}
end

return BuildTagService

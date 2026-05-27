-- Base class detection rules only (Guardian / Slayer / Lancer). No class effects.

local ClassRuleData = {}

ClassRuleData.AllowedClasses = { "Guardian", "Slayer", "Lancer" }

ClassRuleData.WeaponTagScores = {
	ss = { Guardian = 2 },
	th = { Slayer = 2 },
	sp = { Lancer = 2 },
}

ClassRuleData.ClassTagScores = {
	Guardian = { Guardian = 1 },
	Slayer = { Slayer = 1 },
	Lancer = { Lancer = 1 },
}

ClassRuleData.EffectTargetTagScores = {
	ss = { Guardian = 1 },
	th = { Slayer = 1 },
	sp = { Lancer = 1 },
}

local FORBIDDEN_TAG_LITERALS = {
	none = true,
	["-"] = true,
}

function ClassRuleData.isAllowedClass(className: string): boolean
	if type(className) ~= "string" or className == "" then
		return false
	end
	for _, allowed in ipairs(ClassRuleData.AllowedClasses) do
		if allowed == className then
			return true
		end
	end
	return false
end

function ClassRuleData.isForbiddenTagLiteral(tag: string): boolean
	if type(tag) ~= "string" or tag == "" then
		return true
	end
	return FORBIDDEN_TAG_LITERALS[tag:lower()] == true
end

--- Returns ok, list of warning strings (empty when ok).
function ClassRuleData.validate(): (boolean, { string })
	local warnings: { string } = {}

	if type(ClassRuleData.AllowedClasses) ~= "table" or #ClassRuleData.AllowedClasses == 0 then
		table.insert(warnings, "[ClassRuleData] AllowedClasses must be a non-empty array")
	end

	for _, className in ipairs(ClassRuleData.AllowedClasses) do
		if type(className) ~= "string" or className == "" then
			table.insert(warnings, "[ClassRuleData] AllowedClasses contains invalid entry")
		end
	end

	local function checkScoreMap(mapName: string, scoreMap: any)
		if type(scoreMap) ~= "table" then
			table.insert(warnings, string.format("[ClassRuleData] %s must be a table", mapName))
			return
		end
		for key, row in pairs(scoreMap) do
			if type(row) ~= "table" then
				table.insert(warnings, string.format("[ClassRuleData] %s[%s] must be a table", mapName, tostring(key)))
				continue
			end
			for className, delta in pairs(row) do
				if not ClassRuleData.isAllowedClass(className) then
					table.insert(
						warnings,
						string.format(
							"[ClassRuleData] %s[%s] references unknown class %s",
							mapName,
							tostring(key),
							tostring(className)
						)
					)
				end
				if type(delta) ~= "number" then
					table.insert(
						warnings,
						string.format(
							"[ClassRuleData] %s[%s].%s score must be a number",
							mapName,
							tostring(key),
							tostring(className)
						)
					)
				end
			end
		end
	end

	checkScoreMap("WeaponTagScores", ClassRuleData.WeaponTagScores)
	checkScoreMap("ClassTagScores", ClassRuleData.ClassTagScores)
	checkScoreMap("EffectTargetTagScores", ClassRuleData.EffectTargetTagScores)

	local ok = #warnings == 0
	return ok, warnings
end

return ClassRuleData

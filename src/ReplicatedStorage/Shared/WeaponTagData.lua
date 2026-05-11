-- Weapon tag SSOT for Phase 3 (implemented weapons only). Combat/relic/class wiring comes later.
-- Tag arrays never contain "none"; use empty tables where applicable.

local WeaponTagData = {}

WeaponTagData.RangeOrder = {
	superclose = 1,
	close = 2,
	mid = 3,
	closerange = 4,
	midrange = 5,
	longrange = 6,
}

--[[
	Implemented weapons only (SwordShield, Spear, TwoHandedSword).
	Future weapons stay out of this table until implemented.
]]
WeaponTagData.WeaponsById = {
	SwordShield = {
		weaponId = "SwordShield",
		displayName = "Sword Shield",
		weaponTag = "ss",
		typeTags = { "melee" },
		attackTags = { "sweep", "thrust" },
		effectTags = { "block", "knockback" },
		rangeTags = { "close" },
		tempoTags = { "normal" },
	},
	Spear = {
		weaponId = "Spear",
		displayName = "Spear",
		weaponTag = "sp",
		typeTags = { "melee" },
		attackTags = { "thrust" },
		effectTags = { "pierce" },
		rangeTags = { "mid" },
		tempoTags = { "slow" },
	},
	TwoHandedSword = {
		weaponId = "TwoHandedSword",
		displayName = "Two-Handed Sword",
		weaponTag = "th",
		typeTags = { "melee" },
		attackTags = { "sweep" },
		effectTags = { "slash" },
		rangeTags = { "mid" },
		tempoTags = { "slow" },
	},
}

local TAG_ARRAY_KEYS = { "typeTags", "attackTags", "effectTags", "rangeTags", "tempoTags" }

local function getWeaponTagOrNil(weaponId: string): any
	if type(weaponId) ~= "string" or weaponId == "" then
		return nil
	end
	return WeaponTagData.WeaponsById[weaponId]
end

function WeaponTagData.getWeaponTagOrNil(weaponId: string): any
	return getWeaponTagOrNil(weaponId)
end

function WeaponTagData.getWeaponTagRow(weaponId: string): any
	return getWeaponTagOrNil(weaponId)
end

function WeaponTagData.hasWeaponTagRow(weaponId: string): boolean
	return getWeaponTagOrNil(weaponId) ~= nil
end

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

--- Returns ok, list of warning strings (empty when ok).
function WeaponTagData.validate(): (boolean, { string })
	local warnings: { string } = {}

	for key, row in pairs(WeaponTagData.WeaponsById) do
		if type(row) ~= "table" then
			table.insert(warnings, string.format("[WeaponTagData] WeaponsById[%s] is not a table", tostring(key)))
			continue
		end
		if row.weaponId ~= key then
			table.insert(
				warnings,
				string.format("[WeaponTagData] key %s ~= row.weaponId %s", tostring(key), tostring(row.weaponId))
			)
		end
		if type(row.displayName) ~= "string" or row.displayName == "" then
			table.insert(warnings, string.format("[WeaponTagData] %s: missing displayName", tostring(key)))
		end
		if type(row.weaponTag) ~= "string" or row.weaponTag == "" then
			table.insert(warnings, string.format("[WeaponTagData] %s: missing weaponTag", tostring(key)))
		end

		for _, arrKey in ipairs(TAG_ARRAY_KEYS) do
			local arr = row[arrKey]
			if arr == nil then
				table.insert(warnings, string.format("[WeaponTagData] %s: missing %s", tostring(key), arrKey))
			elseif not isStringArray(arr) then
				table.insert(
					warnings,
					string.format("[WeaponTagData] %s: %s must be array of non-empty strings", tostring(key), arrKey)
				)
			end
		end

		if type(row.rangeTags) == "table" then
			for _, r in ipairs(row.rangeTags) do
				if WeaponTagData.RangeOrder[r] == nil then
					table.insert(
						warnings,
						string.format("[WeaponTagData] %s: unknown rangeTag %q (not in RangeOrder)", tostring(key), r)
					)
				end
			end
		end
	end

	local ok = #warnings == 0
	return ok, warnings
end

return WeaponTagData

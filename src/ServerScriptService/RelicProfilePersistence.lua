-- PlayerRelicProfile DataStore I/O. Stage result grants (RewardBudget minimum). Lobby RelicProfileService.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunRewardBudgetPolicy = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RunRewardBudgetPolicy")
)

local RelicProfilePersistence = {}

local SCHEMA_VERSION = 2
local CRAFT_MATERIAL_KEYS = RunRewardBudgetPolicy.CRAFT_MATERIAL_KEYS
local CURRENCY_KEYS = RunRewardBudgetPolicy.CURRENCY_KEYS
local LEGACY_MATERIAL_KEYS = { "shard", "ancient_shard", "ceremonial_coin" }
--- Retired RelicData id (7C-1): keep ownedRelics; never restore to equipped loadout.
local RETIRED_EQUIPPED_RELIC_ID = "cracked_sword_tip"

local enabled = false
local dataStoreName = "PlayerRelicProfile"
local loadRetryCount = 3
local saveRetryCount = 3
local getDefaultProfileFn: (() -> any)? = nil
local store: GlobalDataStore? = nil

local function defaultMaterials(): { [string]: number }
	return {
		mysterious_metal_part = 0,
		stinky_bond = 0,
		corrupted_gear = 0,
	}
end

local function defaultCurrencies(): { [string]: number }
	return { ancient_shard = 0 }
end

local function copyMaterials(src: any): { [string]: number }
	local out = defaultMaterials()
	if type(src) ~= "table" then
		return out
	end
	for _, key in ipairs(CRAFT_MATERIAL_KEYS) do
		local v = src[key]
		if type(v) == "number" and v >= 0 then
			out[key] = v
		end
	end
	return out
end

local function copyCurrencies(src: any): { [string]: number }
	local out = defaultCurrencies()
	if type(src) ~= "table" then
		return out
	end
	for _, key in ipairs(CURRENCY_KEYS) do
		local v = src[key]
		if type(v) == "number" and v >= 0 then
			out[key] = v
		end
	end
	return out
end

local function migrateLegacyMaterialsToCurrencies(materials: any, currencies: { [string]: number })
	if type(materials) ~= "table" then
		return
	end
	local legacyShard = materials.ancient_shard
	if type(legacyShard) == "number" and legacyShard > 0 then
		currencies.ancient_shard = (currencies.ancient_shard or 0) + math.floor(legacyShard + 0.5)
	end
end

local function normalizeProfileStorage(profile: any): any
	if type(profile) ~= "table" then
		return profile
	end
	profile.currencies = copyCurrencies(profile.currencies)
	migrateLegacyMaterialsToCurrencies(profile.materials, profile.currencies)
	profile.materials = copyMaterials(profile.materials)
	profile.version = SCHEMA_VERSION
	return profile
end

local function copyOwnedRelics(src: any): { [string]: boolean }
	local out: { [string]: boolean } = {}
	if type(src) ~= "table" then
		return out
	end
	for relicId, owned in pairs(src) do
		if type(relicId) == "string" and relicId ~= "" and owned == true then
			out[relicId] = true
		end
	end
	return out
end

local function copyBlueprintProgress(src: any): { [string]: number }
	local out: { [string]: number } = {}
	if type(src) ~= "table" then
		return out
	end
	for blueprintId, progress in pairs(src) do
		if type(blueprintId) == "string" and blueprintId ~= "" and type(progress) == "number" then
			out[blueprintId] = progress
		end
	end
	return out
end

local function copyEquippedStartingRelics(src: any): { string }
	local out: { string } = {}
	if type(src) ~= "table" then
		return out
	end
	for _, relicId in ipairs(src) do
		if type(relicId) == "string" and relicId ~= "" and relicId ~= RETIRED_EQUIPPED_RELIC_ID then
			table.insert(out, relicId)
		end
	end
	return out
end

function RelicProfilePersistence.getSchemaVersion(): number
	return SCHEMA_VERSION
end

function RelicProfilePersistence.isEnabled(): boolean
	return enabled
end

function RelicProfilePersistence.getDataStoreName(): string
	return dataStoreName
end

function RelicProfilePersistence.getKey(userId: number): string
	return tostring(userId)
end

function RelicProfilePersistence.migrate(raw: any): any?
	if raw == nil then
		return nil
	end
	if type(raw) ~= "table" then
		return nil
	end
	local version = raw.version
	if type(version) ~= "number" then
		version = 1
	end
	if version > SCHEMA_VERSION then
		return nil
	end
	if version < 1 then
		version = 1
	end
	return {
		version = version,
		ownedRelics = raw.ownedRelics,
		blueprintProgress = raw.blueprintProgress,
		materials = raw.materials,
		currencies = raw.currencies,
		equippedStartingRelics = raw.equippedStartingRelics,
	}
end

function RelicProfilePersistence.mergeWithDefault(migrated: any?): any
	assert(getDefaultProfileFn, "[RelicProfilePersistence] init required")
	local base = getDefaultProfileFn()
	if type(migrated) ~= "table" then
		return normalizeProfileStorage({
			version = SCHEMA_VERSION,
			ownedRelics = copyOwnedRelics(base.ownedRelics),
			blueprintProgress = copyBlueprintProgress(base.blueprintProgress),
			materials = copyMaterials(base.materials),
			currencies = copyCurrencies(base.currencies),
			equippedStartingRelics = copyEquippedStartingRelics(base.equippedStartingRelics),
		})
	end
	return normalizeProfileStorage({
		version = SCHEMA_VERSION,
		ownedRelics = copyOwnedRelics(migrated.ownedRelics),
		blueprintProgress = copyBlueprintProgress(migrated.blueprintProgress),
		materials = migrated.materials,
		currencies = migrated.currencies,
		equippedStartingRelics = copyEquippedStartingRelics(migrated.equippedStartingRelics),
	})
end

function RelicProfilePersistence.packForStorage(profile: any): any
	if type(profile) ~= "table" then
		return RelicProfilePersistence.mergeWithDefault(nil)
	end
	local normalized = normalizeProfileStorage({
		version = SCHEMA_VERSION,
		ownedRelics = copyOwnedRelics(profile.ownedRelics),
		blueprintProgress = copyBlueprintProgress(profile.blueprintProgress),
		materials = profile.materials,
		currencies = profile.currencies,
		equippedStartingRelics = copyEquippedStartingRelics(profile.equippedStartingRelics),
	})
	return {
		version = SCHEMA_VERSION,
		ownedRelics = normalized.ownedRelics,
		blueprintProgress = normalized.blueprintProgress,
		materials = normalized.materials,
		currencies = normalized.currencies,
		equippedStartingRelics = normalized.equippedStartingRelics,
	}
end

local function getStore(): GlobalDataStore?
	if not enabled then
		return nil
	end
	if store == nil then
		store = DataStoreService:GetDataStore(dataStoreName)
	end
	return store
end

local function retryDelay(attempt: number)
	task.wait(math.min(2 ^ attempt, 8))
end

function RelicProfilePersistence.loadProfile(userId: number): (any?, string?)
	if not enabled then
		return RelicProfilePersistence.mergeWithDefault(nil), "disabled"
	end
	local ds = getStore()
	if not ds then
		return nil, "STORE_UNAVAILABLE"
	end
	local key = RelicProfilePersistence.getKey(userId)
	local lastErr: string? = nil
	for attempt = 0, loadRetryCount - 1 do
		local ok, result = pcall(function()
			return ds:GetAsync(key)
		end)
		if ok then
			local migrated = RelicProfilePersistence.migrate(result)
			if result ~= nil and migrated == nil then
				return nil, "MIGRATE_FAILED"
			end
			return RelicProfilePersistence.mergeWithDefault(migrated), nil
		end
		lastErr = tostring(result)
		if attempt < loadRetryCount - 1 then
			retryDelay(attempt)
		end
	end
	return nil, lastErr or "LOAD_FAILED"
end

function RelicProfilePersistence.saveProfile(userId: number, profile: any): (boolean, string?)
	if not enabled then
		return false, "disabled"
	end
	local ds = getStore()
	if not ds then
		return false, "STORE_UNAVAILABLE"
	end
	local key = RelicProfilePersistence.getKey(userId)
	local payload = RelicProfilePersistence.packForStorage(profile)
	local lastErr: string? = nil
	for attempt = 0, saveRetryCount - 1 do
		local ok, err = pcall(function()
			ds:SetAsync(key, payload)
		end)
		if ok then
			return true, nil
		end
		lastErr = tostring(err)
		if attempt < saveRetryCount - 1 then
			retryDelay(attempt)
		end
	end
	return false, lastErr or "SAVE_FAILED"
end

local function applyMaterialGrants(profile: any, materialsGranted: any): any
	if type(profile) ~= "table" then
		return profile
	end
	profile = normalizeProfileStorage(profile)
	if type(materialsGranted) ~= "table" then
		return profile
	end
	for _, key in ipairs(CRAFT_MATERIAL_KEYS) do
		local add = materialsGranted[key]
		if type(add) == "number" and add > 0 then
			profile.materials[key] = (profile.materials[key] or 0) + math.floor(add + 0.5)
		end
	end
	return profile
end

function RelicProfilePersistence.grantMaterials(userId: number, materialsGranted: any): (boolean, string?)
	if not enabled then
		return false, "disabled"
	end
	if type(materialsGranted) ~= "table" or not next(materialsGranted) then
		return true, nil
	end
	local profile, loadErr = RelicProfilePersistence.loadProfile(userId)
	if not profile then
		return false, loadErr or "LOAD_FAILED"
	end
	profile = applyMaterialGrants(profile, materialsGranted)
	return RelicProfilePersistence.saveProfile(userId, profile)
end

local function applyCurrencyGrants(profile: any, currenciesGranted: any): any
	if type(profile) ~= "table" then
		return profile
	end
	profile = normalizeProfileStorage(profile)
	if type(currenciesGranted) ~= "table" then
		return profile
	end
	for _, key in ipairs(CURRENCY_KEYS) do
		local add = currenciesGranted[key]
		if type(add) == "number" and add > 0 then
			profile.currencies[key] = (profile.currencies[key] or 0) + math.floor(add + 0.5)
		end
	end
	return profile
end

function RelicProfilePersistence.grantCurrencies(userId: number, currenciesGranted: any): (boolean, string?)
	if not enabled then
		return false, "disabled"
	end
	if type(currenciesGranted) ~= "table" or not next(currenciesGranted) then
		return true, nil
	end
	local profile, loadErr = RelicProfilePersistence.loadProfile(userId)
	if not profile then
		return false, loadErr or "LOAD_FAILED"
	end
	profile = applyCurrencyGrants(profile, currenciesGranted)
	return RelicProfilePersistence.saveProfile(userId, profile)
end

local function applyBlueprintGrants(profile: any, blueprintGranted: any): any
	if type(profile) ~= "table" then
		return profile
	end
	profile.blueprintProgress = copyBlueprintProgress(profile.blueprintProgress)
	if type(blueprintGranted) ~= "table" then
		return profile
	end
	for blueprintId, add in pairs(blueprintGranted) do
		if type(blueprintId) == "string" and blueprintId ~= "" and type(add) == "number" and add > 0 then
			profile.blueprintProgress[blueprintId] = (profile.blueprintProgress[blueprintId] or 0)
				+ math.floor(add + 0.5)
		end
	end
	return profile
end

function RelicProfilePersistence.grantBlueprintProgress(userId: number, blueprintGranted: any): (boolean, string?)
	if not enabled then
		return false, "disabled"
	end
	if type(blueprintGranted) ~= "table" or not next(blueprintGranted) then
		return true, nil
	end
	local profile, loadErr = RelicProfilePersistence.loadProfile(userId)
	if not profile then
		return false, loadErr or "LOAD_FAILED"
	end
	profile = applyBlueprintGrants(profile, blueprintGranted)
	return RelicProfilePersistence.saveProfile(userId, profile)
end

function RelicProfilePersistence.init(gameConfig: any, opts: { getDefaultProfile: () -> any })
	assert(opts and opts.getDefaultProfile, "[RelicProfilePersistence] getDefaultProfile required")
	getDefaultProfileFn = opts.getDefaultProfile

	local cfg = type(gameConfig) == "table" and gameConfig.RelicProfilePersistence or nil
	enabled = type(cfg) == "table" and cfg.Enabled == true
	if type(cfg) == "table" then
		if type(cfg.DataStoreName) == "string" and cfg.DataStoreName ~= "" then
			dataStoreName = cfg.DataStoreName
		end
		if type(cfg.LoadRetryCount) == "number" and cfg.LoadRetryCount >= 1 then
			loadRetryCount = math.floor(cfg.LoadRetryCount + 0.5)
		end
		if type(cfg.SaveRetryCount) == "number" and cfg.SaveRetryCount >= 1 then
			saveRetryCount = math.floor(cfg.SaveRetryCount + 0.5)
		end
	end
	store = nil
end

return RelicProfilePersistence

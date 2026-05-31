-- Lobby relic profile (4B-4C-2) + DataStore persistence (5A).
-- Stage chest still uses GameConfig.Debug until Step 7.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RelicDefinitions = require(Shared:WaitForChild("RelicDefinitions"))
local RelicProfilePersistence = require(script.Parent:WaitForChild("RelicProfilePersistence"))

local RelicProfileService = {}

local sessionsByUserId: { [number]: {
	profile: any?,
	loadState: "loading" | "ready",
	dirty: boolean,
	persistDisabled: boolean,
	equipSaveThread: thread?,
} } = {}
local gameConfigRef: any = nil
local getRelicProfileRemote: RemoteFunction? = nil
local craftRelicRequestRemote: RemoteFunction? = nil
local equipStartingRelicsRequestRemote: RemoteFunction? = nil

local MATERIAL_KEYS = { "shard", "ancient_shard", "ceremonial_coin" }

local function defaultMaterials(): { [string]: number }
	return {
		shard = 0,
		ancient_shard = 0,
		ceremonial_coin = 0,
	}
end

local function copyMaterials(src: any): { [string]: number }
	local out = defaultMaterials()
	if type(src) ~= "table" then
		return out
	end
	for _, key in ipairs(MATERIAL_KEYS) do
		local v = src[key]
		if type(v) == "number" then
			out[key] = v
		end
	end
	return out
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
		if type(relicId) == "string" and relicId ~= "" then
			table.insert(out, relicId)
		end
	end
	return out
end

local function equippedSet(profile: any): { [string]: boolean }
	local set: { [string]: boolean } = {}
	if type(profile) ~= "table" then
		return set
	end
	for _, relicId in ipairs(profile.equippedStartingRelics or {}) do
		if type(relicId) == "string" and relicId ~= "" then
			set[relicId] = true
		end
	end
	return set
end

local function getRelicStartingSlotMax(): number
	local cap = gameConfigRef and gameConfigRef.RelicStartingSlotMax
	if type(cap) == "number" and cap >= 0 then
		return math.floor(cap + 0.5)
	end
	return 1
end

local function shouldSkipCraftRequirements(): boolean
	local dbg = gameConfigRef and gameConfigRef.Debug
	return type(dbg) == "table" and dbg.RelicCraftSkipRequirements == true
end

function RelicProfileService.getDefaultProfile(): any
	return {
		version = 1,
		ownedRelics = {},
		blueprintProgress = {},
		materials = defaultMaterials(),
		equippedStartingRelics = {},
	}
end

local function applyTestSeed(profile: any)
	local dbg = gameConfigRef and gameConfigRef.Debug
	if type(dbg) ~= "table" then
		return
	end
	local seed = dbg.RelicProfileTestSeed
	if type(seed) ~= "table" then
		return
	end
	if type(seed.ownedRelics) == "table" then
		for relicId, owned in pairs(seed.ownedRelics) do
			if type(relicId) == "string" and relicId ~= "" and owned == true then
				profile.ownedRelics[relicId] = true
			end
		end
	end
	if type(seed.blueprintProgress) == "table" then
		for blueprintId, progress in pairs(seed.blueprintProgress) do
			if type(blueprintId) == "string" and blueprintId ~= "" and type(progress) == "number" then
				profile.blueprintProgress[blueprintId] = progress
			end
		end
	end
	if type(seed.materials) == "table" then
		profile.materials = copyMaterials(seed.materials)
	end
	if type(seed.equippedStartingRelics) == "table" then
		profile.equippedStartingRelics = copyEquippedStartingRelics(seed.equippedStartingRelics)
	end
end

local function getPersistenceCfg(): any
	return gameConfigRef and gameConfigRef.RelicProfilePersistence
end

local function getEquipSaveDebounceSeconds(): number
	local cfg = getPersistenceCfg()
	local sec = type(cfg) == "table" and cfg.EquipSaveDebounceSeconds
	if type(sec) == "number" and sec > 0 then
		return sec
	end
	return 5
end

local function getAutosaveIntervalSeconds(): number
	local cfg = getPersistenceCfg()
	local sec = type(cfg) == "table" and cfg.AutosaveIntervalSeconds
	if type(sec) == "number" and sec > 0 then
		return sec
	end
	return 60
end

local function getSession(uid: number): any?
	return sessionsByUserId[uid]
end

local function isProfileLoading(player: Player): boolean
	local meta = getSession(player.UserId)
	return meta ~= nil and meta.loadState == "loading"
end

local function sessionProfileReady(player: Player): any?
	local meta = getSession(player.UserId)
	if not meta or meta.loadState ~= "ready" or type(meta.profile) ~= "table" then
		return nil
	end
	return meta.profile
end

local function ensureProfile(player: Player): any?
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return nil
	end
	return sessionProfileReady(player)
end

local function tryImmediateSave(player: Player, profile: any)
	local meta = getSession(player.UserId)
	if not meta or meta.persistDisabled or not RelicProfilePersistence.isEnabled() then
		return
	end
	local ok, err = RelicProfilePersistence.saveProfile(player.UserId, profile)
	if ok then
		meta.dirty = false
	else
		meta.dirty = true
		warn(string.format("[RelicProfileService] craft save failed uid=%d err=%s", player.UserId, tostring(err)))
	end
end

local function flushDirtySave(player: Player): boolean
	local meta = getSession(player.UserId)
	if not meta or meta.persistDisabled or not meta.dirty or not RelicProfilePersistence.isEnabled() then
		return false
	end
	if type(meta.profile) ~= "table" then
		return false
	end
	local ok, err = RelicProfilePersistence.saveProfile(player.UserId, meta.profile)
	if ok then
		meta.dirty = false
		return true
	end
	warn(string.format("[RelicProfileService] save failed uid=%d err=%s", player.UserId, tostring(err)))
	return false
end

local function cancelEquipSaveThread(meta: any)
	if meta and meta.equipSaveThread then
		local t = meta.equipSaveThread
		meta.equipSaveThread = nil
		pcall(function()
			task.cancel(t)
		end)
	end
end

local function scheduleEquipDebouncedSave(player: Player)
	local meta = getSession(player.UserId)
	if not meta or meta.persistDisabled or not RelicProfilePersistence.isEnabled() then
		return
	end
	cancelEquipSaveThread(meta)
	local debounce = getEquipSaveDebounceSeconds()
	meta.equipSaveThread = task.delay(debounce, function()
		meta.equipSaveThread = nil
		if meta.dirty then
			flushDirtySave(player)
		end
	end)
end

local function markDirty(player: Player)
	local meta = getSession(player.UserId)
	if meta then
		meta.dirty = true
	end
end

local function beginProfileLoad(player: Player)
	local uid = player.UserId
	if getSession(uid) ~= nil then
		return
	end
	sessionsByUserId[uid] = {
		profile = nil,
		loadState = "loading",
		dirty = false,
		persistDisabled = false,
		equipSaveThread = nil,
	}
	task.spawn(function()
		local meta = getSession(uid)
		if not meta then
			return
		end
		if not RelicProfilePersistence.isEnabled() then
			local profile = RelicProfileService.getDefaultProfile()
			applyTestSeed(profile)
			meta.profile = profile
			meta.loadState = "ready"
			meta.persistDisabled = true
			return
		end
		local loaded, err = RelicProfilePersistence.loadProfile(uid)
		meta = getSession(uid)
		if not meta then
			return
		end
		if loaded then
			applyTestSeed(loaded)
			meta.profile = loaded
			meta.loadState = "ready"
			meta.persistDisabled = false
		else
			warn(string.format("[RelicProfileService] load failed uid=%d err=%s session-only", uid, tostring(err)))
			local profile = RelicProfileService.getDefaultProfile()
			applyTestSeed(profile)
			meta.profile = profile
			meta.loadState = "ready"
			meta.persistDisabled = true
		end
	end)
end

function RelicProfileService.getProfile(player: Player): any?
	return ensureProfile(player)
end

function RelicProfileService.hasOwnedRelic(player: Player, relicId: string): boolean
	local profile = ensureProfile(player)
	if not profile or type(relicId) ~= "string" or relicId == "" then
		return false
	end
	return profile.ownedRelics[relicId] == true
end

function RelicProfileService.canCraftRelic(profile: any, relicId: string): (boolean, string?)
	if type(profile) ~= "table" then
		return false, "PROFILE_UNAVAILABLE"
	end
	if type(relicId) ~= "string" or relicId == "" then
		return false, "INVALID_RELIC_ID"
	end
	local def = RelicDefinitions.getDefinition(relicId)
	if type(def) ~= "table" then
		return false, "UNKNOWN_RELIC"
	end
	if def.isCraftable ~= true then
		return false, "NOT_CRAFTABLE"
	end
	if def.isPermanentUnlockable == false then
		return false, "NOT_PERMANENT_UNLOCKABLE"
	end
	if profile.ownedRelics[relicId] == true then
		return false, "ALREADY_OWNED"
	end
	local blueprintId = def.blueprintId
	if type(blueprintId) ~= "string" or blueprintId == "" then
		blueprintId = relicId
	end
	local craftCost = def.craftCost
	local bpm = 1
	local materialsRequired = {}
	if type(craftCost) == "table" then
		if type(craftCost.blueprintProgressMin) == "number" then
			bpm = craftCost.blueprintProgressMin
		end
		if type(craftCost.materials) == "table" then
			materialsRequired = craftCost.materials
		end
	end
	if not shouldSkipCraftRequirements() then
		local progress = profile.blueprintProgress[blueprintId]
		if type(progress) ~= "number" then
			progress = 0
		end
		if progress < bpm then
			return false, "NOT_ENOUGH_BLUEPRINT"
		end
		for matKey, required in pairs(materialsRequired) do
			if type(matKey) == "string" and type(required) == "number" and required > 0 then
				local have = profile.materials[matKey]
				if type(have) ~= "number" or have < required then
					return false, "NOT_ENOUGH_MATERIALS"
				end
			end
		end
	end
	return true, nil
end

local function getCraftMaterialsRequired(def: any): { [string]: number }
	local craftCost = def.craftCost
	if type(craftCost) ~= "table" or type(craftCost.materials) ~= "table" then
		return {}
	end
	return craftCost.materials
end

local function deductCraftMaterials(profile: any, def: any)
	local materialsRequired = getCraftMaterialsRequired(def)
	for matKey, required in pairs(materialsRequired) do
		if type(matKey) == "string" and type(required) == "number" and required > 0 then
			local have = profile.materials[matKey]
			if type(have) == "number" then
				profile.materials[matKey] = have - required
			end
		end
	end
end

function RelicProfileService.craftRelic(player: Player, relicId: any): any
	if isProfileLoading(player) then
		return { ok = false, reason = "PROFILE_LOADING" }
	end
	if type(relicId) ~= "string" or relicId == "" then
		return { ok = false, reason = "INVALID_RELIC_ID" }
	end
	local profile = ensureProfile(player)
	if not profile then
		return { ok = false, reason = "PROFILE_UNAVAILABLE" }
	end
	local canCraft, reason = RelicProfileService.canCraftRelic(profile, relicId)
	if not canCraft then
		return { ok = false, reason = reason or "UNKNOWN_RELIC" }
	end
	local def = RelicDefinitions.getDefinition(relicId)
	if type(def) ~= "table" then
		return { ok = false, reason = "UNKNOWN_RELIC" }
	end
	if not shouldSkipCraftRequirements() then
		deductCraftMaterials(profile, def)
	end
	profile.ownedRelics[relicId] = true
	tryImmediateSave(player, profile)
	return {
		ok = true,
		relicId = relicId,
		profile = RelicProfileService.getPublicProfile(player),
	}
end

function RelicProfileService.canEquipStartingRelics(profile: any, relicIds: any): (boolean, string?)
	if type(profile) ~= "table" then
		return false, "PROFILE_UNAVAILABLE"
	end
	if type(relicIds) ~= "table" then
		return false, "INVALID_RELIC_ID"
	end
	local slotMax = getRelicStartingSlotMax()
	if #relicIds > slotMax then
		return false, "TOO_MANY_EQUIPPED"
	end
	local seen: { [string]: boolean } = {}
	for _, relicId in ipairs(relicIds) do
		if type(relicId) ~= "string" or relicId == "" then
			return false, "INVALID_RELIC_ID"
		end
		if seen[relicId] then
			return false, "DUPLICATE_RELIC"
		end
		seen[relicId] = true
		local def = RelicDefinitions.getDefinition(relicId)
		if type(def) ~= "table" then
			return false, "UNKNOWN_RELIC"
		end
		if profile.ownedRelics[relicId] ~= true then
			return false, "NOT_OWNED"
		end
	end
	return true, nil
end

function RelicProfileService.setEquippedStartingRelics(player: Player, relicIds: any): any
	if isProfileLoading(player) then
		return { ok = false, reason = "PROFILE_LOADING" }
	end
	local profile = ensureProfile(player)
	if not profile then
		return { ok = false, reason = "PROFILE_UNAVAILABLE" }
	end
	local canEquip, reason = RelicProfileService.canEquipStartingRelics(profile, relicIds)
	if not canEquip then
		return { ok = false, reason = reason or "INVALID_RELIC_ID" }
	end
	local equippedCopy = copyEquippedStartingRelics(relicIds)
	profile.equippedStartingRelics = equippedCopy
	markDirty(player)
	scheduleEquipDebouncedSave(player)
	return {
		ok = true,
		equippedStartingRelics = copyEquippedStartingRelics(equippedCopy),
		profile = RelicProfileService.getPublicProfile(player),
	}
end

function RelicProfileService.buildCraftableRelics(profile: any): { any }
	local out: { any } = {}
	if type(profile) ~= "table" then
		return out
	end
	for relicId, def in pairs(RelicDefinitions.DefinitionsById) do
		if type(def) == "table" and def.isCraftable == true then
			if profile.ownedRelics[relicId] ~= true then
				local blueprintId = def.blueprintId
				if type(blueprintId) ~= "string" or blueprintId == "" then
					blueprintId = relicId
				end
				local craftCost = def.craftCost
				local bpm = 1
				local materialsRequired = {}
				if type(craftCost) == "table" then
					if type(craftCost.blueprintProgressMin) == "number" then
						bpm = craftCost.blueprintProgressMin
					end
					if type(craftCost.materials) == "table" then
						materialsRequired = craftCost.materials
					end
				end
				local progress = profile.blueprintProgress[blueprintId]
				if type(progress) ~= "number" then
					progress = 0
				end
				local canCraft, reason = RelicProfileService.canCraftRelic(profile, relicId)
				local label = def.label
				if type(label) ~= "string" or label == "" then
					label = relicId
				end
				local blockReason = nil
				if not canCraft then
					blockReason = reason
				end
				table.insert(out, {
					relicId = relicId,
					label = label,
					blueprintId = blueprintId,
					blueprintProgress = progress,
					blueprintProgressMin = bpm,
					materialsRequired = materialsRequired,
					isCraftable = true,
					isOwned = false,
					canCraft = canCraft,
					craftBlockReason = blockReason,
				})
			end
		end
	end
	table.sort(out, function(a, b)
		return tostring(a.relicId) < tostring(b.relicId)
	end)
	return out
end

function RelicProfileService.buildStartingEligibleRelics(profile: any): { any }
	local out: { any } = {}
	if type(profile) ~= "table" then
		return out
	end
	local equipped = equippedSet(profile)
	for relicId, owned in pairs(profile.ownedRelics) do
		if owned == true and type(relicId) == "string" and relicId ~= "" then
			local def = RelicDefinitions.getDefinition(relicId)
			if type(def) == "table" and def.isStartingEligible == true then
				local label = def.label
				if type(label) ~= "string" or label == "" then
					label = relicId
				end
				table.insert(out, {
					relicId = relicId,
					label = label,
					equipped = equipped[relicId] == true,
					isOwned = true,
					isStartingEligible = true,
				})
			end
		end
	end
	table.sort(out, function(a, b)
		return tostring(a.relicId) < tostring(b.relicId)
	end)
	return out
end

function RelicProfileService.getPublicProfile(player: Player): any
	if isProfileLoading(player) then
		return { ok = false, reason = "PROFILE_LOADING" }
	end
	local profile = ensureProfile(player)
	if not profile then
		return { ok = false, reason = "PROFILE_UNAVAILABLE" }
	end
	return {
		ok = true,
		version = profile.version,
		ownedRelics = copyOwnedRelics(profile.ownedRelics),
		blueprintProgress = copyBlueprintProgress(profile.blueprintProgress),
		materials = copyMaterials(profile.materials),
		equippedStartingRelics = copyEquippedStartingRelics(profile.equippedStartingRelics),
		craftableRelics = RelicProfileService.buildCraftableRelics(profile),
		startingEligibleRelics = RelicProfileService.buildStartingEligibleRelics(profile),
		relicStartingSlotMax = getRelicStartingSlotMax(),
	}
end

function RelicProfileService.cleanup(player: Player)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return
	end
	local uid = player.UserId
	local meta = getSession(uid)
	if meta then
		cancelEquipSaveThread(meta)
	end
	sessionsByUserId[uid] = nil
end

local function onPlayerRemoving(player: Player)
	local meta = getSession(player.UserId)
	if meta and meta.loadState == "ready" then
		cancelEquipSaveThread(meta)
		flushDirtySave(player)
	end
	RelicProfileService.cleanup(player)
end

local function onGetRelicProfile(player: Player): any
	return RelicProfileService.getPublicProfile(player)
end

local function onCraftRelicRequest(player: Player, relicId: any): any
	return RelicProfileService.craftRelic(player, relicId)
end

local function onEquipStartingRelicsRequest(player: Player, relicIds: any): any
	return RelicProfileService.setEquippedStartingRelics(player, relicIds)
end

local function ensureGetRelicProfileRemote(replicatedStorage: Instance): RemoteFunction
	local remotes = replicatedStorage:WaitForChild("Remotes")
	local existing = remotes:FindFirstChild("GetRelicProfile")
	if existing and existing:IsA("RemoteFunction") then
		return existing
	end
	local rf = Instance.new("RemoteFunction")
	rf.Name = "GetRelicProfile"
	rf.Parent = remotes
	return rf
end

local function ensureCraftRelicRequestRemote(replicatedStorage: Instance): RemoteFunction
	local remotes = replicatedStorage:WaitForChild("Remotes")
	local existing = remotes:FindFirstChild("CraftRelicRequest")
	if existing and existing:IsA("RemoteFunction") then
		return existing
	end
	local rf = Instance.new("RemoteFunction")
	rf.Name = "CraftRelicRequest"
	rf.Parent = remotes
	return rf
end

local function ensureEquipStartingRelicsRequestRemote(replicatedStorage: Instance): RemoteFunction
	local remotes = replicatedStorage:WaitForChild("Remotes")
	local existing = remotes:FindFirstChild("EquipStartingRelicsRequest")
	if existing and existing:IsA("RemoteFunction") then
		return existing
	end
	local rf = Instance.new("RemoteFunction")
	rf.Name = "EquipStartingRelicsRequest"
	rf.Parent = remotes
	return rf
end

function RelicProfileService.init(deps: {
	players: Players,
	replicatedStorage: Instance,
	gameConfig: any,
})
	assert(deps, "[RelicProfileService] deps required")
	assert(deps.players, "[RelicProfileService] deps.players required")
	assert(deps.replicatedStorage, "[RelicProfileService] deps.replicatedStorage required")

	gameConfigRef = deps.gameConfig

	getRelicProfileRemote = ensureGetRelicProfileRemote(deps.replicatedStorage)
	getRelicProfileRemote.OnServerInvoke = onGetRelicProfile

	craftRelicRequestRemote = ensureCraftRelicRequestRemote(deps.replicatedStorage)
	craftRelicRequestRemote.OnServerInvoke = onCraftRelicRequest

	equipStartingRelicsRequestRemote = ensureEquipStartingRelicsRequestRemote(deps.replicatedStorage)
	equipStartingRelicsRequestRemote.OnServerInvoke = onEquipStartingRelicsRequest

	RelicProfilePersistence.init(deps.gameConfig, {
		getDefaultProfile = RelicProfileService.getDefaultProfile,
	})

	deps.players.PlayerAdded:Connect(function(player)
		beginProfileLoad(player)
	end)

	deps.players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in deps.players:GetPlayers() do
		beginProfileLoad(player)
	end

	task.spawn(function()
		local interval = getAutosaveIntervalSeconds()
		while true do
			task.wait(interval)
			for _, player in deps.players:GetPlayers() do
				local meta = getSession(player.UserId)
				if meta and meta.loadState == "ready" and meta.dirty then
					flushDirtySave(player)
				end
			end
		end
	end)
end

return RelicProfileService

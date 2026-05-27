local ProgressionService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local RunWeaponResolver = require(Shared:WaitForChild("RunWeaponResolver"))
local RunContext = require(script.Parent:WaitForChild("Run"):WaitForChild("RunContext"))
local UpgradeOfferBuilder = require(script.Parent:WaitForChild("Progression"):WaitForChild("UpgradeOfferBuilder"))
local WeaponProgression = require(script.Parent:WaitForChild("Progression"):WaitForChild("WeaponProgression"))

local progressByPlayer = {}
local levelUpChoiceEvent = nil
local gameConfigRef = nil
local immediateHudPush = nil


local pendingLevelUpOfferByPlayer: { [Player]: { [string]: boolean } } = {}
local pendingStartingWeaponByPlayer: { [Player]: { [string]: boolean } } = {}
local pendingPhase3RelicByPlayer: { [Player]: { [string]: boolean } } = {}

local relicDefinitionsModule = nil
local phase3RelicPoolModule = nil

local function progressionVerbose(): boolean
	local d = gameConfigRef and gameConfigRef.Debug
	return type(d) == "table" and d.ProgressionVerbose == true
end

local function debugProgression(...)
	if progressionVerbose() then
		print(...)
	end
end

local relicDataModule = nil
local weaponPickupNotifyEvent: RemoteEvent? = nil
local HEALTH_UPGRADE_ID = "ab_Health_increase"
local HEALTH_UPGRADE_BONUS_PER_STACK = 20
local XP_UPGRADE_ID = "ab_xp_increase"
local XP_UPGRADE_MUL_PER_STACK = 0.05
local SPEED_UPGRADE_ID = "ab_Speed_increase"
local SPEED_UPGRADE_MUL_PER_STACK = 0.03
local MAGNET_RANGE_UPGRADE_ID = "mg_Range_increase"
local HEALTH_ORB_AMOUNT_UPGRADE_ID = "ho_Amount_increase"
local HEALTH_ORB_CHANCE_UPGRADE_ID = "ho_Chance_increase"

local function resolveStartingRelicIdFromRunContext(): string?
	if not relicDataModule then
		return nil
	end
	if type(RunContext) ~= "table" or type(RunContext.getStartingRelicId) ~= "function" then
		return nil
	end
	local relicId = RunContext.getStartingRelicId()
	if type(relicId) ~= "string" or relicId == "" then
		return nil
	end
	local choices = relicDataModule.getStartingRelicChoices and relicDataModule.getStartingRelicChoices() or nil
	if type(choices) ~= "table" then
		return nil
	end
	for _, row in ipairs(choices) do
		if type(row) == "table" and row.Id == relicId then
			return relicId
		end
	end
	warn(string.format("[Progression] invalid startingRelicId from RunContext ignored: %s", tostring(relicId)))
	return nil
end

local function fireWeaponPickupNotify(player: Player, kind: string)
	if weaponPickupNotifyEvent then
		weaponPickupNotifyEvent:FireClient(player, { Kind = kind })
	end
end

function ProgressionService.getWeaponId(player): string?
	local state = progressByPlayer[player]
	return WeaponProgression.getWeaponId(state)
end

function ProgressionService.getWeaponGrade(player): string?
	local state = progressByPlayer[player]
	if not state then
		return "Normal"
	end
	return WeaponProgression.getWeaponGrade(state)
end

function ProgressionService.getWeaponGradeFor(player, weaponId: string): string
	local state = progressByPlayer[player]
	return WeaponProgression.getWeaponGradeFor(state, weaponId)
end

function ProgressionService.getActiveWeapons(player): { [string]: { weaponId: string, grade: string } }?
	local state = progressByPlayer[player]
	if not state then
		return nil
	end
	local aw = state.activeWeapons
	if type(aw) ~= "table" then
		return nil
	end
	return aw
end

--- Sorted weaponIds with a non-empty Phase3 pool from activeWeapons; primary fallback if empty.
function ProgressionService.getActiveWeaponIdsForPhase3Offer(player): { string }
	local ids: { string } = {}
	local aw = ProgressionService.getActiveWeapons(player)
	if type(aw) == "table" then
		for weaponId, entry in pairs(aw) do
			if type(weaponId) == "string" and weaponId ~= "" and type(entry) == "table" then
				table.insert(ids, weaponId)
			end
		end
	end
	table.sort(ids)

	local poolMod = phase3RelicPoolModule
	local filtered: { string } = {}
	if type(poolMod) == "table" and type(poolMod.getRelicIdsForWeapon) == "function" then
		for _, weaponId in ipairs(ids) do
			local pool = poolMod.getRelicIdsForWeapon(weaponId)
			if type(pool) == "table" and #pool > 0 then
				table.insert(filtered, weaponId)
			end
		end
	end
	if #filtered > 0 then
		return filtered
	end

	local primary = ProgressionService.getWeaponId(player)
	if type(primary) == "string" and primary ~= "" then
		return { primary }
	end
	return {}
end

function ProgressionService.getPhase3ActiveRelicIds(player): { string }
	local state = progressByPlayer[player]
	local src = type(state) == "table" and state.phase3ActiveRelicIds
	if type(src) ~= "table" then
		return {}
	end
	local out: { string } = {}
	for _, relicId in ipairs(src) do
		if type(relicId) == "string" and relicId ~= "" then
			table.insert(out, relicId)
		end
	end
	return out
end

function ProgressionService.tryApplyWeaponDropPickup(player, weaponIdFromDrop: string): boolean
	local state = progressByPlayer[player]
	local function notify(kind: string)
		fireWeaponPickupNotify(player, kind)
	end
	local function verbose(msg: string)
		debugProgression(msg)
	end
	return WeaponProgression.tryApplyWeaponDropPickup(state, player, weaponIdFromDrop, notify, verbose)
end

function ProgressionService.setImmediateHudPush(callback)
	immediateHudPush = callback
end

local function xpRequiredForLevel(level)
	if not gameConfigRef then
		return 100 * level
	end
	return gameConfigRef.XpRequiredPerLevelBase * level
end

local upgradeDataModule = nil

local function defaultUpgradeZeros()
	if not upgradeDataModule then
		return {
			damage_up = 0,
			attack_interval_down = 0,
			attack_size_up = 0,
		}
	end
	if type(upgradeDataModule.createZeroUpgradeTable) == "function" then
		return upgradeDataModule.createZeroUpgradeTable()
	end
	local t = {}
	for _, choice in ipairs(upgradeDataModule.Choices) do
		t[choice.Id] = 0
	end
	for _, choice in ipairs(upgradeDataModule.SwordShieldChoices) do
		t[choice.Id] = 0
	end
	return t
end

local function fillMissingUpgradeKeys(upgrades)
	if not upgradeDataModule then
		return
	end
	if type(upgradeDataModule.fillMissingUpgradeKeys) == "function" then
		upgradeDataModule.fillMissingUpgradeKeys(upgrades)
		return
	end
	for _, choice in ipairs(upgradeDataModule.Choices) do
		if upgrades[choice.Id] == nil then
			upgrades[choice.Id] = 0
		end
	end
	for _, choice in ipairs(upgradeDataModule.SwordShieldChoices) do
		if upgrades[choice.Id] == nil then
			upgrades[choice.Id] = 0
		end
	end
end

function ProgressionService.getHudProgress(player)
	local state = progressByPlayer[player]
	if not state then
		return {
			level = 1,
			xp = 0,
			xpToNext = xpRequiredForLevel(1),
		}
	end

	return {
		level = state.level,
		xp = state.xp,
		xpToNext = xpRequiredForLevel(state.level),
	}
end

function ProgressionService.getUpgradeCounts(player)
	local state = progressByPlayer[player]
	if not state or not state.upgrades then
		return defaultUpgradeZeros()
	end
	return state.upgrades
end

local function getHealthUpgradeStackFromState(state): number
	if type(state) ~= "table" or type(state.upgrades) ~= "table" then
		return 0
	end
	local raw = state.upgrades[HEALTH_UPGRADE_ID]
	if type(raw) ~= "number" or raw <= 0 then
		return 0
	end
	return math.max(0, math.floor(raw + 0.5))
end

local function getXpUpgradeStackFromState(state): number
	if type(state) ~= "table" or type(state.upgrades) ~= "table" then
		return 0
	end
	local raw = state.upgrades[XP_UPGRADE_ID]
	if type(raw) ~= "number" or raw <= 0 then
		return 0
	end
	return math.max(0, math.floor(raw + 0.5))
end

local function getSpeedUpgradeStackFromState(state): number
	if type(state) ~= "table" or type(state.upgrades) ~= "table" then
		return 0
	end
	local raw = state.upgrades[SPEED_UPGRADE_ID]
	if type(raw) ~= "number" or raw <= 0 then
		return 0
	end
	return math.max(0, math.floor(raw + 0.5))
end

local function getMagnetRangeUpgradeStackFromState(state): number
	if type(state) ~= "table" or type(state.upgrades) ~= "table" then
		return 0
	end
	local raw = state.upgrades[MAGNET_RANGE_UPGRADE_ID]
	if type(raw) ~= "number" or raw <= 0 then
		return 0
	end
	return math.max(0, math.floor(raw + 0.5))
end

local function getHealthOrbAmountUpgradeStackFromState(state): number
	if type(state) ~= "table" or type(state.upgrades) ~= "table" then
		return 0
	end
	local raw = state.upgrades[HEALTH_ORB_AMOUNT_UPGRADE_ID]
	if type(raw) ~= "number" or raw <= 0 then
		return 0
	end
	return math.max(0, math.floor(raw + 0.5))
end

local function getHealthOrbChanceUpgradeStackFromState(state): number
	if type(state) ~= "table" or type(state.upgrades) ~= "table" then
		return 0
	end
	local raw = state.upgrades[HEALTH_ORB_CHANCE_UPGRADE_ID]
	if type(raw) ~= "number" or raw <= 0 then
		return 0
	end
	return math.max(0, math.floor(raw + 0.5))
end

function ProgressionService.getEffectiveMaxHealthFor(player, baseMaxHealth: number): number
	local base = baseMaxHealth
	if type(base) ~= "number" or base <= 0 then
		base = 100
	end
	local state = progressByPlayer[player]
	local stack = getHealthUpgradeStackFromState(state)
	local effective = base + HEALTH_UPGRADE_BONUS_PER_STACK * stack
	return math.max(1, effective)
end

function ProgressionService.getEffectiveWalkSpeedFor(player, baseWalkSpeed: number): number
	local base = tonumber(baseWalkSpeed) or 16
	if base <= 0 then
		base = 16
	end
	local state = progressByPlayer[player]
	local stack = getSpeedUpgradeStackFromState(state)
	local effective = base * (1 + SPEED_UPGRADE_MUL_PER_STACK * stack)
	return math.max(0, effective)
end

local function applyHealthUpgradeToCurrentCharacter(player, state)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	local baseMax = gameConfigRef and gameConfigRef.PlayerBaseHealth or 100
	if type(baseMax) ~= "number" or baseMax <= 0 then
		baseMax = 100
	end
	local oldMax = hum.MaxHealth
	if type(oldMax) ~= "number" or oldMax <= 0 then
		oldMax = baseMax
	end
	local stack = getHealthUpgradeStackFromState(state)
	local newMax = math.max(1, baseMax + HEALTH_UPGRADE_BONUS_PER_STACK * stack)
	local delta = newMax - oldMax
	hum.MaxHealth = newMax
	local oldHealth = hum.Health
	if type(oldHealth) ~= "number" or oldHealth < 0 then
		oldHealth = 0
	end
	hum.Health = math.clamp(oldHealth + math.max(0, delta), 0, newMax)
end

local function applySpeedUpgradeToCurrentCharacter(player, state)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	local baseWalkSpeed = gameConfigRef and gameConfigRef.PlayerBaseWalkSpeed or 16
	if type(baseWalkSpeed) ~= "number" or baseWalkSpeed <= 0 then
		baseWalkSpeed = 16
	end
	local stack = getSpeedUpgradeStackFromState(state)
	local effectiveWalkSpeed = baseWalkSpeed * (1 + SPEED_UPGRADE_MUL_PER_STACK * stack)
	hum.WalkSpeed = math.max(0, effectiveWalkSpeed)
end

local function syncHealthUpgradeStackAttribute(player, state)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return
	end
	player:SetAttribute("ab_Health_increase_stack", getHealthUpgradeStackFromState(state))
end

local function syncXpUpgradeStackAttribute(player, state)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return
	end
	player:SetAttribute("ab_xp_increase_stack", getXpUpgradeStackFromState(state))
end

local function syncSpeedUpgradeStackAttribute(player, state)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return
	end
	player:SetAttribute("ab_Speed_increase_stack", getSpeedUpgradeStackFromState(state))
end

local function syncMagnetRangeUpgradeStackAttribute(player, state)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return
	end
	player:SetAttribute("mg_Range_increase_stack", getMagnetRangeUpgradeStackFromState(state))
end

local function syncHealthOrbAmountUpgradeStackAttribute(player, state)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return
	end
	player:SetAttribute("ho_Amount_increase_stack", getHealthOrbAmountUpgradeStackFromState(state))
end

local function syncHealthOrbChanceUpgradeStackAttribute(player, state)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return
	end
	player:SetAttribute("ho_Chance_increase_stack", getHealthOrbChanceUpgradeStackFromState(state))
end

local function buildOfferForPlayer(player): ({ { Id: string, Label: string } }, { [string]: boolean })
	local upgradeData = upgradeDataModule :: any
	local st = progressByPlayer[player]
	local poolWeaponId = st and st.weaponId
	if poolWeaponId ~= "SwordShield" and poolWeaponId ~= "BasicMagic" then
		poolWeaponId = RunWeaponResolver.resolveEffectiveWeaponId(gameConfigRef)
	end

	local relicId = st and st.startingRelicId or nil
local activeWeapons = st and st.activeWeapons or nil
return UpgradeOfferBuilder.buildUpgradeOffer(poolWeaponId, relicId, upgradeData, relicDataModule, {
	activeWeapons = activeWeapons,
})
end

local function flushUpgradeOfferQueue(player: Player)
	debugProgression("[Progression][FLUSH_ENTER]", player.Name)
	if not levelUpChoiceEvent or not upgradeDataModule then
		debugProgression("[Progression][FLUSH_BLOCKED_NO_EVENT_OR_DATA]", player.Name)
		return
	end
	if pendingLevelUpOfferByPlayer[player] then
		debugProgression("[Progression][FLUSH_BLOCKED_PENDING_LEVEL]", player.Name)
		return
	end
	if pendingStartingWeaponByPlayer[player] then
		debugProgression("[Progression][FLUSH_BLOCKED_PENDING_START_WEAPON]", player.Name)
		return
	end
	if pendingPhase3RelicByPlayer[player] then
		debugProgression("[Progression][FLUSH_BLOCKED_PENDING_PHASE3]", player.Name)
		return
	end
	local state = progressByPlayer[player]
	if state and state.phase3RelicOfferPending == true then
		debugProgression("[Progression][FLUSH_BLOCKED_PHASE3_OFFER_PENDING]", player.Name)
		return
	end
	if not state or not state.upgradeOfferQueue or #state.upgradeOfferQueue == 0 then
		debugProgression("[Progression][FLUSH_EMPTY_QUEUE]", player.Name)
		return
	end
	local lvl = table.remove(state.upgradeOfferQueue, 1)
	local picked, pendingMap = buildOfferForPlayer(player)
	pendingLevelUpOfferByPlayer[player] = pendingMap
	debugProgression(
		"[Progression][FIRE_UPGRADE_FLUSH]",
		player.Name,
		"level",
		lvl,
		"choices",
		#picked,
		"queueLeft",
		#(state.upgradeOfferQueue or {})
	)
	
	levelUpChoiceEvent:FireClient(player, {
		Level = lvl,
		Choices = picked,
		ChoiceKind = "Upgrade",
	})
end

local function tryFlushPhase3RelicOffer(player: Player)
	if not levelUpChoiceEvent then
		return
	end
	local state = progressByPlayer[player]
	if not state or state.phase3RelicOfferPending ~= true then
		return
	end
	local choices = state.phase3RelicOfferChoices
	if type(choices) ~= "table" or #choices == 0 then
		return
	end
	if pendingLevelUpOfferByPlayer[player] then
		return
	end
	if pendingStartingWeaponByPlayer[player] then
		return
	end
	if pendingPhase3RelicByPlayer[player] then
		return
	end

	local allowed = {}
	for _, c in ipairs(choices) do
		if type(c) == "table" and type(c.Id) == "string" then
			allowed[c.Id] = true
		end
	end
	pendingPhase3RelicByPlayer[player] = allowed
	state.phase3RelicOfferPending = false
	state.phase3RelicOfferChoices = nil
	levelUpChoiceEvent:FireClient(player, {
		ChoiceKind = "Phase3Relic",
		Title = "Choose Relic",
		Choices = choices,
	})
end

local function sanitizeBasicMagicRelicState(player: Player, s)
	if s.weaponId ~= "BasicMagic" then
		return
	end
	s.startingRelicId = nil
	s.phase3RelicOfferPending = false
	s.phase3RelicOfferChoices = nil
	pendingStartingWeaponByPlayer[player] = nil
	pendingPhase3RelicByPlayer[player] = nil
end

function ProgressionService.init(players, replicatedStorage, gameConfig)
	gameConfigRef = gameConfig

	do
		local remotesFolder = replicatedStorage:WaitForChild("Remotes")
		local wpn = remotesFolder:FindFirstChild("WeaponPickupNotify")
		if wpn and wpn:IsA("RemoteEvent") then
			weaponPickupNotifyEvent = wpn
		else
			warn("[ProgressionService] Remotes.WeaponPickupNotify missing — weapon pickup notify disabled.")
			weaponPickupNotifyEvent = nil
		end
	end
	local shared = replicatedStorage:WaitForChild("Shared")
	local upgradeData = require(shared:WaitForChild("UpgradeData"))
	local weaponProfiles = require(shared:WaitForChild("WeaponProfiles"))
	relicDataModule = require(shared:WaitForChild("RelicData"))
	relicDefinitionsModule = require(shared:WaitForChild("RelicDefinitions"))
	phase3RelicPoolModule = require(shared:WaitForChild("Phase3RelicPool"))
	upgradeDataModule = upgradeData

	local allowedChoiceIds: { [string]: boolean } = {}
	for _, choice in ipairs(upgradeData.Choices) do
		allowedChoiceIds[choice.Id] = true
	end
	for _, choice in ipairs(upgradeData.SwordShieldChoices) do
		allowedChoiceIds[choice.Id] = true
	end

	local function newUpgradeTable()
		if type(upgradeData.createZeroUpgradeTable) == "function" then
			return upgradeData.createZeroUpgradeTable()
		end
		local t = {}
		for _, choice in ipairs(upgradeData.Choices) do
			t[choice.Id] = 0
		end
		for _, choice in ipairs(upgradeData.SwordShieldChoices) do
			t[choice.Id] = 0
		end
		return t
	end

	levelUpChoiceEvent = replicatedStorage:FindFirstChild("LevelUpChoiceRequest")
	if not levelUpChoiceEvent then
		levelUpChoiceEvent = Instance.new("RemoteEvent")
		levelUpChoiceEvent.Name = "LevelUpChoiceRequest"
		levelUpChoiceEvent.Parent = replicatedStorage
	end

	local submitEvent = replicatedStorage:FindFirstChild("LevelUpChoiceSubmit")
	if not submitEvent then
		submitEvent = Instance.new("RemoteEvent")
		submitEvent.Name = "LevelUpChoiceSubmit"
		submitEvent.Parent = replicatedStorage
	end

	submitEvent.OnServerEvent:Connect(function(player, choiceId)
		if type(choiceId) ~= "string" then
			warn(string.format("[Progression] LevelUpChoiceSubmit: invalid payload from %s", player.Name))
			return
		end

		local weaponPending = pendingStartingWeaponByPlayer[player]
		if weaponPending then
			if not weaponPending[choiceId] then
				warn(string.format("[Progression] StartingWeapon submit: choiceId not in pending offer (%s / %s)", choiceId, player.Name))
				return
			end
			local st = progressByPlayer[player]
			if not st then
				pendingStartingWeaponByPlayer[player] = nil
				warn(string.format("[Progression] StartingWeapon submit: rejected — no state (%s)", player.Name))
				return
			end
			st.weaponId = choiceId
			st.weaponGrade = "Normal"
			st.activeWeapons = {
				[choiceId] = {
					weaponId = choiceId,
					grade = "Normal",
				},
			}
			pendingStartingWeaponByPlayer[player] = nil
			flushUpgradeOfferQueue(player)
			tryFlushPhase3RelicOffer(player)
			if immediateHudPush then
				immediateHudPush(player)
			end
			return
		end

		local phase3Pending = pendingPhase3RelicByPlayer[player]
		if phase3Pending then
			if not phase3Pending[choiceId] then
				warn(string.format("[Progression] Phase3Relic submit: choiceId not in pending offer (%s / %s)", choiceId, player.Name))
				return
			end
			if not ProgressionService.addPhase3Relic(player, choiceId) then
				warn(string.format("[Progression] Phase3Relic submit: addPhase3Relic failed (%s / %s)", choiceId, player.Name))
				return
			end
			pendingPhase3RelicByPlayer[player] = nil
			local stPhase3 = progressByPlayer[player]
			if stPhase3 then
				stPhase3.phase3RelicOfferPending = false
				stPhase3.phase3RelicOfferChoices = nil
			end
			flushUpgradeOfferQueue(player)
			tryFlushPhase3RelicOffer(player)
			if immediateHudPush then
				immediateHudPush(player)
			end
			return
		end

		local pending = pendingLevelUpOfferByPlayer[player]
		debugProgression(
			"[Progression][SUBMIT_UPGRADE_RECEIVED]",
			player.Name,
			"choiceId",
			choiceId,
			"hasPending",
			pendingLevelUpOfferByPlayer[player] ~= nil
		)
		if pending and pending[choiceId] then
			-- offered choice: proceed
		elseif pending then
			warn(
				string.format(
					"[Progression] Upgrade submit: no pending offer or choiceId not offered (%s / %s)",
					choiceId,
					player.Name
				)
			)
			return
		elseif not allowedChoiceIds[choiceId] then
			warn(string.format("[Progression] unknown choiceId=%s (%s)", choiceId, player.Name))
			return
		else
			warn(
				string.format(
					"[Progression] Upgrade submit: no pending offer or choiceId not offered (%s / %s)",
					choiceId,
					player.Name
				)
			)
			return
		end

		local state = progressByPlayer[player]
		if not state then
			warn("[Progression] Upgrade submit rejected: no progress state", player.Name)
			return
		end
		-- PATCH_TAG: PS_GUARD_FIX_20260507
		local upgrades = state.upgrades
		if type(upgrades) ~= "table" then
			upgrades = {}
			state.upgrades = upgrades
		end

		upgrades[choiceId] = (upgrades[choiceId] or 0) + 1
		if choiceId == XP_UPGRADE_ID then
			syncXpUpgradeStackAttribute(player, state)
		elseif choiceId == HEALTH_UPGRADE_ID then
			syncHealthUpgradeStackAttribute(player, state)
			applyHealthUpgradeToCurrentCharacter(player, state)
		elseif choiceId == SPEED_UPGRADE_ID then
			syncSpeedUpgradeStackAttribute(player, state)
			applySpeedUpgradeToCurrentCharacter(player, state)
		elseif choiceId == MAGNET_RANGE_UPGRADE_ID then
			syncMagnetRangeUpgradeStackAttribute(player, state)
		elseif choiceId == HEALTH_ORB_AMOUNT_UPGRADE_ID then
			syncHealthOrbAmountUpgradeStackAttribute(player, state)
		elseif choiceId == HEALTH_ORB_CHANCE_UPGRADE_ID then
			syncHealthOrbChanceUpgradeStackAttribute(player, state)
		end
		pendingLevelUpOfferByPlayer[player] = nil
		debugProgression("[Progression][SUBMIT_UPGRADE_CLEAR_PENDING]", player.Name)
		debugProgression(
			"[Progression][SUBMIT_UPGRADE_APPLIED]",
			player.Name,
			"choiceId",
			choiceId,
			"newStack",
			upgrades[choiceId]
		)

		local u = upgrades
		if string.sub(choiceId, 1, 3) == "ss_" then
			local eff = upgradeData.getSwordShieldEffectiveCombat(
				gameConfigRef,
				weaponProfiles.SwordShield,
				u,
				state.startingRelicId,
				state.weaponGrade,
				ProgressionService.getPhase3ActiveRelicIds(player)
			)
			debugProgression(
				string.format(
					"[Progression] %s | SS 선택: %s | 간격 %.3fs | Sweep 피해 %.2f 각%.1f | Thrust 피해 %.2f 길이%.1f 폭%.1f",
					player.Name,
					choiceId,
					eff.AttackIntervalSeconds,
					eff.Sweep.BaseDamage,
					eff.Sweep.AngleDeg,
					eff.Thrust.BaseDamage,
					eff.Thrust.RangeStuds,
					eff.Thrust.WidthStuds
				)
			)
		else
			local stats = upgradeData.getEffectiveCombatStats(gameConfigRef, u)
			debugProgression(
				string.format(
					"[Progression] %s | 선택: %s | 스택 피해%d 공속%d 사거리%d | 결과 → 피해량 %d | 공격간격 %.3fs | 사거리 %.1f 스터드",
					player.Name,
					choiceId,
					u.damage_up or 0,
					u.attack_interval_down or 0,
					u.attack_size_up or 0,
					stats.damagePerHit,
					stats.attackIntervalSeconds,
					stats.attackRangeStuds
				)
			)
		end

		tryFlushPhase3RelicOffer(player)
		flushUpgradeOfferQueue(player)
	end)

	local function copyPhase3TestRelicIdsFromConfig(): { string }
		local out: { string } = {}
		local dbg = gameConfigRef and gameConfigRef.Debug
		if type(dbg) ~= "table" then
			return out
		end
		local src = dbg.Phase3TestRelicIds
		if type(src) ~= "table" or #src == 0 then
			return out
		end
		for _, relicId in ipairs(src) do
			if type(relicId) == "string" and relicId ~= "" then
				table.insert(out, relicId)
			end
		end
		return out
	end

	local function ensureProgress(player)
		local eff = RunWeaponResolver.resolveEffectiveWeaponId(gameConfigRef)
		local dbg = gameConfigRef and gameConfigRef.Debug
		local hasOverride = type(dbg) == "table" and (dbg.OverrideWeaponId == "SwordShield" or dbg.OverrideWeaponId == "BasicMagic")

		if not progressByPlayer[player] then
			progressByPlayer[player] = {
				level = 1,
				xp = 0,
				upgrades = newUpgradeTable(),
				startingRelicId = nil,
				weaponId = eff,
				weaponGrade = "Normal",
				activeWeapons = {},
				upgradeOfferQueue = {},
				phase3ActiveRelicIds = copyPhase3TestRelicIdsFromConfig(),
				phase3RelicOfferPending = false,
				phase3RelicOfferChoices = nil,
			}
		else
			local s = progressByPlayer[player]
			if not s.upgrades then
				s.upgrades = newUpgradeTable()
			else
				fillMissingUpgradeKeys(s.upgrades)
			end
			if not s.upgradeOfferQueue then
				s.upgradeOfferQueue = {}
			end
			if s.phase3ActiveRelicIds == nil then
				s.phase3ActiveRelicIds = copyPhase3TestRelicIdsFromConfig()
			end
			if s.phase3RelicOfferPending == nil then
				s.phase3RelicOfferPending = false
			end
			if s.phase3RelicOfferChoices == nil then
				s.phase3RelicOfferChoices = nil
			end
		end
		local finalState = progressByPlayer[player]

		WeaponProgression.ensureWeaponFields(finalState, eff, hasOverride)
		if finalState.startingRelicId == nil then
			local runCtxRelicId = resolveStartingRelicIdFromRunContext()
			if type(runCtxRelicId) == "string" and runCtxRelicId ~= "" then
				finalState.startingRelicId = runCtxRelicId
			end
		end
		syncXpUpgradeStackAttribute(player, finalState)
		syncHealthUpgradeStackAttribute(player, finalState)
		syncSpeedUpgradeStackAttribute(player, finalState)
		syncMagnetRangeUpgradeStackAttribute(player, finalState)
		syncHealthOrbAmountUpgradeStackAttribute(player, finalState)
		syncHealthOrbChanceUpgradeStackAttribute(player, finalState)

		sanitizeBasicMagicRelicState(player, finalState)
		return finalState
	end

	players.PlayerAdded:Connect(function(player)
		ensureProgress(player)
	end)

	players.PlayerRemoving:Connect(function(player)
		progressByPlayer[player] = nil
		pendingLevelUpOfferByPlayer[player] = nil
		pendingStartingWeaponByPlayer[player] = nil
		pendingPhase3RelicByPlayer[player] = nil
	end)

	for _, player in players:GetPlayers() do
		ensureProgress(player)
	end
end

function ProgressionService.addExperience(player, amount)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return
	end
	if type(amount) ~= "number" or amount <= 0 then
		return
	end

	local state = progressByPlayer[player]
	if not state then
		return
	end

	local stackRaw = player:GetAttribute("ab_xp_increase_stack")
	local stack = 0
	if type(stackRaw) == "number" and stackRaw > 0 then
		stack = math.max(0, math.floor(stackRaw + 0.5))
	end
	local effectiveAmount = amount * (1 + XP_UPGRADE_MUL_PER_STACK * stack)
	effectiveAmount = math.floor(effectiveAmount + 0.5)
	if effectiveAmount <= 0 then
		return
	end

	state.xp += effectiveAmount

	while true do
		local need = xpRequiredForLevel(state.level)
		if state.xp < need then
			break
		end

		state.xp -= need
		state.level += 1
		debugProgression(
			"[Progression][LEVELUP]",
			player.Name,
			"level",
			state.level,
			"xp",
			state.xp,
			"pendingLevel",
			pendingLevelUpOfferByPlayer[player] ~= nil,
			"queue",
			#(state.upgradeOfferQueue or {})
		)

		if levelUpChoiceEvent and upgradeDataModule then
			if pendingPhase3RelicByPlayer[player]
				or state.phase3RelicOfferPending == true then
				debugProgression(
					"[Progression][QUEUE_UPGRADE]",
					player.Name,
					"level",
					state.level,
					"queue",
					#(state.upgradeOfferQueue or {}),
					"pendingLevel",
					pendingLevelUpOfferByPlayer[player] ~= nil
				)
				table.insert(state.upgradeOfferQueue, state.level)
			elseif pendingLevelUpOfferByPlayer[player] then
				debugProgression(
					"[Progression][QUEUE_UPGRADE]",
					player.Name,
					"level",
					state.level,
					"queue",
					#(state.upgradeOfferQueue or {}),
					"pendingLevel",
					pendingLevelUpOfferByPlayer[player] ~= nil
				)
				table.insert(state.upgradeOfferQueue, state.level)
			else
				local picked, pendingMap = buildOfferForPlayer(player)
				pendingLevelUpOfferByPlayer[player] = pendingMap
				debugProgression(
					"[Progression][FIRE_UPGRADE_IMMEDIATE]",
					player.Name,
					"level",
					state.level,
					"choices",
					#picked
				)
				levelUpChoiceEvent:FireClient(player, {
					Level = state.level,
					Choices = picked,
					ChoiceKind = "Upgrade",
				})
			end
		end

		if immediateHudPush then
			immediateHudPush(player)
		end
	end
end

function ProgressionService.getStartingRelicId(player): string?
	local state = progressByPlayer[player]
	if not state then
		return nil
	end
	return state.startingRelicId
end

function ProgressionService.hasPhase3Relic(player, relicId: string): boolean
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return false
	end
	if type(relicId) ~= "string" or relicId == "" then
		return false
	end
	for _, id in ipairs(ProgressionService.getPhase3ActiveRelicIds(player)) do
		if id == relicId then
			return true
		end
	end
	return false
end

function ProgressionService.addPhase3Relic(player, relicId: string): boolean
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return false
	end
	if type(relicId) ~= "string" or relicId == "" then
		return false
	end
	if ProgressionService.hasPhase3Relic(player, relicId) then
		return false
	end
	if type(relicDefinitionsModule) ~= "table" or relicDefinitionsModule.getDefinition(relicId) == nil then
		return false
	end
	local state = progressByPlayer[player]
	if not state then
		return false
	end
	if type(state.phase3ActiveRelicIds) ~= "table" then
		state.phase3ActiveRelicIds = {}
	end
	table.insert(state.phase3ActiveRelicIds, relicId)
	if immediateHudPush then
		immediateHudPush(player)
	end
	return true
end

function ProgressionService.buildPhase3RelicOffer(player: Player)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return nil
	end
	if type(phase3RelicPoolModule) ~= "table" then
		return nil
	end
	local weaponIds = ProgressionService.getActiveWeaponIdsForPhase3Offer(player)
	local owned = ProgressionService.getPhase3ActiveRelicIds(player)
	local choices = phase3RelicPoolModule.buildOfferChoicesForWeapons(weaponIds, owned, 3)
	if type(choices) ~= "table" or #choices == 0 then
		return nil
	end
	local allowed: { [string]: boolean } = {}
	for _, c in ipairs(choices) do
		if type(c) == "table" and type(c.Id) == "string" then
			allowed[c.Id] = true
		end
	end
	return choices, allowed
end

function ProgressionService.tryGrantPhase3RelicOfferFromChest(player): boolean
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return false
	end
	local state = progressByPlayer[player]
	if not state then
		return false
	end
	local choices = ProgressionService.buildPhase3RelicOffer(player)
	if choices == nil then
		return false
	end
	state.phase3RelicOfferPending = true
	state.phase3RelicOfferChoices = choices
	tryFlushPhase3RelicOffer(player)
	return true
end

function ProgressionService.tryOfferStartingWeapon(player)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return
	end
	if not levelUpChoiceEvent then
		return
	end
	local state = progressByPlayer[player]
	if not state then
		return
	end
	if pendingStartingWeaponByPlayer[player] then
		return
	end
	if pendingLevelUpOfferByPlayer[player] then
		return
	end
	if pendingPhase3RelicByPlayer[player] then
		return
	end
	local stWeapon = progressByPlayer[player]
	if stWeapon and stWeapon.phase3RelicOfferPending == true then
		return
	end

	local choices = {
		{ Id = "SwordShield", Label = "Sword & Shield" },
		{ Id = "Spear", Label = "Spear" },
		{ Id = "TwoHandedSword", Label = "Two-Handed Sword" },
	}
	local allowed = {
		SwordShield = true,
		Spear = true,
		TwoHandedSword = true,
	}
	pendingStartingWeaponByPlayer[player] = allowed
	levelUpChoiceEvent:FireClient(player, {
		ChoiceKind = "StartingWeapon",
		Title = "Choose Test Weapon",
		Choices = choices,
	})
end

return ProgressionService

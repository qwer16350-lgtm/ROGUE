local ProgressionService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local RunWeaponResolver = require(Shared:WaitForChild("RunWeaponResolver"))
local UpgradeOfferBuilder = require(script.Parent:WaitForChild("Progression"):WaitForChild("UpgradeOfferBuilder"))
local WeaponProgression = require(script.Parent:WaitForChild("Progression"):WaitForChild("WeaponProgression"))

local progressByPlayer = {}
local levelUpChoiceEvent = nil
local gameConfigRef = nil
local immediateHudPush = nil

--- Progression: 레벨업 풀은 state.weaponId 가 SwordShield 일 때만 SwordShield 7종 풀 사용.

--- [Player] = { [choiceId: string]: true } — 직전 레벨업에서 제시된 선택지만 true
local pendingLevelUpOfferByPlayer: { [Player]: { [string]: boolean } } = {}
--- Starting Relic 3택 pending (Relic Id 만 허용). LevelUp pending 과 동시에 두지 않음.
local pendingStartingRelicByPlayer: { [Player]: { [string]: boolean } } = {}
--- Step 4-1: Dropped Relic 3택 pending (고정 Id 만 허용).
local pendingDroppedRelicByPlayer: { [Player]: { [string]: boolean } } = {}

local function progressionVerbose(): boolean
	local d = gameConfigRef and gameConfigRef.Debug
	return type(d) == "table" and d.ProgressionVerbose == true
end

local relicDataModule = nil
local weaponPickupNotifyEvent: RemoteEvent? = nil

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

-- 신규: 무기별 grade 조회 (activeWeapons 우선)
function ProgressionService.getWeaponGradeFor(player, weaponId: string): string
	local state = progressByPlayer[player]
	return WeaponProgression.getWeaponGradeFor(state, weaponId)
end

-- 신규: activeWeapons 조회 (없으면 nil)
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

function ProgressionService.tryApplyWeaponDropPickup(player, weaponIdFromDrop: string): boolean
	local state = progressByPlayer[player]
	local function notify(kind: string)
		fireWeaponPickupNotify(player, kind)
	end
	local function verbose(msg: string)
		if progressionVerbose() then
			print(msg)
		end
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

--- module init 이후 호출 전까지 빈 테이블 폴백
local upgradeDataModule = nil

local function defaultUpgradeZeros()
	local t = {}
	if not upgradeDataModule then
		return {
			damage_up = 0,
			attack_interval_down = 0,
			attack_size_up = 0,
		}
	end
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
	print("[Progression][FLUSH_ENTER]", player.Name)
	if not levelUpChoiceEvent or not upgradeDataModule then
		print("[Progression][FLUSH_BLOCKED_NO_EVENT_OR_DATA]", player.Name)
		return
	end
	if pendingLevelUpOfferByPlayer[player] then
		print("[Progression][FLUSH_BLOCKED_PENDING_LEVEL]", player.Name)
		return
	end
	if pendingStartingRelicByPlayer[player] then
		print("[Progression][FLUSH_BLOCKED_PENDING_START]", player.Name)
		return
	end
	if pendingDroppedRelicByPlayer[player] then
		print("[Progression][FLUSH_BLOCKED_PENDING_DROP]", player.Name)
		return
	end
	local state = progressByPlayer[player]
	if not state or not state.upgradeOfferQueue or #state.upgradeOfferQueue == 0 then
		print("[Progression][FLUSH_EMPTY_QUEUE]", player.Name)
		return
	end
	local lvl = table.remove(state.upgradeOfferQueue, 1)
	local picked, pendingMap = buildOfferForPlayer(player)
	pendingLevelUpOfferByPlayer[player] = pendingMap
	print(
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

local function tryFlushDroppedRelicOffer(player: Player)
	if not levelUpChoiceEvent or not relicDataModule then
		return
	end
	local state = progressByPlayer[player]
	if not state then
		return
	end
	if state.weaponId ~= "SwordShield" then
		return
	end
	if state.droppedRelicOfferConsumed or state.droppedRelicId ~= nil then
		return
	end
	if not state.droppedRelicOfferPending then
		return
	end
	if pendingStartingRelicByPlayer[player] then
		return
	end
	if pendingLevelUpOfferByPlayer[player] then
		return
	end
	if pendingDroppedRelicByPlayer[player] then
		return
	end
	local choices = relicDataModule.getDroppedRelicChoices()
	local allowed = {}
	for _, c in ipairs(choices) do
		allowed[c.Id] = true
	end
	pendingDroppedRelicByPlayer[player] = allowed
	state.droppedRelicOfferPending = false
	levelUpChoiceEvent:FireClient(player, {
		ChoiceKind = "DroppedRelic",
		Title = "Dropped Relic",
		Choices = choices,
	})
end

local function sanitizeBasicMagicRelicState(player: Player, s)
	if s.weaponId ~= "BasicMagic" then
		return
	end
	--- BasicMagic 런: SwordShield 전용 Starting/Dropped Relic 비활성 — 스테일 필드·pending 제거
	s.startingRelicId = nil
	s.droppedRelicId = nil
	s.droppedRelicOfferPending = false
	s.droppedRelicOfferConsumed = true
	pendingStartingRelicByPlayer[player] = nil
	pendingDroppedRelicByPlayer[player] = nil
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
	upgradeDataModule = upgradeData

	local allowedChoiceIds: { [string]: boolean } = {}
	for _, choice in ipairs(upgradeData.Choices) do
		allowedChoiceIds[choice.Id] = true
	end
	for _, choice in ipairs(upgradeData.SwordShieldChoices) do
		allowedChoiceIds[choice.Id] = true
	end

	local function newUpgradeTable()
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

		local relicPending = pendingStartingRelicByPlayer[player]
		if relicPending then
			local st = progressByPlayer[player]
			if not st or st.weaponId ~= "SwordShield" then
				pendingStartingRelicByPlayer[player] = nil
				warn(string.format("[Progression] StartingRelic submit: rejected — not SwordShield run (%s)", player.Name))
				return
			end
			if not relicPending[choiceId] then
				warn(
					string.format(
						"[Progression] StartingRelic submit: choiceId not in pending offer (%s / %s)",
						choiceId,
						player.Name
					)
				)
				return
			end
			st.startingRelicId = choiceId
			pendingStartingRelicByPlayer[player] = nil
			flushUpgradeOfferQueue(player)
			tryFlushDroppedRelicOffer(player)
			return
		end

		local dropPending = pendingDroppedRelicByPlayer[player]
		if dropPending then
			local st = progressByPlayer[player]
			if not st or st.weaponId ~= "SwordShield" then
				pendingDroppedRelicByPlayer[player] = nil
				warn(string.format("[Progression] DroppedRelic submit: rejected — not SwordShield run (%s)", player.Name))
				return
			end
			if not dropPending[choiceId] then
				warn(
					string.format(
						"[Progression] DroppedRelic submit: choiceId not in pending offer (%s / %s)",
						choiceId,
						player.Name
					)
				)
				return
			end
			st.droppedRelicId = choiceId
			st.droppedRelicOfferConsumed = true
			pendingDroppedRelicByPlayer[player] = nil
			flushUpgradeOfferQueue(player)
			tryFlushDroppedRelicOffer(player)
			return
		end

		local pending = pendingLevelUpOfferByPlayer[player]
		print(
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
		pendingLevelUpOfferByPlayer[player] = nil
		print("[Progression][SUBMIT_UPGRADE_CLEAR_PENDING]", player.Name)
		print( "[Progression][SUBMIT_UPGRADE_APPLIED]",
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
				state.droppedRelicId,
				state.weaponGrade
			)
			if progressionVerbose() then
				print(
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
			end
		else
			local stats = upgradeData.getEffectiveCombatStats(gameConfigRef, u)
			if progressionVerbose() then
				print(
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
		end

		tryFlushDroppedRelicOffer(player)
		flushUpgradeOfferQueue(player)
	end)

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
				droppedRelicId = nil,
				droppedRelicOfferPending = false,
				droppedRelicOfferConsumed = false,
				--- 로비 무기 선택/TeleportData 연동 시 이 필드는 런 진입 페이로드로 시드할 수 있음.
				weaponId = eff,
				weaponGrade = "Normal",
				-- 신규: multi-weapon 기반
				activeWeapons = {},
				upgradeOfferQueue = {},
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
			if s.droppedRelicLv6PendingAfterUpgrade ~= nil and s.droppedRelicOfferPending == nil then
				s.droppedRelicOfferPending = s.droppedRelicLv6PendingAfterUpgrade == true
				s.droppedRelicLv6PendingAfterUpgrade = nil
			end
			if s.droppedRelicLv6OfferConsumed ~= nil and s.droppedRelicOfferConsumed == nil then
				s.droppedRelicOfferConsumed = s.droppedRelicLv6OfferConsumed == true
				s.droppedRelicLv6OfferConsumed = nil
			end
			if s.droppedRelicOfferPending == nil then
				s.droppedRelicOfferPending = false
			end
			if s.droppedRelicOfferConsumed == nil then
				s.droppedRelicOfferConsumed = false
			end
		end
		local finalState = progressByPlayer[player]

		-- 보수적 초기화: activeWeapons는 생성만 하고, 기본 effective weapon 1개만 누락 시 보충
		WeaponProgression.ensureWeaponFields(finalState, eff, hasOverride)

		sanitizeBasicMagicRelicState(player, finalState)
		return finalState
	end

	players.PlayerAdded:Connect(function(player)
		ensureProgress(player)
	end)

	players.PlayerRemoving:Connect(function(player)
		progressByPlayer[player] = nil
		pendingLevelUpOfferByPlayer[player] = nil
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

	state.xp += amount

	while true do
		local need = xpRequiredForLevel(state.level)
		if state.xp < need then
			break
		end

		state.xp -= need
		state.level += 1
		print(
	"[Progression][LEVELUP]",
	player.Name,
	"level", state.level,
	"xp", state.xp,
	"pendingLevel", pendingLevelUpOfferByPlayer[player] ~= nil,
	"pendingStart", pendingStartingRelicByPlayer[player] ~= nil,
	"pendingDrop", pendingDroppedRelicByPlayer[player] ~= nil,
	"queue", #(state.upgradeOfferQueue or {})
)

		if levelUpChoiceEvent and upgradeDataModule then
			if pendingStartingRelicByPlayer[player] then
				table.insert(state.upgradeOfferQueue, state.level)
				print(
	"[Progression][QUEUE_UPGRADE]",
	player.Name,
	"level", state.level,
	"queue", #(state.upgradeOfferQueue or {}),
	"pendingLevel", pendingLevelUpOfferByPlayer[player] ~= nil,
	"pendingStart", pendingStartingRelicByPlayer[player] ~= nil,
	"pendingDrop", pendingDroppedRelicByPlayer[player] ~= nil
)
			elseif pendingDroppedRelicByPlayer[player] then
				print(
	"[Progression][QUEUE_UPGRADE]",
	player.Name,
	"level", state.level,
	"queue", #(state.upgradeOfferQueue or {}),
	"pendingLevel", pendingLevelUpOfferByPlayer[player] ~= nil,
	"pendingStart", pendingStartingRelicByPlayer[player] ~= nil,
	"pendingDrop", pendingDroppedRelicByPlayer[player] ~= nil
)
				table.insert(state.upgradeOfferQueue, state.level)
			elseif pendingLevelUpOfferByPlayer[player] then
				print(
	"[Progression][QUEUE_UPGRADE]",
	player.Name,
	"level", state.level,
	"queue", #(state.upgradeOfferQueue or {}),
	"pendingLevel", pendingLevelUpOfferByPlayer[player] ~= nil,
	"pendingStart", pendingStartingRelicByPlayer[player] ~= nil,
	"pendingDrop", pendingDroppedRelicByPlayer[player] ~= nil
)
				table.insert(state.upgradeOfferQueue, state.level)
			else
				
				local picked, pendingMap = buildOfferForPlayer(player)
				pendingLevelUpOfferByPlayer[player] = pendingMap
				print(
	"[Progression][FIRE_UPGRADE_IMMEDIATE]",
	player.Name,
	"level", state.level,
	"choices", #picked
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

function ProgressionService.getDroppedRelicId(player): string?
	local state = progressByPlayer[player]
	if not state then
		return nil
	end
	return state.droppedRelicId
end

function ProgressionService.tryGrantDroppedRelicOfferFromChest(player): boolean
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return false
	end
	local state = progressByPlayer[player]
	if not state or state.weaponId ~= "SwordShield" then
		return false
	end
	if state.droppedRelicId ~= nil or state.droppedRelicOfferConsumed == true then
		return false
	end
	state.droppedRelicOfferPending = true
	tryFlushDroppedRelicOffer(player)
	return true
end

function ProgressionService.tryOfferStartingRelic(player)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return
	end
	local pre = progressByPlayer[player]
	if not pre or pre.weaponId ~= "SwordShield" then
		return
	end
	task.delay(1.25, function()
		if typeof(player) ~= "Instance" or not player:IsA("Player") or not player.Parent then
			return
		end
		local state = progressByPlayer[player]
		if not state or state.weaponId ~= "SwordShield" then
			return
		end
		if state.startingRelicId ~= nil then
			return
		end
		if pendingStartingRelicByPlayer[player] then
			return
		end
		if pendingLevelUpOfferByPlayer[player] then
			return
		end
		if pendingDroppedRelicByPlayer[player] then
			return
		end
		if not relicDataModule or not levelUpChoiceEvent then
			return
		end
		local choices = relicDataModule.getStartingRelicChoices()
		local allowed = {}
		for _, c in ipairs(choices) do
			allowed[c.Id] = true
		end
		pendingStartingRelicByPlayer[player] = allowed
		levelUpChoiceEvent:FireClient(player, {
			ChoiceKind = "StartingRelic",
			Title = "Starting Relic",
			Choices = choices,
		})
	end)
end

return ProgressionService
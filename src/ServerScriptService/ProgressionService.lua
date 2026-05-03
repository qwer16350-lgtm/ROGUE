local ProgressionService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local RunWeaponResolver = require(Shared:WaitForChild("RunWeaponResolver"))
local UpgradeOfferBuilder = require(script.Parent:WaitForChild("Progression"):WaitForChild("UpgradeOfferBuilder"))

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

local DROPPED_RELIC_OFFER_LEVEL = 6

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
	if not state then
		return nil
	end
	return state.weaponId
end

function ProgressionService.getWeaponGrade(player): string?
	local state = progressByPlayer[player]
	if not state then
		return "Normal"
	end
	local g = state.weaponGrade
	if type(g) == "string" and g ~= "" then
		return g
	end
	return "Normal"
end

function ProgressionService.tryApplyWeaponDropPickup(player, weaponIdFromDrop: string): boolean
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return false
	end
	if type(weaponIdFromDrop) ~= "string" then
		warn("[ProgressionService] tryApplyWeaponDropPickup: invalid weaponIdFromDrop")
		return false
	end
	local state = progressByPlayer[player]
	if not state then
		warn(string.format("[ProgressionService] tryApplyWeaponDropPickup: no progress state (%s)", player.Name))
		return false
	end
	if state.weaponId ~= weaponIdFromDrop then
		warn(
			string.format(
				"[ProgressionService] weapon drop pickup id mismatch: playerWeapon=%s drop=%s (%s)",
				tostring(state.weaponId),
				weaponIdFromDrop,
				player.Name
			)
		)
		return false
	end
	if state.weaponId ~= "SwordShield" then
		warn(string.format("[ProgressionService] weapon drop pickup rejected — not SwordShield (%s)", player.Name))
		return false
	end

	if state.weaponGrade == "Rare" then
		fireWeaponPickupNotify(player, "AlreadyRareDuplicate")
		return true
	end

	if state.weaponGrade == "Normal" then
		state.weaponGrade = "Rare"
		fireWeaponPickupNotify(player, "UpgradedToRare")
		if progressionVerbose() then
			print(string.format("[Progression] %s | SwordShield duplicate 획득 → Rare 승급", player.Name))
		end
		return true
	end

	warn(string.format("[ProgressionService] weapon drop pickup: unknown weaponGrade=%s (%s)", tostring(state.weaponGrade), player.Name))
	return false
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
	return UpgradeOfferBuilder.buildUpgradeOffer(poolWeaponId, relicId, upgradeData, relicDataModule)
end

local function flushUpgradeOfferQueue(player: Player)
	if not levelUpChoiceEvent or not upgradeDataModule then
		return
	end
	if pendingLevelUpOfferByPlayer[player] then
		return
	end
	if pendingStartingRelicByPlayer[player] then
		return
	end
	if pendingDroppedRelicByPlayer[player] then
		return
	end
	local state = progressByPlayer[player]
	if not state or not state.upgradeOfferQueue or #state.upgradeOfferQueue == 0 then
		return
	end
	local lvl = table.remove(state.upgradeOfferQueue, 1)
	local picked, pendingMap = buildOfferForPlayer(player)
	pendingLevelUpOfferByPlayer[player] = pendingMap
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
	if state.droppedRelicLv6OfferConsumed or state.droppedRelicId ~= nil then
		return
	end
	if not state.droppedRelicLv6PendingAfterUpgrade then
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
	state.droppedRelicLv6PendingAfterUpgrade = false
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
	s.droppedRelicLv6PendingAfterUpgrade = false
	s.droppedRelicLv6OfferConsumed = true
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
			st.droppedRelicLv6OfferConsumed = true
			pendingDroppedRelicByPlayer[player] = nil
			flushUpgradeOfferQueue(player)
			tryFlushDroppedRelicOffer(player)
			return
		end

		if not allowedChoiceIds[choiceId] then
			warn(string.format("[Progression] unknown choiceId=%s (%s)", choiceId, player.Name))
			return
		end

		local pending = pendingLevelUpOfferByPlayer[player]
		if not pending or not pending[choiceId] then
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
		if not state or not state.upgrades then
			warn(string.format("[Progression] Upgrade submit: no progress state (%s)", player.Name))
			return
		end

		state.upgrades[choiceId] += 1
		pendingLevelUpOfferByPlayer[player] = nil

		local u = state.upgrades
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
				droppedRelicLv6PendingAfterUpgrade = false,
				droppedRelicLv6OfferConsumed = false,
				--- 로비 무기 선택/TeleportData 연동 시 이 필드는 런 진입 페이로드로 시드할 수 있음.
				weaponId = eff,
				weaponGrade = "Normal",
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
			if s.droppedRelicLv6PendingAfterUpgrade == nil then
				s.droppedRelicLv6PendingAfterUpgrade = false
			end
			if s.droppedRelicLv6OfferConsumed == nil then
				s.droppedRelicLv6OfferConsumed = false
			end
			if hasOverride then
				s.weaponId = eff
			elseif s.weaponId == nil or (s.weaponId ~= "SwordShield" and s.weaponId ~= "BasicMagic") then
				s.weaponId = eff
			end
			if s.weaponGrade == nil then
				s.weaponGrade = "Normal"
			end
		end
		local finalState = progressByPlayer[player]
		sanitizeBasicMagicRelicState(player, finalState)
		return finalState
	end

	players.PlayerAdded:Connect(function(player)
		ensureProgress(player)
	end)

	players.PlayerRemoving:Connect(function(player)
		progressByPlayer[player] = nil
		pendingLevelUpOfferByPlayer[player] = nil
		pendingStartingRelicByPlayer[player] = nil
		pendingDroppedRelicByPlayer[player] = nil
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

		if
			state.weaponId == "SwordShield"
			and state.level == DROPPED_RELIC_OFFER_LEVEL
			and not state.droppedRelicLv6OfferConsumed
			and state.droppedRelicId == nil
		then
			state.droppedRelicLv6PendingAfterUpgrade = true
		end

		if levelUpChoiceEvent and upgradeDataModule then
			if pendingStartingRelicByPlayer[player] then
				table.insert(state.upgradeOfferQueue, state.level)
			elseif pendingDroppedRelicByPlayer[player] then
				table.insert(state.upgradeOfferQueue, state.level)
			elseif pendingLevelUpOfferByPlayer[player] then
				table.insert(state.upgradeOfferQueue, state.level)
			else
				local picked, pendingMap = buildOfferForPlayer(player)
				pendingLevelUpOfferByPlayer[player] = pendingMap
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

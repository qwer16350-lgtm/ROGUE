local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UpgradeData = require(Shared:WaitForChild("UpgradeData"))
local WeaponProfiles = require(Shared:WaitForChild("WeaponProfiles"))

local BuildTagService = require(script.Parent:WaitForChild("BuildTagService"))

local HudSyncService = {}
local DEBUG_STAGE_HUD = true

local hudStateRemote = nil

local SS_KEYS = {
	"ss_common_damage",
	"ss_common_cooldown",
	"ss_sweep_angle",
	"ss_sweep_damage",
	"ss_sweep_range",
	"ss_thrust_damage",
	"ss_thrust_range",
}

local function buildDevCombat(player, progressionService, gameConfig)
	local dbg = gameConfig.Debug
	if type(dbg) ~= "table" or dbg.ShowDevCombatPanel ~= true then
		return nil
	end

	local weaponId = progressionService.getWeaponId(player)
	local upgrades = progressionService.getUpgradeCounts(player)
	if type(upgrades) ~= "table" then
		upgrades = {}
	end
	local phase3ActiveRelicIds = progressionService.getPhase3ActiveRelicIds(player)
	local weaponGrade = progressionService.getWeaponGrade(player)
	local activeWeaponsMap = progressionService.getActiveWeapons(player)
	local activeWeaponsList = {}
	if type(activeWeaponsMap) == "table" then
		for wid, info in pairs(activeWeaponsMap) do
			local grade = "Normal"
			if type(info) == "table" and type(info.grade) == "string" and info.grade ~= "" then
				grade = info.grade
			elseif type(progressionService.getWeaponGradeFor) == "function" then
				grade = progressionService.getWeaponGradeFor(player, wid)
			end
			table.insert(activeWeaponsList, {
				WeaponId = tostring(wid),
				Grade = grade,
			})
		end
		table.sort(activeWeaponsList, function(a, b)
			return a.WeaponId < b.WeaponId
		end)
	end

	local dc = {
		WeaponId = weaponId,
		WeaponGrade = weaponGrade,
		ActiveWeapons = activeWeaponsList,
		Phase3ActiveRelicIds = phase3ActiveRelicIds,
		Run = {
			DefaultWeaponId = gameConfig.Run and gameConfig.Run.DefaultWeaponId,
		},
		Debug = {
			OverrideWeaponId = dbg.OverrideWeaponId,
			ShowAttackRanges = dbg.ShowAttackRanges,
			ShowDevCombatPanel = dbg.ShowDevCombatPanel,
		},
		WeaponDropChance = gameConfig.WeaponDropChance,
		WeaponDropChanceOverride = dbg.WeaponDropChanceOverride,
	}

	for _, k in ipairs(SS_KEYS) do
		local v = upgrades[k]
		dc[k] = type(v) == "number" and math.max(0, math.floor(v + 0.5)) or 0
	end

	local function hasActiveWeapon(targetWeaponId: string): boolean
		if type(targetWeaponId) ~= "string" or targetWeaponId == "" then
			return false
		end
		if type(activeWeaponsMap) == "table" and activeWeaponsMap[targetWeaponId] ~= nil then
			return true
		end
		return weaponId == targetWeaponId
	end

	if weaponId == "SwordShield" then
		dc.SwordShieldEffective = UpgradeData.getSwordShieldEffectiveCombat(
			gameConfig,
			WeaponProfiles.SwordShield,
			upgrades,
			weaponGrade,
			phase3ActiveRelicIds
		)
	elseif weaponId == "BasicMagic" then
		dc.BasicMagicEffective = UpgradeData.getEffectiveCombatStats(gameConfig, upgrades)
	end

	if hasActiveWeapon("Spear") then
		local sp = WeaponProfiles.Spear
		local spGrade = progressionService.getWeaponGradeFor(player, "Spear")
		local phase3RelicIds = progressionService.getPhase3ActiveRelicIds(player)
		local eff = UpgradeData.getSpearEffectiveCombat(gameConfig, sp, upgrades, spGrade, phase3RelicIds)
		local th = type(eff) == "table" and eff.Thrust or nil
		local meta = type(eff) == "table" and eff.Meta or nil
		dc.SpearEffective = {
			Grade = spGrade,
			BaseDamage = th and th.BaseDamage or nil,
			AttackIntervalSeconds = eff and eff.AttackIntervalSeconds or nil,
			RangeStuds = th and th.RangeStuds or nil,
			WidthStuds = th and th.WidthStuds or nil,
			TargetLimit = th and th.TargetLimit or nil,
			sp_thrust_damage = meta and meta.sp_thrust_damage or 0,
			sp_thrust_range = meta and meta.sp_thrust_range or 0,
		}
	end

	if hasActiveWeapon("TwoHandedSword") then
		local tw = WeaponProfiles.TwoHandedSword
		local twGrade = progressionService.getWeaponGradeFor(player, "TwoHandedSword")
		local phase3RelicIds = progressionService.getPhase3ActiveRelicIds(player)
		local eff = UpgradeData.getTwoHandedSwordEffectiveCombat(gameConfig, tw, upgrades, twGrade, phase3RelicIds)
		local sw = type(eff) == "table" and eff.Sweep or nil
		local meta = type(eff) == "table" and eff.Meta or nil
		dc.TwoHandedSwordEffective = {
			Grade = twGrade,
			BaseDamage = sw and sw.BaseDamage or nil,
			AttackIntervalSeconds = eff and eff.AttackIntervalSeconds or nil,
			RangeStuds = sw and sw.RangeStuds or nil,
			AngleDeg = sw and sw.AngleDeg or nil,
			TargetLimit = sw and sw.TargetLimit or nil,
			th_sweep_damage = meta and meta.th_sweep_damage or 0,
			th_sweep_range = meta and meta.th_sweep_range or 0,
		}
	end

	local buildSnapshot = BuildTagService.computeBuildSnapshot({
		activeWeapons = activeWeaponsMap,
		phase3RelicIds = progressionService.getPhase3ActiveRelicIds(player),
		primaryWeaponId = weaponId,
	})
	dc.BuildTag = {
		TagCounts = buildSnapshot.TagCounts,
		Phase3RelicIds = buildSnapshot.Phase3RelicIds,
	}
	dc.ClassDetection = {
		DetectedClass = buildSnapshot.DetectedClass,
		Scores = buildSnapshot.ClassScores,
		TieBreakNote = buildSnapshot.TieBreakNote,
		PrimaryWeaponId = buildSnapshot.PrimaryWeaponId,
	}

	return dc
end

local function buildPayload(player, progressionService, waveService, gameConfig)
	local waveInfo = waveService.getHudInfo()
	local prog = progressionService.getHudProgress(player)

	local sessionLen = waveInfo.sessionLengthSeconds
	if type(sessionLen) ~= "number" or sessionLen <= 0 then
		sessionLen = gameConfig.SessionDurationSeconds
	end

	local payload = {
		Level = prog.level,
		Xp = prog.xp,
		XpToNext = prog.xpToNext,
		SecondsLeft = waveInfo.remaining,
		SecondsLeftFloat = waveInfo.remainingFloat,
		SessionActive = waveInfo.active,
		SessionLengthSeconds = sessionLen,
		StageIndex = waveInfo.stageIndex or 1,
	}

	local devCombat = buildDevCombat(player, progressionService, gameConfig)
	if devCombat ~= nil then
		payload.DevCombat = devCombat
	end

	return payload
end

function HudSyncService.pushToPlayer(player, progressionService, waveService, gameConfig)
	if not hudStateRemote then
		return
	end
	if not player or not player.Parent then
		return
	end

	local payload = buildPayload(player, progressionService, waveService, gameConfig)
	if DEBUG_STAGE_HUD then
		print(string.format("[HudSyncService] pushToPlayer %s StageIndex=%d SessionActive=%s", player.Name, payload.StageIndex or -1, tostring(payload.SessionActive)))
	end
	hudStateRemote:FireClient(player, payload)
end

function HudSyncService.init(players, runService, progressionService, waveService, gameConfig)
	local syncInterval = gameConfig.HudSyncIntervalSeconds

	hudStateRemote = ReplicatedStorage:FindFirstChild("HudState")
	if not hudStateRemote then
		hudStateRemote = Instance.new("RemoteEvent")
		hudStateRemote.Name = "HudState"
		hudStateRemote.Parent = ReplicatedStorage
	end

	local accumulator = 0

	runService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < syncInterval then
			return
		end
		accumulator = 0

		for _, player in ipairs(players:GetPlayers()) do
			local payload = buildPayload(player, progressionService, waveService, gameConfig)
			if DEBUG_STAGE_HUD then
				print(string.format("[HudSyncService] heartbeat push %s StageIndex=%d SessionActive=%s", player.Name, payload.StageIndex or -1, tostring(payload.SessionActive)))
			end
			hudStateRemote:FireClient(player, payload)
		end
	end)
end

return HudSyncService
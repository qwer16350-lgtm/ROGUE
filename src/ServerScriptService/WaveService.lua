local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StageData = require(Shared:WaitForChild("StageData"))
local SpawnRules = require(Shared:WaitForChild("SpawnRules"))
local RunConstants = require(Shared:WaitForChild("Run"):WaitForChild("RunConstants"))
local EnemyTier = require(Shared:WaitForChild("Config"):WaitForChild("EnemyTier"))
local RunResultRewardPolicy = require(Shared:WaitForChild("RunResultRewardPolicy"))
local PlayerContactDamageService = require(script.Parent:WaitForChild("PlayerContactDamageService"))
local RelicProfilePersistence = require(script.Parent:WaitForChild("RelicProfilePersistence"))

local WaveService = {}

local hudRemainingSec = 0
local hudRemainingFloat = 0
local hudSessionActive = false
local hudSessionLengthSeconds = 0

local recordKillImpl = nil

local ctx = {
	blueprintDiscoveryService = nil,
	players = nil,
	gameConfig = nil,
	enemyService = nil,
	progressionService = nil,
	xpPickupService = nil,
	hudSyncService = nil,
	stageFlow = nil,
}

local sess = {
	startTime = 0,
	lengthSec = 0,
	active = false,
	bossSpawned = false,
	bossPart = nil,
	killCount = 0,
	normalKills = 0,
	eliteKills = 0,
	bossKills = 0,
	bossSpawnAt = nil,
	finalDamageTakenByUserId = {},
	lastSpawnTime = 0,
	lastEliteSpawnTime = 0,
	spawnProfile = nil,
	--- Resolved once per session via SpawnRules; immutable until next startSession.
	gruntTuning = nil,
	floor = nil,
	maxFloor = nil,
}

function WaveService.recordKill(entry: any?)
	if recordKillImpl then
		recordKillImpl(entry)
	end
end

function WaveService.recordFinalDamage(player: Player, amount: number)
	if not sess.active then
		return
	end
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return
	end
	if type(amount) ~= "number" or amount <= 0 then
		return
	end
	local uid = player.UserId
	sess.finalDamageTakenByUserId[uid] = (sess.finalDamageTakenByUserId[uid] or 0) + amount
end

function WaveService.getHudInfo()
	return {
		remaining = hudRemainingSec,
		remainingFloat = hudRemainingFloat,
		active = hudSessionActive,
		sessionLengthSeconds = hudSessionLengthSeconds,
		stageIndex = sess.floor or 0,
	}
end

function WaveService.bindHudPushContext(deps)
	ctx.hudSyncService = deps.hudSyncService
	ctx.xpPickupService = deps.xpPickupService
	ctx.players = deps.players
	ctx.progressionService = deps.progressionService
	ctx.gameConfig = deps.gameConfig
	ctx.blueprintDiscoveryService = deps.blueprintDiscoveryService
end

function WaveService.bindStageFlow(stageFlow)
	ctx.stageFlow = stageFlow
end

function WaveService.init(players, runService, gameConfig, enemyService, progressionService, xpPickupService)
	ctx.players = players
	ctx.gameConfig = gameConfig
	ctx.enemyService = enemyService
	ctx.progressionService = progressionService
	ctx.xpPickupService = xpPickupService

	local resultEvent = ReplicatedStorage:FindFirstChild("SessionResult")
	if not resultEvent then
		resultEvent = Instance.new("RemoteEvent")
		resultEvent.Name = "SessionResult"
		resultEvent.Parent = ReplicatedStorage
	end

	local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
	local bossHealthEvent = remotesFolder:WaitForChild("BossHealthEvent") :: RemoteEvent

	local function fireBossBarHide()
		bossHealthEvent:FireAllClients({ Phase = "Hide" })
	end

	local function buildUpgradesPayload(upgradeCounts)
		local list = {}
		for id, count in pairs(upgradeCounts) do
			if type(count) == "number" and count > 0 then
				table.insert(list, { Id = id, Count = count })
			end
		end
		table.sort(list, function(a, b)
			return a.Id < b.Id
		end)
		return list
	end

	local function pushHudAllPlayers()
		local h = ctx.hudSyncService
		local plrs = ctx.players
		local prog = ctx.progressionService
		local gc = ctx.gameConfig
		if not h or not plrs or not prog or not gc then
			return
		end
		for _, p in ipairs(plrs:GetPlayers()) do
			h.pushToPlayer(p, prog, WaveService, gc)
		end
	end

	local function applyStageSpawnOrigin()
		local enemy = ctx.enemyService
		local gc = ctx.gameConfig
		if not enemy or not gc then
			return
		end
		enemy.setSpawnWorldOffset(StageData.getEnemySpawnOrigin(gc, sess.floor or 1))
	end

	local function startSessionInternal(floorIndex)
		sess.floor = (type(floorIndex) == "number" and floorIndex) or 1
		sess.maxFloor = RunConstants.MaxFloor
		sess.spawnProfile = StageData.getSpawnProfile(gameConfig, sess.floor)
		sess.gruntTuning = SpawnRules.resolveGruntTuning(gameConfig, sess.spawnProfile)
		local len = StageData.getSessionDurationSeconds(gameConfig, sess.floor)
		sess.lengthSec = len
		hudSessionLengthSeconds = len
		hudRemainingSec = len
		hudRemainingFloat = len
		hudSessionActive = true
		sess.active = true
		sess.bossSpawned = false
		sess.bossPart = nil
		sess.killCount = 0
		sess.normalKills = 0
		sess.eliteKills = 0
		sess.bossKills = 0
		sess.bossSpawnAt = nil
		sess.finalDamageTakenByUserId = {}
		sess.startTime = tick()
		sess.lastSpawnTime = tick()
		sess.lastEliteSpawnTime = tick()
		applyStageSpawnOrigin()
		enemyService.clearAllEnemies()
		local startSpawns = gameConfig.EnemyGruntSpawnsPerTick or 1
		if type(startSpawns) ~= "number" or startSpawns < 1 then
			startSpawns = 1
		end
		for _ = 1, startSpawns do
			enemyService.spawnGrunt(gameConfig)
		end
		pushHudAllPlayers()
	end

	WaveService.startSession = startSessionInternal

	local function finishSession(bossKilled)
		if not sess.active then
			return
		end
		fireBossBarHide()
		sess.active = false

		local elapsed = tick() - sess.startTime
		local survivalSeconds = math.floor(elapsed + 0.5)

		local floorIdx = sess.floor or 0
		local maxFloor = sess.maxFloor or RunConstants.MaxFloor
		local isLastFloor = floorIdx >= maxFloor
		local cleared = bossKilled == true
		local canAdvance = cleared and not isLastFloor
		local outcome = cleared and RunConstants.Outcome.Clear or RunConstants.Outcome.Fail

		for _, p in ipairs(players:GetPlayers()) do
			local prog = progressionService.getHudProgress(p)
			local ups = progressionService.getUpgradeCounts(p)

			local finalDamageTaken = sess.finalDamageTakenByUserId[p.UserId] or 0
			local baseMax = gameConfig.PlayerBaseHealth
			if type(baseMax) ~= "number" or baseMax <= 0 then
				baseMax = 100
			end
			local cleanDamageBudget = progressionService.getEffectiveMaxHealthFor(p, baseMax)

			local bossKillElapsedSeconds = nil
			if cleared and type(sess.bossSpawnAt) == "number" then
				bossKillElapsedSeconds = tick() - sess.bossSpawnAt
			end

			local grant = RunResultRewardPolicy.compute({
				outcome = outcome,
				floor = floorIdx,
				isLastFloor = isLastFloor,
				cleared = cleared,
				killCount = sess.killCount,
				survivalSeconds = survivalSeconds,
				normalKills = sess.normalKills,
				eliteKills = sess.eliteKills,
				bossKills = sess.bossKills,
				bossKillElapsedSeconds = bossKillElapsedSeconds,
				finalDamageTaken = finalDamageTaken,
				cleanDamageBudget = cleanDamageBudget,
			}, gameConfig)
			local materialsGranted = grant.materialsGranted
			local currenciesGranted = grant.currenciesGranted
			local matApplied, matErr = RelicProfilePersistence.grantMaterials(p.UserId, materialsGranted)
			local curApplied, curErr = RelicProfilePersistence.grantCurrencies(p.UserId, currenciesGranted)
			local applied = matApplied and curApplied
			local grantErr = matErr or curErr
						local blueprintProgressGranted = {}
			local bpApplied = true
			local bpGrantErr = nil
			local blueprintSvc = ctx.blueprintDiscoveryService
			if blueprintSvc and type(blueprintSvc.takeAndClearPending) == "function" then
				blueprintProgressGranted = blueprintSvc.takeAndClearPending(p.UserId)
				if next(blueprintProgressGranted) then
					bpApplied, bpGrantErr = RelicProfilePersistence.grantBlueprintProgress(
						p.UserId,
						blueprintProgressGranted
					)
					if not bpApplied then
						warn(string.format(
							"[WaveService] blueprint result grant failed uid=%d err=%s",
							p.UserId,
							tostring(bpGrantErr)
						))
					end
				end
			end
			local rewardSummary = {
				applied = applied,
				materialsGranted = materialsGranted,
				currenciesGranted = currenciesGranted,
				rewardBudget = grant.rewardBudget,
				blueprintProgressGranted = blueprintProgressGranted,
				blueprintGrantApplied = bpApplied,
			}
			if not bpApplied then
				rewardSummary.blueprintGrantError = bpGrantErr
			end
			if not applied then
				rewardSummary.grantError = grantErr
				warn(string.format(
					"[WaveService] result grant failed uid=%d err=%s",
					p.UserId,
					tostring(grantErr)
				))
			end

			resultEvent:FireClient(p, {
				SurvivalSeconds = survivalSeconds,
				KillCount       = sess.killCount,
				FinalLevel      = prog.level,
				Upgrades        = buildUpgradesPayload(ups),
				BossKilled      = cleared,
				CanAdvance      = canAdvance,
				Floor           = floorIdx,
				MaxFloor        = maxFloor,
				IsLastFloor     = isLastFloor,
				Outcome         = outcome,
				RewardSummary   = rewardSummary,
			})
		end

		sess.bossPart = nil
		enemyService.clearAllEnemies()

		if ctx.stageFlow and ctx.stageFlow.onSessionFinished then
			ctx.stageFlow.onSessionFinished(outcome)
		end
	end

	local function allPlayersDead()
		local list = players:GetPlayers()
		if #list == 0 then
			return false
		end

		for _, p in ipairs(list) do
			local char = p.Character
			if not char then
				return false
			end
			local h = char:FindFirstChildOfClass("Humanoid")
			if not h then
				return false
			end
			if h.Health > 0 then
				return false
			end
		end

		return true
	end

	recordKillImpl = function(entry)
		sess.killCount += 1
		local tier = entry and entry.state and entry.state.tier
		if tier == EnemyTier.Elite then
			sess.eliteKills += 1
		elseif EnemyTier.isBossFamily(tier) or (entry and entry.state and entry.state.isBoss) then
			sess.bossKills += 1
		else
			sess.normalKills += 1
		end
	end

	runService.Heartbeat:Connect(function()
		local now = tick()
		local elapsed = now - sess.startTime

		if sess.active then
			hudRemainingFloat = math.max(0, sess.lengthSec - elapsed)
			hudRemainingSec = math.floor(hudRemainingFloat + 0.5)
			hudSessionActive = true
		else
			hudRemainingFloat = 0
			hudRemainingSec = 0
			hudSessionActive = false
		end

		if not sess.active then
			return
		end

		if sess.bossSpawned and sess.bossPart and not sess.bossPart.Parent then
			finishSession(true)
			return
		end

		if allPlayersDead() then
			finishSession(false)
			return
		end

		if elapsed >= sess.lengthSec and not sess.bossSpawned then
			sess.bossPart = enemyService.spawnBoss(gameConfig)
			sess.bossSpawned = true
			sess.bossSpawnAt = tick()
			if not sess.bossPart then
				finishSession(false)
			else
				local bp = sess.bossPart
				local mh = tonumber(bp:GetAttribute("MaxHealth"))
				local ch = tonumber(bp:GetAttribute("Health"))
				local maxInt = mh ~= nil and math.max(1, math.floor(mh :: number + 0.5)) or 1
				local curInt = ch ~= nil and math.max(0, math.floor(ch :: number + 0.5)) or maxInt
				bossHealthEvent:FireAllClients({
					Phase = "Show",
					Current = curInt,
					Max = maxInt,
				})
			end
			return
		end

		if sess.bossSpawned then
			return
		end

		local effectiveInterval = SpawnRules.computeGruntIntervalSeconds(
			elapsed,
			sess.lengthSec,
			sess.gruntTuning
		)
		local prof = sess.spawnProfile
		local spawnsPerTick = gameConfig.EnemyGruntSpawnsPerTick or 1
		if type(spawnsPerTick) ~= "number" or spawnsPerTick < 1 then
			spawnsPerTick = 1
		end

		if now - sess.lastSpawnTime >= effectiveInterval then
			sess.lastSpawnTime = now
			for _ = 1, spawnsPerTick do
				enemyService.spawnGrunt(gameConfig)
			end
		end

		if prof and prof.EliteGruntEnabled then
			local eliteMul = prof.EliteGruntSpawnIntervalMul
			if type(eliteMul) ~= "number" or eliteMul <= 0 then
				eliteMul = 10
			end
			if now - sess.lastEliteSpawnTime >= effectiveInterval * eliteMul then
				sess.lastEliteSpawnTime = now
				for _ = 1, spawnsPerTick do
					enemyService.spawnGrunt(gameConfig, true, prof.EliteGruntHealthMultiplier)
				end
			end
		end
	end)

	PlayerContactDamageService.bindFinalDamageRecorder(function(player, amount)
		WaveService.recordFinalDamage(player, amount)
	end)
end

return WaveService
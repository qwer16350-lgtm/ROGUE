local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EnemyTier = require(Shared:WaitForChild("Config"):WaitForChild("EnemyTier"))

local PlayerContactDamageService = {}

local HEALTH_UPGRADE_STACK_ATTR = "ab_Health_increase_stack"
local HEALTH_UPGRADE_BONUS_PER_STACK = 20
local SPEED_UPGRADE_STACK_ATTR = "ab_Speed_increase_stack"
local SPEED_UPGRADE_MUL_PER_STACK = 0.03
local DAMAGE_TAKEN_MULTIPLIER_ATTR = "damageTakenMultiplier"
local BLOCK_CAPABLE_ATTR = "blockCapable"
local EFFECTIVE_BLOCK_CHANCE_ATTR = "effectiveBlockChance"
local BLOCK_COOLDOWN_UNTIL_ATTR = "blockCooldownUntil"
local LAST_BLOCK_SUCCESS_AT_ATTR = "lastBlockSuccessAt"

local finalDamageRecorder: ((Player, number) -> ())? = nil

local function resolveDamageTakenMultiplier(player: Player): number
	local raw = player:GetAttribute(DAMAGE_TAKEN_MULTIPLIER_ATTR)
	if type(raw) == "number" and raw >= 0 then
		return raw
	end
	return 1
end

local function recordFinalDamageApplied(player: Player, appliedDamage: number)
	if finalDamageRecorder and appliedDamage > 0 then
		finalDamageRecorder(player, appliedDamage)
	end
end

local function clearBlockCooldownAttributes(player: Player)
	player:SetAttribute(BLOCK_COOLDOWN_UNTIL_ATTR, nil)
	player:SetAttribute(LAST_BLOCK_SUCCESS_AT_ATTR, nil)
end

local function resolveBlockCooldownSeconds(gameConfig): number
	local blockDef = type(gameConfig) == "table" and gameConfig.BlockDefense or nil
	if type(blockDef) == "table" and type(blockDef.BlockCooldownSeconds) == "number" and blockDef.BlockCooldownSeconds >= 0 then
		return blockDef.BlockCooldownSeconds
	end
	return 3
end

local function logBlockDefense(gameConfig, player: Player, rawDamage: number, chance: number, blocked: boolean, finalDamage: number)
	local dbg = type(gameConfig) == "table" and gameConfig.Debug or nil
	if type(dbg) ~= "table" or dbg.LogBlockDefense ~= true then
		return
	end
	print(
		string.format(
			"[BlockDefense] uid=%d raw=%.2f chance=%.3f roll=%s final=%.2f",
			player.UserId,
			rawDamage,
			chance,
			if blocked then "ok" else "fail",
			finalDamage
		)
	)
end

local function resolveContactFinalDamage(
	player: Player,
	rawDamage: number,
	takenMult: number,
	now: number,
	gameConfig
): (number, boolean)
	local blockCapable = player:GetAttribute(BLOCK_CAPABLE_ATTR) == true
	local blockChance = player:GetAttribute(EFFECTIVE_BLOCK_CHANCE_ATTR)
	if not blockCapable or type(blockChance) ~= "number" or blockChance <= 0 then
		return rawDamage * takenMult, false
	end

	local cdUntil = player:GetAttribute(BLOCK_COOLDOWN_UNTIL_ATTR)
	if type(cdUntil) == "number" and now < cdUntil then
		return rawDamage * takenMult, false
	end

	if math.random() < blockChance then
		local cdSec = resolveBlockCooldownSeconds(gameConfig)
		player:SetAttribute(BLOCK_COOLDOWN_UNTIL_ATTR, now + cdSec)
		player:SetAttribute(LAST_BLOCK_SUCCESS_AT_ATTR, now)
		return 0, true
	end

	return rawDamage * takenMult, false
end

function PlayerContactDamageService.bindFinalDamageRecorder(fn: (Player, number) -> ())
	finalDamageRecorder = fn
end

local function resolveEffectiveMaxHealth(player: Player, gameConfig): number
	local base = gameConfig.PlayerBaseHealth
	if type(base) ~= "number" or base <= 0 then
		base = 100
	end
	local raw = player:GetAttribute(HEALTH_UPGRADE_STACK_ATTR)
	local stack = 0
	if type(raw) == "number" and raw > 0 then
		stack = math.max(0, math.floor(raw + 0.5))
	end
	return math.max(1, base + HEALTH_UPGRADE_BONUS_PER_STACK * stack)
end

local function applyCharacterHealth(player: Player, humanoid, gameConfig)
	local effectiveMaxHealth = resolveEffectiveMaxHealth(player, gameConfig)
	humanoid.MaxHealth = effectiveMaxHealth
	humanoid.Health = effectiveMaxHealth
end

local function resolveEffectiveWalkSpeed(player: Player, gameConfig): number
	local base = gameConfig.PlayerBaseWalkSpeed
	if type(base) ~= "number" or base <= 0 then
		base = 16
	end
	local raw = player:GetAttribute(SPEED_UPGRADE_STACK_ATTR)
	local stack = 0
	if type(raw) == "number" and raw > 0 then
		stack = math.max(0, math.floor(raw + 0.5))
	end
	return math.max(0, base * (1 + SPEED_UPGRADE_MUL_PER_STACK * stack))
end

local function applyCharacterWalkSpeed(player: Player, humanoid, gameConfig)
	local effectiveWalkSpeed = resolveEffectiveWalkSpeed(player, gameConfig)
	humanoid.WalkSpeed = effectiveWalkSpeed
end

local vfxEventCache = nil
local damageNumberEventCache = nil

local function getVfxEvent()
	if vfxEventCache then
		return vfxEventCache
	end
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if remotes then
		vfxEventCache = remotes:FindFirstChild("VFXEvent")
	end
	return vfxEventCache
end

local function getDamageNumberEvent()
	if damageNumberEventCache then
		return damageNumberEventCache
	end
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if remotes then
		damageNumberEventCache = remotes:FindFirstChild("DamageNumberEvent")
	end
	return damageNumberEventCache
end

--- Same offset as CombatService.damageFloatingWorldPosition (top of part + 1.5 studs).
local function characterFloatingWorldPosition(character: Model): Vector3?
	local part: BasePart? = nil
	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		part = head
	else
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if hrp and hrp:IsA("BasePart") then
			part = hrp
		end
	end
	if not part then
		return nil
	end
	return (part.CFrame * CFrame.new(0, part.Size.Y * 0.5 + 1.5, 0)).Position
end

local function pushBlockFloatingLabel(character: Model)
	local ev = getDamageNumberEvent()
	if not ev then
		return
	end
	local pos = characterFloatingWorldPosition(character)
	if not pos then
		return
	end
	ev:FireAllClients({
		Text = "Block!",
		WorldPosition = pos,
	})
end

function PlayerContactDamageService.init(players, runService, gameConfig, enemyService)
	local lastDamageAt = {}

	local function onCharacterAdded(player: Player, character)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if not humanoid then
			return
		end
		applyCharacterHealth(player, humanoid, gameConfig)
		applyCharacterWalkSpeed(player, humanoid, gameConfig)
		clearBlockCooldownAttributes(player)
	end

	for _, player in ipairs(players:GetPlayers()) do
		if player.Character then
			task.spawn(onCharacterAdded, player, player.Character)
		end
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
	end

	players.PlayerAdded:Connect(function(player)
		if player.Character then
			task.spawn(onCharacterAdded, player, player.Character)
		end
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
	end)

	players.PlayerRemoving:Connect(function(player)
		lastDamageAt[player] = nil
	end)

	local function getRadiusMulFor(tier)
		local tbl = gameConfig.EnemyContactRadiusMultiplierByTier
		if type(tbl) ~= "table" then
			return 1
		end
		local v = tbl[tier]
		if type(v) ~= "number" or v <= 0 then
			return 1
		end
		return v
	end

	runService.Heartbeat:Connect(function()
		local now = tick()
		local entries = enemyService.getEnemyEntries()
		if not entries then
			return
		end

		local cooldown = gameConfig.EnemyContactDamageCooldownSeconds
		local baseDamage = gameConfig.EnemyContactDamagePerTick
		local reachExtra = gameConfig.EnemyContactReachStuds
		local bossMult = gameConfig.EnemyContactDamageBossMultiplier or 1

		for _, player in ipairs(players:GetPlayers()) do
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if not hrp or not hum or hum.Health <= 0 then
				continue
			end

			local last = lastDamageAt[player] or 0
			if now - last < cooldown then
				continue
			end

			local touchingAny = false
			local touchingBoss = false

			for _, entry in ipairs(entries) do
				local part = entry.part
				if part and part.Parent then
					local halfExtent = math.max(part.Size.X, part.Size.Y, part.Size.Z) * 0.5
					local base = halfExtent + reachExtra
					local tier = (entry.state and entry.state.tier) or EnemyTier.Basic
					local threshold = base * getRadiusMulFor(tier)
					if (part.Position - hrp.Position).Magnitude <= threshold then
						touchingAny = true
						if EnemyTier.isBossFamily(tier) or (entry.state and entry.state.isBoss) then
							touchingBoss = true
						end
					end
				end
			end

			if touchingAny then
				local mult = touchingBoss and bossMult or 1
				local rawDamage = baseDamage * mult
				local takenMult = resolveDamageTakenMultiplier(player)
				local finalDamage, blocked = resolveContactFinalDamage(player, rawDamage, takenMult, now, gameConfig)
				local blockChance = player:GetAttribute(EFFECTIVE_BLOCK_CHANCE_ATTR)
				if type(blockChance) ~= "number" then
					blockChance = 0
				end
				logBlockDefense(gameConfig, player, rawDamage, blockChance, blocked, finalDamage)
				local healthBefore = hum.Health
				hum:TakeDamage(finalDamage)
				local applied = math.max(0, healthBefore - hum.Health)
				recordFinalDamageApplied(player, applied)
				lastDamageAt[player] = now

				if blocked and char then
					pushBlockFloatingLabel(char)
				end

				local vfxEvent = getVfxEvent()
				if vfxEvent then
					vfxEvent:FireAllClients({
						EffectType = "player_hit",
						PlayerUserId = player.UserId,
					})
				end
			end
		end
	end)
end

return PlayerContactDamageService

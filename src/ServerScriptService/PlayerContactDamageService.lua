local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EnemyTier = require(Shared:WaitForChild("Config"):WaitForChild("EnemyTier"))

local PlayerContactDamageService = {}

local HEALTH_UPGRADE_STACK_ATTR = "ab_Health_increase_stack"
local HEALTH_UPGRADE_BONUS_PER_STACK = 20
local SPEED_UPGRADE_STACK_ATTR = "ab_Speed_increase_stack"
local SPEED_UPGRADE_MUL_PER_STACK = 0.03

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

function PlayerContactDamageService.init(players, runService, gameConfig, enemyService)
	local lastDamageAt = {}

	local function onCharacterAdded(player: Player, character)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if not humanoid then
			return
		end
		applyCharacterHealth(player, humanoid, gameConfig)
		applyCharacterWalkSpeed(player, humanoid, gameConfig)
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
				hum:TakeDamage(baseDamage * mult)
				lastDamageAt[player] = now

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
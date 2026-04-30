local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EnemyTier = require(Shared:WaitForChild("Config"):WaitForChild("EnemyTier"))

local PlayerContactDamageService = {}

local function applyCharacterHealth(humanoid, gameConfig)
	humanoid.MaxHealth = gameConfig.PlayerBaseHealth
	humanoid.Health = gameConfig.PlayerBaseHealth
end

-- Lazy 캐시: Remotes/VFXEvent 가 다른 서비스 부팅보다 늦게 만들어질 수 있으므로
-- 첫 데미지 틱에서 1회 조회 후 보관한다. 없으면 점멸만 생략하고 데미지 자체에는 영향 없음.
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

	local function onCharacterAdded(character)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if not humanoid then
			return
		end
		applyCharacterHealth(humanoid, gameConfig)
	end

	for _, player in ipairs(players:GetPlayers()) do
		if player.Character then
			task.spawn(onCharacterAdded, player.Character)
		end
		player.CharacterAdded:Connect(onCharacterAdded)
	end

	players.PlayerAdded:Connect(function(player)
		if player.Character then
			task.spawn(onCharacterAdded, player.Character)
		end
		player.CharacterAdded:Connect(onCharacterAdded)
	end)

	players.PlayerRemoving:Connect(function(player)
		lastDamageAt[player] = nil
	end)

	-- Per-tier sphere 반지름 배수 lookup. 누락 / 비정상 값은 1 폴백.
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
						-- 신규 tier 우선, 호환성을 위해 레거시 isBoss 플래그도 OR 처리.
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

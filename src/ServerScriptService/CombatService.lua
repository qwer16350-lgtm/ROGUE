local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatService = {}

function CombatService.init(players, runService, gameConfig, enemyService, progressionService, xpPickupService, waveService, healthPickupService)
	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local upgradeData = require(Shared:WaitForChild("UpgradeData"))

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local vfxEvent = remotes:WaitForChild("VFXEvent")
	local damageNumberEvent = remotes:WaitForChild("DamageNumberEvent") :: RemoteEvent
	local bossHealthEvent = remotes:WaitForChild("BossHealthEvent") :: RemoteEvent

	local function damageFloatingWorldPosition(part: BasePart): Vector3
		return (part.CFrame * CFrame.new(0, part.Size.Y * 0.5 + 1.5, 0)).Position
	end

	local function pushBossHealthBar(part: BasePart?)
		if not part or not part.Parent then
			return
		end
		local mxAttr = tonumber(part:GetAttribute("MaxHealth"))
		local mx = mxAttr ~= nil and math.max(1, math.floor(mxAttr :: number + 0.5)) or 1
		local curAttr = tonumber(part:GetAttribute("Health"))
		local cur = curAttr ~= nil and math.floor((curAttr :: number) + 0.5) or mx
		if cur < 0 then
			cur = 0
		end
		bossHealthEvent:FireAllClients({
			Phase = "Update",
			Current = cur,
			Max = mx,
		})
	end

	local function pushDamageNumber(dmg: number, part: BasePart)
		local pos = damageFloatingWorldPosition(part)
		damageNumberEvent:FireAllClients({
			Amount = math.floor(dmg + 0.5),
			WorldPosition = pos,
		})
	end

	local function fireVfx(effectType, position, hitPart, attackRadiusStuds, attackerUserId, attackCooldownSeconds)
		local payload = {
			EffectType = effectType,
			Position = position,
		}
		if hitPart then
			payload.HitPart = hitPart
		end
		if effectType == "attack" and type(attackRadiusStuds) == "number" then
			payload.Radius = attackRadiusStuds
		end
		if effectType == "attack" and type(attackerUserId) == "number" then
			payload.AttackerUserId = attackerUserId
		end
		if effectType == "attack" and type(attackCooldownSeconds) == "number" and attackCooldownSeconds > 0 then
			payload.AttackCooldown = attackCooldownSeconds
		end
		vfxEvent:FireAllClients(payload)
	end

	local lastAttackTime = {}

	players.PlayerRemoving:Connect(function(player)
		lastAttackTime[player] = nil
	end)

	runService.Heartbeat:Connect(function()
		local entries = enemyService.getEnemyEntries()
		if not entries then
			return
		end

		local now = tick()
		local xpDrop = gameConfig.XpOrbPerKill

		for _, player in players:GetPlayers() do
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if not root then
				continue
			end

			local upgrades = progressionService.getUpgradeCounts(player)
			local stats = upgradeData.getEffectiveCombatStats(gameConfig, upgrades)
			local effectiveInterval = stats.attackIntervalSeconds
			local effectiveRange = stats.attackRangeStuds
			local damage = stats.damagePerHit

			local last = lastAttackTime[player] or 0
			if now - last < effectiveInterval then
				continue
			end

			lastAttackTime[player] = now

			local function gatherCandidatesAtHrp()
				local center = root.Position
				local list = {}
				for _, entry in ipairs(entries) do
					local part = entry.part
					if part and part.Parent then
						local dist = (part.Position - center).Magnitude
						if dist <= effectiveRange then
							table.insert(list, { entry = entry, dist = dist })
						end
					end
				end
				return center, list
			end

			local rootPos, candidates = gatherCandidatesAtHrp()
			fireVfx("attack", rootPos, nil, effectiveRange, player.UserId, effectiveInterval)

			if #candidates == 0 then
				continue
			end

			table.sort(candidates, function(a, b)
				return a.dist < b.dist
			end)

			for _, cand in ipairs(candidates) do
				local entry = cand.entry
				local part = entry.part
				if not part.Parent then
					continue
				end
				local centerNow = root.Position
				if (part.Position - centerNow).Magnitude > effectiveRange then
					continue
				end
				local hitPos = part.Position

				entry.state.health -= damage

				pushDamageNumber(damage, part)

				if entry.state.isBoss and part.Parent then
					part:SetAttribute("Health", math.max(0, entry.state.health))
					pushBossHealthBar(part)
				end

				if entry.state.health <= 0 then
					fireVfx("death", hitPos)
					waveService.recordKill()
					-- Health vs XP 배타 드랍: Health 롤이 성공하면 XP 는 그 사망에서 미드랍.
					-- healthPickupService 누락 / 확률 0 → 항상 XP 폴백 (안전).
					local dropChance = (healthPickupService and gameConfig.HealthOrbDropChance) or 0
					if type(dropChance) ~= "number" or dropChance <= 0 then
						dropChance = 0
					end
					if dropChance > 0 and math.random() < dropChance then
						healthPickupService.spawnAt(hitPos, gameConfig)
					else
						xpPickupService.spawnAt(hitPos, xpDrop)
					end
					part:Destroy()
				else
					fireVfx("hit", hitPos, part)
				end
			end
		end
	end)
end

return CombatService

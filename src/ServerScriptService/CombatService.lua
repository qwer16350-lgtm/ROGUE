local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatService = {}

function CombatService.init(
	players,
	runService,
	gameConfig,
	enemyService,
	progressionService,
	xpPickupService,
	waveService,
	healthPickupService,
	weaponDropService,
	relicDropService
)
	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local RunWeaponResolver = require(Shared:WaitForChild("RunWeaponResolver"))
	local upgradeData = require(Shared:WaitForChild("UpgradeData"))
	local weaponProfiles = require(Shared:WaitForChild("WeaponProfiles"))
	local relicData = require(Shared:WaitForChild("RelicData"))

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local vfxEvent = remotes:WaitForChild("VFXEvent")
	local damageNumberEvent = remotes:WaitForChild("DamageNumberEvent") :: RemoteEvent
	local bossHealthEvent = remotes:WaitForChild("BossHealthEvent") :: RemoteEvent

	local attackRangeDebugEvent = ReplicatedStorage:FindFirstChild("AttackRangeDebugEvent")
	if not attackRangeDebugEvent then
		local ev = Instance.new("RemoteEvent")
		ev.Name = "AttackRangeDebugEvent"
		ev.Parent = ReplicatedStorage
		attackRangeDebugEvent = ev
	end
	attackRangeDebugEvent = attackRangeDebugEvent :: RemoteEvent

	local function fireAttackRangeDebug(payload)
		local dbg = gameConfig.Debug
		if type(dbg) ~= "table" or dbg.ShowAttackRanges ~= true then
			return
		end
		attackRangeDebugEvent:FireAllClients(payload)
	end

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

	local function fireVfx(
		effectType,
		position,
		hitPart,
		attackRadiusStuds,
		attackerUserId,
		attackCooldownSeconds,
		subtype: string?,
		attackForward: Vector3?
	)
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
		if effectType == "attack" and type(subtype) == "string" then
			payload.Subtype = subtype
		end
		if effectType == "attack" and typeof(attackForward) == "Vector3" then
			payload.AttackForward = attackForward
		end
		vfxEvent:FireAllClients(payload)
	end

	-- multi-weapon 대비: cooldown은 player + weaponId 단위로 저장
	local lastAttackByPlayerWeapon: { [Player]: { [string]: number } } = {}
	local function getLastAttack(player: Player, weaponId: string): number
		local m = lastAttackByPlayerWeapon[player]
		if type(m) ~= "table" then
			return 0
		end
		local v = m[weaponId]
		return type(v) == "number" and v or 0
	end
	local function setLastAttack(player: Player, weaponId: string, t: number)
		local m = lastAttackByPlayerWeapon[player]
		if type(m) ~= "table" then
			m = {}
			lastAttackByPlayerWeapon[player] = m
		end
		m[weaponId] = t
	end

	-- SwordShield alternating state: player + weaponId 단위 분리 (요구사항)
	local swordShieldNextIsThrust: { [Player]: { [string]: boolean } } = {}
	local warnedUnknownActiveWeapon: { [string]: boolean } = {}

	local effectiveWeaponId = RunWeaponResolver.resolveEffectiveWeaponId(gameConfig)

	players.PlayerRemoving:Connect(function(player)
		lastAttackByPlayerWeapon[player] = nil
		swordShieldNextIsThrust[player] = nil
	end)

	local xpDrop = gameConfig.XpOrbPerKill

	local function getSwordShieldWeaponDropChance(): number
		local base = gameConfig.SwordShieldWeaponDropChance
		if type(base) ~= "number" or base < 0 or base > 1 then
			base = 0.01
		end
		local dbg = gameConfig.Debug
		if type(dbg) == "table" then
			local o = dbg.SwordShieldWeaponDropChanceOverride
			if type(o) == "number" and o >= 0 and o <= 1 then
				return o
			end
		end
		return base
	end

	local function getSwordShieldRelicChestDropChance(): number
		local base = gameConfig.SwordShieldRelicChestDropChance
		if type(base) ~= "number" or base < 0 or base > 1 then
			base = 0.02
		end
		local dbg = gameConfig.Debug
		if type(dbg) == "table" then
			local o = dbg.RelicChestDropChanceOverride
			if type(o) == "number" and o >= 0 and o <= 1 then
				return o
			end
		end
		return base
	end

	--- 타겟 확정 후 피해/처치 처리 (판정 분기 바깥 공통 로직)
	local function applyDamageResolved(player: Player, entry, damage: number, sourceWeaponId: string)
		local part = entry.part
		if not part.Parent then
			return
		end
		entry.state.health -= damage

		pushDamageNumber(damage, part)

		if entry.state.isBoss and part.Parent then
			part:SetAttribute("Health", math.max(0, entry.state.health))
			pushBossHealthBar(part)
		end

		local hitPos = part.Position

		if entry.state.health <= 0 then
			fireVfx("death", hitPos)
			waveService.recordKill()
			local deathPos = part.Position
			local dropChance = (healthPickupService and gameConfig.HealthOrbDropChance) or 0
			if type(dropChance) ~= "number" or dropChance <= 0 then
				dropChance = 0
			end
			if dropChance > 0 and math.random() < dropChance then
				healthPickupService.spawnAt(hitPos, gameConfig)
			else
				xpPickupService.spawnAt(hitPos, xpDrop)
			end

			-- 기존 정책 유지(보수): 런 effective weapon 및 legacy weaponId가 SwordShield일 때만 드롭/릴릭 체스트 롤
			if weaponDropService and sourceWeaponId == "SwordShield" and math.random() < getSwordShieldWeaponDropChance() then
				local dropWeaponId = "SwordShield"
				if type(weaponDropService.pickDropWeaponId) == "function" then
					dropWeaponId = weaponDropService.pickDropWeaponId()
					if type(dropWeaponId) ~= "string" or dropWeaponId == "" then
						dropWeaponId = "SwordShield"
					end
				end
				if type(weaponDropService.spawnWeaponDropAt) == "function" then
					weaponDropService.spawnWeaponDropAt(deathPos, player, dropWeaponId)
				else
					weaponDropService.spawnSwordShieldDropAt(deathPos, player)
				end
			end
			if
				relicDropService
				and sourceWeaponId == "SwordShield"
				and progressionService.getWeaponId(player) == "SwordShield"
				and math.random() < getSwordShieldRelicChestDropChance()
			then
				relicDropService.spawnRelicChestAt(deathPos, player)
			end
			part:Destroy()
		else
			fireVfx("hit", hitPos, part)
		end
	end

	--- apexDeg = 원뿔 꼭짓점 각(전체 각도). 전방축 forward 기준 대칭 원뿔.
	local function inForwardCone(origin: Vector3, forward: Vector3, targetPos: Vector3, range: number, apexDeg: number): boolean
		local v = targetPos - origin
		local dist = v.Magnitude
		if dist > range or dist < 1e-4 then
			return false
		end
		local dir = v / dist
		local f = forward.Unit
		local c = f:Dot(dir)
		local half = math.rad(math.clamp(apexDeg, 0, 360) * 0.5)
		return c >= math.cos(half)
	end

	local function thrustForwardXZFromOffset(offset: Vector3): Vector3
		local f = Vector3.new(offset.X, 0, offset.Z)
		if f.Magnitude < 1e-4 then
			return Vector3.new(0, 0, -1)
		end
		return f.Unit
	end

	local function thrustRightXZ(forwardXZ: Vector3): Vector3
		local r = Vector3.new(-forwardXZ.Z, 0, forwardXZ.X)
		if r.Magnitude < 1e-4 then
			return Vector3.new(1, 0, 0)
		end
		return r.Unit
	end

	--- Thrust 전용: XZ 평면 스트립 (forwardXZ·rightXZ 는 단위벡터, Y 성분 0).
	local function inThrustStripXZ(
		origin: Vector3,
		forwardXZ: Vector3,
		targetPos: Vector3,
		length: number,
		widthStuds: number
	): boolean
		if type(length) ~= "number" or length <= 0 then
			return false
		end
		if type(widthStuds) ~= "number" or widthStuds <= 0 then
			return false
		end
		local f = forwardXZ
		local right = thrustRightXZ(forwardXZ)
		local halfW = widthStuds * 0.5
		local offset = targetPos - origin
		local forwardDistance = offset:Dot(f)
		local rightDistance = math.abs(offset:Dot(right))
		return forwardDistance >= 0 and forwardDistance <= length and rightDistance <= halfW
	end

	local function heartbeatBasicMagicWeapon(player: Player, weaponId: string, root: BasePart, entries, now: number)
		local upgrades = progressionService.getUpgradeCounts(player)
		local stats = upgradeData.getEffectiveCombatStats(gameConfig, upgrades)
		local effectiveInterval = stats.attackIntervalSeconds
		local effectiveRange = stats.attackRangeStuds
		local damage = stats.damagePerHit

		local last = getLastAttack(player, weaponId)
		if now - last < effectiveInterval then
			return
		end
		setLastAttack(player, weaponId, now)

		local center = root.Position
		local candidates = {}
		for _, entry in ipairs(entries) do
			local part = entry.part
			if part and part.Parent then
				local dist = (part.Position - center).Magnitude
				if dist <= effectiveRange then
					table.insert(candidates, { entry = entry, dist = dist })
				end
			end
		end

		fireVfx("attack", center, nil, effectiveRange, player.UserId, effectiveInterval, "BasicMagic", nil)
		fireAttackRangeDebug({
			Shape = "Circle",
			Origin = center,
			Range = effectiveRange,
			Duration = 0.15,
			AttackKind = "BasicMagic",
		})

		if #candidates == 0 then
			return
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
			applyDamageResolved(player, entry, damage, "BasicMagic")
		end
	end

	local function heartbeatSwordShieldWeapon(player: Player, weaponId: string, root: BasePart, entries, now: number)
		local profile = weaponProfiles.SwordShield
		local upgrades = progressionService.getUpgradeCounts(player)
		local relicId = progressionService.getStartingRelicId(player)
		local droppedRelicId = progressionService.getDroppedRelicId(player)
		local weaponGrade = progressionService.getWeaponGradeFor(player, weaponId)
		local eff = upgradeData.getSwordShieldEffectiveCombat(gameConfig, profile, upgrades, relicId, droppedRelicId, weaponGrade)
		local interval = eff.AttackIntervalSeconds
		local sweepEff = eff.Sweep
		local thrustEff = eff.Thrust

		local lastSs = getLastAttack(player, weaponId)
		if now - lastSs < interval then
			return
		end

		local searchRange =
			type(profile.TargetSearchRangeStuds) == "number" and profile.TargetSearchRangeStuds > 0 and profile.TargetSearchRangeStuds
				or thrustEff.RangeStuds

		local origin = root.Position

		local bestEntry = nil
		local bestDist = math.huge
		for _, entry in ipairs(entries) do
			local part = entry.part
			if part and part.Parent then
				local d = (part.Position - origin).Magnitude
				if d <= searchRange and d < bestDist then
					bestDist = d
					bestEntry = entry
				end
			end
		end

		if not bestEntry or not bestEntry.part.Parent then
			return
		end

		local toTarget = bestEntry.part.Position - origin
		local dMag = toTarget.Magnitude
		if dMag < 1e-4 then
			return
		end
		local forward = toTarget / dMag
		local forwardThrustXZ = thrustForwardXZFromOffset(toTarget)

		setLastAttack(player, weaponId, now)

		local m = swordShieldNextIsThrust[player]
		if type(m) ~= "table" then
			m = {}
			swordShieldNextIsThrust[player] = m
		end
		local useThrust = m[weaponId] == true
		m[weaponId] = not useThrust

		local cfgEff = useThrust and thrustEff or sweepEff
		local range = cfgEff.RangeStuds
		local apex = cfgEff.AngleDeg
		local damage = cfgEff.BaseDamage
		local subtype = useThrust and "Thrust" or "Sweep"

		local thrustW = thrustEff.WidthStuds
		if type(thrustW) ~= "number" or thrustW <= 0 then
			thrustW = 3
		end

		local inCone = {}

		if useThrust then
			local thrustLen = thrustEff.RangeStuds
			for _, entry in ipairs(entries) do
				local part = entry.part
				if part and part.Parent and inThrustStripXZ(origin, forwardThrustXZ, part.Position, thrustLen, thrustW) then
					table.insert(inCone, entry)
				end
			end
			table.sort(inCone, function(a, b)
				local pa = a.part.Position - origin
				local pb = b.part.Position - origin
				local ta = pa:Dot(forwardThrustXZ)
				local tb = pb:Dot(forwardThrustXZ)
				if math.abs(ta - tb) > 1e-3 then
					return ta < tb
				end
				return pa.Magnitude < pb.Magnitude
			end)
		else
			for _, entry in ipairs(entries) do
				local part = entry.part
				if part and part.Parent and inForwardCone(origin, forward, part.Position, range, apex) then
					table.insert(inCone, entry)
				end
			end
			table.sort(inCone, function(a, b)
				return (a.part.Position - origin).Magnitude < (b.part.Position - origin).Magnitude
			end)
		end

		--- Sweep/Thrust attack VFX: 적 타점이 아닌 공격자 HRP (방향은 AttackForward 유지).
		local attackVfxOrigin = root.Position
		fireVfx("attack", attackVfxOrigin, nil, range, player.UserId, interval, subtype, forward)
		if useThrust then
			fireAttackRangeDebug({
				Shape = "LineBox",
				Origin = origin,
				Forward = forwardThrustXZ,
				Length = thrustEff.RangeStuds,
				Width = thrustW,
				Duration = 0.15,
				AttackKind = subtype,
			})
		else
			fireAttackRangeDebug({
				Shape = "Cone",
				Origin = origin,
				Forward = forward,
				Range = range,
				AngleDeg = apex,
				Duration = 0.15,
				AttackKind = subtype,
			})
		end

		for _, entry in ipairs(inCone) do
			local part = entry.part
			if part.Parent then
				-- DroppedRelic shield_spike: Sweep hit knockback only (server-side, XZ only).
				if not useThrust and droppedRelicId == "shield_spike" then
					local eff2 = relicData.getDroppedRelicEffect(droppedRelicId)
					if type(eff2) == "table" and eff2.sweepKnockback == true then
						local force = eff2.knockbackForce
						if type(force) ~= "number" or force <= 0 then
							force = 60
						end
						local offset = part.Position - root.Position
						local dirXZ = Vector3.new(offset.X, 0, offset.Z)
						if dirXZ.Magnitude < 1e-4 then
							dirXZ = Vector3.new(forward.X, 0, forward.Z)
						end
						if dirXZ.Magnitude >= 1e-4 then
							local dir = dirXZ.Unit
							local v = part.AssemblyLinearVelocity
							part.AssemblyLinearVelocity = Vector3.new(dir.X * force, v.Y, dir.Z * force)
						end
					end
				end
				applyDamageResolved(player, entry, damage, "SwordShield")
			end
		end
	end

	local function heartbeatSpearWeapon(player: Player, weaponId: string, root: BasePart, entries, now: number)
		local profile = weaponProfiles.Spear
		if type(profile) ~= "table" then
			return
		end
		local upgrades = progressionService.getUpgradeCounts(player)
		local weaponGrade = progressionService.getWeaponGradeFor(player, weaponId)
		local eff = upgradeData.getSpearEffectiveCombat(gameConfig, profile, upgrades, weaponGrade)
		local thrustEff = type(eff) == "table" and eff.Thrust or nil
		if type(thrustEff) ~= "table" then
			return
		end
		local interval = type(eff.AttackIntervalSeconds) == "number" and eff.AttackIntervalSeconds or 1.1
		if interval <= 0 then
			interval = 1.1
		end
		local baseDamage = type(thrustEff.BaseDamage) == "number" and thrustEff.BaseDamage or 30
		local thrustLen = type(thrustEff.RangeStuds) == "number" and thrustEff.RangeStuds or 12
		local thrustW = type(thrustEff.WidthStuds) == "number" and thrustEff.WidthStuds or 3
		local targetLimit = type(thrustEff.TargetLimit) == "number" and math.max(1, math.floor(thrustEff.TargetLimit)) or 1

		local last = getLastAttack(player, weaponId)
		if now - last < interval then
			return
		end

		local searchRange = type(profile.TargetSearchRangeStuds) == "number" and profile.TargetSearchRangeStuds or thrustLen
		local origin = root.Position
		local bestEntry = nil
		local bestDist = math.huge
		for _, entry in ipairs(entries) do
			local part = entry.part
			if part and part.Parent then
				local d = (part.Position - origin).Magnitude
				if d <= searchRange and d < bestDist then
					bestDist = d
					bestEntry = entry
				end
			end
		end
		if not bestEntry or not bestEntry.part or not bestEntry.part.Parent then
			return
		end

		local toTarget = bestEntry.part.Position - origin
		if toTarget.Magnitude < 1e-4 then
			return
		end
		local forward = toTarget.Unit
		local forwardThrustXZ = thrustForwardXZFromOffset(toTarget)

		setLastAttack(player, weaponId, now)

		local inStrip = {}
		for _, entry in ipairs(entries) do
			local part = entry.part
			if part and part.Parent and inThrustStripXZ(origin, forwardThrustXZ, part.Position, thrustLen, thrustW) then
				table.insert(inStrip, entry)
			end
		end
		table.sort(inStrip, function(a, b)
			local pa = a.part.Position - origin
			local pb = b.part.Position - origin
			local ta = pa:Dot(forwardThrustXZ)
			local tb = pb:Dot(forwardThrustXZ)
			if math.abs(ta - tb) > 1e-3 then
				return ta < tb
			end
			return pa.Magnitude < pb.Magnitude
		end)

		fireVfx("attack", origin, nil, thrustLen, player.UserId, interval, "SpearThrust", forward)
		fireAttackRangeDebug({
			Shape = "LineBox",
			Origin = origin,
			Forward = forwardThrustXZ,
			Length = thrustLen,
			Width = thrustW,
			Duration = 0.15,
			AttackKind = "Spear",
		})

		local hitCount = 0
		for _, entry in ipairs(inStrip) do
			local part = entry.part
			if part and part.Parent then
				applyDamageResolved(player, entry, baseDamage, "Spear")
				hitCount += 1
				if hitCount >= targetLimit then
					break
				end
			end
		end
	end

	local function heartbeatTwoHandedSwordWeapon(player: Player, weaponId: string, root: BasePart, entries, now: number)
		local profile = weaponProfiles.TwoHandedSword
		if type(profile) ~= "table" then
			return
		end
		local sweep = profile.Sweep
		if type(sweep) ~= "table" then
			return
		end
		local interval = type(profile.AttackIntervalSeconds) == "number" and profile.AttackIntervalSeconds or 1.6
		if interval <= 0 then
			interval = 1.6
		end
		local damage = type(profile.BaseDamage) == "number" and profile.BaseDamage or 45
		local range = type(sweep.RangeStuds) == "number" and sweep.RangeStuds or 12
		local angle = type(sweep.AngleDeg) == "number" and sweep.AngleDeg or 180
		local targetLimit = nil
		if type(sweep.TargetLimit) == "number" then
			targetLimit = math.max(1, math.floor(sweep.TargetLimit))
		end

		local last = getLastAttack(player, weaponId)
		if now - last < interval then
			return
		end

		local searchRange = type(profile.TargetSearchRangeStuds) == "number" and profile.TargetSearchRangeStuds or range
		local origin = root.Position
		local bestEntry = nil
		local bestDist = math.huge
		for _, entry in ipairs(entries) do
			local part = entry.part
			if part and part.Parent then
				local d = (part.Position - origin).Magnitude
				if d <= searchRange and d < bestDist then
					bestDist = d
					bestEntry = entry
				end
			end
		end
		if not bestEntry or not bestEntry.part or not bestEntry.part.Parent then
			return
		end

		local toTarget = bestEntry.part.Position - origin
		if toTarget.Magnitude < 1e-4 then
			return
		end
		local forward = toTarget.Unit

		setLastAttack(player, weaponId, now)

		local inCone = {}
		for _, entry in ipairs(entries) do
			local part = entry.part
			if part and part.Parent and inForwardCone(origin, forward, part.Position, range, angle) then
				table.insert(inCone, entry)
			end
		end
		table.sort(inCone, function(a, b)
			return (a.part.Position - origin).Magnitude < (b.part.Position - origin).Magnitude
		end)

		fireVfx("attack", origin, nil, range, player.UserId, interval, "TwoHandedSweep", forward)
		fireAttackRangeDebug({
			Shape = "Cone",
			Origin = origin,
			Forward = forward,
			Range = range,
			AngleDeg = angle,
			Duration = 0.15,
			AttackKind = "TwoHandedSword",
		})

		local hitCount = 0
		for _, entry in ipairs(inCone) do
			local part = entry.part
			if part and part.Parent then
				applyDamageResolved(player, entry, damage, "TwoHandedSword")
				hitCount += 1
				if targetLimit ~= nil and hitCount >= targetLimit then
					break
				end
			end
		end
	end

	runService.Heartbeat:Connect(function()
		local entries = enemyService.getEnemyEntries()
		if not entries then
			return
		end

		local now = tick()
		local fallbackWeaponId = effectiveWeaponId

		for _, player in players:GetPlayers() do
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if not root then
				continue
			end

			-- 핵심 조건: activeWeapons가 1개 이상이면 그것만 실행(중복 방지)
			local aw = progressionService.getActiveWeapons(player)
			local hasActive = type(aw) == "table" and next(aw) ~= nil
			if hasActive then
				for weaponId, _ in pairs(aw) do
					if weaponId == "SwordShield" then
						heartbeatSwordShieldWeapon(player, weaponId, root, entries, now)
					elseif weaponId == "BasicMagic" then
						heartbeatBasicMagicWeapon(player, weaponId, root, entries, now)
					elseif weaponId == "Spear" then
						heartbeatSpearWeapon(player, weaponId, root, entries, now)
					elseif weaponId == "TwoHandedSword" then
						heartbeatTwoHandedSwordWeapon(player, weaponId, root, entries, now)
					else
						if warnedUnknownActiveWeapon[weaponId] ~= true then
							warn(string.format("[CombatService] unknown active weapon skipped: %s", tostring(weaponId)))
							warnedUnknownActiveWeapon[weaponId] = true
						end
					end
				end
			else
				-- activeWeapons가 없거나 비어있을 때만 legacy fallback
				if fallbackWeaponId == "SwordShield" then
					heartbeatSwordShieldWeapon(player, "SwordShield", root, entries, now)
				else
					heartbeatBasicMagicWeapon(player, "BasicMagic", root, entries, now)
				end
			end
		end
	end)
end

return CombatService
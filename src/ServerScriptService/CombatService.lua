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
	local phase3RelicPool = require(Shared:WaitForChild("Phase3RelicPool"))

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
		attackForward: Vector3?,
		attackCenter: Vector3?,
		attackLengthStuds: number?,
		attackWidthStuds: number?,
		attackAngleDeg: number?
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
		if effectType == "attack" and typeof(attackCenter) == "Vector3" then
			payload.AttackCenter = attackCenter
		end
		if effectType == "attack" and type(attackLengthStuds) == "number" and attackLengthStuds > 0 then
			payload.AttackLength = attackLengthStuds
		end
		if effectType == "attack" and type(attackWidthStuds) == "number" and attackWidthStuds > 0 then
			payload.AttackWidth = attackWidthStuds
		end
		if effectType == "attack" and type(attackAngleDeg) == "number" and attackAngleDeg > 0 then
			payload.AttackAngle = attackAngleDeg
		end
		vfxEvent:FireAllClients(payload)
	end

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

	local swordShieldNextIsThrust: { [Player]: { [string]: boolean } } = {}
	local warnedUnknownActiveWeapon: { [string]: boolean } = {}
	local HEALTH_ORB_CHANCE_STACK_ATTR = "ho_Chance_increase_stack"
	local HEALTH_ORB_CHANCE_BONUS_PER_STACK = 0.005

	local effectiveWeaponId = RunWeaponResolver.resolveEffectiveWeaponId(gameConfig)

	players.PlayerRemoving:Connect(function(player)
		lastAttackByPlayerWeapon[player] = nil
		swordShieldNextIsThrust[player] = nil
	end)

	local xpDrop = gameConfig.XpOrbPerKill

	local WEAPON_DROP_KILL_WEAPONS: { [string]: boolean } = {
		SwordShield = true,
		Spear = true,
		TwoHandedSword = true,
	}

	local function getWeaponDropChance(): number
		local base = gameConfig.WeaponDropChance
		if type(base) ~= "number" or base < 0 or base > 1 then
			base = 0.01
		end
		local dbg = gameConfig.Debug
		if type(dbg) == "table" then
			local o = dbg.WeaponDropChanceOverride
			if type(o) == "number" and o >= 0 and o <= 1 then
				return o
			end
		end
		return base
	end

	local PHASE3_CHEST_SOURCE_WEAPONS: { [string]: boolean } = {
		TwoHandedSword = true,
		Spear = true,
		SwordShield = true,
	}

	local function getPhase3RelicChestDropChance(): number
		local base = gameConfig.Phase3RelicChestDropChance
		if type(base) ~= "number" or base < 0 or base > 1 then
			return 0
		end
		local dbg = gameConfig.Debug
		if type(dbg) == "table" then
			local o = dbg.Phase3RelicChestDropChanceOverride
			if type(o) == "number" and o >= 0 and o <= 1 then
				return o
			end
		end
		return base
	end

	local function shouldForcePhase3RelicChestOnKill(): boolean
		local dbg = gameConfig.Debug
		return type(dbg) == "table" and dbg.ForcePhase3RelicChestOnKill == true
	end

	local function canSpawnPhase3RelicChestOnKill(player: Player, sourceWeaponId: string): boolean
		if not relicDropService or type(sourceWeaponId) ~= "string" then
			return false
		end
		if not PHASE3_CHEST_SOURCE_WEAPONS[sourceWeaponId] then
			return false
		end
		local weaponIds = progressionService.getActiveWeaponIdsForPhase3Offer(player)
		if type(weaponIds) ~= "table" or #weaponIds == 0 then
			return false
		end
		local owned = progressionService.getPhase3ActiveRelicIds(player)
		return phase3RelicPool.hasAvailableChoicesForWeapons(weaponIds, owned)
	end

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
			local baseDropChance = (healthPickupService and gameConfig.HealthOrbDropChance) or 0
			if type(baseDropChance) ~= "number" or baseDropChance <= 0 then
				baseDropChance = 0
			end
			local chanceStackRaw = player:GetAttribute(HEALTH_ORB_CHANCE_STACK_ATTR)
			local chanceStack = 0
			if type(chanceStackRaw) == "number" and chanceStackRaw > 0 then
				chanceStack = math.max(0, math.floor(chanceStackRaw + 0.5))
			end
			local effectiveDropChance = math.clamp(
				baseDropChance + HEALTH_ORB_CHANCE_BONUS_PER_STACK * chanceStack,
				0,
				1
			)
			if effectiveDropChance > 0 and math.random() < effectiveDropChance then
				healthPickupService.spawnAt(hitPos, gameConfig)
			else
				xpPickupService.spawnAt(hitPos, xpDrop)
			end

			if weaponDropService and WEAPON_DROP_KILL_WEAPONS[sourceWeaponId] and math.random() < getWeaponDropChance() then
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
			if canSpawnPhase3RelicChestOnKill(player, sourceWeaponId) then
				if shouldForcePhase3RelicChestOnKill() or math.random() < getPhase3RelicChestDropChance() then
					relicDropService.spawnPhase3RelicChestAt(deathPos, player)
				end
			end
			part:Destroy()
		else
			fireVfx("hit", hitPos, part)
		end
	end

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

		fireVfx("attack", center, nil, effectiveRange, player.UserId, effectiveInterval, "BasicMagic", nil, nil, nil, nil, nil)
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
		local weaponGrade = progressionService.getWeaponGradeFor(player, weaponId)
		local phase3RelicIds = progressionService.getPhase3ActiveRelicIds(player)
		local eff = upgradeData.getSwordShieldEffectiveCombat(
			gameConfig,
			profile,
			upgrades,
			relicId,
			weaponGrade,
			phase3RelicIds
		)
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

		local attackVfxOrigin = root.Position
		fireVfx("attack", attackVfxOrigin, nil, range, player.UserId, interval, subtype, forward, nil, useThrust and thrustEff.RangeStuds or range, useThrust and thrustW or nil, useThrust and nil or apex)
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
		local phase3RelicIds = progressionService.getPhase3ActiveRelicIds(player)
		local eff = upgradeData.getSpearEffectiveCombat(
			gameConfig,
			profile,
			upgrades,
			weaponGrade,
			phase3RelicIds
		)
		local thrustEff = type(eff) == "table" and eff.Thrust or nil
		if type(thrustEff) ~= "table" then
			return
		end
		local interval = type(eff.AttackIntervalSeconds) == "number" and eff.AttackIntervalSeconds or 0.7
		if interval <= 0 then
			interval = 0.7
		end
		local baseDamage = type(thrustEff.BaseDamage) == "number" and thrustEff.BaseDamage or 40
		local thrustLen = type(thrustEff.RangeStuds) == "number" and thrustEff.RangeStuds or 12
		local thrustW = type(thrustEff.WidthStuds) == "number" and thrustEff.WidthStuds or 3

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

		fireVfx("attack", origin + forwardThrustXZ * (thrustLen * 0.5), nil, thrustLen, player.UserId, interval, "SpearThrust", forward, origin + forwardThrustXZ * (thrustLen * 0.5), thrustLen, thrustW, nil)
		fireAttackRangeDebug({
			Shape = "LineBox",
			Origin = origin,
			Forward = forwardThrustXZ,
			Length = thrustLen,
			Width = thrustW,
			Duration = 0.15,
			AttackKind = "Spear",
		})

		for _, entry in ipairs(inStrip) do
			local part = entry.part
			if part and part.Parent then
				applyDamageResolved(player, entry, baseDamage, "Spear")
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
		local upgrades = progressionService.getUpgradeCounts(player)
		local weaponGrade = progressionService.getWeaponGradeFor(player, weaponId)
		local phase3RelicIds = progressionService.getPhase3ActiveRelicIds(player)
		local effective = upgradeData.getTwoHandedSwordEffectiveCombat(
			gameConfig,
			profile,
			upgrades,
			weaponGrade,
			phase3RelicIds
		)
		local effSweep = type(effective) == "table" and effective.Sweep or nil

		local interval = type(effective) == "table" and type(effective.AttackIntervalSeconds) == "number"
				and effective.AttackIntervalSeconds
			or (type(profile.AttackIntervalSeconds) == "number" and profile.AttackIntervalSeconds or 1.6)
		if interval <= 0 then
			interval = 1.6
		end
		local damage = type(effSweep) == "table" and type(effSweep.BaseDamage) == "number" and effSweep.BaseDamage
			or (type(profile.BaseDamage) == "number" and profile.BaseDamage or 45)
		local range = type(effSweep) == "table" and type(effSweep.RangeStuds) == "number" and effSweep.RangeStuds
			or (type(sweep.RangeStuds) == "number" and sweep.RangeStuds or 12)
		local angle = type(effSweep) == "table" and type(effSweep.AngleDeg) == "number" and effSweep.AngleDeg
			or (type(sweep.AngleDeg) == "number" and sweep.AngleDeg or 180)
		local targetLimit = nil
		if type(effSweep) == "table" and type(effSweep.TargetLimit) == "number" then
			targetLimit = math.max(1, math.floor(effSweep.TargetLimit + 0.5))
		elseif type(sweep.TargetLimit) == "number" then
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

		fireVfx("attack", origin, nil, range, player.UserId, interval, "TwoHandedSweep", forward, nil, range, nil, angle)
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
--- HealthPickupService — 적 사망 시 일정 확률로 떨어지는 빨간 회복 오브.
--- 시각·물리(직경, idle bob, 자석 반경/속도, 픽업 반경) 는 XpPickupService 와 동일한
--- GameConfig 키(XpOrbPartDiameter, XpOrbBob*, Xp*RadiusStuds, XpMagnetSpeedStudsPerSecond)
--- 를 그대로 공유한다. 차등 튜닝이 필요해지면 GameConfig 에 Health 전용 키를 분기.
---
--- 픽업 정책:
---   - hum.Health <= 0 (사망)         → 무시 (오브 유지)
---   - hum.Health >= hum.MaxHealth     → 무시 (오브 유지) — 만체 시 소비 안 함
---   - 그 외                            → 회복 + 오브 소비
--- 만체 / 사망 플레이어는 자석 흡수 대상에서도 제외하여, 가까이 있어도 오브가
--- 들러붙지 않고 idle bob 상태로 남는다.

local Workspace = game:GetService("Workspace")

local HealthPickupService = {}

local orbs = {}
local folder = nil
local orbDiameter = 1.2

local function ensureFolder()
	if folder and folder.Parent then
		return folder
	end
	folder = Workspace:FindFirstChild("HealthOrbs")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "HealthOrbs"
		folder.Parent = Workspace
	end
	return folder
end

function HealthPickupService.spawnAt(position, gameConfig)
	if typeof(position) ~= "Vector3" then
		return
	end

	local d = orbDiameter
	local color = (gameConfig and gameConfig.HealthOrbColor) or Color3.fromRGB(255, 60, 60)

	local part = Instance.new("Part")
	part.Name = "HealthOrb"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(d, d, d)
	part.Anchored = true
	part.CanCollide = false
	part.Color = color
	part.Material = Enum.Material.Neon
	part.Position = position
	part.Parent = ensureFolder()

	table.insert(orbs, {
		part = part,
		idleAnchorPosition = position,
		bobPhase = math.random() * math.pi * 2,
	})
end

function HealthPickupService.clearAllOrbs()
	for i = #orbs, 1, -1 do
		local orb = orbs[i]
		if orb.part and orb.part.Parent then
			orb.part:Destroy()
		end
		table.remove(orbs, i)
	end
	if folder and folder.Parent then
		for _, ch in ipairs(folder:GetChildren()) do
			if ch:IsA("BasePart") and ch.Name == "HealthOrb" then
				ch:Destroy()
			end
		end
	end
end

function HealthPickupService.init(players, runService, gameConfig)
	orbDiameter = gameConfig.XpOrbPartDiameter
	local pickupRadius = gameConfig.XpPickupRadiusStuds
	local magnetRadius = gameConfig.XpMagnetRadiusStuds
	local magnetSpeed = gameConfig.XpMagnetSpeedStudsPerSecond
	if type(magnetRadius) ~= "number" or magnetRadius <= pickupRadius then
		magnetRadius = pickupRadius + 0.01
	end
	if type(magnetSpeed) ~= "number" or magnetSpeed <= 0 then
		magnetSpeed = 20
	end

	local bobAmp = gameConfig.XpOrbBobAmplitudeStuds
	local bobAngular = gameConfig.XpOrbBobAngularSpeed
	if type(bobAmp) ~= "number" or bobAmp < 0 then
		bobAmp = 0
	end
	if type(bobAngular) ~= "number" or bobAngular < 0 then
		bobAngular = 0
	end

	ensureFolder()

	local function getNearestPlayerRoot(orbPos)
		local bestPlayer = nil
		local bestRoot = nil
		local bestDist = math.huge
		for _, player in ipairs(players:GetPlayers()) do
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if root then
				local d = (root.Position - orbPos).Magnitude
				if d < bestDist then
					bestDist = d
					bestPlayer = player
					bestRoot = root
				end
			end
		end
		return bestPlayer, bestRoot, bestDist
	end

	local function applyIdleBob(orb, part)
		local anchor = orb.idleAnchorPosition
		if not anchor then
			return
		end
		if bobAmp > 0 and bobAngular > 0 then
			local yOff = bobAmp * math.sin(bobAngular * tick() + orb.bobPhase)
			part.Position = Vector3.new(anchor.X, anchor.Y + yOff, anchor.Z)
		else
			part.Position = anchor
		end
	end

	--- 회복·자석 흡수 자격 판정. 사망/만체 플레이어는 false.
	local function isEligible(humanoid)
		if not humanoid then
			return false
		end
		if humanoid.Health <= 0 then
			return false
		end
		if humanoid.Health >= humanoid.MaxHealth then
			return false
		end
		return true
	end

	runService.Heartbeat:Connect(function(dt)
		if type(dt) ~= "number" or dt <= 0 then
			dt = 1 / 60
		end
		for i = #orbs, 1, -1 do
			local orb = orbs[i]
			local part = orb.part
			if not part.Parent then
				table.remove(orbs, i)
				continue
			end

			local pos = part.Position
			local _nearestPlayer, nearestRoot, dist = getNearestPlayerRoot(pos)
			if not nearestRoot then
				applyIdleBob(orb, part)
				continue
			end

			local hum = nearestRoot.Parent and nearestRoot.Parent:FindFirstChildOfClass("Humanoid")
			local eligible = isEligible(hum)

			if dist <= pickupRadius then
				if eligible then
					local healPct = gameConfig.HealthOrbHealPercentOfMaxHp
					if type(healPct) ~= "number" or healPct < 0 then
						healPct = 0
					end
					local healAmt = hum.MaxHealth * healPct
					hum.Health = math.min(hum.MaxHealth, hum.Health + healAmt)
					part:Destroy()
					table.remove(orbs, i)
				else
					applyIdleBob(orb, part)
				end
				continue
			end

			if dist <= magnetRadius and eligible then
				local targetPos = nearestRoot.Position
				local offset = targetPos - pos
				local len = offset.Magnitude
				if len > 1e-4 then
					local dir = offset / len
					local step = math.min(magnetSpeed * dt, len)
					part.Position = pos + dir * step
				end
			else
				applyIdleBob(orb, part)
			end
		end
	end)
end

return HealthPickupService

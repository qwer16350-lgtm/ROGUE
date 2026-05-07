---

local Workspace = game:GetService("Workspace")

local HealthPickupService = {}

local orbs = {}
local folder = nil
local orbDiameter = 1.2
local MAGNET_RANGE_STACK_ATTR = "mg_Range_increase_stack"
local MAGNET_RANGE_MUL_PER_STACK = 0.20
local HEALTH_ORB_AMOUNT_STACK_ATTR = "ho_Amount_increase_stack"
local HEALTH_ORB_AMOUNT_MUL_PER_STACK = 0.20

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

	local function getEffectiveMagnetRadiusForPlayer(player)
		if not player then
			return magnetRadius
		end
		local raw = player:GetAttribute(MAGNET_RANGE_STACK_ATTR)
		local stack = 0
		if type(raw) == "number" and raw > 0 then
			stack = math.max(0, math.floor(raw + 0.5))
		end
		return magnetRadius * (1 + MAGNET_RANGE_MUL_PER_STACK * stack)
	end

	local function getHealthOrbAmountMultiplierForPlayer(player)
		if not player then
			return 1
		end
		local raw = player:GetAttribute(HEALTH_ORB_AMOUNT_STACK_ATTR)
		local stack = 0
		if type(raw) == "number" and raw > 0 then
			stack = math.max(0, math.floor(raw + 0.5))
		end
		return 1 + HEALTH_ORB_AMOUNT_MUL_PER_STACK * stack
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
			local nearestPlayer, nearestRoot, dist = getNearestPlayerRoot(pos)
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
					local baseHeal = hum.MaxHealth * healPct
					local effectiveHeal = baseHeal * getHealthOrbAmountMultiplierForPlayer(nearestPlayer)
					hum.Health = math.min(hum.MaxHealth, hum.Health + effectiveHeal)
					part:Destroy()
					table.remove(orbs, i)
				else
					applyIdleBob(orb, part)
				end
				continue
			end

			local effectiveMagnetRadius = getEffectiveMagnetRadiusForPlayer(nearestPlayer)
			if dist <= effectiveMagnetRadius and eligible then
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
local Workspace = game:GetService("Workspace")

local XpPickupService = {}

local orbs = {}
local folder = nil
local orbDiameter = 1.2

function XpPickupService.spawnAt(position, amount)
	if type(amount) ~= "number" or amount <= 0 then
		return
	end

	if not folder or not folder.Parent then
		folder = Workspace:FindFirstChild("XpOrbs")
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = "XpOrbs"
			folder.Parent = Workspace
		end
	end

	local d = orbDiameter
	local part = Instance.new("Part")
	part.Name = "XpOrb"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(d, d, d)
	part.Anchored = true
	part.CanCollide = false
	part.Color = Color3.fromRGB(100, 220, 130)
	part.Material = Enum.Material.Neon
	part.Position = position
	part.Parent = folder

	table.insert(orbs, {
		part = part,
		amount = amount,
		idleAnchorPosition = position,
		bobPhase = math.random() * math.pi * 2,
	})
end

function XpPickupService.clearAllOrbs()
	for i = #orbs, 1, -1 do
		local orb = orbs[i]
		if orb.part and orb.part.Parent then
			orb.part:Destroy()
		end
		table.remove(orbs, i)
	end
	if folder and folder.Parent then
		for _, ch in ipairs(folder:GetChildren()) do
			if ch:IsA("BasePart") and ch.Name == "XpOrb" then
				ch:Destroy()
			end
		end
	end
end

function XpPickupService.init(players, runService, progressionService, gameConfig)
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

	folder = Workspace:FindFirstChild("XpOrbs")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "XpOrbs"
		folder.Parent = Workspace
	end

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

			if dist <= pickupRadius then
				progressionService.addExperience(nearestPlayer, orb.amount)
				part:Destroy()
				table.remove(orbs, i)
				continue
			end

			if dist <= magnetRadius then
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

return XpPickupService

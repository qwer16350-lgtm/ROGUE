local Workspace = game:GetService("Workspace")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EnemyTier = require(Shared:WaitForChild("Config"):WaitForChild("EnemyTier"))

local EnemyService = {}

local enemyEntriesRef = nil
local enemiesFolderRef = nil
local spawnWorldOffset = Vector3.zero

local ELITE_GRUNT_SIZE_MUL = 1.3

local function applyGruntPartDefaults(part, gameConfig, isElite)
	part.Name = "Enemy"
	if isElite then
		part.Size = gameConfig.EnemyGruntSize * ELITE_GRUNT_SIZE_MUL
		part.Color = Color3.fromRGB(230, 200, 60)
		part:SetAttribute("IsElite", true)
	else
		part.Size = gameConfig.EnemyGruntSize
		part.Color = Color3.fromRGB(200, 60, 60)
		part:SetAttribute("IsElite", false)
	end

	local useCollide = gameConfig.EnemyPartCanCollide
	part.CanCollide = useCollide
	if useCollide then
		part.Anchored = false
		part.Massless = true
		part.CollisionGroup = "Enemy"
	else
		part.Anchored = true
	end
end

local function applyBossPartDefaults(part, gameConfig)
	part.Name = "Boss"
	part.Size = gameConfig.EnemyBossSize
	part.Color = Color3.fromRGB(140, 40, 180)

	local useCollide = gameConfig.EnemyPartCanCollide
	part.CanCollide = useCollide
	if useCollide then
		part.Anchored = false
		part.Massless = true
		part.CollisionGroup = "Enemy"
	else
		part.Anchored = true
	end
end

function EnemyService.getEnemyEntries()
	return enemyEntriesRef
end

function EnemyService.setSpawnWorldOffset(offset)
	if typeof(offset) == "Vector3" then
		spawnWorldOffset = offset
	else
		spawnWorldOffset = Vector3.zero
	end
end

function EnemyService.spawnGrunt(gameConfig, isElite, eliteHealthMul)
	if isElite == nil then
		isElite = false
	end
	if not enemyEntriesRef or not enemiesFolderRef then
		return
	end

	local part = Instance.new("Part")
	applyGruntPartDefaults(part, gameConfig, isElite)

	local angle = math.random() * math.pi * 2
	local dist = gameConfig.EnemySpawnRadiusMin
		+ math.random() * (gameConfig.EnemySpawnRadiusMax - gameConfig.EnemySpawnRadiusMin)
	local y = gameConfig.EnemyGruntSpawnHeight
	part.Position = spawnWorldOffset
		+ Vector3.new(math.cos(angle) * dist, y, math.sin(angle) * dist)
	part.Parent = enemiesFolderRef

	local hp = gameConfig.EnemyBaseHealth
	if isElite then
		local mul = eliteHealthMul
		if type(mul) ~= "number" or mul <= 0 then
			mul = 1.5
		end
		hp *= mul
	end

	table.insert(enemyEntriesRef, {
		part = part,
		state = {
			health = hp,
			spawnY = y,
			isElite = isElite == true,
			tier = (isElite == true) and EnemyTier.Elite or EnemyTier.Basic,
		},
	})
end

function EnemyService.spawnBoss(gameConfig)
	if not enemyEntriesRef or not enemiesFolderRef then
		return nil
	end

	local part = Instance.new("Part")
	applyBossPartDefaults(part, gameConfig)

	local angle = math.random() * math.pi * 2
	local dist = gameConfig.EnemySpawnRadiusMin
		+ math.random() * (gameConfig.EnemySpawnRadiusMax - gameConfig.EnemySpawnRadiusMin)
	local y = gameConfig.EnemyBossSpawnHeight
	part.Position = spawnWorldOffset
		+ Vector3.new(math.cos(angle) * dist, y, math.sin(angle) * dist)
	part.Parent = enemiesFolderRef

	table.insert(enemyEntriesRef, {
		part = part,
		state = {
			health = gameConfig.EnemyBaseHealth * gameConfig.EnemyBossHealthMultiplier,
			isBoss = true,
			spawnY = y,
			tier = EnemyTier.Boss,
		},
	})

	return part
end

function EnemyService.clearAllEnemies()
	if not enemyEntriesRef then
		return
	end

	for i = #enemyEntriesRef, 1, -1 do
		local e = enemyEntriesRef[i]
		if e.part and e.part.Parent then
			e.part:Destroy()
		end
		table.remove(enemyEntriesRef, i)
	end
end

function EnemyService.init(players, runService, gameConfig)
	pcall(function()
		PhysicsService:RegisterCollisionGroup("Enemy")
	end)

	local folder = Workspace:FindFirstChild("Enemies")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Enemies"
		folder.Parent = Workspace
	end

	enemiesFolderRef = folder

	local enemies = {}
	enemyEntriesRef = enemies

	local function nearestRootPosition(fromPos)
		local bestPos = nil
		local bestDist = math.huge

		for _, player in players:GetPlayers() do
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if root then
				local d = (root.Position - fromPos).Magnitude
				if d < bestDist then
					bestDist = d
					bestPos = root.Position
				end
			end
		end

		return bestPos
	end

	runService.Heartbeat:Connect(function(dt)
		local speed = gameConfig.EnemyBaseSpeed
		local usePhysics = gameConfig.EnemyPartCanCollide

		for i = #enemies, 1, -1 do
			local entry = enemies[i]
			local part = entry.part
			if not part.Parent then
				table.remove(enemies, i)
			else
				local target = nearestRootPosition(part.Position)
				if target then
					local delta = target - part.Position
					if usePhysics and not part.Anchored then
						local flat = Vector3.new(delta.X, 0, delta.Z)
						local spawnY = (entry.state and entry.state.spawnY) or part.Position.Y
						if flat.Magnitude > 0.5 then
							local dir = flat.Unit
							part.AssemblyLinearVelocity = Vector3.new(dir.X * speed, 0, dir.Z * speed)
						else
							part.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
						end
						part.AssemblyAngularVelocity = Vector3.zero
						local p = part.Position
						part.Position = Vector3.new(p.X, spawnY, p.Z)
					else
						if delta.Magnitude > 0.5 then
							local move = delta.Unit * speed * dt
							if move.Magnitude > delta.Magnitude then
								move = delta
							end
							part.Position = part.Position + move
						end
					end
				end
			end
		end
	end)
end

return EnemyService

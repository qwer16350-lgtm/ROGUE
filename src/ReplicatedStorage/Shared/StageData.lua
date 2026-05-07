local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapConfig = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("MapConfig")
)

local Stages = {
	{
		SpawnPartName = "Spawn_1",
		OriginPartName = "Origin_1",
		Biome = "Grassland",
		MarkerRootName = "Grassland",
	},
	{
		SpawnPartName = "Spawn_2",
		OriginPartName = "Origin_2",
		Biome = "Desert",
		MarkerRootName = "Desert",
		GruntIntervalStart = 1.2,
		GruntIntervalEnd = 0.55,
		EliteGruntEnabled = true,
		EliteGruntHealthMultiplier = 1.5,
		EliteGruntSpawnIntervalMul = 10,
	},
}

local function findPart(folderName, partName)
	if type(partName) ~= "string" or partName == "" then
		return nil
	end
	local folder = Workspace:FindFirstChild(folderName)
	if not folder then
		return nil
	end
	local p = folder:FindFirstChild(partName)
	if p and p:IsA("BasePart") then
		return p
	end
	return nil
end

local function defaultSpawnCFrame(index)
	return CFrame.new(0, 5, (index - 1) * 200)
end

local function defaultOrigin(index)
	return Vector3.new(0, 0, (index - 1) * 200)
end

local StageData = {}

function StageData.getStageCount()
	return #Stages
end

function StageData.getRow(stageIndex)
	local i = math.clamp(stageIndex, 1, #Stages)
	return Stages[i], i
end

function StageData.getBiomeName(stageIndex)
	local row = select(1, StageData.getRow(stageIndex))
	if type(row.Biome) == "string" and row.Biome ~= "" then
		return row.Biome
	end
	return MapConfig.DefaultBiome
end

function StageData.getMarkerRootName(stageIndex)
	local row = select(1, StageData.getRow(stageIndex))
	if type(row.MarkerRootName) == "string" and row.MarkerRootName ~= "" then
		return row.MarkerRootName
	end
	return StageData.getBiomeName(stageIndex)
end

function StageData.getPlayerSpawnCFrame(gameConfig, stageIndex)
	local row, idx = StageData.getRow(stageIndex)
	local p = findPart("StageSpawns", row.SpawnPartName)
	if p then
		return p.CFrame
	end
	return defaultSpawnCFrame(idx)
end

function StageData.getEnemySpawnOrigin(gameConfig, stageIndex)
	local row, idx = StageData.getRow(stageIndex)
	local p = findPart("StageOrigins", row.OriginPartName)
	if p then
		return p.Position
	end
	return defaultOrigin(idx)
end

function StageData.getSessionDurationSeconds(gameConfig, stageIndex)
	local row = select(1, StageData.getRow(stageIndex))
	if type(row.SessionDurationSeconds) == "number" and row.SessionDurationSeconds > 0 then
		return row.SessionDurationSeconds
	end
	return gameConfig.SessionDurationSeconds
end

function StageData.getSpawnProfile(gameConfig, stageIndex)
	local row = select(1, StageData.getRow(stageIndex))
	local gruntStart = gameConfig.WaveGruntSpawnIntervalStart
	local gruntEnd = gameConfig.WaveGruntSpawnIntervalEnd
	if type(row.GruntIntervalStart) == "number" and row.GruntIntervalStart > 0 then
		gruntStart = row.GruntIntervalStart
	end
	if type(row.GruntIntervalEnd) == "number" and row.GruntIntervalEnd > 0 then
		gruntEnd = row.GruntIntervalEnd
	end

	local eliteEnabled = row.EliteGruntEnabled == true
	local eliteHpMul = 1.5
	if type(row.EliteGruntHealthMultiplier) == "number" and row.EliteGruntHealthMultiplier > 0 then
		eliteHpMul = row.EliteGruntHealthMultiplier
	end
	local eliteIntervalMul = 10
	if type(row.EliteGruntSpawnIntervalMul) == "number" and row.EliteGruntSpawnIntervalMul > 0 then
		eliteIntervalMul = row.EliteGruntSpawnIntervalMul
	end

	return {
		GruntIntervalStart = gruntStart,
		GruntIntervalEnd = gruntEnd,
		EliteGruntEnabled = eliteEnabled,
		EliteGruntHealthMultiplier = eliteHpMul,
		EliteGruntSpawnIntervalMul = eliteIntervalMul,
	}
end

return StageData
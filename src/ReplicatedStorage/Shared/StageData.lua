local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapConfig = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("MapConfig")
)

-- 축 구분 (중요):
--   Biome          = 자산 소속. ServerStorage.MapAssets.Biomes.<Biome> 의 타일/경계 풀과
--                    BiomeRegistry 의 RuntimeNames(Open/Bottleneck/Boundary) 를 결정.
--                    여러 stage 가 같은 biome 을 공유해도 된다.
--   MarkerRootName = stage 좌표 소속. Workspace.Map.RuntimeMarkers.<MarkerRootName>
--                    하위에 놓인 Marker_Tile_* 좌표 집합을 결정. stage 마다 고유.
-- 두 값은 직교한다. 같은 규칙(biome) × 분리된 좌표(marker root) 구조.
-- 아래 각 row 는 두 필드를 모두 명시하는 것이 기준이다.
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
		-- 테스트: 1층보다 그런트 간격 곡선만 다르게 (램프는 GameConfig 그대로)
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

--- Biome 축 (자산 소속) 해석.
--- row.Biome 이 비빈 문자열이면 그것을 사용.
--- TODO(temp-fallback): 모든 stage row 가 Biome 을 명시하면 아래 폴백 라인은 제거한다.
--- 이 폴백은 임시 호환 장치일 뿐 장기 구조로 간주하지 말 것.
function StageData.getBiomeName(stageIndex)
	local row = select(1, StageData.getRow(stageIndex))
	if type(row.Biome) == "string" and row.Biome ~= "" then
		return row.Biome
	end
	return MapConfig.DefaultBiome
end

--- MarkerRootName 축 (stage 좌표 소속) 해석.
--- row.MarkerRootName 이 비빈 문자열이면 그것을 사용.
--- TODO(temp-fallback): 모든 stage row 가 MarkerRootName 을 명시하면 아래 폴백 라인은 제거한다.
--- 임시 호환 장치 — biome 이름을 좌표 루트로 간주하던 구 커플링을 유지할 뿐 장기 구조가 아니다.
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

--- 층별 스폰에 쓸 값만 명시적으로 채운다. (범용 merge 유틸 아님)
--- 램프는 WaveService가 GameConfig 그대로 사용.
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

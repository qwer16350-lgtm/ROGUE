--- StageBootstrap — StagePlace 단일 부팅 ModuleScript.
--- MainServer 가 PlaceId 분기에서 한 번 require 후 init(deps) 만 호출.
---
--- 책임:
---   1) RunContext.initFromTeleportData(players)
---   2) StageFlow.init(...) — Remotes.StageFlowRequest 바인딩
---   3) MapService.GenerateMap(currentFloor)
---   4) 멤버 LoadCharacter 직후 StageData.getPlayerSpawnCFrame 으로 HRP 정렬
---   5) WaveService.startSession(currentFloor)
---
--- Run 도메인 sibling 모듈 (RunContext / Teleport / StageFlow) 은 직접 require.
--- 게임 도메인 의존성 (mapService / waveService) 은 deps 로 주입 — 테스트 / 분리 부팅 가능성을 위해.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StageData = require(Shared:WaitForChild("StageData"))

local RunContext = require(script.Parent:WaitForChild("RunContext"))
local Teleport = require(script.Parent:WaitForChild("Teleport"))
local StageFlow = require(script.Parent:WaitForChild("StageFlow"))

local StageBootstrap = {}

--- LoadCharacter 시 엔진이 SpawnLocation 을 후보로 쓰므로 스테이지에서는 전부 끈다.
local function disableWorkspaceSpawnLocations()
	for _, inst in ipairs(Workspace:GetDescendants()) do
		if inst:IsA("SpawnLocation") then
			inst.Enabled = false
		end
	end
end

--- deps = {
---   players          : Players service,
---   stageFlowRequest : Remotes.StageFlowRequest RemoteEvent,
---   mapService       : require("Map/MapService"),
---   waveService      : require("WaveService"),
---   gameConfig       : require("Shared/GameConfig") 반환 테이블,
--- }
function StageBootstrap.init(deps)
	assert(deps, "[StageBootstrap] deps required")
	assert(deps.players, "[StageBootstrap] deps.players required")
	assert(deps.stageFlowRequest, "[StageBootstrap] deps.stageFlowRequest required")
	assert(deps.mapService, "[StageBootstrap] deps.mapService required")
	assert(deps.waveService, "[StageBootstrap] deps.waveService required")
	assert(deps.gameConfig, "[StageBootstrap] deps.gameConfig required")

	RunContext.initFromTeleportData(deps.players)

	StageFlow.init({
		players = deps.players,
		stageFlowRequest = deps.stageFlowRequest,
		runContext = RunContext,
		teleport = Teleport,
	})

	-- StageFlow.init 이후에 bind: WaveService.finishSession 시 outcome 을 StageFlow 가
	-- 받아 자동 lobby 귀환 / 다음 층 대기 흐름을 결정한다.
	deps.waveService.bindStageFlow(StageFlow)

	local floor = RunContext.getCurrentFloor()
	deps.mapService.GenerateMap(floor)
	disableWorkspaceSpawnLocations()

	-- ⚠ MainServer Stage branch 가 CharacterAutoLoads=false 로 차단해두므로,
	--   맵 생성 직후 명시적으로 캐릭터를 로드한다. (솔로 MVP: members[1] 만 로드되지만
	--   loop 형태로 두어 Party 확장 시 그대로 동작.)
	local gc = deps.gameConfig
	local spawnCf = StageData.getPlayerSpawnCFrame(gc, floor)
	for _, p in ipairs(RunContext.getMembers()) do
		p:LoadCharacter()
		local character = p.Character or p.CharacterAdded:Wait()
		local hrp = character:WaitForChild("HumanoidRootPart", 10)
		if hrp and hrp:IsA("BasePart") then
			RunService.Heartbeat:Wait()
			hrp.AssemblyLinearVelocity = Vector3.zero
			local av = hrp.AssemblyAngularVelocity
			if typeof(av) == "Vector3" then
				hrp.AssemblyAngularVelocity = Vector3.zero
			end
			hrp.CFrame = spawnCf
			task.defer(function()
				if hrp.Parent and hrp:IsA("BasePart") then
					hrp.AssemblyLinearVelocity = Vector3.zero
					local av2 = hrp.AssemblyAngularVelocity
					if typeof(av2) == "Vector3" then
						hrp.AssemblyAngularVelocity = Vector3.zero
					end
					hrp.CFrame = spawnCf
				end
			end)
		end
	end

	deps.waveService.startSession(floor)
end

return StageBootstrap

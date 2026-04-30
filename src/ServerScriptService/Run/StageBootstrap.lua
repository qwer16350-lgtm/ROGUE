--- StageBootstrap — StagePlace 단일 부팅 ModuleScript.
--- MainServer 가 PlaceId 분기에서 한 번 require 후 init(deps) 만 호출.
---
--- 책임:
---   1) RunContext.initFromTeleportData(players)
---   2) StageFlow.init(...) — Remotes.StageFlowRequest 바인딩
---   3) MapService.GenerateMap(currentFloor)
---   4) WaveService.startSession(currentFloor)
---
--- Run 도메인 sibling 모듈 (RunContext / Teleport / StageFlow) 은 직접 require.
--- 게임 도메인 의존성 (mapService / waveService) 은 deps 로 주입 — 테스트 / 분리 부팅 가능성을 위해.

local ServerScriptService = game:GetService("ServerScriptService")

local RunContext = require(script.Parent:WaitForChild("RunContext"))
local Teleport = require(script.Parent:WaitForChild("Teleport"))
local StageFlow = require(script.Parent:WaitForChild("StageFlow"))

local StageBootstrap = {}

--- deps = {
---   players          : Players service,
---   stageFlowRequest : Remotes.StageFlowRequest RemoteEvent,
---   mapService       : require("Map/MapService"),
---   waveService      : require("WaveService"),
--- }
function StageBootstrap.init(deps)
	assert(deps, "[StageBootstrap] deps required")
	assert(deps.players, "[StageBootstrap] deps.players required")
	assert(deps.stageFlowRequest, "[StageBootstrap] deps.stageFlowRequest required")
	assert(deps.mapService, "[StageBootstrap] deps.mapService required")
	assert(deps.waveService, "[StageBootstrap] deps.waveService required")

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

	-- ⚠ MainServer Stage branch 가 CharacterAutoLoads=false 로 차단해두므로,
	--   맵 생성 직후 명시적으로 캐릭터를 로드한다. (솔로 MVP: members[1] 만 로드되지만
	--   loop 형태로 두어 Party 확장 시 그대로 동작.)
	for _, p in ipairs(RunContext.getMembers()) do
		p:LoadCharacter()
	end

	deps.waveService.startSession(floor)
end

return StageBootstrap

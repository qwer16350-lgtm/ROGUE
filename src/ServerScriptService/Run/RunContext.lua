--- RunContext — StagePlace 단일 인스턴스 데이터홀더.
--- "이 서버는 누구의 몇 층 run 인가?" 만 보관한다. 텔레포트 / 맵 / 게임 도메인 호출 없음.
--- 외부 모듈(StageFlow, StageBootstrap, WaveService) 은 모두 getter 만 호출 — Party 확장 시
--- initFromTeleportData 한 곳을 교체하면 다른 모듈은 변경 없이 재사용된다.

local Players = game:GetService("Players") -- 타입 참조 / API 확인용. 실제 인스턴스는 deps 로 주입.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunConstants = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Run"):WaitForChild("RunConstants")
)

local RunContext = {}

local state = {
	initialized = false,
	runId = nil,
	partyId = nil,
	mode = nil,
	towerId = nil,
	currentFloor = nil,
	maxFloor = nil,
	lobbyPlaceId = nil,
	stagePlaceId = nil,
	members = {}, -- { Player } — solo MVP 에서는 1명, host = members[1]
}

local function readTeleportData(player)
	local ok, joinData = pcall(function()
		return player:GetJoinData()
	end)
	if ok and type(joinData) == "table" and type(joinData.TeleportData) == "table" then
		return joinData.TeleportData
	end
	return nil
end

local function applyFromTd(td)
	local k = RunConstants.TeleportKeys
	state.runId = td[k.RunId] or HttpService:GenerateGUID(false)
	state.partyId = td[k.PartyId]
	state.mode = td[k.Mode] or RunConstants.Mode.Solo
	state.towerId = td[k.TowerId] or RunConstants.TowerIdDefault
	state.currentFloor = td[k.CurrentFloor] or 1
	state.maxFloor = td[k.MaxFloor] or RunConstants.MaxFloor
	state.lobbyPlaceId = td[k.LobbyPlaceId] or RunConstants.LobbyPlaceId
	state.stagePlaceId = td[k.StagePlaceId] or RunConstants.StagePlaceId
end

local function applyDefaults()
	state.runId = HttpService:GenerateGUID(false)
	state.partyId = nil
	state.mode = RunConstants.Mode.Solo
	state.towerId = RunConstants.TowerIdDefault
	state.currentFloor = 1
	state.maxFloor = RunConstants.MaxFloor
	state.lobbyPlaceId = RunConstants.LobbyPlaceId
	state.stagePlaceId = RunConstants.StagePlaceId
end

--- StagePlace 의 reserved server 부팅 시 1회 호출.
---
--- ⚠ 솔로 MVP 임시 구조 — Party 도입 전 한정 동작:
---   * StagePlace 의 reserved server 가 한 명의 솔로 플레이어를 위해 만들어진다고 가정.
---   * 첫 join 한 플레이어 1명의 GetJoinData().TeleportData 만 읽어 단일 RunContext 를 채운다.
---   * 그 외 후속 join 은 무시 (members 에 추가 안 함). LobbyPlace 가 한 명만 텔레포트한다는 전제.
---   * Studio Play / 직접 join (TeleportData 없음) 시 폴백: runId=GUID, mode=Solo,
---     currentFloor=1, 나머지는 RunConstants 기본값.
---
--- ⚠ 호출자 제약:
---   * 이 함수는 yield 가능 (`Players.PlayerAdded:Wait()` 가능).
---   * 호출 전에 `Players.CharacterAutoLoads = false` 로 차단해두는 것이 안전 — 그렇지 않으면
---     맵 생성 전에 첫 플레이어가 빈 공간으로 떨어질 수 있음 (Step 4 MainServer 책임).
---
--- Party 확장 시 교체 지점 — 이 함수 본문만 교체하면 됨:
---   * members 다인원 수집 (host 선정 정책: members[1] = host 등).
---   * teleport data 의 어떤 필드를 누구의 join 으로 읽을지 (host only vs first-arrival 등).
---   * 모든 멤버 join 대기 (timeout / 부분 도착 보호).
---   * 이 모듈 외부 (StageFlow / StageBootstrap / WaveService 등) 는 getter 만 쓰므로 영향 없음.
function RunContext.initFromTeleportData(playersService)
	if state.initialized then
		return
	end

	local firstPlayer = playersService:GetPlayers()[1]
	if not firstPlayer then
		firstPlayer = playersService.PlayerAdded:Wait()
	end

	local td = readTeleportData(firstPlayer)
	if td then
		applyFromTd(td)
	else
		applyDefaults()
	end

	table.insert(state.members, firstPlayer)
	state.initialized = true
end

function RunContext.isInitialized()
	return state.initialized
end

function RunContext.getCurrentFloor()
	return state.currentFloor or 1
end

function RunContext.getMaxFloor()
	return state.maxFloor or RunConstants.MaxFloor
end

function RunContext.getMode()
	return state.mode or RunConstants.Mode.Solo
end

function RunContext.getTowerId()
	return state.towerId or RunConstants.TowerIdDefault
end

function RunContext.getRunId()
	return state.runId
end

function RunContext.getPartyId()
	return state.partyId
end

function RunContext.getLobbyPlaceId()
	return state.lobbyPlaceId or RunConstants.LobbyPlaceId
end

function RunContext.getStagePlaceId()
	return state.stagePlaceId or RunConstants.StagePlaceId
end

function RunContext.getMembers()
	return state.members
end

return RunContext

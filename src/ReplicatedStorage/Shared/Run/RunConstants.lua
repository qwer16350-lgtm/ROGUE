--- RunConstants — 단순 값 모듈, 함수/상태 없음.
--- Run / Lobby / Stage 시스템의 단일 진실 소스(SRC OF TRUTH) 로서, 다른 모든
--- Run 관련 모듈(이후 Step 들에서 추가될 RunContext / Teleport / StageFlow /
--- StageBootstrap / LobbyEntry / LobbyBootstrap) 이 require 해서 PlaceId·MaxFloor·
--- teleport key·outcome·action enum 을 조회한다.
---
--- 사용 예:
---     local RunConstants = require(ReplicatedStorage.Shared.Run.RunConstants)
---     if game.PlaceId == RunConstants.LobbyPlaceId then ...
---     local floor = teleportData[RunConstants.TeleportKeys.CurrentFloor]
---
--- LobbyPlaceId / StagePlaceId:
---   publish 후 실 PlaceId 로 사용자가 직접 갱신해야 한다. 0 인 동안에는
---   MainServer 의 PlaceId 분기에서 어느 쪽도 매칭되지 않아, MainServer 가
---   "알 수 없는 PlaceId" 의 안전한 테스트 폴백 분기를 타게 된다.

local RunConstants = {}

------------------------------------------------------------
-- Place identifiers (publish 후 실 PlaceId 로 갱신)
------------------------------------------------------------
RunConstants.LobbyPlaceId = 115533709219984
RunConstants.StagePlaceId = 84494361661192

------------------------------------------------------------
-- Floor / tower defaults
------------------------------------------------------------
RunConstants.MaxFloor = 5
RunConstants.TowerIdDefault = "Default"

------------------------------------------------------------
-- Run mode
-- Solo MVP — Party 는 자리만. RunContext / Teleport 가 분기 가능하도록 enum 노출.
------------------------------------------------------------
RunConstants.Mode = {
	Solo = "Solo",
	Party = "Party",
}

------------------------------------------------------------
-- Teleport data keys
-- TeleportService teleport data 테이블의 키를 한 곳에서 관리.
-- 직렬화/역직렬화는 항상 이 enum 의 문자열로 한다.
------------------------------------------------------------
RunConstants.TeleportKeys = {
	RunId        = "RunId",
	PartyId      = "PartyId",
	Mode         = "Mode",
	TowerId      = "TowerId",
	CurrentFloor = "CurrentFloor",
	MaxFloor     = "MaxFloor",
	LobbyPlaceId = "LobbyPlaceId",
	StagePlaceId = "StagePlaceId",
}

------------------------------------------------------------
-- Stage outcome enum
-- WaveService 가 finishSession 시 Result payload 의 Outcome 필드로 사용.
-- ResultClient / StageFlow 도 이 enum 으로 분기.
------------------------------------------------------------
RunConstants.Outcome = {
	Clear = "Clear",
	Fail  = "Fail",
}

------------------------------------------------------------
-- StageFlowRequest action enum
-- ResultClient 가 Remotes.StageFlowRequest:FireServer({ Action = ... }) 로 보내고
-- StageFlow 가 처리한다. 본 enum 의 두 값만 허용 — 그 외 키는 StageFlow.onRequest 에서
-- warn 후 무시.
------------------------------------------------------------
RunConstants.StageFlowAction = {
	NextFloor     = "NextFloor",
	ReturnToLobby = "ReturnToLobby",
}

return RunConstants

--- PartyService — Party 확장 지점 stub. Solo MVP 단계에서는 항상 단일 플레이어 / Solo 모드.
---
--- ⚠ Solo MVP 임시 구현 — 본 단계에서는 의도적으로 stub 만 유지:
---   * getMembersFor(player) 하나만 export.
---   * party UI / 초대 / 큐 / 멤버 동기화 / 멤버 도착 대기 / 부분 도달 / 타임아웃 정책
---     일체 구현하지 않는다. 향후 Party 단계에서 본 모듈 내부만 교체.
---
--- ⚠ 호출 시그니처 안정성 약속:
---   * 본 모듈의 public API 시그니처는 Party 도입 후에도 보존된다.
---   * LobbyBootstrap 은 본 함수의 반환값(members table + mode string) 만 의존.
---   * 향후 확장 시:
---       - 같은 파티 멤버 lookup (PartyMembership 테이블 / 외부 데이터).
---       - mode = RunConstants.Mode.Party 분기.
---       - 멤버 도착 / 타임아웃 정책.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local RunConstants = require(Shared:WaitForChild("Run"):WaitForChild("RunConstants"))

local PartyService = {}

--- 입장 트리거 플레이어 기준으로 텔레포트 대상 멤버 / 모드를 산출.
--- @return members table — 항상 numeric-indexed array. solo 에서는 { player }.
--- @return mode string  — RunConstants.Mode 의 값. solo 에서는 RunConstants.Mode.Solo.
function PartyService.getMembersFor(player)
	return { player }, RunConstants.Mode.Solo
end

return PartyService

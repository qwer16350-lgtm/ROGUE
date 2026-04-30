--- LobbyBootstrap — LobbyPlace 단일 부팅 ModuleScript.
--- MainServer 가 PlaceId 분기에서 한 번 require 후 init(deps) 만 호출.
---
--- 책임:
---   1) CollectionService 태그 `LobbyEntryPad` 가 붙은 Workspace 인스턴스를 찾아,
---      그 후손 ProximityPrompt.Triggered 를 입장 트리거로 연결.
---   2) Remotes.LobbyEnterRequest.OnServerEvent 도 같은 입장 핸들러로 연결 (UI/스크립트 트리거 대안).
---   3) 입장 트리거 시 Teleport.toFirstFloor(player) 호출.
---   4) 플레이어 단위 debounce — 더블 트리거 / 텔레포트 진행 중 재호출 방지.
---
--- ⚠ 패드 / 프롬프트 코드 생성 절대 금지 — Studio 에 사용자가 배치한 약속된 오브젝트만 연결.
---
--- 패드 명세 (Studio 에서 사용자가 따르는 약속):
---   * CollectionService 태그: "LobbyEntryPad"
---   * 태그된 인스턴스 자체 또는 후손 어딘가에 ProximityPrompt 1개 이상 존재.
---   * 첫 번째 발견된 ProximityPrompt 의 Triggered 를 입장 트리거로 사용.
---   * ProximityPrompt 가 없으면 해당 인스턴스는 warn 후 skip.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RunConstants = require(Shared:WaitForChild("Run"):WaitForChild("RunConstants"))
local PartyService = require(script.Parent:WaitForChild("PartyService"))

local LobbyBootstrap = {}

------------------------------------------------------------
-- Tunables
------------------------------------------------------------
local ENTRY_PAD_TAG = "LobbyEntryPad"
--- 같은 플레이어가 더블 트리거 / 텔레포트 진행 중 재호출 시 차단할 시간(초).
local PER_PLAYER_DEBOUNCE_SECONDS = 5

------------------------------------------------------------
-- State
------------------------------------------------------------
local ctx = {
	players = nil,
	lobbyEnterRequest = nil,
	teleport = nil,
}

--- 플레이어 UserId → 마지막 트리거 tick. 전역 debounce 가 아니라 플레이어 별 독립.
--- weak key 가 아니라 UserId(number) 기준이므로 PlayerRemoving 시 명시 정리 필요.
local lastTriggerByUserId = {}

------------------------------------------------------------
-- Helpers
------------------------------------------------------------
local function findFirstProximityPrompt(instance)
	if instance:IsA("ProximityPrompt") then
		return instance
	end
	for _, d in ipairs(instance:GetDescendants()) do
		if d:IsA("ProximityPrompt") then
			return d
		end
	end
	return nil
end

local function tryEnter(player)
	if not player or not player.Parent then
		return
	end
	local now = tick()
	local last = lastTriggerByUserId[player.UserId]
	if last and (now - last) < PER_PLAYER_DEBOUNCE_SECONDS then
		return
	end
	lastTriggerByUserId[player.UserId] = now

	--- PartyService 반환값 최소 방어 — Party stub 교체 시점의 안전망.
	---   * members 가 table 이 아니거나 비어 있으면 entry abort + warn + debounce 해제.
	---   * mode 가 nil 이면 Solo 폴백 (Teleport 가 td 의 Mode 키를 그대로 받음).
	local members, mode = PartyService.getMembersFor(player)
	if type(members) ~= "table" or #members == 0 then
		warn(string.format(
			"[LobbyBootstrap] PartyService.getMembersFor returned invalid members for %s — entry aborted",
			player.Name
		))
		lastTriggerByUserId[player.UserId] = nil
		return
	end
	if mode == nil then
		mode = RunConstants.Mode.Solo
	end

	local ok = ctx.teleport.toFirstFloor(members, { mode = mode })
	if not ok then
		warn(string.format("[LobbyBootstrap] toFirstFloor failed for %s", player.Name))
		--- 텔레포트가 실패했으면 사용자가 다시 시도할 수 있도록 debounce 즉시 해제.
		lastTriggerByUserId[player.UserId] = nil
	end
end

local function connectPad(instance)
	local prompt = findFirstProximityPrompt(instance)
	if not prompt then
		warn(string.format(
			"[LobbyBootstrap] tagged %q has no ProximityPrompt descendant: %s",
			ENTRY_PAD_TAG, instance:GetFullName()
		))
		return
	end
	prompt.Triggered:Connect(function(player)
		tryEnter(player)
	end)
end

------------------------------------------------------------
-- Public API
------------------------------------------------------------
function LobbyBootstrap.init(deps)
	assert(deps, "[LobbyBootstrap] deps required")
	assert(deps.players, "[LobbyBootstrap] deps.players required")
	assert(deps.lobbyEnterRequest, "[LobbyBootstrap] deps.lobbyEnterRequest required")
	assert(deps.teleport, "[LobbyBootstrap] deps.teleport required")

	ctx.players = deps.players
	ctx.lobbyEnterRequest = deps.lobbyEnterRequest
	ctx.teleport = deps.teleport

	-- 1) 이미 태그된 패드 연결.
	local existing = CollectionService:GetTagged(ENTRY_PAD_TAG)
	for _, inst in ipairs(existing) do
		connectPad(inst)
	end
	if #existing == 0 then
		warn(string.format(
			"[LobbyBootstrap] no instances tagged %q found at boot. " ..
			"Studio 에서 입장 패드에 태그를 추가하면 동적 연결됨.",
			ENTRY_PAD_TAG
		))
	end

	-- 2) 동적으로 추가되는 패드 연결 (Studio 후속 배치 / 런타임 추가).
	CollectionService:GetInstanceAddedSignal(ENTRY_PAD_TAG):Connect(function(inst)
		connectPad(inst)
	end)

	-- 3) UI / 스크립트 트리거 대안 — Remotes.LobbyEnterRequest.
	ctx.lobbyEnterRequest.OnServerEvent:Connect(function(player)
		tryEnter(player)
	end)

	-- 4) 디바운스 정리.
	ctx.players.PlayerRemoving:Connect(function(player)
		lastTriggerByUserId[player.UserId] = nil
	end)
end

return LobbyBootstrap

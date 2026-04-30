--- StageFlow — Remotes.StageFlowRequest 단일 처리 + WaveService 의 finishSession 후속 처리.
--- WaveService 바깥에서 floor 간 흐름(다음 층 / 로비 귀환 / 자동 귀환) 을 담당하는 상위 orchestration.
---
--- 책임 외 (안 함): 텔레포트 직접 호출(Teleport 모듈 위임), GUI(ResultClient), enemy/맵 정리.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunConstants = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Run"):WaitForChild("RunConstants")
)

local StageFlow = {}

------------------------------------------------------------
-- Tunables (모듈 상단 상수 — 다른 곳에 흩어두지 않음)
------------------------------------------------------------
--- 자동 lobby 귀환 발동까지의 지연(초). Fail / 마지막 층 클리어 시.
--- ResultClient 가 결과창을 표시하는 시간을 고려해 조정. 너무 짧으면 결과창이 거의 보이지 않음.
local AUTO_RETURN_DELAY_SECONDS = 4

------------------------------------------------------------
-- State
------------------------------------------------------------
local ctx = {
	players = nil,
	stageFlowRequest = nil,
	runContext = nil,
	teleport = nil,
}

local sessionState = {
	finished = false,
	outcome = nil, -- "Clear" | "Fail" (RunConstants.Outcome)
	autoReturnDispatched = false,
}

------------------------------------------------------------
-- Helpers
------------------------------------------------------------
--- 표준 StageFlowAction 키만 허용. 그 외 nil.
local function normalizeAction(action)
	if type(action) ~= "string" then
		return nil
	end
	if RunConstants.StageFlowAction[action] then
		return action
	end
	return nil
end

local function dispatchAutoReturnIfNeeded()
	if sessionState.autoReturnDispatched then
		return
	end
	local autoReturn = false
	if sessionState.outcome == RunConstants.Outcome.Fail then
		autoReturn = true
	elseif
		sessionState.outcome == RunConstants.Outcome.Clear
		and ctx.runContext.getCurrentFloor() >= ctx.runContext.getMaxFloor()
	then
		autoReturn = true
	end
	if not autoReturn then
		return
	end
	sessionState.autoReturnDispatched = true
	task.delay(AUTO_RETURN_DELAY_SECONDS, function()
		ctx.teleport.toLobby(ctx.runContext.getMembers(), ctx.runContext)
	end)
end

------------------------------------------------------------
-- Action handlers
------------------------------------------------------------
local function handleNextFloor(_player)
	if not sessionState.finished or sessionState.outcome ~= RunConstants.Outcome.Clear then
		warn("[StageFlow] NextFloor rejected: session not in cleared state")
		return
	end
	local cur = ctx.runContext.getCurrentFloor()
	local mx = ctx.runContext.getMaxFloor()
	if cur >= mx then
		warn("[StageFlow] NextFloor rejected: already at last floor")
		return
	end
	local ok = ctx.teleport.toFloor(ctx.runContext.getMembers(), ctx.runContext, cur + 1)
	if not ok then
		warn("[StageFlow] NextFloor: teleport failed")
	end
end

local function handleReturnToLobby(_player)
	local ok = ctx.teleport.toLobby(ctx.runContext.getMembers(), ctx.runContext)
	if not ok then
		warn("[StageFlow] ReturnToLobby: teleport failed")
	end
end

local function onRequest(player, payload)
	if type(payload) ~= "table" then
		return
	end
	local action = normalizeAction(payload.Action)
	if action == RunConstants.StageFlowAction.NextFloor then
		handleNextFloor(player)
	elseif action == RunConstants.StageFlowAction.ReturnToLobby then
		handleReturnToLobby(player)
	else
		warn(string.format(
			"[StageFlow] Unknown StageFlowRequest Action=%s from %s",
			tostring(payload.Action),
			(player and player.Name) or "<nil>"
		))
	end
end

------------------------------------------------------------
-- Public API
------------------------------------------------------------
--- WaveService 가 finishSession 직후 호출.
--- outcome 은 RunConstants.Outcome 의 값 ("Clear" | "Fail").
--- 자동 lobby 귀환 조건:
---   * Fail → 항상 자동
---   * Clear AND currentFloor == maxFloor → 자동
--- Clear AND not last floor → 자동 안 함, ResultClient 의 NextFloor / ReturnToLobby 입력 대기.
function StageFlow.onSessionFinished(outcome)
	sessionState.finished = true
	sessionState.outcome = outcome
	dispatchAutoReturnIfNeeded()
end

function StageFlow.init(deps)
	ctx.players = deps.players
	ctx.stageFlowRequest = deps.stageFlowRequest
	ctx.runContext = deps.runContext
	ctx.teleport = deps.teleport

	ctx.stageFlowRequest.OnServerEvent:Connect(onRequest)
end

return StageFlow

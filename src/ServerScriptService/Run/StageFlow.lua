---

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunConstants = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Run"):WaitForChild("RunConstants")
)

local StageFlow = {}

------------------------------------------------------------
------------------------------------------------------------
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
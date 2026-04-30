--- Teleport — TeleportService 어댑터. TeleportService 직접 호출은 이 모듈 밖에서 하지 않는다.
--- toFirstFloor (Lobby→1층 신규 run), toFloor (Stage→다음 층), toLobby (어디서든 → Lobby) 3개.
--- 모든 외부 호출은 pcall 가드 + warn + bool 반환. PlaceId 가 0 이면 즉시 false (publish 전 안전).

local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunConstants = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Run"):WaitForChild("RunConstants")
)

local Teleport = {}

--- 단일 / 배열 인자를 항상 배열로 정규화.
local function asArray(playerOrPlayers)
	if type(playerOrPlayers) ~= "table" then
		return { playerOrPlayers }
	end
	-- numeric-indexed 배열로 가정 (Players:GetPlayers() 결과 또는 명시 배열)
	if #playerOrPlayers > 0 then
		return playerOrPlayers
	end
	-- 빈 테이블이거나 dictionary — 안전 폴백
	return playerOrPlayers
end

--- TeleportData 직렬화. 키 문자열은 RunConstants.TeleportKeys 단일 소스.
local function buildTeleportData(args)
	local k = RunConstants.TeleportKeys
	return {
		[k.RunId] = args.runId,
		[k.PartyId] = args.partyId,
		[k.Mode] = args.mode,
		[k.TowerId] = args.towerId,
		[k.CurrentFloor] = args.currentFloor,
		[k.MaxFloor] = args.maxFloor,
		[k.LobbyPlaceId] = args.lobbyPlaceId,
		[k.StagePlaceId] = args.stagePlaceId,
	}
end

local function reserveStageServer(stagePlaceId)
	local code, privateServerId
	local ok, err = pcall(function()
		code, privateServerId = TeleportService:ReserveServer(stagePlaceId)
	end)
	if not ok or not code then
		warn("[Teleport] ReserveServer failed:", err)
		return nil
	end
	return code, privateServerId
end

local function teleportAsyncSafe(placeId, players, options)
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(placeId, players, options)
	end)
	if not ok then
		warn("[Teleport] TeleportAsync failed:", err)
		return false
	end
	return true
end

--- Lobby → 1층 reserved server. 신규 run 시작.
--- opts = { mode? = "Solo"/"Party", towerId? = "Default" } — 누락 시 RunConstants 기본값.
function Teleport.toFirstFloor(playerOrPlayers, opts)
	opts = opts or {}
	local players = asArray(playerOrPlayers)

	local stagePlaceId = RunConstants.StagePlaceId
	if type(stagePlaceId) ~= "number" or stagePlaceId <= 0 then
		warn("[Teleport] toFirstFloor: StagePlaceId not configured (publish 후 RunConstants 갱신 필요)")
		return false
	end

	local code = reserveStageServer(stagePlaceId)
	if not code then
		return false
	end

	local td = buildTeleportData({
		runId = HttpService:GenerateGUID(false),
		partyId = nil,
		mode = opts.mode or RunConstants.Mode.Solo,
		towerId = opts.towerId or RunConstants.TowerIdDefault,
		currentFloor = 1,
		maxFloor = RunConstants.MaxFloor,
		lobbyPlaceId = RunConstants.LobbyPlaceId,
		stagePlaceId = stagePlaceId,
	})

	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = code
	options:SetTeleportData(td)

	return teleportAsyncSafe(stagePlaceId, players, options)
end

--- Stage → 다음 층 reserved server. 같은 run 의 다음 floor.
function Teleport.toFloor(playerOrPlayers, runContext, floorIndex)
	if not runContext then
		warn("[Teleport] toFloor: runContext is nil — Stage 호출은 RunContext 가 필수")
		return false
	end
	local players = asArray(playerOrPlayers)

	local stagePlaceId = runContext.getStagePlaceId()
	if type(stagePlaceId) ~= "number" or stagePlaceId <= 0 then
		warn("[Teleport] toFloor: StagePlaceId not configured")
		return false
	end

	local code = reserveStageServer(stagePlaceId)
	if not code then
		return false
	end

	local td = buildTeleportData({
		runId = runContext.getRunId(),
		partyId = runContext.getPartyId(),
		mode = runContext.getMode(),
		towerId = runContext.getTowerId(),
		currentFloor = floorIndex,
		maxFloor = runContext.getMaxFloor(),
		lobbyPlaceId = runContext.getLobbyPlaceId(),
		stagePlaceId = stagePlaceId,
	})

	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = code
	options:SetTeleportData(td)

	return teleportAsyncSafe(stagePlaceId, players, options)
end

--- 어디서든 Lobby 로 복귀 (일반 텔레포트, reserved 아님).
--- runContext 폴백 동작:
---   * runContext == nil 이면 RunConstants.LobbyPlaceId 폴백 + warn 출력.
---     (정상 호출은 Stage 측에서 RunContext 를 보유한 채 사용. Lobby→Lobby 호출은 정상 시나리오 아님.)
---   * runContext 가 있으면 runContext:getLobbyPlaceId() 사용.
function Teleport.toLobby(playerOrPlayers, runContext)
	local players = asArray(playerOrPlayers)

	local lobbyPlaceId
	if runContext then
		lobbyPlaceId = runContext.getLobbyPlaceId()
	else
		warn("[Teleport] toLobby: runContext is nil — RunConstants.LobbyPlaceId 폴백 사용")
		lobbyPlaceId = RunConstants.LobbyPlaceId
	end

	if type(lobbyPlaceId) ~= "number" or lobbyPlaceId <= 0 then
		warn("[Teleport] toLobby: LobbyPlaceId not configured")
		return false
	end

	return teleportAsyncSafe(lobbyPlaceId, players, nil)
end

return Teleport

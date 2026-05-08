
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunConstants = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Run"):WaitForChild("RunConstants")
)

local Teleport = {}

local function asArray(playerOrPlayers)
	if type(playerOrPlayers) ~= "table" then
		return { playerOrPlayers }
	end
	if #playerOrPlayers > 0 then
		return playerOrPlayers
	end
	return playerOrPlayers
end

local function buildTeleportData(args)
	local k = RunConstants.TeleportKeys
	local payload = {
		[k.RunId] = args.runId,
		[k.PartyId] = args.partyId,
		[k.Mode] = args.mode,
		[k.TowerId] = args.towerId,
		[k.CurrentFloor] = args.currentFloor,
		[k.MaxFloor] = args.maxFloor,
		[k.LobbyPlaceId] = args.lobbyPlaceId,
		[k.StagePlaceId] = args.stagePlaceId,
	}
	local startingRelicId = args.startingRelicId
	if type(startingRelicId) == "string" and startingRelicId ~= "" then
		payload[k.StartingRelicId] = startingRelicId
	end
	return payload
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
		startingRelicId = opts.startingRelicId,
	})

	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = code
	options:SetTeleportData(td)

	return teleportAsyncSafe(stagePlaceId, players, options)
end

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
		startingRelicId = runContext.getStartingRelicId and runContext.getStartingRelicId() or nil,
	})

	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = code
	options:SetTeleportData(td)

	return teleportAsyncSafe(stagePlaceId, players, options)
end

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
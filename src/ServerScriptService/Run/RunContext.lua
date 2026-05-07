
local Players = game:GetService("Players")
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
	members = {},
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

---
---
---
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
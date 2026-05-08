---
---     local RunConstants = require(ReplicatedStorage.Shared.Run.RunConstants)
---     if game.PlaceId == RunConstants.LobbyPlaceId then ...
---     local floor = teleportData[RunConstants.TeleportKeys.CurrentFloor]
---
--- LobbyPlaceId / StagePlaceId:

local RunConstants = {}

------------------------------------------------------------
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
------------------------------------------------------------
RunConstants.Mode = {
	Solo = "Solo",
	Party = "Party",
}

------------------------------------------------------------
-- Teleport data keys
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
	StartingRelicId = "startingRelicId",
}

------------------------------------------------------------
-- Stage outcome enum
------------------------------------------------------------
RunConstants.Outcome = {
	Clear = "Clear",
	Fail  = "Fail",
}

------------------------------------------------------------
-- StageFlowRequest action enum
------------------------------------------------------------
RunConstants.StageFlowAction = {
	NextFloor     = "NextFloor",
	ReturnToLobby = "ReturnToLobby",
}

return RunConstants
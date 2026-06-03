local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RunConstants = require(Shared:WaitForChild("Run"):WaitForChild("RunConstants"))

local LobbyClient = require(script.Parent:WaitForChild("LobbyClient"))
local StageClient = require(script.Parent:WaitForChild("StageClient"))

local placeId = game.PlaceId

local function matchesPlace(actual, configured)
	return type(configured) == "number" and configured > 0 and actual == configured
end

if matchesPlace(placeId, RunConstants.LobbyPlaceId) then
	LobbyClient.init()
	print("[MainClient] branch=LobbyPlace placeId=", placeId)
elseif matchesPlace(placeId, RunConstants.StagePlaceId) then
	StageClient.init()
	local CombatDebugClient = require(script.Parent:WaitForChild("CombatDebugClient"))
	CombatDebugClient.init()
	local PickupNotifyClient = require(script.Parent:WaitForChild("PickupNotifyClient"))
	PickupNotifyClient.init()
	local BlueprintNoticeClient = require(script.Parent:WaitForChild("BlueprintNoticeClient"))
	BlueprintNoticeClient.init()
	print("[MainClient] branch=StagePlace placeId=", placeId)
else
	warn(
		string.format(
			"[MainClient] Unknown PlaceId=%d ??LobbyPlaceId=%s StagePlaceId=%s ??no Lobby/Stage client init (safe no-op)",
			placeId,
			tostring(RunConstants.LobbyPlaceId),
			tostring(RunConstants.StagePlaceId)
		)
	)
end
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RunConstants = require(Shared:WaitForChild("Run"):WaitForChild("RunConstants"))

local LobbyClient = require(script.Parent:WaitForChild("LobbyClient"))
local StageClient = require(script.Parent:WaitForChild("StageClient"))

local placeId = game.PlaceId

local function matchesPlace(actual, configured)
	return type(configured) == "number" and configured > 0 and actual == configured
end

--- MainClient — 클라 단일 진입점. Place 분기 후 Lobby / Stage 초기화만 위임한다.
if matchesPlace(placeId, RunConstants.LobbyPlaceId) then
	LobbyClient.init()
	print("[MainClient] branch=LobbyPlace placeId=", placeId)
elseif matchesPlace(placeId, RunConstants.StagePlaceId) then
	StageClient.init()
	print("[MainClient] branch=StagePlace placeId=", placeId)
else
	warn(
		string.format(
			"[MainClient] Unknown PlaceId=%d — LobbyPlaceId=%s StagePlaceId=%s — no Lobby/Stage client init (safe no-op)",
			placeId,
			tostring(RunConstants.LobbyPlaceId),
			tostring(RunConstants.StagePlaceId)
		)
	)
end

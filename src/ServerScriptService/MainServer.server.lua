
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RunConstants = require(Shared:WaitForChild("Run"):WaitForChild("RunConstants"))

local placeId = game.PlaceId

local function matchesPlace(actual, configured)
	return type(configured) == "number" and configured > 0 and actual == configured
end

local function startLobbyBranch()
	local mapInLobby = Workspace:FindFirstChild("Map")
	if mapInLobby then
		mapInLobby:Destroy()
	end

	local Teleport = require(ServerScriptService:WaitForChild("Run"):WaitForChild("Teleport"))
	local GameConfig = require(Shared:WaitForChild("GameConfig"))
	local RelicProfileService = require(ServerScriptService:WaitForChild("RelicProfileService"))
	local LobbyBootstrap = require(ServerScriptService:WaitForChild("Lobby"):WaitForChild("LobbyBootstrap"))
	local Remotes = ReplicatedStorage:WaitForChild("Remotes")

	RelicProfileService.init({
		players = Players,
		replicatedStorage = ReplicatedStorage,
		gameConfig = GameConfig,
	})

	LobbyBootstrap.init({
		players          = Players,
		lobbyEnterRequest = Remotes:WaitForChild("LobbyEnterRequest"),
		teleport         = Teleport,
	})

	print(string.format("[MainServer] LobbyPlace started (placeId=%d)", placeId))
end

local function startStageBranch()
	local lobbyInStage = Workspace:FindFirstChild("Lobby")
	if lobbyInStage then
		lobbyInStage:Destroy()
	end

	Players.CharacterAutoLoads = false

	local GameConfig = require(Shared:WaitForChild("GameConfig"))
	local EnemyService = require(script.Parent:WaitForChild("EnemyService"))
	local WaveService = require(script.Parent:WaitForChild("WaveService"))
	local CombatService = require(script.Parent:WaitForChild("CombatService"))
	local ProgressionService = require(script.Parent:WaitForChild("ProgressionService"))
	local WeaponDropService = require(script.Parent:WaitForChild("WeaponDropService"))
	local RelicDropService = require(script.Parent:WaitForChild("RelicDropService"))
	local XpPickupService = require(script.Parent:WaitForChild("XpPickupService"))
	local HealthPickupService = require(script.Parent:WaitForChild("HealthPickupService"))
	local HudSyncService = require(script.Parent:WaitForChild("HudSyncService"))
	local PlayerContactDamageService = require(script.Parent:WaitForChild("PlayerContactDamageService"))
	local MapService = require(script.Parent:WaitForChild("Map"):WaitForChild("MapService"))
	local StageBootstrap = require(script.Parent:WaitForChild("Run"):WaitForChild("StageBootstrap"))
	local Remotes = ReplicatedStorage:WaitForChild("Remotes")

	EnemyService.init(Players, RunService, GameConfig)
	PlayerContactDamageService.init(Players, RunService, GameConfig, EnemyService)
	ProgressionService.init(Players, ReplicatedStorage, GameConfig)
	WeaponDropService.init(Players, RunService, Workspace, ProgressionService)
	RelicDropService.init(Players, RunService, Workspace, ProgressionService)
	XpPickupService.init(Players, RunService, ProgressionService, GameConfig)
	HealthPickupService.init(Players, RunService, GameConfig)
	WaveService.init(Players, RunService, GameConfig, EnemyService, ProgressionService, XpPickupService)
	HudSyncService.init(Players, RunService, ProgressionService, WaveService, GameConfig)
	WaveService.bindHudPushContext({
		hudSyncService = HudSyncService,
		xpPickupService = XpPickupService,
		healthPickupService = HealthPickupService,
		players = Players,
		progressionService = ProgressionService,
		gameConfig = GameConfig,
	})
	ProgressionService.setImmediateHudPush(function(player)
		HudSyncService.pushToPlayer(player, ProgressionService, WaveService, GameConfig)
	end)
	CombatService.init(
		Players, RunService, GameConfig, EnemyService, ProgressionService,
		XpPickupService, WaveService, HealthPickupService, WeaponDropService, RelicDropService
	)

	StageBootstrap.init({
		players          = Players,
		stageFlowRequest = Remotes:WaitForChild("StageFlowRequest"),
		mapService       = MapService,
		waveService      = WaveService,
		gameConfig       = GameConfig,
	})

	for _, pl in Players:GetPlayers() do
		ProgressionService.tryOfferStartingWeapon(pl)
	end

	print(string.format("[MainServer] StagePlace started (placeId=%d)", placeId))
end

if matchesPlace(placeId, RunConstants.LobbyPlaceId) then
	startLobbyBranch()
elseif matchesPlace(placeId, RunConstants.StagePlaceId) then
	startStageBranch()
else
	warn(string.format(
		"[MainServer] 개발용 fallback — Unknown PlaceId=%d (LobbyPlaceId=%d, StagePlaceId=%d). " ..
		"publish 후 RunConstants 의 두 PlaceId 를 실 ID 로 갱신하세요. 현재는 Stage 분기로 폴백합니다.",
		placeId, RunConstants.LobbyPlaceId, RunConstants.StagePlaceId
	))
	startStageBranch()
end
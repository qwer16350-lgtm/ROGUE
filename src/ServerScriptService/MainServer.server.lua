--- MainServer — 양 PlaceId 의 단일 진입점.
--- thin entry: PlaceId 분기 후 각 branch 함수에서만 require 를 수행한다.
--- (LobbyPlace 에서 Stage 전용 모듈을 require 하지 않기 위함 — 메모리 / 부팅 시간 절약.)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RunConstants = require(Shared:WaitForChild("Run"):WaitForChild("RunConstants"))

local placeId = game.PlaceId

--- 안전 매칭: configured == 0 (publish 전 미설정) 이거나 number 가 아니면 매칭 안 함.
--- → 두 PlaceId 모두 0 인 동안에는 어느 분기도 안 매칭되어 fallback 으로 빠진다.
local function matchesPlace(actual, configured)
	return type(configured) == "number" and configured > 0 and actual == configured
end

local function startLobbyBranch()
	--- 같은 default.project.json 로 sync 된 Workspace.Map 은 LobbyPlace 에서 미사용.
	--- 메모리·클라 레플리케이션 절약. Workspace 전체 조작 금지 — 하위 이름 Map 만.
	local mapInLobby = Workspace:FindFirstChild("Map")
	if mapInLobby then
		mapInLobby:Destroy()
	end

	local Teleport = require(ServerScriptService:WaitForChild("Run"):WaitForChild("Teleport"))
	local LobbyBootstrap = require(ServerScriptService:WaitForChild("Lobby"):WaitForChild("LobbyBootstrap"))
	local Remotes = ReplicatedStorage:WaitForChild("Remotes")

	LobbyBootstrap.init({
		players          = Players,
		lobbyEnterRequest = Remotes:WaitForChild("LobbyEnterRequest"),
		teleport         = Teleport,
	})

	print(string.format("[MainServer] LobbyPlace started (placeId=%d)", placeId))
end

local function startStageBranch()
	--- 같은 default.project.json 로 sync 된 Workspace.Lobby 는 StagePlace 에서 미사용.
	--- Lobby 내 SpawnLocation 이 :LoadCharacter() 스폰 후보로 끼어들 수 있으므로
	--- CharacterAutoLoads=false 선행 설정 전에 반드시 제거. Workspace 전체 조작 금지.
	local lobbyInStage = Workspace:FindFirstChild("Lobby")
	if lobbyInStage then
		lobbyInStage:Destroy()
	end

	-- ⚠ CharacterAutoLoads=false: StagePlace reserved server 에서 플레이어가
	--   Map 생성 전에 빈 공간으로 떨어지지 않도록 차단. StageBootstrap 이 GenerateMap
	--   직후 멤버 별 :LoadCharacter() 를 명시 호출.
	-- ⚠ Stage branch 안에서만 설정 — Lobby 는 기본값(true) 유지하여 SpawnLocation 자동 spawn.
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

	-- 사용자 명시 wiring 순서 (전투 / 지원 서비스 → WaveService → bindHud → CombatService).
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

	-- 마지막에 StageBootstrap.init: RunContext init / StageFlow init / bindStageFlow /
	-- GenerateMap / LoadCharacter·StageSpawns 정렬 / WaveService.startSession 을 한 곳에서.
	StageBootstrap.init({
		players          = Players,
		stageFlowRequest = Remotes:WaitForChild("StageFlowRequest"),
		mapService       = MapService,
		waveService      = WaveService,
		gameConfig       = GameConfig,
	})

	for _, pl in Players:GetPlayers() do
		ProgressionService.tryOfferStartingRelic(pl)
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

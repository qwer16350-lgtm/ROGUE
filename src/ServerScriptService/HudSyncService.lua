local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HudSyncService = {}
local DEBUG_STAGE_HUD = true

local hudStateRemote = nil

local function buildPayload(player, progressionService, waveService, gameConfig)
	local waveInfo = waveService.getHudInfo()
	local prog = progressionService.getHudProgress(player)

	local sessionLen = waveInfo.sessionLengthSeconds
	if type(sessionLen) ~= "number" or sessionLen <= 0 then
		sessionLen = gameConfig.SessionDurationSeconds
	end

	return {
		Level = prog.level,
		Xp = prog.xp,
		XpToNext = prog.xpToNext,
		SecondsLeft = waveInfo.remaining,
		SecondsLeftFloat = waveInfo.remainingFloat,
		SessionActive = waveInfo.active,
		SessionLengthSeconds = sessionLen,
		StageIndex = waveInfo.stageIndex or 1,
	}
end

function HudSyncService.pushToPlayer(player, progressionService, waveService, gameConfig)
	if not hudStateRemote then
		return
	end
	if not player or not player.Parent then
		return
	end

	local payload = buildPayload(player, progressionService, waveService, gameConfig)
	if DEBUG_STAGE_HUD then
		print(string.format("[HudSyncService] pushToPlayer %s StageIndex=%d SessionActive=%s", player.Name, payload.StageIndex or -1, tostring(payload.SessionActive)))
	end
	hudStateRemote:FireClient(player, payload)
end

function HudSyncService.init(players, runService, progressionService, waveService, gameConfig)
	local syncInterval = gameConfig.HudSyncIntervalSeconds

	hudStateRemote = ReplicatedStorage:FindFirstChild("HudState")
	if not hudStateRemote then
		hudStateRemote = Instance.new("RemoteEvent")
		hudStateRemote.Name = "HudState"
		hudStateRemote.Parent = ReplicatedStorage
	end

	local accumulator = 0

	runService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < syncInterval then
			return
		end
		accumulator = 0

		for _, player in ipairs(players:GetPlayers()) do
			local payload = buildPayload(player, progressionService, waveService, gameConfig)
			if DEBUG_STAGE_HUD then
				print(string.format("[HudSyncService] heartbeat push %s StageIndex=%d SessionActive=%s", player.Name, payload.StageIndex or -1, tostring(payload.SessionActive)))
			end
			hudStateRemote:FireClient(player, payload)
		end
	end)
end

return HudSyncService

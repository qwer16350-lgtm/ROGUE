local ProgressionService = {}

local progressByPlayer = {}
local levelUpChoiceEvent = nil
local choicePayloadForClient = nil
local gameConfigRef = nil
local immediateHudPush = nil

function ProgressionService.setImmediateHudPush(callback)
	immediateHudPush = callback
end

local function xpRequiredForLevel(level)
	if not gameConfigRef then
		return 100 * level
	end
	return gameConfigRef.XpRequiredPerLevelBase * level
end

function ProgressionService.getHudProgress(player)
	local state = progressByPlayer[player]
	if not state then
		return {
			level = 1,
			xp = 0,
			xpToNext = xpRequiredForLevel(1),
		}
	end

	return {
		level = state.level,
		xp = state.xp,
		xpToNext = xpRequiredForLevel(state.level),
	}
end

function ProgressionService.getUpgradeCounts(player)
	local state = progressByPlayer[player]
	if not state or not state.upgrades then
		return {
			damage_up = 0,
			attack_interval_down = 0,
			attack_size_up = 0,
		}
	end
	return state.upgrades
end

function ProgressionService.init(players, replicatedStorage, gameConfig)
	gameConfigRef = gameConfig

	local shared = replicatedStorage:WaitForChild("Shared")
	local upgradeData = require(shared:WaitForChild("UpgradeData"))

	local function newUpgradeTable()
		local t = {}
		for _, choice in ipairs(upgradeData.Choices) do
			t[choice.Id] = 0
		end
		return t
	end

	local choices = {}
	for _, choice in ipairs(upgradeData.Choices) do
		table.insert(choices, {
			Id = choice.Id,
			Label = choice.Label,
		})
	end
	choicePayloadForClient = choices

	levelUpChoiceEvent = replicatedStorage:FindFirstChild("LevelUpChoiceRequest")
	if not levelUpChoiceEvent then
		levelUpChoiceEvent = Instance.new("RemoteEvent")
		levelUpChoiceEvent.Name = "LevelUpChoiceRequest"
		levelUpChoiceEvent.Parent = replicatedStorage
	end

	local allowedChoiceIds = {}
	for _, choice in ipairs(upgradeData.Choices) do
		allowedChoiceIds[choice.Id] = true
	end

	local submitEvent = replicatedStorage:FindFirstChild("LevelUpChoiceSubmit")
	if not submitEvent then
		submitEvent = Instance.new("RemoteEvent")
		submitEvent.Name = "LevelUpChoiceSubmit"
		submitEvent.Parent = replicatedStorage
	end

	submitEvent.OnServerEvent:Connect(function(player, choiceId)
		if type(choiceId) ~= "string" then
			return
		end
		if not allowedChoiceIds[choiceId] then
			return
		end

		local state = progressByPlayer[player]
		if not state or not state.upgrades then
			return
		end

		state.upgrades[choiceId] += 1

		local stats = upgradeData.getEffectiveCombatStats(gameConfigRef, state.upgrades)
		local u = state.upgrades
		print(
			string.format(
				"[Progression] %s | 선택: %s | 스택 피해%d 공속%d 사거리%d | 결과 → 피해량 %d | 공격간격 %.3fs | 사거리 %.1f 스터드",
				player.Name,
				choiceId,
				u.damage_up or 0,
				u.attack_interval_down or 0,
				u.attack_size_up or 0,
				stats.damagePerHit,
				stats.attackIntervalSeconds,
				stats.attackRangeStuds
			)
		)
	end)

	local function ensureProgress(player)
		if not progressByPlayer[player] then
			progressByPlayer[player] = {
				level = 1,
				xp = 0,
				upgrades = newUpgradeTable(),
			}
		else
			local s = progressByPlayer[player]
			if not s.upgrades then
				s.upgrades = newUpgradeTable()
			end
		end
		return progressByPlayer[player]
	end

	players.PlayerAdded:Connect(function(player)
		ensureProgress(player)
	end)

	players.PlayerRemoving:Connect(function(player)
		progressByPlayer[player] = nil
	end)

	for _, player in players:GetPlayers() do
		ensureProgress(player)
	end
end

function ProgressionService.addExperience(player, amount)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return
	end
	if type(amount) ~= "number" or amount <= 0 then
		return
	end

	local state = progressByPlayer[player]
	if not state then
		return
	end

	state.xp += amount

	while true do
		local need = xpRequiredForLevel(state.level)
		if state.xp < need then
			break
		end

		state.xp -= need
		state.level += 1

		if levelUpChoiceEvent and choicePayloadForClient then
			levelUpChoiceEvent:FireClient(player, {
				Level = state.level,
				Choices = choicePayloadForClient,
			})
		end

		if immediateHudPush then
			immediateHudPush(player)
		end
	end
end

return ProgressionService

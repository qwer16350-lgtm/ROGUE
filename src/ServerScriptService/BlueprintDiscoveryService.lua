-- Blueprint discovery drop (minimum): kill roll, E-prompt pickup, run pending, result merge.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EnemyTier = require(Shared:WaitForChild("Config"):WaitForChild("EnemyTier"))
local RelicDefinitions = require(Shared:WaitForChild("RelicDefinitions"))
local RelicProfilePersistence = require(script.Parent:WaitForChild("RelicProfilePersistence"))

local BlueprintDiscoveryService = {}

local DROP_KIND = "Blueprint"
local PICKUP_FOLDER_NAME = "BlueprintPickups"
local PICKUP_SIZE = Vector3.new(2.2, 0.35, 1.4)
local PROMPT_MAX_DISTANCE = 8
local NEON_COLOR = Color3.fromRGB(80, 200, 255)
local LIGHT_COLOR = Color3.fromRGB(120, 230, 255)

type ProgressionApi = {
	getOwnedRelicIdSetForBlueprintDrop: (Player) -> { [string]: boolean },
}

local pendingByUserId: { [number]: { [string]: number } } = {}
local activePickups: { BasePart } = {}
local gameConfigRef: any = nil
local progressionServiceRef: ProgressionApi? = nil
local noticeEvent: RemoteEvent? = nil

local function copyPendingMap(src: { [string]: number }): { [string]: number }
	local out: { [string]: number } = {}
	for blueprintId, amt in pairs(src) do
		if type(blueprintId) == "string" and blueprintId ~= "" and type(amt) == "number" and amt > 0 then
			out[blueprintId] = amt
		end
	end
	return out
end

local function addPending(userId: number, blueprintId: string, amount: number)
	if type(blueprintId) ~= "string" or blueprintId == "" or type(amount) ~= "number" or amount <= 0 then
		return
	end
	local bucket = pendingByUserId[userId]
	if not bucket then
		bucket = {}
		pendingByUserId[userId] = bucket
	end
	bucket[blueprintId] = (bucket[blueprintId] or 0) + math.floor(amount + 0.5)
end

function BlueprintDiscoveryService.takeAndClearPending(userId: number): { [string]: number }
	local bucket = pendingByUserId[userId]
	pendingByUserId[userId] = nil
	if type(bucket) ~= "table" then
		return {}
	end
	return copyPendingMap(bucket)
end

function BlueprintDiscoveryService.mergePendingToProfile(userId: number): (boolean, string?, { [string]: number })
	local deltas = BlueprintDiscoveryService.takeAndClearPending(userId)
	if not next(deltas) then
		return true, nil, deltas
	end
	local applied, err = RelicProfilePersistence.grantBlueprintProgress(userId, deltas)
	if not applied then
		warn(string.format("[BlueprintDiscoveryService] pending merge failed uid=%d err=%s", userId, tostring(err)))
		return false, err, deltas
	end
	return true, nil, deltas
end

local function resolveSourceKind(entry: any): string
	if type(entry) ~= "table" or type(entry.state) ~= "table" then
		return "Normal"
	end
	local st = entry.state
	if st.isBoss == true then
		return "Boss"
	end
	local tier = st.tier
	if tier == EnemyTier.Boss then
		return "Boss"
	end
	if tier == EnemyTier.Elite or st.isElite == true then
		return "Elite"
	end
	return "Normal"
end

local function getDropChance(sourceKind: string): number
	local dbg = gameConfigRef and gameConfigRef.Debug
	if type(dbg) == "table" then
		local override = dbg.BlueprintDropChanceOverride
		if type(override) == "number" and override >= 0 and override <= 1 then
			return override
		end
	end
	local tbl = gameConfigRef and gameConfigRef.BlueprintDropChanceBySourceKind
	if type(tbl) ~= "table" then
		return 0
	end
	local chance = tbl[sourceKind]
	if type(chance) ~= "number" or chance < 0 or chance > 1 then
		return 0
	end
	return chance
end

local function pickBlueprintId(player: Player): string?
	if not progressionServiceRef then
		return nil
	end
	local ownedSet = progressionServiceRef.getOwnedRelicIdSetForBlueprintDrop(player)
	local candidates = RelicDefinitions.listBlueprintDropCandidateIds(ownedSet)
	if #candidates == 0 then
		return nil
	end
	return candidates[math.random(1, #candidates)]
end

local function ensureFolder(): Folder
	local folder = Workspace:FindFirstChild(PICKUP_FOLDER_NAME)
	if folder and folder:IsA("Folder") then
		return folder
	end
	local f = Instance.new("Folder")
	f.Name = PICKUP_FOLDER_NAME
	f.Parent = Workspace
	return f
end

local function removePickupFromList(part: BasePart)
	for i = #activePickups, 1, -1 do
		if activePickups[i] == part then
			table.remove(activePickups, i)
			break
		end
	end
end

local function destroyPickup(part: BasePart?)
	if not part then
		return
	end
	removePickupFromList(part)
	if part.Parent then
		part:Destroy()
	end
end

local function clearPickupsForUserId(userId: number)
	for i = #activePickups, 1, -1 do
		local part = activePickups[i]
		local bound = part and part.Parent and part:GetAttribute("BoundUserId")
		if part and part.Parent and type(bound) == "number" and bound == userId then
			part:Destroy()
			table.remove(activePickups, i)
		elseif not part or not part.Parent then
			table.remove(activePickups, i)
		end
	end
end

local function fireNotice(player: Player, blueprintId: string)
	local ev = noticeEvent
	if not ev or not player.Parent then
		return
	end
	local label = RelicDefinitions.getDisplayLabelForBlueprintId(blueprintId)
	ev:FireClient(player, {
		Label = label,
		Message = string.format("Blueprint +1: %s", label),
		DurationSeconds = 3,
	})
end

local function onPromptTriggered(part: BasePart, blueprintId: string, boundUserId: number, triggerPlayer: Player)
	if part:GetAttribute("Collected") == true then
		return
	end
	if typeof(triggerPlayer) ~= "Instance" or not triggerPlayer:IsA("Player") then
		return
	end
	if triggerPlayer.UserId ~= boundUserId then
		return
	end
	part:SetAttribute("Collected", true)
	addPending(boundUserId, blueprintId, 1)
	fireNotice(triggerPlayer, blueprintId)
	destroyPickup(part)
end

local function spawnBlueprintPickupAt(worldPosition: Vector3, boundPlayer: Player, blueprintId: string)
	if typeof(boundPlayer) ~= "Instance" or not boundPlayer:IsA("Player") then
		return
	end
	if type(blueprintId) ~= "string" or blueprintId == "" then
		return
	end

	local folder = ensureFolder()
	local pos = worldPosition + Vector3.new(0, 0.5, 0)

	local part = Instance.new("Part")
	part.Name = "BlueprintPickup"
	part.Size = PICKUP_SIZE
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = true
	part.Material = Enum.Material.Neon
	part.Color = NEON_COLOR
	part.CFrame = CFrame.new(pos)
	part:SetAttribute("DropKind", DROP_KIND)
	part:SetAttribute("BlueprintId", blueprintId)
	part:SetAttribute("BoundUserId", boundPlayer.UserId)
	part:SetAttribute("Collected", false)

	local light = Instance.new("PointLight")
	light.Brightness = 2.5
	light.Range = 12
	light.Color = LIGHT_COLOR
	light.Parent = part

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BlueprintCollectPrompt"
	prompt.ActionText = "Collect Blueprint"
	prompt.ObjectText = "Blueprint"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = PROMPT_MAX_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Parent = part

	local boundUserId = boundPlayer.UserId
	prompt.Triggered:Connect(function(triggerPlayer)
		onPromptTriggered(part, blueprintId, boundUserId, triggerPlayer)
	end)

	part.Parent = folder
	table.insert(activePickups, part)
end

function BlueprintDiscoveryService.tryRollAndSpawnOnKill(player: Player, entry: any, deathPos: Vector3)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return
	end
	if typeof(deathPos) ~= "Vector3" then
		return
	end

	local sourceKind = resolveSourceKind(entry)
	local chance = getDropChance(sourceKind)
	if chance <= 0 or math.random() >= chance then
		return
	end

	local blueprintId = pickBlueprintId(player)
	if not blueprintId then
		return
	end

	spawnBlueprintPickupAt(deathPos, player, blueprintId)
end

function BlueprintDiscoveryService.init(players: Players, gameConfig: any, progressionService: ProgressionApi, remotesFolder: Folder)
	gameConfigRef = gameConfig
	progressionServiceRef = progressionService
	noticeEvent = remotesFolder:WaitForChild("BlueprintPickupNotice") :: RemoteEvent
	ensureFolder()

	players.PlayerRemoving:Connect(function(player)
		local uid = player.UserId
		BlueprintDiscoveryService.mergePendingToProfile(uid)
		clearPickupsForUserId(uid)
	end)
end

return BlueprintDiscoveryService
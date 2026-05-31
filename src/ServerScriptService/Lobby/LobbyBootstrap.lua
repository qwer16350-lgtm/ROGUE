---
---
---

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RunConstants = require(Shared:WaitForChild("Run"):WaitForChild("RunConstants"))
local PartyService = require(script.Parent:WaitForChild("PartyService"))
local RelicProfileService = require(ServerScriptService:WaitForChild("RelicProfileService"))

local LobbyBootstrap = {}

------------------------------------------------------------
-- Tunables
------------------------------------------------------------
local ENTRY_PAD_TAG = "LobbyEntryPad"
local PER_PLAYER_DEBOUNCE_SECONDS = 5

------------------------------------------------------------
-- State
------------------------------------------------------------
local ctx = {
	players = nil,
	lobbyEnterRequest = nil,
	teleport = nil,
}

local lastTriggerByUserId = {}

------------------------------------------------------------
-- Helpers
------------------------------------------------------------
local function findFirstProximityPrompt(instance)
	if instance:IsA("ProximityPrompt") then
		return instance
	end
	for _, d in ipairs(instance:GetDescendants()) do
		if d:IsA("ProximityPrompt") then
			return d
		end
	end
	return nil
end

local function copyEquippedStartingRelicIdsForTeleport(player: Player): { string }
	local out: { string } = {}
	local profile = RelicProfileService.getProfile(player)
	if type(profile) ~= "table" or type(profile.equippedStartingRelics) ~= "table" then
		return out
	end
	for _, relicId in ipairs(profile.equippedStartingRelics) do
		if type(relicId) == "string" and relicId ~= "" then
			table.insert(out, relicId)
		end
	end
	return out
end

local function tryEnter(player)
	if not player or not player.Parent then
		return
	end
	local now = tick()
	local last = lastTriggerByUserId[player.UserId]
	if last and (now - last) < PER_PLAYER_DEBOUNCE_SECONDS then
		return
	end
	lastTriggerByUserId[player.UserId] = now

	local members, mode = PartyService.getMembersFor(player)
	if type(members) ~= "table" or #members == 0 then
		warn(string.format(
			"[LobbyBootstrap] PartyService.getMembersFor returned invalid members for %s — entry aborted",
			player.Name
		))
		lastTriggerByUserId[player.UserId] = nil
		return
	end
	if mode == nil then
		mode = RunConstants.Mode.Solo
	end

	local opts = {
		mode = mode,
		equippedStartingRelicIds = copyEquippedStartingRelicIdsForTeleport(player),
	}
	local ok = ctx.teleport.toFirstFloor(members, opts)
	if not ok then
		warn(string.format("[LobbyBootstrap] toFirstFloor failed for %s", player.Name))
		lastTriggerByUserId[player.UserId] = nil
	end
end

local function connectPad(instance)
	local prompt = findFirstProximityPrompt(instance)
	if not prompt then
		warn(string.format(
			"[LobbyBootstrap] tagged %q has no ProximityPrompt descendant: %s",
			ENTRY_PAD_TAG, instance:GetFullName()
		))
		return
	end
	prompt.Triggered:Connect(function(player)
		tryEnter(player)
	end)
end

------------------------------------------------------------
-- Public API
------------------------------------------------------------
function LobbyBootstrap.init(deps)
	assert(deps, "[LobbyBootstrap] deps required")
	assert(deps.players, "[LobbyBootstrap] deps.players required")
	assert(deps.lobbyEnterRequest, "[LobbyBootstrap] deps.lobbyEnterRequest required")
	assert(deps.teleport, "[LobbyBootstrap] deps.teleport required")

	ctx.players = deps.players
	ctx.lobbyEnterRequest = deps.lobbyEnterRequest
	ctx.teleport = deps.teleport

	local existing = CollectionService:GetTagged(ENTRY_PAD_TAG)
	for _, inst in ipairs(existing) do
		connectPad(inst)
	end
	if #existing == 0 then
		warn(string.format(
			"[LobbyBootstrap] no instances tagged %q found at boot. " ..
			"Studio 에서 입장 패드에 태그를 추가하면 동적 연결됨.",
			ENTRY_PAD_TAG
		))
	end

	CollectionService:GetInstanceAddedSignal(ENTRY_PAD_TAG):Connect(function(inst)
		connectPad(inst)
	end)

	ctx.lobbyEnterRequest.OnServerEvent:Connect(function(player)
		tryEnter(player)
	end)

	ctx.players.PlayerRemoving:Connect(function(player)
		lastTriggerByUserId[player.UserId] = nil
	end)
end

return LobbyBootstrap

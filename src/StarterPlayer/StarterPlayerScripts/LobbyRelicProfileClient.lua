local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RunRewardBudgetPolicy = require(Shared:WaitForChild("RunRewardBudgetPolicy"))

local LobbyRelicProfileClient = {}

local CRAFT_MATERIAL_KEYS = RunRewardBudgetPolicy.CRAFT_MATERIAL_KEYS
local CURRENCY_KEYS = RunRewardBudgetPolicy.CURRENCY_KEYS
local LOAD_RETRY_INTERVAL = 0.5
local LOAD_RETRY_MAX = 10

local getRelicProfileRemote: RemoteFunction? = nil
local lastProfile: any = nil

function LobbyRelicProfileClient.getMaterialKeys(): { string }
	return CRAFT_MATERIAL_KEYS
end

function LobbyRelicProfileClient.getCurrencyKeys(): { string }
	return CURRENCY_KEYS
end

function LobbyRelicProfileClient.formatMaterials(materials: any): string
	local parts = {}
	for _, key in ipairs(CRAFT_MATERIAL_KEYS) do
		local amt = 0
		if type(materials) == "table" and type(materials[key]) == "number" then
			amt = materials[key]
		end
		local label = RunRewardBudgetPolicy.MATERIAL_DISPLAY_NAMES[key] or key
		table.insert(parts, string.format("%s=%d", label, amt))
	end
	return table.concat(parts, ", ")
end

function LobbyRelicProfileClient.formatCurrencies(currencies: any): string
	local parts = {}
	for _, key in ipairs(CURRENCY_KEYS) do
		local amt = 0
		if type(currencies) == "table" and type(currencies[key]) == "number" then
			amt = currencies[key]
		end
		local label = RunRewardBudgetPolicy.CURRENCY_DISPLAY_NAMES[key] or key
		table.insert(parts, string.format("%s=%d", label, amt))
	end
	return table.concat(parts, ", ")
end

function LobbyRelicProfileClient.getLastProfile(): any
	return lastProfile
end

function LobbyRelicProfileClient.setLastProfile(profile: any)
	if type(profile) == "table" and profile.ok == true then
		lastProfile = profile
	end
end

local function invokeProfile(): any
	if not getRelicProfileRemote then
		return { ok = false, reason = "REMOTE_MISSING" }
	end
	local ok, result = pcall(function()
		return getRelicProfileRemote:InvokeServer()
	end)
	if not ok then
		return { ok = false, reason = "INVOKE_ERROR" }
	end
	return result
end

function LobbyRelicProfileClient.fetchProfile(): any
	local last = nil
	for _ = 1, LOAD_RETRY_MAX do
		last = invokeProfile()
		if type(last) == "table" and last.ok == true then
			lastProfile = last
			return last
		end
		if type(last) == "table" and last.reason ~= "PROFILE_LOADING" then
			return last
		end
		task.wait(LOAD_RETRY_INTERVAL)
	end
	return last
end

function LobbyRelicProfileClient.init()
	local remotes = ReplicatedStorage:WaitForChild("Remotes", 15)
	if not remotes then
		warn("[LobbyRelicProfileClient] Remotes missing")
		return
	end
	getRelicProfileRemote = remotes:WaitForChild("GetRelicProfile", 15) :: RemoteFunction?
	if not getRelicProfileRemote or not getRelicProfileRemote:IsA("RemoteFunction") then
		warn("[LobbyRelicProfileClient] GetRelicProfile missing")
		return
	end
end

return LobbyRelicProfileClient

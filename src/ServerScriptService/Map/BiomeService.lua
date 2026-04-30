local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local MapConfig = require(Config:WaitForChild("MapConfig"))
local BiomeRegistry = require(Config:WaitForChild("BiomeRegistry"))

local BiomeService = {}

function BiomeService.getCurrentBiomeName()
	return MapConfig.DefaultBiome
end

function BiomeService.getCurrentBiomeData()
	local name = MapConfig.DefaultBiome
	local data = BiomeRegistry[name]
	if not data then
		warn("[BiomeService] Unknown biome in registry:", name)
		return nil
	end
	return data
end

return BiomeService

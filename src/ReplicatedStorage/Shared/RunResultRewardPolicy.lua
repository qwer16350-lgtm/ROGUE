-- Step 5B: placeholder run-end material grants (RewardBudget final balancing is later).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunConstants = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Run"):WaitForChild("RunConstants")
)

local RunResultRewardPolicy = {}

local MATERIAL_KEYS = { "shard", "ancient_shard", "ceremonial_coin" }

local function emptyMaterialsGranted(): { [string]: number }
	return {
		shard = 0,
		ancient_shard = 0,
		ceremonial_coin = 0,
	}
end

local function sanitizeMaterialsGranted(src: any): { [string]: number }
	local out = emptyMaterialsGranted()
	if type(src) ~= "table" then
		return out
	end
	for _, key in ipairs(MATERIAL_KEYS) do
		local v = src[key]
		if type(v) == "number" and v > 0 then
			out[key] = math.floor(v + 0.5)
		end
	end
	return out
end

function RunResultRewardPolicy.compute(runCtx: {
	outcome: string?,
	floor: number?,
	isLastFloor: boolean?,
	cleared: boolean?,
	killCount: number?,
	survivalSeconds: number?,
}, gameConfig: any): { materialsGranted: { [string]: number } }
	local cfg = type(gameConfig) == "table" and gameConfig.RunResultReward or nil
	if type(cfg) ~= "table" or cfg.Enabled ~= true then
		return { materialsGranted = emptyMaterialsGranted() }
	end

	local granted = emptyMaterialsGranted()
	local outcome = runCtx and runCtx.outcome
	local isClear = outcome == RunConstants.Outcome.Clear or (runCtx and runCtx.cleared == true)

	if isClear then
		local clearShard = cfg.ClearShard
		if type(clearShard) == "number" and clearShard > 0 then
			granted.shard = math.floor(clearShard + 0.5)
		end
		if runCtx and runCtx.isLastFloor == true then
			local bonus = cfg.LastFloorClearAncientShard
			if type(bonus) == "number" and bonus > 0 then
				granted.ancient_shard = math.floor(bonus + 0.5)
			end
		end
	else
		local failShard = cfg.FailShard
		if type(failShard) == "number" and failShard > 0 then
			granted.shard = math.floor(failShard + 0.5)
		end
	end

	return { materialsGranted = sanitizeMaterialsGranted(granted) }
end

return RunResultRewardPolicy
-- Stage run-end rewards: delegates to RunRewardBudgetPolicy (RewardBudget minimum).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RunRewardBudgetPolicy = require(Shared:WaitForChild("RunRewardBudgetPolicy"))

local RunResultRewardPolicy = {}

function RunResultRewardPolicy.compute(runCtx: {
	outcome: string?,
	floor: number?,
	isLastFloor: boolean?,
	cleared: boolean?,
	killCount: number?,
	survivalSeconds: number?,
	normalKills: number?,
	eliteKills: number?,
	bossKills: number?,
	bossKillElapsedSeconds: number?,
	finalDamageTaken: number?,
	cleanDamageBudget: number?,
}, gameConfig: any): {
	materialsGranted: { [string]: number },
	currenciesGranted: { [string]: number },
	rewardBudget: { [string]: any },
}
	return RunRewardBudgetPolicy.compute({
		cleared = runCtx and runCtx.cleared,
		normalKills = runCtx and runCtx.normalKills,
		eliteKills = runCtx and runCtx.eliteKills,
		bossKills = runCtx and runCtx.bossKills,
		bossKillElapsedSeconds = runCtx and runCtx.bossKillElapsedSeconds,
		finalDamageTaken = runCtx and runCtx.finalDamageTaken,
		cleanDamageBudget = runCtx and runCtx.cleanDamageBudget,
	}, gameConfig)
end

return RunResultRewardPolicy

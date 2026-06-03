-- Stage run-end RewardBudget (minimum): combat budget, material conversion, Ancient Shard currency.

local RunRewardBudgetPolicy = {}

RunRewardBudgetPolicy.CRAFT_MATERIAL_KEYS = {
	"mysterious_metal_part",
	"stinky_bond",
	"corrupted_gear",
}

RunRewardBudgetPolicy.CURRENCY_KEYS = { "ancient_shard" }

RunRewardBudgetPolicy.MATERIAL_COST = {
	mysterious_metal_part = 1,
	stinky_bond = 4,
	corrupted_gear = 12,
}

RunRewardBudgetPolicy.MATERIAL_DISPLAY_NAMES = {
	mysterious_metal_part = "Mysterious Metal Part",
	stinky_bond = "Stinky Bond",
	corrupted_gear = "Corrupted Gear",
}

RunRewardBudgetPolicy.CURRENCY_DISPLAY_NAMES = {
	ancient_shard = "Ancient Shard",
}

local CORRUPTED_GUARANTEE_COST = 12

local function emptyMaterialsGranted(): { [string]: number }
	return {
		mysterious_metal_part = 0,
		stinky_bond = 0,
		corrupted_gear = 0,
	}
end

local function emptyCurrenciesGranted(): { [string]: number }
	return { ancient_shard = 0 }
end

local function sanitizeMaterialsGranted(src: any): { [string]: number }
	local out = emptyMaterialsGranted()
	if type(src) ~= "table" then
		return out
	end
	for _, key in ipairs(RunRewardBudgetPolicy.CRAFT_MATERIAL_KEYS) do
		local v = src[key]
		if type(v) == "number" and v > 0 then
			out[key] = math.floor(v + 0.5)
		end
	end
	return out
end

local function sanitizeCurrenciesGranted(src: any): { [string]: number }
	local out = emptyCurrenciesGranted()
	if type(src) ~= "table" then
		return out
	end
	for _, key in ipairs(RunRewardBudgetPolicy.CURRENCY_KEYS) do
		local v = src[key]
		if type(v) == "number" and v > 0 then
			out[key] = math.floor(v + 0.5)
		end
	end
	return out
end

local function getCfg(gameConfig: any): any?
	local cfg = type(gameConfig) == "table" and gameConfig.RewardBudget or nil
	if type(cfg) ~= "table" or cfg.Enabled ~= true then
		return nil
	end
	return cfg
end

local function num(cfg: any, key: string, default: number): number
	local v = cfg and cfg[key]
	if type(v) == "number" then
		return v
	end
	return default
end

function RunRewardBudgetPolicy.computeTotalMaterialCostValue(materialsGranted: { [string]: number }): number
	local total = 0
	for key, cost in pairs(RunRewardBudgetPolicy.MATERIAL_COST) do
		local amt = materialsGranted[key]
		if type(amt) == "number" and amt > 0 then
			total += amt * cost
		end
	end
	return total
end

function RunRewardBudgetPolicy.computeAncientShardFromMaterials(materialsGranted: { [string]: number }, cfg: any): number
	local perCost = num(cfg, "AncientShardPerMaterialCostValue", 10)
	local totalCost = RunRewardBudgetPolicy.computeTotalMaterialCostValue(materialsGranted)
	return math.floor(totalCost * perCost + 0.5)
end

local function computeBaseCombatBudget(
	normalKills: number,
	eliteKills: number,
	bossKills: number,
	cfg: any,
	success: boolean
): number
	local successBase = num(cfg, "SuccessBase", 5)
	local failureBase = num(cfg, "FailureBase", 2)
	local base = success and successBase or failureBase
	local perNormal = num(cfg, "NormalKillsPerBudget", 5)
	if perNormal > 0 then
		base += math.floor(math.max(0, normalKills) / perNormal)
	end
	local eliteBudget = num(cfg, "EliteKillBudget", 2)
	base += math.max(0, eliteKills) * eliteBudget
	if success then
		local bossBudget = num(cfg, "BossKillBudget", 15)
		base += math.max(0, bossKills) * bossBudget
	end
	return math.max(0, math.floor(base + 0.5))
end

local function computeBossKillSpeedMultiplier(bossKillElapsedSeconds: number?, cfg: any): number
	if type(bossKillElapsedSeconds) ~= "number" then
		return 1
	end
	local target = num(cfg, "BossTargetKillSeconds", 45)
	local maxWindow = num(cfg, "MaxBossSpeedBonusWindowSeconds", 30)
	local secPerPoint = num(cfg, "SecondsPerBossSpeedPoint", 5)
	local mulPerPoint = num(cfg, "BossSpeedMultiplierPerPoint", 0.05)
	if secPerPoint <= 0 then
		return 1
	end
	local bonusSeconds = math.clamp(target - bossKillElapsedSeconds, 0, maxWindow)
	local points = math.floor(bonusSeconds / secPerPoint)
	return 1 + points * mulPerPoint
end

local function computeCleanPlayBonus(finalDamageTaken: number, cleanDamageBudget: number, cfg: any): number
	local maxBonus = num(cfg, "CleanBonusMax", 10)
	if type(cleanDamageBudget) ~= "number" or cleanDamageBudget <= 0 then
		return 0
	end
	local taken = type(finalDamageTaken) == "number" and math.max(0, finalDamageTaken) or 0
	local ratio = math.clamp(1 - taken / cleanDamageBudget, 0, 1)
	return math.floor(maxBonus * ratio)
end

local function greedyAllocateRemaining(budget: number): (number, number, number)
	local remaining = math.max(0, math.floor(budget + 0.5))
	local corrupted = 0
	local stinky = 0
	while remaining >= CORRUPTED_GUARANTEE_COST do
		corrupted += 1
		remaining -= CORRUPTED_GUARANTEE_COST
	end
	while remaining >= RunRewardBudgetPolicy.MATERIAL_COST.stinky_bond do
		stinky += 1
		remaining -= RunRewardBudgetPolicy.MATERIAL_COST.stinky_bond
	end
	return corrupted, stinky, remaining
end

local function convertSuccessMaterials(rewardBudget: number, cfg: any): { [string]: number }
	local out = emptyMaterialsGranted()
	local guaranteeCost = num(cfg, "CorruptedGearGuaranteeCost", CORRUPTED_GUARANTEE_COST)
	out.corrupted_gear = 1
	local remaining = math.floor(rewardBudget + 0.5) - guaranteeCost
	if remaining > 0 then
		local extraCorrupted, extraStinky, mysterious = greedyAllocateRemaining(remaining)
		out.corrupted_gear += extraCorrupted
		out.stinky_bond = extraStinky
		out.mysterious_metal_part = mysterious
	end
	return out
end

local function convertFailureMaterials(failureBudget: number): { [string]: number }
	local out = emptyMaterialsGranted()
	out.mysterious_metal_part = math.max(0, math.floor(failureBudget + 0.5))
	return out
end

function RunRewardBudgetPolicy.compute(runCtx: {
	cleared: boolean?,
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
	local cfg = getCfg(gameConfig)
	if not cfg then
		return {
			materialsGranted = emptyMaterialsGranted(),
			currenciesGranted = emptyCurrenciesGranted(),
			rewardBudget = { success = false },
		}
	end

	local dbg = type(gameConfig) == "table" and gameConfig.Debug or nil
	local override = type(dbg) == "table" and dbg.RewardBudgetOverride or nil

	local normalKills = type(runCtx.normalKills) == "number" and math.max(0, math.floor(runCtx.normalKills + 0.5)) or 0
	local eliteKills = type(runCtx.eliteKills) == "number" and math.max(0, math.floor(runCtx.eliteKills + 0.5)) or 0
	local bossKills = type(runCtx.bossKills) == "number" and math.max(0, math.floor(runCtx.bossKills + 0.5)) or 0
	local success = runCtx.cleared == true

	local baseCombatBudget = computeBaseCombatBudget(normalKills, eliteKills, bossKills, cfg, success)
	local bossKillSpeedMultiplier = 1
	local cleanPlayBonus = 0
	local finalRewardBudget = 0
	local bossKillElapsedSeconds = runCtx.bossKillElapsedSeconds
	local finalDamageTaken = type(runCtx.finalDamageTaken) == "number" and math.max(0, runCtx.finalDamageTaken) or 0
	local cleanDamageBudget = type(runCtx.cleanDamageBudget) == "number" and runCtx.cleanDamageBudget or 0

	if type(override) == "number" and override >= 0 then
		finalRewardBudget = math.floor(override + 0.5)
	else
		if success then
			bossKillSpeedMultiplier = computeBossKillSpeedMultiplier(bossKillElapsedSeconds, cfg)
			cleanPlayBonus = computeCleanPlayBonus(finalDamageTaken, cleanDamageBudget, cfg)
			finalRewardBudget = math.floor(baseCombatBudget * bossKillSpeedMultiplier) + cleanPlayBonus
		else
			finalRewardBudget = baseCombatBudget
			local cap = num(cfg, "FailureBudgetCap", 20)
			finalRewardBudget = math.min(finalRewardBudget, cap)
		end
	end

	local materialsGranted
	if success then
		materialsGranted = convertSuccessMaterials(finalRewardBudget, cfg)
	else
		materialsGranted = convertFailureMaterials(finalRewardBudget)
	end

	local totalMaterialCostValue = RunRewardBudgetPolicy.computeTotalMaterialCostValue(materialsGranted)
	local ancientShardGranted = RunRewardBudgetPolicy.computeAncientShardFromMaterials(materialsGranted, cfg)
	local currenciesGranted = { ancient_shard = ancientShardGranted }

	return {
		materialsGranted = sanitizeMaterialsGranted(materialsGranted),
		currenciesGranted = sanitizeCurrenciesGranted(currenciesGranted),
		rewardBudget = {
			success = success,
			baseCombatBudget = baseCombatBudget,
			bossKillSpeedMultiplier = bossKillSpeedMultiplier,
			cleanPlayBonus = cleanPlayBonus,
			finalRewardBudget = finalRewardBudget,
			finalDamageTaken = finalDamageTaken,
			bossKillElapsedSeconds = success and bossKillElapsedSeconds or nil,
			normalKills = normalKills,
			eliteKills = eliteKills,
			bossKills = bossKills,
			totalMaterialCostValue = totalMaterialCostValue,
			ancientShardGranted = ancientShardGranted,
		},
	}
end

return RunRewardBudgetPolicy

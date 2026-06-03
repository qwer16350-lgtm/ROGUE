-- Block chance for contact-defense MVP (generic RelicDefinitions blockChance modifiers).
-- Pure resolver: no ProgressionService / server dependencies.

local RelicDefinitions = require(script.Parent:WaitForChild("RelicDefinitions"))

local BlockChanceResolver = {}

--- Block MVP is not limited to a specific weapon run.
function BlockChanceResolver.isBlockCapable(_activeWeapons: any, _primaryWeaponId: string?): boolean
	return true
end

local function applyMulAdd(current: number, operation: string, value: number): number
	if operation == "mul" then
		return current * value
	end
	if operation == "add" then
		return current + value
	end
	return current
end

local function applyOpenOrAdd(current: number, openValue: number, addValue: number): number
	if current <= 0 then
		return openValue
	end
	return current + addValue
end

local function applyAddMulBlockChanceModifiers(chance: number, phase3ActiveRelicIds: { string }?): number
	if type(phase3ActiveRelicIds) ~= "table" then
		return chance
	end
	for _, relicId in ipairs(phase3ActiveRelicIds) do
		if type(relicId) ~= "string" or relicId == "" then
			continue
		end
		local def = RelicDefinitions.getDefinition(relicId)
		if type(def) ~= "table" then
			continue
		end
		local modifiers = def.modifiers
		if type(modifiers) ~= "table" then
			continue
		end
		for _, mod in ipairs(modifiers) do
			if type(mod) ~= "table" or mod.stat ~= "blockChance" then
				continue
			end
			if mod.requiresTuning == true then
				continue
			end
			local op = mod.operation
			if op ~= "add" and op ~= "mul" then
				continue
			end
			if type(op) ~= "string" or RelicDefinitions.ALLOWED_OPERATIONS[op] ~= true then
				continue
			end
			if type(mod.value) ~= "number" then
				continue
			end
			chance = applyMulAdd(chance, op, mod.value)
		end
	end
	return chance
end

local function applyOpenOrAddBlockChanceModifiers(chance: number, phase3ActiveRelicIds: { string }?): number
	if type(phase3ActiveRelicIds) ~= "table" then
		return chance
	end
	for _, relicId in ipairs(phase3ActiveRelicIds) do
		if type(relicId) ~= "string" or relicId == "" then
			continue
		end
		local def = RelicDefinitions.getDefinition(relicId)
		if type(def) ~= "table" then
			continue
		end
		local modifiers = def.modifiers
		if type(modifiers) ~= "table" then
			continue
		end
		for _, mod in ipairs(modifiers) do
			if type(mod) ~= "table" or mod.stat ~= "blockChance" then
				continue
			end
			if mod.requiresTuning == true then
				continue
			end
			if mod.operation ~= "openOrAdd" then
				continue
			end
			if type(mod.openValue) ~= "number" or type(mod.addValue) ~= "number" then
				continue
			end
			chance = applyOpenOrAdd(chance, mod.openValue, mod.addValue)
		end
	end
	return chance
end

export type ResolveContext = {
	activeWeapons: { [string]: any }?,
	primaryWeaponId: string?,
	phase3ActiveRelicIds: { string }?,
	gameConfig: any?,
}

export type ResolveResult = {
	blockCapable: boolean,
	effectiveBlockChance: number,
}

--- Base from GameConfig; add/mul modifiers first, then openOrAdd (e.g. Reinforced Shield Rim).
function BlockChanceResolver.resolve(ctx: ResolveContext): ResolveResult
	local phase3ActiveRelicIds = ctx.phase3ActiveRelicIds
	local gameConfig = ctx.gameConfig

	local blockDef = type(gameConfig) == "table" and gameConfig.BlockDefense or nil
	local baseChance = 0
	if type(blockDef) == "table" and type(blockDef.BaseBlockChance) == "number" then
		baseChance = blockDef.BaseBlockChance
	end

	local chance = applyAddMulBlockChanceModifiers(baseChance, phase3ActiveRelicIds)
	chance = applyOpenOrAddBlockChanceModifiers(chance, phase3ActiveRelicIds)

	chance = math.clamp(chance, 0, 1)
	local capable = chance > 0
	return { blockCapable = capable, effectiveBlockChance = chance }
end

return BlockChanceResolver

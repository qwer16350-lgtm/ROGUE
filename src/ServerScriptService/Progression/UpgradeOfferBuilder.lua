--- 레벨업 Upgrade 선택지 생성 (pending / Remote / Player 무관 순수 로직)

local UpgradeOfferBuilder = {}

local function weightForChoice(choice: { Id: string, Label: string }, weightsMap: { [string]: number }): number
	local w = weightsMap[choice.Id]
	if type(w) == "number" and w > 0 then
		return w
	end
	return 1
end

--- SwordShield 풀에서 가중치 기반 비복원 추출 3개.
function UpgradeOfferBuilder.weightedPickThreeSwordShieldChoices(
	pool: { { Id: string, Label: string } },
	startingRelicId: string?,
	relicDataModule: { getSwordShieldUpgradePickWeights: (string?) -> { [string]: number } }?
): { { Id: string, Label: string } }
	local n = #pool
	if n < 3 then
		error("[UpgradeOfferBuilder] level-up choice pool must have at least 3 entries")
	end
	local weightsMap: { [string]: number } = {}
	if relicDataModule then
		weightsMap = relicDataModule.getSwordShieldUpgradePickWeights(startingRelicId)
	end
	if type(weightsMap) ~= "table" then
		weightsMap = {}
	end

	local remaining = {}
	for i = 1, n do
		remaining[i] = pool[i]
	end

	local picked: { { Id: string, Label: string } } = {}
	for _ = 1, 3 do
		local total = 0
		local effW: { number } = {}
		for i, choice in ipairs(remaining) do
			local w = weightForChoice(choice, weightsMap)
			effW[i] = w
			total += w
		end
		if total <= 0 then
			total = 0
			for i = 1, #remaining do
				effW[i] = 1
				total += 1
			end
		end

		local r = math.random() * total
		local acc = 0
		local pickIdx = #remaining
		for i = 1, #remaining do
			acc += effW[i]
			if r < acc then
				pickIdx = i
				break
			end
		end

		local ch = remaining[pickIdx]
		table.insert(picked, { Id = ch.Id, Label = ch.Label })
		table.remove(remaining, pickIdx)
	end
	return picked
end

--- poolWeaponId 는 "SwordShield" | "BasicMagic" 만 가정 (호출부에서 effective 로 보정).
function UpgradeOfferBuilder.buildUpgradeOffer(
	poolWeaponId: string,
	startingRelicId: string?,
	upgradeData: any,
	relicDataModule: { getSwordShieldUpgradePickWeights: (string?) -> { [string]: number } }?
): ({ { Id: string, Label: string } }, { [string]: boolean })
	if poolWeaponId == "SwordShield" then
		local picked = UpgradeOfferBuilder.weightedPickThreeSwordShieldChoices(
			upgradeData.SwordShieldChoices,
			startingRelicId,
			relicDataModule
		)
		local allowed = {}
		for _, row in ipairs(picked) do
			allowed[row.Id] = true
		end
		return picked, allowed
	end

	local picked = {}
	for _, choice in ipairs(upgradeData.Choices) do
		table.insert(picked, { Id = choice.Id, Label = choice.Label })
	end
	local allowed = {}
	for _, row in ipairs(picked) do
		allowed[row.Id] = true
	end
	return picked, allowed
end

return UpgradeOfferBuilder

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RunConstants = require(Shared:WaitForChild("Run"):WaitForChild("RunConstants"))
local RelicDefinitions = require(Shared:WaitForChild("RelicDefinitions"))
local RunRewardBudgetPolicy = require(Shared:WaitForChild("RunRewardBudgetPolicy"))

local ResultClient = {}

local function formatTime(totalSeconds)
	totalSeconds = math.max(0, math.floor(totalSeconds))
	local m = math.floor(totalSeconds / 60)
	local s = totalSeconds % 60
	return string.format("%d:%02d", m, s)
end

function ResultClient.init()
	local player = Players.LocalPlayer
	local event = ReplicatedStorage:WaitForChild("SessionResult")
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local stageFlow = remotes:WaitForChild("StageFlowRequest")

	event.OnClientEvent:Connect(function(data)
		local playerGui = player:WaitForChild("PlayerGui")
		local old = playerGui:FindFirstChild("SessionResultGui")
		if old then
			old:Destroy()
		end

		local floor       = data.Floor or 0
		local maxFloor    = data.MaxFloor or RunConstants.MaxFloor
		local isLastFloor = data.IsLastFloor == true
		local outcome     = data.Outcome
			or ((data.BossKilled == true) and RunConstants.Outcome.Clear or RunConstants.Outcome.Fail)
		local cleared     = (outcome == RunConstants.Outcome.Clear)
		local canAdvance  = data.CanAdvance == true

		local screenGui = Instance.new("ScreenGui")
		screenGui.Name = "SessionResultGui"
		screenGui.ResetOnSpawn = false
		screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		screenGui.DisplayOrder = 50
		screenGui.Parent = playerGui

		local frame = Instance.new("Frame")
		frame.Name = "Panel"
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Position = UDim2.fromScale(0.5, 0.5)
		frame.Size = UDim2.fromOffset(360, 400)
		frame.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
		frame.BorderSizePixel = 0
		frame.Parent = screenGui

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = frame

		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 6)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.Parent = frame

		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 14)
		pad.PaddingBottom = UDim.new(0, 14)
		pad.PaddingLeft = UDim.new(0, 16)
		pad.PaddingRight = UDim.new(0, 16)
		pad.Parent = frame


		
		local function formatBlueprintProgressGranted(summary)
			if type(summary) ~= "table" then
				return "(없음)"
			end
			local granted = summary.blueprintProgressGranted
			if type(granted) ~= "table" or not next(granted) then
				return "(없음)"
			end
			local lines = {}
			for blueprintId, amt in pairs(granted) do
				if type(blueprintId) == "string" and type(amt) == "number" and amt > 0 then
					local label = RelicDefinitions.getDisplayLabelForBlueprintId(blueprintId)
					table.insert(lines, string.format("%s +%d", label, math.floor(amt + 0.5)))
				end
			end
			table.sort(lines)
			if #lines == 0 then
				return "(없음)"
			end
			return table.concat(lines, ", ")
		end
		local function formatMaterialsGranted(summary)
			if type(summary) ~= "table" then
				return "(없음)"
			end
			local granted = summary.materialsGranted
			if type(granted) ~= "table" then
				return "(없음)"
			end
			local lines = {}
			for _, key in ipairs(RunRewardBudgetPolicy.CRAFT_MATERIAL_KEYS) do
				local amt = granted[key]
				if type(amt) == "number" and amt > 0 then
					local label = RunRewardBudgetPolicy.MATERIAL_DISPLAY_NAMES[key] or key
					table.insert(lines, string.format("%s +%d", label, math.floor(amt + 0.5)))
				end
			end
			if #lines == 0 then
				return "(없음)"
			end
			return table.concat(lines, ", ")
		end

		local function formatCurrenciesGranted(summary)
			if type(summary) ~= "table" then
				return "(없음)"
			end
			local granted = summary.currenciesGranted
			if type(granted) ~= "table" then
				return "(없음)"
			end
			local lines = {}
			for _, key in ipairs(RunRewardBudgetPolicy.CURRENCY_KEYS) do
				local amt = granted[key]
				if type(amt) == "number" and amt > 0 then
					local label = RunRewardBudgetPolicy.CURRENCY_DISPLAY_NAMES[key] or key
					table.insert(lines, string.format("%s +%d", label, math.floor(amt + 0.5)))
				end
			end
			if #lines == 0 then
				return "(없음)"
			end
			return table.concat(lines, ", ")
		end

		local function line(text, order, size)
			local label = Instance.new("TextLabel")
			label.LayoutOrder = order
			label.Size = UDim2.new(1, 0, 0, size or 22)
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.GothamMedium
			label.TextSize = 15
			label.TextColor3 = Color3.new(1, 1, 1)
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.TextWrapped = true
			label.Text = text
			label.Parent = frame
			return label
		end

		line("결과", 1, 26).Font = Enum.Font.GothamBold
		line(string.format("생존 시간: %s", formatTime(data.SurvivalSeconds or 0)), 2)
		line(string.format("처치 수: %d", data.KillCount or 0), 3)
		line(string.format("최종 레벨: %d", data.FinalLevel or 1), 4)

		local upsLines = {}
		for _, row in ipairs(data.Upgrades or {}) do
			table.insert(upsLines, string.format("• %s × %d", row.Id, row.Count))
		end
		local upsStr = #upsLines > 0 and table.concat(upsLines, "\n") or "(없음)"
		line("획득 업그레이드:\n" .. upsStr, 5, 72)

		local rewardSummary = data.RewardSummary
		local rewardStr = formatMaterialsGranted(rewardSummary)
		local currencyStr = formatCurrenciesGranted(rewardSummary)
		if type(rewardSummary) == "table" and rewardSummary.applied == false then
			rewardStr = rewardStr .. " (저장 실패)"
			currencyStr = currencyStr .. " (저장 실패)"
		end
		line("Materials: " .. rewardStr, 55, 28)
		line("Currency: " .. currencyStr, 57, 28)
		local blueprintStr = formatBlueprintProgressGranted(rewardSummary)
		if type(rewardSummary) == "table" and rewardSummary.blueprintGrantApplied == false then
			blueprintStr = blueprintStr .. " (저장 실패)"
		end
		line("Blueprints: " .. blueprintStr, 56, 28)

		local bossStr = (data.BossKilled == true) and "예" or "아니오"
		line("보스 처치: " .. bossStr, 6)

		line(string.format("현재 층: %d / %d", floor, maxFloor), 7)

		if not cleared then
			line("잠시 후 로비로 이동합니다", 8)
		elseif cleared and isLastFloor then
			line("최종 층 클리어. 잠시 후 로비로 이동합니다", 8)
		end

		local btnRow = Instance.new("Frame")
		btnRow.LayoutOrder = 10
		btnRow.Size = UDim2.new(1, 0, 0, 40)
		btnRow.BackgroundTransparency = 1
		btnRow.Parent = frame

		local btnLayout = Instance.new("UIListLayout")
		btnLayout.FillDirection = Enum.FillDirection.Horizontal
		btnLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		btnLayout.Padding = UDim.new(0, 10)
		btnLayout.Parent = btnRow

		local function makeButton(text, order, enabled)
			local b = Instance.new("TextButton")
			b.LayoutOrder = order
			b.Size = UDim2.fromOffset(150, 36)
			b.Text = text
			b.Font = Enum.Font.GothamMedium
			b.TextSize = 14
			b.AutoButtonColor = true
			b.Active = enabled
			b.TextTransparency = enabled and 0 or 0.45
			b.BackgroundColor3 = Color3.fromRGB(55, 55, 70)
			b.TextColor3 = Color3.new(1, 1, 1)
			b.BorderSizePixel = 0
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0, 6)
			c.Parent = b
			b.Parent = btnRow
			return b
		end

		local fired = false
		local function closeGui()
			if screenGui.Parent then
				screenGui:Destroy()
			end
		end

		local nextBtn = nil
		if canAdvance then
			nextBtn = makeButton("다음 층", 1, true)
		end
		local lobbyBtn = makeButton("로비로", 2, true)

		if nextBtn then
			nextBtn.MouseButton1Click:Connect(function()
				if fired then return end
				fired = true
				closeGui()
				stageFlow:FireServer({ Action = RunConstants.StageFlowAction.NextFloor })
			end)
		end

		lobbyBtn.MouseButton1Click:Connect(function()
			if fired then return end
			fired = true
			closeGui()
			stageFlow:FireServer({ Action = RunConstants.StageFlowAction.ReturnToLobby })
		end)
	end)
end

return ResultClient
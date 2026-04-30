
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local HUDClient = {}


local HEALTH_LERP_SPEED_DOWN = 5
local HEALTH_LERP_SPEED_UP = 2
local HEALTH_NUMBER_LERP_SPEED_DOWN = 2
local HEALTH_NUMBER_LERP_SPEED_UP = 3

local XP_LERP_SPEED = 3
local XP_LEVELUP_FILL_SPEED = 3

local TIMER_LERP_SPEED = 3

local XP_FILL_COMPLETE_EPS = 0.002

-- ---------------------------------------------------------------------------
-- 공통: 지수 스무딩 (매 프레임 안정적, tween 난사 없음)
-- ---------------------------------------------------------------------------

local function smoothToward(current, target, speed, dt)
	if speed <= 0 or dt <= 0 then
		return target
	end
	local alpha = 1 - math.exp(-speed * math.min(dt, 0.05))
	return current + (target - current) * alpha
end

local function clamp01(x)
	return math.clamp(x, 0, 1)
end

local function setBarRatio(barBg, ratio)
	if not barBg or not barBg:IsA("GuiObject") then
		return
	end
	ratio = clamp01(ratio)
	local fill = barBg:FindFirstChild("Fill", true)
	if fill and fill:IsA("GuiObject") then
		fill.Size = UDim2.new(ratio, 0, 1, 0)
	end
end

local function formatTimeSmooth(totalSeconds)
	totalSeconds = math.max(0, totalSeconds)
	local m = math.floor(totalSeconds / 60)
	local s = totalSeconds % 60
	return string.format("%d:%04.1f", m, s)
end

local function waitForChildTimeout(parent, name, timeoutSec)
	local deadline = tick() + (timeoutSec or 60)
	repeat
		local inst = parent:FindFirstChild(name)
		if inst then
			return inst
		end
		task.wait(0.1)
	until tick() >= deadline
	return parent:FindFirstChild(name)
end

function HUDClient.init()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local mainHUD = waitForChildTimeout(playerGui, "MainHUD", 60)
	if not mainHUD then
		warn("[HUDClient] MainHUD 가 PlayerGui 에 없습니다.")
		return
	end

	local hudFrame = waitForChildTimeout(mainHUD, "HUDFrame", 60)
	if not hudFrame then
		warn("[HUDClient] HUDFrame 없음 — 레벨/XP 표시 비활성.")
	end

	local levelLabel = hudFrame and hudFrame:FindFirstChild("LevelLabel", true)
	local xpLabel = hudFrame and hudFrame:FindFirstChild("XPLabel", true)
	local xpBarBg = hudFrame and hudFrame:FindFirstChild("XPBarBG", true)
	local healthLabel = hudFrame and hudFrame:FindFirstChild("HealthLabel", true)
	local healthBarBg = hudFrame and hudFrame:FindFirstChild("HealthBarBG", true)
	if hudFrame and not healthLabel then
		warn("[HUDClient] HealthLabel 을 HUDFrame 아래에서 찾지 못했습니다. 이름·부모 구조를 확인하세요.")
	end

	local timerBarRoot = waitForChildTimeout(mainHUD, "TimerBarRoot", 60)
	if not timerBarRoot then
		warn("[HUDClient] TimerBarRoot 없음 — 타이머 표시 비활성.")
	end
	local timerLabel = timerBarRoot and timerBarRoot:FindFirstChild("TimerLabel", true)
	local timerBarBg = timerBarRoot and timerBarRoot:FindFirstChild("TimerBarBG", true)
	local stageLabel = timerBarRoot and timerBarRoot:FindFirstChild("StageLabel", true)

	local hudEvent = ReplicatedStorage:WaitForChild("HudState")

	-- ---- 표시/목표 상태 (Humanoid) ----
	local targetHealth = 0
	local targetMaxHealth = 1
	local targetHealthRatio = 0
	local displayedHealthRatio = 0
	local displayedHealthNumber = 0

	local function applyHealthTargetsFromHumanoid(humanoid)
		local hp = humanoid.Health
		local maxHp = humanoid.MaxHealth > 0 and humanoid.MaxHealth or 1
		targetHealth = hp
		targetMaxHealth = maxHp
		targetHealthRatio = clamp01(hp / maxHp)
	end

	-- ---- 표시/목표 상태 (HudState) ----
	local hudTargetLevel = 1
	local hudTargetXp = 0
	local hudTargetXpToNext = 1
	local hudTargetXpRatio = 0
	local displayedXpRatio = 0
	local lastHudLevelSeen = 1
	local xpPhase = "normal"

	local hudSessionActive = true
	local hudSessionLength = 300
	local hudStageIndex = 1
	local timerAnchorTick = 0
	local timerAnchorRemaining = 0
	local displayedTimerRemaining = 0

	local hudDataInitialized = false

	local function recomputeTimerTargetRemaining()
		if not hudSessionActive then
			return 0
		end
		return math.max(0, timerAnchorRemaining - (tick() - timerAnchorTick))
	end

	local function ingestHudPayload(payload)
		hudTargetLevel = payload.Level or 1
		hudTargetXp = payload.Xp or 0
		hudTargetXpToNext = math.max(1, payload.XpToNext or 1)
		hudSessionActive = payload.SessionActive ~= false
		hudSessionLength = math.max(1, payload.SessionLengthSeconds or 300)
		hudStageIndex = math.max(1, payload.StageIndex or 1)

		local newRatio = hudTargetXp / hudTargetXpToNext
		hudTargetXpRatio = clamp01(newRatio)

		timerAnchorTick = tick()
		timerAnchorRemaining = math.max(0, payload.SecondsLeft or 0)

		if not hudDataInitialized then
			displayedXpRatio = hudTargetXpRatio
			lastHudLevelSeen = hudTargetLevel
			xpPhase = "normal"
			displayedTimerRemaining = timerAnchorRemaining
			hudDataInitialized = true
		else
			if hudTargetLevel > lastHudLevelSeen then
				xpPhase = "fillToFull"
				lastHudLevelSeen = hudTargetLevel
			elseif hudTargetLevel < lastHudLevelSeen then
				lastHudLevelSeen = hudTargetLevel
				xpPhase = "normal"
				displayedXpRatio = hudTargetXpRatio
			end
		end

		if levelLabel and levelLabel:IsA("TextLabel") then
			levelLabel.Text = string.format("레벨 %d", hudTargetLevel)
		end
		if xpLabel and xpLabel:IsA("TextLabel") then
			xpLabel.Text = string.format("XP %d / %d", hudTargetXp, hudTargetXpToNext)
		end
		if timerLabel and timerLabel:IsA("TextLabel") then
			if hudSessionActive then
				timerLabel.Text = string.format("남은 시간 %s", formatTimeSmooth(displayedTimerRemaining))
			else
				timerLabel.Text = "세션 종료"
			end
		end
		if stageLabel and stageLabel:IsA("TextLabel") then
			stageLabel.Text = string.format("Stage %d", hudStageIndex)
		end

		setBarRatio(healthBarBg, displayedHealthRatio)
		setBarRatio(xpBarBg, displayedXpRatio)
		local tRatio = hudSessionLength > 0 and (displayedTimerRemaining / hudSessionLength) or 0
		setBarRatio(timerBarBg, tRatio)
	end

	-- Roblox 기본 체력 UI 억제
	playerGui.ChildAdded:Connect(function(child)
		if child.Name == "Health" and child:IsA("ScreenGui") then
			child.Enabled = false
		end
	end)

	local function suppressDefaultRobloxHealthUi(humanoid)
		if humanoid and humanoid.Parent then
			humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		end
		pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
		end)
		local h = playerGui:FindFirstChild("Health")
		if h and h:IsA("ScreenGui") then
			h.Enabled = false
		end
	end

	suppressDefaultRobloxHealthUi(nil)

	local humanoidConns = {}

	local function clearHumanoidConns()
		for _, c in ipairs(humanoidConns) do
			c:Disconnect()
		end
		humanoidConns = {}
	end

	local function bindHumanoid(humanoid)
		clearHumanoidConns()
		if not humanoid then
			return
		end

		local function refreshTargets()
			applyHealthTargetsFromHumanoid(humanoid)
		end

		refreshTargets()
		displayedHealthRatio = targetHealthRatio
		displayedHealthNumber = targetHealth

		table.insert(humanoidConns, humanoid:GetPropertyChangedSignal("Health"):Connect(refreshTargets))
		table.insert(humanoidConns, humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(function()
			refreshTargets()
		end))
		table.insert(humanoidConns, humanoid.HealthChanged:Connect(refreshTargets))

		local delayTimes = { 0, 0.05, 0.1, 0.25, 0.5, 1, 2 }
		for _, sec in ipairs(delayTimes) do
			task.delay(sec, function()
				if humanoid.Parent then
					suppressDefaultRobloxHealthUi(humanoid)
				end
			end)
		end
	end

	local function bindCharacter(character)
		if not character then
			clearHumanoidConns()
			return
		end
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid and humanoid:IsA("Humanoid") then
			bindHumanoid(humanoid)
		end
	end

	player.CharacterAdded:Connect(bindCharacter)
	if player.Character then
		task.spawn(bindCharacter, player.Character)
	end

	hudEvent.OnClientEvent:Connect(ingestHudPayload)

	RunService.RenderStepped:Connect(function(dt)
		-- ---- Health ----
		local hpBarSpeed = (targetHealthRatio < displayedHealthRatio) and HEALTH_LERP_SPEED_DOWN
			or HEALTH_LERP_SPEED_UP
		displayedHealthRatio = smoothToward(displayedHealthRatio, targetHealthRatio, hpBarSpeed, dt)

		local numSpeed = (targetHealth < displayedHealthNumber) and HEALTH_NUMBER_LERP_SPEED_DOWN
			or HEALTH_NUMBER_LERP_SPEED_UP
		displayedHealthNumber = smoothToward(displayedHealthNumber, targetHealth, numSpeed, dt)

		if healthLabel and healthLabel:IsA("TextLabel") then
			healthLabel.Text = string.format(
				"HP %d / %d",
				math.floor(displayedHealthNumber + 0.5),
				math.floor(targetMaxHealth + 0.5)
			)
		end
		setBarRatio(healthBarBg, displayedHealthRatio)

		-- ---- XP bar ----
		if xpPhase == "fillToFull" then
			displayedXpRatio = smoothToward(displayedXpRatio, 1, XP_LEVELUP_FILL_SPEED, dt)
			if displayedXpRatio >= 1 - XP_FILL_COMPLETE_EPS then
				displayedXpRatio = hudTargetXpRatio
				xpPhase = "normal"
			end
		else
			displayedXpRatio = smoothToward(displayedXpRatio, hudTargetXpRatio, XP_LERP_SPEED, dt)
		end
		setBarRatio(xpBarBg, displayedXpRatio)

		-- ---- Timer ----
		local timerTarget = recomputeTimerTargetRemaining()
		displayedTimerRemaining = smoothToward(displayedTimerRemaining, timerTarget, TIMER_LERP_SPEED, dt)

		if timerLabel and timerLabel:IsA("TextLabel") then
			if hudSessionActive then
				timerLabel.Text = string.format("남은 시간 %s", formatTimeSmooth(displayedTimerRemaining))
			else
				timerLabel.Text = "세션 종료"
			end
		end
		local tr = hudSessionLength > 0 and (displayedTimerRemaining / hudSessionLength) or 0
		setBarRatio(timerBarBg, clamp01(tr))
	end)
end

return HUDClient

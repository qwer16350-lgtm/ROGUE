
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local HUDClient = {}

local SS_KEYS_ORDERED = {
	"ss_common_damage",
	"ss_common_cooldown",
	"ss_sweep_angle",
	"ss_sweep_damage",
	"ss_sweep_range",
	"ss_thrust_damage",
	"ss_thrust_range",
}

local function strRelic(id)
	if id == nil or id == "" then
		return "-"
	end
	return tostring(id)
end

local function fmtDevNum(v)
	if type(v) ~= "number" then
		return "-"
	end
	return string.format("%.4g", v)
end

local function fmtDevScalar(v)
	if v == nil then
		return "-"
	end
	return tostring(v)
end

local function formatSsUpgrade(v)
	if type(v) == "number" then
		return tostring(math.max(0, math.floor(v + 0.5)))
	end
	return "-"
end

local BUILD_TAG_DISPLAY_LIMIT = 24

local function formatTagCountsLine(tagCounts: any): string
	if type(tagCounts) ~= "table" then
		return "-"
	end
	local entries = {}
	for tag, count in pairs(tagCounts) do
		if type(tag) == "string" and type(count) == "number" and count > 0 then
			table.insert(entries, { tag = tag, count = count })
		end
	end
	table.sort(entries, function(a, b)
		if a.count ~= b.count then
			return a.count > b.count
		end
		return a.tag < b.tag
	end)
	local chunks = {}
	local limit = math.min(#entries, BUILD_TAG_DISPLAY_LIMIT)
	for i = 1, limit do
		local e = entries[i]
		table.insert(chunks, string.format("%s: %d", e.tag, e.count))
	end
	if #entries > limit then
		table.insert(chunks, string.format("... +%d more", #entries - limit))
	end
	if #chunks == 0 then
		return "-"
	end
	return table.concat(chunks, ", ")
end

local function formatPhase3RelicIdsLine(ids: any): string
	if type(ids) ~= "table" or #ids == 0 then
		return "-"
	end
	local chunks = {}
	for _, relicId in ipairs(ids) do
		if type(relicId) == "string" and relicId ~= "" then
			table.insert(chunks, relicId)
		end
	end
	if #chunks == 0 then
		return "-"
	end
	return table.concat(chunks, ", ")
end

local function formatClassScoresLine(scores: any): string
	if type(scores) ~= "table" then
		return "Guardian=- Slayer=- Lancer=-"
	end
	return string.format(
		"Guardian=%s Slayer=%s Lancer=%s",
		fmtDevScalar(scores.Guardian),
		fmtDevScalar(scores.Slayer),
		fmtDevScalar(scores.Lancer)
	)
end

local DEV_COMBAT_COLUMN_WIDTH_PX = 300

local function devCombatLinesToText(lines: { string }): string
	return table.concat(lines, "\n")
end

local function formatDevCombat(dc)
	if type(dc) ~= "table" then
		return { left = "[DevCombat]\n(invalid)", right = "" }
	end
	local leftLines: { string } = {}
	local rightLines: { string } = {}
	table.insert(leftLines, "[DevCombat]")
	table.insert(leftLines, string.format("WeaponId: %s", fmtDevScalar(dc.WeaponId)))
	table.insert(leftLines, string.format("WeaponGrade: %s", dc.WeaponGrade ~= nil and tostring(dc.WeaponGrade) or "-"))
	local aw = dc.ActiveWeapons
	if type(aw) == "table" and #aw > 0 then
		local chunks = {}
		for _, it in ipairs(aw) do
			if type(it) == "table" then
				local wid = fmtDevScalar(it.WeaponId)
				local grade = fmtDevScalar(it.Grade)
				table.insert(chunks, string.format("%s(%s)", wid, grade))
			end
		end
		if #chunks > 0 then
			table.insert(leftLines, string.format("ActiveWeapons: %s", table.concat(chunks, ", ")))
		end
	end
	local weaponId = dc.WeaponId
	local isBasic = weaponId == "BasicMagic"
	local isSword = weaponId == "SwordShield"
	if isBasic then
		table.insert(leftLines, "(BasicMagic 럼 — 유물 미표시)")
	else
		table.insert(
			leftLines,
			string.format("Phase3ActiveRelicIds: %s", formatPhase3RelicIdsLine(dc.Phase3ActiveRelicIds))
		)
	end
	table.insert(leftLines, "--- upgrades (ss_*) ---")
	for _, k in ipairs(SS_KEYS_ORDERED) do
		table.insert(leftLines, string.format("%s: %s", k, formatSsUpgrade(dc[k])))
	end
	local hasAnyEffective = false
	if isSword and type(dc.SwordShieldEffective) == "table" then
		hasAnyEffective = true
		local eff = dc.SwordShieldEffective
		table.insert(leftLines, "--- SwordShieldEffective ---")
		table.insert(leftLines, string.format("AttackIntervalSeconds: %s", fmtDevNum(eff.AttackIntervalSeconds)))
		local sw = eff.Sweep
		if type(sw) == "table" then
			table.insert(leftLines, string.format("Sweep.BaseDamage: %s", fmtDevNum(sw.BaseDamage)))
			table.insert(leftLines, string.format("Sweep.RangeStuds: %s", fmtDevNum(sw.RangeStuds)))
			table.insert(leftLines, string.format("Sweep.AngleDeg: %s", fmtDevNum(sw.AngleDeg)))
			table.insert(leftLines, string.format("Sweep.KnockbackPower: %s", fmtDevNum(sw.KnockbackPower)))
		end
		local th = eff.Thrust
		if type(th) == "table" then
			table.insert(leftLines, string.format("Thrust.BaseDamage: %s", fmtDevNum(th.BaseDamage)))
			table.insert(leftLines, string.format("Thrust.RangeStuds: %s", fmtDevNum(th.RangeStuds)))
			table.insert(leftLines, string.format("Thrust.WidthStuds: %s", fmtDevNum(th.WidthStuds)))
		end
	end
	if type(dc.BasicMagicEffective) == "table" then
		hasAnyEffective = true
		local bm = dc.BasicMagicEffective
		table.insert(leftLines, "--- BasicMagicEffective ---")
		table.insert(leftLines, string.format("damagePerHit: %s", fmtDevNum(bm.damagePerHit)))
		table.insert(leftLines, string.format("attackIntervalSeconds: %s", fmtDevNum(bm.attackIntervalSeconds)))
		table.insert(leftLines, string.format("attackRangeStuds: %s", fmtDevNum(bm.attackRangeStuds)))
	end
	if type(dc.SpearEffective) == "table" then
		hasAnyEffective = true
		local sp = dc.SpearEffective
		table.insert(leftLines, "--- SpearEffective ---")
		table.insert(leftLines, string.format("Grade: %s", fmtDevScalar(sp.Grade)))
		table.insert(leftLines, string.format("BaseDamage: %s", fmtDevNum(sp.BaseDamage)))
		table.insert(leftLines, string.format("AttackIntervalSeconds: %s", fmtDevNum(sp.AttackIntervalSeconds)))
		table.insert(leftLines, string.format("RangeStuds: %s", fmtDevNum(sp.RangeStuds)))
		table.insert(leftLines, string.format("WidthStuds: %s", fmtDevNum(sp.WidthStuds)))
		table.insert(leftLines, string.format("TargetLimit: %s", fmtDevNum(sp.TargetLimit)))
		table.insert(leftLines, string.format("sp_thrust_damage: %s", formatSsUpgrade(sp.sp_thrust_damage)))
		table.insert(leftLines, string.format("sp_thrust_range: %s", formatSsUpgrade(sp.sp_thrust_range)))
	end
	if type(dc.TwoHandedSwordEffective) == "table" then
		hasAnyEffective = true
		local tw = dc.TwoHandedSwordEffective
		table.insert(leftLines, "--- TwoHandedSwordEffective ---")
		table.insert(leftLines, string.format("Grade: %s", fmtDevScalar(tw.Grade)))
		table.insert(leftLines, string.format("BaseDamage: %s", fmtDevNum(tw.BaseDamage)))
		table.insert(leftLines, string.format("AttackIntervalSeconds: %s", fmtDevNum(tw.AttackIntervalSeconds)))
		table.insert(leftLines, string.format("RangeStuds: %s", fmtDevNum(tw.RangeStuds)))
		table.insert(leftLines, string.format("AngleDeg: %s", fmtDevNum(tw.AngleDeg)))
		table.insert(leftLines, string.format("TargetLimit: %s", fmtDevNum(tw.TargetLimit)))
		table.insert(leftLines, string.format("th_sweep_damage: %s", formatSsUpgrade(tw.th_sweep_damage)))
		table.insert(leftLines, string.format("th_sweep_range: %s", formatSsUpgrade(tw.th_sweep_range)))
	end
	if not hasAnyEffective then
		table.insert(leftLines, "SwordShieldEffective: --")
		table.insert(leftLines, "BasicMagicEffective: --")
		table.insert(leftLines, "SpearEffective: --")
		table.insert(leftLines, "TwoHandedSwordEffective: --")
	end
	local buildTag = dc.BuildTag
	if type(buildTag) == "table" then
		table.insert(rightLines, "--- BuildTag ---")
		table.insert(rightLines, formatTagCountsLine(buildTag.TagCounts))
		table.insert(rightLines, string.format("Phase3RelicIds: %s", formatPhase3RelicIdsLine(buildTag.Phase3RelicIds)))
	end
	local classDetection = dc.ClassDetection
	if type(classDetection) == "table" then
		table.insert(rightLines, "--- ClassDetection ---")
		table.insert(rightLines, string.format("DetectedClass: %s", fmtDevScalar(classDetection.DetectedClass)))
		table.insert(rightLines, string.format("Scores: %s", formatClassScoresLine(classDetection.Scores)))
		table.insert(rightLines, string.format("PrimaryWeaponId: %s", fmtDevScalar(classDetection.PrimaryWeaponId)))
		table.insert(rightLines, string.format("TieBreak: %s", fmtDevScalar(classDetection.TieBreakNote)))
	end
	local classEffects = dc.ClassEffects
	if type(classEffects) == "table" then
		table.insert(rightLines, "--- ClassEffects ---")
		table.insert(rightLines, string.format("ActiveClass: %s", fmtDevScalar(classEffects.ActiveClass)))
		table.insert(rightLines, string.format("damageTakenMultiplier: %s", fmtDevNum(classEffects.damageTakenMultiplier)))
		table.insert(rightLines, string.format("sweepBaseDamageMul: %s", fmtDevNum(classEffects.sweepBaseDamageMul)))
		table.insert(rightLines, string.format("attackIntervalSecondsMul: %s", fmtDevNum(classEffects.attackIntervalSecondsMul)))
	end
	local blockDefense = dc.BlockDefense
	if type(blockDefense) == "table" then
		table.insert(rightLines, "--- BlockDefense ---")
		table.insert(rightLines, string.format("blockCapable: %s", fmtDevScalar(blockDefense.blockCapable)))
		table.insert(rightLines, string.format("effectiveBlockChance: %s", fmtDevNum(blockDefense.effectiveBlockChance)))
		table.insert(rightLines, string.format("blockCooldownRemaining: %s", fmtDevNum(blockDefense.blockCooldownRemaining)))
		table.insert(rightLines, string.format("blockCooldownUntil: %s", fmtDevNum(blockDefense.blockCooldownUntil)))
		table.insert(rightLines, string.format("lastBlockSuccessAt: %s", fmtDevNum(blockDefense.lastBlockSuccessAt)))
	end
	local runInfo = dc.Run
	if type(runInfo) == "table" then
		table.insert(rightLines, "--- Run ---")
		table.insert(rightLines, string.format("DefaultWeaponId: %s", fmtDevScalar(runInfo.DefaultWeaponId)))
	end
	local dbgInfo = dc.Debug
	if type(dbgInfo) == "table" then
		table.insert(rightLines, "--- Debug ---")
		table.insert(rightLines, string.format("OverrideWeaponId: %s", fmtDevScalar(dbgInfo.OverrideWeaponId)))
		table.insert(rightLines, string.format("ShowAttackRanges: %s", fmtDevScalar(dbgInfo.ShowAttackRanges)))
		table.insert(rightLines, string.format("ShowDevCombatPanel: %s", fmtDevScalar(dbgInfo.ShowDevCombatPanel)))
	end
	table.insert(rightLines, string.format("WeaponDropChance: %s", fmtDevScalar(dc.WeaponDropChance)))
	table.insert(rightLines, string.format("WeaponDropChanceOverride: %s", fmtDevScalar(dc.WeaponDropChanceOverride)))
	return { left = devCombatLinesToText(leftLines), right = devCombatLinesToText(rightLines) }
end

local HEALTH_LERP_SPEED_DOWN = 5
local HEALTH_LERP_SPEED_UP = 2
local HEALTH_NUMBER_LERP_SPEED_DOWN = 2
local HEALTH_NUMBER_LERP_SPEED_UP = 3

local XP_LERP_SPEED = 3
local XP_LEVELUP_FILL_SPEED = 3

local TIMER_LERP_SPEED = 3

local XP_FILL_COMPLETE_EPS = 0.002

-- ---------------------------------------------------------------------------
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

local HUDSTATE_WAIT_TIMEOUT_SEC = 60

function HUDClient.init()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

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

	local hudEvent = waitForChildTimeout(ReplicatedStorage, "HudState", HUDSTATE_WAIT_TIMEOUT_SEC)
	if not hudEvent or not hudEvent:IsA("RemoteEvent") then
		warn(
			string.format(
				"[HUDClient] HudState RemoteEvent 없음 또는 대기 타임아웃(%ds). 커스텀 HUD/Dev 패널은 건너뜁니다. 기본 체력바 숨김은 적용된 상태입니다.",
				HUDSTATE_WAIT_TIMEOUT_SEC
			)
		)
		return
	end

	local devCombatGui = Instance.new("ScreenGui")
	devCombatGui.Name = "DevCombatPanel"
	devCombatGui.ResetOnSpawn = false
	devCombatGui.DisplayOrder = 100
	devCombatGui.IgnoreGuiInset = true
	devCombatGui.Enabled = false
	devCombatGui.Parent = playerGui

	local devCombatFrame = Instance.new("Frame")
	devCombatFrame.Name = "DevCombatFrame"
	devCombatFrame.AnchorPoint = Vector2.new(1, 0)
	devCombatFrame.Position = UDim2.new(1, -8, 0, 8)
	devCombatFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
	devCombatFrame.BackgroundTransparency = 0.35
	devCombatFrame.BorderSizePixel = 0
	devCombatFrame.AutomaticSize = Enum.AutomaticSize.XY
	devCombatFrame.Parent = devCombatGui

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.Parent = devCombatFrame

	local columnsFrame = Instance.new("Frame")
	columnsFrame.Name = "Columns"
	columnsFrame.BackgroundTransparency = 1
	columnsFrame.AutomaticSize = Enum.AutomaticSize.XY
	columnsFrame.Parent = devCombatFrame

	local columnsLayout = Instance.new("UIListLayout")
	columnsLayout.FillDirection = Enum.FillDirection.Horizontal
	columnsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	columnsLayout.Padding = UDim.new(0, 12)
	columnsLayout.Parent = columnsFrame

	local function makeDevCombatColumnLabel(name: string): TextLabel
		local label = Instance.new("TextLabel")
		label.Name = name
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.Code
		label.TextSize = 13
		label.TextColor3 = Color3.fromRGB(235, 235, 245)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Top
		label.TextWrapped = true
		label.ZIndex = 2
		label.MaxVisibleGraphemes = -1
		label.AutomaticSize = Enum.AutomaticSize.Y
		label.Size = UDim2.fromOffset(DEV_COMBAT_COLUMN_WIDTH_PX, 0)
		label.Parent = columnsFrame
		return label
	end

	local devCombatLabelLeft = makeDevCombatColumnLabel("DevCombatLabelLeft")
	local devCombatLabelRight = makeDevCombatColumnLabel("DevCombatLabelRight")

	local function updateDevCombatPanel(payload)
		local dc = payload and payload.DevCombat
		if type(dc) ~= "table" then
			devCombatGui.Enabled = false
			devCombatLabelLeft.Text = ""
			devCombatLabelRight.Text = ""
			return
		end
		local dbg = dc.Debug
		if type(dbg) == "table" and dbg.ShowDevCombatPanel == false then
			devCombatGui.Enabled = false
			devCombatLabelLeft.Text = ""
			devCombatLabelRight.Text = ""
			return
		end
		devCombatGui.Enabled = true
		local ok, textOrErr = pcall(formatDevCombat, dc)
		if ok and type(textOrErr) == "table" then
			devCombatLabelLeft.Text = textOrErr.left or ""
			devCombatLabelRight.Text = textOrErr.right or ""
		elseif ok then
			devCombatLabelLeft.Text = tostring(textOrErr)
			devCombatLabelRight.Text = ""
		else
			warn("[HUDClient] formatDevCombat 실패:", textOrErr)
			devCombatLabelLeft.Text = "[DevCombat]\n(표시 오류)"
			devCombatLabelRight.Text = ""
		end
	end

	local mainHUD = waitForChildTimeout(playerGui, "MainHUD", 60)
	if not mainHUD then
		warn("[HUDClient] MainHUD 가 PlayerGui 에 없습니다. — 기본 HUD 라벨 비활성 (DevCombat 패널은 HudState 가 오면 표시 가능).")
	end

	local hudFrame = mainHUD and waitForChildTimeout(mainHUD, "HUDFrame", 60)
	if mainHUD and not hudFrame then
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

	local timerBarRoot = mainHUD and waitForChildTimeout(mainHUD, "TimerBarRoot", 60)
	if mainHUD and not timerBarRoot then
		warn("[HUDClient] TimerBarRoot 없음 — 타이머 표시 비활성.")
	end
	local timerLabel = timerBarRoot and timerBarRoot:FindFirstChild("TimerLabel", true)
	local timerBarBg = timerBarRoot and timerBarRoot:FindFirstChild("TimerBarBG", true)
	local stageLabel = timerBarRoot and timerBarRoot:FindFirstChild("StageLabel", true)

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
		if type(payload) ~= "table" then
			updateDevCombatPanel(nil)
			return
		end
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

		updateDevCombatPanel(payload)
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
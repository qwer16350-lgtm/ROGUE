
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local VFXClient = {}

local DEFAULT_EMIT = 1

-- 이전 단발(0.07+0.14초)과 동일한 총 길이 안에서 흰색 점멸 횟수
local ENEMY_HIT_FLASH_TOTAL_SEC = 0.21
local ENEMY_HIT_FLASH_PULSES = 3
local ENEMY_HIT_FLASH_COLOR = Color3.fromRGB(255, 255, 255)

local enemyHitFlashState = setmetatable({}, { __mode = "k" })

-- 플레이어가 적과 접촉해 피격될 때 캐릭터 전체에 입히는 빨간 점멸.
-- 적 피격 점멸과 동일한 펄스 길이/횟수를 차용 — 색상만 빨강.
-- 단일 BasePart 가 아니라 캐릭터 전체에 일관된 오버레이를 입히기 위해
-- Highlight 인스턴스의 FillTransparency 를 펄스로 토글한다.
local PLAYER_HIT_FLASH_TOTAL_SEC = 0.21
local PLAYER_HIT_FLASH_PULSES = 3
local PLAYER_HIT_FLASH_COLOR = Color3.fromRGB(255, 0, 0)
-- 0 = 완전 빨강, 1 = 완전 투명. 0.35 → 강하게 보이되 캐릭터 실루엣 유지.
local PLAYER_HIT_FLASH_PEAK_TRANSPARENCY = 0.35

local playerHitFlashState = setmetatable({}, { __mode = "k" })
local warnedMissingAttackVfxLifetime = false
-- FollowAttacker 일 때: AttackerUserId → 현재 공격 클론(신규 공격 시 이전 클론 제거)
local activeAttackVfxByUserId = {}
local attackFollowBindSerial = 0


local EFFECTS = {
	attack = {
		FolderName = "Attack",
		PrefabName = "ATTACK",
		UseFade = false,
		UseBurst = true,
		LifecycleEndsWithDebris = true,
		FollowAttacker = true,
		FollowPartName = "HumanoidRootPart",
		ScaleByAttackRange = true,
	},
	hit = {
		FolderName = "Hit",
		PrefabName = nil,
		UseFade = true,
		UseBurst = true,
		LifecycleEndsWithDebris = false,
		FollowAttacker = false,
		ScaleByAttackRange = false,
		FadeIn = 0.05,
		Hold = 0.25,
		FadeOut = 0.15,
	},
	death = {
		FolderName = "Death",
		PrefabName = "DOTS",
		UseFade = true,
		UseBurst = true,
		LifecycleEndsWithDebris = false,
		FollowAttacker = false,
		ScaleByAttackRange = false,
		FadeIn = 0.1,
		Hold = 0.2,
		FadeOut = 0.3,
	},
}

local function localAxisFromLabel(label)
	if type(label) ~= "string" then
		return nil
	end
	local u = string.upper(label)
	if u == "X" then
		return Vector3.new(1, 0, 0)
	elseif u == "Y" then
		return Vector3.new(0, 1, 0)
	elseif u == "Z" then
		return Vector3.new(0, 0, 1)
	end
	return nil
end

local function findPrefab(vfxRoot, cfg)
	local folder = vfxRoot:FindFirstChild(cfg.FolderName)
	if not folder then
		return nil
	end

	if type(cfg.PrefabName) == "string" and cfg.PrefabName ~= "" then
		local named = folder:FindFirstChild(cfg.PrefabName)
		if named and (named:IsA("Model") or named:IsA("BasePart") or named:IsA("Attachment")) then
			return named
		end
		return nil
	end

	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("Model") or child:IsA("BasePart") or child:IsA("Attachment") then
			return child
		end
	end

	return nil
end

local function placeCloneAtPosition(clone, position)
	if clone:IsA("Model") then
		clone:PivotTo(CFrame.new(position))
		clone.Parent = Workspace
		return clone
	elseif clone:IsA("BasePart") then
		clone.Anchored = true
		clone.CanCollide = false
		clone.Position = position
		clone.Parent = Workspace
		return clone
	elseif clone:IsA("Attachment") then
		local anchor = Instance.new("Part")
		anchor.Name = "VfxAnchor"
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.Transparency = 1
		anchor.Size = Vector3.new(0.1, 0.1, 0.1)
		anchor.Position = position
		anchor.Parent = Workspace
		clone.Parent = anchor
		return anchor
	end

	clone:Destroy()
	return nil
end

local function scaleNumberSequenceByFactor(seq, k)
	local kps = {}
	for _, kp in ipairs(seq.Keypoints) do
		table.insert(kps, NumberSequenceKeypoint.new(kp.Time, kp.Value * k, kp.Envelope * k))
	end
	return NumberSequence.new(kps)
end

--- 공격 반경 배율 k (= 실제 판정 반경 / 기준 반경)에 맞춘 1차 보정. 연출 가중 없음.
--- 지오메트리는 ScaleTo/Part Size로 k배; 입자·빔 등은 아래 속성도 k배로 “보이는 거리/두께”를 판정과 선형 정렬.
--- Speed·Acceleration만 k배: Lifetime은 동시에 k배하지 않음(전파 거리가 k²로 가는 것 방지).
local function applyAttackVfxProportionalEffects(rootInstance, k)
	if type(k) ~= "number" or k <= 0 or k == 1 then
		return
	end
	for _, d in ipairs(rootInstance:GetDescendants()) do
		if d:IsA("ParticleEmitter") then
			d.Size = scaleNumberSequenceByFactor(d.Size, k)
			d.Squash = scaleNumberSequenceByFactor(d.Squash, k)
			local spd = d.Speed
			d.Speed = NumberRange.new(spd.Min * k, spd.Max * k)
			d.Acceleration = d.Acceleration * k
		elseif d:IsA("Beam") then
			d.Width0 = d.Width0 * k
			d.Width1 = d.Width1 * k
			d.CurveSize0 = d.CurveSize0 * k
			d.CurveSize1 = d.CurveSize1 * k
		elseif d:IsA("Trail") then
			d.WidthScale = scaleNumberSequenceByFactor(d.WidthScale, k)
		elseif d:IsA("BillboardGui") then
			local sz = d.Size
			d.Size = UDim2.new(sz.X.Scale, sz.X.Offset * k, sz.Y.Scale, sz.Y.Offset * k)
			d.StudsOffset = d.StudsOffset * k
			d.StudsOffsetWorldSpace = d.StudsOffsetWorldSpace * k
		elseif d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight") then
			d.Range *= k
		end
	end
end

local function applyAttackVfxRangeScale(rootInstance, radiusStuds, refRadiusStuds)
	if type(radiusStuds) ~= "number" or type(refRadiusStuds) ~= "number" or refRadiusStuds <= 0 then
		return
	end
	local k = math.clamp(radiusStuds / refRadiusStuds, 0.05, 50)

	if rootInstance:IsA("Model") then
		local ok = pcall(function()
			rootInstance:ScaleTo(k)
		end)
		if ok then
			applyAttackVfxProportionalEffects(rootInstance, k)
			return
		end
	end

	if rootInstance:IsA("BasePart") then
		local s = rootInstance.Size
		rootInstance.Size = Vector3.new(s.X * k, s.Y * k, s.Z * k)
		applyAttackVfxProportionalEffects(rootInstance, k)
		return
	end

	for _, d in ipairs(rootInstance:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Size = d.Size * k
		end
	end
	applyAttackVfxProportionalEffects(rootInstance, k)
end

local function parsePositiveNumberAttr(inst, attrName)
	if not inst then
		return nil
	end
	local v = inst:GetAttribute(attrName)
	if type(v) == "number" and v > 0 then
		return v
	end
	if type(v) == "string" then
		local n = tonumber(v)
		if type(n) == "number" and n > 0 then
			return n
		end
	end
	return nil
end

local function getVfxReferenceRadiusStuds(rootInstance)
	local r = parsePositiveNumberAttr(rootInstance, "VfxReferenceRadius")
	if r then
		return r
	end
	for _, d in ipairs(rootInstance:GetDescendants()) do
		r = parsePositiveNumberAttr(d, "VfxReferenceRadius")
		if r then
			return r
		end
	end
	return nil
end

local function collectFadeParts(root)
	local parts = {}

	local function add(p)
		if p:IsA("BasePart") and p.Name ~= "VfxAnchor" then
			table.insert(parts, {
				Part = p,
				TargetTransparency = p.Transparency,
			})
		end
	end

	if root:IsA("BasePart") and root.Name ~= "VfxAnchor" then
		add(root)
	end

	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") then
			add(d)
		end
	end

	return parts
end

local function prepFadeInStart(parts)
	for _, row in ipairs(parts) do
		if row.Part.Parent then
			row.Part.Transparency = 1
		end
	end
end

local function tweenFadeIn(parts, duration)
	if duration <= 0 then
		for _, row in ipairs(parts) do
			if row.Part.Parent then
				row.Part.Transparency = row.TargetTransparency
			end
		end
		return
	end

	for _, row in ipairs(parts) do
		local p = row.Part
		if p.Parent then
			TweenService:Create(p, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Transparency = row.TargetTransparency,
			}):Play()
		end
	end
end

local function tweenFadeOut(parts, duration)
	if duration <= 0 then
		for _, row in ipairs(parts) do
			if row.Part.Parent then
				row.Part.Transparency = 1
			end
		end
		return
	end

	for _, row in ipairs(parts) do
		local p = row.Part
		if p.Parent then
			TweenService:Create(p, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Transparency = 1,
			}):Play()
		end
	end
end

local function burstParticles(root)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("ParticleEmitter") then
			local n = d:GetAttribute("EmitCount")
			if type(n) ~= "number" then
				n = DEFAULT_EMIT
			end
			d.Enabled = true
			d:Emit(math.floor(n))
		end
	end
end

local function getAttackDurationScale(rootInstance, currentAttackCooldown)
	if type(currentAttackCooldown) ~= "number" or currentAttackCooldown <= 0 then
		return 1
	end
	local baseAttr = rootInstance:GetAttribute("VfxBaseCooldown")
	local baseCooldown = (type(baseAttr) == "number" and baseAttr > 0) and baseAttr
		or GameConfig.PlayerBaseAttackIntervalSeconds
	local scale = currentAttackCooldown / baseCooldown
	return math.clamp(scale, 0.1, 10)
end

local function scaleNumberRangeByFactor(range, factor)
	return NumberRange.new(range.Min * factor, range.Max * factor)
end

local function applyAttackVfxPlaybackSpeed(rootInstance, speedScale)
	if type(speedScale) ~= "number" or speedScale <= 0 or speedScale == 1 then
		return
	end

	for _, d in ipairs(rootInstance:GetDescendants()) do
		if d:IsA("ParticleEmitter") then
			pcall(function()
				d.TimeScale = d.TimeScale * speedScale
			end)
			pcall(function()
				d.FlipbookFramerate = scaleNumberRangeByFactor(d.FlipbookFramerate, speedScale)
			end)
		end
	end
end

local function applyAttackVfxDynamicTiming(rootInstance, currentAttackCooldown)
	local durationScale = getAttackDurationScale(rootInstance, currentAttackCooldown)
	local speedScale = 1 / durationScale

	local baseLifetimeAttr = rootInstance:GetAttribute("VfxBaseLifetime")
	if type(baseLifetimeAttr) == "number" and baseLifetimeAttr > 0 then
		rootInstance:SetAttribute("VfxLifetime", math.max(0.02, baseLifetimeAttr * durationScale))
	end

	applyAttackVfxPlaybackSpeed(rootInstance, speedScale)
end

local function getSpinPart(rootInstance)
	if rootInstance:IsA("BasePart") and rootInstance.Name ~= "VfxAnchor" then
		return rootInstance
	end
	if rootInstance:IsA("Model") then
		if rootInstance.PrimaryPart then
			return rootInstance.PrimaryPart
		end
		return rootInstance:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function startPivotRotation(part, initialCFrame, cfg)
	local rotateTime = cfg.RotateTime
	local rotateDegrees = cfg.RotateDegrees
	local axisVec = localAxisFromLabel(cfg.RotateAxis)

	if type(rotateTime) ~= "number" or rotateTime <= 0 then
		return
	end
	if type(rotateDegrees) ~= "number" or rotateDegrees == 0 then
		return
	end
	if not axisVec then
		return
	end

	local axis = axisVec.Unit
	local rad = math.rad(rotateDegrees)

	task.spawn(function()
		local t0 = tick()
		while true do
			if not part.Parent then
				return
			end
			local elapsed = tick() - t0
			if elapsed >= rotateTime then
				part.CFrame = initialCFrame * CFrame.fromAxisAngle(axis, rad)
				return
			end
			local alpha = elapsed / rotateTime
			part.CFrame = initialCFrame * CFrame.fromAxisAngle(axis, rad * alpha)
			RunService.RenderStepped:Wait()
		end
	end)
end

--- FollowPart를 매 프레임 렌더 직전에 맞춤. Workspace에 둔 채 1인칭 가림 회피.
--- @return { Disconnect: function } — UnbindFromRenderStep
local function connectAttackFollowHrp(rootInstance, followPart, cfg)
	local followOffset = cfg.FollowOffset
	if typeof(followOffset) ~= "Vector3" then
		followOffset = Vector3.zero
	end

	local rotateTime = cfg.RotateTime or 0
	local rotateDegrees = cfg.RotateDegrees or 0
	local axisVec = localAxisFromLabel(cfg.RotateAxis)
	local hasSpin = type(rotateTime) == "number"
		and rotateTime > 0
		and type(rotateDegrees) == "number"
		and rotateDegrees ~= 0
		and axisVec ~= nil

	local t0 = tick()
	local radFull = hasSpin and math.rad(rotateDegrees) or 0

	attackFollowBindSerial += 1
	local bindName = "RogueAttackVfxFollow_" .. tostring(attackFollowBindSerial)
	local renderPriority = Enum.RenderPriority.Last.Value

	local function step()
		if not rootInstance.Parent or not followPart.Parent then
			pcall(function()
				RunService:UnbindFromRenderStep(bindName)
			end)
			return
		end

		local basePos = (followPart.CFrame * CFrame.new(followOffset)).Position
		local rotCF = CFrame.new()
		if hasSpin then
			local elapsed = tick() - t0
			local alpha = math.clamp(elapsed / rotateTime, 0, 1)
			rotCF = CFrame.fromAxisAngle(axisVec.Unit, radFull * alpha)
		end

		local target = CFrame.new(basePos) * rotCF
		if rootInstance:IsA("Model") then
			rootInstance:PivotTo(target)
		elseif rootInstance:IsA("BasePart") then
			rootInstance.CFrame = target
		end
	end

	RunService:BindToRenderStep(bindName, renderPriority, step)

	return {
		Disconnect = function()
			pcall(function()
				RunService:UnbindFromRenderStep(bindName)
			end)
		end,
	}
end

--- AttackerUserId로 FollowPart를 찾아 Vfx 수명 동안 BindToRenderStep 팔로우 연결 (실패 시 잠시 재시도).
local function beginAttackFollow(rootInstance, cfg, attackerUserId, followBundle)
	local partName = (type(cfg.FollowPartName) == "string" and cfg.FollowPartName ~= "") and cfg.FollowPartName
		or "HumanoidRootPart"

	local function tryAttach()
		local plr = Players:GetPlayerByUserId(attackerUserId)
		local char = plr and plr.Character
		local part = char and char:FindFirstChild(partName)
		if part and part:IsA("BasePart") then
			if followBundle.conn then
				pcall(function()
					followBundle.conn:Disconnect()
				end)
				followBundle.conn = nil
			end
			followBundle.conn = connectAttackFollowHrp(rootInstance, part, cfg)
			return true
		end
		return false
	end

	if tryAttach() then
		return
	end

	task.spawn(function()
		local deadline = tick() + 3
		while rootInstance.Parent and tick() < deadline do
			task.wait(0.05)
			if tryAttach() then
				return
			end
		end
	end)
end

--- 이전 공격 클론 제거 (같은 공격자가 짧은 간격으로 쏠 때 겹침 방지)
local function replacePreviousFollowAttackVfx(attackerUserId)
	local prev = activeAttackVfxByUserId[attackerUserId]
	if prev and prev.Parent then
		prev:Destroy()
	end
end

local function registerFollowAttackVfxInstance(attackerUserId, rootInstance)
	activeAttackVfxByUserId[attackerUserId] = rootInstance
	rootInstance.AncestryChanged:Connect(function()
		if rootInstance.Parent == nil and activeAttackVfxByUserId[attackerUserId] == rootInstance then
			activeAttackVfxByUserId[attackerUserId] = nil
		end
	end)
end

local function applyScaleByAttackRangeIfNeeded(cfg, rootInstance, attackRadiusStuds)
	if not cfg.ScaleByAttackRange or type(attackRadiusStuds) ~= "number" then
		return
	end
	local ref = getVfxReferenceRadiusStuds(rootInstance)
	if not ref then
		ref = GameConfig.PlayerAttackVfxReferenceRadiusStuds or GameConfig.PlayerAttackRangeStuds
	end
	applyAttackVfxRangeScale(rootInstance, attackRadiusStuds, ref)
end

--- attack: Burst 후 VfxLifetime(초) 동안 팔로우 → 만료 시 정리 후 Destroy.
local function scheduleAttackVfxLifecycle(rootInstance, cfg, followBundle)
	task.spawn(function()
		if cfg.UseBurst then
			burstParticles(rootInstance)
		end
		if not cfg.LifecycleEndsWithDebris then
			return
		end
		local life = rootInstance:GetAttribute("VfxLifetime")
		if type(life) == "number" and life > 0 then
			local wallDuration = math.max(0.02, life)
			task.delay(wallDuration, function()
				if followBundle and followBundle.conn then
					pcall(function()
						followBundle.conn:Disconnect()
					end)
					followBundle.conn = nil
				end
				if rootInstance.Parent then
					rootInstance:Destroy()
				end
			end)
		elseif not warnedMissingAttackVfxLifetime then
			warnedMissingAttackVfxLifetime = true
			warn(
				"[VFXClient] ATTACK 클론 정리: 루트에 VfxLifetime(Number, 초)를 넣거나, 프리팹 안에서 수명 후 Destroy 하세요."
			)
		end
	end)
end

--- hit / death: Fade → Burst → Hold → FadeOut → follow 해제 → Destroy
local function scheduleFadeHoldBurstDestroyLifecycle(rootInstance, cfg, followConn, fadeParts)
	task.spawn(function()
		local fadeIn = cfg.FadeIn or 0
		local hold = cfg.Hold or 0
		local fadeOut = cfg.FadeOut or 0

		if cfg.UseFade then
			if #fadeParts > 0 and fadeIn > 0 then
				prepFadeInStart(fadeParts)
			end
			if #fadeParts > 0 then
				tweenFadeIn(fadeParts, fadeIn)
				if fadeIn > 0 then
					task.wait(fadeIn)
				end
			end
		end

		if cfg.UseBurst then
			burstParticles(rootInstance)
		end

		if hold > 0 then
			task.wait(hold)
		end

		if cfg.UseFade and #fadeParts > 0 and fadeOut > 0 then
			tweenFadeOut(fadeParts, fadeOut)
			if fadeOut > 0 then
				task.wait(fadeOut)
			end
		end

		if followConn then
			followConn:Disconnect()
			followConn = nil
		end

		if rootInstance and rootInstance.Parent then
			rootInstance:Destroy()
		end
	end)
end

local function playWorldVfx(vfxRoot, effectType, position, attackRadiusStuds, attackFollowUserId, currentAttackCooldown)
	local cfg = EFFECTS[effectType]
	if not cfg then
		return
	end
	if typeof(position) ~= "Vector3" then
		return
	end

	local template = findPrefab(vfxRoot, cfg)
	if not template then
		return
	end

	if cfg.FollowAttacker and type(attackFollowUserId) == "number" then
		replacePreviousFollowAttackVfx(attackFollowUserId)
	end

	local clone = template:Clone()
	if effectType == "attack" then
		applyAttackVfxDynamicTiming(clone, currentAttackCooldown)
	end
	applyScaleByAttackRangeIfNeeded(cfg, clone, attackRadiusStuds)

	local rootInstance = placeCloneAtPosition(clone, position)
	if not rootInstance then
		return
	end

	if effectType == "attack" and rootInstance ~= clone then
		local lt = clone:GetAttribute("VfxLifetime")
		if type(lt) == "number" and lt > 0 then
			rootInstance:SetAttribute("VfxLifetime", lt)
		end
	end

	if cfg.FollowAttacker and type(attackFollowUserId) == "number" then
		registerFollowAttackVfxInstance(attackFollowUserId, rootInstance)
	end

	local fadeParts = cfg.UseFade and collectFadeParts(rootInstance) or {}

	local followBundle = nil
	if effectType == "attack" and cfg.FollowAttacker and type(attackFollowUserId) == "number" then
		followBundle = { conn = nil }
		beginAttackFollow(rootInstance, cfg, attackFollowUserId, followBundle)
		rootInstance.Destroying:Connect(function()
			if followBundle.conn then
				pcall(function()
					followBundle.conn:Disconnect()
				end)
				followBundle.conn = nil
			end
		end)
	end

	local followConn = nil

	local spinPart = getSpinPart(rootInstance)
	if not cfg.FollowAttacker and spinPart then
		startPivotRotation(spinPart, spinPart.CFrame, cfg)
	end

	if cfg.LifecycleEndsWithDebris then
		scheduleAttackVfxLifecycle(rootInstance, cfg, followBundle)
	else
		scheduleFadeHoldBurstDestroyLifecycle(rootInstance, cfg, followConn, fadeParts)
	end
end

local function playEnemyHitFlash(part)
	if not part:IsA("BasePart") or not part.Parent then
		return
	end

	local f = enemyHitFlashState[part]
	if not f then
		f = { base = part.Color, gen = 0 }
		enemyHitFlashState[part] = f
	end
	f.gen += 1
	local myGen = f.gen

	task.spawn(function()
		local pulses = math.max(1, math.floor(ENEMY_HIT_FLASH_PULSES))
		local total = math.max(0.05, ENEMY_HIT_FLASH_TOTAL_SEC)
		local segment = total / pulses
		local half = segment * 0.5

		for _ = 1, pulses do
			if not part.Parent then
				break
			end
			if enemyHitFlashState[part] ~= f or f.gen ~= myGen then
				return
			end

			part.Color = ENEMY_HIT_FLASH_COLOR
			task.wait(half)

			if not part.Parent then
				break
			end
			if enemyHitFlashState[part] ~= f or f.gen ~= myGen then
				return
			end

			local tw = TweenService:Create(
				part,
				TweenInfo.new(half, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
				{ Color = f.base }
			)
			tw:Play()
			tw.Completed:Wait()
		end

		if enemyHitFlashState[part] == f and f.gen == myGen then
			enemyHitFlashState[part] = nil
		end
	end)
end

local function playPlayerHitFlash(character)
	if not character or not character.Parent then
		return
	end

	local f = playerHitFlashState[character]
	if not f then
		f = { gen = 0, highlight = nil }
		playerHitFlashState[character] = f
	end
	f.gen += 1
	local myGen = f.gen

	if not f.highlight or not f.highlight.Parent then
		local hl = Instance.new("Highlight")
		hl.Name = "PlayerHitFlashHighlight"
		hl.FillColor = PLAYER_HIT_FLASH_COLOR
		hl.OutlineColor = PLAYER_HIT_FLASH_COLOR
		hl.OutlineTransparency = 1
		hl.FillTransparency = 1
		hl.DepthMode = Enum.HighlightDepthMode.Occluded
		hl.Adornee = character
		hl.Parent = character
		f.highlight = hl
	end

	task.spawn(function()
		local pulses = math.max(1, math.floor(PLAYER_HIT_FLASH_PULSES))
		local total = math.max(0.05, PLAYER_HIT_FLASH_TOTAL_SEC)
		local segment = total / pulses
		local half = segment * 0.5

		for _ = 1, pulses do
			if not character.Parent or not f.highlight or not f.highlight.Parent then
				break
			end
			if playerHitFlashState[character] ~= f or f.gen ~= myGen then
				return
			end

			f.highlight.FillTransparency = PLAYER_HIT_FLASH_PEAK_TRANSPARENCY
			task.wait(half)

			if not character.Parent or not f.highlight or not f.highlight.Parent then
				break
			end
			if playerHitFlashState[character] ~= f or f.gen ~= myGen then
				return
			end

			local tw = TweenService:Create(
				f.highlight,
				TweenInfo.new(half, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
				{ FillTransparency = 1 }
			)
			tw:Play()
			tw.Completed:Wait()
		end

		if playerHitFlashState[character] == f and f.gen == myGen then
			if f.highlight and f.highlight.Parent then
				f.highlight:Destroy()
			end
			playerHitFlashState[character] = nil
		end
	end)
end

function VFXClient.init()
	local vfxRoot = ReplicatedStorage:WaitForChild("VFX")
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local evt = remotes:WaitForChild("VFXEvent")

	Players.PlayerRemoving:Connect(function(plr)
		local prev = activeAttackVfxByUserId[plr.UserId]
		if prev and prev.Parent then
			prev:Destroy()
		end
		activeAttackVfxByUserId[plr.UserId] = nil
	end)

	evt.OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end
		local effectType = payload.EffectType
		if type(effectType) ~= "string" then
			return
		end
		local t = string.lower(effectType)
		local attackR = (t == "attack" and type(payload.Radius) == "number") and payload.Radius or nil
		local attackFollowUid = (t == "attack" and type(payload.AttackerUserId) == "number") and payload.AttackerUserId
			or nil
		local attackCooldown = (t == "attack" and type(payload.AttackCooldown) == "number" and payload.AttackCooldown > 0)
				and payload.AttackCooldown
			or nil
		playWorldVfx(vfxRoot, t, payload.Position, attackR, attackFollowUid, attackCooldown)
		if t == "hit" then
			local hp = payload.HitPart
			if hp and hp:IsA("BasePart") then
				playEnemyHitFlash(hp)
			end
		elseif t == "player_hit" then
			local uid = payload.PlayerUserId
			if type(uid) == "number" then
				local plr = Players:GetPlayerByUserId(uid)
				local char = plr and plr.Character
				if char then
					playPlayerHitFlash(char)
				end
			end
		end
	end)
end

return VFXClient

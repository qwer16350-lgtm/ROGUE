
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local VFXClient = {}

local DEFAULT_EMIT = 1
local DEBUG_VFX_CLIENT_VERBOSE = false

local ENEMY_HIT_FLASH_TOTAL_SEC = 0.21
local ENEMY_HIT_FLASH_PULSES = 3
local ENEMY_HIT_FLASH_COLOR = Color3.fromRGB(255, 255, 255)

local enemyHitFlashState = setmetatable({}, { __mode = "k" })

local PLAYER_HIT_FLASH_TOTAL_SEC = 0.21
local PLAYER_HIT_FLASH_PULSES = 3
local PLAYER_HIT_FLASH_COLOR = Color3.fromRGB(255, 0, 0)
local PLAYER_HIT_FLASH_PEAK_TRANSPARENCY = 0.35

local playerHitFlashState = setmetatable({}, { __mode = "k" })
local warnedMissingAttackVfxLifetime = false
local activeAttackVfxByUserId = {}
local attackFollowBindSerial = 0

local DEBUG_SWORDSHIELD_ZERO_DISPLAY_OFFSET = false

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

local function coerceVector3(v): Vector3?
	if typeof(v) == "Vector3" then
		return v
	end
	if type(v) ~= "table" then
		return nil
	end
	local x = v.X ~= nil and v.X or v.x
	local y = v.Y ~= nil and v.Y or v.y
	local z = v.Z ~= nil and v.Z or v.z
	if type(x) == "number" and type(y) == "number" and type(z) == "number" then
		return Vector3.new(x, y, z)
	end
	return nil
end

local warnedMissingVfxAttackFolder = false

local function warnMissingVfxAttackFolderOnce()
	if warnedMissingVfxAttackFolder then
		return
	end
	warnedMissingVfxAttackFolder = true
	warn("[VFXClient] ReplicatedStorage.VFX 아래 ATTACK/Attack 폴더를 찾지 못했습니다. Studio에서 VFX 트리를 확인하세요.")
end

local function resolveVfxAttackFolder(vfxRoot)
	local direct = vfxRoot:FindFirstChild("ATTACK") or vfxRoot:FindFirstChild("Attack")
	if direct then
		return direct
	end
	for _, ch in ipairs(vfxRoot:GetChildren()) do
		if ch:IsA("Folder") and string.lower(ch.Name) == "attack" then
			return ch
		end
	end
	return nil
end

local function unwrapVfxPrefabInstance(inst)
	if not inst then
		return nil
	end
	if inst:IsA("Model") or inst:IsA("BasePart") or inst:IsA("Attachment") then
		return inst
	end
	if inst:IsA("Folder") then
		for _, ch in ipairs(inst:GetChildren()) do
			if ch:IsA("Model") or ch:IsA("BasePart") or ch:IsA("Attachment") then
				return ch
			end
		end
	end
	return nil
end

local function findSwordShieldPrefabInAttackFolder(folder, canonicalName: string)
	if not folder then
		return nil
	end
	local exact = folder:FindFirstChild(canonicalName)
	local u = unwrapVfxPrefabInstance(exact)
	if u then
		return u
	end
	local want = string.lower(canonicalName)
	for _, ch in ipairs(folder:GetChildren()) do
		if string.lower(ch.Name) == want then
			u = unwrapVfxPrefabInstance(ch)
			if u then
				return u
			end
		end
	end
	for _, d in ipairs(folder:GetDescendants()) do
		if string.lower(d.Name) == want then
			if d:IsA("Folder") or d:IsA("Model") or d:IsA("BasePart") or d:IsA("Attachment") then
				u = unwrapVfxPrefabInstance(d)
				if u then
					return u
				end
			end
		end
	end
	return nil
end

local function resolveSwordShieldSweepTemplate(vfxRoot)
	local folder = resolveVfxAttackFolder(vfxRoot)
	if not folder then
		warnMissingVfxAttackFolderOnce()
	end
	return findSwordShieldPrefabInAttackFolder(folder, "SwordShieldSweep")
end

local function resolveSwordShieldThrustTemplate(vfxRoot)
	local folder = resolveVfxAttackFolder(vfxRoot)
	if not folder then
		warnMissingVfxAttackFolderOnce()
	end
	return findSwordShieldPrefabInAttackFolder(folder, "SwordShieldThrust")
end

local function resolveSpearThrustTemplate(vfxRoot)
	local folder = resolveVfxAttackFolder(vfxRoot)
	if not folder then
		warnMissingVfxAttackFolderOnce()
	end
	return findSwordShieldPrefabInAttackFolder(folder, "Spear")
end

local function resolveTwoHandedSweepTemplate(vfxRoot)
	local folder = resolveVfxAttackFolder(vfxRoot)
	if not folder then
		warnMissingVfxAttackFolderOnce()
	end
	return findSwordShieldPrefabInAttackFolder(folder, "TwoHandedSword")
end

local function placeCloneAtPosition(clone, position)
	if clone:IsA("Model") then
		pcall(function()
			clone:PivotTo(CFrame.new(position))
		end)
		clone.Parent = Workspace
		if DEBUG_VFX_CLIENT_VERBOSE then
			print(
				"[DEBUG VFXClient] placeCloneAtPosition Model root=",
				clone.Name,
				clone.ClassName,
				"Parent=",
				clone.Parent and clone.Parent.Name or "nil"
			)
		end
		return clone
	elseif clone:IsA("BasePart") then
		clone.Anchored = true
		clone.CanCollide = false
		clone.Position = position
		clone.Parent = Workspace
		if DEBUG_VFX_CLIENT_VERBOSE then
			print(
				"[DEBUG VFXClient] placeCloneAtPosition BasePart root=",
				clone.Name,
				clone.ClassName,
				"Parent=",
				clone.Parent and clone.Parent.Name or "nil"
			)
		end
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
		if DEBUG_VFX_CLIENT_VERBOSE then
			print(
				"[DEBUG VFXClient] placeCloneAtPosition Attachment clone=",
				clone.Name,
				clone.ClassName,
				"underVfxAnchor=",
				clone.Parent ~= nil,
				"VfxAnchor.Parent=",
				anchor.Parent and anchor.Parent.Name or "nil"
			)
		end
		return anchor
	end

	warn("[VFXClient] 지원하지 않는 VFX 클론 타입:", clone.ClassName, clone.Name)
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

local DEFAULT_SWORDSHIELD_VFX_REFERENCE_RADIUS_STUDS = 5

local function applySwordShieldAttackRangeVisualScale(clone, radiusStuds: number?, subtypeStr: string?)
	if subtypeStr ~= "Sweep" and subtypeStr ~= "Thrust" then
		return
	end
	if type(radiusStuds) ~= "number" or radiusStuds <= 0 then
		return
	end
	local ref = parsePositiveNumberAttr(clone, "VfxReferenceRadius")
		or DEFAULT_SWORDSHIELD_VFX_REFERENCE_RADIUS_STUDS
	applyAttackVfxRangeScale(clone, radiusStuds, ref)
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

local function debugFormatAttributes(inst: Instance): string
	local attrs = inst:GetAttributes()
	local keys = {}
	for k in pairs(attrs) do
		table.insert(keys, k)
	end
	table.sort(keys)
	local parts = {}
	for _, k in ipairs(keys) do
		table.insert(parts, string.format("%s=%s", k, tostring(attrs[k])))
	end
	if #parts == 0 then
		return "{}"
	end
	return table.concat(parts, "; ")
end

local function burstParticles(root)
	if DEBUG_VFX_CLIENT_VERBOSE then
		print("[DEBUG VFXClient] burstParticles root GetFullName=", root:GetFullName())
		print("[DEBUG VFXClient] burstParticles root GetAttributes=", debugFormatAttributes(root))
	end

	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("ParticleEmitter") then
			local attr = d:GetAttribute("EmitCount")
			local n = attr
			if type(n) ~= "number" then
				n = DEFAULT_EMIT
			end
			local emitCalls = math.floor(n)

			if DEBUG_VFX_CLIENT_VERBOSE then
				print("[DEBUG VFXClient] burstParticles emitter GetFullName=", d:GetFullName())
				print("[DEBUG VFXClient] burstParticles emitter GetAttributes=", debugFormatAttributes(d))
				print("[DEBUG VFXClient] LockedToPart", d:GetFullName(), "LockedToPart=", d.LockedToPart)
				if d.Name == "Slash2" then
					print(
						"[DEBUG VFXClient] burstParticles Slash2 EmitCount via GetAttribute=",
						attr,
						"type=",
						type(attr),
						"resolvedEmitCalls=",
						emitCalls
					)
				end
				print(
					"[DEBUG VFXClient] burstParticles emitter=",
					d.Name,
					"EmitCountAttr=",
					type(attr) == "number" and attr or "(nil→DEFAULT_EMIT)",
					"EmitCalls=",
					emitCalls,
					"EnabledBefore=",
					d.Enabled
				)
			end
			d.Enabled = true
			d:Emit(emitCalls)
			if DEBUG_VFX_CLIENT_VERBOSE then
				print("[DEBUG VFXClient] burstParticles after Emit Enabled=", d.Enabled)
			end
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

local function connectAttackFollowHrp(
	rootInstance,
	followPart,
	cfg,
	preserveAttackForward: Vector3?,
	worldOffsetFromFollowPart: Vector3?
)
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

		local basePos
		if typeof(worldOffsetFromFollowPart) == "Vector3" then
			basePos = followPart.Position + worldOffsetFromFollowPart
		else
			basePos = (followPart.CFrame * CFrame.new(followOffset)).Position
		end
		local rotCF = CFrame.new()
		if hasSpin then
			local elapsed = tick() - t0
			local alpha = math.clamp(elapsed / rotateTime, 0, 1)
			rotCF = CFrame.fromAxisAngle(axisVec.Unit, radFull * alpha)
		end

		local pf = preserveAttackForward
		local target: CFrame
		if typeof(pf) == "Vector3" and pf.Magnitude > 1e-4 then
			local dirUnit = pf / pf.Magnitude
			local baseCf = CFrame.lookAt(basePos, basePos + dirUnit)
			target = baseCf * rotCF
		else
			target = CFrame.new(basePos) * rotCF
		end
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

local function beginAttackFollow(
	rootInstance,
	cfg,
	attackerUserId,
	followBundle,
	preserveAttackForward: Vector3?,
	worldOffsetFromFollowPart: Vector3?
)
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
			followBundle.conn = connectAttackFollowHrp(
				rootInstance,
				part,
				cfg,
				preserveAttackForward,
				worldOffsetFromFollowPart
			)
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

local function swordShieldFlatForwardAndDisplayPos(
	basePosition: Vector3,
	rawForward: Vector3?,
	subtypeStr: string
): (Vector3, Vector3)
	local hrpLook: Vector3? = nil
	local char = Players.LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		hrpLook = hrp.CFrame.LookVector
	end

	local flatRaw = typeof(rawForward) == "Vector3" and Vector3.new(rawForward.X, 0, rawForward.Z) or Vector3.zero
	local flatDir: Vector3
	if flatRaw.Magnitude > 1e-3 then
		flatDir = flatRaw.Unit
	elseif typeof(hrpLook) == "Vector3" then
		local flatHrp = Vector3.new(hrpLook.X, 0, hrpLook.Z)
		if flatHrp.Magnitude > 1e-3 then
			flatDir = flatHrp.Unit
		elseif typeof(rawForward) == "Vector3" and rawForward.Magnitude > 1e-4 then
			flatDir = rawForward.Unit
		else
			flatDir = Vector3.new(0, 0, -1)
		end
	elseif typeof(rawForward) == "Vector3" and rawForward.Magnitude > 1e-4 then
		flatDir = rawForward.Unit
	else
		flatDir = Vector3.new(0, 0, -1)
	end

	local displayPos = basePosition
	if not DEBUG_SWORDSHIELD_ZERO_DISPLAY_OFFSET then
		local along = 0.3
		local up = 0.1
		if subtypeStr == "Thrust" then
			along = 0.6
		end
		displayPos = basePosition + flatDir * along + Vector3.new(0, up, 0)
	end
	return flatDir, displayPos
end

local function orientAttackCloneIfForward(rootInstance, position, attackForward)
	if typeof(attackForward) ~= "Vector3" then
		return
	end
	local m = attackForward.Magnitude
	if m <= 1e-4 then
		return
	end
	local lookCf = CFrame.lookAt(position, position + (attackForward / m))
	if rootInstance:IsA("Model") then
		pcall(function()
			rootInstance:PivotTo(lookCf)
		end)
	elseif rootInstance:IsA("BasePart") then
		rootInstance.CFrame = lookCf
	end
end

local function playWorldVfx(
	vfxRoot,
	effectType,
	position,
	attackRadiusStuds,
	attackFollowUserId,
	currentAttackCooldown,
	attackSubtype: string?,
	attackForward: Vector3?
)
	local cfg = EFFECTS[effectType]
	if not cfg then
		warn("[VFXClient] 알 수 없는 EffectType:", tostring(effectType))
		return
	end
	local posVec = coerceVector3(position)
	if not posVec then
		warn(
			"[VFXClient] Position 을 Vector3 로 해석할 수 없습니다. type=",
			type(position),
			"subtype=",
			tostring(attackSubtype)
		)
		return
	end
	local fwdVec = coerceVector3(attackForward)
	local subtypeStr = effectType == "attack" and type(attackSubtype) == "string" and attackSubtype or nil

	local displayPos = posVec
	local displayFwdForVfx = fwdVec
	if effectType == "attack" and (subtypeStr == "Sweep" or subtypeStr == "Thrust") then
		local flatDir, adjPos = swordShieldFlatForwardAndDisplayPos(posVec, fwdVec, subtypeStr)
		displayFwdForVfx = flatDir
		displayPos = adjPos
	end

	local template
	if effectType == "attack" then
		if subtypeStr == "BasicMagic" then
			return
		end
		if subtypeStr == "Sweep" then
			if DEBUG_VFX_CLIENT_VERBOSE then
				print("[DEBUG VFXClient] playWorldVfx entered Sweep branch")
			end
			template = resolveSwordShieldSweepTemplate(vfxRoot)
			if not template then
				warn("[VFXClient] SwordShieldSweep 프리팹을 찾지 못했습니다 (VFX/ATTACK/SwordShieldSweep).")
				return
			end
		elseif subtypeStr == "Thrust" then
			if DEBUG_VFX_CLIENT_VERBOSE then
				print("[DEBUG VFXClient] playWorldVfx entered Thrust branch")
			end
			template = resolveSwordShieldThrustTemplate(vfxRoot)
			if not template then
				warn("[VFXClient] SwordShieldThrust 프리팹을 찾지 못했습니다 (VFX/ATTACK/SwordShieldThrust).")
				return
			end
		elseif subtypeStr == "SpearThrust" then
			template = resolveSpearThrustTemplate(vfxRoot)
			if not template then
				warn("[VFXClient] Spear 프리팹을 찾지 못했습니다 (VFX/ATTACK/Spear).")
				return
			end
		elseif subtypeStr == "TwoHandedSweep" then
			template = resolveTwoHandedSweepTemplate(vfxRoot)
			if not template then
				warn("[VFXClient] TwoHandedSword 프리팹을 찾지 못했습니다 (VFX/ATTACK/TwoHandedSword).")
				return
			end
		else
			template = findPrefab(vfxRoot, cfg)
			if not template then
				return
			end
		end
	else
		template = findPrefab(vfxRoot, cfg)
		if not template then
			return
		end
	end

	local radiusForVisual = attackRadiusStuds
	if effectType == "attack" then
		local st = type(attackSubtype) == "string" and attackSubtype or nil
		if st == "Sweep" and type(radiusForVisual) == "number" then
			radiusForVisual = radiusForVisual * 1.08
		elseif st == "Thrust" and type(radiusForVisual) == "number" then
			radiusForVisual = radiusForVisual * 0.88
		end
	end

	if cfg.FollowAttacker and type(attackFollowUserId) == "number" then
		replacePreviousFollowAttackVfx(attackFollowUserId)
	end

	local clone = template:Clone()
	if effectType == "attack" then
		applyAttackVfxDynamicTiming(clone, currentAttackCooldown)
	end
	if effectType == "attack" and (subtypeStr == "Sweep" or subtypeStr == "Thrust") then
		applySwordShieldAttackRangeVisualScale(clone, radiusForVisual, subtypeStr)
	else
		applyScaleByAttackRangeIfNeeded(cfg, clone, radiusForVisual)
	end

	local rootInstance = placeCloneAtPosition(clone, displayPos)
	if not rootInstance then
		warn("[VFXClient] playWorldVfx: 클론을 Workspace 에 배치하지 못했습니다.")
		return
	end

	if DEBUG_VFX_CLIENT_VERBOSE then
		print(
			"[DEBUG VFXClient] playWorldVfx after placeClone rootInstance=",
			rootInstance.Name,
			rootInstance.ClassName,
			"Parent=",
			rootInstance.Parent and rootInstance.Parent.Name or "nil"
		)
		if clone:IsA("Attachment") then
			print(
				"[DEBUG VFXClient] Attachment clone parent name=",
				clone.Parent and clone.Parent.Name or "nil",
				"isVfxAnchor=",
				clone.Parent ~= nil and clone.Parent.Name == "VfxAnchor"
			)
		end
	end

	if effectType == "attack" and rootInstance ~= clone then
		local lt = clone:GetAttribute("VfxLifetime")
		if type(lt) == "number" and lt > 0 then
			rootInstance:SetAttribute("VfxLifetime", lt)
		end
	end

	if effectType == "attack" and rootInstance then
		local lt2 = rootInstance:GetAttribute("VfxLifetime")
		if type(lt2) == "number" and lt2 > 0 then
			local st = type(attackSubtype) == "string" and attackSubtype or nil
			if st == "Sweep" then
				rootInstance:SetAttribute("VfxLifetime", lt2 * 0.92)
			elseif st == "Thrust" then
				rootInstance:SetAttribute("VfxLifetime", lt2 * 1.12)
			end
		end
	end

	if effectType == "attack" and rootInstance then
		orientAttackCloneIfForward(rootInstance, displayPos, displayFwdForVfx)
	end

	if cfg.FollowAttacker and type(attackFollowUserId) == "number" then
		registerFollowAttackVfxInstance(attackFollowUserId, rootInstance)
	end

	local fadeParts = cfg.UseFade and collectFadeParts(rootInstance) or {}

	local followBundle = nil
	if effectType == "attack" and cfg.FollowAttacker and type(attackFollowUserId) == "number" then
		followBundle = { conn = nil }
		local preserveForward: Vector3? = nil
		if displayFwdForVfx then
			local fm = displayFwdForVfx.Magnitude
			if fm > 1e-4 then
				preserveForward = displayFwdForVfx / fm
			end
		end
		beginAttackFollow(rootInstance, cfg, attackFollowUserId, followBundle, preserveForward, nil)
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
	if DEBUG_VFX_CLIENT_VERBOSE then
		print("[DEBUG VFXClient] VFXClient.init() entered")
	end
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
			warn("[VFXClient] VFXEvent: payload 가 table 이 아닙니다.")
			return
		end
		local effectType = payload.EffectType
		if type(effectType) ~= "string" then
			warn("[VFXClient] VFXEvent: EffectType 이 string 이 아닙니다.")
			return
		end
		if DEBUG_VFX_CLIENT_VERBOSE then
			local posRaw = payload.Position
			local fwdRaw = payload.AttackForward
			local posStr
			if typeof(posRaw) == "Vector3" then
				posStr = tostring(posRaw)
			elseif type(posRaw) == "table" then
				posStr = string.format(
					"table(%s,%s,%s)",
					tostring(posRaw.X ~= nil and posRaw.X or posRaw.x),
					tostring(posRaw.Y ~= nil and posRaw.Y or posRaw.y),
					tostring(posRaw.Z ~= nil and posRaw.Z or posRaw.z)
				)
			else
				posStr = tostring(posRaw)
			end
			local fwdStr
			if typeof(fwdRaw) == "Vector3" then
				fwdStr = tostring(fwdRaw)
			elseif type(fwdRaw) == "table" then
				fwdStr = string.format(
					"table(%s,%s,%s)",
					tostring(fwdRaw.X ~= nil and fwdRaw.X or fwdRaw.x),
					tostring(fwdRaw.Y ~= nil and fwdRaw.Y or fwdRaw.y),
					tostring(fwdRaw.Z ~= nil and fwdRaw.Z or fwdRaw.z)
				)
			else
				fwdStr = tostring(fwdRaw)
			end
			print(
				"[DEBUG VFXClient] VFXEvent recv EffectType=",
				effectType,
				"Subtype=",
				payload.Subtype,
				"Position=",
				posStr,
				"AttackForward=",
				fwdStr,
				"AttackerUserId=",
				payload.AttackerUserId
			)
		end
		local t = string.lower(effectType)
		local attackR = (t == "attack" and type(payload.Radius) == "number") and payload.Radius or nil
		local attackFollowUid = (t == "attack" and type(payload.AttackerUserId) == "number") and payload.AttackerUserId
			or nil
		local attackCooldown = (t == "attack" and type(payload.AttackCooldown) == "number" and payload.AttackCooldown > 0)
				and payload.AttackCooldown
			or nil
		local atkSubtype =
			(t == "attack" and type(payload.Subtype) == "string") and payload.Subtype or nil
		local atkForward = t == "attack" and coerceVector3(payload.AttackForward) or nil

		local skipBasicMagicAttackVfx =
			t == "attack" and type(atkSubtype) == "string" and atkSubtype == "BasicMagic"

		if not skipBasicMagicAttackVfx then
			local worldPos = coerceVector3(payload.Position)
			if
				t == "attack"
				and attackFollowUid
				and (atkSubtype == "Sweep" or atkSubtype == "Thrust")
			then
				local lp = Players.LocalPlayer
				if lp.UserId == attackFollowUid then
					local hrp = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
					if hrp and hrp:IsA("BasePart") then
						worldPos = hrp.Position
					end
				end
			end
			playWorldVfx(vfxRoot, t, worldPos, attackR, attackFollowUid, attackCooldown, atkSubtype, atkForward)
		end
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
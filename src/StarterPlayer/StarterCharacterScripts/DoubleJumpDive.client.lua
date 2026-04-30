-- Put this LocalScript under StarterCharacterScripts
-- Press space twice to double jump
-- Press shift to dash
-- Made by SlowGhost208 (project-adapted version)

local MAX_JUMPS = 2
local TIME_BETWEEN_JUMPS = 0.1
local DASH_POWER = 50
local DASH_STEPS = 4
local DASH_STEP_TIME = 0.05
local DASH_DECAY = 0.7
local DASH_COOLDOWN = 0.6
local DASH_ANIMATION_ID = "rbxassetid://80401536436816"
local DASH_VFX_LIFETIME_MUL = 0.5

local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local character = script.Parent
local hrp = character:WaitForChild("HumanoidRootPart")
local humanoid = character:WaitForChild("Humanoid")
local particle = script:FindFirstChild("Particle")
if particle then
	particle.Parent = nil
end

local anim
if humanoid.RigType == Enum.HumanoidRigType.R15 then
	local rollR15 = script:FindFirstChild("Roll_R15")
	if rollR15 then
		anim = humanoid:LoadAnimation(rollR15)
	end
else
	local rollR6 = script:FindFirstChild("Roll_R6")
	if rollR6 then
		anim = humanoid:LoadAnimation(rollR6)
	end
end

local dashAnimTrack
if DASH_ANIMATION_ID ~= "" then
	local dashAnimation = Instance.new("Animation")
	dashAnimation.AnimationId = DASH_ANIMATION_ID
	dashAnimTrack = humanoid:LoadAnimation(dashAnimation)
end

local canJump = true
local jumpCount = 0

local canDash = true
local DASH_VFX_SCALE = 0.5
local DASH_VFX_BACK_OFFSET = 2
local DASH_VFX_HEIGHT_OFFSET = 0.2
local DASH_VFX_ROT_OFFSET = CFrame.Angles(0, math.rad(180), 0)

local function getDashPrefab()
	local vfxRoot = ReplicatedStorage:FindFirstChild("VFX")
	if not vfxRoot then
		return nil
	end

	local dashFolder = vfxRoot:FindFirstChild("DASH") or vfxRoot:FindFirstChild("Dash")
	if not dashFolder then
		return nil
	end

	return dashFolder:FindFirstChild("Dash")
end

local function getAttachPart(inst)
	if inst:IsA("BasePart") then
		return inst
	end
	if inst:IsA("Model") then
		if not inst.PrimaryPart then
			local primary = inst:FindFirstChildWhichIsA("BasePart", true)
			if primary then
				inst.PrimaryPart = primary
			end
		end
		return inst.PrimaryPart
	end
	return nil
end

local function spawnDashVfx(duration)
	local prefab = getDashPrefab()
	if not prefab then
		return
	end

	local clone = prefab:Clone()
	local attachPart = getAttachPart(clone)
	if not attachPart then
		clone:Destroy()
		return
	end

	local flatLook = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
	if flatLook.Magnitude < 0.001 then
		flatLook = Vector3.new(0, 0, -1)
	else
		flatLook = flatLook.Unit
	end
	local spawnPos = hrp.Position - flatLook * DASH_VFX_BACK_OFFSET + Vector3.new(0, DASH_VFX_HEIGHT_OFFSET, 0)
	local targetCf = CFrame.lookAt(spawnPos, spawnPos + flatLook, Vector3.yAxis) * DASH_VFX_ROT_OFFSET

	if clone:IsA("Model") then
		clone:PivotTo(targetCf)
		clone.Parent = workspace
	else
		clone.CFrame = targetCf
		clone.Parent = workspace
	end

	local function scaleNumberSequence(seq, factor)
		local keypoints = {}
		for _, kp in ipairs(seq.Keypoints) do
			table.insert(keypoints, NumberSequenceKeypoint.new(kp.Time, kp.Value * factor, kp.Envelope * factor))
		end
		return NumberSequence.new(keypoints)
	end

	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.Size *= DASH_VFX_SCALE
		elseif d:IsA("ParticleEmitter") then
			-- Some dash prefabs are authored with EmissionDirection=Top,
			-- which forces vertical streaks regardless of part orientation.
			d.EmissionDirection = Enum.NormalId.Front
			d.LockedToPart = true
			d.Size = scaleNumberSequence(d.Size, DASH_VFX_SCALE)
			d.Lifetime = NumberRange.new(
				d.Lifetime.Min * DASH_VFX_LIFETIME_MUL,
				d.Lifetime.Max * DASH_VFX_LIFETIME_MUL
			)
		end
	end

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hrp
	weld.Part1 = attachPart
	weld.Parent = attachPart

	Debris:AddItem(clone, duration)
end

local function createParticle(cf, t)
	if not particle then
		return
	end

	local part = Instance.new("Part")
	part.Size = Vector3.new(4, 4, 4)
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 1
	part.CFrame = cf
	part.Parent = workspace

	local clone = particle:Clone()
	clone.Enabled = true
	clone.Parent = part

	local life = clone.Lifetime
	for i = 0, 1.1, 0.1 do
		clone.Lifetime = NumberRange.new((1 - i) * life.Min, (1 - i) * life.Max + 0.1)
		task.wait(t * 0.1)
	end

	Debris:AddItem(part, t)
end

local function onStateChange(_, newState)
	if newState == Enum.HumanoidStateType.Landed
		or newState == Enum.HumanoidStateType.Swimming
		or newState == Enum.HumanoidStateType.Running
		or newState == Enum.HumanoidStateType.RunningNoPhysics then
		canJump = true
		jumpCount = 0
		if anim then
			anim:Stop()
		end
	elseif newState == Enum.HumanoidStateType.Freefall then
		task.wait(TIME_BETWEEN_JUMPS)
		canJump = true
	end
end

local function onJumpPressed()
	if humanoid:GetState() == Enum.HumanoidStateType.Dead then
		return
	end

	if canJump and jumpCount < MAX_JUMPS then
		canJump = false
		jumpCount += 1
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)

		if jumpCount > 1 then
			if anim and (jumpCount % 2 == 0 or humanoid:GetState() == Enum.HumanoidStateType.Flying) then
				anim:Play(nil, nil, 2.5)
			end
			createParticle(hrp.CFrame * CFrame.new(0, -1, 0), 0.3)
		end
	end
end

local function onInput(input, gameProcessed)
	if gameProcessed or humanoid:GetState() == Enum.HumanoidStateType.Dead then
		return
	end

	if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.Space then
		onJumpPressed()
		return
	end

	local state = humanoid:GetState()
	local isGrounded = state == Enum.HumanoidStateType.Running
		or state == Enum.HumanoidStateType.RunningNoPhysics
		or state == Enum.HumanoidStateType.Landed
	-- Allow dash from ground, or from air after exactly one jump used (1단 점프 후).
	-- Block dash after reaching MAX_JUMPS (2단 점프) and during non-jump freefall (jumpCount == 0).
	local dashAllowed = isGrounded or jumpCount == 1

	if input.KeyCode == Enum.KeyCode.LeftShift and canDash and dashAllowed then
		canDash = false
		if anim then
			anim:Stop()
		end

		local dash = Instance.new("BodyVelocity")
		dash.MaxForce = Vector3.new(1, 0, 1) * 30000
		dash.Velocity = hrp.CFrame.LookVector * DASH_POWER
		dash.Parent = hrp
		if dashAnimTrack then
			dashAnimTrack:Play()
		end
		local dashDuration = DASH_STEPS * DASH_STEP_TIME
		spawnDashVfx(dashDuration)
		createParticle(hrp.CFrame * CFrame.new(0, -1, -3), 0.3)

		for _ = 1, DASH_STEPS do
			task.wait(DASH_STEP_TIME)
			dash.Velocity *= DASH_DECAY
		end
		dash:Destroy()
		if dashAnimTrack and dashAnimTrack.IsPlaying then
			dashAnimTrack:Stop()
		end
		task.delay(DASH_COOLDOWN, function()
			canDash = true
		end)
	end
end

UserInputService.InputBegan:Connect(onInput)

humanoid.StateChanged:Connect(onStateChange)

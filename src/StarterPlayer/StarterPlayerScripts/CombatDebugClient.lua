
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatDebugClient = {}

local DEBUG_COLOR = Color3.fromRGB(255, 40, 40)
local DEBUG_TRANSPARENCY = 0.72
local CONE_SEGMENTS = 16
local FLOOR_Y_OFFSET = -2.2
local CIRCLE_DISK_HEIGHT = 0.14
local CONE_SLICE_HEIGHT = 0.12
local LINEBOX_HEIGHT = 0.12

local containerFolder: Folder? = nil

local function ensureContainer(): Folder
	local f = Workspace:FindFirstChild("DEV_AttackRangeDebug")
	if f and f:IsA("Folder") then
		return f
	end
	local nf = Instance.new("Folder")
	nf.Name = "DEV_AttackRangeDebug"
	nf.Parent = Workspace
	containerFolder = nf
	return nf
end

local function applyDebugPartProps(p: BasePart)
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = DEBUG_COLOR
	p.Transparency = DEBUG_TRANSPARENCY
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

local function displayOrigin(origin: Vector3): Vector3
	return Vector3.new(origin.X, origin.Y + FLOOR_Y_OFFSET, origin.Z)
end

local function renderCircle(origin: Vector3, rangeStuds: number, duration: number)
	if type(rangeStuds) ~= "number" or rangeStuds <= 0 then
		return
	end
	local base = displayOrigin(origin)
	local diameter = rangeStuds * 2
	local p = Instance.new("Part")
	p.Name = "DEV_AttackRange_Circle"
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(CIRCLE_DISK_HEIGHT, diameter, diameter)
	p.CFrame = CFrame.new(base) * CFrame.Angles(0, math.rad(90), math.rad(90))
	applyDebugPartProps(p)
	p.Parent = ensureContainer()
	task.delay(duration, function()
		if p.Parent then
			p:Destroy()
		end
	end)
end

local function rotateAroundY(dir: Vector3, angleRad: number): Vector3
	local c = math.cos(angleRad)
	local s = math.sin(angleRad)
	return (Vector3.new(dir.X * c - dir.Z * s, dir.Y, dir.X * s + dir.Z * c)).Unit
end

local function renderCone(origin: Vector3, forward: Vector3, rangeStuds: number, angleDeg: number, duration: number)
	if type(rangeStuds) ~= "number" or rangeStuds <= 0 then
		return
	end
	if type(angleDeg) ~= "number" or angleDeg <= 0 then
		return
	end
	local flat = Vector3.new(forward.X, 0, forward.Z)
	if flat.Magnitude < 1e-3 then
		flat = Vector3.new(0, 0, -1)
	else
		flat = flat.Unit
	end
	local halfRad = math.rad(math.clamp(angleDeg, 1, 360) * 0.5)
	local base = displayOrigin(origin)
	local model = Instance.new("Model")
	model.Name = "DEV_AttackRange_Cone"
	model.Parent = ensureContainer()

	local seg = math.clamp(CONE_SEGMENTS, 12, 24)
	for i = 0, seg - 1 do
		local t0 = -halfRad + (2 * halfRad) * (i / seg)
		local t1 = -halfRad + (2 * halfRad) * ((i + 1) / seg)
		local midA = (t0 + t1) * 0.5
		local midDir = rotateAroundY(flat, midA)
		local dTheta = math.abs(t1 - t0)
		local halfW = rangeStuds * math.tan(dTheta * 0.5)
		if halfW < 0.08 then
			halfW = 0.08
		end
		local center = base + midDir * (rangeStuds * 0.5)
		local p = Instance.new("Part")
		p.Name = "DEV_ConeSlice_" .. tostring(i)
		p.Size = Vector3.new(2 * halfW, CONE_SLICE_HEIGHT, rangeStuds)
		p.CFrame = CFrame.lookAt(center, center + midDir)
		applyDebugPartProps(p)
		p.Parent = model
	end

	task.delay(duration, function()
		if model.Parent then
			model:Destroy()
		end
	end)
end

local function renderLineBox(origin: Vector3, forward: Vector3, lengthStuds: number, widthStuds: number, duration: number)
	if type(lengthStuds) ~= "number" or lengthStuds <= 0 then
		return
	end
	if type(widthStuds) ~= "number" or widthStuds <= 0 then
		return
	end
	local f = forward.Unit
	local base = displayOrigin(origin)
	local center = base + f * (lengthStuds * 0.5)
	local p = Instance.new("Part")
	p.Name = "DEV_AttackRange_LineBox"
	p.Size = Vector3.new(widthStuds, LINEBOX_HEIGHT, lengthStuds)
	p.CFrame = CFrame.new(center, center + f)
	applyDebugPartProps(p)
	p.Parent = ensureContainer()
	task.delay(duration, function()
		if p.Parent then
			p:Destroy()
		end
	end)
end

local function clampDuration(sec: number): number
	if type(sec) ~= "number" or sec ~= sec then
		return 0.15
	end
	return math.clamp(sec, 0.05, 1)
end

function CombatDebugClient.init()
	local evt = ReplicatedStorage:WaitForChild("AttackRangeDebugEvent", 30)
	if not evt or not evt:IsA("RemoteEvent") then
		warn("[CombatDebugClient] AttackRangeDebugEvent 없음 — 디버그 범위 표시 비활성.")
		return
	end

	evt.OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end
		local shape = payload.Shape
		local dur = clampDuration(payload.Duration)
		local origin = coerceVector3(payload.Origin)
		if not origin then
			return
		end

		if shape == "Circle" then
			local r = payload.Range
			if type(r) == "number" then
				renderCircle(origin, r, dur)
			end
		elseif shape == "Cone" then
			local fwd = coerceVector3(payload.Forward)
			local r = payload.Range
			local ang = payload.AngleDeg
			if fwd and type(r) == "number" and type(ang) == "number" then
				renderCone(origin, fwd, r, ang, dur)
			end
		elseif shape == "LineBox" then
			local fwd = coerceVector3(payload.Forward)
			local len = payload.Length
			if type(len) ~= "number" then
				len = payload.Range
			end
			local wid = payload.Width
			if fwd and type(len) == "number" and type(wid) == "number" then
				renderLineBox(origin, fwd, len, wid, dur)
			end
		end
	end)
end

return CombatDebugClient
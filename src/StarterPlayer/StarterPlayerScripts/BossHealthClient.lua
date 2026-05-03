local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossHealthClient = {}

type Refs = {
	sg: ScreenGui?,
	txt: TextLabel?,
	barBg: Frame?,
	fill: Frame?,
}

local refs: Refs = {
	sg = nil,
	txt = nil,
	barBg = nil,
	fill = nil,
}

local storedMax = 1
local storedCur = 1

local function clampDisplayInt(n: number): number
	if n ~= n or n == math.huge or n == -math.huge then
		return 0
	end
	local k = math.floor(n + 0.5)
	if k < 0 then
		return 0
	end
	return k
end

local function redrawBarAndText()
	local sg = refs.sg
	local txt = refs.txt
	local barBg = refs.barBg
	local fill = refs.fill
	if not sg or not txt or not barBg or not fill then
		return
	end

	local mx = math.max(1, storedMax)
	local cur = math.clamp(storedCur, 0, mx)
	txt.Text = string.format("%d / %d", cur, mx)

	local bw = math.max(barBg.AbsoluteSize.X, 24)
	local inner = math.max(bw - 8, 4)
	local frac = cur / mx
	local minPx = math.max(math.floor(inner * 0.02 + 0.5), 2)
	local wantPx = math.max(math.floor(inner * frac + 0.5), minPx)
	wantPx = math.min(wantPx, inner)

	fill.AnchorPoint = Vector2.new(0, 0.5)
	fill.Position = UDim2.new(0, 4, 0.5, 0)
	fill.Size = UDim2.new(0, wantPx, 0, 14)
end

local function ensureGui(playerGui: PlayerGui)
	local existing = playerGui:FindFirstChild("BossHealthOverlay")
	if existing then
		existing:Destroy()
	end

	local sg = Instance.new("ScreenGui")
	sg.Name = "BossHealthOverlay"
	sg.ResetOnSpawn = false
	sg.IgnoreGuiInset = true
	sg.DisplayOrder = 45
	sg.Enabled = false
	sg.Parent = playerGui

	local root = Instance.new("Frame")
	root.Name = "BarRoot"
	root.AnchorPoint = Vector2.new(0.5, 0)
	root.Position = UDim2.fromScale(0.5, 0.035)
	root.Size = UDim2.new(2 / 3, 0, 0, 52)
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.Parent = sg

	local label = Instance.new("TextLabel")
	label.Name = "HpText"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 18)
	label.Position = UDim2.fromOffset(0, 2)
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(240, 240, 246)
	label.TextSize = 16
	label.Text = ""
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.Parent = root

	local barBg = Instance.new("Frame")
	barBg.Name = "HpBarBg"
	barBg.BorderSizePixel = 0
	barBg.AnchorPoint = Vector2.new(0.5, 0)
	barBg.Position = UDim2.new(0.5, 0, 0, 26)
	barBg.Size = UDim2.new(1, -8, 0, 20)
	barBg.BackgroundColor3 = Color3.fromRGB(38, 36, 48)
	barBg.Parent = root

	local ucb = Instance.new("UICorner")
	ucb.CornerRadius = UDim.new(0, 8)
	ucb.Parent = barBg

	local fill = Instance.new("Frame")
	fill.Name = "HpFill"
	fill.BorderSizePixel = 0
	fill.BackgroundColor3 = Color3.fromRGB(120, 220, 120)
	fill.Parent = barBg

	local ucf = Instance.new("UICorner")
	ucf.CornerRadius = UDim.new(0, 6)
	ucf.Parent = fill

	barBg:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		redrawBarAndText()
	end)

	refs.sg = sg
	refs.txt = label
	refs.barBg = barBg
	refs.fill = fill
end

function BossHealthClient.init()
	local player = Players.LocalPlayer
	local pg = player:WaitForChild("PlayerGui") :: PlayerGui

	ensureGui(pg)

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local ev = remotes:WaitForChild("BossHealthEvent") :: RemoteEvent

	ev.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		local p = payload :: any
		local phase = string.lower(tostring(p.Phase or ""))

		local sgRef = refs.sg
		if not sgRef then
			return
		end

		if phase == "hide" then
			sgRef.Enabled = false
			return
		end

		local curRaw = tonumber(p.Current)
		local mxRaw = tonumber(p.Max)

		if phase == "show" then
			storedMax = clampDisplayInt(mxRaw ~= nil and (mxRaw :: number) or 1)
			if storedMax < 1 then
				storedMax = 1
			end
			storedCur = curRaw ~= nil and clampDisplayInt(curRaw :: number) or storedMax
			storedCur = math.clamp(storedCur, 0, storedMax)
			sgRef.Enabled = true
			redrawBarAndText()
			return
		end

		if phase == "update" then
			if mxRaw ~= nil then
				storedMax = math.max(1, clampDisplayInt(mxRaw :: number))
			end
			if curRaw ~= nil then
				storedCur = clampDisplayInt(curRaw :: number)
			end
			storedCur = math.clamp(storedCur, 0, storedMax)
			sgRef.Enabled = true
			redrawBarAndText()
			return
		end
	end)
end

return BossHealthClient

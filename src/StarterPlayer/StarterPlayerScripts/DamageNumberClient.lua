local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local DamageNumberClient = {}

local DISPLAY_SECONDS = 0.475

local function tryParseVector3(raw: unknown): Vector3?
	if typeof(raw) == "Vector3" then
		return raw
	end
	return nil
end

local function showFloating(displayText: string, worldPos: Vector3, billboardSize: Vector2)
	local anchor = Instance.new("Part")
	anchor.Name = "DamageNumberAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CastShadow = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.05, 0.05, 0.05)
	anchor.CFrame = CFrame.new(worldPos)
	anchor.Parent = Workspace

	local bb = Instance.new("BillboardGui")
	bb.Name = "DamageBillboard"
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.ClipsDescendants = false
	bb.Size = UDim2.fromOffset(billboardSize.X, billboardSize.Y)
	bb.StudsOffsetWorldSpace = Vector3.zero
	bb.Parent = anchor

	local lbl = Instance.new("TextLabel")
	lbl.AnchorPoint = Vector2.new(0.5, 0.5)
	lbl.Position = UDim2.fromScale(0.5, 0.5)
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.BorderSizePixel = 0
	lbl.Font = Enum.Font.GothamBold
	lbl.TextScaled = true
	lbl.Text = displayText
	lbl.TextColor3 = Color3.fromRGB(255, 246, 200)
	lbl.TextStrokeTransparency = 0.65
	lbl.TextStrokeColor3 = Color3.fromRGB(20, 20, 20)
	lbl.TextTransparency = 1
	lbl.Parent = bb

	task.defer(function()
		local tIn = TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(lbl, tIn, { TextTransparency = 0 }):Play()

		task.wait(0.025)

		local rise = TweenInfo.new(0.39, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
		TweenService:Create(bb, rise, {
			StudsOffsetWorldSpace = Vector3.new(0, 3, 0),
		}):Play()

		task.wait(0.26)

		local tOut = TweenInfo.new(0.19, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
		local tw = TweenService:Create(lbl, tOut, { TextTransparency = 1 })
		tw.Completed:Wait()
		if anchor.Parent then
			anchor:Destroy()
		end
	end)

	task.delay(DISPLAY_SECONDS + 0.2, function()
		if anchor.Parent then
			anchor:Destroy()
		end
	end)
end

local function showOne(amount: number, worldPos: Vector3)
	showFloating(tostring(math.floor(amount + 0.5)), worldPos, Vector2.new(67, 27))
end

function DamageNumberClient.init()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local ev = remotes:WaitForChild("DamageNumberEvent") :: RemoteEvent

	ev.OnClientEvent:Connect(function(payload)
		local p = payload
		if typeof(p) ~= "table" then
			return
		end

		local pos = tryParseVector3((p :: any).WorldPosition)
		if pos == nil then
			warn("[DamageNumberClient] invalid payload — WorldPosition:Vector3 required")
			return
		end

		local rawText = (p :: any).Text
		if type(rawText) == "string" and rawText ~= "" then
			showFloating(rawText, pos, Vector2.new(90, 27))
			return
		end

		local rawAmt = (p :: any).Amount
		local amt = tonumber(rawAmt)
		if amt == nil then
			warn("[DamageNumberClient] invalid payload — expected Amount:number or Text:string")
			return
		end

		showOne(amt :: number, pos :: Vector3)
	end)
end

return DamageNumberClient

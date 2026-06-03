local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BlueprintNoticeClient = {}

function BlueprintNoticeClient.init()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local ev = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("BlueprintPickupNotice") :: RemoteEvent

	local gui = Instance.new("ScreenGui")
	gui.Name = "BlueprintNoticeGui"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 81
	gui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Name = "Toast"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0.14, 0)
	frame.Size = UDim2.new(0.5, 0, 0, 72)
	frame.BackgroundColor3 = Color3.fromRGB(22, 32, 48)
	frame.BackgroundTransparency = 0.1
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(80, 200, 255)
	stroke.Thickness = 1.5
	stroke.Transparency = 0.25
	stroke.Parent = frame

	local body = Instance.new("TextLabel")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Font = Enum.Font.GothamMedium
	body.TextSize = 16
	body.TextColor3 = Color3.fromRGB(200, 235, 255)
	body.Position = UDim2.new(0.05, 0, 0.15, 0)
	body.Size = UDim2.new(0.9, 0, 0.7, 0)
	body.TextXAlignment = Enum.TextXAlignment.Center
	body.TextWrapped = true
	body.Parent = frame

	local hideToken = 0
	local function showToast(message: string, duration: number)
		hideToken += 1
		local my = hideToken
		body.Text = message
		frame.Visible = true
		task.delay(duration, function()
			if hideToken == my then
				frame.Visible = false
			end
		end)
	end

	ev.OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end
		local msg = payload.Message
		if type(msg) ~= "string" or msg == "" then
			local label = payload.Label
			if type(label) == "string" and label ~= "" then
				msg = string.format("Blueprint +1: %s", label)
			else
				msg = "Blueprint +1"
			end
		end
		local dur = payload.DurationSeconds
		if type(dur) ~= "number" or dur <= 0 then
			dur = 3
		end
		showToast(msg, dur)
	end)
end

return BlueprintNoticeClient
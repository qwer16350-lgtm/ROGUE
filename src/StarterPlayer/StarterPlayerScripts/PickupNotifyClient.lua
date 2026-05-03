local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PickupNotifyClient = {}

function PickupNotifyClient.init()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local ev = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("WeaponPickupNotify") :: RemoteEvent

	local gui = Instance.new("ScreenGui")
	gui.Name = "PickupNotifyGui"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 80
	gui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Name = "Toast"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0.08, 0)
	frame.Size = UDim2.new(0.48, 0, 0, 80)
	frame.BackgroundColor3 = Color3.fromRGB(26, 26, 34)
	frame.BackgroundTransparency = 0.12
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 210, 60)
	stroke.Thickness = 1.5
	stroke.Transparency = 0.35
	stroke.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 18
	title.TextColor3 = Color3.fromRGB(255, 220, 80)
	title.Position = UDim2.new(0.05, 0, 0.1, 0)
	title.Size = UDim2.new(0.9, 0, 0.36, 0)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = frame

	local body = Instance.new("TextLabel")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Font = Enum.Font.Gotham
	body.TextSize = 15
	body.TextColor3 = Color3.fromRGB(235, 235, 245)
	body.Position = UDim2.new(0.05, 0, 0.48, 0)
	body.Size = UDim2.new(0.9, 0, 0.46, 0)
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextWrapped = true
	body.Parent = frame

	local hideToken = 0
	local function showToast(titleText: string, bodyText: string, duration: number)
		hideToken += 1
		local my = hideToken
		title.Text = titleText
		body.Text = bodyText
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
		local kind = payload.Kind
		if kind == "UpgradedToRare" then
			showToast("Weapon Acquired", "SwordShield upgraded to Rare", 4)
		elseif kind == "AlreadyRareDuplicate" then
			showToast("Weapon Acquired", "SwordShield duplicate acquired — already Rare", 4)
		end
	end)
end

return PickupNotifyClient

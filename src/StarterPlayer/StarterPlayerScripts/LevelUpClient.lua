local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LevelUpClient = {}

local OPTION_BUTTON_NAMES = { "Option1Button", "Option2Button", "Option3Button" }

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

function LevelUpClient.init()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local requestEvent = ReplicatedStorage:WaitForChild("LevelUpChoiceRequest")
	local submitEvent = ReplicatedStorage:WaitForChild("LevelUpChoiceSubmit")

	local mainHUD = waitForChildTimeout(playerGui, "MainHUD", 60)
	if not mainHUD then
		warn("[LevelUpClient] MainHUD 가 PlayerGui 에 없습니다.")
		return
	end

	local levelUpFrame = waitForChildTimeout(mainHUD, "LevelUpFrame", 60)
	if not levelUpFrame or not levelUpFrame:IsA("GuiObject") then
		warn("[LevelUpClient] MainHUD 아래 LevelUpFrame 을 찾지 못했습니다.")
		return
	end

	local optionsContainer = waitForChildTimeout(levelUpFrame, "OptionsContainer", 60)
	if not optionsContainer then
		warn("[LevelUpClient] LevelUpFrame 아래 OptionsContainer 를 찾지 못했습니다.")
		return
	end

	levelUpFrame.Visible = false

	for _, name in ipairs(OPTION_BUTTON_NAMES) do
		local btn = optionsContainer:FindFirstChild(name)
		if btn and btn:IsA("GuiButton") then
			btn.MouseButton1Click:Connect(function()
				local id = btn:GetAttribute("ChoiceId")
				if type(id) ~= "string" or id == "" then
					return
				end
				submitEvent:FireServer(id)
				levelUpFrame.Visible = false
			end)
		end
	end

	requestEvent.OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end

		local level = payload.Level or 0
		local choices = payload.Choices or {}

		local title = levelUpFrame:FindFirstChild("Title", true)
		if title and title:IsA("TextLabel") then
			title.Text = string.format("레벨 %d — 업그레이드 선택", level)
		end

		for i, btnName in ipairs(OPTION_BUTTON_NAMES) do
			local btn = optionsContainer:FindFirstChild(btnName)
			local choice = choices[i]
			if btn and btn:IsA("GuiButton") then
				if choice and type(choice.Id) == "string" then
					btn.Visible = true
					local label = choice.Label
					btn.Text = (type(label) == "string" and label ~= "") and label or choice.Id
					btn:SetAttribute("ChoiceId", choice.Id)
				else
					btn.Visible = false
					btn:SetAttribute("ChoiceId", "")
				end
			end
		end

		levelUpFrame.Visible = true
	end)
end

return LevelUpClient

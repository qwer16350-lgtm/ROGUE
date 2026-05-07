local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HUDClient = require(script.Parent:WaitForChild("HUDClient"))
local VFXClient = require(script.Parent:WaitForChild("VFXClient"))
local LevelUpClient = require(script.Parent:WaitForChild("LevelUpClient"))
local ResultClient = require(script.Parent:WaitForChild("ResultClient"))
local DamageNumberClient = require(script.Parent:WaitForChild("DamageNumberClient"))
local BossHealthClient = require(script.Parent:WaitForChild("BossHealthClient"))

local StageClient = {}

local HUD_TEMPLATE_FOLDER = "Stage"
local TEMPLATE_MAIN_HUD_NAME = "MainHUD"

local function cloneMainHudToPlayerGui(playerGui): boolean
	local existing = playerGui:FindFirstChild(TEMPLATE_MAIN_HUD_NAME)
	if existing then
		existing:Destroy()
	end

	local uiAssets = ReplicatedStorage:FindFirstChild("UIAssets")
	if not uiAssets then
		warn("[StageClient] ReplicatedStorage.UIAssets 가 없음 — MainHUD 미탑재, Stage 클라 초기화 중단")
		return false
	end

	local stageFolder = uiAssets:FindFirstChild(HUD_TEMPLATE_FOLDER)
	if not stageFolder then
		warn("[StageClient] UIAssets." .. HUD_TEMPLATE_FOLDER .. " 폴더 없음 — MainHUD 미탑재, Stage 클라 초기화 중단")
		return false
	end

	local template = stageFolder:FindFirstChild(TEMPLATE_MAIN_HUD_NAME)
	if not template or not template:IsA("ScreenGui") then
		warn(
			string.format(
				"[StageClient] UIAssets.%s 에 ScreenGui `%s` 없음 — Export 후 재동기화. Stage 클라 초기화 중단",
				HUD_TEMPLATE_FOLDER,
				TEMPLATE_MAIN_HUD_NAME
			)
		)
		return false
	end

	local cloneInst = template:Clone()
	if not cloneInst:IsA("ScreenGui") then
		warn("[StageClient] MainHUD 클론이 ScreenGui 가 아님 — Stage 클라 초기화 중단")
		return false
	end

	cloneInst.ResetOnSpawn = false
	cloneInst.Parent = playerGui

	return playerGui:FindFirstChild(TEMPLATE_MAIN_HUD_NAME) ~= nil
end

function StageClient.init()
	print("[DEBUG StageClient] StageClient.init() entered")
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	if not cloneMainHudToPlayerGui(playerGui) then
		print("[DEBUG StageClient] cloneMainHudToPlayerGui FAILED — VFXClient.init() will NOT run")
		return
	end

	print("[DEBUG StageClient] cloneMainHudToPlayerGui OK — VFXClient.init() then HUDClient.init()")
	VFXClient.init()
	local hudOk, hudErr = pcall(HUDClient.init)
	if not hudOk then
		warn("[StageClient] HUDClient.init 실패:", hudErr)
	end
	LevelUpClient.init()
	ResultClient.init()
	DamageNumberClient.init()
	BossHealthClient.init()
	print("[StageClient] MainHUD cloned + Stage UI clients initialized")
end

return StageClient
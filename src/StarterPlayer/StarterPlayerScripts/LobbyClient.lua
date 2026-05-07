local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyClient = {}

local GUI_NAME = "LobbyGui"
local LEGACY_PLACEHOLDER = "LobbyPlaceholderGui"
local LOBBY_STATION_TAG = "LobbyStation"
local ENTRY_PAD_TAG = "LobbyEntryPad"

local PANEL_NAMES = {
	"SkillTreePanel",
	"ShopPanel",
	"InventoryPanel",
	"ArtifactCollectionPanel",
	"Top50Panel",
	"PetGachaPanel",
	"BMShopPanel",
	"InGameShopPanel",
	"RelicShopPanel",
	"RelicFusionPanel",
}

local ACTION_BUTTON_TO_PANEL: { [string]: string } = {
	SkillTreeButton = "SkillTreePanel",
	ShopButton = "ShopPanel",
	InventoryButton = "InventoryPanel",
	ArtifactCollectionButton = "ArtifactCollectionPanel",
}

local function destroyIfPresent(parent: Instance, childName: string)
	local existing = parent:FindFirstChild(childName)
	if existing then
		existing:Destroy()
	end
end

local function deepFind(root: Instance, instanceName: string): Instance?
	if not root then
		return nil
	end
	return root:FindFirstChild(instanceName, true)
end

local function collectPanelMap(guiRoot: Instance): { [string]: GuiObject }
	local map: { [string]: GuiObject } = {}
	for _, name in ipairs(PANEL_NAMES) do
		local inst = deepFind(guiRoot, name)
		if inst and inst:IsA("GuiObject") then
			map[name] = inst
			inst.Visible = false
		end
	end
	return map
end

local function hideAllPanels(panelMap: { [string]: GuiObject })
	for _, p in panelMap do
		if p then
			p.Visible = false
		end
	end
end

local function showOnlyPanel(panelMap: { [string]: GuiObject }, panelName: string)
	hideAllPanels(panelMap)
	local p = panelMap[panelName]
	if p then
		p.Visible = true
	end
end

local function wirePlayerActionButtons(guiRoot: Instance, panelMap: { [string]: GuiObject })
	for btnName, panelName in pairs(ACTION_BUTTON_TO_PANEL) do
		local btn = deepFind(guiRoot, btnName)
		if btn and btn:IsA("GuiButton") then
			btn.MouseButton1Click:Connect(function()
				if panelMap[panelName] then
					showOnlyPanel(panelMap, panelName)
				end
			end)
		end
	end
end

local function wirePanelCloseButtons(guiRoot: Instance, panelMap: { [string]: GuiObject })
	local nameSet: { [string]: boolean } = {}
	for _, n in ipairs(PANEL_NAMES) do
		nameSet[n] = true
	end

	for _, desc in guiRoot:GetDescendants() do
		if desc.Name == "CloseButton" and desc:IsA("GuiButton") then
			local walker: Instance? = desc.Parent
			while walker ~= nil and walker ~= guiRoot do
				if nameSet[walker.Name] and walker:IsA("GuiObject") then
					local panel = walker
					desc.MouseButton1Click:Connect(function()
						panel.Visible = false
					end)
					break
				end
				walker = walker.Parent
			end
		end
	end
end

local function wireLobbyStations(panelMap: { [string]: GuiObject })
	local localPlayer = Players.LocalPlayer
	local tagged = CollectionService:GetTagged(LOBBY_STATION_TAG)

	for _, inst in ipairs(tagged) do
		if CollectionService:HasTag(inst, ENTRY_PAD_TAG) then
			continue
		end

		local panelName = inst:GetAttribute("LobbyPanel")
		if type(panelName) ~= "string" or panelName == "" then
			warn("[LobbyClient] LobbyStation instance missing string attribute LobbyPanel: ", inst:GetFullName())
			continue
		end
		if not panelMap[panelName] then
			warn("[LobbyClient] LobbyStation LobbyPanel not in registry: ", panelName, " at ", inst:GetFullName())
			continue
		end

		local prompt = inst:FindFirstChild("OpenPrompt", true)
		if not prompt or not prompt:IsA("ProximityPrompt") then
			local found: ProximityPrompt? = nil
			for _, d in inst:GetDescendants() do
				if d:IsA("ProximityPrompt") then
					found = d
					break
				end
			end
			prompt = found
		end
		if not prompt or not prompt:IsA("ProximityPrompt") then
			warn("[LobbyClient] LobbyStation has no ProximityPrompt: ", inst:GetFullName())
			continue
		end

		prompt.Triggered:Connect(function(player: Player?)
			if player ~= localPlayer then
				return
			end
			showOnlyPanel(panelMap, panelName :: string)
		end)
	end
end

local function cloneFromUIAssets(playerGui: PlayerGui): ScreenGui?
	local uiAssets = ReplicatedStorage:FindFirstChild("UIAssets")
	local lobbyFolder = uiAssets and uiAssets:FindFirstChild("Lobby")
	local template = lobbyFolder and lobbyFolder:FindFirstChild(GUI_NAME)
	if not template or not template:IsA("ScreenGui") then
		return nil
	end
	local c = template:Clone()
	c.Parent = playerGui
	return c
end

local function buildFallbackLobbyGui(): ScreenGui
	local sg = Instance.new("ScreenGui")
	sg.Name = GUI_NAME
	sg.ResetOnSpawn = false
	sg.IgnoreGuiInset = false
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	sg.DisplayOrder = 15

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Position = UDim2.fromScale(0, 0)
	root.Parent = sg

	local function corner(parent: GuiObject)
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 6)
		c.Parent = parent
	end

	local cur = Instance.new("Frame")
	cur.Name = "CurrencyBar"
	cur.BackgroundColor3 = Color3.fromRGB(36, 36, 44)
	cur.BorderSizePixel = 0
	cur.Size = UDim2.new(1, -40, 0, 34)
	cur.Position = UDim2.new(0, 20, 0, 60)
	cur.Parent = root
	corner(cur)

	local g = Instance.new("TextLabel")
	g.Name = "GoldValue"
	g.BackgroundTransparency = 1
	g.Size = UDim2.new(0.5, -8, 1, -6)
	g.Position = UDim2.fromOffset(8, 3)
	g.Font = Enum.Font.GothamBold
	g.TextSize = 17
	g.TextColor3 = Color3.new(1, 1, 1)
	g.TextXAlignment = Enum.TextXAlignment.Left
	g.Text = "Gold: 0"
	g.Parent = cur

	local d = Instance.new("TextLabel")
	d.Name = "DiaValue"
	d.BackgroundTransparency = 1
	d.Size = UDim2.new(0.5, -8, 1, -6)
	d.Position = UDim2.new(0.5, 4, 0, 3)
	d.Font = Enum.Font.GothamBold
	d.TextSize = 17
	d.TextColor3 = Color3.fromRGB(130, 220, 255)
	d.TextXAlignment = Enum.TextXAlignment.Right
	d.Text = "Dia: 0"
	d.Parent = cur

	local pa = Instance.new("Frame")
	pa.Name = "PlayerActions"
	pa.BackgroundTransparency = 1
	pa.Size = UDim2.new(1, -40, 0, 40)
	pa.Position = UDim2.new(0, 20, 0, 104)
	pa.Parent = root

	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Left
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 10)
	list.Parent = pa

	local function mkBtn(nm: string, txt: string)
		local b = Instance.new("TextButton")
		b.Name = nm
		b.AutoButtonColor = true
		b.Size = UDim2.fromOffset(130, 36)
		b.Text = txt
		b.Font = Enum.Font.GothamMedium
		b.TextSize = 14
		b.TextColor3 = Color3.new(1, 1, 1)
		b.BackgroundColor3 = Color3.fromRGB(56, 56, 70)
		b.BorderSizePixel = 0
		b.Parent = pa
		corner(b)
	end

	mkBtn("SkillTreeButton", "Skill Tree")
	mkBtn("ShopButton", "Shop")
	mkBtn("InventoryButton", "Inventory")
	mkBtn("ArtifactCollectionButton", "Artifacts")

	local panelsWrap = Instance.new("Frame")
	panelsWrap.Name = "Panels"
	panelsWrap.BackgroundTransparency = 1
	panelsWrap.Size = UDim2.fromScale(1, 1)
	panelsWrap.Position = UDim2.fromScale(0, 0)
	panelsWrap.ZIndex = 2
	panelsWrap.Parent = root

	local titles: { [string]: string } = {
		SkillTreePanel = "Skill Tree (placeholder)",
		ShopPanel = "Shop (placeholder)",
		InventoryPanel = "Inventory (placeholder)",
		ArtifactCollectionPanel = "Artifacts (placeholder)",
		Top50Panel = "Top 50 (placeholder)",
		PetGachaPanel = "Pet Gacha (placeholder)",
		BMShopPanel = "BM Shop (placeholder)",
		InGameShopPanel = "In-Game Shop (placeholder)",
		RelicShopPanel = "Relic Shop (placeholder)",
		RelicFusionPanel = "Relic Fusion (placeholder)",
	}

	for _, pname in ipairs(PANEL_NAMES) do
		local p = Instance.new("Frame")
		p.Name = pname
		p.Visible = false
		p.AnchorPoint = Vector2.new(0.5, 0.5)
		p.Position = UDim2.fromScale(0.5, 0.52)
		p.Size = UDim2.fromOffset(440, 300)
		p.BackgroundColor3 = Color3.fromRGB(34, 34, 42)
		p.BorderSizePixel = 0
		p.Parent = panelsWrap
		corner(p)

		local title = Instance.new("TextLabel")
		title.BackgroundTransparency = 1
		title.Position = UDim2.fromOffset(16, 12)
		title.Size = UDim2.new(1, -100, 0, 26)
		title.Font = Enum.Font.GothamBold
		title.TextSize = 18
		title.TextColor3 = Color3.new(1, 1, 1)
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Text = titles[pname] or pname
		title.Parent = p

		local close = Instance.new("TextButton")
		close.Name = "CloseButton"
		close.AnchorPoint = Vector2.new(1, 0)
		close.Position = UDim2.new(1, -12, 0, 12)
		close.Size = UDim2.fromOffset(76, 30)
		close.Text = "Close"
		close.Font = Enum.Font.GothamMedium
		close.TextSize = 14
		close.TextColor3 = Color3.new(1, 1, 1)
		close.BackgroundColor3 = Color3.fromRGB(86, 50, 50)
		close.BorderSizePixel = 0
		close.Parent = p
		corner(close)

		local body = Instance.new("TextLabel")
		body.BackgroundTransparency = 1
		body.Position = UDim2.fromOffset(16, 50)
		body.Size = UDim2.new(1, -32, 1, -64)
		body.Font = Enum.Font.Gotham
		body.TextSize = 14
		body.TextColor3 = Color3.fromRGB(200, 200, 206)
		body.TextWrapped = true
		body.TextXAlignment = Enum.TextXAlignment.Left
		body.TextYAlignment = Enum.TextYAlignment.Top
		body.Text = "Placeholder — 기능 없음 (서버 연동 안 함)."
		body.Parent = p
	end

	return sg
end

local function warnMissingPanels(panelMap: { [string]: GuiObject })
	for _, n in ipairs(PANEL_NAMES) do
		if not panelMap[n] then
			warn("[LobbyClient] LobbyGui 에 패널 누락:", n)
		end
	end
end

function LobbyClient.init()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	destroyIfPresent(playerGui, LEGACY_PLACEHOLDER)
	destroyIfPresent(playerGui, GUI_NAME)

	local gui: ScreenGui
	local cloned = cloneFromUIAssets(playerGui)

	if cloned then
		gui = cloned
		print("[LobbyClient] LobbyGui cloned from ReplicatedStorage.UIAssets.Lobby")
	else
		warn("[LobbyClient] LobbyGui 템플릿 없음 — 폴백 UI 사용 (경로 src/ReplicatedStorage/UIAssets/Lobby/LobbyGui.rbxmx 참고 EXPORT 문서)")
		gui = buildFallbackLobbyGui()
		gui.Parent = playerGui
	end

	local panelMap = collectPanelMap(gui)
	warnMissingPanels(panelMap)

	wirePlayerActionButtons(gui, panelMap)
	wirePanelCloseButtons(gui, panelMap)
	wireLobbyStations(panelMap)

	print("[LobbyClient] 패널/Station placeholder 연결 완료 (패널 1개만 표시, 서버 기능 없음)")
end

return LobbyClient
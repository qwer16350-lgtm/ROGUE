local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RelicDefinitions = require(Shared:WaitForChild("RelicDefinitions"))

local PANEL_NAME = "RelicFusionPanel"
local LIST_NAME = "RelicCraftList"
local STATUS_NAME = "RelicFusionCraftStatus"

local LobbyRelicFusionPanelClient = {}

local profileClient: any = nil
local onCraftSuccess: (() -> ())? = nil
local fusionPanel: GuiObject? = nil
local statusLabel: TextLabel? = nil
local listFrame: ScrollingFrame? = nil
local listLayout: UIListLayout? = nil
local craftRelicRemote: RemoteFunction? = nil
local refreshing = false

local function deepFind(root: Instance, name: string): Instance?
	if not root then
		return nil
	end
	return root:FindFirstChild(name, true)
end

local function resolveLabel(relicId: string, rowLabel: any): string
	if type(rowLabel) == "string" and rowLabel ~= "" then
		return rowLabel
	end
	local def = RelicDefinitions.getDefinition(relicId)
	if type(def) == "table" then
		local label = def.label
		if type(label) == "string" and label ~= "" then
			return label
		end
	end
	return relicId
end

local function setStatus(text: string, isError: boolean?)
	if statusLabel and statusLabel.Parent then
		statusLabel.Text = text
		if isError then
			statusLabel.TextColor3 = Color3.fromRGB(255, 140, 140)
		else
			statusLabel.TextColor3 = Color3.fromRGB(200, 220, 200)
		end
	end
end

local function clearListRows()
	if not listFrame then
		return
	end
	for _, child in listFrame:GetChildren() do
		if child:IsA("GuiObject") and not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

local function makeSectionHeader(title: string, order: number): TextLabel
	local h = Instance.new("TextLabel")
	h.Name = "Section_" .. title
	h.LayoutOrder = order
	h.Size = UDim2.new(1, -8, 0, 22)
	h.BackgroundTransparency = 1
	h.Font = Enum.Font.GothamBold
	h.TextSize = 14
	h.TextColor3 = Color3.fromRGB(180, 200, 255)
	h.TextXAlignment = Enum.TextXAlignment.Left
	h.Text = title
	return h
end

local function formatMaterialsRequired(materialsRequired: any): string
	if type(materialsRequired) ~= "table" then
		return ""
	end
	local parts = {}
	for key, amt in pairs(materialsRequired) do
		if type(key) == "string" and type(amt) == "number" and amt > 0 then
			table.insert(parts, string.format("%s=%d", key, amt))
		end
	end
	table.sort(parts)
	if #parts == 0 then
		return "materials: none"
	end
	return "needs " .. table.concat(parts, ", ")
end

local function makeCraftRow(row: any, layoutOrder: number): Frame
	local relicId = row.relicId
	local rowFrame = Instance.new("Frame")
	rowFrame.Name = "Row_" .. relicId
	rowFrame.LayoutOrder = layoutOrder
	rowFrame.Size = UDim2.new(1, -8, 0, 52)
	rowFrame.BackgroundColor3 = Color3.fromRGB(42, 42, 52)
	rowFrame.BackgroundTransparency = 0.15
	rowFrame.BorderSizePixel = 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = rowFrame

	local label = resolveLabel(relicId, row.label)
	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Position = UDim2.fromOffset(8, 4)
	nameLabel.Size = UDim2.new(1, -100, 0, 18)
	nameLabel.Font = Enum.Font.GothamMedium
	nameLabel.TextSize = 13
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.Text = label .. " (" .. relicId .. ")"
	nameLabel.Parent = rowFrame

	local subParts = {}
	local bpm = row.blueprintProgressMin
	local bp = row.blueprintProgress
	if type(bpm) == "number" and type(bp) == "number" then
		table.insert(subParts, string.format("BP %d/%d", bp, bpm))
	end
	table.insert(subParts, formatMaterialsRequired(row.materialsRequired))

	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.Position = UDim2.fromOffset(8, 22)
	sub.Size = UDim2.new(1, -100, 0, 28)
	sub.Font = Enum.Font.Gotham
	sub.TextSize = 10
	sub.TextColor3 = Color3.fromRGB(170, 170, 180)
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.TextWrapped = true
	sub.TextYAlignment = Enum.TextYAlignment.Top
	if row.canCraft == true then
		sub.Text = table.concat(subParts, " · Ready")
	else
		local reason = row.craftBlockReason
		if type(reason) ~= "string" or reason == "" then
			reason = "Cannot craft"
		end
		sub.Text = table.concat(subParts, " · ") .. reason
	end
	sub.Parent = rowFrame

	local canCraft = row.canCraft == true
	local craftBtn = Instance.new("TextButton")
	craftBtn.Name = "CraftButton"
	craftBtn.AnchorPoint = Vector2.new(1, 0.5)
	craftBtn.Position = UDim2.new(1, -8, 0.5, 0)
	craftBtn.Size = UDim2.fromOffset(72, 30)
	craftBtn.Font = Enum.Font.GothamMedium
	craftBtn.TextSize = 13
	craftBtn.Text = "Craft"
	craftBtn.TextColor3 = Color3.new(1, 1, 1)
	craftBtn.BackgroundColor3 = Color3.fromRGB(56, 100, 70)
	craftBtn.BorderSizePixel = 0
	craftBtn.AutoButtonColor = true
	craftBtn.Active = canCraft
	craftBtn.BackgroundTransparency = canCraft and 0 or 0.5
	craftBtn.Parent = rowFrame

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 4)
	btnCorner.Parent = craftBtn

	if canCraft then
		craftBtn.MouseButton1Click:Connect(function()
			LobbyRelicFusionPanelClient.craftRelic(relicId)
		end)
	end

	return rowFrame
end

local function renderCraftable(profile: any)
	if not listFrame then
		return
	end
	clearListRows()
	local order = 0

	order += 1
	makeSectionHeader("Craftable", order).Parent = listFrame

	local craftable = profile.craftableRelics
	if type(craftable) ~= "table" or #craftable == 0 then
		order += 1
		local empty = Instance.new("TextLabel")
		empty.LayoutOrder = order
		empty.Size = UDim2.new(1, -8, 0, 18)
		empty.BackgroundTransparency = 1
		empty.Font = Enum.Font.Gotham
		empty.TextSize = 12
		empty.TextColor3 = Color3.fromRGB(180, 180, 190)
		empty.TextXAlignment = Enum.TextXAlignment.Left
		empty.Text = "  (none)"
		empty.Parent = listFrame
	else
		for _, row in ipairs(craftable) do
			if type(row) == "table" and type(row.relicId) == "string" and row.relicId ~= "" then
				order += 1
				makeCraftRow(row, order).Parent = listFrame
			end
		end
	end

	if listLayout and listFrame then
		listFrame.CanvasSize = UDim2.fromOffset(0, listLayout.AbsoluteContentSize.Y + 8)
	end
end

function LobbyRelicFusionPanelClient.refresh()
	if not profileClient or refreshing then
		return
	end
	refreshing = true
	setStatus("Loading profile...", false)

	task.spawn(function()
		local response = profileClient.fetchProfile()
		refreshing = false
		if not fusionPanel or not listFrame then
			return
		end
		if type(response) ~= "table" or response.ok ~= true then
			local reason = type(response) == "table" and response.reason or "LOAD_FAILED"
			setStatus("Profile: " .. tostring(reason), true)
			return
		end
		setStatus("Select Craft.", false)
		renderCraftable(response)
	end)
end

function LobbyRelicFusionPanelClient.craftRelic(relicId: string)
	if type(relicId) ~= "string" or relicId == "" then
		return
	end
	if not craftRelicRemote then
		setStatus("CraftRelicRequest missing", true)
		return
	end
	setStatus("Crafting " .. relicId .. "...", false)

	task.spawn(function()
		local ok, result = pcall(function()
			return craftRelicRemote:InvokeServer(relicId)
		end)
		if not ok then
			setStatus("Craft invoke error", true)
			return
		end
		if type(result) ~= "table" or result.ok ~= true then
			local reason = type(result) == "table" and result.reason or "CRAFT_FAILED"
			setStatus("Craft failed: " .. tostring(reason), true)
			return
		end
		if type(result.profile) == "table" and result.profile.ok == true then
			profileClient.setLastProfile(result.profile)
		end
		setStatus("Crafted: " .. tostring(result.relicId or relicId), false)
		LobbyRelicFusionPanelClient.refresh()
		if onCraftSuccess then
			onCraftSuccess()
		end
	end)
end

local function ensureUi(panel: GuiObject)
	if statusLabel and statusLabel.Parent and listFrame and listFrame.Parent then
		return
	end

	local existingStatus = deepFind(panel, STATUS_NAME)
	if existingStatus and existingStatus:IsA("TextLabel") then
		statusLabel = existingStatus
	else
		local sl = Instance.new("TextLabel")
		sl.Name = STATUS_NAME
		sl.BackgroundTransparency = 1
		sl.Position = UDim2.fromOffset(16, 44)
		sl.Size = UDim2.new(1, -32, 0, 20)
		sl.Font = Enum.Font.GothamMedium
		sl.TextSize = 12
		sl.TextColor3 = Color3.fromRGB(200, 220, 200)
		sl.TextXAlignment = Enum.TextXAlignment.Left
		sl.TextWrapped = true
		sl.Text = ""
		sl.Parent = panel
		statusLabel = sl
	end

	local existingList = deepFind(panel, LIST_NAME)
	if existingList and existingList:IsA("ScrollingFrame") then
		listFrame = existingList
	else
		local scroll = Instance.new("ScrollingFrame")
		scroll.Name = LIST_NAME
		scroll.BackgroundTransparency = 1
		scroll.BorderSizePixel = 0
		scroll.Position = UDim2.fromOffset(12, 68)
		scroll.Size = UDim2.new(1, -24, 1, -80)
		scroll.ScrollBarThickness = 6
		scroll.CanvasSize = UDim2.fromOffset(0, 0)
		scroll.Parent = panel
		listFrame = scroll
	end

	local layout = listFrame:FindFirstChildOfClass("UIListLayout")
	if not layout then
		layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 6)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = listFrame
	end
	listLayout = layout

	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		if listFrame then
			listFrame.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 8)
		end
	end)
end

local function wireAttributeCraftButtons(panel: GuiObject)
	for _, desc in panel:GetDescendants() do
		if desc:IsA("GuiButton") and (desc.Name == "CraftButton" or string.find(desc.Name, "Craft", 1, true)) then
			local relicId = desc:GetAttribute("RelicId")
			if type(relicId) == "string" and relicId ~= "" then
				desc.MouseButton1Click:Connect(function()
					LobbyRelicFusionPanelClient.craftRelic(relicId)
				end)
			end
		end
	end
end

function LobbyRelicFusionPanelClient.notifyPanelOpened()
	if fusionPanel and fusionPanel.Visible then
		LobbyRelicFusionPanelClient.refresh()
	end
end

function LobbyRelicFusionPanelClient.init(root: Instance, relicProfileClient: any, opts: { onCraftSuccess: (() -> ())? }?)
	profileClient = relicProfileClient
	if type(opts) == "table" and type(opts.onCraftSuccess) == "function" then
		onCraftSuccess = opts.onCraftSuccess
	end

	local panel = deepFind(root, PANEL_NAME)
	if not panel or not panel:IsA("GuiObject") then
		warn("[LobbyRelicFusionPanelClient] RelicFusionPanel missing")
		return
	end
	fusionPanel = panel

	local remotes = ReplicatedStorage:WaitForChild("Remotes", 15)
	if remotes then
		craftRelicRemote = remotes:WaitForChild("CraftRelicRequest", 15) :: RemoteFunction?
	end
	if not craftRelicRemote or not craftRelicRemote:IsA("RemoteFunction") then
		warn("[LobbyRelicFusionPanelClient] CraftRelicRequest missing")
	end

	ensureUi(panel)
	wireAttributeCraftButtons(panel)
	print("[LobbyRelicFusionPanelClient] fusion craft panel enabled")
end

return LobbyRelicFusionPanelClient

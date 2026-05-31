local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RelicDefinitions = require(Shared:WaitForChild("RelicDefinitions"))

local PANEL_NAME = "ArtifactCollectionPanel"
local LIST_NAME = "RelicCollectionList"
local STATUS_NAME = "RelicCollectionStatus"
local EQUIP_BLOCK_NAME = "RelicEquipReadOnly"

local LobbyRelicCollectionPanelClient = {}

local profileClient: any = nil
local collectionPanel: GuiObject? = nil
local statusLabel: TextLabel? = nil
local listFrame: ScrollingFrame? = nil
local listLayout: UIListLayout? = nil
local equipBlock: TextLabel? = nil
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

local function makeTextRow(text: string, order: number): TextLabel
	local row = Instance.new("TextLabel")
	row.LayoutOrder = order
	row.Size = UDim2.new(1, -8, 0, 18)
	row.BackgroundTransparency = 1
	row.Font = Enum.Font.Gotham
	row.TextSize = 12
	row.TextColor3 = Color3.fromRGB(210, 210, 220)
	row.TextXAlignment = Enum.TextXAlignment.Left
	row.TextTruncate = Enum.TextTruncate.AtEnd
	row.Text = text
	return row
end

local function collectOwnedIds(profile: any): { string }
	local out: { string } = {}
	if type(profile) ~= "table" or type(profile.ownedRelics) ~= "table" then
		return out
	end
	for relicId, owned in pairs(profile.ownedRelics) do
		if type(relicId) == "string" and relicId ~= "" and owned == true then
			table.insert(out, relicId)
		end
	end
	table.sort(out)
	return out
end

local function formatBlueprintLines(profile: any): { string }
	local lines: { string } = {}
	local bp = type(profile) == "table" and profile.blueprintProgress or nil
	if type(bp) ~= "table" then
		return lines
	end
	local keys: { string } = {}
	for blueprintId, progress in pairs(bp) do
		if type(blueprintId) == "string" and blueprintId ~= "" and type(progress) == "number" and progress > 0 then
			table.insert(keys, blueprintId)
		end
	end
	table.sort(keys)
	for _, blueprintId in ipairs(keys) do
		table.insert(lines, string.format("%s: %d", blueprintId, bp[blueprintId]))
	end
	return lines
end

local function formatEquippedSummary(profile: any): string
	local equipped = type(profile) == "table" and profile.equippedStartingRelics or nil
	local slotMax = type(profile) == "table" and profile.relicStartingSlotMax or nil
	if type(slotMax) ~= "number" then
		slotMax = 0
	end
	local ids: { string } = {}
	if type(equipped) == "table" then
		for _, relicId in ipairs(equipped) do
			if type(relicId) == "string" and relicId ~= "" then
				table.insert(ids, relicId)
			end
		end
	end
	local equippedText = #ids > 0 and table.concat(ids, ", ") or "(none)"
	return string.format("Equipped: %s (%d/%d slots)", equippedText, #ids, slotMax)
end

local function formatStartingEligibleNotice(profile: any): string
	local eligible = type(profile) == "table" and profile.startingEligibleRelics or nil
	local count = 0
	if type(eligible) == "table" then
		count = #eligible
	end
	if count == 0 then
		return "Starting-eligible relics: none (Step 7)"
	end
	return string.format("Starting-eligible relics: %d", count)
end

local function renderEquipReadOnly(profile: any)
	if not equipBlock or not equipBlock.Parent then
		return
	end
	equipBlock.Text = formatEquippedSummary(profile)
		.. "\n"
		.. formatStartingEligibleNotice(profile)
		.. "\n(Equip UI — Step 7)"
end

local function renderProfile(profile: any)
	if not listFrame then
		return
	end
	clearListRows()
	local order = 0

	order += 1
	makeSectionHeader("Owned", order).Parent = listFrame

	local ownedIds = collectOwnedIds(profile)
	if #ownedIds == 0 then
		order += 1
		makeTextRow("  (none)", order).Parent = listFrame
	else
		for _, relicId in ipairs(ownedIds) do
			order += 1
			makeTextRow(resolveLabel(relicId, nil) .. " (" .. relicId .. ")", order).Parent = listFrame
		end
	end

	order += 1
	makeSectionHeader("Blueprint progress", order).Parent = listFrame

	local bpLines = formatBlueprintLines(profile)
	if #bpLines == 0 then
		order += 1
		makeTextRow("  (none)", order).Parent = listFrame
	else
		for _, line in ipairs(bpLines) do
			order += 1
			makeTextRow("  " .. line, order).Parent = listFrame
		end
	end

	renderEquipReadOnly(profile)

	if listLayout and listFrame then
		listFrame.CanvasSize = UDim2.fromOffset(0, listLayout.AbsoluteContentSize.Y + 8)
	end
end

local function ensureUi(panel: GuiObject)
	if statusLabel and statusLabel.Parent and listFrame and listFrame.Parent and equipBlock and equipBlock.Parent then
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
		sl.Size = UDim2.new(1, -32, 0, 18)
		sl.Font = Enum.Font.GothamMedium
		sl.TextSize = 12
		sl.TextColor3 = Color3.fromRGB(200, 220, 200)
		sl.TextXAlignment = Enum.TextXAlignment.Left
		sl.Text = ""
		sl.Parent = panel
		statusLabel = sl
	end

	local existingEquip = deepFind(panel, EQUIP_BLOCK_NAME)
	if existingEquip and existingEquip:IsA("TextLabel") then
		equipBlock = existingEquip
	else
		local eq = Instance.new("TextLabel")
		eq.Name = EQUIP_BLOCK_NAME
		eq.BackgroundTransparency = 1
		eq.AnchorPoint = Vector2.new(0, 1)
		eq.Position = UDim2.new(0, 16, 1, -48)
		eq.Size = UDim2.new(1, -32, 0, 56)
		eq.Font = Enum.Font.Gotham
		eq.TextSize = 11
		eq.TextColor3 = Color3.fromRGB(170, 180, 200)
		eq.TextXAlignment = Enum.TextXAlignment.Left
		eq.TextYAlignment = Enum.TextYAlignment.Top
		eq.TextWrapped = true
		eq.Text = ""
		eq.Parent = panel
		equipBlock = eq
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
		scroll.Size = UDim2.new(1, -24, 1, -120)
		scroll.ScrollBarThickness = 6
		scroll.CanvasSize = UDim2.fromOffset(0, 0)
		scroll.Parent = panel
		listFrame = scroll
	end

	local layout = listFrame:FindFirstChildOfClass("UIListLayout")
	if not layout then
		layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 4)
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

function LobbyRelicCollectionPanelClient.refresh()
	if not profileClient or refreshing then
		return
	end
	refreshing = true
	setStatus("Loading profile...", false)

	task.spawn(function()
		local response = profileClient.fetchProfile()
		refreshing = false
		if not collectionPanel or not listFrame then
			return
		end
		if type(response) ~= "table" or response.ok ~= true then
			local reason = type(response) == "table" and response.reason or "LOAD_FAILED"
			setStatus("Profile: " .. tostring(reason), true)
			return
		end
		setStatus("Collection loaded.", false)
		renderProfile(response)
	end)
end

function LobbyRelicCollectionPanelClient.notifyPanelOpened()
	if collectionPanel and collectionPanel.Visible then
		LobbyRelicCollectionPanelClient.refresh()
	end
end

function LobbyRelicCollectionPanelClient.init(root: Instance, relicProfileClient: any)
	profileClient = relicProfileClient

	local panel = deepFind(root, PANEL_NAME)
	if not panel or not panel:IsA("GuiObject") then
		warn("[LobbyRelicCollectionPanelClient] ArtifactCollectionPanel missing")
		return
	end
	collectionPanel = panel

	ensureUi(panel)
	print("[LobbyRelicCollectionPanelClient] collection panel enabled")
end

return LobbyRelicCollectionPanelClient

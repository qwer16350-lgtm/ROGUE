local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RelicDefinitions = require(Shared:WaitForChild("RelicDefinitions"))

local PANEL_NAME = "StartingRelicPanel"
local LIST_NAME = "StartingRelicOwnedList"
local STATUS_NAME = "StartingRelicStatus"
local SLOT_LABEL_NAME = "StartingRelicSlotLabel"
local CLEAR_BUTTON_NAME = "StartingRelicClearSlotsButton"
local LEGACY_LIST_NAME = "RelicButtonList"

local LEGACY_RELIC_IDS: { [string]: boolean } = {
	old_shield_emblem = true,
	cracked_sword_tip = true,
	knights_belt = true,
}

local LEGACY_BUTTON_NAMES: { [string]: boolean } = {
	OldShieldEmblem = true,
	OldShieldEmblemButton = true,
	CrackedSwordTip = true,
	CrackedSwordTipButton = true,
	CrackedSwordTi = true,
	KnightsBeltButton = true,
}

local LobbyRelicStartingPanelClient = {}

local profileClient: any = nil
local equipRemote: RemoteFunction? = nil
local startingPanel: GuiObject? = nil
local statusLabel: TextLabel? = nil
local slotLabel: TextLabel? = nil
local listFrame: ScrollingFrame? = nil
local listLayout: UIListLayout? = nil
local visibleConn: RBXScriptConnection? = nil
local refreshing = false

local function deepFind(root: Instance, name: string): Instance?
	if not root then
		return nil
	end
	return root:FindFirstChild(name, true)
end

local function stripLegacyStartingRelicUi(panel: GuiObject)
	local legacyList = panel:FindFirstChild(LEGACY_LIST_NAME)
	if legacyList then
		legacyList:Destroy()
	end
	for _, desc in panel:GetDescendants() do
		if LEGACY_BUTTON_NAMES[desc.Name] then
			desc:Destroy()
		elseif desc:IsA("GuiButton") then
			local relicId = desc:GetAttribute("StartingRelicId")
			if type(relicId) == "string" and LEGACY_RELIC_IDS[relicId] then
				desc:Destroy()
			end
		end
	end
end

local function resolveLabel(relicId: string): string
	local def = RelicDefinitions.getDefinition(relicId)
	if type(def) == "table" then
		local label = def.label
		if type(label) == "string" and label ~= "" then
			return label
		end
	end
	return relicId
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

local function getEquippedSet(profile: any): { [string]: boolean }
	local set: { [string]: boolean } = {}
	if type(profile) ~= "table" or type(profile.equippedStartingRelics) ~= "table" then
		return set
	end
	for _, relicId in ipairs(profile.equippedStartingRelics) do
		if type(relicId) == "string" and relicId ~= "" then
			set[relicId] = true
		end
	end
	return set
end

local function copyEquippedList(profile: any): { string }
	local out: { string } = {}
	if type(profile) ~= "table" or type(profile.equippedStartingRelics) ~= "table" then
		return out
	end
	for _, relicId in ipairs(profile.equippedStartingRelics) do
		if type(relicId) == "string" and relicId ~= "" then
			table.insert(out, relicId)
		end
	end
	return out
end

local function getSlotMax(profile: any): number
	if type(profile) == "table" and type(profile.relicStartingSlotMax) == "number" then
		return profile.relicStartingSlotMax
	end
	return 0
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

local function updateSlotLabel(profile: any)
	if not slotLabel or not slotLabel.Parent then
		return
	end
	local slotMax = type(profile.relicStartingSlotMax) == "number" and profile.relicStartingSlotMax or 0
	local equipped = profile.equippedStartingRelics
	local count = 0
	local names: { string } = {}
	if type(equipped) == "table" then
		for _, relicId in ipairs(equipped) do
			if type(relicId) == "string" and relicId ~= "" then
				count += 1
				table.insert(names, resolveLabel(relicId))
			end
		end
	end
	local equippedText = #names > 0 and table.concat(names, ", ") or "(none)"
	slotLabel.Text = string.format("Run slots: %s (%d/%d)", equippedText, count, slotMax)
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

local function invokeEquip(relicIds: { string }, onDone: (boolean, string?) -> ())
	if not equipRemote then
		onDone(false, "REMOTE_MISSING")
		return
	end
	task.spawn(function()
		local ok, result = pcall(function()
			return equipRemote:InvokeServer(relicIds)
		end)
		if not ok then
			onDone(false, "INVOKE_ERROR")
			return
		end
		if type(result) ~= "table" or result.ok ~= true then
			local reason = type(result) == "table" and result.reason or "EQUIP_FAILED"
			onDone(false, reason)
			return
		end
		if type(result.profile) == "table" and result.profile.ok == true then
			profileClient.setLastProfile(result.profile)
		end
		onDone(true, nil)
	end)
end

local function makeOwnedRow(
	relicId: string,
	equipped: boolean,
	slotMax: number,
	equippedCount: number,
	currentEquipped: { string },
	layoutOrder: number
): Frame
	local row = Instance.new("Frame")
	row.Name = "Row_" .. relicId
	row.LayoutOrder = layoutOrder
	row.Size = UDim2.new(1, -8, 0, 48)
	row.BackgroundColor3 = Color3.fromRGB(42, 42, 52)
	row.BackgroundTransparency = 0.15
	row.BorderSizePixel = 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = row

	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Position = UDim2.fromOffset(8, 4)
	nameLabel.Size = UDim2.new(1, -100, 0, 18)
	nameLabel.Font = Enum.Font.GothamMedium
	nameLabel.TextSize = 13
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.Text = resolveLabel(relicId) .. " (" .. relicId .. ")"
	nameLabel.Parent = row

	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.Position = UDim2.fromOffset(8, 22)
	sub.Size = UDim2.new(1, -100, 0, 16)
	sub.Font = Enum.Font.Gotham
	sub.TextSize = 11
	sub.TextColor3 = Color3.fromRGB(170, 170, 180)
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.Text = if equipped then "Equipped for run" else "Owned — add to run loadout"
	sub.Parent = row

	local actionBtn = Instance.new("TextButton")
	actionBtn.Name = "SlotActionButton"
	actionBtn.AnchorPoint = Vector2.new(1, 0.5)
	actionBtn.Position = UDim2.new(1, -8, 0.5, 0)
	actionBtn.Size = UDim2.fromOffset(88, 30)
	actionBtn.Font = Enum.Font.GothamMedium
	actionBtn.TextSize = 12
	actionBtn.TextColor3 = Color3.new(1, 1, 1)
	actionBtn.BorderSizePixel = 0
	actionBtn.AutoButtonColor = true

	if equipped then
		actionBtn.Text = "Remove"
		actionBtn.Active = true
		actionBtn.BackgroundColor3 = Color3.fromRGB(86, 50, 50)
		actionBtn.BackgroundTransparency = 0
		actionBtn.MouseButton1Click:Connect(function()
			local nextIds: { string } = {}
			for _, id in ipairs(currentEquipped) do
				if id ~= relicId then
					table.insert(nextIds, id)
				end
			end
			setStatus("Removing " .. relicId .. "...", false)
			invokeEquip(nextIds, function(ok, reason)
				if ok then
					setStatus("Removed: " .. relicId, false)
					LobbyRelicStartingPanelClient.refresh()
				else
					setStatus("Remove failed: " .. tostring(reason), true)
				end
			end)
		end)
	elseif equippedCount >= slotMax then
		actionBtn.Text = "Full"
		actionBtn.Active = false
		actionBtn.BackgroundColor3 = Color3.fromRGB(55, 55, 62)
		actionBtn.BackgroundTransparency = 0.35
	else
		actionBtn.Text = "Add"
		actionBtn.Active = true
		actionBtn.BackgroundColor3 = Color3.fromRGB(56, 100, 70)
		actionBtn.BackgroundTransparency = 0
		actionBtn.MouseButton1Click:Connect(function()
			local nextIds = table.clone(currentEquipped)
			table.insert(nextIds, relicId)
			setStatus("Adding " .. relicId .. "...", false)
			invokeEquip(nextIds, function(ok, reason)
				if ok then
					setStatus("Added: " .. relicId, false)
					LobbyRelicStartingPanelClient.refresh()
				else
					setStatus("Add failed: " .. tostring(reason), true)
				end
			end)
		end)
	end
	actionBtn.Parent = row

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 4)
	btnCorner.Parent = actionBtn

	return row
end

local function renderProfile(profile: any)
	if not listFrame then
		return
	end
	clearListRows()
	updateSlotLabel(profile)

	local order = 0
	order += 1
	local header = Instance.new("TextLabel")
	header.LayoutOrder = order
	header.Size = UDim2.new(1, -8, 0, 22)
	header.BackgroundTransparency = 1
	header.Font = Enum.Font.GothamBold
	header.TextSize = 14
	header.TextColor3 = Color3.fromRGB(180, 200, 255)
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Text = "Owned relics (all)"
	header.Parent = listFrame

	local ownedIds = collectOwnedIds(profile)
	local equippedSet = getEquippedSet(profile)
	local slotMax = getSlotMax(profile)
	local equippedList = copyEquippedList(profile)
	local equippedCount = #equippedList

	if #ownedIds == 0 then
		order += 1
		local empty = Instance.new("TextLabel")
		empty.LayoutOrder = order
		empty.Size = UDim2.new(1, -8, 0, 18)
		empty.BackgroundTransparency = 1
		empty.Font = Enum.Font.Gotham
		empty.TextSize = 12
		empty.TextColor3 = Color3.fromRGB(180, 180, 190)
		empty.TextXAlignment = Enum.TextXAlignment.Left
		empty.Text = "  (none — craft in Relic Fusion)"
		empty.Parent = listFrame
	else
		for _, relicId in ipairs(ownedIds) do
			order += 1
			makeOwnedRow(
				relicId,
				equippedSet[relicId] == true,
				slotMax,
				equippedCount,
				equippedList,
				order
			).Parent = listFrame
		end
	end

	order += 1
	local foot = Instance.new("TextLabel")
	foot.LayoutOrder = order
	foot.Size = UDim2.new(1, -8, 0, 32)
	foot.BackgroundTransparency = 1
	foot.Font = Enum.Font.Gotham
	foot.TextSize = 11
	foot.TextColor3 = Color3.fromRGB(150, 160, 175)
	foot.TextXAlignment = Enum.TextXAlignment.Left
	foot.TextWrapped = true
	foot.Text = string.format(
		"Pick up to %d owned relic(s) for this run. Others stay in the chest pool (Step 7B). isStartingEligible is not used here.",
		slotMax
	)
	foot.Parent = listFrame

	if listLayout and listFrame then
		listFrame.CanvasSize = UDim2.fromOffset(0, listLayout.AbsoluteContentSize.Y + 8)
	end

	local selectedLabel = deepFind(startingPanel, "SelectedStartingRelicLabel")
	if selectedLabel and selectedLabel:IsA("TextLabel") then
		local equipped = profile.equippedStartingRelics
		if type(equipped) == "table" and #equipped > 0 and type(equipped[1]) == "string" then
			selectedLabel.Text = "Selected: " .. resolveLabel(equipped[1])
		else
			selectedLabel.Text = "Selected: (none)"
		end
	end
end

function LobbyRelicStartingPanelClient.refresh()
	if not profileClient or refreshing then
		return
	end
	refreshing = true
	setStatus("Loading profile...", false)

	task.spawn(function()
		local response = profileClient.fetchProfile()
		refreshing = false
		if not startingPanel or not listFrame then
			return
		end
		if type(response) ~= "table" or response.ok ~= true then
			local reason = type(response) == "table" and response.reason or "LOAD_FAILED"
			setStatus("Profile: " .. tostring(reason), true)
			return
		end
		setStatus("Owned relics loaded.", false)
		renderProfile(response)
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
		sl.Size = UDim2.new(1, -32, 0, 18)
		sl.Font = Enum.Font.GothamMedium
		sl.TextSize = 12
		sl.TextColor3 = Color3.fromRGB(200, 220, 200)
		sl.TextXAlignment = Enum.TextXAlignment.Left
		sl.Text = ""
		sl.Parent = panel
		statusLabel = sl
	end

	local existingSlot = deepFind(panel, SLOT_LABEL_NAME)
	if existingSlot and existingSlot:IsA("TextLabel") then
		slotLabel = existingSlot
	else
		local sl = Instance.new("TextLabel")
		sl.Name = SLOT_LABEL_NAME
		sl.BackgroundTransparency = 1
		sl.Position = UDim2.fromOffset(16, 64)
		sl.Size = UDim2.new(1, -32, 0, 18)
		sl.Font = Enum.Font.Gotham
		sl.TextSize = 12
		sl.TextColor3 = Color3.fromRGB(190, 200, 210)
		sl.TextXAlignment = Enum.TextXAlignment.Left
		sl.Text = ""
		sl.Parent = panel
		slotLabel = sl
	end

	local existingList = deepFind(panel, LIST_NAME)
	if existingList and existingList:IsA("ScrollingFrame") then
		listFrame = existingList
	else
		local scroll = Instance.new("ScrollingFrame")
		scroll.Name = LIST_NAME
		scroll.BackgroundTransparency = 1
		scroll.BorderSizePixel = 0
		scroll.Position = UDim2.fromOffset(12, 88)
		scroll.Size = UDim2.new(1, -24, 1, -100)
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

	local existingClear = deepFind(panel, CLEAR_BUTTON_NAME)
	if not existingClear or not existingClear:IsA("GuiButton") then
		local clearBtn = Instance.new("TextButton")
		clearBtn.Name = CLEAR_BUTTON_NAME
		clearBtn.Position = UDim2.new(1, -108, 0, 64)
		clearBtn.Size = UDim2.fromOffset(92, 24)
		clearBtn.Font = Enum.Font.GothamMedium
		clearBtn.TextSize = 11
		clearBtn.Text = "Clear slots"
		clearBtn.TextColor3 = Color3.new(1, 1, 1)
		clearBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 82)
		clearBtn.BorderSizePixel = 0
		clearBtn.Parent = panel
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 4)
		c.Parent = clearBtn
		clearBtn.MouseButton1Click:Connect(function()
			setStatus("Clearing slots...", false)
			invokeEquip({}, function(ok, reason)
				if ok then
					setStatus("Slots cleared ({}).", false)
					LobbyRelicStartingPanelClient.refresh()
				else
					setStatus("Clear failed: " .. tostring(reason), true)
				end
			end)
		end)
	end
end

local function onPanelVisibilityChanged()
	if not startingPanel or not startingPanel.Visible then
		return
	end
	LobbyRelicStartingPanelClient.refresh()
end

function LobbyRelicStartingPanelClient.init(root: Instance, relicProfileClient: any)
	profileClient = relicProfileClient

	local panel = deepFind(root, PANEL_NAME)
	if not panel or not panel:IsA("GuiObject") then
		warn("[LobbyRelicStartingPanelClient] StartingRelicPanel missing")
		return
	end
	startingPanel = panel
	stripLegacyStartingRelicUi(panel)

	local remotes = ReplicatedStorage:WaitForChild("Remotes", 15)
	if remotes then
		equipRemote = remotes:WaitForChild("EquipStartingRelicsRequest", 15) :: RemoteFunction?
	end
	if not equipRemote or not equipRemote:IsA("RemoteFunction") then
		warn("[LobbyRelicStartingPanelClient] EquipStartingRelicsRequest missing")
	end

	ensureUi(panel)

	if visibleConn then
		visibleConn:Disconnect()
		visibleConn = nil
	end
	visibleConn = panel:GetPropertyChangedSignal("Visible"):Connect(onPanelVisibilityChanged)

	print("[LobbyRelicStartingPanelClient] starting panel enabled (owned loadout, slot cap, Equip RF)")
end

function LobbyRelicStartingPanelClient.notifyPanelOpened()
	if startingPanel and startingPanel.Visible then
		LobbyRelicStartingPanelClient.refresh()
	end
end

return LobbyRelicStartingPanelClient

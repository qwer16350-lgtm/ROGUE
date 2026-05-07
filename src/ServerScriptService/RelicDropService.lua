local RelicDropService = {}

local DROP_KIND = "RelicChest"
local PICKUP_RADIUS_STUDS = 4
local DROP_PART_SIZE = Vector3.new(2.75, 2.75, 2.75)

type ProgressionApi = {
	tryGrantDroppedRelicOfferFromChest: (Player) -> boolean,
}

local activeRelicChests: { BasePart } = {}

local function ensureRelicChestFolder(workspace: Workspace): Folder
	local folder = workspace:FindFirstChild("RelicChests")
	if folder and folder:IsA("Folder") then
		return folder
	end
	local f = Instance.new("Folder")
	f.Name = "RelicChests"
	f.Parent = workspace
	return f
end

local function removeFromList(part: BasePart)
	for i = #activeRelicChests, 1, -1 do
		if activeRelicChests[i] == part then
			table.remove(activeRelicChests, i)
			break
		end
	end
end

local function destroyDropPart(part: BasePart?)
	if not part then
		return
	end
	removeFromList(part)
	if part.Parent then
		part:Destroy()
	end
end

local function clearDropsForUserId(userId: number)
	for i = #activeRelicChests, 1, -1 do
		local part = activeRelicChests[i]
		local bound = part and part.Parent and part:GetAttribute("BoundUserId")
		if part and part.Parent and type(bound) == "number" and bound == userId then
			part:Destroy()
			table.remove(activeRelicChests, i)
		elseif not part or not part.Parent then
			table.remove(activeRelicChests, i)
		end
	end
end

function RelicDropService.init(players, runService, workspace: Workspace, progressionService: ProgressionApi)
	ensureRelicChestFolder(workspace)

	runService.Heartbeat:Connect(function()
		for i = #activeRelicChests, 1, -1 do
			local part = activeRelicChests[i]
			if not part.Parent then
				table.remove(activeRelicChests, i)
				continue
			end
			local bound = part:GetAttribute("BoundUserId")
			if type(bound) ~= "number" then
				continue
			end
			local player = players:GetPlayerByUserId(bound)
			if not player or not player.Parent then
				continue
			end
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not hrp then
				continue
			end
			if (hrp.Position - part.Position).Magnitude <= PICKUP_RADIUS_STUDS then
				progressionService.tryGrantDroppedRelicOfferFromChest(player)
				destroyDropPart(part)
			end
		end
	end)

	players.PlayerRemoving:Connect(function(player)
		clearDropsForUserId(player.UserId)
	end)
end

function RelicDropService.spawnRelicChestAt(worldPosition: Vector3, boundPlayer: Player)
	if typeof(boundPlayer) ~= "Instance" or not boundPlayer:IsA("Player") then
		return
	end

	local workspace = game:GetService("Workspace")
	local dropsFolder = ensureRelicChestFolder(workspace)
	local pos = worldPosition + Vector3.new(0, 1, 0)

	local part = Instance.new("Part")
	part.Name = "RelicChestDrop"
	part.Size = DROP_PART_SIZE
	part.Shape = Enum.PartType.Ball
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(171, 85, 255)
	part.CFrame = CFrame.new(pos)
	part:SetAttribute("DropKind", DROP_KIND)
	part:SetAttribute("BoundUserId", boundPlayer.UserId)

	local light = Instance.new("PointLight")
	light.Brightness = 2.75
	light.Range = 14
	light.Color = Color3.fromRGB(196, 120, 255)
	light.Parent = part

	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(Color3.fromRGB(214, 160, 255), Color3.fromRGB(143, 74, 232))
	pe.LightEmission = 1
	pe.Size = NumberSequence.new(0.3, 0.1)
	pe.Lifetime = NumberRange.new(0.45, 1.0)
	pe.Rate = 14
	pe.Speed = NumberRange.new(0.5, 1.6)
	pe.SpreadAngle = Vector2.new(30, 30)
	pe.Parent = part

	part.Parent = dropsFolder
	table.insert(activeRelicChests, part)
end

return RelicDropService
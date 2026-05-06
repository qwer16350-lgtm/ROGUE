--- SwordShield 무기 드롭: 월드 스폰·다중 활성 드롭·거리 기반 획득. 승급은 ProgressionService.

local WeaponDropService = {}

local DROP_KIND = "Weapon"
local DROP_WEAPON_ID = "SwordShield"
local PICKUP_RADIUS_STUDS = 4
local DROP_PART_SIZE = Vector3.new(2.75, 2.75, 2.75)
-- 테스트 편의용 후보 가중치(초기값). 밸런스 단계에서 조정 예정.
local WEAPON_DROP_CANDIDATES = {
	{ weaponId = "SwordShield", weight = 40 },
	{ weaponId = "Spear", weight = 30 },
	{ weaponId = "TwoHandedSword", weight = 30 },
}

type ProgressionApi = {
	tryApplyWeaponDropPickup: (Player, string) -> boolean,
}

local activeWeaponDrops: { BasePart } = {}

local function ensureWeaponDropsFolder(workspace: Workspace): Folder
	local folder = workspace:FindFirstChild("WeaponDrops")
	if folder and folder:IsA("Folder") then
		return folder
	end
	local f = Instance.new("Folder")
	f.Name = "WeaponDrops"
	f.Parent = workspace
	return f
end

local function removeDropFromList(part: BasePart)
	for i = #activeWeaponDrops, 1, -1 do
		if activeWeaponDrops[i] == part then
			table.remove(activeWeaponDrops, i)
			break
		end
	end
end

local function destroyDropPart(part: BasePart?)
	if not part then
		return
	end
	removeDropFromList(part)
	if part.Parent then
		part:Destroy()
	end
end

local function clearDropsForUserId(userId: number)
	for i = #activeWeaponDrops, 1, -1 do
		local part = activeWeaponDrops[i]
		local bound = part and part.Parent and part:GetAttribute("BoundUserId")
		if part and part.Parent and type(bound) == "number" and bound == userId then
			part:Destroy()
			table.remove(activeWeaponDrops, i)
		elseif not part or not part.Parent then
			table.remove(activeWeaponDrops, i)
		end
	end
end

function WeaponDropService.init(players, runService, workspace: Workspace, progressionService: ProgressionApi)
	ensureWeaponDropsFolder(workspace)

	runService.Heartbeat:Connect(function()
		for i = #activeWeaponDrops, 1, -1 do
			local part = activeWeaponDrops[i]
			if not part.Parent then
				table.remove(activeWeaponDrops, i)
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
				local wid: string = DROP_WEAPON_ID
				local wAttr = part:GetAttribute("WeaponId")
				if type(wAttr) == "string" then
					wid = wAttr
				end
				progressionService.tryApplyWeaponDropPickup(player, wid)
				destroyDropPart(part)
			end
		end
	end)

	players.PlayerRemoving:Connect(function(player)
		clearDropsForUserId(player.UserId)
	end)
end

local function pickDropWeaponId(): string
	local total = 0
	for _, c in ipairs(WEAPON_DROP_CANDIDATES) do
		if type(c) == "table" and type(c.weaponId) == "string" then
			local w = c.weight
			if type(w) ~= "number" or w <= 0 then
				w = 1
			end
			total += w
		end
	end
	if total <= 0 then
		return "SwordShield"
	end
	local r = math.random() * total
	for _, c in ipairs(WEAPON_DROP_CANDIDATES) do
		if type(c) == "table" and type(c.weaponId) == "string" then
			local w = c.weight
			if type(w) ~= "number" or w <= 0 then
				w = 1
			end
			r -= w
			if r <= 0 then
				return c.weaponId
			end
		end
	end
	return "SwordShield"
end

function WeaponDropService.pickDropWeaponId(): string
	return pickDropWeaponId()
end

--- 적 사망 위치 등 월드 좌표에 드롭 1개 생성. 킬을 낸 플레이어만 획득 가능.
function WeaponDropService.spawnWeaponDropAt(worldPosition: Vector3, boundPlayer: Player, weaponId: string)
	if typeof(boundPlayer) ~= "Instance" or not boundPlayer:IsA("Player") then
		return
	end
	if type(weaponId) ~= "string" or weaponId == "" then
		weaponId = DROP_WEAPON_ID
	end

	local workspace = game:GetService("Workspace")
	local dropsFolder = ensureWeaponDropsFolder(workspace)
	local pos = worldPosition + Vector3.new(0, 1, 0)

	local part = Instance.new("Part")
	part.Name = "WeaponDrop_" .. weaponId
	part.Size = DROP_PART_SIZE
	part.Shape = Enum.PartType.Ball
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(255, 220, 40)
	part.CFrame = CFrame.new(pos)
	part:SetAttribute("DropKind", DROP_KIND)
	part:SetAttribute("WeaponId", weaponId)
	part:SetAttribute("BoundUserId", boundPlayer.UserId)

	local light = Instance.new("PointLight")
	light.Brightness = 2.5
	light.Range = 14
	light.Color = Color3.fromRGB(255, 230, 80)
	light.Parent = part

	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(Color3.fromRGB(255, 240, 100), Color3.fromRGB(255, 200, 40))
	pe.LightEmission = 1
	pe.Size = NumberSequence.new(0.35, 0.1)
	pe.Lifetime = NumberRange.new(0.4, 0.9)
	pe.Rate = 12
	pe.Speed = NumberRange.new(0.5, 1.5)
	pe.SpreadAngle = Vector2.new(25, 25)
	pe.Parent = part

	part.Parent = dropsFolder
	table.insert(activeWeaponDrops, part)
end

function WeaponDropService.spawnSwordShieldDropAt(worldPosition: Vector3, boundPlayer: Player)
	return WeaponDropService.spawnWeaponDropAt(worldPosition, boundPlayer, "SwordShield")
end

return WeaponDropService

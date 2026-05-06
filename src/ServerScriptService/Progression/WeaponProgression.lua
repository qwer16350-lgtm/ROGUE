--[[
  무기 진행 도메인: progressByPlayer[player] 테이블의 weaponId / weaponGrade 필드만 다룬다.
  저장 구조 분리 없음 — 필드는 호출부가 넘긴 state에 유지된다.
]]

local WeaponProgression = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local WeaponProfiles = require(Shared:WaitForChild("WeaponProfiles"))

local function ensureActiveWeapons(state: any)
	if type(state.activeWeapons) ~= "table" then
		state.activeWeapons = {}
	end
	return state.activeWeapons
end

local function normalizeGrade(raw): string
	if raw == "Rare" then
		return "Rare"
	end
	return "Normal"
end

--- resolveEffectiveWeaponId 결과 eff 및 디버그 오버라이드 플래그로 weapon 필드를 보정한다.
function WeaponProgression.ensureWeaponFields(state: any, eff: string, hasOverride: boolean)
	if hasOverride then
		state.weaponId = eff
	elseif state.weaponId == nil or (state.weaponId ~= "SwordShield" and state.weaponId ~= "BasicMagic") then
		state.weaponId = eff
	end
	if state.weaponGrade == nil then
		state.weaponGrade = "Normal"
	end
	local activeWeapons = ensureActiveWeapons(state)
	local primaryWeaponId = state.weaponId
	if type(primaryWeaponId) == "string" and primaryWeaponId ~= "" and activeWeapons[primaryWeaponId] == nil then
		activeWeapons[primaryWeaponId] = {
			weaponId = primaryWeaponId,
			grade = normalizeGrade(state.weaponGrade),
		}
	end
	if type(primaryWeaponId) == "string" and activeWeapons[primaryWeaponId] then
		activeWeapons[primaryWeaponId].grade = normalizeGrade(activeWeapons[primaryWeaponId].grade or state.weaponGrade)
		state.weaponGrade = activeWeapons[primaryWeaponId].grade
	end
end

function WeaponProgression.getWeaponId(state): string?
	if not state then
		return nil
	end
	return state.weaponId
end

function WeaponProgression.getWeaponGrade(state): string?
	if not state then
		return "Normal"
	end
	local g = state.weaponGrade
	if type(g) == "string" and g ~= "" then
		return g
	end
	return "Normal"
end

function WeaponProgression.getWeaponGradeFor(state, weaponId: string): string
	if not state or type(weaponId) ~= "string" then
		return "Normal"
	end
	local activeWeapons = state.activeWeapons
	if type(activeWeapons) == "table" then
		local entry = activeWeapons[weaponId]
		if type(entry) == "table" then
			return normalizeGrade(entry.grade)
		end
	end
	if state.weaponId == weaponId then
		return normalizeGrade(state.weaponGrade)
	end
	return "Normal"
end

--[[
  SwordShield 중복 드롭 픽업: Normal → Rare, 이미 Rare면 알림만.
  notifyFn(kind): WeaponPickupNotify 계약 ("UpgradedToRare" | "AlreadyRareDuplicate")
  verboseFn(message): 선택 — 디버그 로그 한 줄
]]
function WeaponProgression.tryApplyWeaponDropPickup(
	state: any,
	player: Player,
	weaponIdFromDrop: string,
	notifyFn: ((string) -> ())?,
	verboseFn: ((string) -> ())?
): boolean
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return false
	end
	if type(weaponIdFromDrop) ~= "string" then
		warn("[WeaponProgression] tryApplyWeaponDropPickup: invalid weaponIdFromDrop")
		return false
	end
	if type(WeaponProfiles[weaponIdFromDrop]) ~= "table" then
		warn(string.format("[WeaponProgression] tryApplyWeaponDropPickup: unknown weaponId=%s", tostring(weaponIdFromDrop)))
		return false
	end
	if not state then
		warn(string.format("[WeaponProgression] tryApplyWeaponDropPickup: no progress state (%s)", player.Name))
		return false
	end
	local activeWeapons = ensureActiveWeapons(state)
	local entry = activeWeapons[weaponIdFromDrop]
	if type(entry) ~= "table" then
		activeWeapons[weaponIdFromDrop] = {
			weaponId = weaponIdFromDrop,
			grade = "Normal",
		}
		if state.weaponId == nil then
			state.weaponId = weaponIdFromDrop
		end
		if state.weaponId == weaponIdFromDrop then
			state.weaponGrade = "Normal"
		end
		if verboseFn then
			verboseFn(string.format("[Progression] %s | 새 무기 획득: %s", player.Name, weaponIdFromDrop))
		end
		return true
	end

	entry.grade = normalizeGrade(entry.grade)
	if entry.grade == "Rare" then
		if notifyFn then
			notifyFn("AlreadyRareDuplicate")
		end
		if state.weaponId == weaponIdFromDrop then
			state.weaponGrade = "Rare"
		end
		return true
	end

	if entry.grade == "Normal" then
		entry.grade = "Rare"
		if state.weaponId == weaponIdFromDrop then
			state.weaponGrade = "Rare"
		end
		if notifyFn then
			notifyFn("UpgradedToRare")
		end
		if verboseFn then
			verboseFn(string.format("[Progression] %s | %s duplicate 획득 → Rare 승급", player.Name, weaponIdFromDrop))
		end
		return true
	end

	warn(
		string.format(
			"[WeaponProgression] weapon drop pickup: unknown weaponGrade=%s (%s / %s)",
			tostring(entry.grade),
			weaponIdFromDrop,
			player.Name
		)
	)
	return false
end

return WeaponProgression

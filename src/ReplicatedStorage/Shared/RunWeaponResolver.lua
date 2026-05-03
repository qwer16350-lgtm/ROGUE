--- GameConfig 기반 런 기본 무기 ID 결정 (서버/공유 순수 유틸, 다른 모듈 require 없음)

local RunWeaponResolver = {}

function RunWeaponResolver.resolveEffectiveWeaponId(gameConfig): string
	if not gameConfig then
		return "SwordShield"
	end
	local dbg = gameConfig.Debug
	if type(dbg) == "table" then
		local o = dbg.OverrideWeaponId
		if o == "SwordShield" or o == "BasicMagic" then
			return o
		end
		if o ~= nil then
			warn(string.format("[RunWeaponResolver] Invalid Debug.OverrideWeaponId=%s — using SwordShield.", tostring(o)))
			return "SwordShield"
		end
	end
	local run = gameConfig.Run
	if type(run) == "table" then
		local d = run.DefaultWeaponId
		if d == "SwordShield" or d == "BasicMagic" then
			return d
		end
		if d ~= nil then
			warn(string.format("[RunWeaponResolver] Invalid Run.DefaultWeaponId=%s — using SwordShield.", tostring(d)))
		end
	end
	return "SwordShield"
end

return RunWeaponResolver

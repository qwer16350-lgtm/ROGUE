# MULTI WEAPON PHASE 1 FINAL

## 1. Overview
- 기존 단일 `effectiveWeaponId` 중심 구조에서 `activeWeapons` 기반 multi-weapon 구조로 확장됨.
- 플레이어는 런 중 여러 무기를 획득할 수 있고, `activeWeapons`에 등록된 무기만 전투 루프에서 처리됨.
- 등록된 각 무기는 player+weaponId 기준 독립 쿨타임으로 공격함.
- 기존 `effectiveWeaponId` / `weaponId` / `weaponGrade` 계열 필드는 legacy/debug/fallback 목적로 유지됨.

## 2. Current Weapon Roster
### BasicMagic
- 원형 범위(Circle) 공격.
- 기존 기본 마법형 공격 루틴 유지.
- Relic Chest / Dropped Relic 차단(sanitize) 정책 유지.

### SwordShield
- Sweep / Thrust 교대 공격.
- Sweep: Cone 판정.
- Thrust: LineBox/Strip 판정.
- Starting Relic / Dropped Relic 적용 대상.
- `shield_spike`는 SwordShield Sweep에만 knockback 적용.

### Spear
- Thrust only.
- SwordShield Thrust와 유사한 LineBox/Strip 판정.
- 기본 `TargetLimit = 1`.
- 긴 직선형 단일 딜 무기.
- Spear kill은 SwordShield 전용 WeaponDrop / RelicChest trigger를 발생시키지 않음.

### TwoHandedSword
- Sweep only.
- SwordShield Sweep보다 넓은 Cone 판정.
- 높은 피해 / 긴 쿨타임.
- 기본 `TargetLimit = nil`이면 unlimited 처리.
- 검기 방출은 아직 미구현.
- TwoHandedSword kill은 SwordShield 전용 WeaponDrop / RelicChest trigger를 발생시키지 않음.

## 3. activeWeapons Structure
```lua
activeWeapons = {
    SwordShield = {
        weaponId = "SwordShield",
        grade = "Normal",
    },

    Spear = {
        weaponId = "Spear",
        grade = "Normal",
    },

    TwoHandedSword = {
        weaponId = "TwoHandedSword",
        grade = "Normal",
    },
}
```

- key는 `weaponId`.
- value는 최소 `weaponId` / `grade`를 가짐.
- `activeWeapons`에 있는 무기만 `CombatService`에서 순회 공격.
- `activeWeapons`가 비어 있거나 없을 때만 legacy `effectiveWeaponId` fallback 사용.
- unknown `weaponId`는 BasicMagic으로 fallback하지 않고 skip.

## 4. Combat Loop Policy
- player별 `activeWeapons` 순회.
- 무기별 독립 쿨타임(`lastAttackByPlayerWeapon[player][weaponId]`) 사용.
- SwordShield는 weaponId 기준 Sweep/Thrust 교대 상태 유지.
- BasicMagic / SwordShield / Spear / TwoHandedSword는 명시 분기 처리.
- unknown `weaponId`는 skip.
- `applyDamageResolved(player, entry, damage, sourceWeaponId)`로 kill source 전달.

## 5. WeaponDrop / Pickup Flow
- `WeaponDropService`는 generic `spawnWeaponDropAt(position, ownerPlayer, weaponId)` 구조를 가짐.
- 기존 `spawnSwordShieldDropAt`는 wrapper로 유지.
- Drop Part에 `WeaponId` attribute를 저장.
- pickup 시 `ProgressionService.tryApplyWeaponDropPickup(player, weaponId)` 호출.
- `WeaponProgression`은 `WeaponProfiles[weaponId]` 검증으로 invalid weaponId 차단.
- 미보유 무기면 `activeWeapons`에 추가.
- 보유 무기면 duplicate / grade 처리.

현재 드롭 후보(테스트용 초기값):
- SwordShield: 40
- Spear: 30
- TwoHandedSword: 30

## 6. Reward Source Policy
현재 정책:
- WeaponDrop trigger:
  - `sourceWeaponId == "SwordShield"`
- RelicChest trigger:
  - `sourceWeaponId == "SwordShield"`
  - `progressionService.getWeaponId(player) == "SwordShield"`

정책 결과:
- Spear kill은 WeaponDrop / RelicChest를 트리거하지 않음.
- TwoHandedSword kill은 WeaponDrop / RelicChest를 트리거하지 않음.
- BasicMagic kill은 SwordShield 전용 보상을 트리거하지 않음.
- SwordShield kill만 현재 weapon/relic chest reward trigger 역할을 함.

## 7. Relic Policy
- Starting Relic / Dropped Relic은 현재 SwordShield 중심 정책 유지.
- BasicMagic은 relic sanitize / 차단 유지.
- RelicChest는 SwordShield 정책 조건을 만족해야 열림.
- Dropped Relic은 Relic Chest pickup을 통해서만 열림.
- Lv6 자동 Dropped Relic trigger는 제거 상태 유지.
- `shield_spike`는 Dropped Relic이며 SwordShield Sweep에만 knockback 적용.

## 8. DevPanel / HUD
- `DevCombat.ActiveWeapons` 표시.
- `SpearEffective` 표시.
- `TwoHandedSwordEffective` 표시.
- 기존 SwordShield / BasicMagic DevCombat 필드 유지.
- `HUDClient`는 nil-safe 표시 유지.

## 9. Current Non-Implemented Items
- `sp_*` Spear 전용 업그레이드
- `th_*` TwoHandedSword 전용 업그레이드
- `co_*` 공격 타입 공용 업그레이드
- `ab_*`, `mg_*`, `ho_*` 시스템/플레이어 공용 업그레이드
- TwoHandedSword 검기 방출
- Spear elite damage / pierce 확장
- WeaponDrop 운영 밸런스 가중치
- CombatService 무기별 모듈 분리

## 10. Stability Notes
Do not casually modify:
- Choice UI RemoteEvent payload shape
- HudState 기존 필드
- activeWeapons fallback 정책
- unknown weaponId skip 정책
- sourceWeaponId reward 정책
- BasicMagic relic sanitize 정책
- Lv6 Dropped Relic 자동 트리거 제거 상태
- `spawnSwordShieldDropAt` wrapper 호환
- `WeaponId` attribute 기반 pickup 흐름

## 11. Next Phase TODO
1. Stage 실플레이 기준 4무기 회귀 검증
2. WeaponDrop 후보 가중치 임시 튜닝
3. 업그레이드 3계층 설계 문서화
4. Spear `sp_*` 업그레이드 추가
5. TwoHandedSword `th_*` 업그레이드 추가
6. 공격 타입 공용 `co_*` 업그레이드 추가
7. TwoHandedSword 검기 방출 구현
8. 필요 시 CombatService 무기별 모듈 분리

## Related Files
- `src/ReplicatedStorage/Shared/WeaponProfiles.lua`
- `src/ReplicatedStorage/Shared/UpgradeData.lua`
- `src/ReplicatedStorage/Shared/GameConfig.lua`
- `src/ServerScriptService/CombatService.lua`
- `src/ServerScriptService/WeaponDropService.lua`
- `src/ServerScriptService/ProgressionService.lua`
- `src/ServerScriptService/Progression/WeaponProgression.lua`
- `src/ServerScriptService/HudSyncService.lua`
- `src/StarterPlayer/StarterPlayerScripts/HUDClient.lua`

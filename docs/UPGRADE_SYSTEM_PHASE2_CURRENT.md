# UPGRADE SYSTEM PHASE 2 CURRENT

## 1. Overview

현재 Upgrade System Phase 2는 `activeWeapons` 기반 multi-weapon 런타임 위에서 `WeaponSpecific` + `AttackTypeCommon` 계층을 함께 운용한다.  
핵심 변화는 SwordShield 계산(Sweep / Thrust / Cooldown)의 generic applicator 이관 완료와 `co_common_cooldown`의 전 무기 실효 연결이다.

## 2. Current Weapon Roster

### BasicMagic
- `weaponId`: `BasicMagic`
- 런타임 루프: `CombatService.heartbeatBasicMagicWeapon`
- 계산 경로: `UpgradeData.getEffectiveCombatStats` (legacy 중심)
- 현재 연결:
  - legacy: `damage_up`, `attack_interval_down`, `attack_size_up`
  - generic(cooldown-only): `co_common_cooldown`
- 상태: Partial (full generic migration 아님)

### SwordShield
- `weaponId`: `SwordShield`
- 공격 타입: `Sweep`, `Thrust`
- 현재 연결:
  - WeaponSpecific: `ss_common_damage`, `ss_common_cooldown`, `ss_sweep_*`, `ss_thrust_*`
  - AttackTypeCommon: `co_sweep_*`, `co_thrust_*`, `co_common_cooldown`
- 상태: Sweep / Thrust / Cooldown effective 계산이 generic applicator 경로로 이관됨

### Spear
- `weaponId`: `Spear`
- 공격 타입: `Thrust`
- 현재 연결:
  - WeaponSpecific: `sp_thrust_damage`, `sp_thrust_range`, `sp_common_cooldown`
  - AttackTypeCommon: `co_thrust_damage`, `co_thrust_range`, `co_common_cooldown`
- 상태: generic applicator 기반

### TwoHandedSword
- `weaponId`: `TwoHandedSword`
- 공격 타입: `Sweep`
- 현재 연결:
  - WeaponSpecific: `th_sweep_damage`, `th_sweep_range`, `th_sweep_angle`, `th_common_cooldown`
  - AttackTypeCommon: `co_sweep_damage`, `co_sweep_range`, `co_common_cooldown`
- 상태: generic applicator 기반

## 3. Upgrade Layers

### 3.1 WeaponSpecific
현재 구현:
- `ss_common_damage`
- `ss_common_cooldown`
- `ss_sweep_angle`
- `ss_sweep_damage`
- `ss_sweep_range`
- `ss_thrust_damage`
- `ss_thrust_range`
- `sp_thrust_damage`
- `sp_thrust_range`
- `sp_common_cooldown`
- `th_sweep_damage`
- `th_sweep_range`
- `th_sweep_angle`
- `th_common_cooldown`

### 3.2 AttackTypeCommon
현재 구현:
- `co_thrust_damage`
- `co_thrust_range`
- `co_sweep_damage`
- `co_sweep_range`
- `co_common_cooldown`

정리:
- `co_thrust_*`: Spear Thrust + SwordShield Thrust
- `co_sweep_*`: TwoHandedSword Sweep + SwordShield Sweep
- `co_common_cooldown`: `System = CombatAttack` 대상 공통 cooldown

### 3.3 Player/System
현재 준비 상태:
- `ab_xp_increase`

정리:
- definition은 존재
- label/value 정합화 완료
- offer/effect 실연결은 아직 미구현

## 4. Generic Upgrade Applicator

핵심 함수:
- `UpgradeData.applyUpgradeDefinitionsToStats(baseStats, context, upgrades)`

지원 문맥:
- `WeaponId`, `AttackId`, `AttackType`, `WeaponTags`, `AttackTags`, `System`, `LayerAllowList`

지원 `AppliesTo`:
- `WeaponId`, `AttackId`, `AttackType`, `RequiredTags`, `AnyTags`, `System`

지원 Stat alias:
- `Damage/BaseDamage`, `Range/RangeStuds`, `Width/WidthStuds`, `Angle/AngleDeg`, `Cooldown/AttackIntervalSeconds`, `TargetLimit`, `Pierce`

## 5. WeaponProfiles Metadata

`WeaponProfiles.lua` 메타 필드:
- `Tags`
- `Attacks`
- `Attacks[*].AttackId`
- `Attacks[*].AttackType`
- `Attacks[*].Tags`

기존 호환을 위해 legacy 필드(`BaseDamage`, `Sweep`, `Thrust`, `AttackIntervalSeconds`)도 유지된다.

## 6. co_common_cooldown (Implemented)

정의:

```lua
co_common_cooldown = {
    Id = "co_common_cooldown",
    Label = "Common Attack Cooldown -5%",
    Layer = "AttackTypeCommon",
    AppliesTo = {
        System = "CombatAttack",
    },
    Stat = "Cooldown",
    Operation = "Multiplier",
    ValuePerStack = -0.05,
    MaxStack = 5,
}
```

적용 대상:
- `BasicMagic`
- `SwordShield`
- `Spear`
- `TwoHandedSword`

계산 의미:
- `AttackIntervalSeconds × (1 - 0.05 × stack)`

최종값은 공통 floor 정책(`0.25`)으로 clamp된다.

## 7. Effective Combat Calculation Status

### BasicMagic (Partial)
- helper: `getEffectiveCombatStats`
- legacy 유지:
  - `damage_up`
  - `attack_interval_down`
  - `attack_size_up`
- 추가 연결:
  - cooldown 전용 generic applicator 경로로 `co_common_cooldown` 후단 적용
- 소비:
  - `CombatService`가 `stats.attackIntervalSeconds`를 실제 공격 간격으로 사용
  - `HudSyncService`/`HUDClient`의 `BasicMagicEffective.attackIntervalSeconds`에 반영

### SwordShield
- helper: `getSwordShieldEffectiveCombat`
- Sweep:
  - `ss_common_damage`, `ss_sweep_damage`, `ss_sweep_range`, `ss_sweep_angle`, `co_sweep_damage`, `co_sweep_range` generic 경로
- Thrust:
  - `ss_common_damage`, `ss_thrust_damage`, `ss_thrust_range`, `co_thrust_damage`, `co_thrust_range` generic 경로
- Cooldown:
  - `ss_common_cooldown`, `co_common_cooldown` generic 경로
- 별도 유지(비-generic/도메인 로직):
  - `SwordShieldChoices` legacy offer pool
  - StartingRelic / DroppedRelic 처리
  - `shield_spike` knockback 특수 효과
  - Sweep/Thrust 교대 로직(`CombatService`)

### Spear
- helper: `getSpearEffectiveCombat`
- `LayerAllowList = { WeaponSpecific = true, AttackTypeCommon = true }`
- `sp_*`, `co_thrust_*`, `co_common_cooldown` 적용

### TwoHandedSword
- helper: `getTwoHandedSwordEffectiveCombat`
- `LayerAllowList = { WeaponSpecific = true, AttackTypeCommon = true }`
- `th_*`, `co_sweep_*`, `co_common_cooldown` 적용

## 8. Upgrade Offer Rules (Current)

기본:
- `activeWeapons` 기반 조건부 후보 추가
- SwordShield 경로는 기존 `SwordShieldChoices` + 가중 비복원 3택 유지
- BasicMagic 경로는 legacy choices 기반 확장

현재 조건:

- Spear 보유 시:
  - `sp_thrust_damage`
  - `sp_thrust_range`
  - `sp_common_cooldown`
  - `co_thrust_damage`
  - `co_thrust_range`
  - `co_common_cooldown`

- TwoHandedSword 보유 시:
  - `th_sweep_damage`
  - `th_sweep_range`
  - `th_sweep_angle`
  - `th_common_cooldown`
  - `co_sweep_damage`
  - `co_sweep_range`
  - `co_common_cooldown`

- SwordShield 보유 시:
  - `ss_*` (`SwordShieldChoices`)
  - `co_thrust_damage`
  - `co_thrust_range`
  - `co_sweep_damage`
  - `co_sweep_range`
  - `co_common_cooldown`

- BasicMagic:
  - legacy BasicMagic choices
  - `co_common_cooldown` 후보 가능 (현재 실효 연결됨)

## 9. Cooldown Floor Policy

- 상수: `MIN_ATTACK_INTERVAL_SECONDS = 0.25`
- 정책: 모든 effective combat helper에서 최종 `AttackIntervalSeconds`를 clamp

적용 대상:
- BasicMagic (`getEffectiveCombatStats`)
- SwordShield (`getSwordShieldEffectiveCombat`)
- Spear (`getSpearEffectiveCombat`)
- TwoHandedSword (`getTwoHandedSwordEffectiveCombat`)

주의:
- 신규 무기/helper 추가 시 동일 floor 정책 누락 금지

## 10. DevPanel / HUD

현재 DevPanel/HUD에서 확인:
- `SwordShieldEffective`
- `BasicMagicEffective`
- `SpearEffective`
- `TwoHandedSwordEffective`
- 각 무기별 `AttackIntervalSeconds` 및 주요 수치

정리:
- DevPanel은 검증용
- offer 노출 항목은 반드시 실제 effect 경로와 연결되어야 함

## 11. Current Implemented Upgrade List

| Id | Layer | Applies To | Stat | Offer Condition | Status |
|---|---|---|---|---|---|
| `ss_common_damage` | WeaponSpecific | SwordShield common | Damage | SwordShield pool | active (generic) |
| `ss_common_cooldown` | WeaponSpecific | SwordShield common | Cooldown | SwordShield pool | active (generic) |
| `ss_sweep_angle` | WeaponSpecific | SwordShield Sweep | Angle | SwordShield pool | active (generic) |
| `ss_sweep_damage` | WeaponSpecific | SwordShield Sweep | Damage | SwordShield pool | active (generic) |
| `ss_sweep_range` | WeaponSpecific | SwordShield Sweep | Range | SwordShield pool | active (generic) |
| `ss_thrust_damage` | WeaponSpecific | SwordShield Thrust | Damage | SwordShield pool | active (generic) |
| `ss_thrust_range` | WeaponSpecific | SwordShield Thrust | Range | SwordShield pool | active (generic) |
| `sp_thrust_damage` | WeaponSpecific | Spear Thrust | Damage | `activeWeapons.Spear` | active |
| `sp_thrust_range` | WeaponSpecific | Spear Thrust | Range | `activeWeapons.Spear` | active |
| `sp_common_cooldown` | WeaponSpecific | Spear common | Cooldown | `activeWeapons.Spear` | active |
| `th_sweep_damage` | WeaponSpecific | TwoHandedSword Sweep | Damage | `activeWeapons.TwoHandedSword` | active |
| `th_sweep_range` | WeaponSpecific | TwoHandedSword Sweep | Range | `activeWeapons.TwoHandedSword` | active |
| `th_sweep_angle` | WeaponSpecific | TwoHandedSword Sweep | Angle | `activeWeapons.TwoHandedSword` | active |
| `th_common_cooldown` | WeaponSpecific | TwoHandedSword common | Cooldown | `activeWeapons.TwoHandedSword` | active |
| `co_thrust_damage` | AttackTypeCommon | Thrust 계열 | Damage | Spear or SwordShield | active |
| `co_thrust_range` | AttackTypeCommon | Thrust 계열 | Range | Spear or SwordShield | active |
| `co_sweep_damage` | AttackTypeCommon | Sweep 계열 | Damage | TwoHandedSword or SwordShield | active |
| `co_sweep_range` | AttackTypeCommon | Sweep 계열 | Range | TwoHandedSword or SwordShield | active |
| `co_common_cooldown` | AttackTypeCommon | `System=CombatAttack` | Cooldown | any attack weapon | active |
| `ab_xp_increase` | PlayerSystem | `System=XP` | XP | not offered | schema only |

## 12. Current Non-Implemented / Deferred Items

- `sp_thrust_Chance`
- `sp_pierce`
- `sp_elite_damage`
- `th_wave_unlock`
- `th_wave_damage`
- `th_wave_range`
- 검기 방출(Wave 실제 전투 로직)
- `ab_Health_increase`
- `ab_Speed_increase`
- `mg_Range_increase`
- `ho_Amount_increase`
- `ho_Chance_increase`
- BasicMagic full generic migration
- OfferBuilder category weight redesign

`sp_thrust_Chance` 보류 사유:
- 단순 stat modifier가 아니라 attack pattern modifier 성격
- 무기 업그레이드 / 유물 / 고급 런 업그레이드 중 소속 정책 미확정
- 현재 구현 보류

## 13. ID Naming Notes

기획 표기 vs 현재 코드 ID 차이:
- 표: `sp_common_damage` / 코드: `sp_thrust_damage`
- 표: `th_common_damage` / 코드: `th_sweep_damage`
- 표: `ab_XP_increase` / 코드: `ab_xp_increase`

현재 정책:
- 기존 코드 ID 유지
- `state.upgrades` key 안정성 때문에 rename하지 않음
- `Label` / `ValuePerStack`은 표 기준으로 정합화 진행

## 14. Stability Notes

- SwordShield `ss_*`는 definition + 계산 모두 generic 이관이 진행된 상태
- 중복 적용 방지를 위해 legacy 수동 계산을 재도입하지 말 것
- `co_common_cooldown`은 `System = "CombatAttack"` 기반 적용임
- BasicMagic은 `co_common_cooldown`만 generic 후단 적용이며 full generic으로 오해하지 말 것
- 신규 무기/helper 추가 시 `AttackIntervalSeconds` floor `0.25` 누락 주의
- offer에 노출된 upgrade는 반드시 실제 effect 경로와 일치해야 함
- Choice payload shape(`{ Id, Label }`) 변경 금지

## 15. Next Phase TODO

- P1. Phase 2G 문서/감사표 정합화
- P2. BasicMagic full generic migration 여부 검토
- P3. `sp_thrust_Chance` 설계 결정
- P4. Spear pattern upgrade / relic 위치 결정
- P5. `th_wave_unlock` / 검기 방출 설계
- P6. Player/System 업그레이드(`ab_Health`, `ab_Speed`, `mg_*`, `ho_*`) 연결
- P7. OfferBuilder category weight redesign
- P8. Upgrade ID naming policy / migration policy 정리

## 16. Related Files

- `src/ReplicatedStorage/Shared/UpgradeData.lua`
- `src/ReplicatedStorage/Shared/WeaponProfiles.lua`
- `src/ServerScriptService/Progression/UpgradeOfferBuilder.lua`
- `src/ServerScriptService/ProgressionService.lua`
- `src/ServerScriptService/CombatService.lua`
- `src/ServerScriptService/HudSyncService.lua`
- `src/StarterPlayer/StarterPlayerScripts/HUDClient.lua`

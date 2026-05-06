# UPGRADE SYSTEM PHASE 2 PLAN

## 1. Overview

- 현재 업그레이드 구조는 단일 무기 또는 SwordShield 중심 처리에 가깝다.
- multi-weapon 구조에서는 `activeWeapons`에 여러 무기가 동시에 존재한다.
- 같은 `attackType`이라도 `weaponId`가 다르면 별도 공격/밸런스 대상으로 취급해야 한다.
- 따라서 업그레이드는 최소 3계층(무기 전용 / 공격 타입 공용 / 플레이어·시스템 공용)으로 분리되어야 한다.

## 2. Core Principle

Final attack stats must be calculated from:

`weaponId + attackType + upgrade layers`

예시:

- `SwordShield + Thrust`
- `Spear + Thrust`

둘 다 Thrust지만 적용 업그레이드는 다르게 누적된다.

- `ss_thrust_damage` -> SwordShield Thrust만
- `sp_thrust_damage` -> Spear Thrust만
- `co_thrust_damage` -> SwordShield Thrust + Spear Thrust 모두

## 3. Upgrade Layer 1 — Weapon-Specific Upgrades

### SwordShield (`ss_*`)

예시:

- `ss_common_damage`
- `ss_common_cooldown`
- `ss_sweep_damage`
- `ss_sweep_range`
- `ss_sweep_angle`
- `ss_thrust_damage`
- `ss_thrust_range`
- `ss_thrust_width`

적용 대상:

- SwordShield 전체 공통
- SwordShield Sweep
- SwordShield Thrust

### Spear (`sp_*`)

예시:

- `sp_common_damage`
- `sp_common_cooldown`
- `sp_thrust_damage`
- `sp_thrust_range`
- `sp_thrust_width`
- `sp_pierce`
- `sp_elite_damage`

적용 대상:

- Spear 전체 공통
- Spear Thrust

메모:

- `sp_elite_damage`는 elite/boss 태그 체계가 확정되기 전까지 후순위.

### TwoHandedSword (`th_*`)

예시:

- `th_common_damage`
- `th_common_cooldown`
- `th_sweep_damage`
- `th_sweep_range`
- `th_sweep_angle`
- `th_wave_unlock`
- `th_wave_damage`
- `th_wave_range`

적용 대상:

- TwoHandedSword 전체 공통
- TwoHandedSword Sweep
- TwoHandedSword Wave

메모:

- 검기 방출(Wave)은 아직 미구현이므로 `th_wave_*`는 후속 항목으로 유지.

### BasicMagic (`bm_*` 또는 legacy)

후보:

- `bm_common_damage`
- `bm_common_cooldown`
- `bm_range`
- `bm_projectile_count` 또는 `bm_area`

현행 legacy와 관계:

- 기존 `damage_up`, `attack_interval_down`, `attack_size_up` 유지 여부를 마이그레이션 전략에서 분리 결정.

## 4. Upgrade Layer 2 — Attack-Type Common Upgrades

예시:

- `co_sweep_damage`
- `co_sweep_range`
- `co_sweep_angle`
- `co_thrust_damage`
- `co_thrust_range`
- `co_thrust_width`
- `co_common_cooldown`

적용 관계:

- `co_sweep_*`
  - SwordShield Sweep
  - TwoHandedSword Sweep
- `co_thrust_*`
  - SwordShield Thrust
  - Spear Thrust
- `co_common_cooldown`
  - activeWeapons의 모든 공격 루프 공통

주의:

- `co_*`는 무기 전용 업그레이드를 대체하지 않는다.
- `co_*`는 무기 전용 결과에 추가 누적되는 계층이다.
- 중복 적용 순서/배율 정책을 명시적으로 고정해야 한다.

## 5. Upgrade Layer 3 — Player/System Upgrades

예시:

- `ab_XP_increase`
- `ab_Health_increase`
- `ab_Speed_increase`
- `mg_Range_increase`
- `ho_Amount_increase`
- `ho_Chance_increase`

적용 대상:

- `ab_*`: 플레이어 스탯 계층
- `mg_*`: 자석/픽업 시스템
- `ho_*`: 체력 오브 시스템

주의:

- 이 계층은 CombatService의 weapon attack 계산과 분리되어야 한다.

## 6. Calculation Policy

권장 최종 계산 순서:

1. Base weapon profile
2. grade modifier
3. weapon-specific common modifier
4. weapon-specific attack modifier
5. attack-type-common modifier
6. relic modifier
7. final clamp/safety

예시:

Spear Thrust Damage

- `Spear base damage`
- `x grade modifier`
- `x sp_common_damage`
- `x sp_thrust_damage`
- `x co_thrust_damage`
- `x relic modifier(if applicable)`

TwoHandedSword Sweep Range

- `TwoHandedSword base sweep range`
- `x th_sweep_range`
- `x co_sweep_range`

연산 권장:

- damage: multiplier 중심
- cooldown: multiplier 중심
- width/range/angle: multiplier 또는 additive 중 하나로 통일 필요
- targetLimit/pierce: integer additive 권장

## 7. UpgradeData 변경 방향

현재 한계:

- `Choices` / `SwordShieldChoices` 중심 구조는 다무기/다계층 확장에 제한적.

제안:

- `UpgradeDefinitions` 단일 테이블 또는 카테고리별 테이블로 통합.
- 각 업그레이드에 메타 필드 포함:

```lua
{
    Id = "sp_thrust_damage",
    Label = "Spear Thrust Damage",
    Layer = "WeaponSpecific",
    WeaponId = "Spear",
    AttackType = "Thrust",
    Stat = "Damage",
    Operation = "Multiplier",
    ValuePerStack = 0.15,
    MaxStack = 5,
}
```

## 8. UpgradeOfferBuilder 변경 방향

`UpgradeOfferBuilder`는 `activeWeapons` 기반 후보 생성이 필요하다.

- weapon-specific 후보:
  - 현재 보유 무기(`activeWeapons`) 기준 생성
- attack-type-common 후보:
  - 현재 보유 무기가 가진 attackType 기준 생성
- player/system 후보:
  - 항상 후보 가능
- offer 슬롯 category weight 도입:
  - WeaponSpecific: 50%
  - AttackTypeCommon: 30%
  - PlayerSystem: 20%

위 비율은 테스트용 초기값으로 취급.

## 9. DevPanel / HUD 변경 방향

업그레이드 디버깅을 위해 다음 표시를 권장:

- ActiveWeapons별 upgrade stack
- attack-type-common stack
- player/system stack
- 무기별 final effective stats

## 10. Migration Strategy

대상:

- `damage_up`
- `attack_interval_down`
- `attack_size_up`
- `ss_*`

옵션 A (추천): legacy 유지 후 단계적 이관

- 기존 BasicMagic 계열은 당분간 legacy 유지
- 신규 계층(`bm_*`, `co_*`, `ab_*/mg_*/ho_*`)를 점진 도입
- 회귀 리스크 최소화에 유리

옵션 B: BasicMagic 즉시 `bm_*` 마이그레이션

- 단기 정합성은 높지만 초기 회귀 리스크 증가

추천안:

- **A안(legacy 유지 후 단계적 마이그레이션)**.

## 11. Implementation Phases

- Phase 2A — 설계 문서 고정
- Phase 2B — UpgradeData schema 확장
- Phase 2C — Spear `sp_*` 최소 업그레이드 추가
- Phase 2D — TwoHandedSword `th_*` 최소 업그레이드 추가
- Phase 2E — `co_*` attack-type-common 추가
- Phase 2F — player/system upgrades 추가
- Phase 2G — UpgradeOfferBuilder category weight 적용
- Phase 2H — DevPanel 확장

## 12. Stability Notes

Do not casually modify:

- `activeWeapons` structure
- `weaponId + attackType` 계산 원칙
- `sourceWeaponId` reward policy
- Choice UI RemoteEvent payload shape
- HudState 기존 필드
- BasicMagic relic sanitize 정책
- Relic Chest trigger policy
- existing `ss_*` behavior

## 13. Open Questions

- `co_common_cooldown`을 모든 무기에 동일 적용할지?
- Spear pierce를 기본 업그레이드로 둘지, relic로 둘지?
- TwoHandedSword wave를 업그레이드 unlock으로 둘지, 기본 기능으로 둘지?
- BasicMagic legacy 업그레이드를 언제 `bm_*`로 이관할지?
- elite/boss 태그 시스템은 언제 도입할지?

## Related Files

- `src/ReplicatedStorage/Shared/UpgradeData.lua`
- `src/ReplicatedStorage/Shared/WeaponProfiles.lua`
- `src/ServerScriptService/Progression/UpgradeOfferBuilder.lua`
- `src/ServerScriptService/ProgressionService.lua`
- `src/ServerScriptService/CombatService.lua`
- `src/ServerScriptService/HudSyncService.lua`
- `src/StarterPlayer/StarterPlayerScripts/HUDClient.lua`

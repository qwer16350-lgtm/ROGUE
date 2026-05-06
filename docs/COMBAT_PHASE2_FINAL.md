# Combat Phase 2 — Final Structure (Baseline)

이 문서는 **현재 코드베이스 기준 Combat Phase 2의 “동작하는 최종 구조”를 안정적으로 고정**하기 위한 기준점 문서입니다.  
목표는 **기능 변경이 아니라**, 다음 리팩터링/확장 작업을 위한 **공통 참조(SSOT) 문서**를 만드는 것입니다.

> 범위: SwordShield/BasicMagic 전투 루프, 업그레이드/유물(Starting/Dropped), 월드 드롭(Weapon Drop/Relic Chest), 등급, DevCombatPanel(HUD), 분기 정책.

---

## A. 현재 구조 요약

### 1) 무기 종류
- **무기 종류**: `SwordShield`, `BasicMagic`
- 런 진행 중 “무기 효과/풀/유물 정책”은 이 두 무기 타입을 기준으로 분기합니다.

### 2) 런 기준 effective weapon 결정 방식
- 서버 전투 루프는 **런의 `effectiveWeaponId`** 를 기준으로 “SwordShield 루프 vs BasicMagic 루프”를 선택합니다.
- `effectiveWeaponId`는 서버에서 `RunWeaponResolver.resolveEffectiveWeaponId(gameConfig)`로 결정됩니다.
- 디버그 오버라이드(예: `GameConfig.Debug.OverrideWeaponId`)가 유효한 경우 이를 우선 적용합니다.

### 3) 서버 전투 루프 구조 (Server authoritative)
- 서버 `CombatService`가 `RunService.Heartbeat` 기반으로 루프를 돌며:
  - 플레이어별 공격 쿨다운 관리
  - 대상 탐색/판정
  - 피해 적용 및 사망 처리
  - XP/Health orb 스폰
  - Weapon Drop / Relic Chest roll 및 스폰
  - VFX/피해 숫자/보스 체력바 등 RemoteEvent 브로드캐스트
- **서버 판정 / 클라이언트 표현 분리 원칙**을 유지합니다.

### 4) BasicMagic 공격 방식
- **공격 주기/사거리/피해**는 서버에서 업그레이드 스택 기반으로 계산됩니다.
- **판정**: 플레이어 HRP 기준 원형(거리) 범위 내 적을 후보로 잡아 공격.
- **공격 범위 디버그**: 설정(`GameConfig.Debug.ShowAttackRanges`)이 켜져 있으면 `AttackRangeDebugEvent`로 범위가 표시됩니다.

### 5) SwordShield 공격 방식

#### a) Sweep
- **판정**: 전방 원뿔(Cone) 판정 (거리 + 각도)

#### b) Thrust
- **판정**: XZ 평면 기준 고정 폭 스트립(LineBox/Strip) 판정 (길이 + 폭)

#### c) 교대 실행 구조
- SwordShield는 **Sweep / Thrust를 교대로** 실행합니다.
- “다음 공격이 Thrust인지 여부”를 플레이어별 상태로 보관하며 틱마다 토글됩니다.

### 6) 런 업그레이드 구조
- `ProgressionService`가 레벨업 시 선택 UI를 제공하고, 제출된 선택을 서버가 적용합니다.
- 업그레이드 선택지는 `UpgradeOfferBuilder`가 구성합니다(무기/StartingRelic 상태에 따라 오퍼가 달라질 수 있음).
- **ChoiceKind 계약**을 기반으로 클라 UI가 표시됩니다(아래 Stability notes 참고).
- 동시 UI 충돌을 방지하기 위해 pending/queue 정책이 존재합니다.

### 7) Starting Relic 구조
- 런 시작 시(스테이지 브랜치) 서버가 `ProgressionService.tryOfferStartingRelic(player)`로 3택 UI를 제공합니다.
- 선택 결과는 `startingRelicId`로 서버 진행 상태에 저장되며, 이후 전투 실효 수치 계산에 반영됩니다.

### 8) Dropped Relic 구조 (Relic Chest 기반)
- **중요: Lv6 자동 트리거는 제거된 상태입니다.**
- Dropped Relic UI는 **필드 Relic Chest 획득을 통해서만** 열립니다.
- 흐름:
  1. SwordShield 런에서 적 처치
  2. 확률 roll 성공 시 월드에 `RelicChest` 스폰
  3. 플레이어가 chest를 획득(Heartbeat 거리 체크)
  4. 서버 `ProgressionService.tryGrantDroppedRelicOfferFromChest(player)` 호출
  5. pending 충돌이 없으면 즉시 `ChoiceKind = "DroppedRelic"` UI 제공, 충돌 시 pending 예약 후 flush 시점에 제공
  6. 선택 결과는 `droppedRelicId`로 저장되고 전투 실효 수치에 반영됩니다

### 9) Weapon Drop 구조
- SwordShield 런에서 적 처치 시 확률 roll 성공 시 월드에 Weapon Drop을 스폰합니다.
- 드롭 파트는 `BoundUserId`로 소유자가 제한되며, 서버 Heartbeat 거리 체크로 획득 판정합니다.
- 획득 시 `ProgressionService.tryApplyWeaponDropPickup(player, weaponId)`가 호출됩니다.

### 10) Grade 구조
- 무기 등급은 최소 `Normal` / `Rare` 형태로 유지됩니다.
- Weapon Drop duplicate pickup은 등급 승급(예: Normal→Rare) 흐름과 연결됩니다.
- 등급은 SwordShield 실효 수치 계산 입력으로 포함될 수 있습니다(`weaponGrade`).

### 11) DevCombatPanel 구조
- 목적: 개발/밸런스 확인용 HUD (플레이어 최종 UI 아님)
- 서버 `HudSyncService`가 `HudState` payload에 조건부로 `DevCombat` 블록을 포함합니다.
  - 토글: `GameConfig.Debug.ShowDevCombatPanel == true`
- 클라 `HUDClient`가 `PlayerGui` 아래 코드 생성형 ScreenGui/Frame/TextLabel로 출력합니다.
- `DevCombat`은 무기/등급/유물/스택/실효 수치/디버그 설정 등을 포함합니다.

### 12) BasicMagic / SwordShield 분기 정책
- 전투 루프(공격 방식): `effectiveWeaponId`에 따라 서버에서 분기.
- Relic:
  - SwordShield: Starting/Dropped Relic 활성
  - BasicMagic: relic state sanitize 정책으로 SwordShield 전용 relic/pending을 제거하고, DroppedRelic는 사실상 비활성
- 월드 드롭:
  - Weapon Drop / Relic Chest는 SwordShield 런에서만 roll되도록 가드됩니다.

---

## B. 관련 파일 목록 (실제 경로 기준)

### Server
- `src/ServerScriptService/CombatService.lua`
- `src/ServerScriptService/ProgressionService.lua`
- `src/ServerScriptService/WeaponDropService.lua`
- `src/ServerScriptService/RelicDropService.lua`
- `src/ServerScriptService/HudSyncService.lua`

### Shared (ReplicatedStorage)
- `src/ReplicatedStorage/Shared/GameConfig.lua`
- `src/ReplicatedStorage/Shared/UpgradeData.lua`
- `src/ReplicatedStorage/Shared/WeaponProfiles.lua`
- `src/ReplicatedStorage/Shared/RelicData.lua`

### Client
- `src/StarterPlayer/StarterPlayerScripts/HUDClient.lua`

---

## C. Stability notes (Do not casually modify)

### 1) Choice UI RemoteEvent 계약
- `ProgressionService`는 선택 UI를 `RemoteEvent`로 제공하며, 클라 UI는 **`ChoiceKind` 값**에 의존합니다.
- 대표 `ChoiceKind`:
  - `Upgrade`
  - `StartingRelic`
  - `DroppedRelic`
- 이 계약(필드명/shape/타이밍)을 임의로 바꾸면 UI/진행 큐가 깨질 수 있으므로 **신중하게 변경**해야 합니다.

### 2) `HudState` payload shape
- `HudSyncService`가 `HudState` RemoteEvent로 HUD 업데이트 payload를 주기적으로 전송합니다.
- `payload.DevCombat`는 `ShowDevCombatPanel`이 켜졌을 때만 포함되는 **조건부 블록**입니다.
- DevPanel은 payload 누락을 전제로 nil-safe해야 하며, 서버/클라 간 shape 변경은 회귀를 유발할 수 있습니다.

### 3) BasicMagic relic sanitize 정책
- BasicMagic 런에서는 SwordShield 전용 Starting/Dropped relic이 스테일로 남지 않도록 서버에서 sanitize합니다.
- 이 정책이 약해지면 “무기 분기 교차/디버그 오버라이드” 상황에서 상태 오염이 발생할 수 있습니다.

### 4) Relic Chest 소유자 제한 처리
- Relic Chest는 `BoundUserId`로 소유자를 제한합니다.
- 획득 판정은 Touch가 아니라 **서버 Heartbeat 거리 체크**로 처리합니다.
- 소유자 제한을 느슨하게 하면 멀티플레이에서 의도치 않은 경쟁/훔치기 문제가 생깁니다.

### 5) WeaponDrop duplicate / grade 처리 흐름
- Weapon Drop 획득은 `ProgressionService.tryApplyWeaponDropPickup` → `WeaponProgression` 경로로 이어집니다.
- duplicate pickup이 등급 승급과 연결되어 있으므로, 이 경로는 “단일 진실”로 유지하는 것이 중요합니다.

### 6) 서버 판정 / 클라이언트 표현 분리 원칙
- 공격 판정/드롭/유물 선택 결과 확정은 서버가 수행합니다.
- 클라는 HUD/DevPanel 표시 및 VFX 표현에 집중합니다.

### 7) Lv6 자동 Dropped Relic 트리거 제거 상태
- 현재 Dropped Relic UI는 **Lv6 도달로는 절대 열리면 안 됩니다.**
- Dropped Relic UI는 **Relic Chest 획득으로만** 열려야 합니다.

---

## D. 다음 Phase TODO (구현 금지 — 문서만)

우선순위 순:
1. `WeaponProgression.lua` 스타일 모듈 분리(Progression 내부 도메인 로직을 더 명확히 분리)
2. `weaponId` / `weaponGrade` / duplicate pickup / Normal→Rare 승급 흐름 정리(단일 책임 경계 확정)
3. 무기 드롭 획득 결과 payload 정리(서버→클라 통지 데이터의 표준화)
4. HUD 또는 DevPanel에 마지막 weapon pickup 결과 표시(개발용 관측성 강화)
5. Weapon Drop / Relic Chest 동시 드롭 정책 결정(상호배타 vs 독립 roll)
6. 필요 시 CombatService의 무기별 공격 로직 분리(서비스/모듈로 분리하여 엔트리 슬림화)


# Phase 2 MVP Closure & Phase 3 Entry Notes

이 문서는 **Phase 2 MVP**가 실플레이 기준으로 마감된 상태를 기록하고, **임시·테스트 구조를 정식 설계로 오해하지 않도록** 명시한다.  
작성 시점 기준: 레포 `src/` 및 확인된 런타임 동작에 따른 클로저 문서이며, 본 문서만으로 게임 규칙이 변경되지 않는다.

> **Historical snapshot (Phase 2 MVP closure, pre–Phase 3 meta).**  
> **현재 SSOT:** `docs/PHASE3_MVP_CURRENT_ARCHITECTURE.md` §1.1 · `docs/PHASE3_RELIC_META_PROGRESSION.md` §0.

---

## 1. Phase 2 MVP Closure Summary (historical)

아래 항목은 **Phase 2 MVP 범위에서 완료 처리**한다.

- Lobby → Stage 진입 기본 흐름
- Lobby StartingRelicStation E 상호작용
- StartingRelicPanel 열림
- StartingRelic 버튼 선택
- StartingRelicSelectRequest 전송
- Lobby 서버 `selectedStartingRelicByPlayer` 저장·검증
- Entry 시 Teleport `opts.startingRelicId` 전달
- TeleportData `startingRelicId` payload 포함
- `RunContext.getStartingRelicId`
- `ProgressionService` `state.startingRelicId` 반영
- Stage StartingRelic fallback 선택창 제거
- 테스트용 StartingWeapon 3택1 선택창
- StartingWeapon 선택 시 `activeWeapons` 즉시 교체
- SwordShield / Spear / TwoHandedSword 테스트 접근성 확보
- LobbyClient station 후속 바인딩 안정화
  - `CollectionService:GetTagged` 초기 바인딩
  - `CollectionService:GetInstanceAddedSignal("LobbyStation")` 후속 바인딩
- StartingRelicSelectRequest `WaitForChild` 타이밍 안정화
- ResultClient NextFloor / ReturnToLobby 코드 경로
- StartingRelicStation source 반영
- LobbyGui / StartingRelicPanel source 반영

---

## 2. Confirmed Runtime Behavior (historical - superseded by Phase 3) (historical — superseded by Phase 3)

아래는 **사용자 실플레이로 정상 작동을 확인한 항목**으로 기록한다.

- StartingRelic을 Lobby Station에서 선택 가능
- 선택한 StartingRelic이 Stage로 전달됨
- Stage에서 기존 StartingRelic fallback 선택창이 뜨지 않음
- 테스트용 StartingWeapon 3택1 선택창 정상 작동
- 선택한 무기로 전투 테스트 가능
- 기존 Lobby → Stage 진입 흐름 정상
- 현재까지의 관련 문제는 해결됨

---

## 3. Temporary / Test-only Structures

아래는 **정식 게임 구조가 아니라** Phase 2 테스트·임시 구조로 명시한다. 이후 작업에서 정식 스펙으로 취급하지 않는다.

### StartingWeapon Picker

- 현재 StartingWeapon 3택1은 **정식 런 시작 구조가 아니라 테스트 편의용**이다.
- 목적은 SwordShield / Spear / TwoHandedSword를 빠르게 확인하기 위한 것이다.
- Wave 시작을 지연하지 않는다.
- 선택하지 않아도 Stage·wave는 기존 흐름대로 진행될 수 있다.
- Phase 3 또는 후속 단계에서 **정식 starting weapon flow**로 재설계될 수 있다.

### StartingRelic Owned State

- 현재 StartingRelic 3종은 모두 **temporary owned**로 취급한다.
- 실제 unlock·owned relic filtering은 아직 없다.
- 향후 `PlayerData.unlockedStartingRelics` 같은 구조로 교체될 수 있다.

### Result Reward

- 현재 ResultClient / NextFloor / ReturnToLobby 흐름은 **최소 결과·이동 구조**다.
- 실제 reward 지급, 재화 저장, DataStore 반영은 **아직 구현 범위가 아니다**.
- Phase 3 또는 후속 reward system에서 별도로 다룬다.

---

## 4. Current StartingRelic IDs

`RelicData` Starting 정의와 일치하는 3종이다.

- `old_shield_emblem`
- `cracked_sword_tip`
- `knights_belt`

---

## 5. Current StartingWeapon IDs

테스트용 StartingWeapon 후보 3종이다.

- `SwordShield`
- `Spear`
- `TwoHandedSword`

`BasicMagic`은 현재 테스트용 3택1 선택지에 **포함하지 않는다**.  
단, legacy·fallback 무기 구조로 코드에 남아 있을 수 있다.

---

## 6. Known Technical Debt Before Phase 3

아래 항목은 **Phase 3 진입 전 또는 Phase 3 초기**에 정리 대상으로 명시한다.

### ProgressionService choice/pending complexity

현재 ProgressionService에는 여러 choice-kind와 pending 상태가 누적되어 있다.

**현재 choice kind (런타임):**

- Upgrade
- StartingWeapon (테스트용)
- Phase3Relic (`Phase3RelicChest` 픽업 후)

**legacy / removed:**

- **DroppedRelic** — Progression offer·submit·`pendingDroppedRelicByPlayer` **제거됨** (Step A). Phase 2 보라 RelicChest kill drop **제거됨**.
- StartingRelic Stage `ChoiceKind` 오퍼 없음 (Lobby only)

**pending 상태 (현재):**

- `pendingLevelUpOfferByPlayer`
- `pendingStartingWeaponByPlayer`
- `pendingPhase3RelicByPlayer`

Phase 3에서 ClassChoice, RelicRewardChoice, BlueprintChoice 등이 추가될 수 있으므로 **choice/pending 구조 정리**가 필요하다.

### StartingRelic Stage fallback legacy

StartingRelic은 **Lobby Station에서 선택하는 구조**로 이동했다.  
따라서 Stage fallback StartingRelic choice 관련 코드는 **legacy**로 간주한다.

**정리 후보:**

- `tryOfferStartingRelic`
- `pendingStartingRelicByPlayer`
- `ChoiceKind == "StartingRelic"` submit branch
- 관련 flush blocking 조건

단, **삭제 전 호출부 grep 확인**이 필요하다.

### DroppedRelic / Phase 2 RelicChest (historical — removed from runtime)

> **Step A:** Phase 2 **보라 RelicChest kill drop**, `spawnRelicChestAt`, `tryGrantDroppedRelicOfferFromChest`, `tryFlushDroppedRelicOffer`, `pendingDroppedRelicByPlayer`, `ChoiceKind = "DroppedRelic"` 발송·submit 분기는 **ProgressionService에서 제거**됨.  
> **현재 relic 획득(런타임):** `Phase3RelicChest` → `ChoiceKind = "Phase3Relic"` → `phase3ActiveRelicIds` (TH/Spear 킬 드랍 등).  
> **Step B/C 완료:** `droppedRelicId` state/read·`shield_spike` 분기 제거. RelicData `DROPPED_*`·dropped API **Step C에서 제거** — 모듈은 StartingRelic-only.

#### Historical reference (pre-removal)

| 영역 | 파일 | 과거 내용 |
|------|------|-----------|
| RelicChest 스폰 | `CombatService.lua` | SS 킬 시 보라 RelicChest — **removed** |
| RelicChest 상호작용 | `RelicDropService.lua` | `tryGrantDroppedRelicOfferFromChest` — **removed** |
| 드랍 유물 오퍼 | `ProgressionService.lua` | DroppedRelic pending/flush — **removed** |
| 유물 정의·배율 | `RelicData.lua` | `DROPPED_DEFINITIONS` — **removed** (Step C); Starting 3종만 |
| SS 전투 read | `CombatService.lua` | `startingRelicId` via UpgradeData only — dropped read **removed** (Step B) |

#### SS dependency (historical note)

- 과거 DroppedRelic offer는 `weaponId == "SwordShield"`에 묶여 있었음. **현재 SS**는 Lobby `startingRelicId` → `RelicData.getCombatMultipliers`만 사용.
- Spear/TH relic은 **Phase3Relic** + `RelicDefinitions`만 확장. DroppedRelic 패턴 복제 **금지**.

### Debug print noise

ProgressionService 등에 남아 있는 임시 debug print는 Phase 3 전에 **제거하거나 debug flag 뒤로 숨긴다**.

---

## 7. Phase 3 Entry Rules

Phase 3에 들어갈 때 지켜야 할 원칙이다.

- 대형 리팩터링보다 **구조 안정성** 우선
- CombatService 전체 generic weapon loop 전환은 **보류**
- VFXClient 대형 리팩터링 **보류**
- MapService 대형 리팩터링 **보류**
- Relic system 전면 재설계는 **별도 PLAN 이후** 진행
- ChoiceFlow·pending 공통화는 **PLAN 먼저 작성 후** 진행
- 태그 기반 유물·클래스 구조가 들어올 수 있는 자리를 **막지 않는다**
- 임시 StartingWeapon picker를 **정식 구조로 오해하지 않는다**
- StartingRelic은 **Lobby equipment·station flow**로 유지한다

---

## 8. Recommended Next Cleanup Tasks

Phase 3 진입 전 추천 작업 순서.

1. ProgressionService debug print 제거 또는 debug flag화
2. StartingRelic Stage fallback legacy 제거 PLAN 작성
3. StartingRelic legacy 제거 패치
4. StartingWeapon 테스트용 구조 주석·플래그화
5. ~~DroppedRelic offer/data~~ → **removed** (Step A–C); historical §「DroppedRelic / Phase 2 RelicChest」참고
6. ChoiceFlow·pending 공통화 PLAN 작성
7. Phase 3 tag·relic·class 구조 설계 진입

---

## 9. Explicit Non-goals

아래는 **Phase 2 마감 문서 기준 non-goal**이다.

- DataStore reward 지급
- Relic unlock·equip 영구 저장
- Party별 StartingRelic·StartingWeapon 구조
- Weapon unlock system
- Class system
- Tag-based relic generation
- Full generic CombatService refactor
- Full VFXClient refactor
- Full MapService refactor

---

## 산출 요약 (메타)

| 항목 | 내용 |
|------|------|
| 문서 경로 | `docs/PHASE2_MVP_CLOSURE_AND_PHASE3_ENTRY.md` |
| 코드 수정 | 게임 `src/` 로직 변경 없음 (본 문서 **보강·편집**) |

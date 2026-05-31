# Choice Flow: Current Structure & Phase 3 Planning Notes

이 문서는 **`ProgressionService`의 ChoiceKind·pending 구조**를 정본으로 기록하고, Phase 3에서 선택 종류가 늘어날 때의 리팩터링 방향만 제안한다.  
**본 문서만으로 게임 동작이나 코드가 변경되지 않는다.**

---

## 1. Current ChoiceKind List

서버가 `LevelUpChoiceRequest`로 클라이언트에 보내는 payload에 설정되는 `ChoiceKind` 값.

| ChoiceKind | 용도 |
|------------|------|
| **Upgrade** | 레벨업 시 표시되는 업그레이드 3선택 (큐 flush 또는 즉시 오퍼) |
| **StartingWeapon** | 스테이지 진입 등에서 호출되는 **테스트용** 무기 3택1 |
| **Phase3Relic** | **Phase 3** `Phase3RelicChest` 픽업 후 `RelicDefinitions` 기반 선택 → `phase3ActiveRelicIds` |

### Legacy (runtime inactive)

| ChoiceKind | 상태 |
|------------|------|
| **DroppedRelic** | **legacy removed** — Phase 2 보라 `RelicChest` kill drop·`tryGrantDroppedRelicOfferFromChest`·`pendingDroppedRelicByPlayer` 제거됨. 런타임에서 선택 UI **발송 없음**. |

### Starting loadout (현행 — not a ChoiceKind)

Lobby `StartingRelicPanel` → `EquipStartingRelicsRequest` → profile `equippedStartingRelics` → Teleport `equippedStartingRelicIds` → `RunContext` → `ProgressionService.trySeedEquippedStartingRelicsFromRunContext` → `phase3ActiveRelicIds`.

**Stage에 `ChoiceKind == "StartingRelic"` 오퍼 없음.** (`startingRelicId` / `RelicData` — **removed 7C-3**, historical only.)

### 현재 relic 획득 경로 (런타임)

| 경로 | 흐름 |
|------|------|
| **Phase3Relic** | 적 처치(TH/Spear 킬, pool·확률) 또는 수동 스폰 → `Phase3RelicChest` 픽업 → `ChoiceKind = "Phase3Relic"` → `phase3ActiveRelicIds` (owned − equipped − active 후보) |
| **Starting (equipped)** | Lobby equip → cross-place seed → `phase3ActiveRelicIds` (no separate ChoiceKind) |

DroppedRelic data/API — **removed** (Phase 2). See legacy table above.

---

## 2. Current Submit Contract

### 서버 → 클라이언트 (`LevelUpChoiceRequest`)

- 서버는 **`LevelUpChoiceRequest` RemoteEvent**로 테이블 payload를 보낸다.
- payload 필드: `ChoiceKind`, `Title`, `Level`(Upgrade), `Choices` 등. Phase3Relic은 `Description` 가능(클라는 Label 위주).

### 클라이언트 (`LevelUpClient`)

- **`ChoiceKind`는 로그·제목 보조 용도.**
- submit 시 **`choiceId`만** `FireServer`. Kind 미전송.

### 서버 수신 (`LevelUpChoiceSubmit`)

- **`pending*` 테이블**이 단일 진실 소스.

---

## 3. Current Pending Tables

형태: `{ [Player]: { [choiceId: string]: boolean } }`

### `pendingLevelUpOfferByPlayer`

| 항목 | 설명 |
|------|------|
| **생성** | `flushUpgradeOfferQueue` / `addExperience` 즉시 오퍼 |
| **소비** | Upgrade submit 후 `nil`; PlayerRemoving `nil` |
| **상호 배제** | 다른 pending·`phase3RelicOfferPending` 시 defer |

### `pendingStartingWeaponByPlayer`

| 항목 | 설명 |
|------|------|
| **생성** | `tryOfferStartingWeapon` |
| **소비** | StartingWeapon submit 후 `nil` |

### `pendingPhase3RelicByPlayer`

| 항목 | 설명 |
|------|------|
| **생성** | `tryFlushPhase3RelicOffer` |
| **defer** | `phase3RelicOfferPending` + `phase3RelicOfferChoices` |
| **소비** | Phase3Relic submit → `addPhase3Relic` |
| **grant** | `tryGrantPhase3RelicOfferFromChest` |

### `pendingDroppedRelicByPlayer` (legacy removed)

**런타임 inactive.** 코드·문서에서 제거됨.

---

## 4. Current Submit Priority

`LevelUpChoiceSubmit` 처리 순서:

1. **StartingWeapon** (`pendingStartingWeaponByPlayer`)
2. **Phase3Relic** (`pendingPhase3RelicByPlayer`)
3. **Upgrade** (`pendingLevelUpOfferByPlayer`)

각 submit 분기 종료 시: `flushUpgradeOfferQueue` → `tryFlushPhase3RelicOffer` (DroppedRelic flush **없음**).

---

## 5. Phase3RelicChest

- **적 처치 드랍:** `CombatService` — TH/Spear 킬, `Phase3RelicPool`·`Phase3RelicChestDropChance` (Publish: `ForcePhase3RelicChestOnKill` **false**).
- **수동 테스트:** `RelicDropService.spawnPhase3RelicChestAt(position, player)` — Command Bar 예:

```lua
local RDS = require(game.ServerScriptService.RelicDropService)
local pl = game.Players:GetPlayers()[1]
local hrp = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
if hrp then RDS.spawnPhase3RelicChestAt(hrp.Position, pl) end
```

- Phase 2 보라 `RelicChest` / `spawnRelicChestAt`: **removed**.

---

## 6. Current Problems & Limits

- 새 ChoiceKind마다 pending·submit·flush 가드 선형 증가.
- defer: Phase3 `phase3RelicOfferPending` boolean (full queue 아님).
- 클라 submit에 Kind 미포함.

---

## 7. Phase 3 Refactor Options (비교만)

(기존 Option A/B/C — `ChoiceFlow.lua` 분리 등 — 변경 없음.)

---

## 8. Explicit Rules

1. **지금 당장 `ChoiceFlow.lua`를 만들지 않는다.**
2. **DroppedRelic offer 경로를 Phase3Relic으로 대체하지 않는다** (별도 chest·정의 유지).
3. **새 ChoiceKind 추가 시** submit 순서·pending·flush를 본 문서에 갱신.
4. **클라 submit에 `ChoiceKind` 추가**는 별도 PLAN·승인 후.
5. **RelicData / startingRelicId Starting 경로 복구 금지.**

---

## 산출 메타

| 항목 | 내용 |
|------|------|
| 정본 코드 | `ProgressionService.lua`, `Phase3RelicPool.lua`, `RelicDropService.lua` |
| DroppedRelic cleanup | Step A offer/submit; Step B `droppedRelicId` read; Step C RelicData dropped data/API **removed** |
| Meta SSOT | `docs/PHASE3_RELIC_META_PROGRESSION.md` §0 |

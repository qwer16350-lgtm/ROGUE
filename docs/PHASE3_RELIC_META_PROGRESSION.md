# Phase 3 Relic Meta Progression — Design (Owned / Craft / Run Chest)

**목적:** 런 중 **Phase3RelicChest**와 **영구 성장**(blueprint / material / craft)의 역할을 분리하고, 계정 귀속 relic(Owned) · Starting 슬롯 · Run chest pool 공식을 SSOT로 고정한다.

| 항목 | 값 |
|------|-----|
| 문서 경로 | `docs/PHASE3_RELIC_META_PROGRESSION.md` |
| 런타임 정본 (현재 MVP) | `docs/PHASE3_MVP_CURRENT_ARCHITECTURE.md` |
| Choice / pending | `docs/CHOICE_FLOW_CURRENT_AND_PHASE3_PLAN.md` |
| **이 문서만으로 게임 동작이 바뀌지 않는다** | 설계·용어·단계만 |

**상태:** 설계 확정 (문서). DataStore · UI · Result 지급 · chest Owned 필터 **미구현** (구현 단계는 §9).

---

## 1. 최종 Relic 구조

### 1.1 Run reward (영구 성장 입력)

런을 돌면서 **relic 완성품이 아닌** 재료·진행도를 획득한다.

| 종류 | 설명 |
|------|------|
| **blueprint fragment** | `blueprintProgress[blueprintId]` 증가 (제작 전 단계) |
| **material** | 일반 런 보상 재료 |
| **shard** | craft 소비 재료 (예: `materials.shard`) |
| **boss material** | 보스·층 클리어 등 희귀 재료 |

**하지 않는 것:** Phase3RelicChest 선택으로 **새 relic 영구 획득**.

### 1.2 Lobby (계정 귀속 · 장착)

| 단계 | 동작 |
|------|------|
| **Craft** | `blueprintProgress` + `materials`가 `RelicDefinitions.craftCost` 등을 충족하면 제작 |
| **Owned** | 제작 완료 시 `ownedRelics[relicId] = true` (계정 귀속, Account-bound) |
| **Equip** | `ownedRelics` 중 **일부만** `equippedStartingRelics` 슬롯에 장착 (개수 제한) |

**Locked:** blueprint/재료 부족으로 미제작 relic → `ownedRelics`에 없음.

### 1.3 Stage (런타임)

| 경로 | 동작 |
|------|------|
| **시작** | `equippedStartingRelics`에 들어간 relic은 **런 시작 시 즉시 활성** (modifier / BuildTag) |
| **Phase3RelicChest** | **`ownedRelics` 중 Starting 슬롯에 넣지 않은 relic만** 3택 오퍼 후보 |
| **런 활성 목록** | Starting + Chest에서 고른 id → `phase3ActiveRelicIds` (이번 런만) |
| **미소유** | Starting 선택 불가, Phase3RelicChest **미등장** |

```text
[메타]     Run → blueprint / material / shard (+ boss)
[Lobby]    Craft → ownedRelics · equip → equippedStartingRelics
[Stage]    Start(active from equipped) + Chest(active more from Owned \ equipped)
[Result]   blueprint/material 지급 요약 (ownedRelics 변경 없음, 예외 태그만 direct relic)
```

---

## 2. 용어 정의

| 용어 | 정의 | 저장/런타임 |
|------|------|-------------|
| **OwnedRelics** / **AccountRelics** | Lobby에서 **제작 완료**되어 계정에 귀속된 relic. 동의어; 문서·코드 키는 **`ownedRelics`** 권장 | `PlayerRelicProfile.ownedRelics` |
| **EquippedStartingRelics** | **이번 런 시작 시** 들고 가는 Owned relic 목록. 슬롯 **개수 제한** | Teleport → RunContext → Stage 적용 |
| **RunRelicChestPool** | Chest UI에 나올 수 있는 relic id 집합 (§5 공식) | 매 킬/픽업 시 계산, 영구 저장 아님 |
| **LockedRelics** | 아직 craft하지 못한 relic (`ownedRelics`에 없음) | Starting·Chest **모두 제외** |
| **phase3ActiveRelicIds** | **이번 런에서 이미 활성화한** relic id (Starting ∪ Chest 선택 누적) | `ProgressionService` 런 state; **영구 unlock 아님** |

**주의:** `phase3ActiveRelicIds`에 있다고 **account에 새로 Owned 되는 것이 아니다.** 이미 `ownedRelics`에 있어야 Chest 후보가 됐고, 선택은 **런 내 modifier 활성화**만 의미한다.

---

## 3. 기존 구조와 달라지는 점

### 3.1 현재 MVP 코드 (2026-05 기준)

| 항목 | 현재 |
|------|------|
| `Phase3RelicPool` | 무기별 **정적 7종** 합집합 + `activeWeapons` + round-robin |
| `addPhase3Relic` | `RelicDefinitions` 존재·중복만 검사 — **Owned 검사 없음** |
| `startingRelicId` | Lobby `RelicData` **1종** → Teleport |
| `SessionResult` | relic / blueprint / material **미포함** |
| 영구 프로필 | **없음** (Stage `progressByPlayer` 메모리만) |

### 3.2 목표 설계와의 차이 (명시)

| 주제 | 잘못된 해석 (하지 않음) | 목표 |
|------|-------------------------|------|
| **Phase3RelicChest** | 새 relic **영구 획득** 장소 | 이미 **Owned**인 relic 중 **이번 런 추가 활성화** |
| **Chest 선택** | `ownedRelics` 추가 | **`phase3ActiveRelicIds`만** 변경 |
| **영구 성장** | chest / `phase3ActiveRelicIds` | **blueprint / material / Lobby craft** |
| **Result** | `phase3ActiveRelicIds` → unlock | **blueprintProgress / materials** 지급·표시 |
| **StartingRelic** | RelicData와 무관한 별도 유물군 (장기) | **Owned의 장착 슬롯** |

### 3.3 이전 메타 PLAN 초안과의 차이

- ~~Chest 획득 relicId마다 Result에서 `blueprintProgress` 지급~~ → **폐기**
- ~~Chest가 영구 unlock 경로~~ → **폐기**; unlock = **Lobby craft → `ownedRelics`**

---

## 4. 데이터 모델 초안

### 4.1 계정 프로필 (`PlayerRelicProfile`)

DataStore 대상. **5A:** store `PlayerRelicProfile`, key `tostring(userId)`, payload `version = 1`.

```lua
playerRelicProfile = {
  version = 1,

  ownedRelics = {
    [relicId] = true,
  },

  blueprintProgress = {
    [blueprintId] = number,
  },

  materials = {
    shard = number,
    ancient_shard = number,
    ceremonial_coin = number,
  },

  equippedStartingRelics = {
    -- MVP: 순서 있는 배열, 최대 RelicStartingSlotMax
    "relicId_1",
    "relicId_2",
  },
}
```

### 4.2 필드 설명

| 결정 | 내용 |
|------|------|
| **`ownedRelics` vs `unlockedRelics`** | **`ownedRelics`** — “제작 완료·귀속”. `unlocked`는 chest 오해 유발 |
| **`equippedStartingRelics`** | MVP **배열**. 장기 slot map 가능 (`{ slot1 = id }`) |
| **Starting slot cap** | `GameConfig.RelicStartingSlotMax` 또는 `RelicConfig.RelicStartingSlotMax` (기본값 TBD, 예: 1) |
| **`blueprintId`** | MVP **`blueprintId = relicId` (1:1)**. fragment 종류 분리 시만 `bp_*` 분리 |
| **`materials`** | **craft 전용** — `playerRelicProfile` 내부. 전역 골드 등은 별도 currency profile (후속) |

### 4.3 런타임 Stage state (기존 + 목표)

| 필드 | 역할 |
|------|------|
| `equippedStartingRelics` | Teleport payload → 런 시작 시 `phase3ActiveRelicIds`에 **시드** |
| `phase3ActiveRelicIds` | Starting + Chest 선택으로 **런 중 활성** (applicator / BuildTag) |
| `startingRelicId` (현행) | **과도기:** 슬롯 1개일 때 단일 장착 미러; Step 7에서 배열로 대체 |

### 4.4 직접 relic grant 예외 (`obtainTags` 설계)

| 태그 | 용도 |
|------|------|
| `Crafted` | Lobby craft → `ownedRelics` (정규 경로) |
| `Starter` / newbie | 뉴비 기본 Owned (과도기 RelicData 3종) |
| `Shop` / `Event` | 상점·이벤트 direct |
| `RankReward` | 랭크 보상 direct |

---

## 5. Phase3RelicChest pool 공식

### 5.1 SSOT 공식

```text
RunRelicChestPool(player, activeWeapons) =
  ⋃_{weaponId ∈ activeWeapons} Phase3RelicPool.staticPool[weaponId]
  ∩ { relicId | playerRelicProfile.ownedRelics[relicId] == true }
  \ equippedStartingRelics
  \ phase3ActiveRelicIds
```

- **합집합:** `Phase3RelicPool.buildOfferChoicesForWeapons(weaponIds, filters, …)` — **Step 3 구현됨** (`filters.sessionOwnedRelicIds` 등).
- **차집합:** Lua/서버에서는 `equippedStartingRelics`와 `phase3ActiveRelicIds`를 set으로 제외.

### 5.2 추가 필터 (정의 메타)

```text
  ∩ { relicId | RelicDefinitions[relicId].isRunChestEligible ~= false }
  ∩ { relicId | activeWeapons와 weapon/class/effect target 호환 }
```

현재 MVP는 `Phase3RelicPool`이 **weaponId 키**로 이미 무기를 나누므로, `staticPool[weaponId]`가 weapon 매칭에 해당한다.

### 5.3 오퍼 추출 (현행 유지)

- 후보 집합에 대해 **round-robin**, **최대 3택**, **relicId 중복 없음**
- `hasAvailableChoicesForWeapons` → `|RunRelicChestPool| > 0` 일 때만 킬 드랍 roll (`CombatService`)

### 5.4 Locked / 소진

| 상태 | Chest |
|------|-------|
| **Locked** (not Owned) | 공식 좌항에 없음 → **미등장** |
| **전부 Owned + 모두 Starting 또는 이미 phase3Active** | 빈 pool → **미스폰** (현행 `hasAvailableChoices`와 동일 패턴) |

---

## 6. StartingRelic slot 정책

### 6.1 원칙

- **StartingRelic은 별도 유물군이 아니다.**
- **`ownedRelics` 중 일부**를 런 시작 시 들고 가는 **제한 슬롯**이다.
- `equippedStartingRelics`에 포함된 relic은 **해당 런의 RunRelicChestPool에서 제외** (이중 적용 방지).

### 6.2 과도기 (현재 코드)

| 항목 | 현재 |
|------|------|
| Lobby | `RelicData.lua` 3종 — `old_shield_emblem`, `cracked_sword_tip`, `knights_belt` |
| 전달 | `startingRelicId` **1개** — `LobbyBootstrap` → Teleport → `RunContext` |
| 전투 | `RelicData.getCombatMultipliers(startingRelicId)` (SS SwordShield 가중) |
| Phase3 | `RelicDefinitions` 7종 pool — **Owned 필터 없음** (갭) |

**정책:** **RelicData 즉시 삭제 금지.** RelicDefinitions로의 **통합은 Step 7 이후 별도 migration PLAN**.

### 6.3 목표

| 항목 | 목표 |
|------|------|
| 장착 | `equippedStartingRelics` ≤ `RelicStartingSlotMax` |
| 검증 | 장착 id ∈ `ownedRelics` |
| Chest | 장착분 제외 (§5) |
| RelicData | `isStartingEligible` relic만 장착 후보 (Definitions 메타 또는 RelicData 병행) |

### 6.4 migration 시점

**DataStore + Craft + Owned 기반 Chest filter(Step 3~5) 안정화 후** — Starting 슬롯 전환(Step 7). 그 전에 RelicDefinitions 일괄 통합 **하지 않음**.

---

## 7. Result reward 방향

### 7.1 원칙

| 항목 | 정책 |
|------|------|
| **Result → `ownedRelics`** | **변경하지 않음** (craft는 Lobby만) |
| **Result 지급** | `blueprintProgress`, `materials` (shard 등), boss material |
| **Result UI** | 지급량·진행도 **요약 표시** (구현 Step 6) |
| **`phase3ActiveRelicIds`** | **이번 런 활성 목록** 참고·표시 가능; **영구 unlock 목록 아님** |

### 7.2 보상 산정 (MVP 설계)

| 우선 | 출처 |
|------|------|
| **P0 (추천)** | floor / boss / biome 테이블 — **chest와 독립** |
| P1 | `phase3ActiveRelicIds` 계열 **보너스** material (선택, 복잡도↑) |

**하지 않음:** chest 선택 relicId마다 자동 `ownedRelics` 또는 blueprint 완성.

### 7.3 Direct relic grant 예외

Result 또는 메타 시스템에서 **relic 완성품** 직접 지급:

- newbie starter  
- shop  
- event  
- rank_reward  

→ `ownedRelics[relicId] = true` + `obtainTags` 기록.

---

## 8. RelicDefinitions schema — Step 2 적용 (dead metadata)

`src/ReplicatedStorage/Shared/RelicDefinitions.lua` 7종에 아래 필드가 등록됨. **런타임은 `modifiers` + `Phase3RelicPool` 정적 목록만 사용** — Step 3 전까지 필터·craft 미연동.

| 필드 | 용도 |
|------|------|
| `blueprintId` | `blueprintProgress` 키 (MVP: `= relicId`) |
| `craftCost` | `{ blueprintProgressMin, materials }` — placeholder |
| `requiredMaterials` | (기존) 엑셀 string `""` — table 변환은 후속 |
| `isCraftable` | Lobby craft 가능 여부 |
| `isStartingEligible` | Starting 슬롯 후보 (Step 7 전 **전부 false**) |
| `isRunChestEligible` | Phase3RelicChest 후보 (Step 3에서 읽기) |
| `isPermanentUnlockable` | `ownedRelics` 귀속 가능 |
| `obtainTags` / `unlockTags` | (기존) 엑셀 정합 |
| `modifiers` | `RelicModifierApplicator` (변경 없음) |

### 8.1 Run relic 7종 Step 2 기본값 (동일 정책)

| relicId | blueprintId | craftCost (placeholder) | isCraftable | isStartingEligible | isRunChestEligible | isPermanentUnlockable |
|---------|-------------|-------------------------|-------------|-------------------|--------------------|-----------------------|
| `run_reinforced_rim` | = id | `{ blueprintProgressMin = 1, materials = {} }` | true | **false** | true | true |
| `run_rhythm_harness` | = id | 동일 | true | false | true | true |
| `mercenarys_baldric` | = id | 동일 | true | false | true | true |
| `shattering_light` | = id | 동일 | true | false | true | true |
| `last_giants_claw` | = id | 동일 | true | false | true | true |
| `needle_edge` | = id | 동일 | true | false | true | true |
| `giants_pike` | = id | 동일 | true | false | true | true |

- `giants_pike`: `obtainTags`/`unlockTags`를 다른 6종과 동일 `{ Crafted }` / `{ Blueprint }` 로 정합.
- `validate()`: meta 필드는 **optional 타입 검사**만 (`RelicDefinitions.validateMetaProgression` 로컬 헬퍼).

---

## 9. 최소 구현 단계

| Step | 내용 | 코드/DataStore |
|------|------|----------------|
| **1** | **본 문서** — 용어 · RunRelicChestPool 공식 · 정책 확정 | **docs only** ✓ |
| **2** | `RelicDefinitions` craft/chest eligibility metadata | Shared, **런타임 동작 변경 없음** ✓ |
| **3** | 세션 **fake `ownedRelics`** + Chest filter (Owned ∩ pool − equipped − phase3Active) | ProgressionService / Phase3RelicPool ✓ |
| **4A** | Lobby relic **API 스펙 문서화** (본 §13) | **docs only** ✓ |
| **4B** | `RelicProfileService` 세션 stub + `GetRelicProfile` | Lobby ✓ (§13.9) |
| **4C-1** | `CraftRelicRequest` 세션 craft (materials 차감, blueprint 유지) | Lobby ✓ (§13.10) |
| **4C-2** | `EquipStartingRelicsRequest` 세션 equip (`{}` 해제 포함) | Lobby ✓ (§13.11) |
| **5A** | **DataStore** `PlayerRelicProfile` foundation | `RelicProfilePersistence` + `RelicProfileService` |
| **5B** | Result material grant (RewardBudget) | WaveService |
| **5C** | Phase3RelicChest real `ownedRelics` | ProgressionService |
| **6** | **Result** blueprint/material 지급 + UI 요약 | WaveService, ResultClient |
| **7** | Starting = **ownedRelics + slot cap**; RelicData migration은 **별도 PLAN** | Lobby, Teleport, Progression |

---

## 10. 하지 말아야 할 것 (구현 시)

- Phase3RelicChest에 **미소유( Locked ) relic** 등장  
- Chest 선택을 **`ownedRelics` 영구 unlock**으로 처리  
- StartingRelic을 **별도 유물군**으로 신규 정의 (장기적으로 슬롯만)  
- **RelicData 즉시 삭제** · **RelicDefinitions 즉시 통합**  
- 본 설계 단계에서 **DataStore / UI / Result 구현** (별도 승인)  
- **Class effect** 구현  
- reward **수치 확정** (테이블은 placeholder)

---

## 11. 관련 경로

| 용도 | 경로 |
|------|------|
| 현재 MVP 런타임 | `docs/PHASE3_MVP_CURRENT_ARCHITECTURE.md` |
| Choice flow | `docs/CHOICE_FLOW_CURRENT_AND_PHASE3_PLAN.md` |
| 정적 pool | `src/ReplicatedStorage/Shared/Phase3RelicPool.lua` |
| 런 state | `src/ServerScriptService/ProgressionService.lua` |
| Lobby relic profile (4B) | `src/ServerScriptService/RelicProfileService.lua` |
| Starting (과도기) | `src/ReplicatedStorage/Shared/RelicData.lua` |
| Chest drop | `src/ServerScriptService/CombatService.lua` |

---

## Change Log

| 날짜 | 내용 |
|------|------|
| 2026-05-27 | 초안: Owned / Craft / Starting slot / RunRelicChestPool · Result blueprint 방향 · 구현 단계 |
| 2026-05-27 | **Step 2:** RelicDefinitions 7종 meta 필드 + optional validate · dead until Step 3 |
| 2026-05-27 | **Step 3:** Debug fake owned/equipped · Phase3RelicPool filters · `hasPhase3RelicChestOfferAvailable` |
| 2026-05-27 | **Step 4A:** Lobby GetRelicProfile / Craft / Equip API 스펙 · RelicProfileService · UI 연결 · 4B/4C 후보 (docs only) |
| 2026-05-27 | **Step 4B:** `RelicProfileService` 세션 stub · `GetRelicProfile` · `GameConfig.RelicStartingSlotMax` · Lobby `MainServer` wiring (§13.9) |
| 2026-05-27 | **Step 4C-1:** `CraftRelicRequest` 세션 craft · materials 차감 · blueprint 유지 · 성공 시 `profile` 스냅샷 (§13.10) |
| 2026-05-29 | **Step 5B:** Run result material grant · RunResultRewardPolicy · Persistence.grantMaterials · SessionResult.RewardSummary |
| 2026-05-27 | **Step 5A:** RelicProfilePersistence DataStore foundation (§13.12) |
| 2026-05-27 | **Step 4C-2:** `EquipStartingRelicsRequest` 세션 equip · `{}` 해제 · 7종 non-empty `NOT_STARTING_ELIGIBLE` (§13.11) |

---

## 12. Step 3 — Debug chest filter (Studio)

| `GameConfig.Debug` 키 | 값 | 효과 |
|------------------------|-----|------|
| `Phase3FakeOwnedRelicIds` | **`nil`** (기본) | legacy — activeWeapons static pool 전부 owned로 간주 |
| | `{}` | owned 없음 → Chest 미스폰 |
| | `{ "needle_edge", … }` | 해당 id만 Owned ∩ 후보 |
| `Phase3FakeEquippedStartingRelicIds` | `{}` (기본) | listed id는 chest에서 제외 (`startingRelicId`와 **무관**) |
| `Phase3TestRelicIds` | (기존) | `phase3ActiveRelicIds` **런 시드** — fake owned와 별개 |

**API:** `ProgressionService.buildPhase3RelicOfferFilters` → `Phase3RelicPool.buildOfferChoicesForWeapons(weaponIds, filters, maxCount)`. `CombatService` 드랍 게이트 → `hasPhase3RelicChestOfferAvailable`.

---

## 13. Lobby Relic Profile / Craft / Equip API

**상태:** **4B** ✓ · **4C-1** Craft ✓ · **4C-2** Equip ✓ · **5A** persistence ✓ · **5B** result materials ✓ · **5C**·UI·Stage(Teleport/Starting)는 후속.

**Place 경계:** Lobby Place에서 프로필 API 사용. Stage Place는 Step 3까지 `GameConfig.Debug` chest filter + `startingRelicId` Teleport만. Lobby `ownedRelics`가 Stage chest에 반영되려면 **Step 5~7** (DataStore · Teleport payload).

### 13.1 Remote 목록

| 이름 | 종류 | 호출 주체 | 비고 |
|------|------|-----------|------|
| **`GetRelicProfile`** | RemoteFunction | Lobby 클라 | 읽기 전용 스냅샷 — **4B 구현** (`default.project.json` + `RelicProfileService`) |
| **`CraftRelicRequest`** | RemoteFunction | Lobby 클라 | 서버 검증 후 `ownedRelics` 추가 — **4C-1 구현** |
| **`EquipStartingRelicsRequest`** | RemoteFunction | Lobby 클라 | `equippedStartingRelics` 전체 교체 — **4C-2 구현** |

**후속 후보 (Step 4A 범위 밖):**

| 이름 | 비고 |
|------|------|
| `GetRelicDefinitionSummary` | 클라 캐시용 id/label/craft 메타 일괄 — UI 연동 시 |
| `UnequipStartingRelicRequest` | 단일 해제 — `EquipStartingRelicsRequest`가 배열 교체로 대체 가능 |


### 13.12 Step 5A — DataStore foundation

| 항목 | 정책 |
|------|------|
| Store name | **PlayerRelicProfile** (document version field) |
| Craft save | immediate SetAsync on success |
| Equip save | markDirty + debounce + autosave + PlayerRemoving flush |
| Load gate | PROFILE_LOADING |
| Modules | RelicProfilePersistence.lua, RelicProfileService.lua |

### 13.13 Step 5B — Result material grant (placeholder)

| 항목 | 정책 |
|------|------|
| Pipeline | WaveService.finishSession → RunResultRewardPolicy → RelicProfilePersistence.grantMaterials |
| Grant | **materials only** (Option C); no blueprint from Result |
| Save | immediate save (5A SetAsync) |
| UI payload | RewardSummary: applied, materialsGranted (no materialsAfter) |
| Config | GameConfig.RunResultReward + RelicProfilePersistence.Enabled |

**Remotes 위치:** `ReplicatedStorage.Remotes` (기존 `StartingRelicSelectRequest`와 동일 패턴). Step 4B에서 서버가 `FindFirstChild` 또는 생성.

---

### 13.2 `GetRelicProfile`

**Request:** 인자 없음 (호출 플레이어 = `player`).

**Response (성공):**

```lua
{
  ok = true,
  version = 1,

  ownedRelics = {
    -- [relicId] = true
  },

  blueprintProgress = {
    -- [blueprintId] = number  -- MVP: blueprintId == relicId
  },

  materials = {
    shard = 0,
    ancient_shard = 0,
    ceremonial_coin = 0,
  },

  equippedStartingRelics = {
    -- 순서 배열, 최대 relicStartingSlotMax
    -- "relicId_1",
  },

  craftableRelics = {
    -- 서버가 RelicDefinitions 스캔 + 프로필 기준 파생 (저장 필드 아님)
    {
      relicId = "needle_edge",
      blueprintId = "needle_edge",
      label = "Needle Edge",
      blueprintProgress = 0,
      blueprintProgressMin = 1,
      materialsRequired = {},  -- craftCost.materials 스냅샷
      isCraftable = true,
      isOwned = false,
      canCraft = false,        -- canCraftRelic 결과 미러
      craftBlockReason = "NOT_ENOUGH_BLUEPRINT",  -- canCraft == false 일 때
    },
  },

  startingEligibleRelics = {
    -- owned & RelicDefinitions.isStartingEligible == true
    {
      relicId = "example_id",
      label = "…",
      equipped = false,  -- equippedStartingRelics 포함 여부
    },
  },

  relicStartingSlotMax = 1,  -- GameConfig.RelicStartingSlotMax (4B placeholder)
}
```

**Response (실패):**

```lua
{ ok = false, reason = "PROFILE_UNAVAILABLE" }
```

**파생 규칙:**

- `craftableRelics`: `isCraftable == true`, 정의 존재, **not** `ownedRelics[relicId]`.
- `startingEligibleRelics`: `ownedRelics[relicId]` and `isStartingEligible == true` (현재 7종 run relic은 **후보 0개**).
- `locked` relic 목록은 클라가 `RelicDefinitions` 전체 − owned로 계산 가능 — 서버는 `craftableRelics` / `startingEligibleRelics`만 필수 제공.

---

### 13.3 `CraftRelicRequest`

**Request:** `relicId: string`

**Response (성공):**

```lua
{
  ok = true,
  relicId = "needle_edge",
  profile = { /* getPublicProfile DTO — Option B */ },
}
```

**Response (실패):**

```lua
{ ok = false, reason = "<CraftFailReason>" }
```

#### Craft 검증 규칙 (서버 SSOT)

검사 순서 권장:

| 순서 | 조건 | `reason` |
|------|------|----------|
| 0 | profile 없음 | `PROFILE_UNAVAILABLE` |
| 1 | `relicId` 비문자열/빈 문자열 | `INVALID_RELIC_ID` |
| 2 | `RelicDefinitions.getDefinition(relicId)` 없음 | `UNKNOWN_RELIC` |
| 3 | `def.isCraftable ~= true` | `NOT_CRAFTABLE` |
| 4 | `def.isPermanentUnlockable == false` | `NOT_PERMANENT_UNLOCKABLE` |
| 5 | `ownedRelics[relicId] == true` | `ALREADY_OWNED` |
| 6 | `blueprintProgress[def.blueprintId or relicId] < craftCost.blueprintProgressMin` | `NOT_ENOUGH_BLUEPRINT` |
| 7 | `craftCost.materials` 키별 `profile.materials[key] < required` | `NOT_ENOUGH_MATERIALS` |

**성공 시 서버 동작 (4C-1 SSOT):**

1. `craftCost.materials`만 차감 (`blueprintProgress`는 **유지** — unlock threshold).
2. `ownedRelics[relicId] = true`.
3. 응답에 `profile = getPublicProfile(player)` 포함 (Option B).
4. obtain 기록 `Crafted` — Step 5+.

**저장:** 세션 메모리 only — DataStore 없음.

**금지:** 클라가 owned·재료를 직접 설정. **밸런스 수치 확정은 Step 4A 범위 밖** (`craftCost` placeholder 유지).

---

### 13.4 `EquipStartingRelicsRequest`

**Request:** `relicIds: { string }` — **전체 슬롯 스냅샷 교체** (부분 패치 아님).

**Response (성공):**

```lua
{
  ok = true,
  equippedStartingRelics = { "relicId_1" },
  profile = { /* getPublicProfile DTO — Option B */ },
}
```

**Response (실패):**

```lua
{ ok = false, reason = "<EquipFailReason>" }
```

#### Equip 검증 규칙

| 순서 | 조건 | `reason` |
|------|------|----------|
| 0 | profile 없음 | `PROFILE_UNAVAILABLE` |
| 1 | `relicIds`가 table 아님 | `INVALID_RELIC_ID` |
| 2 | `#relicIds > relicStartingSlotMax` | `TOO_MANY_EQUIPPED` |
| 3 | 배열 내 동일 `relicId` 중복 | `DUPLICATE_RELIC` |
| 4 | 항목이 non-empty string 아님 | `INVALID_RELIC_ID` |
| 5 | `RelicDefinitions.getDefinition(relicId)` 없음 | `UNKNOWN_RELIC` |
| 6 | `ownedRelics[relicId] ~= true` | `NOT_OWNED` |
| 7 | `def.isStartingEligible ~= true` | `NOT_STARTING_ELIGIBLE` |

**성공 시 (4C-2 SSOT):** `profile.equippedStartingRelics` = `copyEquippedStartingRelics(relicIds)`. 응답에 `profile` 포함 (Option B).

**빈 배열 `{}`:** 전부 해제 — **성공** (현재 7종 `isStartingEligible=false`라 non-empty는 `NOT_STARTING_ELIGIBLE`).

**저장:** 세션 메모리 only. **Teleport / RunContext / Stage 미연결** (§13.6).

---

### 13.5 `RelicProfileService` (Step 4B)

**경로:** `src/ServerScriptService/RelicProfileService.lua`

**저장:** `profilesByUserId[userId]` — 세션 메모리 (`PlayerAdded` 생성, `PlayerRemoving` 정리). Step 5에서 DataStore adapter로 교체.

**내부 프로필:** §4.1 `playerRelicProfile`와 동형.

| 함수 | 4B | 역할 |
|------|-----|------|
| `init({ players, replicatedStorage, gameConfig })` | ✓ | Lobby `MainServer.startLobbyBranch`만 · `GetRelicProfile` 핸들러 |
| `getProfile(player)` | ✓ | mutable 내부 table |
| `getPublicProfile(player)` | ✓ | `GetRelicProfile` DTO |
| `hasOwnedRelic(player, relicId)` | ✓ | read-only |
| `canCraftRelic(profile, relicId)` | ✓ | read-only (`boolean, reason?`) |
| `craftRelic(player, relicId)` | ✓ (4C-1) | 검증 + materials 차감 + `ownedRelics` + `profile` 응답 |
| `buildCraftableRelics` / `buildStartingEligibleRelics` | ✓ | DTO 파생 |
| `canEquipStartingRelics(profile, relicIds)` | ✓ (4C-2) | read-only |
| `setEquippedStartingRelics(player, relicIds)` | ✓ (4C-2) | 검증 + equip + `profile` 응답 |
| `getOwnedRelicIdsForChest` | 7 | Stage chest SSOT — **4B까지 Stage는 `GameConfig.Debug`** |

**Debug 공존 (Stage chest, 현행):**

- `ProgressionService.getSessionOwnedRelicIdsForChest` → `GameConfig.Debug.Phase3FakeOwnedRelicIds`.
- RelicProfileService 도입 후 통합 순서 (문서만): **Step 5+** 프로필 우선 → 없으면 Debug → 없으면 legacy `nil`.

**테스트 시드 (4B optional):** `GameConfig.Debug.RelicProfileTestSeed` — owned / materials / blueprint 초기값 (별도 PLAN).

---

### 13.6 StartingRelic 과도기 정책 (Step 4A — 유지)

| 항목 | Step 4A | Step 7 |
|------|---------|--------|
| `StartingRelicSelectRequest` (RemoteEvent) | **유지** | 검토 |
| `RelicData` 3종 (`old_shield_emblem`, …) | **유지** | migration PLAN |
| `LobbyBootstrap.selectedStartingRelicByPlayer` | **유지** | → profile 연동 |
| `Teleport` / `RunContext.startingRelicId` | **유지** | `equippedStartingRelics[]` payload |
| `EquipStartingRelicsRequest` | **4C-2 구현** (Lobby 세션) | Step 7: 런 시드 + chest 제외 SSOT |
| `RelicData` vs `RelicDefinitions` id | **분리 유지** — Equip API는 Definitions id만 |

**명시:** `equippedStartingRelics`는 Lobby 프로필 필드로만 존재하며, **이번 단계에서 런 시작 활성화에 쓰이지 않는다.** 런 시작은 계속 `startingRelicId` + `RelicData` multipliers.

---

### 13.7 Lobby UI 연결 계획 (구현 없음)

| 패널 | API | 표시·동작 |
|------|-----|-----------|
| **ArtifactCollectionPanel** | `GetRelicProfile` | owned / locked(클라 파생) / `blueprintProgress` |
| **RelicFusionPanel** | `CraftRelicRequest` | `craftableRelics` + 제작 버튼 |
| **InventoryPanel** | `GetRelicProfile.materials` | shard 등 |
| **StartingRelicPanel** | **현행** `StartingRelicSelectRequest` | RelicData 버튼; **장기** `EquipStartingRelicsRequest` |
| **RelicShopPanel** | (후속) direct grant | Step 4A 제외 |

**클라 흐름 (미래):** Lobby 입장 → `GetRelicProfile` 1회 → craft/equip 성공 후 재호출.

**현재 코드:** `LobbyClient` — 패널 placeholder + StartingRelic wiring만 (`docs/PHASE3_MVP` · `README_LobbyGui_BUILD.md`).

---

### 13.8 Step 4C+ 후보

| 단계 | 범위 |
|------|------|
| **4B** | ✓ §13.9 |
| **4C-1** | ✓ §13.10 — `CraftRelicRequest` |
| **4C-2** | ✓ §13.11 — `EquipStartingRelicsRequest` |
| **5** | DataStore `PlayerRelicProfile` persist |
| **7** | Teleport equipped → Stage seed; chest `equippedStartingRelics` SSOT; RelicData migration |

---

### 13.9 Step 4B — 구현 요약 (2026-05-27)

| 항목 | 내용 |
|------|------|
| **신규** | `src/ServerScriptService/RelicProfileService.lua` |
| **수정** | `MainServer.server.lua` — `startLobbyBranch`에서 `RelicProfileService.init` → `LobbyBootstrap.init` |
| **수정** | `GameConfig.lua` — `RelicStartingSlotMax = 1`, `Debug.RelicProfileTestSeed = nil` |
| **수정** | `default.project.json` — `Remotes.GetRelicProfile` RemoteFunction |
| **미구현 (4B 금지)** | Craft/Equip Remote, UI, Teleport, Stage chest 프로필 연동, DataStore |

**Lobby Studio 검증:**

```lua
game:GetService("ReplicatedStorage").Remotes.GetRelicProfile:InvokeServer()
```

**기대 (`RelicProfileTestSeed = nil`):** `ok == true`, `craftableRelics` 7종 (`isCraftable` 정의), `startingEligibleRelics == {}`, `ownedRelics == {}`, `relicStartingSlotMax == 1`.

**Stage:** `ProgressionService` chest는 계속 `GameConfig.Debug.Phase3FakeOwnedRelicIds` — 프로필과 **미연동**.

**Starting 과도기 유지:** `StartingRelicSelectRequest`, `RelicData` 3종, `selectedStartingRelicByPlayer`, Teleport `startingRelicId`.


---

### 13.10 Step 4C-1 — CraftRelicRequest 구현 요약 (2026-05-27)

| 항목 | 내용 |
|------|------|
| **수정** | `RelicProfileService.lua` — `craftRelic`, `CraftRelicRequest` Remote, `canCraftRelic` 빈 id → `INVALID_RELIC_ID` |
| **수정** | `default.project.json` — `Remotes.CraftRelicRequest` |
| **mutation** | `craftCost.materials` 차감 only · `blueprintProgress` 유지 · `ownedRelics[relicId]=true` |
| **응답** | 성공 `{ ok, relicId, profile }` · 실패 `{ ok=false, reason }` |
| **미구현** | Equip, UI, DataStore, Teleport, Stage chest 연동, obtain history |

**Lobby Studio 검증 (클라 Command Bar):**

```lua
-- GameConfig.Debug.RelicProfileTestSeed = { blueprintProgress = { needle_edge = 1 }, ownedRelics = {}, materials = {} }
local r = game:GetService("ReplicatedStorage").Remotes
print(r.CraftRelicRequest:InvokeServer("needle_edge"))
print(r.GetRelicProfile:InvokeServer())
```

**기대:** 첫 호출 `ok==true`, `profile.ownedRelics.needle_edge==true`, `craftableRelics` 6종; 재호출 `ALREADY_OWNED`.


---

### 13.11 Step 4C-2 — EquipStartingRelicsRequest 구현 요약 (2026-05-27)

| 항목 | 내용 |
|------|------|
| **수정** | `RelicProfileService.lua` — `canEquipStartingRelics`, `setEquippedStartingRelics`, `EquipStartingRelicsRequest` Remote |
| **수정** | `default.project.json` — `Remotes.EquipStartingRelicsRequest` |
| **mutation** | `equippedStartingRelics` 전체 스냅샷 교체 (shallow copy) |
| **응답** | 성공 `{ ok, equippedStartingRelics, profile }` · 실패 `{ ok=false, reason }` |
| **현재 데이터** | 7종 `isStartingEligible=false` → non-empty equip은 `NOT_STARTING_ELIGIBLE`; `{}`만 성공 |
| **미구현** | UI, DataStore, Teleport, Stage chest/StartingRelic 연동 |

**Lobby Studio 검증 (클라 Command Bar):**

```lua
local r = game:GetService("ReplicatedStorage").Remotes
print(r.EquipStartingRelicsRequest:InvokeServer({}))  -- A: ok, equipped {}
-- craft/seed owned 후:
print(r.EquipStartingRelicsRequest:InvokeServer({ "needle_edge" }))  -- C: NOT_STARTING_ELIGIBLE
```

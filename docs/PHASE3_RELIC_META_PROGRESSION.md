# Phase 3 Relic Meta Progression — Design (Owned / Craft / Run Chest)

**목적:** 런 중 **Phase3RelicChest**와 **영구 성장**(blueprint / material / craft)의 역할을 분리하고, 계정 귀속 relic(Owned) · Starting 슬롯 · Run chest pool 공식을 SSOT로 고정한다.

| 항목 | 값 |
|------|-----|
| 문서 경로 | `docs/PHASE3_RELIC_META_PROGRESSION.md` |
| 런타임 정본 (현재 MVP) | `docs/PHASE3_MVP_CURRENT_ARCHITECTURE.md` |
| Choice / pending | `docs/CHOICE_FLOW_CURRENT_AND_PHASE3_PLAN.md` |
| **이 문서만으로 게임 동작이 바뀌지 않는다** | 설계·용어·단계·구현 로그 |

**Phase 3 Meta Progression — core: COMPLETE (2026-05 closeout).** 검증: 개발 중 실플레이.


---

## 0. Phase 3 Closeout SSOT (runtime)

| Layer | SSOT |
|-------|------|
| Relic 정의·전투 modifier | `RelicDefinitions` + `RelicModifierApplicator` |
| 계정 프로필 | `RelicProfilePersistence` / `RelicProfileService` |
| Lobby 장착 | `EquipStartingRelicsRequest` → `equippedStartingRelics` |
| Cross-place | `equippedStartingRelicIds` → `RunContext` → `phase3ActiveRelicIds` |
| Run chest 후보 | `ownedRelics` − `equippedStartingRelics` − `phase3ActiveRelicIds` (+ `isRunChestEligible`) |
| Result (구현) | materials placeholder (5B) |
| Result (미구현) | blueprint discovery |
| Class | detection baseline only; effects 미구현 |
| Removed (7C-3) | `RelicData.lua`, `startingRelicId`, `StartingRelicSelectRequest`, `getStartingRelicId` |
| `cracked_sword_tip` | retired — Phase 4+ redesign |
| Obsolete | `ShowLobbyRelicFusionCraftDev`, `ShowLobbyRelicMaterialsDevLabel` (§13.15) |

**Phase 4+ backlog:** → §14.
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
[Result]   materials 지급 요약 (placeholder 5B); blueprint from Result **미구현**
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

### 3.1 구현 완료 코드 (2026-05 closeout)

| 항목 | 현재 |
|------|------|
| 항목 | 상태 |
|------|------|
| `Phase3RelicPool` | pool + filters (owned - equipped - active) + round-robin |
| `ProgressionService` | `phase3ActiveRelicIds`; chest owned from profile (5C) |
| Lobby profile | `RelicProfileService` + DataStore (5A) |
| Starting | `EquipStartingRelicsRequest` -> Teleport -> phase3 seed (7B) |
| `SessionResult` | `RewardSummary.materialsGranted` only (5B placeholder) |
| Legacy | RelicData / startingRelicId / StartingRelicSelectRequest - **removed (7C-3)** |

### 3.2 목표 설계와의 차이 (명시)

| 주제 | 잘못된 해석 (하지 않음) | 목표 |
|------|-------------------------|------|
| **Phase3RelicChest** | 새 relic **영구 획득** 장소 | 이미 **Owned**인 relic 중 **이번 런 추가 활성화** |
| **Chest 선택** | `ownedRelics` 추가 | **`phase3ActiveRelicIds`만** 변경 |
| **영구 성장** | chest / `phase3ActiveRelicIds` | **blueprint / material / Lobby craft** |
| **Result** | materials 지급 (5B); blueprint discovery **미구현** |
| **StartingRelic** | 별도 유물군이 아님 | **Owned의 장착 슬롯** (`equippedStartingRelics`) |

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
| `startingRelicId` | **removed (7C-3)** — see §6 Historical |

### 4.4 직접 relic grant 예외 (`obtainTags` 설계)

| 태그 | 용도 |
|------|------|
| `Crafted` | Lobby craft → `ownedRelics` (정규 경로) |
| `Starter` / newbie | Phase 4+ (RelicShop / direct grant) |
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

### 6.2 현행 (closeout)

| 항목 | 구현 |
|------|------|
| Lobby UI | StartingRelicPanel + EquipStartingRelicsRequest |
| Teleport | equippedStartingRelicIds only |
| Stage | phase3ActiveRelicIds seed + Applicator |
| Chest | owned - equipped - active (§5) |

### 6.3 Historical — RelicData era (pre-7C-3)

| 항목 | 과거 (removed) |
|------|----------------|
| Lobby | RelicData.lua 3종 |
| 전달 | startingRelicId |
| Remote | StartingRelicSelectRequest |
| 전투 | RelicData.getCombatMultipliers (superseded 7C-2+) |

---

## 7. Result reward 방향

### 7.1 원칙

| 항목 | 정책 |
|------|------|
| **Result → `ownedRelics`** | **변경하지 않음** (craft는 Lobby만) |
| **Result 지급 (구현)** | `materials` only — RunResultRewardPolicy placeholder (5B) |
| **Result 지급 (미구현)** | blueprint discovery (Phase 4+) |
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
| **7A** | Lobby StartingRelicPanel owned loadout | ✓ §13.17 |
| **7B** | Teleport equipped → RunContext → phase3 seed + chest exclude | ✓ §13.18 |
| **7C-1** | RelicDefinitions migrate 2종 + `cracked_sword_tip` retire | ✓ §13.19 |
| **7C-2** | RelicData runtime 제거 (combat/offer/HUD) | ✓ §13.20 |
| **7C-3** | RelicData.lua·Teleport `startingRelicId`·Remote 삭제 | ✓ §13.21 |

---

## 10. 하지 말아야 할 것 (구현 시)

- Phase3RelicChest에 **미소유( Locked ) relic** 등장  
- Chest 선택을 **`ownedRelics` 영구 unlock**으로 처리  
- StartingRelic을 **별도 유물군**으로 신규 정의 (장기적으로 슬롯만)  


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
| Lobby profile | `src/ServerScriptService/RelicProfileService.lua` |
| Persistence | `src/ServerScriptService/RelicProfilePersistence.lua` |
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
| 2026-05-31 | **Closeout:** docs sync — §0 · §14 · historical labels |`n| 2026-05-27 | **Step 4C-2:** `EquipStartingRelicsRequest` 세션 equip · `{}` 해제 · 7종 non-empty `NOT_STARTING_ELIGIBLE` (§13.11) |

---

## 12. Step 3 — Debug chest filter (Studio)

| `GameConfig.Debug` 키 | 값 | 효과 |
|------------------------|-----|------|
| `Phase3FakeOwnedRelicIds` | **`nil`** (기본) | legacy — activeWeapons static pool 전부 owned로 간주 |
| | `{}` | owned 없음 → Chest 미스폰 |
| | `{ "needle_edge", … }` | 해당 id만 Owned ∩ 후보 |
| `Phase3FakeEquippedStartingRelicIds` | **`nil` / `{}`** | RunContext `equippedStartingRelicIds`로 chest 제외 (7B SSOT) |
| | **non-empty array** | Debug **chest exclude override** (RunContext 무시). **phase3 시드는 RunContext만** |
| `Phase3TestRelicIds` | (기존) | `phase3ActiveRelicIds` **런 시드** — fake owned와 별개 |

**API:** `ProgressionService.buildPhase3RelicOfferFilters` → `Phase3RelicPool.buildOfferChoicesForWeapons(weaponIds, filters, maxCount)`. `CombatService` 드랍 게이트 → `hasPhase3RelicChestOfferAvailable`.

---

## 13. Lobby Relic Profile / Craft / Equip API

**상태 (closeout):** 4B–5B ✓ · 5C · Step 6 UI ✓ · 7A–7C ✓ · legacy removed (7C-3).

**Place 경계:** Lobby 프로필 API + **7B** `equippedStartingRelicIds` Teleport → RunContext → `phase3ActiveRelicIds` 시드 + chest equipped 제외. `startingRelicId` / `StartingRelicSelectRequest` **removed** (historical §13.6).

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

**Remotes 위치:** `ReplicatedStorage.Remotes`. (`StartingRelicSelectRequest` **removed** - historical section 13.6.)

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

**성공 시 (4C-2 SSOT):** `profile.equippedStartingRelics` = `copyEquippedStartingRelics(relicIds)`. 응답에 `profile` 포함 (Option B).

**빈 배열 `{}`:** 전부 해제 — **성공**.

**Step 7A 정책 (2026-05-31):** `isStartingEligible`는 Equip 게이트에 **사용하지 않음**. owned + slot cap만 검증. Run chest pool = `ownedRelics` − `equippedStartingRelics` − `phase3ActiveRelicIds` (7B).

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

### 13.6 Historical — StartingRelic policy snapshot (pre-7C-3, do not implement)

| 항목 | Step 4A | Step 7 |
|------|---------|--------|
| `StartingRelicSelectRequest` (RemoteEvent) | **유지** | 검토 |
| `RelicData` 3종 | **7C-1:** 2종 Definitions 이관 · `cracked_sword_tip` retire | **7C-2:** 모듈 제거 |
| `LobbyBootstrap.selectedStartingRelicByPlayer` | **유지** | → profile 연동 |
| `Teleport` / `RunContext.startingRelicId` | **유지** | `equippedStartingRelics[]` payload |
| `EquipStartingRelicsRequest` | **4C-2 구현** (Lobby 세션) | Step 7: 런 시드 + chest 제외 SSOT |
| `RelicData` vs `RelicDefinitions` id | **분리 유지** — Equip API는 Definitions id만 |

**7B (historical note):** equipped → phase3 seed + chest exclude. Pre-7C-3 also had `startingRelicId` + RelicData (removed).

---

### 13.7 Lobby UI (구현 완료 — Step 6·7A)

| 패널 | API | 표시·동작 |
|------|-----|-----------|
| **ArtifactCollectionPanel** | `GetRelicProfile` | owned / locked(클라 파생) / `blueprintProgress` |
| **RelicFusionPanel** | `CraftRelicRequest` | `craftableRelics` + 제작 버튼 |
| **InventoryPanel** | `GetRelicProfile.materials` | shard 등 |
| **StartingRelicPanel** | `EquipStartingRelicsRequest` | `LobbyRelicStartingPanelClient` (historical: RelicData buttons removed) |
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
| **7A 정책** | `NOT_STARTING_ELIGIBLE` 제거 — owned + slot cap만 |
| **미구현** | UI, DataStore, Teleport, Stage chest/StartingRelic 연동 |

**Lobby Studio 검증 (클라 Command Bar):**

```lua
local r = game:GetService("ReplicatedStorage").Remotes
print(r.EquipStartingRelicsRequest:InvokeServer({}))  -- A: ok, equipped {}
-- craft/seed owned 후:
print(r.EquipStartingRelicsRequest:InvokeServer({ "needle_edge" }))  -- C: ok if owned (7A+)
```


---

### 13.15 Historical — 5C dev bridge (obsolete)

| 항목 | 정책 |
|------|------|
| **모듈** | `LobbyRelicFusionCraftClient.lua` — `LobbyClient.init`에서 require |
| **플래그** | `GameConfig.Debug.ShowLobbyRelicFusionCraftDev` — **기본 `false`**. 5C Publish 검증 빌드만 `true` → 검증 후 **`false` 복구 + 재Publish** |
| **목록 SSOT** | `GetRelicProfile` 응답: `craftableRelics` (Craft 행) + `ownedRelics` (Owned 섹션). `RelicDefinitions`는 label/메타 **보조만** |
| **Craft** | `CraftRelicRequest:InvokeServer(relicId)` 만. 성공 시 상태 `Crafted: <relicId>` 후 refresh |
| **UI** | `RelicFusionPanel` — `RelicFusionStation` (`LobbyPanel=RelicFusionPanel`). 없으면 런타임 `RelicCraftList` / `RelicFusionCraftStatus` 생성 |
| **금지** | 서버 craft/DataStore/owned 직접 조작 · 5C chest 로직 우회 · 정식 Lobby Relic UI · `CraftRelicRequest` 서버 변경 |

**Publish 5C craft 절차 (Command Bar 불필요):**

1. Rojo sync 후 `ShowLobbyRelicFusionCraftDev = true` 로 **로비만** 재Publish (스테이지는 기존 5C 빌드 유지 가능).
2. 로비 입장 → **Relic Fusion Station** → 패널에서 `needle_edge` **Craft** (시드: `RelicProfileTestSeed.blueprintProgress.needle_edge = 1`, 재료 `{}`).
3. Owned 섹션에 `needle_edge` 표시 · Craftable에서 제거 확인 → 스테이지 Spear 런으로 §13.14 표 순서 계속.
4. 검증 종료: `ShowLobbyRelicFusionCraftDev = false` (+ chest 가속 플래그 복구) → sync → **재Publish**.

**Studio-only 대안:** `CraftRelicRequest:InvokeServer("needle_edge")` (Publish 플래그 off 시 패널 비활성).
**대체:** Step 6 정식 UI (§13.16) — dev 모듈·플래그 제거.

---

### 13.16 Step 6 — Lobby Relic UI (정식)

| 우선순위 | 범위 | 모듈 | Remote |
|----------|------|------|--------|
| **A** | Collection: owned, blueprint | `LobbyRelicCollectionPanelClient` | `GetRelicProfile` |
| **B** | Craft: craftable + Craft | `LobbyRelicFusionPanelClient` | `GetRelicProfile`, `CraftRelicRequest` |
| **C** | Materials: 3키 | `LobbyClient` + `LobbyRelicProfileClient` | `GetRelicProfile` |
| **D** | Equip read-only | Collection 동일 | **호출 없음** |

| 제거 | `LobbyRelicFusionCraftClient`, `LobbyRelicMaterialsDevClient`, dev Debug 플래그 |
| 유지 | `StartingRelicPanel`, `StartingRelicSelectRequest`, `RelicData`, `RelicFusionStation` |
---

### 13.17 Step 7A — StartingRelicPanel (owned loadout)

| 항목 | 정책 |
|------|------|
| **후보 SSOT** | `ownedRelics` = 패널에서 선택 가능한 전체 |
| **장착 SSOT** | `equippedStartingRelics` = 이번 런 시작 loadout (`EquipStartingRelicsRequest` 전체 배열 스냅샷) |
| **Chest pool (7B)** | `ownedRelics` − `equippedStartingRelics` − `phase3ActiveRelicIds` |
| **Equip 게이트** | **owned** + **slot cap** (`relicStartingSlotMax` / `GameConfig.RelicStartingSlotMax`)만 · `isStartingEligible` **미사용** (Definitions 값 변경 없음) |
| **UI** | Add / Remove per owned row · cap 초과 시 **Full** · `Clear slots` → `{}` |
| **Deprecated** | `StartingRelicSelectRequest` 클라 미연동 · 서버 warn only |
| **Teleport 7A** | `equippedStartingRelics[1]` → legacy `startingRelicId` · **7B** full array → `equippedStartingRelicIds` |
| **Legacy UI** | `RelicButtonList` + RelicData 3버튼 제거(Studio/MCP) · `StartingRelicOwnedList`만 |
| **모듈** | `LobbyRelicStartingPanelClient` · `RelicProfileService.canEquipStartingRelics` (eligible 검사 제거) |

**7A 검증 순서:** (1) owned 표시 (2) owned면 Add 가능(eligible 무관) (3) SelectRequest 클라 없음 (4) Teleport (5) owned non-empty Equip RF + `{}` clear + cap 초과 `TOO_MANY_EQUIPPED`.

### 13.18 Step 7B — Cross-Place equipped → active seed

| 항목 | 정책 |
|------|------|
| **Teleport key** | `RunConstants.TeleportKeys.EquippedStartingRelicIds` |
| **Lobby** | `LobbyBootstrap` — profile `equippedStartingRelics` + `startingRelicId` dual-write |
| **RunContext** | `getEquippedStartingRelicIds()` — `toFloor` payload 유지 |
| **phase3 시드** | `trySeedEquippedStartingRelicsFromRunContext` — **RunContext only** · idempotent |
| **시드 트리거** | StageBootstrap (RunContext 직후, startSession 전) + ensureProgress (initialized 시) |
| **Chest equipped** | `getEquippedStartingRelicIdsForChest` — nil/`{}` fake → RunContext; non-empty fake → override only |
| **5C** | `sessionOwnedRelicIds` 유지 |
| **Done (7C-3)** | RelicData · startingRelicId · StartingRelicSelectRequest removed |

**7B 검증:** owned needle_edge+giants_pike · equip needle_edge → active needle_edge · chest needle_edge 제외 · giants_pike 후보 · chest pick 후 owned 불변.
### 13.19 Step 7C-1 — RelicData → RelicDefinitions (partial migrate)

| id | 7C-1 정책 | RelicDefinitions | Chest pool |
|----|-----------|------------------|------------|
| `old_shield_emblem` | **migrate** — SS Sweep damage ×1.10 | 등록 · `isRunChestEligible=false` | `Phase3RelicPool` **미등록** (starting loadout) |
| `knights_belt` | **migrate** — SS attack interval ×0.80 | 등록 · `isRunChestEligible=false` | 동일 |
| `cracked_sword_tip` | **retire** — Thrust ×1.10 **이관 안 함** (후속: Block 후 Thrust crit mechanic) | **미등록** | — |

**런타임:** 7C-1 Definitions 이관 ✓ · **7C-2** combat/offer/HUD RelicData 제거 ✓ · Teleport payload·`RelicData.lua` 파일 — **7C-3**.

**7B 시드:** migrated 2종은 `equippedStartingRelics` → `phase3ActiveRelicIds` + `RelicModifierApplicator`로 전투 적용. `startingRelicId`가 동일 id이면 RelicData multiplier와 **중복 가능**(7C-1~7C-2 구간); Publish 검증은 Definitions 장착 플로우 우선.

**DataStore (`RelicProfilePersistence`):** `ownedRelics["cracked_sword_tip"]` **유지**. `equippedStartingRelics` 로드 시 `cracked_sword_tip` **자동 제거** (Equip API는 Definitions id만 허용).

**Craft meta (migrated 2종):** `isCraftable=true`, `isPermanentUnlockable=true`, `blueprintId` = id, `craftCost` = `{ blueprintProgressMin = 1, materials = {} }`.

**7C-1 검증:** (1) `old_shield_emblem` / `knights_belt` owned → Equip OK → Stage active + Applicator 효과 (2) 7B chest 회귀 (`needle_edge` 등) (3) `cracked` equipped strip — 재접속 후 loadout에서 absent, owned 유지 (4) chest에 migrated 2종 **미등장**.

**7C-2 handoff:** RelicData 삭제, `startingRelicId` 제거, pick weights 이전, `cracked` RelicData 잔재 정리.

### 13.20 Historical — Step 7C-2 (RelicData runtime removal)

| 항목 | 7C-2 |
|------|------|
| **SS 전투** | `UpgradeData.getSwordShieldEffectiveCombat` — RelicData mul 제거 · `phase3RelicIds` + Applicator만 |
| **SS 레벨업 offer** | `UpgradeOfferBuilder` — RelicData pick weight 제거 (균등 3선) |
| **Progression** | `startingRelicId` 시드 제거 · `getStartingRelicId()` **deprecated, always nil** (7C-3 삭제 예정) |
| **HUD** | `Phase3ActiveRelicIds` 표시 · `StartingRelicId` 제거 |
| **Removed in 7C-3** | `RelicData.lua` · `startingRelicId` · `StartingRelicSelectRequest` |

**이중 배율:** 7C-2 이후 migrated id 장착 시 RelicData+Applicator 중복 **해소** (전투는 phase3만).

**7C-2 검증:** `knights_belt`/`old_shield_emblem` equip → 단일 배율 · 7B `needle_edge` 회귀 · SS level-up 3선 정상.

**7C-3 handoff:** `RelicData.lua` 삭제 · Teleport/RunContext/LobbyBootstrap `startingRelicId` 제거 · `getStartingRelicId` API 제거.

### 13.21 Step 7C-3

| Item | 7C-3 |
|------|------|
| Deleted | Shared/RelicData.lua |
| Teleport | StartingRelicId key removed |
| RunContext | startingRelicId removed; equippedStartingRelicIds kept |
| LobbyBootstrap | dual-write + StartingRelicSelectRequest removed |
| Progression | startingRelicId state + getStartingRelicId removed |
| Combat SSOT | 7B equipped to phase3ActiveRelicIds seed (unchanged) |
---

## 14. Phase 4+ backlog (not in Phase 3 core)

| 항목 | 상태 |
|------|------|
| Blueprint discovery | 미구현 |
| RewardBudget balancing | placeholder (5B) |
| RelicShopPanel / Rank / Relic upgrade | Phase 4+ |
| Class combat effects | detection only |
| cracked_sword_tip redesign | retired |
| Relic pool / offer weight | MVP round-robin |

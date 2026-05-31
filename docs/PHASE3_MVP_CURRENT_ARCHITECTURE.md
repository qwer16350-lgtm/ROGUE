# Phase 3 MVP — Current Architecture (Playtest-Verified)

**목적:** 현재까지 **구현·실플레이로 검증된** Phase 3 구조를 SSOT 문서로 고정한다.  
**범위:** 분석·설계·구현 가이드의 기준선. 이 문서만으로 게임 동작이 바뀌지 않는다.

| 항목 | 값 |
|------|-----|
| 문서 경로 | `docs/PHASE3_MVP_CURRENT_ARCHITECTURE.md` |
| 코드 정본 | `src/` + `default.project.json` |
| 선행 문서 | `docs/PHASE3_DATASET_ANALYSIS.md`, `docs/PHASE3_RELIC_CANDIDATE_TRIAGE.md`, `docs/CHOICE_FLOW_CURRENT_AND_PHASE3_PLAN.md` |
| 최종 갱신 기준 | Phase 3 meta core closeout · 7종 Run relic · profile/chest/Starting · BuildTag/ClassDetection baseline |

---

## 1. Current Overall Relic Structure

런타임 유물은 **두 경로**로 분리된다. 혼동하지 않는다.

### 1.1 Starting loadout (Lobby to Stage, 7B+)

| Item | Implemented |
|------|-----------------|
| Select | StartingRelicPanel + EquipStartingRelicsRequest |
| Teleport | equippedStartingRelicIds to RunContext |
| Seed | ProgressionService phase3ActiveRelicIds (7B) |
| SS combat | RelicDefinitions + RelicModifierApplicator (7C-2+) |
| Legacy | RelicData.lua / startingRelicId removed (7C-3) |


### 1.2 Run Relic (Stage 런 중 — Phase3RelicChest)

| 항목 | **Implemented** |
|------|-----------------|
| 획득 | `Phase3RelicChest` 픽업 → `ChoiceKind = "Phase3Relic"` 3택1 |
| 풀 | `Phase3RelicPool.lua` + `RelicDefinitions.lua` |
| 보유 | `phase3ActiveRelicIds` (런당 중복 획득 불가) |
| 전투 | `RelicModifierApplicator` → `UpgradeData` effective (SS / TH / Spear) |
| 표시 | `BuildTagService` snapshot · `ClassDetection` (효과 없음, detect only) |
| 테스트 시드 | `GameConfig.Debug.Phase3TestRelicIds` (정식 unlock/equip 아님) |

Run relic id is RelicDefinitions SSOT (run_* namespace).

**Meta (closeout):** `RelicProfilePersistence` · Lobby craft/equip UI · chest = owned − equipped − active.

---

## 2. Phase 2 DroppedRelic Legacy — Removed

**Completed.** 런타임 `.lua` 기준 `DroppedRelic` / `droppedRelicId` / `DROPPED_*` grep **0건**.

| 제거 항목 | 상태 |
|-----------|------|
| `ChoiceKind = "DroppedRelic"` | **removed** |
| `pendingDroppedRelicByPlayer` | **removed** |
| `droppedRelicId` state / getter / HUD read | **removed** |
| `RelicData` `DROPPED_*` | **removed** (module deleted 7C-3) |
| `getDroppedRelicChoices` / `getDroppedRelicEffect` | **removed** |
| `shield_spike` dropped branch | **removed** |
| Phase 2 보라 `RelicChest` kill drop | **removed** |
| `_patch_phase3_progression.js` (비런타임 패치 스크립트) | **deleted** |

**역사:** Phase 2에서는 킬 드랍 보라 상자 → DroppedRelic 선택이 있었으나, Phase 3에서는 **`Phase3RelicChest` → `Phase3Relic`** 만 사용한다.

---

## 3. Phase3RelicChest — Current Acquisition Loop

**Implemented** end-to-end flow:

```text
적 처치 (sourceWeaponId ∈ { SwordShield, Spear, TwoHandedSword })
  → canSpawnPhase3RelicChestOnKill
       · activeWeapons 기준 미보유 Phase3 pool 존재 시에만 roll
  → Phase3RelicChestDropChance roll (Publish: ForcePhase3RelicChestOnKill = false)
  → RelicDropService.spawnPhase3RelicChestAt
  → 플레이어 픽업 (반경 내)
  → ProgressionService.tryGrantPhase3RelicOfferFromChest
  → activeWeapons 전체 → Phase3RelicPool 합집합
  → RunRelicChestPool: static ∩ sessionOwned \ equippedStarting \ phase3Active ∩ isRunChestEligible
  → round-robin 최대 3택 · relicId 중복 없음
  → ChoiceKind = "Phase3Relic" UI
  → submit choiceId
  → addPhase3Relic → phase3ActiveRelicIds
  → RelicModifierApplicator (effective combat)
  → BuildTag / ClassDetection (HudSync DevCombat when enabled)
```

| 단계 | 모듈 |
|------|------|
| 킬·드랍 게이트 | `CombatService` — `hasPhase3RelicChestOfferAvailable` (ProgressionService → Phase3RelicPool filters) |
| 상자 | `RelicDropService` — `DropKind = Phase3RelicChest` |
| 오퍼 | `ProgressionService.buildPhase3RelicOffer` → `Phase3RelicPool.buildOfferChoicesForWeapons` |
| 보유 | `ProgressionService.addPhase3Relic` |

**주의:** `Phase3RelicChest` ≠ 과거 DroppedRelic `RelicChest`. Chest는 **owned unlock이 아님** — `phase3ActiveRelicIds`만 변경.

---

## 4. Offer Pool — activeWeapons (Not primary-only)

### 4.1 Previous (removed)

- `ProgressionService.getWeaponId(player)` **단일** primary 기준
- `Phase3RelicPool.buildOfferChoices(weaponId, …)` — 해당 무기 풀만

### 4.2 Current (**implemented**)

| 규칙 | 내용 |
|------|------|
| 무기 집합 | `state.activeWeapons` 키 중 Phase3 풀 비어 있지 않은 무기 (알파벳 정렬) |
| Fallback | `activeWeapons` 비어 있으면 `getWeaponId` 1종 |
| 합집합 | 무기별 `POOL_BY_WEAPON_ID` relic id 병합 |
| Owned | `ProgressionService.getSessionOwnedRelicIdsForChest` ← DataStore profile (5C); `Phase3FakeOwnedRelicIds = nil` on Publish |
| 제외 | `equippedStartingRelicIds` + `phase3ActiveRelicIds` |
| Eligible | `RelicDefinitions.isRunChestEligible ~= false` |
| 선택지 수 | 최대 **3** |
| 추출 | **round-robin** (무기 순서 고정, 무기별 pool 순서 유지) |
| 중복 | 동일 `relicId` 오퍼·출력에 **없음** |
| 스폰 조건 | filters 후 RunRelicChestPool이 1개 이상일 때만 킬 드랍 가능 |

**예:** Spear 시작 + SwordShield weapon drop 보유 → Spear·SS 풀 모두 오퍼·스폰 후보에 포함 (round-robin).

---

## 5. Phase3RelicPool — Current (7 relics)

| weaponId | relicId (순서) | 종수 |
|----------|----------------|------|
| **SwordShield** | `run_reinforced_rim`, `run_rhythm_harness` | 2 |
| **TwoHandedSword** | `mercenarys_baldric`, `shattering_light`, `last_giants_claw` | 3 |
| **Spear** | `needle_edge`, `giants_pike` | 2 |
| **BasicMagic** | *(empty)* | 0 |

**총 7종** (`Phase3RelicPool.lua` `POOL_BY_WEAPON_ID`).

---

## 6. RelicDefinitions — Run Relic Summary

| relicId | scope | targetTags | stat modifier(s) |
|---------|-------|------------|------------------|
| `run_reinforced_rim` | SwordShield | `ss` + `sweep` | `sweepBaseDamage` ×1.15 |
| `run_rhythm_harness` | SwordShield | `ss` (weapon-wide) | `attackIntervalSeconds` ×0.90 |
| `mercenarys_baldric` | TwoHandedSword | `th` + `sweep` | `sweepBaseDamage` ×1.10 |
| `shattering_light` | TwoHandedSword | `th` + `sweep` | `sweepBaseDamage` ×0.5, `attackIntervalSeconds` ×0.7 |
| `last_giants_claw` | TwoHandedSword | `th` + `sweep` | `sweepBaseDamage` ×1.4, `attackIntervalSeconds` ×1.3 |
| `needle_edge` | Spear | `sp` + `thrust` | `thrustBaseDamage` ×1.10 |
| `giants_pike` | Spear | `sp` + `thrust` | `thrustRangeStuds` ×2.0 → `Thrust.RangeStuds` |

`giants_pike`: upgrade 적용 **후** `RangeStuds`에 ×2.0 후적용 (snapshot 없음). 기본 Spear thrust range 12 stud → ×2.0 시 **24** (업그레이드 0 기준).

**Schema enum (`ALLOWED_STATS`):** `sweepBaseDamage`, `thrustBaseDamage`, `thrustRangeStuds`, `attackIntervalSeconds`, `blockChance`, `attackHitCount` — applicator는 아래 §7만 **실연결**.

---

## 7. RelicModifierApplicator — Supported Stats (by weapon)

코드: `STAT_FIELD_*` + `applyTo*Effective` (2026-05 기준).

### 7.1 Common (정의·스키마)

| stat | 비고 |
|------|------|
| `attackIntervalSeconds` | 무기별 mapping (`thrust=false` 또는 SS weapon-wide) |
| `blockChance`, `attackHitCount` | `ALLOWED_STATS`에만 존재 — **applicator 미연결** |

### 7.2 SwordShield — **implemented**

| stat | maps to |
|------|---------|
| `sweepBaseDamage` | `Sweep.BaseDamage` |
| `thrustBaseDamage` | `Thrust.BaseDamage` |
| `attackIntervalSeconds` | `AttackIntervalSeconds` (weapon-wide, `attackTag` 생략) |

경로: `getSwordShieldEffectiveCombat(..., phase3RelicIds)` → `applyToSwordShieldEffective`.

### 7.3 TwoHandedSword — **implemented**

| stat | maps to |
|------|---------|
| `sweepBaseDamage` | `Sweep.BaseDamage` |
| `attackIntervalSeconds` | `AttackIntervalSeconds` |

경로: `getTwoHandedSwordEffectiveCombat(..., phase3RelicIds)` → `applyToTwoHandedSwordEffective`.

### 7.4 Spear — **implemented**

| stat | maps to |
|------|---------|
| `thrustBaseDamage` | `Thrust.BaseDamage` |
| `thrustRangeStuds` | `Thrust.RangeStuds` |
| `attackIntervalSeconds` | `AttackIntervalSeconds` (weapon-wide) |

경로: `getSpearEffectiveCombat(..., phase3RelicIds)` → `applyToSpearEffective`.  
`CombatService` Spear heartbeat·VFX·판정은 `eff.Thrust.RangeStuds` / `WidthStuds` 사용 — **유물별 if 없음**.

---

## 8. Phase 3 MVP — Verified vs Not Implemented

### 8.1 Verified (playtest / dev)

| 축 | 상태 |
|----|------|
| Run relic 7종 + pool | `Phase3RelicPool` + `RelicDefinitions` |
| Phase3RelicChest kill drop | SS / Spear / TH |
| activeWeapons offer pool | round-robin, max 3 |
| Modifier SS / TH / Spear | effective + combat (DevCombat when `ShowDevCombatPanel=true`, Publish default false) |
| BuildTag `TagCounts` | DevCombat when enabled |
| ClassDetection | Guardian / Slayer / Lancer, `ambiguous` |
| DataStore `PlayerRelicProfile` | `RelicProfilePersistence` (5A) |
| Lobby craft / equip / collection UI | Step 6 + 7A |
| Result material grant | `RunResultRewardPolicy` (5B placeholder) |
| Starting loadout | equippedStartingRelicIds → phase3 seed · Definitions + Applicator |

### 8.2 Not implemented / Phase 4+ (explicit)

| 항목 |
|------|
| **blueprint discovery** (runs → `blueprintProgress`) |
| RewardBudget balancing (Result materials placeholder only) |
| `RelicShopPanel` / Rank / Relic upgrade |
| class **effect** (ClassDetection baseline only) |
| 파생 클래스 (Paladin, Impaler, …) |
| 상태이상 (burn, bleed, stun, …) |
| Golden Trident / Forked Pike / Konic's Teeth / Sawtooth Spearhead 등 **패턴 변경** 유물 |
| Attack_Amount / 다중 thrust |
| AOE relic |
| block / knockback / crit / attack skip relic (Phase3 applicator) |
| relic weight / random offer policy (round-robin deterministic) |
| `cracked_sword_tip` mechanic redesign |

---

## 9. Core Modules (Quick Reference)

| 모듈 | 경로 | 역할 |
|------|------|------|
| **Phase3RelicPool** | `Shared/Phase3RelicPool.lua` | 무기별 pool · `buildOfferChoicesForWeapons` · round-robin |
| **RelicDefinitions** | `Shared/RelicDefinitions.lua` | Run relic 7종 + migrated starting ids |
| **RelicModifierApplicator** | `Shared/RelicModifierApplicator.lua` | `applyToSwordShieldEffective` / `TwoHandedSword` / `Spear` |
| **UpgradeData** | `Shared/UpgradeData.lua` | effective 계산 후 `phase3RelicIds` applicator |
| **RelicProfileService** | `ServerScriptService/RelicProfileService.lua` | Lobby profile · craft · equip |
| **RelicProfilePersistence** | `ServerScriptService/RelicProfilePersistence.lua` | DataStore I/O |
| **ProgressionService** | `ServerScriptService/ProgressionService.lua` | `phase3ActiveRelicIds`, offer, chest filters |
| **CombatService** | `ServerScriptService/CombatService.lua` | 킬 드랍 · heartbeat (activeWeapons) · relic id 분기 **없음** |
| **RelicDropService** | `ServerScriptService/RelicDropService.lua` | `spawnPhase3RelicChestAt` |
| **BuildTagService** | `ServerScriptService/BuildTagService.lua` | snapshot → TagCounts / ClassScores |
| **ClassRuleData** | `Shared/ClassRuleData.lua` | detection 규칙만 |
| **HudSyncService** | `ServerScriptService/HudSyncService.lua` | DevCombat + BuildTag + ClassDetection |
| **WeaponTagData** | `Shared/WeaponTagData.lua` | 3무기 태그 SSOT (`effectTags` 없음) |

```text
WeaponTagData
  → RelicDefinitions / Phase3RelicPool
  → phase3ActiveRelicIds
  → RelicModifierApplicator
  → UpgradeData (SS / TH / Spear effective)
  → CombatService / HudSyncService
  → BuildTagService (+ ClassRuleData)
  → HUDClient DevCombat
```

**Parallel paths (do not merge):**

- **Starting loadout:** Lobby `EquipStartingRelicsRequest` → Teleport `equippedStartingRelicIds` → `phase3ActiveRelicIds` seed
- **Run relic:** `Phase3RelicChest` → `phase3ActiveRelicIds` → `RelicDefinitions` + applicator
- **Account:** craft → `ownedRelics` (chest does **not** unlock owned)

---

## 10. Debug Test Method

`GameConfig.Debug.Phase3TestRelicIds` → `ensureProgress` 시 `phase3ActiveRelicIds` shallow copy (**not** unlock/equip).

| `Phase3TestRelicIds` | 기대 (Normal, 업그레이드 0, 단일 무기) |
|----------------------|--------------------------------------|
| `{ "mercenarys_baldric" }` | TH Sweep dmg ×1.10 |
| `{ "shattering_light" }` | TH Sweep ×0.5, interval ×0.7 |
| `{ "last_giants_claw" }` | TH Sweep ×1.4, interval ×1.3 |
| `{ "needle_edge" }` | Spear Thrust dmg ×1.10 |
| `{ "giants_pike" }` | Spear Thrust `RangeStuds` ×2.0 (12→24) |
| `{ "run_reinforced_rim" }` | SS Sweep dmg ×1.15 |
| `{ "run_rhythm_harness" }` | SS interval ×0.90 |

절차: Rojo sync → Stage Play → weapon 선택 → config 변경 시 **재Play** → **Studio only:** `ShowDevCombatPanel = true` (Publish default **false**).

---

## 11. Next Step Candidates (not committed)

1. Phase3RelicChest **드랍률 / UX / 밸런스** 조정  
2. relic offer **random / weight** 정책 (현재 round-robin deterministic)  
3. relic **pool 추가** (triage Tier A/B, stat-only)  
4. **class effect** 설계 (detection과 분리)  
5. **blueprint discovery** + RewardBudget  
6. **RelicShop** / Rank  

---

## 12. Hard Rules Going Forward

| 규칙 | 내용 |
|------|------|
| Triage first | `docs/PHASE3_RELIC_CANDIDATE_TRIAGE.md` 후 `RelicDefinitions` 등록 |
| No per-relic combat if | `CombatService`에 `relicId ==` 분기 **금지** |
| Applicator path | stat → `RelicModifierApplicator` + `UpgradeData` effective |
| Pattern/status | Attack_Amount, multi-thrust, AOE, status — **별도 마일스톤** |
| Starting vs Run vs Account | equipped/phase3 (run) vs owned (account); chest never grants owned |
| Detection ≠ effect | ClassDetection / BuildTag ≠ 클래스 전투 배율 |
| DroppedRelic | **복구 금지** — Phase3RelicChest만 |
| RelicData / startingRelicId | **복구 금지** (removed 7C-3) |
| `src/` change | PLAN + `APPROVE_PATCH` (`.cursor/rules/01-workflow.mdc`) |

---

## 13. Phase 3 Closeout Status

**Meta progression core: COMPLETE.** DataStore profile, Lobby relic UI, craft/equip, equipped→phase3 seed, owned chest filter, Result material placeholder (5B), 7C-3 legacy removal, publish-safe `GameConfig.Debug`.

**Verification:** development playtest (no formal Publish regression suite).

**Phase 4+:** See `docs/PHASE3_RELIC_META_PROGRESSION.md` §14.

---

## Related Paths

| 용도 | 경로 |
|------|------|
| Choice / pending | `docs/CHOICE_FLOW_CURRENT_AND_PHASE3_PLAN.md` |
| Meta SSOT | `docs/PHASE3_RELIC_META_PROGRESSION.md` §0 |
| 엑셀·Tier | `docs/PHASE3_DATASET_ANALYSIS.md` |
| 후보 triage | `docs/PHASE3_RELIC_CANDIDATE_TRIAGE.md` |
| Playtest | `docs/VERIFICATION_PLAYTEST.md` |

---

## Change Log

| 날짜 | 내용 |
|------|------|
| 2026-05-27 | Phase 3 MVP 실플레이 검증 구조 고정 초안 (relic TH/Spear + BuildTag/ClassDetection). |
| 2026-05-27 | DroppedRelic legacy removed · Phase3RelicChest · 7종 pool · activeWeapons offer · SS/Spear range relic · 문서 전면 갱신. |
| 2026-05-27 | Meta Step 3: fake owned/equipped Debug · RunRelicChestPool filters · CombatService offer gate helper. |
| 2026-05-31 | Closeout docs sync — meta core complete · §8/§13 updated. |

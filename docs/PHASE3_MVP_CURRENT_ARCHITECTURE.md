# Phase 3 MVP — Current Architecture (Playtest-Verified)

**목적:** 현재까지 **구현·실플레이로 검증된** Phase 3 구조를 SSOT 문서로 고정한다.  
**범위:** 분석·설계·구현 가이드의 기준선. 이 문서만으로 게임 동작이 바뀌지 않는다.

| 항목 | 값 |
|------|-----|
| 문서 경로 | `docs/PHASE3_MVP_CURRENT_ARCHITECTURE.md` |
| 코드 정본 | `src/` + `default.project.json` |
| 선행 문서 | `docs/PHASE3_DATASET_ANALYSIS.md`, `docs/PHASE3_RELIC_CANDIDATE_TRIAGE.md`, `docs/CHOICE_FLOW_CURRENT_AND_PHASE3_PLAN.md` |
| 최종 갱신 기준 | **8종 Run relic** · Block/Knockback generic mechanic (**Studio §3b/§3c verified**) · meta/chest/Starting · BuildTag/ClassDetection |
| Mechanic routing | `docs/RELIC_MECHANIC_ROUTING.md` |

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
| 전투 (attack stats) | `RelicModifierApplicator` → `UpgradeData` effective (SS / TH / Spear) |
| 전투 (contact block) | `BlockChanceResolver` → player attributes → `PlayerContactDamageService` |
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

## 5. Phase3RelicPool — Current (8 relics)

| weaponId | relicId (순서) | 종수 |
|----------|----------------|------|
| **SwordShield** | `run_reinforced_rim`, `run_rhythm_harness`, `run_shield_spike` | 3 |
| **TwoHandedSword** | `mercenarys_baldric`, `shattering_light`, `last_giants_claw` | 3 |
| **Spear** | `needle_edge`, `giants_pike` | 2 |
| **BasicMagic** | *(empty)* | 0 |

**총 8종** (`Phase3RelicPool.lua` `POOL_BY_WEAPON_ID`).

---

## 6. RelicDefinitions — Run Relic Summary

| relicId | scope | targetTags | stat modifier(s) |
|---------|-------|------------|------------------|
| `run_reinforced_rim` | SwordShield | `block` | `blockChance` **openOrAdd** (0→5%, else +10%p) — **첫 blockChance sample** |
| `run_rhythm_harness` | SwordShield | `ss` (weapon-wide) | `attackIntervalSeconds` ×0.90 |
| `run_shield_spike` | SwordShield | `ss` + `sweep` | `knockbackPower` +60 — **첫 knockbackPower sample** |
| `mercenarys_baldric` | TwoHandedSword | `th` + `sweep` | `sweepBaseDamage` ×1.10 |
| `shattering_light` | TwoHandedSword | `th` + `sweep` | `sweepBaseDamage` ×0.5, `attackIntervalSeconds` ×0.7 |
| `last_giants_claw` | TwoHandedSword | `th` + `sweep` | `sweepBaseDamage` ×1.4, `attackIntervalSeconds` ×1.3 |
| `needle_edge` | Spear | `sp` + `thrust` | `thrustBaseDamage` ×1.10 |
| `giants_pike` | Spear | `sp` + `thrust` | `thrustRangeStuds` ×2.0 → `Thrust.RangeStuds` |

`giants_pike`: upgrade 적용 **후** `RangeStuds`에 ×2.0 후적용 (snapshot 없음). 기본 Spear thrust range 12 stud → ×2.0 시 **24** (업그레이드 0 기준).

**Schema enum (`ALLOWED_STATS`):** `sweepBaseDamage`, `thrustBaseDamage`, `thrustRangeStuds`, `attackIntervalSeconds`, `blockChance`, `knockbackPower`, `attackHitCount` — attack-bound은 §8 applicator; `blockChance`는 §7.6 resolver.

**Operations:** `add`, `mul`, `openOrAdd` (`openOrAdd` = **blockChance only**, validate in `RelicDefinitions`).

---

## 7. Generic relic mechanics (Block · Knockback)

**Routing SSOT:** `docs/RELIC_MECHANIC_ROUTING.md`.

### 7.0 Hard rule — no per-relic id in runtime combat

| 모듈 | 금지 | 읽는 것 |
|------|------|---------|
| `CombatService` | `relicId ==` | `effective` stats (e.g. `Sweep.KnockbackPower`) |
| `PlayerContactDamageService` | `relicId ==` | `blockCapable`, `effectiveBlockChance`, cooldown attributes |
| `BlockChanceResolver` | `relicId ==` | all `phase3ActiveRelicIds` → `RelicDefinitions` modifiers only |
| `ProgressionService` (combat) | per-relic combat branches | resolver/applicator outputs → attributes |

샘플 id(`run_reinforced_rim`, `run_shield_spike`)는 **데이터 행 이름**이지 런타임 특수분기 키가 아니다.

### 7.5 Knockback (SS Sweep — Studio §3c verified)

```text
RelicDefinitions (knockbackPower)
  → RelicModifierApplicator (ss + sweep)
  → UpgradeData.getSwordShieldEffectiveCombat → Sweep.KnockbackPower (default 0)
  → CombatService SwordShield Sweep hit (Power > 0)
  → knockbackUntil + AssemblyLinearVelocity
  → EnemyService (knockbackUntil guard; no relic awareness)
```

| 항목 | 값 / 범위 |
|------|-----------|
| 첫 sample | `run_shield_spike` — add **60** |
| MVP scope | **SS Sweep only**; Thrust / TH / Spear / BasicMagic 없음 |
| Duration | `GameConfig.KnockbackCombat.DefaultDurationSeconds` = **0.20** |
| Kill hit | 생존 적만 넉백 (처치 타격 스킵) |

### 7.6 Block contact (Studio §3b verified)

```text
RelicDefinitions (blockChance: add / mul / openOrAdd)
  → BlockChanceResolver (pass1 add/mul, pass2 openOrAdd)
  → ProgressionService.syncBlockDefenseAttributes
  → attributes: blockCapable, effectiveBlockChance
  → PlayerContactDamageService (contact tick)
```

| 항목 | 값 / 범위 |
|------|-----------|
| 첫 sample | `run_reinforced_rim` — openOrAdd open **0.05**, add **0.10** |
| Base | `GameConfig.BlockDefense.BaseBlockChance` = **0** |
| Cooldown | `BlockCooldownSeconds` = **3** |
| Rim 전용 GameConfig key | **없음** (제거됨) |
| Applicator `blockChance` | **런타임 미적용** (resolver only) |

**기대 chance (Studio §3b):** no relic **0%** · Rim only **5%** · existing 5% + Rim **15%**.

---

## 8. RelicModifierApplicator — Supported Stats (by weapon)

코드: `STAT_FIELD_*` + `applyTo*Effective` (2026-05 기준). Block/Knockback mechanics: §7.

### 8.1 Common (정의·스키마)

| stat | 비고 |
|------|------|
| `attackIntervalSeconds` | 무기별 mapping (`thrust=false` 또는 SS weapon-wide) |
| `attackHitCount` | `ALLOWED_STATS`에만 존재 — **applicator 미연결** |
| `blockChance` | **BlockChanceResolver only** (Applicator skips); contact → `PlayerContactDamageService` |
| `knockbackPower` | attack-bound (SS `Sweep.KnockbackPower`); see §7.5 |

### 8.2 SwordShield — **implemented**

| stat | maps to |
|------|---------|
| `sweepBaseDamage` | `Sweep.BaseDamage` |
| `thrustBaseDamage` | `Thrust.BaseDamage` |
| `attackIntervalSeconds` | `AttackIntervalSeconds` (weapon-wide, `attackTag` 생략) |
| `knockbackPower` | `Sweep.KnockbackPower` (`attackTag` = sweep) |

경로: `getSwordShieldEffectiveCombat(..., phase3RelicIds)` → `applyToSwordShieldEffective`.  
Block: §7.6 (`BlockChanceResolver` — **not** applicator `BlockChance`). Knockback: §7.5.

### 8.3 TwoHandedSword — **implemented**

| stat | maps to |
|------|---------|
| `sweepBaseDamage` | `Sweep.BaseDamage` |
| `attackIntervalSeconds` | `AttackIntervalSeconds` |

경로: `getTwoHandedSwordEffectiveCombat(..., phase3RelicIds)` → `applyToTwoHandedSwordEffective`.

### 8.4 Spear — **implemented**

| stat | maps to |
|------|---------|
| `thrustBaseDamage` | `Thrust.BaseDamage` |
| `thrustRangeStuds` | `Thrust.RangeStuds` |
| `attackIntervalSeconds` | `AttackIntervalSeconds` (weapon-wide) |

경로: `getSpearEffectiveCombat(..., phase3RelicIds)` → `applyToSpearEffective`.  
`CombatService` Spear heartbeat·VFX·판정은 `eff.Thrust.RangeStuds` / `WidthStuds` 사용 — **유물별 if 없음**.

---

## 9. Phase 3 MVP — Verified vs Not Implemented

### 9.1 Verified (playtest / dev)

| 축 | 상태 |
|----|------|
| Run relic **8종** + pool | `Phase3RelicPool` + `RelicDefinitions` (SS 3 incl. spike) |
| **Block** contact MVP | `BlockChanceResolver` → attributes → `PlayerContactDamageService` (**Studio §3b**) |
| **Knockback** SS Sweep | `knockbackPower` → effective → `CombatService` (**Studio §3c**) |
| Blueprint / RewardBudget / Class effect | **회귀 없음** (Block/Knockback 검증 시 확인) |
| Phase3RelicChest kill drop | SS / Spear / TH |
| activeWeapons offer pool | round-robin, max 3 |
| Modifier SS / TH / Spear | effective + combat (DevCombat when `ShowDevCombatPanel=true`, Publish default false) |
| BuildTag `TagCounts` | DevCombat when enabled |
| ClassDetection | Guardian / Slayer / Lancer, `ambiguous` |
| DataStore `PlayerRelicProfile` | `RelicProfilePersistence` (5A) |
| Lobby craft / equip / collection UI | Step 6 + 7A |
| Result material grant | `RunResultRewardPolicy` (5B placeholder) |
| Starting loadout | equippedStartingRelicIds → phase3 seed · Definitions + Applicator |

### 9.2 Not implemented / Phase 4+ (explicit)

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
| TH / Spear **knockback** (SS Sweep only today) |
| crit / attack skip relic |
| `attackHitCount` / multi-hit runtime |
| block **onBlockSuccess** trigger · knockback VFX/UI |
| relic weight / random offer policy (round-robin deterministic) |
| `cracked_sword_tip` mechanic redesign |

---

## 10. Core Modules (Quick Reference)

| 모듈 | 경로 | 역할 |
|------|------|------|
| **Phase3RelicPool** | `Shared/Phase3RelicPool.lua` | 무기별 pool · `buildOfferChoicesForWeapons` · round-robin |
| **RelicDefinitions** | `Shared/RelicDefinitions.lua` | Run relic **8종** + migrated starting ids |
| **BlockChanceResolver** | `Shared/BlockChanceResolver.lua` | `blockChance` modifiers → effective chance (no relicId branches) |
| **RelicModifierApplicator** | `Shared/RelicModifierApplicator.lua` | attack effective; **skips** `blockChance` |
| **PlayerContactDamageService** | `ServerScriptService/PlayerContactDamageService.lua` | contact damage + block roll (attributes only) |
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
- **Run relic (attack stats):** `phase3ActiveRelicIds` → Applicator → `UpgradeData` effective → `CombatService`
- **Run relic (contact block):** `phase3ActiveRelicIds` → `BlockChanceResolver` → attributes → `PlayerContactDamageService`
- **Account:** craft → `ownedRelics` (chest does **not** unlock owned)

---

## 11. Debug Test Method

`GameConfig.Debug.Phase3TestRelicIds` → `ensureProgress` 시 `phase3ActiveRelicIds` shallow copy (**not** unlock/equip).

| `Phase3TestRelicIds` | 기대 (Normal, 업그레이드 0, 단일 무기) |
|----------------------|--------------------------------------|
| `{ "mercenarys_baldric" }` | TH Sweep dmg ×1.10 |
| `{ "shattering_light" }` | TH Sweep ×0.5, interval ×0.7 |
| `{ "last_giants_claw" }` | TH Sweep ×1.4, interval ×1.3 |
| `{ "needle_edge" }` | Spear Thrust dmg ×1.10 |
| `{ "giants_pike" }` | Spear Thrust `RangeStuds` ×2.0 (12→24) |
| `{ "run_reinforced_rim" }` | 0% → **5%** entry (DevCombat `BlockDefense`; openOrAdd) |
| `{ "run_shield_spike" }` | `Sweep.KnockbackPower` **60**; Sweep hit knockback |
| `{ "run_rhythm_harness" }` | SS interval ×0.90 |

절차: Rojo sync → Stage Play → weapon 선택 → config 변경 시 **재Play** → **Studio only:** `ShowDevCombatPanel = true` (Publish default **false**).

---

## 12. Next Step Candidates (not committed)

1. Phase3RelicChest **드랍률 / UX / 밸런스** 조정  
2. relic offer **random / weight** 정책 (현재 round-robin deterministic)  
3. relic **pool 추가** (triage Tier A/B, stat-only)  
4. **class effect** 설계 (detection과 분리)  
5. **blueprint discovery** + RewardBudget  
6. **RelicShop** / Rank  

---

## 13. Hard Rules Going Forward

| 규칙 | 내용 |
|------|------|
| Triage first | `docs/PHASE3_RELIC_CANDIDATE_TRIAGE.md` 후 `RelicDefinitions` 등록 |
| No per-relic combat if | `CombatService`, `PlayerContactDamageService`, `BlockChanceResolver`에 `relicId ==` **금지** |
| Attack-bound stat | `RelicModifierApplicator` + `UpgradeData` effective → `CombatService` |
| Contact block stat | `blockChance` → **`BlockChanceResolver`** only (not applicator runtime) |
| Knockback stat | `knockbackPower` → effective → generic CombatService read |
| Pattern/status | Attack_Amount, multi-thrust, AOE, status — **별도 마일스톤** |
| Starting vs Run vs Account | equipped/phase3 (run) vs owned (account); chest never grants owned |
| Detection ≠ effect | ClassDetection / BuildTag ≠ 클래스 전투 배율 |
| DroppedRelic | **복구 금지** — Phase3RelicChest만 |
| RelicData / startingRelicId | **복구 금지** (removed 7C-3) |
| `src/` change | PLAN + `APPROVE_PATCH` (`.cursor/rules/01-workflow.mdc`) |

---

## 14. Phase 3 Closeout Status

**Meta progression core: COMPLETE.** DataStore profile, Lobby relic UI, craft/equip, equipped→phase3 seed, owned chest filter, Result material placeholder (5B), 7C-3 legacy removal, publish-safe `GameConfig.Debug`.

**Verification:** development playtest; **Block §3b · Knockback §3c · Blueprint/RewardBudget/Class 회귀** Studio confirmed (see `docs/VERIFICATION_PLAYTEST.md`). No formal Publish regression suite.

**Phase 4+:** See `docs/PHASE3_RELIC_META_PROGRESSION.md` §14.

---

## Related Paths

| 용도 | 경로 |
|------|------|
| Choice / pending | `docs/CHOICE_FLOW_CURRENT_AND_PHASE3_PLAN.md` |
| Meta SSOT | `docs/PHASE3_RELIC_META_PROGRESSION.md` §0 |
| 엑셀·Tier | `docs/PHASE3_DATASET_ANALYSIS.md` |
| 후보 triage | `docs/PHASE3_RELIC_CANDIDATE_TRIAGE.md` |
| Playtest | `docs/VERIFICATION_PLAYTEST.md` (§3b Block, §3c Knockback) |
| Mechanic routing | `docs/RELIC_MECHANIC_ROUTING.md` |

---

## Change Log

| 날짜 | 내용 |
|------|------|
| 2026-05-27 | Phase 3 MVP 실플레이 검증 구조 고정 초안 (relic TH/Spear + BuildTag/ClassDetection). |
| 2026-05-27 | DroppedRelic legacy removed · Phase3RelicChest · 7종 pool · activeWeapons offer · SS/Spear range relic · 문서 전면 갱신. |
| 2026-05-27 | Meta Step 3: fake owned/equipped Debug · RunRelicChestPool filters · CombatService offer gate helper. |
| 2026-05-31 | Closeout docs sync — meta core complete · §8/§13 updated. |
| 2026-05-31 | **8종 pool** (`run_shield_spike`) · generic Block/Knockback pipelines · Studio §3b/§3c verified · `RELIC_MECHANIC_ROUTING.md` |

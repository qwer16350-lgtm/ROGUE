# Relic mechanic routing (Phase 3 SSOT)

**목적:** `RelicDefinitions` modifier가 **어느 레이어에서 집계**되고 **어디서 소비**되는지 한 페이지로 고정한다.  
**코드 정본:** `src/ReplicatedStorage/Shared/` + `ServerScriptService/`.  
**상세 아키텍처:** `docs/PHASE3_MVP_CURRENT_ARCHITECTURE.md` §7·§9.

**원칙:** `CombatService`, `PlayerContactDamageService`, `BlockChanceResolver`는 **`relicId`를 직접 검사하지 않는다.** 샘플 relic id(`run_reinforced_rim`, `run_shield_spike`)는 데이터 행 이름일 뿐이다.

---

## Routing table

| stat / mechanic | RelicDefinitions | 집계 | sink | 소비 (서버) |
|-----------------|------------------|------|------|-------------|
| `sweepBaseDamage`, `thrustBaseDamage`, `attackIntervalSeconds`, `thrustRangeStuds` | modifier `add`/`mul` | `RelicModifierApplicator` | `UpgradeData` → `effective.*` | `CombatService` heartbeat |
| `knockbackPower` | modifier `add`/`mul` + `targetTags` | `RelicModifierApplicator` | `effective.Sweep.KnockbackPower` (SS MVP) | `CombatService` — Power > 0 시 generic knockback |
| `blockChance` | modifier `add`/`mul`/`openOrAdd` | **`BlockChanceResolver`** (Applicator **미사용**) | `blockCapable`, `effectiveBlockChance` attributes | `PlayerContactDamageService` contact tick |
| `attackHitCount` | (enum only) | *미연결* | — | Phase 4+ |

---

## Pipelines (verified Studio §3b / §3c)

### Block (contact damage)

```text
RelicDefinitions (stat=blockChance)
  → BlockChanceResolver (pass1 add/mul, pass2 openOrAdd; no relicId branches)
  → ProgressionService.syncBlockDefenseAttributes
  → player attributes
  → PlayerContactDamageService
```

**첫 sample:** `run_reinforced_rim` — `openOrAdd` openValue 0.05, addValue 0.10.  
**Config:** `GameConfig.BlockDefense.BaseBlockChance = 0`, `BlockCooldownSeconds = 3` (Rim 전용 config key 없음).

### Knockback (attack-bound, SS Sweep MVP)

```text
RelicDefinitions (stat=knockbackPower, ss+sweep)
  → RelicModifierApplicator
  → UpgradeData.getSwordShieldEffectiveCombat
  → effective.Sweep.KnockbackPower
  → CombatService (Sweep hit only; no relicId read)
  → entry.state.knockbackUntil + AssemblyLinearVelocity
  → EnemyService (knockbackUntil guard only)
```

**첫 sample:** `run_shield_spike` — `knockbackPower` add 60.  
**Config:** `GameConfig.KnockbackCombat.DefaultDurationSeconds = 0.20`.

---

## Operations (`RelicDefinitions.ALLOWED_OPERATIONS`)

| operation | 허용 stat (현재) | 집계 위치 |
|-----------|------------------|-----------|
| `add`, `mul` | numeric stats + `blockChance` | Applicator 또는 BlockChanceResolver pass1 |
| `openOrAdd` | **`blockChance` only** | BlockChanceResolver pass2 |

---

## 신규 relic 추가 절차 (요약)

1. Triage → `RelicDefinitions` row + modifier (`targetTags`, `stat`, `operation`).
2. 위 표에서 **집계·sink** 결정 (Applicator vs Resolver vs future trigger).
3. 소비측에 **generic read**만 추가 (stat threshold / attribute); **`relicId ==` 금지**.
4. `docs/VERIFICATION_PLAYTEST.md` 체크리스트 섹션 추가.
5. grep: `relicId ==` in `CombatService`, `PlayerContactDamageService`, `BlockChanceResolver`.

---

## Related

| 문서 | 용도 |
|------|------|
| `docs/PHASE3_MVP_CURRENT_ARCHITECTURE.md` | Pool, modules, Verified |
| `docs/VERIFICATION_PLAYTEST.md` | §3b Block, §3c Knockback |
| `docs/PHASE3_RELIC_SSOT_GAPS.md` | Excel row gap log |

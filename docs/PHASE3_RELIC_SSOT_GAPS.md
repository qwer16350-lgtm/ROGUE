# Phase 3 relic — Excel SSOT gap log

정본: `docs/data/데이터셋_v20_RL_TAGS_드롭다운_실제복구_v2.xlsx` 시트 `RL.TAGS`.

## Resolved (Block MVP)

| sourceRow | Excel name | relicId | 이전 구현 | 현재 |
|-----------|------------|---------|-----------|------|
| 13 | Reinforced Shield Rim | `run_reinforced_rim` | `sweepBaseDamage` ×1.15 | `blockChance` **openOrAdd** (generic `BlockChanceResolver`); first blockChance sample |

- **id 유지:** `run_reinforced_rim` (Phase3 pool / blueprint / ownedRelics migration 없음).
- **범위:** enemy contact damage 1경로만; parry / armor stat 미포함 (Shield Spike는 knockback — 별도 Resolved).
- **정책:** 기본 BlockChance **0%**; Rim 0%→5% 진입 또는 기존 chance +10%p. SS/무기 런 한정 없음.

## Resolved (Knockback MVP)

| sourceRow | Excel name | relicId | 구현 |
|-----------|------------|---------|------|
| 18 | Shield Spike | `run_shield_spike` | `knockbackPower` add 60 → `effective.Sweep.KnockbackPower`; CombatService generic stat read |

- **generic:** CombatService는 relic id 검사 없음; TH/Spear knockback·Boss 감쇠·VFX 미포함.

## Open (deferred)

| sourceRow | Excel name | 비고 |
|-----------|------------|------|
| 14 | Konic's teeth | spawn / deferred mechanic |

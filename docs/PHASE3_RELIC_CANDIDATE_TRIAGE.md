# Phase 3 Relic Candidate Triage (RL.TAGS v20)

엑셀 **`데이터셋_v20_RL_TAGS_드롭다운_실제복구_v2.xlsx`** 의 **RL.TAGS**·**CLASS** 시트를 read-only로 분석해, Phase 3 MVP(구현 3무기 · Guardian/Slayer/Lancer)와 연관된 **`O` 유물 후보**를 선별·Tier 분류한 문서다.

| 항목 | 값 |
|------|-----|
| 입력 | `RL.TAGS`, `CLASS` (v20) |
| 선행 문서 | `docs/PHASE3_DATASET_ANALYSIS.md` |
| RL.TAGS `O` 전체 | 175 |
| **본 문서 필터 통과** | **61** |
| 코드 수정 | **없음** |

**원칙:** 유물 이름·효과·태그는 **엑셀 값만** 인용한다. 기능 창작·구현 코드·`RelicDefinitions` 생성은 하지 않는다.

---

## 산출 요약 (요청 형식)

| # | 항목 | 내용 |
|---|------|------|
| 1 | 생성 문서 경로 | `docs/PHASE3_RELIC_CANDIDATE_TRIAGE.md` |
| 2 | 분석 대상 필터 기준 | §2 |
| 3 | Guardian / Slayer / Lancer 관련 후보 수 | **classTags 직접 일치 16** · 필터 전체 **61** |
| 4 | Tier A~E 분포 | A=7, B=8, C=0, D=41, E=5 |
| 5 | High 우선순위 후보 | §6 (2건) |
| 6 | Hold 후보와 보류 이유 | §7 (46건, Tier D/E·트리거·상태이상) |
| 7 | Phase 3 MVP 첫 구현 추천군 | §8 |
| 8 | 코드 수정 여부 | **없음** |

---

## 1. CLASS ↔ 3무기 매핑 (엑셀 기준)

| weaponTag | 기초직군 (CLASS) | 구현 weaponId |
|-----------|------------------|---------------|
| `ss` | Guardian | SwordShield |
| `th` | Slayer | TwoHandedSword |
| `sp` | Lancer | Spear |

---

## 2. 분석 대상 필터 기준

**포함:** `검수 = O` (△ 제외)

**OR 조건 (하나라도 만족):**

1. `classTags` ∈ {`Guardian`, `Slayer`, `Lancer`}
2. `effectTargetTags` 토큰이 다음 중 하나와 매칭 (콤마/슬래시 분리, 대소문자 무시)  
   `ss`, `th`, `sp`, `sweep`, `thrust`, `melee`, `close`, `mid`, `normal`, `slow`, `block`
3. `classTags = Melee` 이고 `effectTargetTags`에 `melee` 포함

**제외:**

- `검수 ≠ O`
- Range/Magic 전용(`bo`, `fi`, `shot`만 등)이며 3무기 태그와 무교차인 행

**Tier·MVP 우선순위:** §3 규칙 + `modifierTags` / `triggerTags` / `유물군` / 엑셀 **효과** 문구(조건부 스택·Block 연계 등).

---

## 3. Tier A~E 분류 규칙 (본 triage 적용)

| Tier | 기준 (요약) | MVP 우선순위 경향 |
|------|-------------|-------------------|
| **A** | Damage / Cooldown / Defense 등 단순 modifier, `trigger` 비어 있음, `RelicData`·`UpgradeData` 배율로 표현 가능 | High (미구현) / Medium (`RelicData`已有) |
| **B** | 3무기 `weaponTag`·`attackTag`·`block` 조건, Attack_Amount/Range/AOE/Block_chance 등, 상태이상 시스템 불필요 | Medium |
| **C** | BuildTag·class detection 위주, 전투 훅 최소 (`GrantsTags` 등) | Low — **필터 61건 중 0건** |
| **D** | `Status_Add`, `on_hit`/`passive`/`on_damaged`, Block 연계·스택·ArmorBreak/Bleed 등 | **Hold** |
| **E** | 미구현 weaponTag(`ax`,`bo`…), `Change`/`Effect_Change`, 검기·패턴 교체 등 | **Hold** |

**MVP 우선순위 라벨**

| 라벨 | 의미 |
|------|------|
| **High** | Tier A, 레포 `RelicData`에 **아직 없음**, 3직군 직접 태그 |
| **Medium** | Tier A/B, 이미 `RelicData` 동형 또는 2차 확장 |
| **Low** | Tier A 상충 설계(중복 행), Tier B 후순위 |
| **Hold** | Tier D/E 또는 트리거·상태이상·미구현 무기 의존 |

---

## 4. Guardian / Slayer / Lancer 관련 후보 수

| 집계 | 건수 | 설명 |
|------|------|------|
| `classTags` = Guardian | 6 | #11,12,13,19,29,31 |
| `classTags` = Slayer | 5 | #6,7,8,9,50 |
| `classTags` = Lancer | 5 | #14,15,17,27,53 |
| **소계 (3직군 직접)** | **16** | §5 표 "핵심 16" |
| 필터 OR 전체 | **61** | 파생직군(Paladin·Impaler…) + `sweep`/`thrust`/`block` 타깃 포함 |

---

## 5. Tier A~E 분포

| Tier | 건수 | 비율(61 기준) |
|------|------|---------------|
| A | 7 | 11% |
| B | 8 | 13% |
| C | 0 | — |
| D | 41 | 67% |
| E | 5 | 8% |

**MVP 우선순위 분포:** High=2 · Medium=13 · Low=1 · Hold=46

**해석:** 필터를 넓히면 `Status_Add`·`on_hit`·`passive` 유물이 다수 포함되어 **Tier D가 과반**이다. MVP 1차는 **§5.1 핵심 16** 중 Tier A/B만 추려도 충분하다.

### 5.1 핵심 16 (classTags = Guardian / Slayer / Lancer)

| 번호 | 유물명 | classTags | effectTarget | modifier | trigger | Tier | MVP |
|------|--------|-----------|--------------|----------|---------|------|-----|
| 6 | Roid Rage | Slayer | th | Attack_Amount | | B | Medium |
| 7 | TwoHandedSword | Slayer | th | Damage / Cooldown | | A | High |
| 8 | TwoHandedSword | Slayer | th | Damage / Cooldown | | A | Low |
| 9 | mercenary's baldric | Slayer | th | Damage | | A | High |
| 11 | Rhythm Strap | Guardian | ss | cooldown | | A | Medium |
| 12 | Cracked Sword Tip | Guardian | ss | Crit_Chance / block | | D | Hold |
| 13 | Reinforced Shield Rim | Guardian | block | Block_chance | | B | Medium |
| 14 | Konic's teeth | Lancer | sp | Attack_Range | | B | Medium |
| 15 | Golden Trident | Lancer | sp | Attack_Amount | | B | Medium |
| 17 | Sawtooth Spearhead | Lancer | sp | AOE | | B | Medium |
| 19 | Knight's Belt | Guardian | ss | Cooldown | | A | Medium |
| 27 | Needle Edge | Lancer | Thrust | Damage | | A | Medium |
| 29 | Old Shield Emblem | Guardian | block | Damage | | A | Medium |
| 31 | Guardrail Emblem | Guardian | block, thrust | Critical / Attack_Skip | passive | D | Hold |
| 50 | Sunder Wedge | Slayer | th, sweep, armorbreak | Status_Add | on_hit | D | Hold |
| 53 | Forked Pike | Lancer | sp, thrust | Attack_Amount / Tradeoff | passive | B | Medium |

**엑셀 효과 (핵심 16, 발췌):**

| 번호 | 효과 (엑셀原文) |
|------|----------------|
| 6 | TwohadedSword 가 보유 무기중 쿨타임이 제일 긴 경우 Sweep(slash) +1타 추가 |
| 7 | TwoHandedSword Sweep 공격 대미지 50%감소 … AttackCooldown 30% 감소 |
| 8 | TwoHandedSword AttackCooldown 30% 증가 … Sweep 공격 대미지 40%증가 |
| 9 | Sweep 계열 가중치 증가 / Sweep 피해 ×1.10 |
| 11 | 공격 템포 강화 유물 |
| 12 | Block 후 다음 Thrust critical |
| 13 | Block 확률 증가 |
| 19 | 쿨다운 계열 가중치 증가 / 공격 간격 ×0.80 |
| 27 | Thrust 계열 가중치 증가 / Thrust 피해 ×1.10 |
| 29 | Sweep 계열 가중치 증가 / Sweep 피해 ×1.10 |
| 31 | Block 성공 후 다음 Thrust가 Critical … 다음 Sweep 1회를 생략 |
| 50 | Sweep 적중 시 ArmorBreak 10% 확률 … |
| 53 | Thrust가 두 갈래로 공격, 각 Thrust 피해 40% 저하 |

### 5.2 레포 `RelicData.lua`와 대응 (기구현, 분석만)

| 엑셀 유물명 | 번호 | relicId (코드) | triage Tier | 비고 |
|-------------|------|----------------|-------------|------|
| Old Shield Emblem | 29 | `old_shield_emblem` | A | Sweep ×1.10 — 코드와 동형 |
| Cracked Sword Tip | 12 | `cracked_sword_tip` | D | 코드는 Thrust ×1.10; 엑셀은 Block 후 Crit |
| Knight's Belt | 19 | `knights_belt` | A | AttackInterval ×0.80 |
| Reinforced Shield Rim | 13 | `reinforced_shield_rim` | B | Sweep ×1.15 |
| Needle Edge | 27 | `needle_edge` | A | Thrust ×1.10 |
| Rhythm Strap | 11 | `rhythm_strap` | A | AttackInterval ×0.90 |
| Shield Spike | 18 | `shield_spike` | B | Paladin/ss; 넉백 Effect 부분 구현 |

---

## 6. High 우선순위 후보 목록

| 번호 | 유물명 | classTags | modifier | Tier | 판정 이유 |
|------|--------|-----------|----------|------|-----------|
| **7** | TwoHandedSword | Slayer | Damage / Cooldown | A | `th` 전용, trigger 없음, 데미지↓+쿨↓ 트레이드오프 — `RelicData` 미등록 |
| **9** | mercenary's baldric | Slayer | Damage | A | `th` Sweep ×1.10 — `RelicData` 미등록, #9와 동형 패턴 |

---

## 7. Hold 후보와 보류 이유

**Hold = 46건** (Tier D 41 + Tier E 5, 일부 Tier A는 Low로만 완화)

| 보류 유형 | 대표 번호 | 엑셀 근거 (요약) |
|-----------|-----------|------------------|
| **상태이상·Status_Add** | 50, 46, 48, 55, 60, 141, 142, 173… | `modifierTags=Status_Add`, effect에 armorbreak/bleed/paralyze/stun 등 |
| **trigger 필수** | 32, 46, 49, 51, 158… | `on_hit`, `on_damaged`, `passive`, `on_low_hp` |
| **Block·공격 스킵 연계** | 12, 31, 45 | Block 성공 후 Thrust crit / Sweep skip |
| **미구현 무기·Change** | 10, 25, 47, 135, 159 | `Change`, `Effect_Change`, `ax`/`bo`, Riftcleaver/Oathbreaker |
| **Melee 계열 타이머** | 4, 5 | 피격 전 5초마다 스택 — modifier만으로는 부족 |

**Tier E Hold (5):** #10 Aura Blade, #25 Hanji's Katana, #47 Nibbling Evil Sword, #135 Arioch's Deception, #159 Revenant's Arsenal

---

## 8. Phase 3 MVP에 추천하는 첫 구현 후보군

**목적:** `RelicDefinitions` schema 도입 시 **사용자가 고를 수 있는** 좁은 후보 풀(분석 추천, 구현 확정 아님).

### 8.1 1차 — Tier A/B · 3직군 · RelicData 미등록

| 순위 | 번호 | 유물명 | 이유 |
|------|------|--------|------|
| 1 | 9 | mercenary's baldric | High; Slayer/th Damage — TH sweep 배율, 패턴 단순 |
| 2 | 7 | TwoHandedSword | High; Slayer/th Damage+Cooldown (엑셀 #8과 택1) |
| 3 | 6 | Roid Rage | Medium; Attack_Amount + 조건부 +1타 (쿨타임 비교 분기) |
| 4 | 15 | Golden Trident | Medium; Lancer/sp Attack_Amount (세갈래 thrust) |
| 5 | 13 | Reinforced Shield Rim | Medium; Block_chance — SS block 확장 |

### 8.2 2차 — 이미 `RelicData` 있음 → schema 이전·정합 검증

`old_shield_emblem`, `cracked_sword_tip`, `knights_belt`, `needle_edge`, `rhythm_strap`, `reinforced_shield_rim`, `shield_spike` — **신규 기능보다 RelicDefinitions 이관·엑셀 정합(#12 Cracked Sword Tip 갭)** 우선.

### 8.3 명시적 보류 (1차 제외)

- **전부 Tier D/E·Hold (§7)**
- **#8** TwoHandedSword (상충 옵션, #7과 중복 설계)
- **#12, #31** Block 연계 Crit/Skip
- **#50** Sunder Wedge (ArmorBreak + on_hit)

---

## 9. 전체 후보 목록 (필터 61건)

ObtainTags / UnlockTags / Required Materials / ClassTag Match는 표 간략화(엑셀原値는 WP 참고). **효과** 전문은 엑셀 RL.TAGS 행 기준.

| 번호 | 유물명 | 유물군 | classTags | effectTarget | modifier | trigger | stack | 3무기 관련 | Tier | MVP | 판정 이유 |
|------|--------|--------|-----------|--------------|----------|---------|-------|------------|------|-----|-----------|
| 4 | Knight's Oath | Type-based relic (계열 유물) | Melee | melee | Defense | | Stackable | effectTarget: melee → 3무기 melee 계열 | D | Hold | 피격 전 5초마다 방어 스택 — 전투 상태·타이머 필요 |
| 5 | Dead Wrath | Type-based relic (계열 유물) | Melee | melee | Damage | | Stackable | effectTarget: melee → 3무기 melee 계열 | D | Hold | 피격 전 5초마다 데미지 스택 — 전투 상태·타이머 필요 |
| 6 | Roid Rage | Weapon-based relic (무기 유물) | Slayer | th | Attack_Amount | | Unique | TwoHandedSword (th) / Slayer; effectTarget: th → TwoHandedSword | B | Medium | 3무기 한정 수치/타수/범위 |
| 7 | TwoHandedSword | Weapon-based relic (무기 유물) | Slayer | th | Damage / Cooldown | | Stackable | TwoHandedSword (th) / Slayer; effectTarget: th → TwoHandedSword | A | High | Damage/Cooldown, th, trigger 없음 |
| 8 | TwoHandedSword | Weapon-based relic (무기 유물) | Slayer | th | Damage / Cooldown | | Stackable | TwoHandedSword (th) / Slayer; effectTarget: th → TwoHandedSword | A | Low | Damage/Cooldown, th, trigger 없음 (상충 옵션) |
| 9 | mercenary's baldric | Weapon-based relic (무기 유물) | Slayer | th | Damage | | Upgradeable | TwoHandedSword (th) / Slayer; effectTarget: th → TwoHandedSword | A | High | Damage sweep ×1.10, th |
| 10 | Aura Blade | Weapon-based relic (무기 유물) | Riftcleaver | th | Change | | Unique | effectTarget: th → TwoHandedSword | E | Hold | Change/복합/미구현 계열 |
| 11 | Rhythm Strap | Weapon-based relic (무기 유물) | Guardian | ss | cooldown | | Unique | SwordShield (ss) / Guardian; effectTarget: ss → SwordShield | A | Medium | cooldown modifier, trigger 없음; RelicData AttackIntervalMul 동형 |
| 12 | Cracked Sword Tip | Weapon-based relic (무기 유물) | Guardian | ss | Crit_Chance / block | | Unique | SwordShield (ss) / Guardian; effectTarget: ss → SwordShield | D | Hold | Block 후 Thrust crit — Block 성공·공격 스킵 연계 필요 |
| 13 | Reinforced Shield Rim | Weapon-based relic (무기 유물) | Guardian | block | Block_chance | | Stackable | SwordShield (ss) / Guardian; effectTarget: block → SwordShield 방패 | B | Medium | Block_chance — SS block 로직 확장 |
| 14 | Konic's teeth | Weapon-based relic (무기 유물) | Lancer | sp | Attack_Range | | Unique | Spear (sp) / Lancer; effectTarget: sp → Spear | B | Medium | 3무기 한정 수치/타수/범위 |
| 15 | Golden Trident | Weapon-based relic (무기 유물) | Lancer | sp | Attack_Amount | | Unique | Spear (sp) / Lancer; effectTarget: sp → Spear | B | Medium | 3무기 한정 수치/타수/범위 |
| 16 | Giant's pike | Weapon-based relic (무기 유물) | Impaler | sp | Range | | Stackable | effectTarget: sp → Spear | B | Medium | 3무기 한정 수치/타수/범위 |
| 17 | Sawtooth Spearhead | Weapon-based relic (무기 유물) | Lancer | sp | AOE | | Upgradeable | Spear (sp) / Lancer; effectTarget: sp → Spear | B | Medium | 3무기 한정 수치/타수/범위 |
| 18 | Shield Spike | Weapon-based relic (무기 유물) | Paladin | ss | Knockback_Power | | Upgradeable | effectTarget: ss → SwordShield | B | Medium | Knockback_Power, ss_sweep — RelicData shield_spike Effect 이미 부분 구현 |
| 19 | Knight's Belt | Weapon-based relic (무기 유물) | Guardian | ss | Cooldown | | Upgradeable | SwordShield (ss) / Guardian; effectTarget: ss → SwordShield | A | Medium | Cooldown, ss; 공격 간격 ×0.80 — RelicData knights_belt 동형 |
| 25 | Hanji's Katana | Ability/tag-based relic (능력 유물) | Samurai | Sweep | Effect_Change | | Unique | effectTarget: sweep → SS/TH attackTag | E | Hold | Change/복합/미구현 계열 |
| 27 | Needle Edge | Ability/tag-based relic (능력 유물) | Lancer | Thrust | Damage | | Stackable | Spear (sp) / Lancer; effectTarget: thrust → SS/SP attackTag | A | Medium | Damage, Thrust; ×1.10 — RelicData needle_edge 동형 |
| 29 | Old Shield Emblem | Ability/tag-based relic (능력 유물) | Guardian | block | Damage | | Upgradeable | SwordShield (ss) / Guardian; effectTarget: block → SwordShield 방패 | A | Medium | Damage, block target; Sweep ×1.10 — RelicData old_shield_emblem 동형 |
| 31 | Guardrail Emblem | Type-based relic (계열 유물) | Guardian | block, thrust | Critical / Attack_Skip | passive | Unique | SwordShield (ss) / Guardian; … | D | Hold | passive; Block 후 Thrust crit + Sweep skip |
| 32 | Counter Prayer | Type-based relic (계열 유물) | Vanguard | block, sweep | Damage_Store / Counter | on_damaged | Unique | effectTarget: sweep … block … | D | Hold | trigger 또는 Status_Add/복합 modifier |
| 45 | Cracked Guardplate | Weapon-based relic (무기 유물) | Paladin | ss, block, sweep | Knockback_Add | passive | Unique | effectTarget: ss … sweep … block … | D | Hold | trigger 또는 Status_Add/복합 modifier |
| 46 | Shieldhook | Weapon-based relic (무기 유물) | Paladin | ss, sweep, knockback | Status_Add | on_hit | Unique | effectTarget: ss … sweep … | D | Hold | trigger 또는 Status_Add/복합 modifier |
| 47 | Nibbling Evil Sword | Weapon-based relic (무기 유물) | Oathbreaker | ss, sweep | Attack_Change / Tradeoff | passive | Upgradeable | effectTarget: ss … sweep … | E | Hold | Change/복합/미구현 계열 |
| 48 | Frost Rim | Weapon-based relic (무기 유물) | Glacier Knight | ss, knockback, freeze | Crush_Add | on_hit | Unique | effectTarget: ss → SwordShield | D | Hold | trigger 또는 Status_Add/복합 modifier |
| 49 | Execution Grip | Weapon-based relic (무기 유물) | Executioner | th, sweep, slash | Effect_Add | on_hit | Unique | effectTarget: th … sweep … | D | Hold | trigger 또는 Status_Add/복합 modifier |
| 50 | Sunder Wedge | Weapon-based relic (무기 유물) | Slayer | th, sweep, armorbreak | Status_Add | on_hit | Unique | TwoHandedSword (th) / Slayer; … | D | Hold | trigger 또는 Status_Add/복합 modifier |
| 51 | Harvester's Hook | Weapon-based relic (무기 유물) | Harvester | th, sweep, pull | Status_Add | on_hit | Unique | effectTarget: th … sweep … | D | Hold | trigger 또는 Status_Add/복합 modifier |
| 52 | Maul Seal | Weapon-based relic (무기 유물) | Mauler | th, slam, stun | Status_Add | on_hit | Unique | effectTarget: th → TwoHandedSword | D | Hold | trigger 또는 Status_Add/복합 modifier |
| 53 | Forked Pike | Weapon-based relic (무기 유물) | Lancer | sp, thrust | Attack_Amount / Tradeoff | passive | Unique | Spear (sp) / Lancer; … | B | Medium | passive Attack_Amount/Tradeoff, sp thrust 2갈래 |
| 55 | Bloodline Spear | Weapon-based relic (무기 유물) | Bloodletter | sp, thrust, bleed | Critical_Chance | on_hit | Unique | effectTarget: sp … thrust … | D | Hold | trigger 또는 Status_Add/복합 modifier |
| 57 | Linepiercer's Rule | Weapon-based relic (무기 유물) | Impaler | sp, thrust, critical | Conditional_Crit | on_hit | Unique | effectTarget: sp … thrust … | D | Hold | trigger 또는 Status_Add/복합 modifier |
| 58 | Red Cleaver | Weapon-based relic (무기 유물) | Butcher | ax, sweep, bleed | Drain_Add | on_hit | Unique | effectTarget: sweep → SS/TH attackTag | D | Hold | trigger 또는 Status_Add/복합 modifier |
| 59 | Frenzy Chain | Weapon-based relic (무기 유물) | Berserker | ax, sweep, frenzy | Combo_Add | on_hit | Unique | effectTarget: sweep → SS/TH attackTag | D | Hold | trigger 또는 Status_Add/복합 modifier |
| 60 | Thunder Cleaver | Weapon-based relic (무기 유물) | Stormbreaker | ax, sweep, paralyze | Status_Add | on_hit | Unique | effectTarget: sweep → SS/TH attackTag | D | Hold | trigger 또는 Status_Add/복합 modifier |
| 63 | Madfang Handle | Weapon-based relic (무기 유물) | Berserker | ax, sweep, combo | Combo | on_hit | Unique | effectTarget: sweep → SS/TH attackTag | D | Hold | trigger 또는 Status_Add/복합 modifier |
| 77 | Harrier Fletching | Weapon-based relic (무기 유물) | Harrier | bo, shot, slow | Status_Add | on_hit | Unique | | D | Hold | trigger 또는 Status_Add/복합 modifier |
| 95 | Frostguard Rivet | Weapon-based relic (무기 유물) | Glacier Knight | block, freeze, crush | Crush_Add | passive | Unique | effectTarget: block → SwordShield 방패 | D | Hold | trigger 또는 Status_Add/복합 modifier |
| 111 | Cryogenic Current | Ability/tag-based relic (능력 유물) | Frostbinder | freeze, slow | Status_Add | passive | Unique | | D | Hold | trigger 또는 Status_Add/복합 modifier |
| 115 | Beam Lock | Ability/tag-based relic (능력 유물) | Railpiercer, Stormchannel | beam, slow | Status_Add | on_hit | Unique | | D | Hold | trigger 또는 Status_Add/복합 modifier |
| 132 | Shield Return | Weapon-based relic (무기 유물) | Bulwark | block, sweep | Knockback_Add / Damage_Down | passive | Unique | effectTarget: sweep … block … | D | Hold | trigger 또는 Status_Add/복합 modifier |
| 133 | Faded Monolith Statue | Weapon-based relic (무기 유물) | Bulwark | block | Block_Add | passive | Unique | effectTarget: block → SwordShield 방패 | D | Hold | trigger 또는 Status_Add/복합 modifier |
| 134 | Dull Shield Edge | Weapon-based relic (무기 유물) | Paladin | sweep, knockback | Knockback_Repeat / Crit_Lock | on_hit | Unique | effectTarget: sweep → SS/TH attackTag | D | Hold | trigger 또는 Status_Add/복합 modifier |
| 135 | Arioch's Deception | Weapon-based relic (무기 유물) | Oathbreaker | ss, block, Thrust | Effect_Change / Block_Remove | passive | Unique | effectTarget: ss … thrust … block … | E | Hold | Change/복합/미구현 계열 |
| 136 | Heavy Furrow | Weapon-based relic (무기 유물) | Mauler | th, sweep, stun | Status_Add | on_hit | Unique | effectTarget: th … sweep … | D | Hold | trigger 또는 Status_Add/복합 modifier |
| 137 | Diabolic Blade | Weapon-based relic (무기 유물) | Executioner | sweep | Conditional_Sweep_Add | on_hit | Unique | effectTarget: sweep → SS/TH attackTag | D | Hold | trigger 또는 Status_Add/복합 modifier |
| 139 | Needle Parade | Weapon-based relic (무기 유물) | Stinger | thrust, critical | Crit_On_Stack | on_hit | Unique | effectTarget: thrust → SS/SP attackTag | D | Hold | trigger 또는 Status_Add/복합 modifier |
| 140 | Rage Splitter | Weapon-based relic (무기 유물) | Stormbreaker | sweep, combo, paralyze | Status_Add / Early_Status_Lock | on_hit | Unique | effectTarget: sweep → SS/TH attackTag | D | Hold | trigger 또는 Status_Add/복합 modifier |
| 141 | Butcher Hook | Weapon-based relic (무기 유물) | Butcher | sweep, bleed, drain | Drain_Add | on_hit | Unique | effectTarget: sweep → SS/TH attackTag | D | Hold | trigger 또는 Status_Add/복합 modifier |
| 142 | Storm Cleaver | Weapon-based relic (무기 유물) | Stormbreaker | sweep, paralyze, chain | Status_Consume / Chain_Add | on_hit | Unique | effectTarget: sweep → SS/TH attackTag | D | Hold | trigger 또는 Status_Add/복합 modifier |
| 158 | Sinister Reflexes | Weapon-based relic (무기 유물) | Oathbreaker | ss, sweep | Sweep_Add | on_damaged | Upgradeable | effectTarget: ss … sweep … | D | Hold | trigger 또는 Status_Add/복합 modifier |
| 159 | Revenant's Arsenal | Weapon-based relic (무기 유물) | Oathbreaker | ss, sweep, thrust | Attack_Change / Cooldown | passive | Unique | effectTarget: ss … sweep … thrust … | E | Hold | Change/복합/미구현 계열 |
| 160 | Impale Coin | Weapon-based relic (무기 유물) | Impaler | thrust, critical | Crit_On_Single_Target | on_hit | Unique | effectTarget: thrust → SS/SP attackTag | D | Hold | trigger 또는 Status_Add/복합 modifier |
| 161 | Blood Halberd | Weapon-based relic (무기 유물) | Bloodletter | thrust, bleed | Status_Duration_Extend / Damage_Down | on_hit | Unique | effectTarget: thrust → SS/SP attackTag | D | Hold | trigger 또는 Status_Add/복합 modifier |
| 162 | Grindstone Axe | Weapon-based relic (무기 유물) | Butcher | sweep, armorbreak, slash | Slash_Add | on_hit | Unique | effectTarget: sweep → SS/TH attackTag | D | Hold | trigger 또는 Status_Add/복합 modifier |
| 163 | Redline Wrap | Weapon-based relic (무기 유물) | Berserker | low_hp, sweep, bleed | Status_Add | on_low_hp | Unique | effectTarget: sweep → SS/TH attackTag | D | Hold | trigger 또는 Status_Add/복합 modifier |
| 168 | Crippling Fletch | Weapon-based relic (무기 유물) | Harrier | shot, slow | Status_Duration_Extend / Damage_Down | on_hit | Unique | | D | Hold | trigger 또는 Status_Add/복합 modifier |
| 170 | Thorn Oath | Weapon-based relic (무기 유물) | Oathbreaker | ss, block, sweep, bleed | Status_Add / Knockback_Lock | passive | Unique | effectTarget: ss … sweep … block … | D | Hold | trigger 또는 Status_Add/복합 modifier |
| 171 | Rust Plow | Weapon-based relic (무기 유물) | Mauler | th, slam, armorbreak, airborne | Status_Add | on_hit | Unique | effectTarget: th → TwoHandedSword | D | Hold | trigger 또는 Status_Add/복합 modifier |
| 172 | Fencer's Debt | Weapon-based relic (무기 유물) | Impaler | sp, thrust, pierce | Pierce_Add / Miss_Reset | on_hit | Unique | effectTarget: sp … thrust … | D | Hold | trigger 또는 Status_Add/복합 modifier |
| 173 | Blood Channel | Weapon-based relic (무기 유물) | Bloodletter | sp, thrust, bleed | Status_Copy / Status_Consume | on_hit | Unique | effectTarget: sp … thrust … | D | Hold | trigger 또는 Status_Add/복합 modifier |

---

## 10. 참조

| 문서/모듈 | 용도 |
|-----------|------|
| `docs/PHASE3_DATASET_ANALYSIS.md` | RL.TAGS 컬럼·Tier 정책·WP.TAGS |
| `src/ReplicatedStorage/Shared/RelicData.lua` | 현재 구현 7종 (이관 전 스냅샷) |
| `src/ReplicatedStorage/Shared/WeaponTagData.lua` | effectTags 제거 후 6필드 row |

---

## 변경 이력

| 날짜 | 내용 |
|------|------|
| 2026-05-27 | v20 RL.TAGS 필터 61건 triage 초안. 코드 수정 없음. |

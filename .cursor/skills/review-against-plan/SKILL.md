---
name: review-against-plan
description: diff vs plan 일치 검사 — 공통 절차(Skill); 에이전트 역할 아님 (ROGUE)
---

# Review against plan

## 이 Skill의 성격

- **에이전트 역할 정의가 아니다.** Reviewer(서브) 전용이 아니라, 누구나 리뷰 단계에서 **동일 절차**를 적용하기 위한 문서다.

## When to use

구현 직후, PR/채팅에 “리뷰” 요청이 있을 때.

## Steps

1. 확정 **PLAN** 텍스트(Goal, Task type, **Files in scope**, Planned steps) 확보.
2. 실제 변경 파일 목록(diff) 추출 → **Plan compliance** 표에 넣을 대조 자료 준비.
3. **Scope creep** 점검:
   - 플랜에 없는 **추가 파일**;
   - 승인 범위를 넘는 **동작·데이터** 변경;
   - 불필요한 **rename / move / refactor** 의심(플랜·승인과 불일치 시 강하게).
4. **Plan compliance:** Goal·파일 집합·Planned steps 가 diff와 맞는지.
5. **Rule violations (가벼운 스팟):** 플랜·diff만으로 보이는 **02/03 위반 후보**(코드 수정은 하지 않음).
6. **Regression risk** 수준(low/medium/high) 가늠.
7. **Verdict:** 위를 종합해 PASS/FAIL — 출력은 `.cursor/agents/reviewer.md` 고정 형식.

## PASS 조건 (요지)

- **실제 변경 파일 ⊆** 플랜 **Files in scope**(또는 플랜에 명시된 추가)가 아니면 보통 **FAIL**(추가 수정 = scope creep).
- 플랜 **Goal·Planned steps** 과 무관한 수정이 보이면 **FAIL**.
- rename/move/refactor 가 플랜·**01-workflow**(승인)와 맞지 않으면 **FAIL** 후보.

Rule violations·regression 은 단독으로 PASS를 깨지 않을 수 있으나 **중대하면 FAIL** 또는 Failure details 에 명시.

## Output

- **Reviewer 고정 형식 준수:** `.cursor/agents/reviewer.md` 의 **`## 고정 출력 형식 (필수)`** 와 동일 헤딩·순서 — `## 검토` → `### Verdict` → `### Plan reference` → `### Plan compliance` → `### Scope creep` → `### Rule violations` → `### Regression risk` → `### Failure details`.
- 판정은 **`PASS`** 또는 **`FAIL`** 단일 줄(`### Verdict`).
- 구식 한 줄 형식(`FAIL — 이유 — 파일`)만으로 대체하지 않는다.

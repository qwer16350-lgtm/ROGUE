---
name: plan-before-change
description: 변경 전 플랜 필수 및 승인 게이트 — 공통 절차(Skill); 에이전트 역할 아님 (ROGUE)
---

# Plan before change

## 이 Skill의 성격

- **에이전트 역할 정의가 아니다.** Coordinator(메인)와 Planner·Implementer 등 **서브 에이전트가 공통으로 재사용**하는 반복 절차·보호장치다.
- 내용이 `.cursor/rules/` 와 겹치면 **Rules가 우선**한다.

## When to use

`src/` 또는 레포 파일을 바꿀 수 있는 요청 직전. **read-only** 플랜도 같은 절차로 PLAN 블록만 출력할 수 있다.

## Steps

`.cursor/agents/planner.md` 고정 순서와 1:1로 맞춘다.

1. **Goal** — 목표 한 문단.
2. **Task type** — `repo-change` \| `read-only`, 필요 시 태그.
3. **Files in scope** — 수정 후보 전부 `src/...` (read-only 면 `(none — read-only)`).
4. **Planned steps** — 승인 후 실행 순서 번호 목록 (구현·코드 아님).
5. **Out of scope** — 비범위 경로·시스템.
6. **Risks and assumptions** — 리스크·롤백·가정·**Rojo / default.project.json impact** 한 불릿.
7. **Approval wait** — 승인 전 파일 쓰기 금지 문구. 사용자 **승인 문구**를 받을 때까지 구현 도구 사용 금지.

## ROGUE paths to mention if touched

`Files in scope` / `Planned steps` 작성 시 특히 확인:

- `default.project.json`
- `src/ServerScriptService/MainServer.server.lua`
- `src/StarterPlayer/StarterPlayerScripts/MainClient.client.lua`
- `src/StarterGui/`, `src/ReplicatedStorage/Shared/`

## Output

- **Planner 고정 형식 준수:** `.cursor/agents/planner.md` 의 **`## 고정 출력 형식 (필수)`** 와 동일한 헤딩·순서만 사용한다 — `## PLAN` → `### Goal` → `### Task type` → `### Files in scope` → `### Planned steps` → `### Out of scope` → `### Risks and assumptions` → `### Approval wait`.
- 패치·파일 수정 없음.

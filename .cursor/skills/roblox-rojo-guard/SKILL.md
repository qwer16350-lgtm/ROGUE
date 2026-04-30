---
name: roblox-rojo-guard
description: Rojo 동기화·src 정본 가드 — 공통 절차(Skill); 에이전트 역할 아님 (ROGUE)
---

# Roblox Rojo guard

## 이 Skill의 성격

- **에이전트 역할 정의가 아니다.** Validator(서브)뿐 아니라 구현 직후 **Coordinator** 등이 Rojo 확인에 **같은 체크리스트**를 쓰기 위한 것이다.

## When to use

스크립트/트리 변경 후, 또는 “Studio에만 있다”는 제보가 있을 때.

런타임 플레이 검증은 **`docs/VERIFICATION_PLAYTEST.md`** — 이 Skill은 **§A(Rojo·매핑)** 만 다룬다.

## Checklist (로컬) — Validator 보고서 §A 와 동일 번호

| 번호 | 항목 |
|------|------|
| **A1** | 루트 `default.project.json` 존재. |
| **A2** | `rojo sourcemap default.project.json` (또는 Rojo CLI)로 구문·파싱 오류 없음. |
| **A3** | 변경한 경로가 json에 `$path`로 잡혀 있는지 (Workspace·ServerStorage 등). |
| **A4** | `rojo serve` 등 동기화 절차: Studio 플러그인이 **이 워크스페이스**에 붙는지. |

**출력:** Validator는 `.cursor/agents/validator.md` 의 **`## 검증 보고`** 중 **§A** 표로만 적는다. Skill과 에이전트 표 번호가 충돌하지 않도록 유지한다.

## Truth rule

- **정본: `src/`** + `default.project.json`.
- Studio 단독 편집은 동기화가 올 때까지 **미확정** 취급.

## If sync is wrong

- Rojo 연결 끊고 다시 연결, 이전 `rojo serve` 중복 프로세스 종료 (Windows: `netstat`로 포트).

---
name: minimal-diff-implementation
description: 승인 플랜 범위 최소 diff — 공통 절차(Skill); 에이전트 역할 아님 (ROGUE)
---

# Minimal diff implementation

## 이 Skill의 성격

- **에이전트 역할 정의가 아니다.** Implementer(서브) 실행 시 Coordinator가 동일 절차를 상기할 때도 열 수 있는 **재사용 체크리스트**다.
- Rules·플랜과 충돌 시 Rules·플랜이 우선한다.

## When to use

사용자가 플랜을 **승인한 뒤** 구현할 때.

## Rules

1. 플랜에 없는 파일: **수정 금지**
2. “리팩터/정리/스타일” **드라이브**: 금지 (플랜에 있을 때만)
3. 한 커밋(또는 한 턴)의 이야기는 **한 목적**만
4. 엔트리(`MainServer`, `MainClient`)는 **wiring만** — 비대한 로직 직접 삽입 지양 (플랜 달리면 예외)

## ROGUE

- 경로는 항상 `src/...` 로 말할 것.
- Map, VFX, Session 등 **다른 시스템**을 손대면 플랜에 반드시 적을 것.

## Output

1. 필요한 파일에만 unified diff 수준의 최소 변경.
2. 적용 후 **Implementer 고정 형식 준수:** `.cursor/agents/implementer.md` 의 **`## 고정 출력 형식 (필수)`** (`## 구현 보고` …) 로 변경 보고.

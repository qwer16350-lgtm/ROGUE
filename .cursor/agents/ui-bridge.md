# 서브 에이전트: UI-bridge

> **역할 유형:** 서브 — GUI/HUD 관련 요청일 때만 **Coordinator** 가 활성화한다.  
> StarterGui/MainHUD 점검 절차는 **`Skills/gui-truth-source-check/SKILL.md`** 에 있다.

## 정의

GUI 자산·클라 HUD 바인딩만 다룬다. 게임플레이 로직·스폰 로직은 여기서 확장하지 않는다.

## Coordinator와의 관계

- 일반적으로 **Planner → (승인) → Implementer** 와 조합되며, UI 경로만 Implementer 범위에 명시된다.
- Coordinator는 HUD 이슈면 먼저 이 서브 모드를 고른다.

## 레포 경로 관용

- 자산: `src/StarterGui/` (`default.project.json` 의 StarterGui 매핑)
- 클라: `src/StarterPlayer/StarterPlayerScripts/` 내 HUD 관련 스크립트
- 서버: `HudSyncService` 등 **상태 전달** 패턴 유지 (플랜에 다르면 예외)

## 공통 절차 (Skill)

작업 전후 **`gui-truth-source-check/SKILL.md`** 를 연다.

## 금지

- Skill을 “UI 전용 두 번째 Coordinator”로 쓰기 — Skill은 **진실 소스 체크리스트**다.

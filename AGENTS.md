# ROGUE — Cursor agent harness (이 레포 전용)

이 파일은 **에이전트·사람 모두의 유일한 1차 진입점**이다. 전역 코드 스캔 전에 여기서만 흐름을 고른다.

## 2차로 읽을 문서 (선택)

| 순서 | 파일 | 내용 |
|------|------|------|
| 다음 | **`CURSOR_WORKFLOW.md`** | 마크다운 문서 맵, 업무 분기, 사람용 Rojo/Git 요약 위치. |
| 요청 양식 | **`docs/REQUEST_TEMPLATE.md`** | 작업 요청 복붙 템플릿(A~D: read-only·소규모·구조·**GUI/HUD**). |
| 플레이 검증 | **`docs/VERIFICATION_PLAYTEST.md`** | 변경 유형별 Studio 플레이테스트 체크리스트(§1 서버 / §2 HUD / §3 전투·성장). |
| 사람용 부록 | **`ROBLOX_RULES.md`** | Rojo·Git·폴더 치트시트. **규범은 아래 Rules에 위임** — 중복 규칙 장문 없음. |
| 런타임 설명 | **`docs/PROJECT_ARCHITECTURE.md`** | 서비스·전투·HUD 흐름. |

**플랜 → 명시 승인 → 구현** 등 저장소 수정 게이트의 규범 문장은 **`.cursor/rules/01-workflow.mdc`** 가 단일 근거다. **가장 짧은 항시 요약**은 **`.cursor/rules/00-priority-always.mdc`** — 루트 **`.cursorrules`** 도 같은 힌트를 한 번 더 준다. `CURSOR_WORKFLOW.md`는 이를 반복하지 않고 링크만 한다.

**도구 레벨 보조:** 저장소의 **`.cursor/hooks.json`** 은 사용자 메시지에 ASCII 토큰 **`APPROVE_PATCH`**(정확한 문자열)가 포함된 턴에서만 편집 성격 도구가 통과하도록 설정한다. 훅이 없거나 해제된 클라이언트에서는 Rules만으로 같은 순서를 유지한다.

## 레포 변경(repo-change) — 첫 응답 규칙

에이전트(Cursor 포함)는 **`src/` 등 파일을 바꿀 수 있는 요청**을 받으면:

1. **그 턴 첫 응답은** `.cursor/agents/planner.md` 의 **`## PLAN`** 형식만 출력한다 — **파일 수정 도구 사용 금지**.
2. 사용자가 같은 스레드에서 **명시 승인**한 **다음 턴**에만 패치한다. **로컬 훅이 켜진 환경**에서는 해당 사용자 메시지에 ASCII 토큰 **`APPROVE_PATCH`**(문자열 그대로)를 넣어야 편집 도구 게이트가 열린다. 절차 문구 예: “승인”, “이 플랜대로 구현” 등은 사람·에이전트 합의용이며, 한글 표현만으로는 훅을 통과하지 않는다.
3. **플랜 출력과 패치를 한 번의 assistant 응답에 넣지 않는다.**

**예외:** 사용자가 요청 맨 처음부터 **read-only**만 명시했거나, **하네스·문서만 수정**(게임 `src/` 미변경)을 명시한 경우 — 또는 사용자가 **이미 확정된 PLAN 전문 + 승인**을 한 메시지에 붙여 **구현만** 요청한 경우.

상세·금지 문구는 **`.cursor/rules/01-workflow.mdc`** (`첫 응답 = 플랜만`).

## 문서 3종 구분 (필수)

| 종류 | 위치 | 정의 |
|------|------|------|
| **Rules** | `.cursor/rules/*.mdc` | **항상 적용**되는 프로젝트 운영 규칙 (플랜·승인·Rojo·GUI 진실 등). 역할 이름이 아님. |
| **Agents** | `.cursor/agents/*.md` | **역할·책임·호출 흐름**만. 누가 무엇을 읽고 쓰는지, 메인/서브 구분. |
| **Skills** | `.cursor/skills/*/SKILL.md` | **여러 에이전트가 공통으로 재사용**하는 반복 절차·체크리스트·보호장치. **에이전트 역할 설명이 아님.** |

## 메인 vs 서브 에이전트

| 구분 | 문서 | 역할 |
|------|------|------|
| **메인** | `coordinator.md` | 사용자 요청을 받아 **어느 서브 에이전트 모드를 쓸지** 결정하고, 서브 단계 순서(플랜→승인→구현→리뷰 등)를 밟게 한다. **단일 진입점.** |
| **서브** | `planner.md`, `implementer.md`, `reviewer.md`, `validator.md`, `ui-bridge.md` | Coordinator가 켠 **한 가지 역할만** 수행한다. 서로를 대체하지 않는다. |

Coordinator는 구현 패치의 **직접 작성자**가 아니라 **오케스트레이터**다. 실제 수정은 **Implementer(서브)** 가 승인된 플랜 범위에서 수행한다.

## 원칙 (한 줄)

**Plan → 사용자 명시 승인 → 구현 → 플랜 대조 리뷰.**  
스크립트 진실 소스는 **`src/` + `default.project.json`** (Rojo). Studio는 동기화 대상이지 편집 진실 소스가 아니다.

## 구조적 금지 (요약)

| 하지 말 것 | Rules |
|------------|--------|
| 엔트리(MainServer/MainClient)에 비대한 로직 쌓기 | `02-roblox-boundaries.mdc` |
| `Shared/Utils.lua` 를 잡탕 모듈로 키우기 | `02-roblox-boundaries.mdc` |
| HUDClient 가 LevelUp·영구 성장 로직 소유 | `03-gui-source-of-truth.mdc` |
| Studio PlayerGui 상태만 상상하고 GUI 수정 | `03-gui-source-of-truth.mdc` |
| LocalScript 에 서버 권한 로직 | `02-roblox-boundaries.mdc` |
| 승인 없이 파일 이동·이름 변경 | `01-workflow.mdc` |

전문 문장은 **`.cursor/rules/*.mdc`** 가 정본이다.

## 권장 흐름 (Coordinator 관점)

1. **Coordinator(메인)** — 요청 분류 → 필요 시 **`plan-before-change` 등 Skills** 확인 → 서브 순서 결정.
2. **Planner(서브)** — 플랜만 산출 (**Skills: plan-before-change** 절차 준수).
3. 사용자 **명시 승인** (`승인`, `이 플랜대로 구현` 등).
4. **Implementer(서브)** — 승인 범위 패치 (**Skills: minimal-diff-implementation**).
5. **Reviewer(서브)** — diff vs 플랜 (**Skills: review-against-plan**).
6. **Validator(서브)** — 구조/Rojo (**Skills: roblox-rojo-guard**, **roblox-validation-checklist**).
7. **UI-bridge(서브)** — GUI/HUD만 해당할 때 (**Skills: gui-truth-source-check**).

Skills는 위 단계에서 **같은 절차를 반복할 때** Coordinator 또는 해당 서브가 **문서를 열어 따른다**. Skills에 “역할”은 없다.

## 디렉터리

| 경로 | 용도 |
|------|------|
| `.cursor/rules/*.mdc` | 항시 운영 규칙 |
| `.cursor/agents/*.md` | 메인(Coordinator)·서브 역할 정의 |
| `.cursor/skills/*/SKILL.md` | 공통 절차 묶음 (체크리스트) |

## 레포 특화 고정 사실

- 엔트리: `src/ServerScriptService/MainServer.server.lua`, `src/StarterPlayer/StarterPlayerScripts/MainClient.client.lua`
- 공유: `src/ReplicatedStorage/Shared/`
- GUI 자산: `src/StarterGui/` (예: MainHUD — 실제 이름은 프로젝트 내 확인)
- Rojo: 루트 `default.project.json`

## Skills 로딩

프로젝트 로컬 스킬은 Cursor 버전에 따라 자동 노출이 다를 수 있다. 자동 매칭이 안 되면 **`@.cursor/skills/<이름>/SKILL.md`** 로 명시한다.

## 게임플레이 코드

의도적인 게임플레이·밸런스 변경은 **별도 요청**으로 분리하고, 하네스 문서만 수정할 때는 `src/` 게임 코드를 건드리지 않는다.

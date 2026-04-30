# 작업 블록 플로 (`시작할게` / `끝마칠게`)

Cursor 로컬 훅이 **IDE 안에서 에이전트가 쓰는 편집 도구와 Cursor 통합 터미널에서 나가는 `git commit` / `git push`** 만 제어한다. GitHub Desktop·외부 콘솔은 막지 못한다.

## 토큰

| 토큰 | 효과 |
|------|------|
| **시작할게** | 새 작업 블록을 연다(`session_active = true`). **같은 메시지에 `끝마칠게`도 있으면 훅은 먼저 끝 처리 후 다시 시작**한다. 새 블록을 열면 `commit_allowed = false`로 돌려, 그 블록을 끝맺기 전엔 원칙적으로 푸시하지 않도록 맞춘다. |
| **끝마칠게** | 블록을 닫고 구간 기록 후 `commit_allowed = true`로 놓아 **`git commit` / `push` 셸**을 허용한다. |

## 세션

- 자정 넘어도 **한 블록**으로 이어 진다 (`끝마칠게` 전까지).
- 같은 날에 여러 블록을 열고 닫을 수 있다.
- **끝마칠게 이후** (`session_active = false`): 새 **`시작할게` 없으면** Write·Task 등 **코드 변경 도구는** 통과하지 못한다.
- 같은 조건이라도 **`commit_allowed`(끝맺은 뒤)** 이면 **터미널 류**(`run_terminal_cmd` 등)은 **시작할게 없이** 통과 가능 — 에이전트가 `git add`/`commit`/`push` 까지만 돌리는 용도. 실제 `git commit`/`push` **문장**은 **`beforeShellExecution`** 이 추가로 허용(`commit_allowed`)할 때만 나간다.
- **부트스트랩**: `.cursor/.daily_workflow_state.json` 이 **아직 없으면** 세션·git 셸 게이트 모두 적용하지 않는다(기존처럼 `APPROVE_PATCH`만). 사용자가 한 번이라도 `시작할게` 또는 `끝마칠게`를 보내면 파일이 생기고, **그때부터** 세션 규칙과 `commit_allowed` 검사가 살아난다.

## `APPROVE_PATCH`

편집·터미널 도구는 예전과 같이 메시지에 **`APPROVE_PATCH`** 가 있어야 한다. 흔한 패턴:

- 작업 시작: `시작할게` … `APPROVE_PATCH`
- 마무리·커밋: `끝마칠게` … 요약 … `APPROVE_PATCH`

## 로컬 상태 파일 (커밋 안 함)

**`.cursor/.daily_workflow_state.json`** (`.gitignore`)

- `session_active`, `commit_allowed`
- 열린 블록: `current_segment_start_iso`, `current_start_excerpt`
- 닫힌 구간 `segments[]` (시작/종료 시각 + 짧은 발췌, 최대 200개)

## 문서화

날짜·블록별 요약은 **`docs/DEVELOPMENT_LOG.md`** 등에 수동으로 남기는 것을 권장한다(훅이 자동 기록하지 않음).

## 구현 위치

- `daily-workflow-state.ps1` — 상태 읽기/쓰기, 프롬프트 반영
- `set-patch-gate.ps1` — `json_ok*` 프롬프트마다 위 모듈 갱신
- `enforce-patch-gate.ps1` — 세션 열림 여부
- `enforce-daily-git-gate.ps1` — `beforeShellExecution` 에서 commit/push
- `.cursor/hooks.json`

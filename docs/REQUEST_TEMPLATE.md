# Cursor 작업 요청 템플릿 (ROGUE)

사람이 Cursor에 작업을 넘길 때 **형식을 통일**하기 위한 문서다. 규칙 정본은 **`AGENTS.md`**, **`.cursor/rules/`** 이며, 이 파일은 요청서 양식만 다룬다.

## 작업 유형

| 유형 | 의미 |
|------|------|
| **read-only** | 읽기·설명·탐색만. 레포 파일 **수정 없음**. |
| **repo-change** | `src/` 등 파일 생성·수정·삭제. **플랜 → 명시 승인 → 구현** (`.cursor/rules/01-workflow.mdc`). |

## 공통 필드

모든 요청에 권장:

- **목표** — 한 문단.
- **수정 범위** — repo-change: 건드릴 경로·파일. read-only: 읽을 범위만.
- **건드리지 말 것** — 비범위 명시.
- **성공 기준** — 무엇이 되면 완료인지.
- **테스트 기준** — Studio 재현·기대 결과. read-only면 “해당 없음” 또는 검증 방법.

Planner 출력 형식은 `.cursor/agents/planner.md` 의 **`## PLAN`** 과 맞추면 이후 단계와 호환된다.

---

## 템플릿 A — read-only 질문용

아래 블록을 채워 채팅에 붙여넣는다.

```markdown
## 작업 요청

### 작업 유형
- **read-only** — 파일 수정 없음 (읽기·설명·설계 논의만).

### 목표
(예: 특정 함수가 언제 호출되는지 흐름 설명 / 이 버그 재현 조건 추정.)

### 조사·읽기 범위
- 폴더 또는 파일 (가능하면 경로):
  - 
- 참고하면 좋은 문서:
  - 

### 건드리지 말 것
- 수정 금지 (명시): **전체 레포 수정 없음.**

### 성공 기준
- (예: 질문에 대한 답변·다이어그램 수준 설명이 나오면 됨.)

### 테스트 기준
- 해당 없음 (코드 변경 없음).

### 비고
- 
```

---

## 템플릿 B — 소규모 수정용

한두 파일·상수·오타 등 **범위가 좁은 repo-change**. 플랜 후 승인 필요.

```markdown
## 작업 요청

### 작업 유형
- **repo-change** — 승인 후 패치.

### 목표
(한 문단.)

### 수정 범위 (예상)
- 파일:
  - `src/...`
- **Rojo / `default.project.json` 영향:** 아니오 | 예 — 사유:

### 건드리지 말 것
- 
- 

### 성공 기준
- 
- 

### 테스트 기준
- Studio에서: (재현 단계 → 기대 동작.)

### 비고
- 
```

---

## 템플릿 C — 구조 개선 / 리팩토링용

여러 파일·폴더·초기화 순서가 걸리는 변경. 플랜에 **파일 목록·비범위·리스크**를 반드시 채운다.

```markdown
## 작업 요청

### 작업 유형
- **repo-change** — 구조 개선 / 리팩토링 (범위 큼).

### 목표
(왜 바꾸는지, 유지하고 싶은 동작.)

### 수정 범위 (초안 — 플랜에서 확정)
- 포함 예정 경로·파일:
  - `src/...`
  - `src/...`
- **Rojo / `default.project.json` 영향:** 예 | 아니오 — 사유:

### 건드리지 말 것
- 게임플레이 수치·밸런스 (별도 요청인 경우 명시):
- 동시에 손대지 않을 시스템:
  - 

### 성공 기준
- 동작 변화 없이 구조만 개선인지 / 의도된 동작 변경인지 구분:
- 완료 판단 조건:

### 테스트 기준
- 회귀 확인 항목 (스테이지 / HUD / 전투 등):
- Studio 재현 절차:

### 리스크·롤백 (알고 있는 것만)
- **리스크:**
- **롤백:**

### 비고
- 참고: `docs/PROJECT_ARCHITECTURE.md` §…
```

---

## 템플릿 D — GUI / HUD 작업

**StarterGui**, **MainHUD**, **`HUDClient`**, **`LevelUpClient`** 등 UI 스크립트·자산을 바꿀 때 사용. PlayerGui 런타임만 상상하고 **`src/`** 를 건드리지 않는 실수를 막기 위해, 아래를 먼저 채운다.

```markdown
## 작업 요청

### 작업 유형
- **repo-change** — GUI / HUD (승인 후 패치).

### Goal
(한 문단.)

### Scope
- 수정·추가할 경로·파일:
  - `src/StarterGui/...`
  - `src/StarterPlayer/StarterPlayerScripts/...` (예: HUDClient, LevelUpClient …)

### Do not touch
- 비범위 UI·서버 로직·HudSync/Remote 패턴 유지 등:

### Success criteria

### Test criteria
- Studio: PlayerGui 반영·에러 없음·기대 표시/입력.

### GUI source of truth
- 규범은 **`.cursor/rules/03-gui-source-of-truth.mdc`** — 편집 정본은 디스크 **`src/StarterGui/`** 및 연결 스크립트. PlayerGui만 보고 레포를 수정하지 않는다.

### Current GUI tree or missing GUI info
- StarterGui/MainHUD 등 **현재 트리 요약**(가능하면) 또는 **`미확인 — 레포(`src/`) 기준으로 확인 필요`**.
```

---

## 관련 링크

- 진입점: `AGENTS.md`
- 플랜 고정 형식: `.cursor/agents/planner.md`
- GUI 규칙: `.cursor/rules/03-gui-source-of-truth.mdc`

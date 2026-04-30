# CURSOR_WORKFLOW — `AGENTS.md` 다음에 읽는 보조 문서

**단일 1차 진입점은 루트 `AGENTS.md` 하나다.** 이 파일은 그다음에 열 **마크다운 인덱스**, **업무 유형별 다음 읽을 문서**, **사람 개발자용 단축 절차**만 담는다.

플랜·승인·`src/` 수정 게이트 등 **강제 규칙의 본문**은 **`.cursor/rules/01-workflow.mdc`** 이다. 여기서는 반복하지 않는다.

---

## 1. 루트·하네스·규칙 연결

| 파일 | 책임 |
|------|------|
| **`AGENTS.md`** | 유일한 1차 진입점. Rules / Agents / Skills 구분, Coordinator 흐름. |
| **`.cursor/rules/*.mdc`** | 항시 적용 운영 규칙 (플랜·Rojo·GUI 등). |
| **`.cursor/agents/*.md`** | 역할·호출 흐름 (메인 Coordinator / 서브). |
| **`.cursor/skills/*/SKILL.md`** | 공통 반복 절차·체크리스트 (역할 정의 아님). |
| **`CURSOR_WORKFLOW.md`** | (이 파일) 문서 맵·업무 분기·사람용 루프 요약. |
| **`ROBLOX_RULES.md`** | 사람용 Rojo/Git·폴더 치트시트; 규범은 `.cursor/rules` 로 위임. |
| **`docs/archive/ROBLOX_RULES_legacy.md`** | 구 `ROBLOX_RULES` 전문 보관 — 정본 아님. |

---

## 2. 저장소 마크다운 인덱스

| 파일 | 용도 |
|------|------|
| **`AGENTS.md`** | 에이전트 하네스 진입점 |
| **`CURSOR_WORKFLOW.md`** | 문서 맵·분기 (이 파일) |
| **`docs/REQUEST_TEMPLATE.md`** | Cursor 작업 요청 템플릿 (read-only / 수정) |
| **`docs/VERIFICATION_PLAYTEST.md`** | Studio 플레이테스트 검증 (유형별 §1–§3) |
| **`docs/WORKSPACE_MAP_ROJO_SOURCE.md`** | `Workspace.Map` Ground / RuntimeMarkers `.rbxmx` 진실 소스 배치 |
| **`ROBLOX_RULES.md`** | Rojo/Git·폴더 요약 |
| **`docs/PROJECT_ARCHITECTURE.md`** | MainServer / MainClient, 서비스 초기화, 전투·HUD·VFX·스테이지 흐름 |
| **`docs/HUD_ARCHITECTURE_ANALYSIS.md`** | HUD 데이터, HudState, ProgressionService 연결 |
| **`docs/STRUCTURE_CLEANUP_PLAN.md`** | StarterGui/MainHUD Rojo 구조, 이름 체크리스트 |
| **`docs/PLAYER_CONTACT_DAMAGE_PLAN.md`** | 접촉 데미지 설계·플레이테스트 참고 |
| **`docs/STAGE_SPAWN_LOGIC_PLAN.md`** | 스테이지별 스폰 규칙 (`StageData` 등) |

서비스명·경로를 바꾸면 **같은 변경 묶음에서** 해당 문서를 갱신한다.

---

## 3. 사람 개발자 워크플로 (요약)

1. **`src/`** 에서 편집 후 저장.
2. **`rojo serve`** 로 Studio 와 동기화.
3. Studio에서 **플레이 테스트**.
4. 확인 후 **`git add` / `git commit`** (백업 시 `git push`).
5. 진실 소스는 **로컬 `src/` + `default.project.json`**.

세부는 **`ROBLOX_RULES.md`** .

---

## 4. AI / 에이전트가 추가로 열 문서

- **“어디서 돌아가나 / init 순서”** → `docs/PROJECT_ARCHITECTURE.md`
- **Rojo 경로·서버클라 경계 (규범)** → `.cursor/rules/02-roblox-boundaries.mdc` (요지는 `AGENTS.md`)
- **GUI·StarterGui** → `.cursor/rules/03-gui-source-of-truth.mdc`, 필요 시 `.cursor/skills/gui-truth-source-check/SKILL.md`
- **플랜 없이 수정하면 안 되는 이유·승인 문구** → `.cursor/rules/01-workflow.mdc`

읽기 전용 질문·코드 탐색만 있으면 승인 루프를 생략할 수 있다 — 조건과 예외는 **01-workflow.mdc** 에 따른다.

---

## 5. 업무 유형별 다음 파일

| 작업 | 먼저 볼 것 |
|------|------------|
| HUD / MainHUD / StarterGui | `docs/STRUCTURE_CLEANUP_PLAN.md`, `docs/HUD_ARCHITECTURE_ANALYSIS.md` |
| 새 서버 서비스·init 순서 | `docs/PROJECT_ARCHITECTURE.md` |
| 밸런스·튜닝 | `GameConfig.lua`, 필요 시 `UpgradeData.lua`; 스테이지별은 `StageData.lua` |
| VFX 파이프라인 | `docs/PROJECT_ARCHITECTURE.md`(VFX), 클라 `VFXClient.lua` 등 |

---

## 6. 규칙·문서를 고칠 때

| 바꿀 내용 | 편집할 위치 |
|-----------|-------------|
| 플랜·승인·구현 순서 | `.cursor/rules/01-workflow.mdc` |
| Rojo·레이어·진실 소스 | `.cursor/rules/02-roblox-boundaries.mdc` |
| GUI 진실 소스 | `.cursor/rules/03-gui-source-of-truth.mdc` |
| 에이전트 역할·Coordinator | `.cursor/agents/*.md`, 요약은 `AGENTS.md` |
| 반복 절차 체크리스트 | `.cursor/skills/*/SKILL.md` |
| 문서 목록·업무 분기 표 | **`CURSOR_WORKFLOW.md`** (이 파일) |
| 사람용 Rojo/Git 치트시트 | **`ROBLOX_RULES.md`** |
| 런타임 동작·서비스 설명 | **`docs/PROJECT_ARCHITECTURE.md`** |
| Studio 플레이 검증 체크리스트 | **`docs/VERIFICATION_PLAYTEST.md`** |

---

## 7. 채팅 언어 (선택)

Cursor 채팅에서 한글이 깨질 때는 사용자 선호에 따라 **영어**로 답할 수 있다. 레포 문서 언어는 통일만 유지하면 된다.

# ROGUE — 사람 개발자용 요약 (Rojo·Git·폴더)

**규범(normative) 규칙은 여기서 길게 반복하지 않는다.** 서버/클라 경계·GUI 진실 소스·플랜 게이트는 **`.cursor/rules/`** 와 **`AGENTS.md`** 가 단일 근거다.

| 필요한 정보 | 어디를 볼지 |
|-------------|-------------|
| 플랜 → 승인 → 구현 | `.cursor/rules/01-workflow.mdc` |
| Rojo·`src/` 정본·레이어 | `.cursor/rules/02-roblox-boundaries.mdc` |
| StarterGui / HUD 편집 원칙 | `.cursor/rules/03-gui-source-of-truth.mdc` |
| 에이전트 하네스·Coordinator | `AGENTS.md`, `.cursor/agents/` |
| 반복 절차 체크리스트 | `.cursor/skills/*/SKILL.md` |
| 런타임 아키텍처·서비스 순서 | `docs/PROJECT_ARCHITECTURE.md` |
| 마크다운 문서 목록·업무 분기 | `CURSOR_WORKFLOW.md` |

구버전 전문은 **`docs/archive/ROBLOX_RULES_legacy.md`** 에만 보관한다.

---

## 일상 워크플로 (짧게)

1. 루트에서 **`rojo serve`** 유지 후 Studio 플러그인으로 연결.
2. 코드는 **`src/`** 에서 편집·저장 — Studio 단독 편집을 정본으로 두지 않는다.
3. 동작 확인은 **Studio에서 플레이 테스트**.
4. 확인 후 **`git add` / `git commit`** (원격 백업 시 `git push`).
5. 새 폴더를 `src/` 에 추가했다면 **`default.project.json`** 매핑을 함께 검토한다.

---

## Rojo 파일 접미사

- `*.server.lua` → 서버 `Script`
- `*.client.lua` → 클라이언트 `LocalScript`
- 그 외 `*.lua` → 보통 `ModuleScript` (프로젝트 설정에 따름)

---

## 이 레포에서 자주 쓰는 디스크 경로 (치트시트)

`default.project.json` 기준 — 실제 트리는 해당 파일이 최종이다.

| 목적 | 디스크 경로 |
|------|-------------|
| 서버 스크립트 | `src/ServerScriptService/` |
| 클라(플레이어 스크립트) | `src/StarterPlayer/StarterPlayerScripts/` |
| 캐릭터 스크립트 | `src/StarterPlayer/StarterCharacterScripts/` |
| 공유 모듈·데이터 | `src/ReplicatedStorage/Shared/` |
| ScreenGui 등 UI 자산 | `src/StarterGui/` |
| 맵(Workspace) | `src/Workspace/Map/` |
| 맵 에셋(ServerStorage) | `src/ServerStorage/MapAssets/` |
| 엔트리 | `MainServer.server.lua`, `MainClient.client.lua` (위 서비스/스크립트 폴더 안) |

엔트리 외 신규 코드는 가능한 **별도 ModuleScript·서비스**로 두고 엔트리에서는 require/초기화만 하는 것이 이 레포 관행이다 (`docs/PROJECT_ARCHITECTURE.md` 참고).

---

## 구조적 금지 (요약)

| 금지 | 규범 위치 |
|------|-----------|
| MainServer / MainClient 비대화 | `.cursor/rules/02-roblox-boundaries.mdc` |
| `Shared/Utils.lua` 잡탕화 | 위와 동일 |
| HUDClient가 LevelUp 등 로직 소유 | `.cursor/rules/03-gui-source-of-truth.mdc` |
| Studio GUI 런타임만 상상하고 `src/` 수정 | 위와 동일 |
| LocalScript에 서버 권한 로직 | `02-roblox-boundaries.mdc` |
| 승인 없는 파일 이동·이름 변경 | `.cursor/rules/01-workflow.mdc` |

상세 문장은 위 **Rules** 파일이 단일 근거다.

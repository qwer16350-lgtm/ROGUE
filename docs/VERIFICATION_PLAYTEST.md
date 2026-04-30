# Studio 플레이테스트 검증 (ROGUE)

**정적 검증**(Rojo·레이어)은 `.cursor/skills/roblox-rojo-guard`, `roblox-validation-checklist` 와 Validator 보고서 **§A·§B** 가 담당한다.  
이 문서는 **런타임**에서 사용자가 Studio로 수행하는 **체크리스트 정본**이다.

## 어떤 섹션을 켤지

| 플랜·변경 요약 | 실행할 섹션 |
|----------------|-------------|
| `ServerScriptService`, 서비스, Remote, 스폰, 판정, 보상 등 **서버** | **§1** |
| `StarterGui`, MainHUD, `HUDClient`, `HudSyncService` 등 **UI** | **§2** |
| 전투, 스테이지, 웨이브, `GameConfig`·`StageData`, 성장·재화·업그레이드 | **§3** |
| 둘 이상 겹치면 | 해당 **§를 모두** 수행 |

---

## §1 — 서버 로직 변경

- [ ] Rojo 동기화 후 Play — **Server 스크립트 관련 Output 에러** 없음.
- [ ] 변경된 흐름에서 **Remote**(요청·이벤트)가 **서버에서 최종 판정**되는지 확인 (보상·전환·데미지 적용 등).
- [ ] **입장/리스폰/스테이지 시작** 등 한 사이클 이상, 변경 로직이 **실제로 실행**되는지 재현.
- [ ] 2인 검증이 어려우면 **1인 + Output 청소**로 대체하되, **다인 이슈** 가능 시 비고에 명시.
- [ ] 서버 변경이 **맵·에셋 로드**와 연결되면 Play 중 **Workspace / ServerStorage** 관련 에러 없음.

---

## §2 — HUD / UI 변경

- [ ] Play 시 UI가 **PlayerGui**에 표시되거나 의도대로 숨김 — **클라 스크립트 즉시 에러** 없음.
- [ ] 수정이 **`src/StarterGui/`** 자산이면 디스크 정본과 동기화 상태에서 테스트 (규칙 `.cursor/rules/03-gui-source-of-truth.mdc`).
- [ ] **HudState·Remote·서버 푸시**를 수정했다면 표시 값이 **서버 의도와 일치**.
- [ ] 레이아웃을 바꿨다면 **기본 Viewport**에서 가독성·잘림 없음.
- [ ] 모달/채팅 등 **입력 포커스**가 전투·이동과 충돌하지 않음(해당 시).

---

## §3 — 전투 / 성장 루프 변경

- [ ] **최소 1웨이브 또는 1스테이지** 이상 — 처치·보상·진행이 **끊기지 않음**.
- [ ] **재화·업그레이드·상점**을 건드렸다면 획득/소비가 **서버 권한**과 맞고 UI와 어긋나지 않음.
- [ ] `GameConfig` / `StageData` / 스폰·웨이브 관련 변경이면 **스테이지 전환·보스/웨이브** 를 한 번이라도 재현.
- [ ] **VFX/클라 연출**과 **실제 HP·판정**이 불일치하지 않음(변경 범위에 따라).

---

## 관련 스킬·문서

| 문서 | 용도 |
|------|------|
| `.cursor/skills/gui-truth-source-check/SKILL.md` | StarterGui 편집 전후 점검 |
| `docs/HUD_ARCHITECTURE_ANALYSIS.md` | HUD 데이터 흐름 참고 |
| `docs/PROJECT_ARCHITECTURE.md` | 서비스·전투 흐름 참고 |

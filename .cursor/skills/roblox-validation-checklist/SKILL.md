---
name: roblox-validation-checklist
description: 서버클라·공유·매핑 정적 검증(B1–B4) — 공통 절차(Skill); 에이전트 역할 아님 (ROGUE)
---

# Roblox validation checklist

## 이 Skill의 성격

- **에이전트 역할 정의가 아니다.** Validator(서브) 외에도 플랜 검토 시 **Planner** 등이 구조 의존을 점검할 때 **재사용**한다.

## 역할 분리 (Validator·플레이테스트와의 관계)

| 구분 | 내용 |
|------|------|
| **이 Skill (`roblox-validation-checklist`)** | 레포 **정적** 검증만 — 서버/클라 레이어·리모트·`default.project.json` 매핑 (**§B 표 B1–B4**). Studio 플레이를 대신하지 않음. |
| **`roblox-rojo-guard`** | Rojo·프로젝트 파일 (**§A A1–A4**). 플레이와 무관. |
| **`docs/VERIFICATION_PLAYTEST.md`** | 사용자 Studio **플레이테스트** 체크리스트 (**§1·§2·§3**). 변경 유형별로 필요한 섹션만 실행. |
| **Validator 에이전트** | 보고서에 **§A·§B·§C·§D** 를 채움. §D는 사용자 플레이 결과 또는 미실시 사유만 기록. |

## When to use

구현 후 Play 전 **정적 검증**, 또는 리모트·폴더 구조 변경 후.

플레이 체크가 필요하면 같은 브랜치 검증 흐름에서 **`docs/VERIFICATION_PLAYTEST.md`** 의 변경 유형에 맞는 §를 사용자에게 안내한다 — Skill 본문으로 플레이 항목을 중복하지 않는다.

## Layers

| 구분 | 예시 경로 |
|------|-----------|
| 서버 전용 | `src/ServerScriptService/*.lua` |
| 클라 로컬 | `src/StarterPlayer/StarterPlayerScripts/*.lua` |
| StarterCharacterScripts | `src/StarterPlayer/StarterCharacterScripts/*.lua` |
| 공유 데이터/모듈 | `src/ReplicatedStorage/Shared/` |
| 리모트 정의 | `default.project.json` 내 `ReplicatedStorage.Remotes` 또는 코드 생성 |

## Checks — Validator 보고서 §B 와 동일 번호

| 번호 | 항목 |
|------|------|
| **B1** | 서버 코드가 클라 로컬 전용 API를 직접 가정하지 않았는지. |
| **B2** | 클라가 서버 판정을 우회하지 않았는지 (예: 보상 확정 등). |
| **B3** | 새 폴더가 `default.project.json` 에 매핑되었는지 (필요 시). |
| **B4** | 이 레포 **`Workspace.Map`**, **`ServerStorage.MapAssets`** 매핑이 변경 시 유효한지. |

**출력:** Validator는 `.cursor/agents/validator.md` 의 **`## 검증 보고`** 중 **§B** 표로만 적는다.

## Limitation

실제 Roblox 플레이 테스트는 사용자 Studio에서 수행한다. 상세 체크리스트는 **`docs/VERIFICATION_PLAYTEST.md`** 이 단일 정본이다.

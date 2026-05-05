---
name: roblox-validation-checklist
description: 서버클라·공유·매핑 정적 검증(B1–B4) + 로컬 실행 가능한 명령 루틴(WARN/FAIL) — 공통 절차(Skill); 에이전트 역할 아님 (ROGUE)
---

# Roblox validation checklist

## 이 Skill의 성격

- **에이전트 역할 정의가 아니다.** Validator(서브) 외 Planner 등이 구조 의존 점검 시 **재사용**한다.
- **규칙 문장 추가용이 아니다.** 아래 **복붙 명령**으로 확인 가능한 것만 실행하고, 안 되면 **WARN**, 실행 후 깨지면 **FAIL**로 표시한다.

## 역할 분리

| 구분 | 내용 |
|------|------|
| **이 Skill** | 레포 **정적** 검증 명령 루틴 + **§B(B1–B4)** 코드·매핑 관점 요약. Studio 플레이를 대신하지 않음. |
| **`roblox-rojo-guard`** | **§A(A1–A4)** 서술과 진실 소스 원칙. Rojo 관련 명령 세부는 여기 루틴과 **교차 참조**. |
| **`docs/VERIFICATION_PLAYTEST.md`** | Studio **플레이테스트** 단일 정본 — 본문 복붙 금지, 필요 시 링크만. |
| **Validator 에이전트** | 보고서에 **§A·§B·§C·§D** 를 채움. §D는 사용자 플레이 결과 또는 미실시 사유만 기록. |

## When to use

구현 후 플레이 전 **정적 검증**, 리모트·트리·`default.project.json` 변경 후. 플레이 필요 시 사용자에게 **`docs/VERIFICATION_PLAYTEST.md`** 해당 §만 안내.

## 판정 기준 — WARN / FAIL / MANUAL VERIFY

| 라벨 | 조건 |
|------|------|
| **WARN** | 명령을 **실행하지 않음**(도구 미설치·PATH 없음·설정 파일 없음·비 Git 저장소 등). 검증 흐름은 계속 가능. 보고서에 `WARN: tool not configured (<이름>)` 또는 이유 한 줄. |
| **FAIL** | 명령을 **실행했고** 비정상 종료·출력상 오류(예: 린트 위반, Rojo 오류). 수정 또는 되돌린 뒤 재실행. |
| **MANUAL VERIFY** | CLI로 완결 불가(Studio·플러그인·계정 등). 무엇을 확인할지만 적고 상세 단계는 **`docs/VERIFICATION_PLAYTEST.md`** 로 위임. |

---

## 실행 가능한 검증 루틴

레포 **루트**에서 실행한다. 순서는 권장일 뿐 필수 고정 아님.

### 1) Git 작업 트리

```bash
git status --short
```

```bash
git diff --name-only
```

- Git 없거나 저장소 아님 → **WARN**. 실행했고 명백히 의도 외 변경만 보임 → Validator 판단으로 **FAIL** 가능.

### 2) Rojo (설치되어 있으면)

임시 출력 경로 예시 — **커밋하지 않는다.**

PowerShell (Windows):

```powershell
rojo sourcemap default.project.json --output "$env:TEMP\rojo-sourcemap.json"
```

```powershell
rojo build default.project.json --output "$env:TEMP\rojo-build.rbxlx"
```

POSIX:

```bash
rojo sourcemap default.project.json --output /tmp/rojo-sourcemap.json
```

```bash
rojo build default.project.json --output /tmp/rojo-build.rbxlx
```

- `rojo` 없음 → **WARN**: `WARN: tool not configured (rojo)`. 실행했고 실패 → **FAIL**.

### 3) Selene (설치되어 있거나 `.selene.toml` 등 설정이 있으면)

```bash
selene src
```

- 설정·바이너리 없음 → **WARN**: `WARN: tool not configured (selene)`. 실행 후 위반 → **FAIL**.

### 4) Stylua (설치되어 있거나 `stylua.toml` 등 설정이 있으면)

```bash
stylua --check src
```

- 없음 → **WARN**: `WARN: tool not configured (stylua)`. 실행 후 포맷 불일치 → **FAIL**.

### 5) Luau 분석 / LSP

저장소 또는 팀 문서에 **정해진 분석 명령 한 줄**이 있으면 그대로 실행한다(예: `package.json`의 `analyze`, 로컬 래퍼 스크립트 — **새 CI/엔진 추가는 이 Skill 범위 밖**).

- 재현 가능한 명령이 없음 → **WARN**: `WARN: tool not configured (luau analyze / LSP)`. 실행 후 오류 → **FAIL**.

### 6) MANUAL VERIFY — Studio / Rojo 동기화

- **A4** 급: `rojo serve`, Studio 플러그인이 **이 워크스페이스**에 붙는지, 중복 프로세스·포트 문제 없는지 등.
- 상세 단계는 **`docs/VERIFICATION_PLAYTEST.md`** 및 **`roblox-rojo-guard`**의 “If sync is wrong”을 따른다.

---

## Layers (경로 관성)

| 구분 | 예시 경로 |
|------|-----------|
| 서버 전용 | `src/ServerScriptService/*.lua` |
| 클라 로컬 | `src/StarterPlayer/StarterPlayerScripts/*.lua` |
| StarterCharacterScripts | `src/StarterPlayer/StarterCharacterScripts/*.lua` |
| 공유 데이터/모듈 | `src/ReplicatedStorage/Shared/` |
| 리모트 정의 | `default.project.json` 내 `ReplicatedStorage.Remotes` 또는 코드 생성 |

## Checks — Validator 보고서 §B 와 동일 번호

명령만으로 자동 증명되지 않는 항목이다. 위 **git diff / Rojo sourcemap·build** 결과와 함께 코드 리뷰로 채운다.

| 번호 | 항목 |
|------|------|
| **B1** | 서버 코드가 클라 로컬 전용 API를 직접 가정하지 않았는지. |
| **B2** | 클라가 서버 판정을 우회하지 않았는지 (예: 보상 확정 등). |
| **B3** | 새 폴더가 `default.project.json` 에 매핑되었는지 (필요 시). |
| **B4** | 이 레포 **`Workspace.Map`**, **`ServerStorage.MapAssets`** 매핑이 변경 시 유효한지. |

**출력:** Validator는 `.cursor/agents/validator.md` 의 **`## 검증 보고`** 중 **§B** 표로만 적는다.

## Limitation

실제 Roblox 플레이 테스트는 사용자 Studio에서 수행한다. 상세 체크리스트는 **`docs/VERIFICATION_PLAYTEST.md`** 이 단일 정본이다.

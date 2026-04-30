# HUD·게임 로직 연결 분석 (ROGUE)

프로젝트 코드·`default.project.json` 기준 분석. 구현 변경 없음.

---

## 1. 관련 폴더·파일 구조 (요약)

| 경로 | 파일·인스턴스 | 역할 요약 |
|------|----------------|------------|
| `src/ReplicatedStorage/Shared/` | `GameConfig.lua` | XP 곡선(`XpRequiredPerLevelBase`), 세션·전투 등 수치 |
| `src/ReplicatedStorage/Shared/` | `UpgradeData.lua` | 업그레이드 Id·Effects(전투 수치는 `CombatService`가 참조) |
| `ReplicatedStorage` (런타임) | `HudState` RemoteEvent | 클라 HUD용 주기 동기화 |
| `ReplicatedStorage` (런타임) | `LevelUpChoiceRequest` | 레벨업 시 선택 UI 오픈 트리거 |
| `ReplicatedStorage` (런타임) | `LevelUpChoiceSubmit` | 클라 → 서버 선택 제출 |
| `ReplicatedStorage` (런타임) | `VFX/…`, `Remotes/VFXEvent` | VFX 전용 (HUD와 무관) |
| `src/ServerScriptService/` | `MainServer.server.lua` | 초기화 순서·모듈 연결 |
| `src/ServerScriptService/` | `ProgressionService.lua` | **레벨/XP/업그레이드 스택** 단일 저장·레벨업 루프 |
| `src/ServerScriptService/` | `HudSyncService.lua` | `getHudProgress` + `WaveService.getHudInfo` → `HudState:FireClient` |
| `src/ServerScriptService/` | `WaveService.lua` | 세션 타이머·`getHudInfo()` → `remaining`(정수)·`remainingFloat`(실수)·`active` |
| `src/ServerScriptService/` | `PlayerContactDamageService.lua` | 플레이어 근접 피해·스폰 시 체력 (`HUD`와 직접 통신 없음) |
| `src/ServerScriptService/` | `XpPickupService.lua` | XP 오브 획득 시 `ProgressionService.addExperience` 호출 |
| `src/ServerScriptService/` | `CombatService.lua` | 전투(업그레이드 적용)·VFX 이벤트만 (레벨/XP 직접 관리 없음) |
| `src/StarterPlayer/StarterPlayerScripts/` | `HUDClient.lua` | `HudState` + `Humanoid` → 라벨·바 (`SecondsLeftFloat`·보간 등) |
| `src/StarterPlayer/StarterPlayerScripts/` | `LevelUpClient.lua` | `LevelUpChoiceRequest` / `LevelUpChoiceSubmit` |
| `src/StarterPlayer/StarterPlayerScripts/` | `MainClient.client.lua` | 클라 모듈 `init` 엔트리 |

---

## 2. 질문별 답변

### 1) Level·XP는 어디서 관리되는가?

- **서버** `ProgressionService.lua`의 **`progressByPlayer[player]`** 테이블: `level`, `xp`, `upgrades`.
- 다음 레벨까지 필요한 XP는 **`xpRequiredForLevel(level)`** → `GameConfig.XpRequiredPerLevelBase * level` (`gameConfigRef`).

### 2) 플레이어 진행 상태를 담당하는 서비스/모듈은?

- **핵심:** `ProgressionService` (레벨·XP·업그레이드 스택).
- **연동:** `XpPickupService`가 XP 지급, `CombatService`가 `getUpgradeCounts`로 전투 반영, `WaveService`/`HudSyncService`는 세션·HUD 표시용만.

### 3) 레벨업 판정은 어디서 발생하는가?

- **`ProgressionService.addExperience`** 내부 `while` 루프: `state.xp >= xpRequiredForLevel(state.level)`이면 `state.xp` 차감·`state.level` 증가.
- 연속 레벨업 가능(루프). 매 레벨업마다 **`LevelUpChoiceRequest:FireClient`** 로 선택 UI 요청.

### 4) 클라가 레벨/XP 변화를 받을 수 있는 기존 수단은?

| 수단 | 사용 여부 |
|------|-----------|
| **RemoteEvent `HudState`** | **있음.** `HudSyncService`가 `HudSyncIntervalSeconds`마다 `Level`, `Xp`, `XpToNext`, `SecondsLeft`, **`SecondsLeftFloat`**, `SessionActive`, `SessionLengthSeconds` 등 전송. |
| **RemoteEvent `LevelUpChoiceRequest`** | **있음.** 레벨·선택지 목록 (HUD 수치 전용은 아님). |
| RemoteFunction | **없음** (해당 흐름에 미사용). |
| Attributes / ValueObject | **없음** (Player/캐릭터로 XP 동기화 안 함). |
| 기타 | XP·레벨은 **서버 전용 테이블** + 위 Remote **푸시(폴링성 HUD)**. |

즉, **HUD용 연속 갱신은 `HudState` 하나**가 사실상 전부이다.

### 5) 업그레이드 선택을 서버에 넘기는 기존 경로는?

- **`LevelUpChoiceSubmit`** (`RemoteEvent`): 클라 `LevelUpClient`가 `choice.Id`를 `FireServer`, 서버 `ProgressionService`에서 `allowedChoiceIds` 검증 후 **`state.upgrades[choiceId] += 1`**.
- Id는 `UpgradeData.Choices`와 정합.

### 6) HUDClient에 가장 적합한 데이터 소스는?

- **1순위 (현재와 동일):** 서버 **`ProgressionService.getHudProgress`** → **`HudSyncService`**가 싣는 **`HudState` 페이로드** (`Level`, `Xp`, `XpToNext`).
- 세션 관련은 **`WaveService.getHudInfo`** → 같은 페이로드의 `SecondsLeft` / **`SecondsLeftFloat`**, `SessionActive`.
- **즉시성:** `MainServer`에서 **`ProgressionService.setImmediateHudPush`** 로 레벨업 직후 `HudSyncService.pushToPlayer`를 한 번 더 호출해, 순수 주기 전송만 쓸 때보다 HUD가 빨리 맞춰진다.
- **잔여 지연:** 네트워크·프레임에 따라 아주 짧은 차이는 남을 수 있음.

### 7) B단계에서 손댈 가능성이 큰 파일 목록

- **`HUDClient.lua`** — 새 필드 표시·레이아웃·(필요 시) 이벤트 추가 구독.
- **`HudSyncService.lua`** — `FireClient` 페이로드 확장 (예: 업그레이드 요약, 킬 수, `SessionActive` 외 상태).
- **`ProgressionService.lua`** — `getHudProgress` 확장; 즉시 HUD는 이미 **`setImmediateHudPush`** 패턴 사용.
- **`GameConfig.lua`** — HUD 주기(`HudSyncIntervalSeconds`) 등.
- **`MainServer.server.lua`** — 새 서비스 연결 시에만 (대부분 기존 모듈 확장으로 충분).
- (선택) **`WaveService.lua` / 기타** — HUD에 넣을 **세션·전투 부가 지표**가 늘면 해당 서비스에서 `HudSync`가 읽을 값 확장.

**반드시 아닐 수 있음:** `LevelUpClient` (선택 UI), `CombatService`/`EnemyService` — HUD가 “판정 결과 표시”만 한다면 직접 연결 불필요.

---

## 3. 데이터 흐름 요약

```
[서버] XP 오브 → XpPickupService.addExperience
        → ProgressionService (level/xp/upgrades)
        → (레벨업 시) LevelUpChoiceRequest → [클라] LevelUpClient
        → LevelUpChoiceSubmit → ProgressionService (upgrades++)

[서버] HudSyncService (Heartbeat 간격) + ProgressionService 레벨업 시 pushToPlayer
        → getHudProgress + WaveService.getHudInfo (remainingFloat 포함)
        → HudState:FireClient(payload)
        → [클라] HUDClient (라벨·바 갱신)
```

---

## 4. HUDClient 연결 전략 (분석 수준 제안)

- **기본:** 계속 **`HudState`를 단일 진실 소스**로 두고, B단계에서 필요한 지표는 **`HudSyncService`의 테이블 확장 + `HUDClient` 표시만** 추가하는 쪽이 구조와 맞음.
- **즉시 반응**(예: 레벨업 직후 바): 현재는 **`ProgressionService.setImmediateHudPush` → `HudSyncService.pushToPlayer`** 로 처리.
- **업그레이드 수치를 HUD에 넣을 때:** 서버의 `getUpgradeCounts`를 `HudSyncService`가 포함해 내려주는 방식이 “판정 서버·표현 클라” 원칙에 맞음.

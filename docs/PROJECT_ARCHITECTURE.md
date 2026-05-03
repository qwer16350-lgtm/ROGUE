# ROGUE 프로젝트 구조·호출 플로우 요약

Rojo 레포(`src` + `default.project.json`) 기준 정리.

---

## 1. Rojo 트리 (파일이 어디로 매핑되는지)

| 영역 | 경로 | 역할 |
|------|------|------|
| 서버 로직 | `src/ServerScriptService/` | 전투·웨이브·진행·HUD 동기화·XP 등 |
| 공유 데이터/설정 | `src/ReplicatedStorage/Shared/` | `GameConfig`, `StageData`, `UpgradeData`, `Utils` 등 |
| 클라 엔트리 | `src/StarterPlayer/StarterPlayerScripts/` | `MainClient` → 각 `*Client.init()` |
| (선택) StarterGui | `src/StarterGui/` | 프로젝트에 경로 있음 — 내용은 레포에 없을 수 있음 |
| VFX·원격 일부 | `default.project.json`의 `ReplicatedStorage.VFX`, `Remotes.VFXEvent`, `Remotes.StageFlowRequest` | VFX 재생 / 층 전환 요청 |

**참고:** `HudState`, `LevelUpChoiceRequest`, `LevelUpChoiceSubmit`, `SessionResult`는 `default.project.json`에 없을 수 있으며, **서버 모듈이 없으면 런타임에 `ReplicatedStorage`에 생성**한다.

### 스테이지 MVP (최소 흐름)

- **데이터:** `Shared/StageData.lua` — 층별 스폰 Part 이름·오리진·(선택) 세션 길이 오버라이드. 전역 규칙은 `GameConfig`.  
  - **층별 그런트 간격 Start/End** — `StageData.getSpawnProfile` → `sess.spawnProfile` 캐시(`startStage`), Heartbeat는 램프만 `GameConfig` 유지. 상세 **`docs/STAGE_SPAWN_LOGIC_PLAN.md`**.
- **소유:** `WaveService` — 세션 시작/종료, `pendingAdvance`, `StageFlowRequest` 처리(`handleStageFlowRequest` → `startStage` / `teleportPlayersToStage` / `applyStageSpawnOrigin` 등 로컬 헬퍼), 직후 **`HudSyncService.pushToPlayer` 전원 호출**.
- **연결:** `MainServer`는 `Remotes.StageFlowRequest` → `WaveService.onStageFlowRequest`만 연결.
- **클라:** `ResultClient` — `SessionResult`의 `CanAdvance`일 때만 “다음 층” 활성 → `{ Action = "NextStage" }` 전송; “나가기”는 `{ Action = "Exit" }`.
- **성장:** `ProgressionService`는 층 전환 시 초기화하지 않음.

### Run / Stage floor transition (층 전환 요약)

- **V1:** 다음 층 진행 요청은 **`StageFlow`** 쪽에서 허용/거부를 판별한 뒤, **`Teleport.toFloor`** 로 **동일 Stage Place의 새 reserved 서버**에 재진입하는 방식이다.
- **같은 서버 인스턴스 안에서만** 층을 바꾸는 전환은 **현재 비목표**이며, 실제 이동은 향후 전환 서비스로 빼내는 교체 가능성만 열어 둔다.
- 자세한 규칙(SSOT): **`docs/STAGE_FLOOR_TRANSITION_AND_SCOPE.md`**.

---

## 2. 서버 부팅 순서 (`MainServer.server.lua`)

의존 관계에 맞춘 `init` 호출 순서 (실제 코드와 동일).

1. **EnemyService** — 적 스폰·이동·처리(Heartbeat 등).
2. **PlayerContactDamageService** — `EnemyService.getEnemyEntries()` 기반 근접 피해·플레이어 스폰 시 `MaxHealth`/`Health` 설정 (`GameConfig.PlayerBaseHealth`).
3. **ProgressionService** — 플레이어당 레벨·XP·업그레이드 스택; `LevelUp*` 리모트 생성·제출 처리.
4. **XpPickupService** — 워드 XP 오브 근접 시 `ProgressionService.addExperience`; `clearAllOrbs()`는 층 전환 시 `WaveService`가 호출.
5. **WaveService** — 세션·보스·`SessionResult`·`getHudInfo()`·`StageFlowRequest` 처리; `bindHudPushContext`로 HUD 푸시 의존성 주입.
6. **HudSyncService** — `HudState` 주기 전송 + `pushToPlayer` 헬퍼.
7. **ProgressionService.setImmediateHudPush** — 레벨업 직후 `HudSyncService.pushToPlayer` 한 번 더 호출(주기보다 빠른 HUD 반영).
8. **CombatService** — 플레이어 자동 공격, 적 피해·사망, 킬 시 오브 스폰·`WaveService.recordKill()`·VFX 이벤트.
9. **`Remotes.StageFlowRequest`** — `MainServer`에서 `WaveService.onStageFlowRequest`에만 연결.

**데이터 주체:** 진행도·XP·업그레이드는 **서버 `ProgressionService` 메모리 테이블**이 단일 소스다.

---

## 3. 클라이언트 부팅 (`MainClient.client.lua`)

1. **HUDClient** — `MainHUD` → `HUDFrame`(레벨·XP·HP) + `TimerBarRoot`(타이머). **`HudState`**로 서버 동기화 수치; HP는 **`Humanoid`** 복제값 기준(바·라벨은 표시 보간 등 클라 전용 처리).
2. **VFXClient** — `Remotes.VFXEvent` 구독, `ReplicatedStorage/VFX` 프리팹 클론.
3. **LevelUpClient** — `MainHUD` → `LevelUpFrame` → `OptionsContainer` 버튼. **`LevelUpChoiceRequest`**로 표시, **`LevelUpChoiceSubmit`**으로 `Id` 전송.
4. **ResultClient** — **`SessionResult`** 수신 시 결과 패널; `CanAdvance` 시 “다음 층” → `StageFlowRequest`(`NextStage` / `Exit`).

---

## 4. 호출 플로우

### 전투·XP

```
CombatService (Heartbeat)
  → 적 탐색·피해
  → 사망 시: XpPickupService.spawnAt, WaveService.recordKill, VFXEvent

XpPickupService (Heartbeat)
  → 플레이어와 오브 거리
  → ProgressionService.addExperience(player, amount)
```

### 진행·레벨업·HUD

```
ProgressionService.addExperience
  → XP/레벨 루프
  → 레벨업 시: LevelUpChoiceRequest:FireClient({ Level, Choices })
            + immediateHudPush → HudSyncService.pushToPlayer

HudSyncService (Heartbeat 주기 + pushToPlayer)
  → HudState:FireClient({ Level, Xp, XpToNext, SecondsLeft, SecondsLeftFloat, SessionActive, SessionLengthSeconds })
  → HUDClient가 UI 반영 (`SecondsLeftFloat`는 연속 타이머용, `SecondsLeft`는 정수 초·호환)

LevelUpClient (버튼 클릭)
  → LevelUpChoiceSubmit:FireServer(choiceId)
  → ProgressionService: 검증 후 state.upgrades[id] += 1
```

### 세션·결과·VFX

```
WaveService (Heartbeat)
  → 시간·보스·전멸 등 판단
  → endSession → SessionResult:FireClient(통계·FinalLevel·Upgrades·CanAdvance 등)
  → ResultClient

ResultClient → Remotes.StageFlowRequest:FireServer({ Action = "NextStage" | "Exit" })
  → MainServer → WaveService.onStageFlowRequest (검증·오브 정리·텔레포트·새 세션·pushToPlayer 전원)

CombatService (공격 시)
  → VFXEvent:FireAllClients
  → VFXClient 재생
```

---

## 5. 역할 매트릭스

| 구분 | 관리 주체 | 내용 |
|------|-----------|------|
| 밸런스·상수 | `GameConfig` | 세션 길이, 피해량, 스폰 간격, XP 오브량, HUD 동기화 주기 등 |
| 업그레이드 정의 | `UpgradeData` | `Choices`(Id·Label), `Effects` — 예: `damage_up`, `attack_interval_down`, `attack_size_up`; `CombatService`·`getEffectiveCombatStats`와 연동 |
| 레벨/XP/선택 스택 | `ProgressionService` | 서버 권한; 클라는 표시·요청만 |
| 플레이어 근접 피해 | `PlayerContactDamageService` | 서버만 `TakeDamage`; `GameConfig.EnemyContact*` |
| 남은 시간·웨이브 | `WaveService` | `getHudInfo()` (`remaining`·`remainingFloat`) → `HudSyncService` |
| HUD 수치 표시 | `HUDClient` | `HudState` + Humanoid HP |
| 레벨업 UI | `LevelUpClient` | 선택지 표시·제출만 |
| 이펙트 | 서버 `CombatService` + 클라 `VFXClient` | 위치/종류 신호 vs 재생 |
| 게임 오버/결과 | `WaveService` 발행 | `ResultClient` 표시 |

---

## 6. 원칙

- **판정·상태:** 서버 서비스(`Progression`, `Wave`, `Combat`, `XpPickup`, `Enemy`, `PlayerContactDamage`).
- **표현:** 클라이언트 모듈이 리모트·Humanoid만 구독해 UI·VFX·결과 창 처리.
- **엔트리:** `MainServer` / `MainClient`는 연결만 담당하고 본 로직은 각 `*Service` / `*Client`에 분산.

---

*생성 시점: 대화 맥락 기준 ROGUE Rojo 레포 구조. 경로·이름 변경 시 문서도 함께 갱신할 것.*

# 개발 로그 · 요약

일자별로 “무슨 의도로 무엇을 바꿨는지”만 짧게 남긴다. 상세 플로우는 `PROJECT_ARCHITECTURE.md`와 각 `docs/*.md`를 본다.

---

## 프로젝트 전체 요약 (현재 상태)

ROGUE는 **Rojo**로 `src`를 Roblox에 동기화하는 로그라이트형 구조다.

- **플레이스 분리:** 로비용 **LobbyPlace**와 플레이(맵·전투)용 **StagePlace**를 나누고, 단일 진실 소스는 `ReplicatedStorage/Shared/Run/RunConstants.lua`의 `LobbyPlaceId` · `StagePlaceId`이다. `MainServer.server.lua`가 `game.PlaceId`로 분기해 **로비 분기에서는 스테이지 전용 서비스를 require 하지 않는다**(메모리·부팅 절약).
- **워크스페이스 구성 분리:** Rojo 단일 트리로 sync 되므로 `MainServer`가 Place별로 불필요한 루트만 제거한다. 로비에서는 `Workspace.Map` 제거, 스테이지에서는 `Workspace.Lobby` 제거 후 스테이지에서만 `Players.CharacterAutoLoads = false`, `StageBootstrap`에서 맵 생성·`LoadCharacter` 순서 제어.
- **런 플로우:** `Run/Teleport.lua`가 로비→1층 reserved, 층 이동, 로비 복귀를 담당한다. `Lobby/LobbyBootstrap.lua`·`Run/StageBootstrap.lua`·`RunContext`·`StageFlow`가 입장·세션·복귀와 맞물린다.
- **스테이지 게임 루프:** `EnemyService` → `PlayerContactDamageService` → `ProgressionService` → `XpPickupService` → `WaveService` → `HudSyncService` → `CombatService` 순으로 부팅·연결(`MainServer` 스테이지 분기). 전투·XP·웨이브·HUD는 **서버가 판정**, 클라는 `MainClient`가 `HUDClient`·`VFXClient`·`LevelUpClient`·`ResultClient`로 표현만 담당.
- **체력:** 플레이어 기본 HP는 `GameConfig.PlayerBaseHealth`, 스폰 시 `PlayerContactDamageService`가 Humanoid에 반영. HUD는 `HUDClient`가 Humanoid 복제값으로 바·라벨 표시(기본 Roblox 체력 UI 억제). **체력 회복 오브**는 `HealthPickupService`가 `Workspace/HealthOrbs` 아래 Part(`HealthOrb`)로 스폰하고, 적 사망 시 `CombatService`가 확률(`GameConfig.HealthOrbDropChance`)로 드랍하며 XP 오브와 배타 롤을 탄다.

---

## 2026-05-01

**한 줄:** 로비·스테이지 **구성·플레이스 분리**를 코드로 고정했고, **체력(회복) 오브**를 스테이지 루프에 연결했다.

**구체적으로:**

| 영역 | 내용 |
|------|------|
| 플레이스 분리 | `RunConstants`에 로비·스테이지 PlaceId 단일 관리 → `MainServer`에서 분기별 `require`/부팅 경로 분리 |
| 로비·스테이지 월드 분리 | 로비에서 `Map` 파기, 스테이지에서 `Lobby` 파기 + 스테이지 전용 `CharacterAutoLoads=false` 및 `StageBootstrap` 흐름 |
| 텔레포트·런 컨텍스트 | `Teleport`/`RunContext`/`LobbyBootstrap`/`StageBootstrap`/`StageFlow`와 `ResultClient`의 로비 복귀 등으로 멀티플레이스 플로우 정리 |
| 체력 오브 | `HealthPickupService` + `GameConfig`의 HealthOrb 관련 키 + `CombatService`·`WaveService` 바인딩으로 킬 드랍·픽업 회복 |

**참고:** 원격 저장소 초기 푸시·Cursor 훅·`RunConstants` Place ID 갱신 등은 초기 커밋 범위에 포함됨.

---

*이 파일은 수동으로 날짜 섹션을 추가·갱신한다.*

# 플레이어 접촉 피해 — 구현 계획

`STRUCTURE_CLEANUP_PLAN.md` / `PROJECT_ARCHITECTURE.md` 원칙에 맞춤:

- **서버만** 체력 감소 판정 (`Humanoid:TakeDamage` 등).
- **클라 `HUDClient`에는 접촉 판정을 넣지 않음** — HP **표시**는 `Humanoid` 복제 + (선택) 바·라벨 보간·기본 Health UI 억제 등 **표현만** 변경 가능.
- **새 RemoteEvent 불필요** (체력 수치는 Replication).

---

## 현재 상태

- 적 Part는 `Anchored` + `GameConfig.EnemyPartCanCollide`로 **물리 충돌 가능**.
- 플레이어 피해는 **`PlayerContactDamageService`** 가 HRP~적 중심 **거리**로 판정 (`EnemyContactReachStuds` 등).

---

## 설계 요약

| 항목 | 제안 |
|------|------|
| 판정 위치 | **서버 전용** 새 모듈 `PlayerContactDamageService.lua` (또는 `EnemyService` 하위 로직 — 파일 분리 권장) |
| 판정 주기 | `RunService.Heartbeat` 또는 기존 `EnemyService` 루프와 **한 번만** 돌리기(중복 루프 방지) |
| “닿음” 정의 | 적 Part 중심과 `HumanoidRootPart` 거리 ≤ **접촉 거리** (반지름: 적 크기·플레이어 대략 2studs 등 `GameConfig`로) |
| 피해량 | `GameConfig` 예: `EnemyContactDamagePerTick` |
| 연속 피해 방지 | **플레이어당 쿨다운** `EnemyContactDamageCooldownSeconds` — 같은 플레이어에게는 쿨다운 내 1회만 피해 |
| 보스/그런트 | 동일 규칙 또는 `EnemyContactDamageBossMultiplier` (선택) |

---

## `GameConfig.lua` 추가 필드 (안)

```lua
-- 플레이어 피해 (적과 근접)
EnemyContactDamagePerTick = 8,
EnemyContactDamageCooldownSeconds = 0.5,
EnemyContactReachStuds = 3, -- HRP~적 Part 거리 기준 (반경 보정은 코드에서 Size 반영 가능)
```

(수치는 밸런스 조정용 placeholder.)

---

## 캐릭터 최대 체력

- **`PlayerContactDamageService`** 가 캐릭터 연결 시 `MaxHealth` / `Health` 를 `GameConfig.PlayerBaseHealth` 로 맞춤 (현재 구현).

---

## `MainServer.server.lua` 초기화 순서

- `EnemyService.init` 이후, `EnemyService.getEnemyEntries()` 가 유효할 때:
  - `PlayerContactDamageService.init(Players, RunService, GameConfig, EnemyService)`

`CombatService`와 독립 — 플레이어→적 피해와 적→플레이어 피해 분리 유지.

---

## 하지 않을 것 (이번 범위)

- 클라에서 체력 직접 수정.
- `Touched` 이벤트 (적이 non-collide이므로 의미 없음).
- `default.project.json` 변경.

---

## 구현 체크리스트

1. [x] `GameConfig` 필드 추가  
2. [x] `PlayerContactDamageService.lua` — Heartbeat 거리·쿨다운·`TakeDamage`  
3. [x] 캐릭터 스폰 시 `MaxHealth`/`Health` = `PlayerBaseHealth`  
4. [x] `MainServer` — `EnemyService.init` 직후 `PlayerContactDamageService.init`  
5. [ ] 플레이 테스트: 다수 적·보스·쿨다운·게임오버(`WaveService`) 연동 — **Studio에서 직접 확인 후 체크**

---

*구현 반영됨. 밸런스는 `GameConfig`의 `EnemyContact*` / `PlayerBaseHealth`로 조정.*

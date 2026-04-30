# 층별 스폰 — 조정된 계획 (골격 우선, 구현은 최소)

## 0. 방향 (한 번에 정리)

- **확장 가능한 최소 골격**은 지금 잡되, **완성형 범용 시스템**(적 종류 전부·이벤트 DSL·복잡한 패턴 엔진)은 만들지 않는다.
- **미래에 붙일 자리**만 남기고, **이번 단계 코드는 필요한 만큼만** 쓴다.
- **DSL / 스크립트형 패턴 / 과한 일반화** 금지.

---

## 1. 역할 (4층 구조 — 고정)

| 레이어 | 책임 |
|--------|------|
| **`GameConfig`** | 전역 기본값(fallback). 기존 `WaveGruntSpawnIntervalStart` / `End` 및 램프 관련 키 유지. |
| **`StageData`** | **데이터만.** 층 행(row)에 optional 필드. **함수는 “읽기/합치기” 수준**(`getSpawnProfile` 정도)만 두고, 스폰 타이밍 **로직·판정은 넣지 않는다.** |
| **`WaveService`** | `startStage`(또는 세션 시작 시점)에 **한 번** 합쳐진 **spawn profile**을 세션 상태에 **캐시**하고, Heartbeat에서는 **캐시만** 읽어 간격·흐름을 계산한다. |
| **`EnemyService`** | **실제 Part 생성·기준점**만. 스폰 타이밍 재작성 없음(기존 `spawnGrunt` / `spawnBoss` 유지). |

---

## 2. 핵심 원칙

1. **`StageData` = 데이터 + 얕은 getter** — “언제 몇 마리” 같은 **규칙 실행은 Wave**가 한다.
2. **`WaveService` = profile 해석기** — `GameConfig`와 층 row를 **merge한 결과**를 `sess`(또는 동등 세션 테이블)에 넣고 사용.
3. **프로필은 `startStage` 시점에 한 번 계산·캐시** — Heartbeat마다 `StageData`를 다시 merge하지 않는다(가벼움·일관성).
4. **`EnemyService`** — 지금처럼 **월드 오프셋 주입** 정도만 최소 확장; 스폰 로직 전체 재작성 금지.

---

## 3. 이번 단계에서 **실제로 구현한 것** (범위)

| 항목 | 내용 |
|------|------|
| API | **`StageData.getSpawnProfile(gameConfig, stageIndex)`** — 반환 테이블에 **`GruntIntervalStart` / `GruntIntervalEnd`** 및 (선택) **`EliteGruntEnabled`**, **`EliteGruntHealthMultiplier`**, **`EliteGruntSpawnIntervalMul`** 를 **명시적으로만** 채움(범용 merge 유틸 아님). |
| 층별 필드 | Stage row optional **`GruntIntervalStart` / `GruntIntervalEnd`**. 없으면 `GameConfig.WaveGruntSpawnIntervalStart` / `End`. 엘리트는 아래 3.1·2층 row 참고. |
| Wave | **`startStage`**에서 프로필 계산 → **`sess.spawnProfile`** 캐시. Heartbeat는 캐시만 사용(일반·엘리트 간격). **램프**는 `GameConfig` + init 시 기본값 보정만(층별 오버라이드 없음). |
| 예시 | **2층 row**에 다른 Start/End + 엘리트 필드(테스트용). |

보스 등장 시점·첫 그런트 횟수·보스 중 스폰 등은 **추가 구현 없음**(기존 `WaveService` 동작 유지).

### 3.1 2층 엘리트 그런트 (e2, 최소 범위)

- **층:** 2층 row에만 `EliteGruntEnabled = true` 등 필드. 1층 등은 엘리트 없음.
- **구분:** Part `Name`은 일반과 동일 `"Enemy"`. `SetAttribute("IsElite", true)`(일반은 `false`)로 구분.
- **외형:** 크기 `EnemyGruntSize * 1.3`(고정 배율), 노란색 틴트.
- **체력:** `EnemyBaseHealth * EliteGruntHealthMultiplier`(2층 예: 1.5).
- **간격:** 일반 그런트와 **같은** `effectiveInterval`을 쓰되, 엘리트는 `effectiveInterval * EliteGruntSpawnIntervalMul`(2층 예: 10배)마다 1마리. 보스 스폰 분기 이후에는 일반과 같이 스폰 없음.

---

## 4. 이번 단계에서 **구현하지 않는 것** (확장 포인트로만 문서에 남김)

아래는 **테이블에 필드를 미리 적어두지 않아도 됨**. 나중에 같은 `getSpawnProfile` merge 패턴으로 붙이면 된다.

| 확장 후보 | 비고 |
|-----------|------|
| `InitialGruntCount` | 층 시작 직후 추가 그런트 |
| `GruntRampEverySeconds` / `Multiplier` / `MinInterval` | 층별 램프 오버라이드 |
| `BossSpawnAtElapsedFraction` | 세션 중간 보스 등 |
| `SpawnGruntsWhileBoss` | 보스 페이즈 잡몹 |
| 적 종류 믹스 / 이벤트형 스폰 / `EnemyId` | 별 트랙으로 설계 예정, 이번 범위 밖 |

---

## 5. 현재 상태와의 차이 (baseline)

- 지금: Heartbeat가 **항상 `GameConfig`의 Start/End**만 사용.
- 이후: Heartbeat는 **`sess.spawnProfile`에 캐시된 Start/End**(층에서 오버라이드했으면 그 값)를 사용. **램프 식·보스 분기 파일 구조는 유지**, 숫자 소스만 분기.

---

## 6. 하지 않을 것 (전역)

- 클라이언트가 스폰 타이밍 결정.
- 문자열 DSL·`loadstring`·외부 패턴 스크립트.
- `EnemyService` 대규모 리라이트.

---

## 7. 문서·코드 연동

- 구현 후 `PROJECT_ARCHITECTURE.md`에 **한 줄**: 그런트 간격의 층별 출처가 `StageData.getSpawnProfile` + `WaveService` 캐시임을 명시.
- 문서 인덱스: `CURSOR_WORKFLOW.md` §2에 이 파일 등록됨. 팀 진입점은 루트 `AGENTS.md`.

---

## 8. 승인 후 구현 시 체크리스트

- [ ] 1층: `StageData`에 Start/End 생략 시 **지금과 동일** 간격.
- [ ] 2층: 예시 값만 다르게 해 **체감 차이** 확인.
- [ ] `NextStage` → `startStage` 경로에서 **프로필 재캐시**됨.
- [ ] Heartbeat에서 **`getSpawnProfile` 재호출 없음**(캐시만 사용).
- [ ] 2층: 엘리트는 `IsElite` 속성·크기 1.3·체력 배율·간격 10× `effectiveInterval`로 동작, 보스 이후 스폰 없음.

---

*이 문서 = 조정된 계획. 코드 변경은 별도 승인 후.*

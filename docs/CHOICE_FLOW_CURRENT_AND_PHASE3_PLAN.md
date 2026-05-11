# Choice Flow: Current Structure & Phase 3 Planning Notes

이 문서는 **`ProgressionService`의 ChoiceKind·pending 구조**를 정본으로 기록하고, Phase 3에서 선택 종류가 늘어날 때의 리팩터링 방향만 제안한다.  
**본 문서만으로 게임 동작이나 코드가 변경되지 않는다.**

---

## 1. Current ChoiceKind List

서버가 `LevelUpChoiceRequest`로 클라이언트에 보내는 payload에 설정되는 `ChoiceKind` 값은 현재 아래 세 가지다.

| ChoiceKind | 용도 |
|------------|------|
| **Upgrade** | 레벨업 시 표시되는 업그레이드 3선택 (큐 flush 또는 즉시 오퍼) |
| **DroppedRelic** | SwordShield 런에서 드랍 유물 상자 조건 충족 후 표시되는 선택 |
| **StartingWeapon** | 스테이지 진입 등에서 호출되는 **테스트용** 무기 3택1 |

**StartingRelic (Stage fallback):** Lobby에서 유물을 선택하고 TeleportData로 전달하는 구조로 통일되었으며, **Stage에서 `ChoiceKind == "StartingRelic"` 오퍼를 띄우던 레거시는 제거 완료**다. StartingRelic 선택 UI는 Lobby 경로에서만 다룬다.

---

## 2. Current Submit Contract

### 서버 → 클라이언트 (`LevelUpChoiceRequest`)

- 서버는 **`LevelUpChoiceRequest` RemoteEvent**로 테이블 payload를 보낸다.
- payload에는 다음 필드가 **조합되어** 들어갈 수 있다.
  - **`ChoiceKind`**: 어떤 종류의 선택인지 구분 (문자열)
  - **`Title`**: 커스텀 제목 (없으면 클라이언트 기본 문구)
  - **`Level`**: 업그레이드 등 레벨 표시용 (일부 Kind에서 생략 가능)
  - **`Choices`**: `{ Id, Label }` 목록 (보통 최대 3개와 UI 버튼 매칭)

### 클라이언트 (`LevelUpClient`)

- **`ChoiceKind`는 로그 및 제목 보조(커스텀 Title 등) 용도로만 사용**한다.
- 선택 버튼 클릭 시 **`LevelUpChoiceSubmit`에 `choiceId` 문자열만** `FireServer` 한다.
- **`ChoiceKind`를 submit payload에 포함하지 않는다.**

### 서버 수신 (`LevelUpChoiceSubmit`)

- 서버는 **클라이언트가 보낸 `choiceId`만** 받는다.
- **현재 열려 있어야 하는 오퍼는 `pending*` 테이블의 존재 여부로 판별**하고, 그에 따라 submit을 라우팅한다.
- 즉 **submit 계약상 “어떤 모달이었는지”는 클라이언트가 명시하지 않고, 서버 pending 상태가 단일 진실 소스**다.

---

## 3. Current Pending Tables

형태: 각 테이블은 **`{ [Player]: { [choiceId: string]: boolean } }`** 에 가까운 “허용된 선택지 집합” 역할을 한다.

### `pendingLevelUpOfferByPlayer`

| 항목 | 설명 |
|------|------|
| **생성** | `flushUpgradeOfferQueue`에서 큐에서 레벨을 꺼낸 뒤 `buildOfferForPlayer` 결과로 설정; `addExperience`에서 다른 활성 pending이 없을 때 즉시 업그레이드 오퍼와 함께 설정 |
| **소비** | Upgrade 선택이 정상 적용되면 `nil`; 플레이어 퇴장 시 `nil` |
| **PlayerRemoving** | `nil`로 정리됨 |
| **상호 배제** | 다른 pending(`DroppedRelic`, `StartingWeapon`) 또는 자기 자신(이미 업그레이드 대기 중)이 있으면 flush 등으로 **새 업그레이드 오퍼를 건너뜀** |

### `pendingDroppedRelicByPlayer`

| 항목 | 설명 |
|------|------|
| **생성** | `tryFlushDroppedRelicOffer`에서 조건 충족 시 `RelicData.getDroppedRelicChoices()` 기반으로 허용 집합 구축 후 설정 |
| **소비** | DroppedRelic 제출 처리 후 `nil`; BasicMagic sanitize 등에서 `nil`; 퇴장 시 `nil` |
| **PlayerRemoving** | `nil`로 정리됨 |
| **상호 배제** | flush·다른 오퍼 진입 전에 **동시에 하나의 “모달 계열” pending**만 유지하도록 가드 |

### `pendingStartingWeaponByPlayer`

| 항목 | 설명 |
|------|------|
| **생성** | `tryOfferStartingWeapon`에서 고정 3무기 허용 집합 설정 후 오퍼 발송 |
| **소비** | StartingWeapon 제출 후 `nil`; BasicMagic sanitize 등에서 `nil`; 퇴장 시 `nil` |
| **PlayerRemoving** | `nil`로 정리됨 |
| **상호 배제** | 다른 pending 또는 자기 중복 오퍼 방지 가드와 함께 사용 |

---

## 4. Current Submit Priority

`LevelUpChoiceSubmit` **`OnServerEvent` 내 처리 순서**는 다음과 같다. **이 순서가 라우팅의 실질적 우선순위다.**

1. **DroppedRelic** (`pendingDroppedRelicByPlayer`가 있으면 이 분기만 처리)
2. **StartingWeapon** (`pendingStartingWeaponByPlayer`)
3. **Upgrade** (`pendingLevelUpOfferByPlayer` 및 `allowedChoiceIds` 기반 업그레이드 로직)

클라이언트가 Kind를 보내지 않으므로, **동일 `choiceId`가 이론상 여러 맥락에 겹칠 경우에도 서버는 위 순서로 먼저 매칭되는 pending이 승리**한다. 새 ChoiceKind를 추가할 때는 **이 순서와 충돌 여부를 반드시 검토**해야 한다.

---

## 5. Current Problems & Limits

- **확장 비용:** 새 `ChoiceKind`마다 pending 저장소·`submit` 상단 분기·flush 가드가 **선형으로 늘어날 수 있다.**
- **서버만 pending으로 맥락 추론:** 클라이언트가 Kind를 보내지 않아 **디버깅·악성/지연 제출 구분**이 어렵고, 분기 순서에 **암묵적 의존**이 생긴다.
- **업그레이드 예외 경로:** pending 없이 `allowedChoiceIds`만 맞는 제출은 대부분 경고 후 거절에 가깝게 동작 — 의도된 방어이나 구조상 혼동 여지가 있다.
- **Phase 3 신규 종류:** ClassChoice, RelicRewardChoice, BlueprintChoice, FloorRewardChoice 등이 들어오면 **pending 종류·우선순위·flush 규칙**이 한 파일 안에서 복잡해지기 쉽다.

위 한계는 **Phase 2 MVP~Phase 3 진입 전 시점에서 인지하고 문서화만** 해 두는 것이 목적이다.

---

## 6. Phase 3 Refactor Options (비교만, 즉시 실행 아님)

### Option A — `ProgressionService` 내부 local helper만 추가

- 예: `hasActiveChoicePending(player)`, `clearChoicePendingsOnLeave(player)`, **`ChoiceKind` 문자열 상수화**
- **장점:** 파일 추가 없음, diff 작고 회귀 범위 통제 용이  
- **단점:** 여전히 단일 모듈 비대  
- **위험도:** **낮음** — Phase 3 초반 “소형 정리”에 적합

### Option B — `ServerScriptService/Progression/ChoiceFlow.lua` 신규 모듈

- pending registry·submit routing **일부**를 모듈로 분리  
- **장점:** 신규 Kind 추가 시 확장면이 한곳으로 모일 수 있음  
- **단점:** 초기 이동 범위·연결 부담  
- **위험도:** **중간** — **Phase 3에서 첫 신규 ChoiceKind를 넣을 마일스톤**에서 검토하는 것이 자연스럽다.

### Option C — choice별 모듈 분리 (`UpgradeChoice.lua` 등)

- **장점:** 도메인 경계가 명확해질 수 있음  
- **단점:** 파일·인터페이스 증가, 태그/보상 설계 전 조기 분할 시 비용 대비 이득이 작을 수 있음  
- **위험도:** **중~높음** (설계 미정 상태에서의 과분할) — **Phase 3 후반·도메인 스펙 안정 후** 검토

---

## 7. Recommended Timing

| 시점 | 권장 |
|------|------|
| **Phase 3 진입 전** | **문서화(SSOT)**까지 — 본 문서 및 `ProgressionService` 변경 없이 운영 원칙만 고정 |
| **Phase 3 초** | **Option A** 수준의 소형 헬퍼·상수화 검토 (동작 동일 조건) |
| **Phase 3 첫 신규 ChoiceKind 추가** | **Option B** 검토 (필요 시에만 모듈 도입) |
| **Phase 3 후반** | 도메인·태그·보상 구조가 안정화되면 **Option C** 검토 |

---

## 8. Explicit Rules

1. **지금 당장 `ChoiceFlow.lua`를 만들지 않는다.** (본 문서는 계획용이며 파일 생성을 요구하지 않는다.)
2. **지금 당장 choice별 모듈로 분리하지 않는다.**
3. **Upgrade 큐, DroppedRelic 상자 흐름, StartingWeapon의 `activeWeapons` 교체 로직**은 도메인 규칙이 다르므로 **무리하게 한 추상으로 묶지 않는다.**
4. **새 ChoiceKind를 코드에 추가할 때**는 반드시 **submit 우선순위·pending 상호 배제·flush 조건**을 본 문서 또는 후속 SSOT에 **갱신**한다.
5. **클라이언트 submit에 `ChoiceKind` 또는 correlation id를 추가하는 것**은 계약 변경이므로 **별도 PLAN·승인 후** 진행한다.

### 왜 지금 ChoiceFlow를 분리하지 않는가

- Phase 3에서 선택·보상 **종류와 트리거가 확정되기 전**에 추상화하면 오히려 **잘못된 경계**가 굳어진다.
- 현재 동작은 **명시적 pending 순서**로 안정적으로 동작하므로, **문서와 타이밍(옵션 A→B)만으로도 진입 리스크를 줄일 수 있다.**

---

## 산출 메타

| 항목 | 내용 |
|------|------|
| 정본 코드 | `src/ServerScriptService/ProgressionService.lua` (본 문서는 기준 시점 스냅샷 설명) |
| 범위 밖 | CombatService, VFXClient, MapService, RelicData, UpgradeData 코드 변경 없음 |

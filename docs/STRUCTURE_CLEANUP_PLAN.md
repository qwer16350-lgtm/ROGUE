# ROGUE 구조 정리안 — MainHUD·클라 고정 (스코프 버전)

**전체 방향:** Studio 임시 흔적을 줄이고 **유지보수 단일 기준 = Rojo `src/`**. 서버 판정 / 클라 표현 분리, **HUDClient ↔ LevelUpClient 분리 유지**.

---

## 이번 작업 범위 (이 문서의 메인)

**이번에 다루는 것**

1. Studio 임시 LocalScript **제거/비활성화 기준** 정리  
2. **최신 `default.project.json`** 기준 **StarterGui 매핑** 재확인  
3. **`src/StarterGui`에 MainHUD 자산**을 Rojo 진실 소스로 두는 **방법 제안**  
4. **HUDClient / LevelUpClient / MainClient** 구조 **유지** (역할 합치지 않음)  
5. **MainHUD 하위 이름**이 코드와 일치하는지 **점검 항목** 제시  

**이번에 하지 않는 것 (문서 본문에서 분기)**

- `default.project.json`에 **RemoteEvent 명시** 추가  
- **ResultClient** 자산형 전환  
- **미사용 파일 대청소** (예: `Utils.lua` 등 — 범위 밖에서 정리)  

장기 항목은 문서 말미 **「부록: 범위 밖 정리」** 에만 남긴다.

---

## 1. Studio 임시 LocalScript — 제거 vs 비활성화 기준

| 조치 | 이렇게 판단할 때 |
|------|------------------|
| **제거(삭제)** | `StarterGui` / `MainHUD` 아래에 있고, **Rojo `StarterPlayerScripts`에 대응 로직이 이미 있는** 경우. (예: 예전 `addXP` 루프, 로컬 레벨업, `HudState`와 무관한 XP/타이머 테스트.) |
| **제거(삭제)** | **엔트리가 중복**인 경우: 이미 `MainClient.client.lua`가 `HUDClient`·`LevelUpClient`를 켜는데, GUI 밑에 또 HUD/레벨업을 건드리는 LocalScript. |
| **비활성화(`Disabled = true`)** | 당장 삭제가 부담스럽지만 **실행되면 안 될 때** 임시 차단. 단, **장기적으로는 삭제**하고 Rojo 쪽만 남기는 것이 권장. |
| **유지** | **에디터 전용**(플레이에 `Disabled`이거나 `RunContext`가 Client인데 실제로 빈 스크립트만 있는 등) 드물게만. 일반적으로 **MainHUD 아래 클라 로컬 스크립트는 두지 않음**. |

**원칙:** 한 화면(HUD/레벨업)에 대해 **진실 소스는 `src/StarterPlayer/StarterPlayerScripts`의 모듈 하나**만 두고, Studio GUI 트리에는 **자산만** 둔다.

---

## 2. `default.project.json` 기준 StarterGui 매핑 (재확인)

**현재 레포 기준** (파일 그대로 요약):

- **`StarterGui`** → `"$path": "src/StarterGui"`  
  → Rojo는 디스크의 `src/StarterGui` 내용을 **데이터모델의 `StarterGui` 서비스**와 동기화한다.
- **`StarterPlayer.StarterPlayerScripts`** → `"$path": "src/StarterPlayer/StarterPlayerScripts"`  
  → `MainClient`, `HUDClient`, `LevelUpClient` 등 **실행 로직**은 여기만.

**주의:** `src/StarterGui`가 **비어 있거나** Rojo가 빈 트리로 덮으면, Studio에서 잡아 두었던 `MainHUD`가 **사라질 수 있다**. **MainHUD 자산을 디스크에 한 번 올리는 것**이 이번 정리의 핵심이다.

`ReplicatedStorage` / `HudState` 등은 **이번 범위에서 JSON에 추가하지 않는다** (서버가 기존처럼 생성).

---

## 3. `src/StarterGui`에 MainHUD를 진실 소스로 두는 방법 (제안)

**방법 A — rbxmx 한 덩어리 (가장 단순)**

1. Studio에서 **`MainHUD` ScreenGui** 선택 → **Save to File…** → `MainHUD.rbxmx` 저장.  
2. 파일을 **`src/StarterGui/MainHUD.rbxmx`** 로 둔다 (이름은 Rojo 트리와 일치하도록 `MainHUD`).  
3. **MainHUD 안에 LocalScript가 있으면 제거**하고, 로직은 전부 `StarterPlayerScripts`에만 남긴다.  
4. Git에 커밋 후 Rojo로 동기화 → `StarterGui`에 `MainHUD`가 파일 기준으로 유지된다.

**방법 B — 폴더 + `init.meta.json`**

1. `src/StarterGui/MainHUD/init.meta.json` 에 `"className": "ScreenGui"` (및 필요한 `properties`).  
2. 자식 `HUDFrame`, `TimerBarRoot`, `LevelUpFrame` 을 폴더·메타·`.model.json` 등으로 세분화.  
3. **유지보수 비용이 큼** — 작은 변경엔 A, 장기적으로만 B 고려.

**공통:** 한 번 고정한 뒤에는 **이름 변경 시 `HUDClient` / `LevelUpClient`와 함께** 바꾼다.

---

## 4. 클라 구조 고정 (이번에 바꾸지 않음)

| 파일 | 역할 | 이번 작업 |
|------|------|-----------|
| `MainClient.client.lua` | `HUDClient`, `VFXClient`, `LevelUpClient`, `ResultClient` `init` | **유지** |
| `HUDClient.lua` | `PlayerGui.MainHUD` + `HudState` + `Humanoid` HP (바·타이머 등 표시 보간·기본 Health UI 억제) | **유지** |
| `LevelUpClient.lua` | `MainHUD.LevelUpFrame` + `LevelUpChoice*` | **유지** |

**합치지 않음.** 서버 판정 / 클라 표현 원칙 유지.

---

## 5. MainHUD 하위 이름 점검표 (코드와 1:1)

런타임에서 클라는 **`PlayerGui`** 아래 **`MainHUD`** 를 찾는다 (`StarterGui`의 자식이 플레이 시 `PlayerGui`로 복제됨).

### 5.1 `HUDClient.lua` 기대 트리

| 부모 | 자식 이름 | 용도 / 비고 |
|------|-----------|-------------|
| `PlayerGui` | **MainHUD** | ScreenGui 등 (이름 정확히 `MainHUD`) |
| **MainHUD** | **HUDFrame** | 없으면 레벨/XP 등만 스킵, HP/타이머는 가능 |
| **HUDFrame** | `LevelLabel`, `XPLabel`, `XPBarBG`, `HealthLabel`, `HealthBarBG` | 이름은 `FindFirstChild(..., true)` 로 중첩 검색 (대소문자 일치) |
| **MainHUD** | **TimerBarRoot** | 없으면 타이머 경고만 |
| **TimerBarRoot** | `TimerLabel`, `TimerBarBG` | |
| *바 안* | **Fill** | 각 `*BarBG` 아래 **`Fill`** (`GuiObject`). 코드는 직계 `Fill` 우선 후 깊은 검색, 크기 갱신은 **`setBarFillSize(fill, ratio)`** (스케일 X = 0~1). 이름·부모가 다르면 바가 안 움직임 |

### 5.2 `LevelUpClient.lua` 기대 트리

| 부모 | 자식 이름 | 비고 |
|------|-----------|------|
| **MainHUD** | **LevelUpFrame** | `GuiObject` |
| **LevelUpFrame** | **OptionsContainer** | |
| **OptionsContainer** | **Option1Button**, **Option2Button**, **Option3Button** | `TextButton` 등 `GuiButton` |
| **LevelUpFrame** | `Title` (선택) | 하위 아무 깊이나 `FindFirstChild(..., true)` — 있으면 제목 갱신 |

**점검 시:** Explorer에서 문자열을 **위 표와 동일**한지 확인한다. `option1button` / `Option 1` 등 **다르면 클라가 못 찾는다**.

---

## 이번 스코프 정리 체크리스트

- [ ] **MainHUD 트리** 위 표와 일치하는지 Studio에서 확인  
- [ ] MainHUD(또는 그 하위) **임시·중복 LocalScript** 제거 또는 `Disabled` 후 삭제 예정 표시  
- [ ] **`src/StarterGui`에 MainHUD 자산** 커밋 (rbxmx 권장) — 빈 `StarterGui` 동기화 방지  
- [ ] 스크립트 수정은 **`src/StarterPlayer/StarterPlayerScripts`만** 한다는 규칙 확정  

---

## 부록: 범위 밖 정리 (참고만)

- **`default.project.json`에 HudState 등 RemoteEvent 명시** — 나중에 서버 생성 로직과 맞춰 검토  
- **ResultClient**를 StarterGui 자산 + 얇은 바인딩으로 이전  
- **CrosshairClient** — 레포에서 제거됨 (더 이상 `Shared`에 없음).  
- **Utils** 등 기타 미사용 모듈 정리는 선택  

---

*이 문서의 이번 스코프는 “MainHUD와 관련 클라이언트 구조를 다시 안 꼬이게 고정”까지다.*

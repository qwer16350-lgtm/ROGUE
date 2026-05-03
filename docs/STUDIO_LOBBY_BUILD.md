# 로비 LobbyGui · Lobby Station 스튜디오 수동 제작 인스트럭션

MCP 타임아웃 없이 Roblox Studio에서 직접 만드는 절차입니다.  
코드 반영 전제: **`src/StarterPlayer/StarterPlayerScripts/LobbyClient.lua`** 의 **`LobbyClient`** 가 이름·태그·Attribute를 기준으로 연결합니다.

**문서 범위**

- `default.project.json` 유지 · **method C(별도 lobby/stage project 분리)** 없음
- **ServerScriptService · RunConstants · Teleport · StageFlow · WaveService 수정 금지**
- **실제 서버·DataStore·구매·가챠·랭킹·강화 구현 금지** — UI·ProximityPrompt 플레이스홀더만

레거시 레벨/바닥/스폰 가이드는 **[LobbyPlace-Studio-Setup.md](./LobbyPlace-Studio-Setup.md)** 를 참고합니다. 스테이션 **이름·태그·패널 매핑**은 **본 문서를 우선**합니다.

---

## 0. 사전 확인

| 항목 | 내용 |
|------|------|
| UI 저장 위치(데이터모델) | `ReplicatedStorage` → **`UIAssets`** → **`Lobby`** → **`LobbyGui`** (`ScreenGui`) |
| 로비 공간 | `Workspace` → **`Lobby`** 안에 스테이션만 배치 (**Workspace 통째 교체 금지**) |

**Explorer에 폴더가 없으면:** `Folder` 이름 `UIAssets` → 하위에 `Folder` 이름 `Lobby` 생성 후 작업합니다.

---

## A. LobbyGui (`ReplicatedStorage.UIAssets.Lobby.LobbyGui`)

### A-1. ScreenGui

- 이름: **`LobbyGui`**
- **`ResetOnSpawn`** = **false**
- **`IgnoreGuiInset`** = **false**

### A-2. Explorer 트리 (이름 규칙 최우선)

```
LobbyGui
└ Root (Frame)
    ├ CurrencyBar (Frame)
    │   ├ GoldValue (TextLabel)   기본 문자열: Gold: 0
    │   └ DiaValue (TextLabel)    기본 문자열: Dia: 0
    ├ PlayerActions (Frame)
    │   ├ SkillTreeButton (TextButton)
    │   ├ ShopButton (TextButton)
    │   ├ InventoryButton (TextButton)
    │   └ ArtifactCollectionButton (TextButton)
    └ Panels (Frame 권장)
        ├ SkillTreePanel (Frame)
        │   └ CloseButton (TextButton)
        ├ ShopPanel
        │   └ CloseButton
        ├ InventoryPanel
        │   └ CloseButton
        ├ ArtifactCollectionPanel
        │   └ CloseButton
        ├ Top50Panel
        │   └ CloseButton
        ├ PetGachaPanel
        │   └ CloseButton
        ├ BMShopPanel
        │   └ CloseButton
        ├ InGameShopPanel
        │   └ CloseButton
        ├ RelicShopPanel
        │   └ CloseButton
        └ RelicFusionPanel
            └ CloseButton
```

각 Panel 안에 선택으로 **제목용 TextLabel** 을 추가해도 됩니다.

### A-3. 패널 공통

- 위 **10개 Panel** 초기 **`Visible` = false**
- 패널마다 **`CloseButton`** 이름의 **`GuiButton`** 1개 이상 (직계·후손 모두 가능 — `LobbyClient`가 부모 패널을 찾습니다)

### A-4. 버튼 → 패널 (코드 고정 매핑)

| 버튼 | 패널 |
|------|------|
| SkillTreeButton | SkillTreePanel |
| ShopButton | ShopPanel |
| InventoryButton | InventoryPanel |
| ArtifactCollectionButton | ArtifactCollectionPanel |

---

## B. Workspace.Lobby 스테이션

### B-1. 부모

- `Workspace.Lobby` 없으면 **Folder `Lobby`** 생성.
- 같은 이름 Model이 이미 있으면 **중복 만들지 말고** 속성·태그만 맞춤.

### B-2. Model 이름 (7개)

1. **`Top50Station`**
2. **`PetGachaStation`**
3. **`BMShopStation`**
4. **`InGameShopStation`**
5. **`RelicShopStation`**
6. **`RelicFusionStation`**
7. **`EntryStation`**

각 Model: **표시용 Part 1개** + 후손에 **`ProximityPrompt` 1개** — 이름 통일 목적으로 **`OpenPrompt`** 권장.

### B-3. 패널 오픈용 (1 ~ 6번)

다음 내용 모두 필요합니다.

- **태그**: **`LobbyStation`** 만 (**`LobbyEntryPad` 는 붙이지 말 것**)
- **Attribute**: 이름 **`LobbyPanel`**, 타입 **String**, 값은 아래와 **패널 Explorer 이름 동일**:

| Station | LobbyPanel 문자열 값 |
|---------|-----------------------|
| Top50Station | Top50Panel |
| PetGachaStation | PetGachaPanel |
| BMShopStation | BMShopPanel |
| InGameShopStation | InGameShopPanel |
| RelicShopStation | RelicShopPanel |
| RelicFusionStation | RelicFusionPanel |

**Studio에서 적용**

1. 해당 **Model** 선택
2. Properties → **Tags** → `LobbyStation` 추가
3. Properties → **Attributes** → `LobbyPanel` (String) 추가 후 위 표의 값 입력

### B-4. 입장 전용 EntryStation (7번)

**서버 `LobbyBootstrap` 전용 — 클라이언트 Lobby 패널과 연결하지 않습니다.**

- **`LobbyEntryPad`** 태그 **필수**
- **`LobbyStation` 태그 금지**
- **`LobbyPanel` Attribute 는 두지 않는 것을 권장**
- 후손에 **ProximityPrompt 1개 이상** (이름은 `OpenPrompt` 권장; 서버는 **첫 번째 후손 프롬프트**만 사용하면 됩니다)

상세 패드 명세는 `LobbyBootstrap.lua` 주석 참고.

---

## C. LobbyClient 동작 요약 (코드 수정 없이 참고만)

1. **`ReplicatedStorage.UIAssets.Lobby.LobbyGui`** 를 `PlayerGui`에 Clone
2. 없으면 **코드 폴백 GUI** 생성 + 경고
3. 10개 패널을 레지스트리로 잡고 초기에는 모두 숨김
4. **`PlayerActions`** 4버튼 → 해당 패널만 **단독 표시**
5. **`CollectionService:GetTagged("LobbyStation")`** 로 순회, **`LobbyPanel`** 문자열과 일치하는 패널 오픈; **`ProximityPrompt.Triggered`** 는 **로컬 플레이어만** 처리
6. **`LobbyEntryPad` 가 같은 인스턴스에 있으면** 클라 패널 연결 스킵 (**Entry는 이중 태그 되어 있어서도 안 되게 설계**) — 정상이라면 Entry는 `LobbyStation` 없음
7. 패널 내부 **`CloseButton`** → 해당 패널 **`Visible = false`**

한 번에 **보이는 패널은 최대 1개**입니다.

---

## D. Save to File (Rojo 정본)

### D-1. LobbyGui 단일 파일

1. 선택: **`ReplicatedStorage`** → **`UIAssets`** → **`Lobby`** → **`LobbyGui`** (`ScreenGui` 루트만)
2. 우클릭 → **Save to File…**
3. 레포 내 경로 예:

`src/ReplicatedStorage/UIAssets/Lobby/LobbyGui.rbxmx`

(팀 규칙에 따라 `.rbxm` 도 가능합니다.)

### D-2. 스테이션 (Workspace 매핑)

`default.project.json` 에서 **`Workspace.Lobby`** 는 **`src/Workspace/Lobby`** **폴더**에 매핑됩니다.

**Model별** Save to File 을 권장합니다.

| 저장 예시 (파일명) |
|-------------------|
| `src/Workspace/Lobby/Top50Station.rbxmx` |
| `src/Workspace/Lobby/PetGachaStation.rbxmx` |
| `src/Workspace/Lobby/BMShopStation.rbxmx` |
| `src/Workspace/Lobby/InGameShopStation.rbxmx` |
| `src/Workspace/Lobby/RelicShopStation.rbxmx` |
| `src/Workspace/Lobby/RelicFusionStation.rbxmx` |
| `src/Workspace/Lobby/EntryStation.rbxmx` |

`Lobby` 폴더 **전체를 한 파일**로만 저장하면 Rojo 폴더 매핑과 트리가 어긋날 수 있어, 위처럼 **스테이션별 분리**가 안전합니다.

---

## E. 검증 체크리스트

### LobbyPlace

| 확인 항목 |
|-----------|
| `MainClient` 로비 브랜치에서 **`LobbyClient` 초기화** |
| `LobbyGui`가 `PlayerGui`에 존재( Clone 또는 폴백 로그 참고 ) |
| `GoldValue` / `DiaValue` 텍스트 표시 |
| 4개 액션 버튼 → 해당 패널만 열림 |
| 각 Panel의 `CloseButton` 동작 |
| 6개 `LobbyStation` 스테이션에서 E → 해당 패널만 열림 |
| **`EntryStation`** 에서 E → **`LobbyBootstrap` 입장 플로우 유지**(Lobby 패널은 열리지 않아야 함) |
| HudState 무한 대기 없음 · **Lobby 에서 MainHUD 자동 생성 없음** |

### StagePlace

| 확인 항목 |
|-----------|
| `LobbyGui` 미표시 |
| `StageClient` / MainHUD 플레이스 홀더 유지 |

---

## F. 문제 해결표

| 증상 | 확인할 것 |
|------|-----------|
| 스테이션 E 후 패널이 안 열림 | **`LobbyStation` 태그**, **`LobbyPanel` 철자**, 후손 **`ProximityPrompt` 존재** |
| 입장 불가 | **`EntryStation`** 에 **`LobbyEntryPad` 존재** · **`LobbyStation` 미부착** |
| 패널이 안 닫힘 | 하위 이름 정확히 **`CloseButton`** 인 **`GuiButton`** |
| 패널이 영원히 안 보임 | Panel **이름**이 본문 표와 **완전 일치**하는지 (대소문자 포함) |

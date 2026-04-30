# LobbyPlace 로비 공간 구성 가이드 (Studio → Lobby.rbxmx)

이 문서는 **LobbyPlace**에서 로비 공간을 Studio로 직접 만든 뒤 `src/Workspace/Lobby.rbxmx`로 export 하는 절차입니다.  
항목별로 따라가다가 막히는 부분은 채팅에서 번호만 짚어서 질문해도 됩니다.

## 워크플로 원칙 (요약)

- Studio에서 레벨 디자인 → **`Workspace.Lobby`만 우클릭 Save to File** → `Lobby.rbxmx` 덮어쓰기.
- **Rojo가 켜져 있으면** 디스크 변경이 즉시 반영되는 경우가 많음.
- Rojo Stop/Connect는 **필수 아님**. 매핑이 안 먹는 것 같을 때만 선택.
- **`Save to File`를 하기 전 변경은 디스크 source에 저장된 것이 아님.**

---

## 1. Workspace에 먼저 만들 것

1. **LobbyPlace**가 열린 Studio에서 **Workspace** 선택.
2. **Insert → Folder** (또는 `+`) 추가.
3. 폴더 이름을 **`Lobby`**로 지정 (`Workspace.Lobby`).
4. 이후 작업은 **전부 이 폴더 안**에서만 진행.

---

## 2. Workspace.Lobby 구조 개요

- **Floor** — 로비 바닥 (Part 1개).
- **SpawnArea** — 폴더 + **SpawnLocation**.
- **StageEntry** — 입장 패드 (**EntryPad** + **ProximityPrompt** + 태그 `LobbyEntryPad`).
- **UpgradeStation / BlueprintStation / ResultStation** — placeholder만 (Prompt·해당 태그 없음).

---

## 3. Floor Part — 크기 / 위치 / 속성

1. `Lobby` 우클릭 → **Insert Object → Part** → 이름 **Floor**.
2. **Position** 예: **`0, 0, 0`**.
3. **Size**: **`80, 1, 80`**.
4. **Anchored**: `true`, **CanCollide**: `true`.
5. **Material**: `SmoothPlastic` 또는 `Concrete`, **Color** 예: `45, 45, 50`.

바닥 윗면 Y는 대략 `Position.Y - Size.Y/2 + Size.Y = -0.5 + 1 = 0.5` 근처. 패드들은 **`Y ≈ 0.75 ~ 1`** 정도로 맞추면 발이 바닥에 닿기 쉬움.

---

## 4. SpawnLocation — 위치 / 속성

1. `Lobby`에 **Folder** → 이름 **`SpawnArea`**.
2. `SpawnArea`에 **SpawnLocation** 추가.
3. **Name**: `SpawnLocation`.
4. **Position** 예: **`0, 1, 0`**.
5. **Size** 예: **`6, 1, 6`**.
6. 필수: **AllowTeamChangeOnTouch** = `false`, **Neutral** = `true`, **Enabled** = `true`.
7. **Anchored** = `true`, **CanCollide** = `true`.

Play로 스폰·낙하 여부 확인.

---

## 5. StageEntry Model 구성

1. `Lobby`에 **Model** → 이름 **`StageEntry`**.
2. 그 안에 **EntryPad** Part를 만든다(§6).

(선택) 안내판 `EntrySign` + SurfaceGui 등은 같은 Model 안에 자유 배치.

---

## 6. EntryPad Part

1. **StageEntry** 안에 Part → 이름 **`EntryPad`**.
2. **Position** 예: **`0, 0.75, -24`** (북쪽 −Z).
3. **Size** 예: **`6, 0.5, 6`**.
4. **Anchored** = `true`, **CanCollide** = `true`.
5. 시각 구분 권장: **Material** `Neon`, **Color** 예 `90, 180, 255`.

---

## 7. ProximityPrompt — 추가와 권장 속성

1. **EntryPad** 선택 → **Insert Object → ProximityPrompt**.
2. 이름 예: `EntryPrompt` (코드는 ** subtree의 첫 ProximityPrompt**를 사용하므로, **패드에는 Prompt 1개만** 두는 것이 안전함).

권장 속성:

| 속성 | 값 |
|------|-----|
| ActionText | `입장` |
| ObjectText | `Stage 1` |
| HoldDuration | `0.4` |
| MaxActivationDistance | `8` |
| RequiresLineOfSight | `false` |
| Enabled | `true` |

---

## 8. LobbyEntryPad 태그

- **태그 문자열 정확히:** `LobbyEntryPad` (대소문자 일치).
- **부여 위치:** **EntryPad** Part에만 (Model 전체에는 달지 말 것).

**방법:** View → **Tag Editor** → `EntryPad` 선택 → Add Tag → `LobbyEntryPad`.  
또는 Properties 하단 **Tags**에 추가.

Placeholder 패드에는 **절대** 이 태그를 붙이지 않는다.

---

## 9. Placeholder Stations (기능 미구현)

각각 **Model** 하나:

- **UpgradeStation** — 자식 **Pad** (Part), Transparency 약간, 회색. **ProximityPrompt 없음**, **LobbyEntryPad 없음**. SurfaceGui 예: `"강화 (준비 중)"`.
- **BlueprintStation** — 동일, 텍스트 `"설계도 (준비 중)"`.
- **ResultStation** — 동일, 텍스트 `"지난 결과 (준비 중)"`.

스크립트·Remote 연동 금지(이 단계는 placeholder만).

---

## 10. 추천 위치 (예시 좌표)

Floor 중심 `0,0,0`, 패드 Y 예 `0.75`:

| 대상 | Position (예) |
|------|----------------|
| SpawnLocation | `0, 1, 0` |
| EntryPad | `0, 0.75, -24` |
| UpgradeStation.Pad | `24, 0.75, 0` |
| BlueprintStation.Pad | `-24, 0.75, 0` |
| ResultStation.Pad | `0, 0.75, 24` |

---

## 11. Explorer 최종 구조 (목표)

```
Workspace
└── Lobby
    ├── Floor
    ├── SpawnArea
    │   └── SpawnLocation
    ├── StageEntry
    │   ├── EntryPad           [Tags: LobbyEntryPad]
    │   │   └── EntryPrompt    (ProximityPrompt)
    │   └── (선택) EntrySign …
    ├── UpgradeStation
    │   ├── Pad
    │   └── (선택) Sign …
    ├── BlueprintStation …
    └── ResultStation …
```

---

## 12. 태그 검증

Command Bar에서:

```lua
print(#game:GetService("CollectionService"):GetTagged("LobbyEntryPad"))
```

기대값: **`1`**.  
`0`이면 미부여·오타, `2+`면 중복 부여를 제거해야 함.

---

## 13. Save to File 순서 (`Lobby.rbxmx`)

1. Explorer에서 **`Lobby` 폴더만** 선택 (Workspace 전체 선택 금지).
2. 우클릭 → **Save to File…**
3. 형식: **Roblox XML Model Files (*.rbxmx)**.
4. 경로: **`…/ROGUE/src/Workspace/Lobby.rbxmx`**  
   (`default.project.json`의 `Workspace.Lobby` `$path`와 일치할 것.)
5. 기존 파일이 있으면 **덮어쓰기**.

---

## 14. Export 후 Rojo 확인

- File Explorer에서 `Lobby.rbxmx` 수정 시간·크기 갱신 확인.
- Rojo 연결 상태에서 트리/태그/프롬프트 유지 확인.
- 이상할 때만 **선택적으로** 플러그인 Disconnect 후 Connect.

---

## 15. 실수 목록 · 체크리스트

| 자주 하는 실수 | 결과 |
|----------------|------|
| 태그를 placeholder에 걸거나 Model에 걸었음 | 잘못된 프롬프트 선택 |
| 태그 오타 (`LobbyEntrypad` 등) | LobbyBootstrap 경고 |
| EntryPad 당 ProximityPrompt 2개+ | 어떤 것이 묶일지 불명확 |
| RequiresLineOfSight=true + 가림 | 프롬프트 안 보임 |
| 수정만 하고 export 안 함 | git/다른 PC에 반영 없음 |
| `Lobby` 아닌 루트로 저장함 | 매핑·이름 불일치 |

**Export 직전 체크**

- [ ] §11 트리와 동일
- [ ] `LobbyEntryPad`는 EntryPad에 **정확히 1개**
- [ ] EntryPad 하위 ProximityPrompt **1개**
- [ ] SpawnLocation 속성 검증 완료
- [ ] Placeholder에 Prompt·LobbyEntryPad **없음**
- [ ] GetTagged 개수 **1**
- [ ] 저장은 **Lobby 폴더만** → `Lobby.rbxmx`
- [ ] (권장) git에 커밋

---

## 참고: StagePlace와 같은 project 사용 시

현재 단계에서는 `MainServer`에서 Stage/Lobby 간 **Workspace 폴더 Destroy cleanup**은 아직 없을 수 있음.  
`Lobby.rbxmx`에 SpawnLocation이 있으면 **Stage 실행 시 스폰 경합**이 일어날 수 있어, 다음 step에서 cleanup PLAN 적용을 권장한다.

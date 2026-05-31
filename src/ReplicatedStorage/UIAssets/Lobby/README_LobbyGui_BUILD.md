# Lobby UI (`LobbyGui`)

**Phase 3 closeout:** 정식 relic UI — `LobbyRelicCollectionPanelClient`, `LobbyRelicFusionPanelClient`, `LobbyRelicStartingPanelClient`. `EquipStartingRelicsRequest` **필수** (7A). `RelicShopPanel` = Phase 4+ placeholder.

Publish `GameConfig.Debug`: `RelicProfileTestSeed=nil`, `RelicCraftSkipRequirements=false` (see `GameConfig.lua`).

## 수동 제작 절차 (Studio)

스튜디오에서 **이름·태그·Attribute**를 맞추는 전체 단계:

- **[docs/STUDIO_LOBBY_BUILD.md](../../../../docs/STUDIO_LOBBY_BUILD.md)**

## Rojo 경로

- **`LobbyGui`**: `src/ReplicatedStorage/UIAssets/Lobby/LobbyGui.rbxmx` (또는 `.rbxm`)
- 템플릿이 없으면 `LobbyClient`가 **코드 폴백** UI를 만듭니다(동일 이름 규칙).

## `LobbyClient`가 찾는 이름 (요약)

| 종류 | 이름 |
|------|------|
| ScreenGui | `LobbyGui` |
| 루트 프레임 | `Root` |
| 재화 라벨 | `GoldValue`, `DiaValue` |
| 액션 버튼 | `SkillTreeButton`, `ShopButton`, `InventoryButton`, `ArtifactCollectionButton` |
| 패널 (10) | `SkillTreePanel`, `ShopPanel`, `InventoryPanel`, `ArtifactCollectionPanel`, `Top50Panel`, `PetGachaPanel`, `BMShopPanel`, `InGameShopPanel`, `RelicShopPanel`, `RelicFusionPanel` |
| 닫기 | 각 패널 하위 **`CloseButton`** (`GuiButton`) |

Relic 패널(Step 6)은 **`LobbyRelic*Client`** 모듈이 연동합니다. 없는 위젯은 런타임 생성됩니다.

## Step 6 — Lobby Relic UI (정식)

| 우선순위 | 패널 | 모듈 | Remote |
|----------|------|------|--------|
| A Collection | `ArtifactCollectionPanel` | `LobbyRelicCollectionPanelClient` | `GetRelicProfile` |
| B Craft | `RelicFusionPanel` | `LobbyRelicFusionPanelClient` | `GetRelicProfile`, `CraftRelicRequest` |
| C Materials | `InventoryPanel` | `LobbyClient` | `GetRelicProfile` |
| D Equip (read-only) | Collection 하단 | `LobbyRelicCollectionPanelClient` | `GetRelicProfile` only |

| 위젯 (없으면 런타임 생성) | 패널 |
|---------------------------|------|
| `RelicCollectionList`, `RelicCollectionStatus`, `RelicEquipReadOnly` | ArtifactCollection |
| `RelicCraftList`, `RelicFusionCraftStatus` | RelicFusion |
| `RelicMaterialsLabel` | Inventory |

- **Station:** `RelicFusionStation` → `LobbyPanel` = `RelicFusionPanel` (변경 없음).
- **Starting (7A):** `StartingRelicPanel` + `EquipStartingRelicsRequest` — owned rows, `StartingRelicOwnedList`.
- **Obsolete:** `ShowLobbyRelicFusionCraftDev` / `ShowLobbyRelicMaterialsDevLabel` — 코드 없음. ~~`LobbyRelicFusionCraftClient`~~ → `LobbyRelicFusionPanelClient`.

## Step 7A — StartingRelicPanel (owned loadout)

| 위젯 | 용도 |
|------|------|
| `StartingRelicOwnedList` | `ownedRelics` 후보 ScrollingFrame |
| `StartingRelicStatus` / `StartingRelicSlotLabel` | 상태·슬롯 요약 (`relicStartingSlotMax`) |
| `StartingRelicClearSlotsButton` | `EquipStartingRelicsRequest({})` |
| 행 `SlotActionButton` | **Add** / **Remove** — owned + slot cap만 (eligible 무시) |
| `SelectedStartingRelicLabel` | (선택) equipped[1] 요약 — 7A 클라가 갱신 |

**제거됨 (legacy):** `RelicButtonList` 및 RelicData 3종 고정 버튼(`OldShieldEmblemButton` 등, `StartingRelicId` Attribute). `StartingRelicSelectRequest` **removed (7C-3 server)**. UI `StartingRelicId` attribute strip is client-only legacy cleanup.

`isStartingEligible`는 Equip/UI 게이트에 사용하지 않음. Definitions 메타 값은 변경하지 않음.

**자산 export:** Studio에서 `LobbyGui` 수정 후 `src/ReplicatedStorage/UIAssets/Lobby/LobbyGui.rbxm`(또는 `.rbxmx`)로 Save to File.

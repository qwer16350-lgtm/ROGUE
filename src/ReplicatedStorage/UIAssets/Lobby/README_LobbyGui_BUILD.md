# Lobby UI (`LobbyGui`)

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

서버·DataStore·구매 등은 연결하지 않습니다 — 플레이스홀더 UI만.

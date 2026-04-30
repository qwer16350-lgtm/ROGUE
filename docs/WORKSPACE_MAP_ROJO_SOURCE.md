# Workspace.Map — Rojo 진실 소스 (Ground / RuntimeMarkers)

`default.project.json` 은 수정하지 않는다. **`Workspace.Map` → `src/Workspace/Map`** 매핑을 전제로 한다.

## 목표 인스턴스

| Studio에서 옮길 것 | 디스크 폴더 | Rojo 반영 후 경로 |
|--------------------|-------------|-------------------|
| **Ground_Base** | `src/Workspace/Map/Ground/` | `Workspace.Map.Ground.Ground_Base` |
| **Marker_Bottleneck_Main** | `src/Workspace/Map/RuntimeMarkers/` | `Workspace.Map.RuntimeMarkers.Marker_Bottleneck_Main` |

`MapService.lua`는 **`Marker_Bottleneck_Main`** 이 **`Workspace.Map.RuntimeMarkers`** 아래 **`BasePart`** 로 존재하는 것을 요구한다.

---

## 파일명 규칙 (.rbxmx)

| 규칙 | 설명 |
|------|------|
| 형식 | **`.rbxmx`** (Roblox XML). 레포에 이미 `Structure_Grassland_Bottleneck_A.rbxmx` 패턴과 동일. |
| 파일 이름 | **인스턴스 `Name` 과 동일** + `.rbxmx` → 예: `Ground_Base.rbxmx`, `Marker_Bottleneck_Main.rbxmx` |
| 루트 클래스 | **Ground_Base**: `Model` 또는 `BasePart`(프로젝트에 맞게). **Marker_Bottleneck_Main**: 반드시 **`BasePart`** 계열(`Part`, `MeshPart` 등) — `MapService` 가 `IsA("BasePart")` 검사. |
| 내부 이름 | Export 전 Studio 탐색기에서 **이름이 파일명(확장자 제외)과 같도록** 맞춘다. |

---

## 해야 할 작업 순서

1. **Studio 백업** — 현재 `Ground_Base`, `Marker_Bottleneck_Main` 위치 스크린샷 또는 복제본 보관.
2. **정본 폴더 확인** — 레포에 `src/Workspace/Map/Ground`, `src/Workspace/Map/RuntimeMarkers` 가 있다 (각 폴더에 `init.meta.json` 로 Folder 유지).
3. **Ground_Base 내보내기** — 아래 [Studio export](#studio-export) 참고 → `Ground_Base.rbxmx` 로 저장.
4. **Marker_Bottleneck_Main 내보내기** — 동일 → `Marker_Bottleneck_Main.rbxmx` 로 저장.
5. **파일 배치** — 아래 [경로](#정확한-경로) 에 복사.
6. **`rojo serve`** 후 Studio 연결 → 동기화 후 **Studio에서만 있던 복제본 제거**(중복 방지; 한 번에 하나의 출처만).
7. **확인** — 아래 [완료 후 확인](#완료-후-확인) 체크리스트.

---

## 정확한 경로

```
src/Workspace/Map/
├── Ground/
│   ├── init.meta.json          ← Folder (Rojo)
│   └── Ground_Base.rbxmx       ← 여기에 배치 (export 후)
└── RuntimeMarkers/
    ├── init.meta.json
    └── Marker_Bottleneck_Main.rbxmx
```

---

## Studio export

### Ground_Base

1. Explorer에서 **`Ground_Base`** 선택 (단일 `Model` 또는 최상위가 될 인스턴스 하나).
2. 우클릭 → **Save to File…** (또는 파일 메뉴에서 동일).
3. 임시 폴더에 저장 → 파일 이름을 **`Ground_Base.rbxmx`** 로 한다.
4. 레포로 옮김: **`src/Workspace/Map/Ground/Ground_Base.rbxmx`**.

### Marker_Bottleneck_Main

1. **`Marker_Bottleneck_Main`** 이 **`Part` / `MeshPart`** 등 BasePart 인지 확인.
2. 동일하게 **Save to File…** → **`Marker_Bottleneck_Main.rbxmx`**.
3. **`src/Workspace/Map/RuntimeMarkers/Marker_Bottleneck_Main.rbxmx`** 로 이동.

Export 후 rbxmx 안의 최상위 `Item` 이름이 파일 stem 과 같으면 Rojo·Studio 모두 헷갈림이 적다.

---

## 완료 후 확인

- [ ] 디스크에 두 파일 존재:  
  `src/Workspace/Map/Ground/Ground_Base.rbxmx`  
  `src/Workspace/Map/RuntimeMarkers/Marker_Bottleneck_Main.rbxmx`
- [ ] Rojo 실행 후 Explorer: **`Workspace.Map.Ground.Ground_Base`**, **`Workspace.Map.RuntimeMarkers.Marker_Bottleneck_Main`**
- [ ] Play 모드에서 Output: **`MapService`** 관련 마커 오류 없음 (`Marker missing or not a BasePart` 미발생).
- [ ] 예전에 Studio 맵에만 있던 동일 이름 인스턴스를 **중복으로 두지 않았는지**(한쪽만 정본).

---

## 코드 / MapService

이 단계에서는 **`MapService.lua` 구조 변경 없음**. 이미 `Workspace.Map.RuntimeMarkers` 에서 `Marker_Bottleneck_Main` 을 찾는다. 정본만 디스크로 옮기면 된다.

`Ground_Base` 는 현재 서버 스크립트에서 참조하지 않을 수 있음 — 시각·레벨 디자인용으로 `Ground` 아래 두는 것이 목적.

# Stage HUD 템플릿 (`MainHUD`)

## 레포 안 위치

- 이 폴더에 **`MainHUD.rbxm`** 또는 **`MainHUD.rbxmx`** 를 둔다.
- **루트 인스턴스** 이름과 클래스: **`ScreenGui` · `MainHUD`** 권장(다르면 `StageClient` 의 `TEMPLATE_NAME` 상수 수정).

## 어디서 가져오나

- 예전 **StarterGui** 에 있던 `MainHUD` 를 Studio에서 우클릭 → **Save to File** 로 export 후 여기에 복사.
- **`StarterGui` 는 MainHUD 진실 소스가 아니다.** 레포에서는 `StarterGui/EXPORT_MAINHUD_HERE.txt` 만 안내용으로 유지한다.

## 런타임

- `StageClient.init()` 가 템플릿을 **`LocalPlayer.PlayerGui` 로 클론**한 뒤 `HUDClient` / `LevelUpClient` 등이 동작한다.
- 템플릿 없으면 `StageClient` 는 `warn` 후 **중단**한다(네 Stage 클라 `init` 미호출).

## 하위 트리

- 클라 표시 이름은 **`docs/`** 또는 `HUDClient`/`LevelUpClient` 가 건드리는 이름과 일치해야 한다(`HUDFrame`, `LevelUpFrame`, `TimerBarRoot` 등).

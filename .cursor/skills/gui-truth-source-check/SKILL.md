---
name: gui-truth-source-check
description: StarterGui/MainHUD 진실 소스 점검 — 공통 절차(Skill); 에이전트 역할 아님 (ROGUE)
---

# GUI truth source check

## 이 Skill의 성격

- **에이전트 역할 정의가 아니다.** UI-bridge(서브)·Implementer 등 **GUI 관련 단계에서 공통**으로 따르는 체크리스트다.

## When to use

UI 텍스트, ScreenGui, MainHUD, PlayerGui 관련 이슈.

## ROGUE layout (verify in repo)

- `default.project.json` → `StarterGui` → `$path: "src/StarterGui"`
- 클라: `src/StarterPlayer/StarterPlayerScripts/HUDClient.lua`, `MainClient.client.lua` 등
- 서버 HUD 푸시: `src/ServerScriptService/HudSyncService.lua` (기존 패턴)

## Checklist

1. 변경이 `src/StarterGui/` 자산인가, 아니면 스크립트인가 구분.
2. PlayerGui 런타임은 **복제본** — 편집은 **StarterGui/로컬 스크립트** 쪽.
3. 서버가 UI를 직접 만지는 코드를 추가하지 않았는가 (플랜 위반).

## Do not

Studio에만 있는 UI를 정본으로 문서화하기.

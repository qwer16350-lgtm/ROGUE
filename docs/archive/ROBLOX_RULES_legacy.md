# Archive: `ROBLOX_RULES.md` 스냅샷 (MyFirstGame 시절 전문)

- **보관 목적:** 일반 튜토리얼 형태의 구버전 전체를 역사 참고용으로 보존.
- **정본이 아님:** 레포 운영 규칙은 **`.cursor/rules/*.mdc`**, 진입점 **`AGENTS.md`**, 요약은 루트 **`ROBLOX_RULES.md`**(현행)를 따른다.

---

# MyFirstGame Roblox Rules (Rojo Workflow)

## Project Goal
This project uses:
- **Cursor** for writing and editing code
- **Rojo** for syncing local files into Roblox Studio
- **Roblox Studio** for playtesting, scene editing, and runtime inspection
- **Git** for version control
- **GitHub** for remote backup

The goal is to keep the project simple, structured, and scalable while using a **local-file-first workflow**.

---

## Source of Truth

The **local project files** are the single source of truth for all code.

- Code must be edited in **Cursor**
- Roblox Studio is used to **view Rojo-synced results**, **test gameplay**, and **inspect runtime behavior**
- Do **not** treat Studio-edited scripts as the primary source once Rojo is in use
- If Studio content and local files differ, treat the **local files** as authoritative

---

## Development Workflow

Use this workflow for all code changes:

1. Edit code in **Cursor**
2. Save local files
3. Let **Rojo** sync changes into Roblox Studio
4. Test in **Roblox Studio**
5. If there is a problem, go back to Cursor and fix it
6. Only after confirming correct behavior:
   - run `git add .`
   - run `git commit -m "..."`
7. Use `git push` when you want to upload or back up confirmed work

Do **not** commit code before basic Studio testing unless you are intentionally creating a temporary checkpoint.

---

## Rojo Workflow Rules

- Run `rojo serve` from the project root before syncing with Studio
- Keep the Rojo terminal window open while working
- Connect from Roblox Studio using the **Rojo plugin**
- If Rojo is not running, Studio changes will not reflect new local code
- Do not mix Rojo workflow with old Script Sync workflow
- Do not maintain duplicate code in both Studio and local files

---

## Core Script Types

### Script
- Runs on the **server**
- Use for:
  - game state
  - enemy spawning
  - server-side validation
  - player data handling
  - secure gameplay logic

### LocalScript
- Runs on the **client**
- Use for:
  - player input
  - camera control
  - UI logic
  - local visual feedback

### ModuleScript
- Shared reusable code
- Use for:
  - helper functions
  - utility logic
  - shared constants/config
  - reusable systems

---

## Core Roblox Locations

### ServerScriptService
Use for main **server-side scripts**.

### StarterPlayer > StarterPlayerScripts
Use for main **client/player-side scripts**.

### ReplicatedStorage
Use for:
- shared modules
- RemoteEvents / RemoteFunctions
- shared constants and config

---

## Local Project Structure

The local project should follow this structure:

- `default.project.json`
- `src/ReplicatedStorage/Shared/Utils.lua`
- `src/ServerScriptService/MainServer.server.lua`
- `src/StarterPlayer/StarterPlayerScripts/MainClient.client.lua`

This structure exists so that:
- server code remains clearly separated
- client code remains clearly separated
- shared modules remain reusable
- the project stays easy to understand
- the project remains compatible with Rojo and Git

---

## Rojo Mapping Rule

Rojo maps local files into Roblox Studio.

Use these filename conventions:

- `*.server.lua` -> `Script`
- `*.client.lua` -> `LocalScript`
- `*.lua` -> `ModuleScript`

Do not rename these carelessly.

---

## Required Studio Structure

When Rojo is connected, Studio should reflect this structure:

- `ReplicatedStorage`
  - `Shared`
    - `Utils`

- `ServerScriptService`
  - `MainServer`

- `StarterPlayer`
  - `StarterPlayerScripts`
    - `MainClient`

---

## File Responsibilities

### MainServer
Server entry point.

Responsible for:
- server bootstrapping
- player join handling
- secure game logic
- server-side state and validation

### MainClient
Client entry point.

Responsible for:
- input handling
- client-side setup
- local UI/camera behavior
- local feedback

### Utils
Shared helper module.

Responsible for:
- reusable helper functions
- shared utilities
- simple general-purpose helper logic

---

## Placement Rules

1. Put **server gameplay logic** in `src/ServerScriptService`
2. Put **player input, camera, and local UI logic** in `src/StarterPlayer/StarterPlayerScripts`
3. Put **shared reusable modules** in `src/ReplicatedStorage/Shared`
4. Do **not** scatter important scripts throughout Workspace unless absolutely necessary
5. Keep server, client, and shared code clearly separated
6. Prefer modular code over one large script
7. Keep the file structure aligned with `default.project.json`

---

## Coding Standards

- Use clear names
- Keep functions small and readable
- Avoid duplicated logic
- Prefer reusable modules when logic may be shared
- Use `WaitForChild()` when accessing important Roblox instances that may not be immediately available
- Do not place sensitive gameplay authority on the client
- Client should request actions; server should validate and decide
- Prefer incremental changes over large rewrites
- Keep beginner-stage code simple and understandable

---

## Architecture Rule

Use this mental model:

- **Client = input / UI / camera / local presentation**
- **Server = authority / validation / game state / secure logic**
- **ReplicatedStorage = shared bridge**

---

## What Cursor Should Do

When generating or editing code for this project:

1. Respect Roblox script type differences:
   - `Script` for server
   - `LocalScript` for client
   - `ModuleScript` for shared reusable code

2. Respect the required local file locations:
   - server code -> `src/ServerScriptService`
   - client code -> `src/StarterPlayer/StarterPlayerScripts`
   - shared code -> `src/ReplicatedStorage/Shared`

3. Respect the Rojo project mapping defined in `default.project.json`

4. Treat local project files as the source of truth for code

5. Prefer creating small modular systems instead of putting everything into one file

6. Preserve the current project structure unless there is a strong reason to improve it

7. Do not assume Studio-edited code is newer than local files

8. When editing code, explain briefly whether the change belongs to:
   - server
   - client
   - shared module

9. Avoid unnecessary renaming, moving, or restructuring unless explicitly requested

10. Keep all suggestions compatible with the current Rojo workflow

---

## Cursor Operating Rules

Cursor should follow these practical rules:

- Edit code in local files only
- Do not treat Studio as the primary code source
- Preserve the current Rojo structure unless asked to refactor
- Do not create duplicate versions of the same gameplay logic in multiple files
- Do not move logic between server/client/shared layers without a reason
- Prefer incremental edits over large rewrites
- For beginner-stage systems, prioritize correctness and clarity over abstraction
- Keep changes easy to test in Studio immediately after saving

---

## Anti-Patterns To Avoid

Do not:
- put all logic into one script
- place important gameplay authority on the client
- randomly place scripts inside Workspace
- duplicate the same logic across multiple scripts
- mix server and client responsibilities in one place
- generate code that ignores Roblox execution context
- treat Studio-only edits as the primary codebase
- commit untested code as if it were confirmed working
- reintroduce old Script Sync assumptions or file paths

---

## Git Workflow Reminder

Use Git only after confirming behavior in Studio.

Typical workflow:
1. edit in Cursor
2. Rojo syncs to Studio
3. test in Studio
4. if correct:
   - `git add .`
   - `git commit -m "..."`
5. push later if needed:
   - `git push`

Remember:
- `commit` = local version history
- `push` = remote backup/upload

---

## Current Development Priority

The project is still in the beginner stage.

Priority order:
1. make the code run correctly
2. keep server/client/shared structure clean
3. keep the project easy to understand
4. keep the project compatible with Rojo workflow
5. keep the code easy to test
6. keep the code easy to scale later

Do not over-engineer early systems.
Keep the first implementation simple and correct.

# Plan scope gate (manual checks)

Live file: `.cursor/task-state/current-plan.json` (not in git — copy from `current-plan.example.json`).

After `APPROVE_PATCH`, `enforce-patch-gate.ps1` allows file tools only if that JSON exists, `state` is `approved`, and the tool target path **exactly** matches an entry in `approvedFiles` (repo-relative, e.g. `src/ServerScriptService/Foo.lua`). `allowNewFiles: false` blocks creating new paths.

Quick checks:

1. No `current-plan.json` → edit tool should deny (`plan_scope_json_missing` in `.cursor/hooks-debug.log`).
2. `state: idle` → deny (`plan_scope_state_not_approved`).
3. `approved` + list only `src/X.lua` → editing `src/Y.lua` denies (`plan_scope_not_in_approved_files`).
4. `allowNewFiles: false` + path not on disk → deny (`plan_scope_new_file_denied`).

Rollback: delete or fix `current-plan.json`; gate flag unchanged.

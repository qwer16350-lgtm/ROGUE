<#
  preToolUse - Blocks gate-controlled Cursor tools unless .cursor/.patch_gate_allow is "1"
  after set-patch-gate.ps1 (beforeSubmitPrompt) saw APPROVE_PATCH.

  Writes .cursor/hooks-debug.log append lines: ts tool_name gate blocked decision note (ASCII).
  UTF-8 with BOM.

  Fail-closed when blocked category hits script-error path.
#>
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'hook-parse-stdin.ps1')
. (Join-Path $PSScriptRoot 'daily-workflow-state.ps1')

function Get-RepoRootSafe {
  try {
    return (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
  }
  catch {
    return ''
  }
}

function Get-BlockedToolNames {
  return @(
    'Write', 'Edit', 'MultiEdit', 'StrReplace', 'Delete',
    'apply_patch', 'ApplyPatch',
    'EditNotebook',
    'Task',
    'run_terminal_cmd', 'run_command', 'RunCommand', 'execute_command',
    'Shell', 'terminal', 'Terminal', 'integrated_terminal'
  )
}

function Test-BlockedAgentTool([string]$name) {
  if ([string]::IsNullOrWhiteSpace($name)) { return $false }
  foreach ($x in @(Get-BlockedToolNames)) {
    if ([string]::Equals($x, $name, [StringComparison]::OrdinalIgnoreCase)) {
      return $true
    }
  }
  return $false
}

function Test-ShellLikeTool([string]$name) {
  if ([string]::IsNullOrWhiteSpace($name)) {
    return $false
  }
  foreach (
    $x in @(
      'run_terminal_cmd', 'run_command', 'RunCommand', 'execute_command',
      'Shell', 'terminal', 'Terminal', 'integrated_terminal'
    )
  ) {
    if ([string]::Equals($x, $name, [StringComparison]::OrdinalIgnoreCase)) {
      return $true
    }
  }
  return $false
}

function Read-GateOpen {
  param([string]$flagPath)
  if (-not (Test-Path -LiteralPath $flagPath)) { return $false }
  $raw = Get-Content -LiteralPath $flagPath -Raw -ErrorAction SilentlyContinue
  if ($null -eq $raw) { return $false }
  return ($raw.Trim() -eq '1')
}

function Read-GateValueForLog {
  param([string]$flagPath)
  if (-not (Test-Path -LiteralPath $flagPath)) { return 'missing' }
  $raw = Get-Content -LiteralPath $flagPath -Raw -ErrorAction SilentlyContinue
  if ($null -eq $raw) { return 'missing' }
  $t = $raw.Trim()
  if ($t -eq '1') { return '1' }
  if ($t -eq '0') { return '0' }
  return 'invalid'
}

function Escape-ToolNameForLog([string]$n) {
  if ([string]::IsNullOrWhiteSpace($n)) { return '_' }
  return (($n -replace '\s', '_') -replace '[^\x20-\x7E]', '?')
}

function Write-DenyEnvelopePlanScope {
  param([string]$Reason)
  $um = "[ROGUE] Plan file scope: $Reason — set `.cursor/task-state/current-plan.json` to `"state`": `"approved`" and exact repo-relative paths in `"approvedFiles`"."
  $am = 'plan_scope deny — see .cursor/task-state/current-plan.json'
  @{ permission = 'deny'; user_message = $um; agent_message = $am } | ConvertTo-Json -Compress
}

function Normalize-PlanScopeRelPath([string]$p) {
  if ([string]::IsNullOrWhiteSpace($p)) { return '' }
  $t = $p.Trim().Replace('\', '/')
  while ($t.StartsWith('./')) {
    $t = $t.Substring(2)
  }
  while ($t.StartsWith('/')) {
    $t = $t.Substring(1).TrimStart('/')
  }
  return $t
}

function Extract-ApplyPatchPathFromText([string]$text) {
  if ([string]::IsNullOrWhiteSpace($text)) { return '' }
  $m = [regex]::Match($text, '(?ms)\*\*\*\s*(?:Add|Update)\s+File:\s*(.+?)\s*\*\*\*')
  if (-not $m.Success) { return '' }
  return $m.Groups[1].Value.Trim()
}

function Get-ToolTargetPathFromStdinJson {
  param(
    [AllowNull()]$Root,
    [string]$RawStdin,
    [string]$ToolLabel,
    [int]$Depth = 0
  )
  if ($Depth -gt 10) { return '' }

  if (-not [string]::IsNullOrWhiteSpace($RawStdin)) {
    $ap = Extract-ApplyPatchPathFromText $RawStdin
    if (-not [string]::IsNullOrWhiteSpace($ap)) {
      foreach ($tls in @('apply_patch', 'ApplyPatch')) {
        if ([string]::Equals($ToolLabel, $tls, [StringComparison]::OrdinalIgnoreCase)) {
          return $ap
        }
      }
    }
  }

  if ($null -eq $Root) { return '' }

  $pathKeyLower = @{
    'path' = $true
    'target_file' = $true
    'targetfile' = $true
    'file_path' = $true
    'filepath' = $true
    'file' = $true
  }

  if ($Root -is [System.Collections.IDictionary]) {
    foreach ($key in $Root.Keys) {
      $kn = [string]$key
      $klower = $kn.ToLowerInvariant()
      if ($pathKeyLower.ContainsKey($klower)) {
        $v = $Root[$key]
        if ($null -ne $v -and $v -is [string] -and -not [string]::IsNullOrWhiteSpace([string]$v)) {
          return ([string]$v).Trim()
        }
      }
    }
    foreach ($nestKey in @('arguments', 'input', 'payload', 'tool_input', 'toolInput', 'params')) {
      if ($Root.ContainsKey($nestKey)) {
        $inner = Get-ToolTargetPathFromStdinJson -Root $Root[$nestKey] -RawStdin '' -ToolLabel $ToolLabel -Depth ($Depth + 1)
        if (-not [string]::IsNullOrWhiteSpace($inner)) { return $inner }
      }
    }
    foreach ($key in $Root.Keys) {
      $inner = Get-ToolTargetPathFromStdinJson -Root $Root[$key] -RawStdin '' -ToolLabel $ToolLabel -Depth ($Depth + 1)
      if (-not [string]::IsNullOrWhiteSpace($inner)) { return $inner }
    }
    return ''
  }

  if ($Root -is [System.Collections.IEnumerable] -and $Root -isnot [string]) {
    foreach ($item in $Root) {
      $inner = Get-ToolTargetPathFromStdinJson -Root $item -RawStdin '' -ToolLabel $ToolLabel -Depth ($Depth + 1)
      if (-not [string]::IsNullOrWhiteSpace($inner)) { return $inner }
    }
  }

  return ''
}

function Test-PlanScopeFileToolName([string]$name) {
  if ([string]::IsNullOrWhiteSpace($name)) { return $false }
  foreach (
    $x in @(
      'Write', 'Edit', 'MultiEdit', 'StrReplace',
      'apply_patch', 'ApplyPatch'
    )
  ) {
    if ([string]::Equals($x, $name, [StringComparison]::OrdinalIgnoreCase)) {
      return $true
    }
  }
  return $false
}

function Invoke-PlanScopeGate {
  param(
    [string]$RepoRoot,
    [string]$ToolLabel,
    [string]$StdinRaw
  )

  $planJsonPath = Join-Path $RepoRoot '.cursor\task-state\current-plan.json'
  if (-not (Test-Path -LiteralPath $planJsonPath)) {
    return [PSCustomObject]@{ ok = $false; note = 'plan_scope_json_missing' }
  }

  $jsonText = Get-Content -LiteralPath $planJsonPath -Raw -Encoding UTF8 -ErrorAction Stop
  $planObj = $null
  try {
    $planObj = $jsonText | ConvertFrom-Json -ErrorAction Stop
  }
  catch {
    return [PSCustomObject]@{ ok = $false; note = 'plan_scope_json_invalid' }
  }

  $st = ''
  try { $st = [string]$planObj.state } catch { $st = '' }
  if ($st -ne 'approved') {
    return [PSCustomObject]@{ ok = $false; note = 'plan_scope_state_not_approved' }
  }

  $allowNew = $false
  try {
    $allowNew = [bool]$planObj.allowNewFiles
  }
  catch {
    $allowNew = $false
  }

  $approvedRaw = @()
  try {
    if ($null -ne $planObj.approvedFiles) {
      $approvedRaw = @($planObj.approvedFiles)
    }
  }
  catch {
    $approvedRaw = @()
  }

  $approvedNorm = @{}
  foreach ($a in $approvedRaw) {
    if ($null -eq $a) { continue }
    $line = Normalize-PlanScopeRelPath ([string]$a)
    if (-not [string]::IsNullOrWhiteSpace($line)) {
      $approvedNorm[$line] = $true
    }
  }

  $normEnvelope = Normalize-HookStdinEnvelope $StdinRaw
  $root = Get-HookDeserializeRootJs $normEnvelope
  $pathRaw = Get-ToolTargetPathFromStdinJson -Root $root -RawStdin $StdinRaw -ToolLabel $ToolLabel -Depth 0
  if ([string]::IsNullOrWhiteSpace($pathRaw)) {
    return [PSCustomObject]@{ ok = $false; note = 'plan_scope_path_unknown_fail_closed' }
  }

  $repoFull = [System.IO.Path]::GetFullPath($RepoRoot)

  $relCandidate = ''
  try {
    $maybeFull = [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $pathRaw))
    if ($maybeFull.StartsWith($repoFull, [StringComparison]::OrdinalIgnoreCase)) {
      $tail = $maybeFull.Substring($repoFull.Length).TrimStart([char[]]@( '/', '\' ))
      $relCandidate = Normalize-PlanScopeRelPath($tail)
    }
    else {
      $relCandidate = Normalize-PlanScopeRelPath $pathRaw
    }
  }
  catch {
    $relCandidate = Normalize-PlanScopeRelPath $pathRaw
  }

  if ([string]::IsNullOrWhiteSpace($relCandidate)) {
    return [PSCustomObject]@{ ok = $false; note = 'plan_scope_path_empty_after_normalize' }
  }

  $combined = Join-Path $RepoRoot ($relCandidate -replace '/', [System.IO.Path]::DirectorySeparatorChar)
  try {
    $fullTarget = [System.IO.Path]::GetFullPath($combined)
    if (-not $fullTarget.StartsWith($repoFull, [StringComparison]::OrdinalIgnoreCase)) {
      return [PSCustomObject]@{ ok = $false; note = 'plan_scope_path_escape_repo' }
    }
  }
  catch {
    return [PSCustomObject]@{ ok = $false; note = 'plan_scope_path_resolve_error' }
  }

  $exists = Test-Path -LiteralPath $combined
  if (-not $exists -and -not $allowNew) {
    return [PSCustomObject]@{ ok = $false; note = 'plan_scope_new_file_denied' }
  }

  if (-not $approvedNorm.ContainsKey($relCandidate)) {
    return [PSCustomObject]@{ ok = $false; note = 'plan_scope_not_in_approved_files' }
  }

  return [PSCustomObject]@{ ok = $true; note = 'plan_scope_ok' }
}

function Write-HooksDebugOneLine {
  param(
    [string]$ProjRoot,
    [string]$ToolSnippet,
    [string]$GateValue,
    [string]$Blocked,
    [string]$Decision,
    [string]$note
  )
  try {
    if ([string]::IsNullOrWhiteSpace($ProjRoot)) { return }
    $cursorDir = Join-Path $ProjRoot '.cursor'
    if (-not (Test-Path -LiteralPath $cursorDir)) {
      New-Item -ItemType Directory -Path $cursorDir -Force | Out-Null
    }
    $logPath = Join-Path $ProjRoot '.cursor\hooks-debug.log'
    $ts = ([DateTime]::UtcNow.ToString(
      'yyyy-MM-ddTHH:mm:ss.fff',
      [System.Globalization.CultureInfo]::InvariantCulture
    )) + 'Z'
    $safeTool = Escape-ToolNameForLog $ToolSnippet
    $line = "ts=$ts event=preToolUse tool_name=$safeTool gate=$GateValue blocked=$Blocked decision=$Decision note=$note"
    $enc = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::AppendAllText($logPath, ($line + [Environment]::NewLine), $enc)
  }
  catch {
  }
}

function Write-DenyEnvelopePatch {
  $um = '[ROGUE] Edit/write tools blocked. Reply with PLAN only, then next message send exact token APPROVE_PATCH.'
  $am = 'Repo gated: APPROVE_PATCH must appear verbatim in user prompt before edit/terminal tools; see hooks-debug.log for tool_name.'
  @{ permission = 'deny'; user_message = $um; agent_message = $am } | ConvertTo-Json -Compress
}

function Write-DenyEnvelopeSession {
  $um = '[ROGUE 세션 플로] 코드 편집/Task 막힘 — **`시작할게`** 필요. 단, **`끝마칠게` 직후 `commit_allowed`면 git용 터미널(runcmd 등)은 `시작할게` 없이 허용**됩니다(`APPROVE_PATCH`는 그대로).'
  $am = 'session_closed: edits blocked; Shell allowed when commit_allowed after 끝마칠게 — docs/DAILY_WORKFLOW.md'
  @{ permission = 'deny'; user_message = $um; agent_message = $am } | ConvertTo-Json -Compress
}

$stdin = ''
try {
  $stdin = Read-HookPipelineStdin
}
catch {
  $stdin = ''
}

$hookEnv = Read-HookStdinFields $stdin
$toolName = if ([string]::IsNullOrWhiteSpace($hookEnv.tool_name)) {
  ''
}
else {
  [string]$hookEnv.tool_name
}

$projRoot = Get-RepoRootSafe

$hintRepoRoot = ''
try {
  $hintRepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
}
catch {
  $hintRepoRoot = ''
}

$effectiveRootForLog = if (-not [string]::IsNullOrWhiteSpace($projRoot)) { $projRoot } else { $hintRepoRoot }

$flagPath = if (-not [string]::IsNullOrWhiteSpace($projRoot)) {
  Join-Path $projRoot '.cursor\.patch_gate_allow'
}
else {
  ''

}

$gateForLog = if (-not [string]::IsNullOrWhiteSpace($flagPath)) {
  Read-GateValueForLog $flagPath
}
else {
  'noflagpath'
}

$isBlockedTool = Test-BlockedAgentTool $toolName

if ([string]::IsNullOrWhiteSpace($projRoot)) {
  if ($isBlockedTool) {
    Write-HooksDebugOneLine -ProjRoot $effectiveRootForLog -ToolSnippet $toolName `
      -GateValue $gateForLog -Blocked 'yes' -Decision 'deny' -note 'missing_repo_root'
    Write-DenyEnvelopePatch
    exit 0
  }
  Write-HooksDebugOneLine -ProjRoot $effectiveRootForLog -ToolSnippet $toolName `
    -GateValue $gateForLog -Blocked 'no' -Decision 'allow' -note 'missing_repo_root_nonblocked'
  @{ permission = 'allow' } | ConvertTo-Json -Compress
  exit 0

}

try {
  $allowed = Read-GateOpen $flagPath
  $blockedTag = if ($isBlockedTool) { 'yes' } else { 'no' }

  if (-not $isBlockedTool) {
    Write-HooksDebugOneLine -ProjRoot $projRoot -ToolSnippet $toolName `
      -GateValue $gateForLog -Blocked $blockedTag -Decision 'allow' -note 'nonblocked_tool'
    @{ permission = 'allow' } | ConvertTo-Json -Compress
    exit 0
  }

  if ($allowed) {
    $dailyStatePath = Join-Path $projRoot '.cursor\.daily_workflow_state.json'
    # 상태 파일이 아직 없음 = 토큰으로 한 번도 기록 안 됨 — 세션 게이트 생략(APPROVE_PATCH만 적용)
    if (Test-Path -LiteralPath $dailyStatePath) {
      $sessionOpen = Get-WorkflowSessionActive -RepoRoot $projRoot
      if (-not $sessionOpen) {
        if ((Test-ShellLikeTool $toolName) -and (Get-WorkflowCommitAllowed -RepoRoot $projRoot)) {
          Write-HooksDebugOneLine -ProjRoot $projRoot -ToolSnippet $toolName `
            -GateValue $gateForLog -Blocked $blockedTag -Decision 'allow' -note 'session_closed_shell_commit_ok'
          @{ permission = 'allow' } | ConvertTo-Json -Compress
          exit 0
        }
        Write-HooksDebugOneLine -ProjRoot $projRoot -ToolSnippet $toolName `
          -GateValue $gateForLog -Blocked $blockedTag -Decision 'deny' -note 'session_closed'
        Write-DenyEnvelopeSession
        exit 0
      }
      $noteSession = 'gate_open_session_ok'
    }
    else {
      $noteSession = 'gate_open_session_bootstrap_skip'
    }
    if (Test-PlanScopeFileToolName $toolName) {
      try {
        $ps = Invoke-PlanScopeGate -RepoRoot $projRoot -ToolLabel $toolName -StdinRaw $stdin
        if (-not $ps.ok) {
          Write-HooksDebugOneLine -ProjRoot $projRoot -ToolSnippet $toolName `
            -GateValue $gateForLog -Blocked $blockedTag -Decision 'deny' -note ($noteSession + '_' + $ps.note)
          Write-DenyEnvelopePlanScope -Reason $ps.note
          exit 0
        }
        $noteSession = $noteSession + '_' + $ps.note
      }
      catch {
        Write-HooksDebugOneLine -ProjRoot $projRoot -ToolSnippet $toolName `
          -GateValue $gateForLog -Blocked $blockedTag -Decision 'deny' -note ($noteSession + '_plan_scope_script_error')
        Write-DenyEnvelopePlanScope -Reason 'plan_scope_script_error'
        exit 0
      }
    }
    Write-HooksDebugOneLine -ProjRoot $projRoot -ToolSnippet $toolName `
      -GateValue $gateForLog -Blocked $blockedTag -Decision 'allow' -note $noteSession
    @{ permission = 'allow' } | ConvertTo-Json -Compress
    exit 0
  }

  Write-HooksDebugOneLine -ProjRoot $projRoot -ToolSnippet $toolName `
    -GateValue $gateForLog -Blocked $blockedTag -Decision 'deny' -note 'gate_closed'
  Write-DenyEnvelopePatch
  exit 0
}
catch {
  if ($isBlockedTool) {
    Write-HooksDebugOneLine -ProjRoot $projRoot -ToolSnippet $toolName `
      -GateValue $gateForLog -Blocked 'yes' -Decision 'deny_fail_closed' -note 'script_error'
    $um = '[ROGUE] enforce-patch-gate.ps1 error - denying invocation (fail-closed).'
    $am = 'Hook threw; unblock only after APPROVE_PATCH and hooks work again.'
    @{ permission = 'deny'; user_message = $um; agent_message = $am } | ConvertTo-Json -Compress
    exit 0
  }

  Write-HooksDebugOneLine -ProjRoot $projRoot -ToolSnippet $toolName `
    -GateValue $gateForLog -Blocked 'no' -Decision 'allow' -note 'nonblocked_after_error'
  @{ permission = 'allow' } | ConvertTo-Json -Compress
  exit 0
}
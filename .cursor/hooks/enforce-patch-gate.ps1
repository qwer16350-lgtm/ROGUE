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
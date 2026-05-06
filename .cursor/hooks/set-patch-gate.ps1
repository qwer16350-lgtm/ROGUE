<#
  beforeSubmitPrompt - Writes .cursor/.patch_gate_allow to "1" only if the prompt contains
  ASCII token APPROVE_PATCH as a standalone token.

  Fallback: JSON parse failure (parse=json_error) or empty extracted prompt — scan raw stdin with the same token regex.

  Always prints { continue: true }; edit gate is enforced in enforce-patch-gate.ps1 (preToolUse).

  Appends ASCII lines to .cursor/hooks-debug.log: stdin length, JSON parse outcome, gate.
  UTF-8 with BOM (script file).

  On resolve/write failure uses fail-closed gate file "0".
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

function Set-GateSafe {
  param([string]$Path, [string]$Value)
  $dir = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
  }
  $enc = New-Object System.Text.UTF8Encoding $false
  [System.IO.File]::WriteAllText($Path, $Value, $enc)
}

function Test-ApprovePatchToken {
  param([string]$prompt)
  if ([string]::IsNullOrWhiteSpace($prompt)) { return $false }
  return [regex]::IsMatch($prompt, '(?<![A-Za-z0-9_])APPROVE_PATCH(?![A-Za-z0-9_])')
}

function Write-BeforeSubmitDebugLine {
  param(
    [string]$ProjRoot,
    [string]$stdinLen,
    [string]$promptLen,
    [string]$ParseStatus,
    [string]$GateVal,
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
    $line = "ts=$ts event=beforeSubmitPrompt stdin_chars=$stdinLen prompt_chars=$promptLen parse=$ParseStatus gate=$GateVal note=$note"
    $enc = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::AppendAllText($logPath, ($line + [Environment]::NewLine), $enc)
  }
  catch {
  }
}

$stdin = ''
try {
  $stdin = Read-HookPipelineStdin
}
catch {
  $stdin = ''
}

$stdinLenStr = if ([string]::IsNullOrWhiteSpace($stdin)) { '0' } else { "$($stdin.Length)" }

$hookEnv = Read-HookStdinFields $stdin
$parseStatus = $hookEnv.parse
$prompt = [string]$hookEnv.prompt
$promptLenStr = if ([string]::IsNullOrWhiteSpace($prompt)) { '0' } else { "$($prompt.Length)" }

$projRoot = Get-RepoRootSafe

$hintRepoRoot = ''
try {
  $hintRepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
}
catch {
  $hintRepoRoot = ''
}

try {
  if ([string]::IsNullOrWhiteSpace($projRoot)) {
    Write-BeforeSubmitDebugLine -ProjRoot $hintRepoRoot -stdinLen $stdinLenStr -promptLen $promptLenStr `
      -ParseStatus $parseStatus -GateVal '0' -note 'missing_repo_root'
    @{ continue = $true } | ConvertTo-Json -Compress
    exit 0
  }
  $flagPath = Join-Path $projRoot '.cursor\.patch_gate_allow'
  $openedViaPrimary = ($parseStatus -like 'json_ok*') -and (Test-ApprovePatchToken $prompt)
  $val = if ($openedViaPrimary) { '1' } else { '0' }

  $tryRawStdinFallback = ($parseStatus -eq 'json_error') -or ([string]::IsNullOrWhiteSpace($prompt))
  $stdinHasApprovePatch = Test-ApprovePatchToken $stdin
  if (($val -eq '0') -and $tryRawStdinFallback -and $stdinHasApprovePatch) {
    $val = '1'
  }

  Set-GateSafe -Path $flagPath -Value $val

  try {
    if ($parseStatus -like 'json_ok*') {
      Update-WorkflowFromUserPrompt -RepoRoot $projRoot -UserPrompt $prompt
    }
  }
  catch {
  }

  $note = 'ok'
  if ($val -eq '1') {
    if ((-not $openedViaPrimary) -and $tryRawStdinFallback -and $stdinHasApprovePatch) {
      $note = 'gate_open_raw_stdin_fallback'
    }
  }
  elseif ($parseStatus -eq 'json_error') { $note = 'gate_forced_zero_json_error' }
  elseif ($parseStatus -eq 'stdin_empty') { $note = 'gate_forced_zero_stdin_empty' }
  Write-BeforeSubmitDebugLine -ProjRoot $projRoot -stdinLen $stdinLenStr -promptLen $promptLenStr `
    -ParseStatus $parseStatus -GateVal $val -note $note

  @{ continue = $true } | ConvertTo-Json -Compress
}
catch {
  try {
    $pr = Get-RepoRootSafe
    if (-not [string]::IsNullOrWhiteSpace($pr)) {
      $fp = Join-Path $pr '.cursor\.patch_gate_allow'
      Set-GateSafe -Path $fp -Value '0'
      Write-BeforeSubmitDebugLine -ProjRoot $pr -stdinLen $stdinLenStr -promptLen $promptLenStr `
        -ParseStatus $parseStatus -GateVal '0' -note 'catch_set_gate_zero'
    }
  }
  catch {
  }

  @{ continue = $true } | ConvertTo-Json -Compress
  exit 0
}

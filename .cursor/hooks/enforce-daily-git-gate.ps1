<#
  beforeShellExecution — 로컬에 commit_allowed 없으면 git commit / git push 차단.
  다른 터미널·GUI git 은 차단 불가(docs/DAILY_WORKFLOW 참고).

  stdin 에서 command 문자열 추출 (Cursor 이벤트 형식 차이 허용).
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

function Get-ShellCommandFromStdin([string]$RawStdin) {
  $norm = Normalize-HookStdinEnvelope $RawStdin
  $root = Get-HookDeserializeRootJs $norm
  if ($null -ne $root) {
    foreach ($k in @('command', 'full_command', 'shellCommand')) {
      $v = Get-HookIndexValue $root $k
      if (($null -ne $v) -and ($v -is [string]) -and -not [string]::IsNullOrWhiteSpace([string]$v)) {
        return ([string]$v).Trim()
      }
    }
    foreach ($nk in @('input', 'payload', 'arguments')) {
      $ns = Get-HookIndexValue $root $nk
      if ($null -eq $ns) {
        continue
      }
      foreach ($k in @('command', 'commandLine', 'line')) {
        $v2 = Get-HookIndexValue $ns $k
        if (($null -ne $v2) -and ($v2 -is [string]) -and -not [string]::IsNullOrWhiteSpace([string]$v2)) {
          return ([string]$v2).Trim()
        }
      }
    }
  }

  foreach ($qk in @('command', 'full_command')) {
    $rx = Invoke-HookExtractQuotedPair -RawEnvelope $norm -KeyWithoutQuotes $qk
    if (-not [string]::IsNullOrWhiteSpace($rx)) {
      return $rx.Trim()
    }
  }

  return ''
}

function Test-IsGitCommitOrPush([string]$cmd) {
  if ([string]::IsNullOrWhiteSpace($cmd)) {
    return $false
  }
  $trim = ($cmd.Trim() -replace '^\$\s+|^cmd\s+/c\s+', '')
  $lower = $trim.ToLowerInvariant()
  if (($lower -notmatch '\bgit\b') -and ($lower -notmatch 'git\.exe')) {
    return $false
  }
  return ($lower -match '\bcommit\b') -or ($lower -match '\bpush\b')
}

$stdin = ''
try {
  $stdin = Read-HookPipelineStdin
}
catch {
  $stdin = ''
}

$command = Get-ShellCommandFromStdin $stdin
$projRoot = Get-RepoRootSafe

if ([string]::IsNullOrWhiteSpace($projRoot)) {
  @{ permission = 'allow' } | ConvertTo-Json -Compress
  exit 0
}

$dailyStatePath = Join-Path $projRoot '.cursor\.daily_workflow_state.json'
if (-not (Test-Path -LiteralPath $dailyStatePath)) {
  @{ permission = 'allow' } | ConvertTo-Json -Compress
  exit 0
}

if (-not (Test-IsGitCommitOrPush $command)) {
  @{ permission = 'allow' } | ConvertTo-Json -Compress
  exit 0
}

try {
  $ca = Get-WorkflowCommitAllowed -RepoRoot $projRoot
  if (-not $ca) {
    $um = '[ROGUE 일일 플로] git commit/push 차단 — 사용자 메시지에 먼저 **끝마칠게**가 필요합니다(commit_allowed 미설정).'
    $am = 'enforce-daily-git-gate: set commit_allowed via 끝마칠게 in beforeSubmitPrompt; see docs/DAILY_WORKFLOW.md'
    @{ permission = 'deny'; user_message = $um; agent_message = $am } | ConvertTo-Json -Compress
    exit 0
  }

  @{ permission = 'allow' } | ConvertTo-Json -Compress
}
catch {
  $um = '[ROGUE 일일 플로] git 게이트 스크립트 오류로 셸이 거부됨.'
  @{ permission = 'deny'; user_message = $um; agent_message = 'enforce-daily-git-gate threw' } | ConvertTo-Json -Compress
  exit 0
}

<#
  작업 세션 (시작할게 / 끝마칠게).

  - 달력으로 세션을 끊지 않음 — 자정을 넘겨도 끝마칠게 전까지 같은 구간.
  - 같은 날·같은 시각 블록에 여러 번 가능.
  - 한 프롬프트에 두 토큰이 있으면 항상 **끝마칠게 처리 후 시작할게**(연속 종료 후 새 시작 허용).
  - session_active 가 false 이면 Cursor 편집/셸 도구가 금지(아래 세션 허브 enforce-patch-gate 참고).
  - segments[] 에 시작/종료 시각 + 짧은 프롬프트 발췌 저장.

  .cursor/.daily_workflow_state.json — .gitignore
#>
$ErrorActionPreference = 'Stop'

function Get-DailyWorkflowStatePath {
  param([string]$RepoRoot)
  return (Join-Path $RepoRoot '.cursor\.daily_workflow_state.json')
}

function New-EmptyWorkflowState {
  return [PSCustomObject]@{
    schema                    = 1
    session_active            = $false
    commit_allowed             = $false
    current_segment_start_iso = $null
    current_start_excerpt     = $null
    segments                  = @()
  }
}

function Read-WorkflowState {
  param([string]$RepoRoot)

  $path = Get-DailyWorkflowStatePath $RepoRoot
  if (-not (Test-Path -LiteralPath $path)) {
    return (New-EmptyWorkflowState)
  }
  try {
    $raw = Get-Content -LiteralPath $path -Raw -Encoding UTF8
    if ([string]::IsNullOrWhiteSpace($raw)) {
      return (New-EmptyWorkflowState)
    }
    $o = $raw | ConvertFrom-Json
    $segments = New-Object System.Collections.ArrayList
    if ($null -ne $o.segments) {
      foreach ($x in @($o.segments)) {
        [void]$segments.Add([PSCustomObject]@{
            started_at     = [string]$x.started_at
            ended_at       = [string]$x.ended_at
            start_excerpt  = if ($null -eq $x.start_excerpt) { '' } else { [string]$x.start_excerpt }
            end_excerpt    = if ($null -eq $x.end_excerpt) { '' } else { [string]$x.end_excerpt }
          })
      }
    }
    return [PSCustomObject]@{
      schema                    = if ($null -ne $o.schema) { [int]$o.schema } else { 1 }
      session_active             = ([bool]$o.session_active -eq $true)
      commit_allowed             = ([bool]$o.commit_allowed -eq $true)
      current_segment_start_iso  = if ($null -eq $o.current_segment_start_iso) { $null } else { [string]$o.current_segment_start_iso }
      current_start_excerpt      = if ($null -eq $o.current_start_excerpt) { $null } else { [string]$o.current_start_excerpt }
      segments                   = @($segments.ToArray())
    }
  }
  catch {
    return (New-EmptyWorkflowState)
  }
}

function Save-WorkflowState {
  param([Parameter(Mandatory)][string]$RepoRoot, [Parameter(Mandatory)]$State)

  $cursorDir = Join-Path $RepoRoot '.cursor'
  if (-not (Test-Path -LiteralPath $cursorDir)) {
    New-Item -ItemType Directory -Path $cursorDir -Force | Out-Null
  }
  $path = Get-DailyWorkflowStatePath $RepoRoot

  $segList = New-Object System.Collections.ArrayList
  foreach ($s in @($State.segments)) {
    [void]$segList.Add([ordered]@{
        started_at     = [string]$s.started_at
        ended_at       = [string]$s.ended_at
        start_excerpt  = [string]$s.start_excerpt
        end_excerpt    = [string]$s.end_excerpt
      })
  }

  $obj = [ordered]@{
    schema                     = [int]$State.schema
    session_active             = [bool]$State.session_active
    commit_allowed             = [bool]$State.commit_allowed
    current_segment_start_iso = $State.current_segment_start_iso
    current_start_excerpt     = $State.current_start_excerpt
    segments                  = @($segList.ToArray())
  }

  $enc = New-Object System.Text.UTF8Encoding $false
  [System.IO.File]::WriteAllText($path, (([string](ConvertTo-Json -InputObject $obj -Depth 8 -Compress))), $enc)
}

function Test-KoreanSubstring {
  param([AllowNull()] [string]$Haystack, [string]$Needle)
  if ([string]::IsNullOrWhiteSpace($Haystack) -or [string]::IsNullOrWhiteSpace($Needle)) {
    return $false
  }
  return $Haystack.IndexOf($Needle, [StringComparison]::Ordinal) -ge 0
}

function Get-PromptExcerpt {
  param([AllowNull()] [string]$Prompt, [int]$MaxLen = 400)
  if ([string]::IsNullOrWhiteSpace($Prompt)) {
    return ''
  }
  $one = (($Prompt -replace "[\r\n]+", ' ').Trim())
  if ($one.Length -le $MaxLen) {
    return $one
  }
  return ($one.Substring(0, $MaxLen) + '...')
}

function Get-WorkflowSessionActive {
  param([string]$RepoRoot)
  if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    return $false
  }
  return ([bool](Read-WorkflowState $RepoRoot).session_active -eq $true)
}

function Get-WorkflowCommitAllowed {
  param([string]$RepoRoot)
  if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    return $false
  }
  return ([bool](Read-WorkflowState $RepoRoot).commit_allowed -eq $true)
}

function Update-WorkflowFromUserPrompt {
  param(
    [Parameter(Mandatory)][string]$RepoRoot,
    [AllowNull()] [string]$UserPrompt
  )

  $prompt = [string]$UserPrompt

  $hasStart = Test-KoreanSubstring $prompt '시작할게'
  $hasEnd = Test-KoreanSubstring $prompt '끝마칠게'

  if (-not $hasStart -and -not $hasEnd) {
    return
  }

  $st = Read-WorkflowState $RepoRoot
  $st.schema = 1
  $nowIso = (Get-Date).ToString('o')

  # ----- 1) 끝먼저: 연속 종료 후 같은 말풍선에서 새 시작 -----
  if ($hasEnd) {
    if (($st.session_active -eq $true) -and -not [string]::IsNullOrWhiteSpace([string]$st.current_segment_start_iso)) {
      $newSeg = [PSCustomObject]@{
        started_at     = [string]$st.current_segment_start_iso
        ended_at       = $nowIso
        start_excerpt  = if ($null -eq $st.current_start_excerpt) { '' } else { [string]$st.current_start_excerpt }
        end_excerpt    = Get-PromptExcerpt $prompt
      }
      $list = New-Object System.Collections.ArrayList
      foreach ($x in @($st.segments)) {
        [void]$list.Add($x)
      }
      [void]$list.Add($newSeg)
      while ($list.Count -gt 200) {
        [void]$list.RemoveAt(0)
      }
      $st.segments = @($list.ToArray())
    }
    $st.session_active = $false
    $st.current_segment_start_iso = $null
    $st.current_start_excerpt = $null
    $st.commit_allowed = $true
  }

  # ----- 2) 시작: 닫혀 있는 동안만 새 구간 열림 -----
  if ($hasStart) {
    if ($st.session_active -ne $true) {
      $st.session_active = $true
      $st.current_segment_start_iso = $nowIso
      $st.current_start_excerpt = Get-PromptExcerpt $prompt
      $st.commit_allowed = $false
    }
  }

  Save-WorkflowState -RepoRoot $RepoRoot -State $st
}

<#
  Cursor sessionStart hook — inject .cursor/rules (*.mdc), agents (*.md), skills (**/SKILL.md)
  stdout: JSON { "additional_context": "<string>" }
  Project root = two directories above this file.
  Rules: full body. Agents / SKILL.md: path + title + role + summary index only.
#>
$ErrorActionPreference = 'Stop'

function Build-AgentIndex([string]$RelPath, [string]$Raw) {
  $title = '(no title)'
  foreach ($line in ($Raw -split "`r?`n")) {
    $t = $line.Trim()
    if ($t.StartsWith('#')) {
      $title = $t
      break
    }
  }
  $role = '(none)'
  foreach ($line in ($Raw -split "`r?`n")) {
    $t = $line.Trim()
    if ($t.StartsWith('>')) {
      $role = ($t -replace '^>\s*', '').Trim()
      $role = ($role -replace '\*\*', '').Trim()
      if ($role.Length -gt 240) {
        $role = $role.Substring(0, 237) + '...'
      }
      break
    }
  }
  $summary = $title.TrimStart('#').Trim()
  if (-not [string]::IsNullOrWhiteSpace($role) -and $role -ne '(none)') {
    $summary = if ($role.Length -gt 160) { $role.Substring(0, 157) + '...' } else { $role }
  }
  return (
    'path: `' + $RelPath + '`' + [Environment]::NewLine +
      'title: ' + $title + [Environment]::NewLine +
      'role: ' + $role + [Environment]::NewLine +
      'summary: ' + $summary + [Environment]::NewLine
  )
}

function Build-SkillIndex([string]$RelPath, [string]$Raw) {
  $title = '(no title)'
  foreach ($line in ($Raw -split "`r?`n")) {
    $t = $line.Trim()
    if ($t.StartsWith('#') -and -not $t.StartsWith('##')) {
      $title = $t
      break
    }
  }
  $fmText = ''
  if ($Raw -match '(?ms)\A---\s*\r?\n(?<fm>.*?)\r?\n---\s*\r?\n') {
    $fmText = $Matches['fm']
  }
  $summary = ''
  $descm = [regex]::Match($fmText, '(?m)^description:\s*(.+)$')
  if ($descm.Success) {
    $summary = $descm.Groups[1].Value.Trim()
  }
  if ([string]::IsNullOrWhiteSpace($summary)) {
    $nm = [regex]::Match($fmText, '(?m)^name:\s*(.+)$')
    if ($nm.Success) {
      $summary = $nm.Groups[1].Value.Trim()
    }
  }
  if ([string]::IsNullOrWhiteSpace($summary)) {
    $summary = $title.TrimStart('#').Trim()
  }
  if ([string]::IsNullOrWhiteSpace($summary)) {
    $summary = '(no summary)'
  }
  if ($summary.Length -gt 240) {
    $summary = $summary.Substring(0, 237) + '...'
  }
  return (
    'path: `' + $RelPath + '`' + [Environment]::NewLine +
      'title: ' + $title + [Environment]::NewLine +
      'role: Skill (procedure checklist)' + [Environment]::NewLine +
      'summary: ' + $summary + [Environment]::NewLine
  )
}

try {
  $stdin = [Console]::In.ReadToEnd()
  if (-not [string]::IsNullOrWhiteSpace($stdin)) {
    $null = $stdin | ConvertFrom-Json
  }

  $projRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path

  $parts = New-Object System.Collections.ArrayList
  [void]$parts.Add('## MANDATORY PROJECT RULES (injected by .cursor hook)')
  [void]$parts.Add('Treat every block below as binding for this Composer session.')
  [void]$parts.Add('')
  [void]$parts.Add('Agents and SKILL.md entries below are **indexes only** — open the repo path for full text.')
  [void]$parts.Add('')

  $files = @()
  $rulesDir = Join-Path $projRoot '.cursor\rules'
  $agentsDir = Join-Path $projRoot '.cursor\agents'
  $skillsDir = Join-Path $projRoot '.cursor\skills'

  if (Test-Path -LiteralPath $rulesDir) {
    $files += Get-ChildItem -LiteralPath $rulesDir -Filter '*.mdc' -File -ErrorAction SilentlyContinue
  }
  if (Test-Path -LiteralPath $agentsDir) {
    $files += Get-ChildItem -LiteralPath $agentsDir -Filter '*.md' -File -ErrorAction SilentlyContinue
  }
  if (Test-Path -LiteralPath $skillsDir) {
    $files += Get-ChildItem -LiteralPath $skillsDir -Recurse -Filter 'SKILL.md' -File -ErrorAction SilentlyContinue
  }

  $sorted = $files | Sort-Object FullName
  $maxChars = 200000
  $total = 0
  $nl = [Environment]::NewLine

  foreach ($f in $sorted) {
    $rel = $f.FullName.Substring($projRoot.Length).TrimStart('\', '/')
    $body = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8

    $isRule = $rel -match '(?i)^\.cursor[/\\]rules[/\\].+\.mdc$'
    $isAgent = $rel -match '(?i)^\.cursor[/\\]agents[/\\].+\.md$'
    $isSkill = $rel -match '(?i)SKILL\.md$'

    $payload = $body
    if ($isAgent) {
      $payload = Build-AgentIndex $rel $body
    }
    elseif ($isSkill) {
      $payload = Build-SkillIndex $rel $body
    }

    $header = "--- FILE: $rel ---"
    $block = $header + $nl + $payload
    if ($total + $block.Length + 2 -gt $maxChars) {
      [void]$parts.Add('')
      [void]$parts.Add('(Further .cursor files omitted: approached ' + $maxChars + ' character budget.)')
      break
    }
    [void]$parts.Add($block)
    [void]$parts.Add('')
    $total += $block.Length + 2
  }

  $blob = ($parts -join $nl)
  $out = @{ additional_context = $blob }
  $out | ConvertTo-Json -Compress -Depth 3
}
catch {
  $msg = $_.Exception.Message
  $fallbackText = '[hook inject-cursor-rules.ps1 failed: ' + $msg + '] Still obey .cursor/rules, .cursor/agents, and AGENTS.md.'
  $fallback = @{ additional_context = $fallbackText }
  $fallback | ConvertTo-Json -Compress
  exit 0
}
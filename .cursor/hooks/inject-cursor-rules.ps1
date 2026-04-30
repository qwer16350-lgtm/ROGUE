<#
  Cursor sessionStart hook — inject .cursor/rules (*.mdc), agents (*.md), skills (**/SKILL.md)
  stdout: JSON { "additional_context": "<string>" }
  Project root = two directories above this file.
#>
$ErrorActionPreference = 'Stop'
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
    $header = "--- FILE: $rel ---"
    $block = $header + $nl + $body
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

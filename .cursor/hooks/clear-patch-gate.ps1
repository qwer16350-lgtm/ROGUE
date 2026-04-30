<#
  stop — 에이전트 루프 종료 시 패치 게이트를 닫아 다음 사용자 요청부터 다시 플랜 선행.
#>
$ErrorActionPreference = 'Stop'
try {
  $null = [Console]::In.ReadToEnd()

  $projRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
  $flagPath = Join-Path $projRoot '.cursor\.patch_gate_allow'

  if (Test-Path -LiteralPath $flagPath) {
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($flagPath, '0', $utf8)
  }

  '{}' 
}
catch {
  '{}'
  exit 0
}

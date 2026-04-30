<#
  Shared Cursor hook stdin JSON parse for PowerShell 5.1.
  UTF-8 stdin + JavaScriptSerializer; regex fallback extracts prompt/tool_name when parsers fail.

  Dot-source from set-patch-gate.ps1 and enforce-patch-gate.ps1 only.
#>
$ErrorActionPreference = 'Continue'

function Read-HookPipelineStdin {
  try {
    $inputStream = [Console]::OpenStandardInput()
    $enc = New-Object System.Text.UTF8Encoding $false
    $reader = New-Object System.IO.StreamReader($inputStream, $enc, $true)
    return $reader.ReadToEnd()
  }
  catch {
    try {
      return [Console]::In.ReadToEnd()
    }
    catch {
      return ''
    }
  }
}

function Normalize-HookStdinEnvelope {
  param([string]$s)
  if ([string]::IsNullOrWhiteSpace($s)) { return '' }
  $t = $s.Trim()
  if ($t.Length -gt 0 -and [int][char]$t[0] -eq 0xFEFF) {
    $t = $t.Substring(1).TrimStart()
  }
  # Strip leading BOM bytes if mis-decoded into replacement chars occasionally
  $t = $t.Trim([char]0)
  $i = $t.IndexOf('{')
  if ($i -gt 0) {
    $t = $t.Substring($i)
  }
  return $t.TrimEnd([char]0)
}

function Expand-HookJsonStringBody {
  param([AllowNull()] [string]$body)
  if ($null -eq $body) { return '' }
  $sb = New-Object System.Text.StringBuilder
  $i = 0
  while ($i -lt $body.Length) {
    $ch = $body[$i]
    if ([int][char]$ch -eq 0x5C) {
      if (($i + 1) -ge $body.Length) {
        [void]$sb.Append($ch)
        break
      }
      $nx = $body[$i + 1]
      $nsk = "$nx"
      if ($nsk -eq '"') { [void]$sb.Append('"'); $i += 2; continue }
      if ($nsk -eq '\') { [void]$sb.Append('\'); $i += 2; continue }
      if ($nsk -eq 'n') { [void]$sb.Append("`n"); $i += 2; continue }
      if ($nsk -eq 'r') { [void]$sb.Append("`r"); $i += 2; continue }
      if ($nsk -eq 't') { [void]$sb.Append("`t"); $i += 2; continue }
      if ($nsk -eq 'u' -and ($i + 6) -le $body.Length) {
        $hx = $body.Substring($i + 2, 4)
        try { [void]$sb.Append([char][Convert]::ToInt32($hx, 16)) }
        catch { [void]$sb.Append('\u'); [void]$sb.Append($hx) }
        $i += 6
        continue
      }
      [void]$sb.Append('\')
      [void]$sb.Append("$nx")
      $i += 2
      continue
    }
    [void]$sb.Append($ch)
    $i++
  }
  return $sb.ToString()
}

function Invoke-HookExtractQuotedPair {
  param([string]$RawEnvelope, [string]$KeyWithoutQuotes)

  # JSON string value for key; supports escapes inside quotes.
  $keyPat = '\"' + ([regex]::Escape($KeyWithoutQuotes)) + '\"\s*:\s*\"'
  $m = [regex]::Match($RawEnvelope, $keyPat + '(?<inner>(\\\\.|[^\"\\\\])*)\"', [Text.RegularExpressions.RegexOptions]::Singleline)
  if (-not $m.Success) { return '' }

  return (Expand-HookJsonStringBody $m.Groups['inner'].Value)
}

function Get-HookDeserializeRootJs {
  param([string]$RawInput)
  if ([string]::IsNullOrWhiteSpace($RawInput)) { return $null }
  try {
    [void][System.Reflection.Assembly]::LoadWithPartialName('System.Web.Extensions')
    $ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer -ErrorAction Stop
    $ser.MaxJsonLength = 2147483647
    return $ser.DeserializeObject($RawInput)
  }
  catch {
    return $null
  }
}

function Get-HookIndexValue {
  param(
    [AllowNull()]$Root,
    [string]$KeyName
  )
  if ($null -eq $Root -or [string]::IsNullOrWhiteSpace($KeyName)) { return $null }
  try { return $Root[$KeyName] } catch { return $null }
}

function Resolve-HookPromptRaw {
  param(
    [AllowNull()]$Root,
    [int]$Depth = 0
  )
  if ($null -eq $Root -or $Depth -gt 2) { return '' }
  $p = Get-HookIndexValue $Root 'prompt'
  if ($null -ne $p) { return [string]$p }
  try {
    if ($null -ne $Root.prompt) { return [string]$Root.prompt }
  }
  catch {
  }
  if ($Depth -lt 2) {
    foreach ($wk in @('input', 'payload')) {
      $nested = Get-HookIndexValue $Root $wk
      if ($null -ne $nested) {
        $inner = Resolve-HookPromptRaw -Root $nested -Depth ($Depth + 1)
        if (-not [string]::IsNullOrWhiteSpace($inner)) { return $inner }
      }
    }
  }
  return ''
}

function Resolve-HookToolNameRaw {
  param(
    [AllowNull()]$Root,
    [int]$Depth = 0
  )
  if ($null -eq $Root -or $Depth -gt 2) { return '' }

  foreach ($k in @('tool_name', 'toolName', 'tool', 'tool_type', 'toolType')) {
    $v = Get-HookIndexValue $Root $k
    if ($null -eq $v) { continue }
    if ($v -is [string] -and -not [string]::IsNullOrWhiteSpace($v)) {
      return $v.Trim()
    }
    foreach ($nk in @('name', 'toolName', 'tool_name', 'toolType', 'type')) {
      $v2 = Get-HookIndexValue $v $nk
      if ($null -ne $v2 -and -not [string]::IsNullOrWhiteSpace([string]$v2)) {
        return ([string]$v2).Trim()
      }
      try {
        if ($null -ne $v2 -and $null -ne $v2.psobject.Properties[$nk]) {
          return [string]$v2.psobject.Properties[$nk].Value
        }
      }
      catch {
      }
    }
  }

  $only = Get-HookIndexValue $Root 'name'
  if ($null -ne $only -and -not [string]::IsNullOrWhiteSpace([string]$only)) {
    return ([string]$only).Trim()
  }

  if ($Depth -lt 2) {
    foreach ($wk in @('input', 'payload', 'arguments', 'toolCall', 'tool_call')) {
      $nested = Get-HookIndexValue $Root $wk
      if ($null -ne $nested) {
        $sx = Resolve-HookToolNameRaw -Root $nested -Depth ($Depth + 1)
        if (-not [string]::IsNullOrWhiteSpace($sx)) { return $sx }
      }
    }
  }

  return ''
}

function Read-HookStdinFields {
  param([string]$RawStdin)

  if ([string]::IsNullOrWhiteSpace($RawStdin)) {
    return [PSCustomObject]@{
      parse     = 'stdin_empty'
      prompt    = ''
      tool_name = ''
    }
  }

  $norm = Normalize-HookStdinEnvelope $RawStdin
  $parse = 'json_error'
  $prompt = ''
  $toolNameOut = ''

  $root = Get-HookDeserializeRootJs $norm
  if ($null -ne $root) {
    $parse = 'json_ok_js'
    $prompt = Resolve-HookPromptRaw $root
    $toolNameOut = Resolve-HookToolNameRaw $root
    return [PSCustomObject]@{ parse = $parse; prompt = $prompt; tool_name = $toolNameOut }
  }

  try {
    $cfj = $norm | ConvertFrom-Json -ErrorAction Stop
    $parse = 'json_ok_cfj'
    $prompt = Resolve-HookPromptRaw $cfj
    $toolNameOut = Resolve-HookToolNameRaw $cfj
    return [PSCustomObject]@{ parse = $parse; prompt = $prompt; tool_name = $toolNameOut }
  }
  catch {
    # Regex salvage — often works when serializers choke on nesting or encoding quirks
    foreach ($qk in @('prompt')) {
      $rxPrompt = Invoke-HookExtractQuotedPair $norm $qk
      if (-not [string]::IsNullOrWhiteSpace($rxPrompt)) {
        $prompt = $rxPrompt
        break
      }
    }
    foreach ($tk in @('tool_name', 'toolName')) {
      $rxTn = Invoke-HookExtractQuotedPair $norm $tk
      if (-not [string]::IsNullOrWhiteSpace($rxTn)) {
        $toolNameOut = $rxTn.Trim()
        break
      }
    }

    if ((-not [string]::IsNullOrWhiteSpace($prompt)) -or (-not [string]::IsNullOrWhiteSpace($toolNameOut))) {
      $parse = 'json_ok_rx'
    }

    return [PSCustomObject]@{
      parse     = $parse
      prompt    = $prompt
      tool_name = $toolNameOut
    }
  }
}

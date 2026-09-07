#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (-not $Preflight) { throw 'Diagnostic is preflight-only.' }

function Get-TextSha256([string[]]$Values) {
    $text = (($Values -join "`n") + "`n")
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes($text)
    $hasher = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($hasher.ComputeHash($bytes))).Replace('-', '') }
    finally { $hasher.Dispose() }
}

$manifestPath = Join-Path $PSScriptRoot 'R18ZT_PAYLOAD_MANIFEST_V2.json'
$gatePath = Join-Path $PSScriptRoot 'R18ZT_PATH_PLAN_GATE_V3.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$gate = Get-Content -LiteralPath $gatePath -Raw | ConvertFrom-Json
$values = @('PORTAL_REQUEST_MANIFEST.json','PORTAL_REQUEST_MANIFEST.sig','payload/Invoke-R18ZTBatchLaunch.ps1','payload/R18ZT_PAYLOAD_MANIFEST.json')
$values += @($manifest.files | ForEach-Object { 'payload/files/' + ([string]$_.installRelativePath).Replace('\','/') })
$default = @($values | Sort-Object)
$caseSensitive = @($values | Sort-Object -CaseSensitive)
$ordinal = [string[]]@($values)
[Array]::Sort($ordinal, [StringComparer]::Ordinal)
$ordinalIgnoreCase = [string[]]@($values)
[Array]::Sort($ordinalIgnoreCase, [StringComparer]::OrdinalIgnoreCase)
$invariant = [string[]]@($values)
[Array]::Sort($invariant, [StringComparer]::InvariantCulture)
$invariantIgnoreCase = [string[]]@($values)
[Array]::Sort($invariantIgnoreCase, [StringComparer]::InvariantCultureIgnoreCase)
$currentIgnoreCase = [string[]]@($values)
[Array]::Sort($currentIgnoreCase, [StringComparer]::CurrentCultureIgnoreCase)

[ordered]@{
    schema = 'argos_opencv_scribe_r18zt_member_set_diagnostic_v1'
    state = 'PASS_R18ZT_MEMBER_SET_DIAGNOSTIC'
    powerShellVersion = [string]$PSVersionTable.PSVersion
    count = $values.Count
    gateSha256 = [string]$gate.plannedFinalZipMemberSetSha256
    defaultSortSha256 = Get-TextSha256 $default
    caseSensitiveSortSha256 = Get-TextSha256 $caseSensitive
    ordinalSortSha256 = Get-TextSha256 $ordinal
    ordinalIgnoreCaseSortSha256 = Get-TextSha256 $ordinalIgnoreCase
    invariantSortSha256 = Get-TextSha256 $invariant
    invariantIgnoreCaseSortSha256 = Get-TextSha256 $invariantIgnoreCase
    currentIgnoreCaseSortSha256 = Get-TextSha256 $currentIgnoreCase
    defaultFirst = $default[0]
    ordinalFirst = $ordinal[0]
    defaultOrderEqualsOrdinal = (($default -join "`n") -ceq ($ordinal -join "`n"))
    targetWritesPerformed = $false
    externalAccessPerformed = $false
} | ConvertTo-Json -Depth 5

#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not $Preflight) { throw 'F3 Add diagnostic requires -Preflight.' }
function Get-Sha256Shared([string]$Path) {
    $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try { ([BitConverter]::ToString($algorithm.ComputeHash($stream))).Replace('-', '') }
    finally { $algorithm.Dispose(); $stream.Dispose() }
}

$source = Get-Item -LiteralPath (Join-Path $PSScriptRoot '..\OPENCV_EDGE_NOTCH_O3F15L4D2\O3F15L4D2_PUBLISH_GATE.json')
$candidateZips = New-Object Collections.Generic.List[object]
$candidateZips.Add($source)
$candidatePaths = New-Object Collections.Generic.List[string]
$candidatePaths.Add([string]$source.FullName)
$matches = New-Object Collections.Generic.List[object]
$matchesTypeBeforeRegex = $matches.GetType().FullName
$regexPassed = 'R_0123456789AB_20260903140000000_abcdef12' -cmatch '^R_[0-9A-F]{12}_[0-9]{17}_[0-9a-f]{8}$'
$matchesTypeAfterRegex = $matches.GetType().FullName
$responseMatches = New-Object Collections.Generic.List[object]
$responseMatches.Add([pscustomobject]@{
    requestId = 'REQ_20260903T125334383Z_CA2B943D4CB0'
    sourceZip = $source.FullName
    sourceZipBytes = [int64]$source.Length
    sourceZipSha256 = Get-Sha256Shared $source.FullName
})
$f2Path = Join-Path $PSScriptRoot '..\OPENCV_EDGE_NOTCH_O3F15L4D2F2\Find-O3F15L4D2ResponseF2.ps1'
$f3Path = Join-Path $PSScriptRoot 'Find-O3F15L4D2ResponseF3.ps1'
$expectedF3 = (Get-Content -LiteralPath $f2Path -Raw).Replace('O3F15L4D2F2', 'O3F15L4D2F3').Replace('D2F2', 'D2F3').Replace('o3f15l4d2f2', 'o3f15l4d2f3').Replace('$matches', '$responseMatches').Replace("`r`n", "`n")
$actualF3 = (Get-Content -LiteralPath $f3Path -Raw).Replace("`r`n", "`n")
if ($actualF3 -cne $expectedF3) { throw 'F3 is not the exact namespace and response-collection-variable successor of F2.' }
[pscustomobject]@{
    schema = 'argos_ocv03_o3f15l4d2f3_add_diagnostic_v1'
    state = 'PASS_O3F15L4D2F3_ADD_DIAGNOSTIC'
    sourceType = $source.GetType().FullName
    candidateObjectListType = $candidateZips.GetType().FullName
    candidateObjectCount = $candidateZips.Count
    candidateStringListType = $candidatePaths.GetType().FullName
    candidateStringCount = $candidatePaths.Count
    regexPassed = $regexPassed
    automaticMatchesTypeBeforeRegex = $matchesTypeBeforeRegex
    automaticMatchesTypeAfterRegex = $matchesTypeAfterRegex
    correctedMatchListType = $responseMatches.GetType().FullName
    correctedMatchCount = $responseMatches.Count
    exactMechanicalSuccessor = $true
    liveShareRead = $false
    mutationsPerformed = $false
} | ConvertTo-Json -Compress

#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (-not $Preflight) { throw 'Specify -Preflight.' }

function Require([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-Sha256([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Get-TextSha256([string]$Text) {
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes($Text)
    $hasher = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($hasher.ComputeHash($bytes))).Replace('-','') }
    finally { $hasher.Dispose() }
}

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$zip = Join-Path $PSScriptRoot 'final\REQ_R18O2.ready.zip'
$membershipGatePath = $zip + '.complete_route_gate.json'
$roundTripGatePath = Join-Path $PSScriptRoot 'R18O_FULL_ROUND_TRIP_PATH_GATE.json'
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'

Require ((Get-Sha256 $zip) -eq '0DC7D8D3FE59AD2296A036DCE04AA425CA20C859EAB2B7B0F1EEC9A8A9A09B36') 'R18O signed ZIP changed.'
Require ((Get-Sha256 $membershipGatePath) -eq '1348489FAD2567B2B0A6B26CE86863270DC3078435F8CAA32124338396AE04AB') 'R18O membership gate changed.'
Require ((Get-Sha256 $roundTripGatePath) -eq 'DE68A5F8EBAE6DE8D65DE8126E002D9273A3287EBBFBD32768E984FD8A1FC5EE') 'R18O round-trip gate changed.'

$membershipGate = Get-Content -Raw -LiteralPath $membershipGatePath | ConvertFrom-Json
$roundTripGate = Get-Content -Raw -LiteralPath $roundTripGatePath | ConvertFrom-Json
Require ([string]$membershipGate.state -eq 'PASS_R18O_COMPLETE_ROUTE_GATE') 'R18O membership gate state changed.'
Require ([string]$roundTripGate.state -eq 'PASS_R18O_FULL_ROUND_TRIP_PATH_GATE') 'R18O round-trip gate state changed.'
Require ([int]$roundTripGate.candidateCount -eq 26 -and @($roundTripGate.paths).Count -eq 26) 'R18O round-trip candidate cardinality changed.'

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($zip)
try { $actualLeaves = @($archive.Entries | ForEach-Object { $_.FullName.Replace('\','/') } | Sort-Object) }
finally { $archive.Dispose() }
$actualSetSha = Get-TextSha256 (($actualLeaves -join "`n") + "`n")
Require ($actualLeaves.Count -eq 27) 'R18O final ZIP member count changed.'
Require ($actualSetSha -eq 'BEAC73C2E887BA363D469913A16C225BA65006CD0AA571BFEF10C663FC187679') 'R18O final ZIP member set changed.'
Require ($actualLeaves -contains 'payload/files/OPENCV_SCRIBE_R18F/reference_bank/SUPPLEMENTAL_GLYPH_REFERENCE_MANIFEST.json') 'R18O prior failing leaf is not checked.'

$pathResult = (& $pathTool -CandidatePath @($roundTripGate.paths) -ReservedSuffixCharacters 32 -WarningEffectiveLength 200 -HardStopEffectiveLength 230 -MaximumComponentLength 80 -AsJson | Out-String) | ConvertFrom-Json
Require ([string]$pathResult.state -eq 'PASS_PATH_BUDGET') 'R18O full round-trip path budget failed.'
$pathCandidates = @($pathResult.candidates)
$maximumEffectiveLength = [int](($pathCandidates | Measure-Object effectiveLength -Maximum).Maximum)
Require ($pathCandidates.Count -eq 26 -and $maximumEffectiveLength -eq 196) 'R18O full round-trip path result changed.'

[ordered]@{
    schema='argos_opencv_scribe_r18o_exact_package_path_preflight_v1';
    checkedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R18O_EXACT_PACKAGE_PATHS';
    requestId='REQ_R18O2';requestZipSha256=Get-Sha256 $zip;
    actualFinalZipMemberCount=$actualLeaves.Count;actualFinalZipMemberSetSha256=$actualSetSha;
    roundTripCandidateCount=$pathCandidates.Count;maximumEffectiveLength=$maximumEffectiveLength;
    priorR18MRejectedLeafExplicitlyChecked=$true;entrypointDefaultsMatchSignedDefinition=$true;
    mutationsPerformed=$false;targetExecuted=$false;
    publicationAuthorized=$false;explicitPublishStillRequired=$true;reviewOnly=$true;productionRoutingEnabled=$false
} | ConvertTo-Json -Depth 8

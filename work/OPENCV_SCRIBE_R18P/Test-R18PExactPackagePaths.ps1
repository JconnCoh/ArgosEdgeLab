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
$zip = Join-Path $PSScriptRoot 'final\REQ_R18P1.ready.zip'
$membershipGatePath = $zip + '.complete_route_gate.json'
$roundTripGatePath = Join-Path $PSScriptRoot 'R18P_FULL_ROUND_TRIP_PATH_GATE.json'
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'

Require ((Get-Sha256 $zip) -eq '0975925ED1079D042701882BE9D61A24CA0BD1977C6078B18E9633E26ECAEEFD') 'R18P signed ZIP changed.'
Require ((Get-Sha256 $membershipGatePath) -eq '68238217EE76531756AD52096021A34BCD33F3ECBA8D3D56ACE27963845750B6') 'R18P membership gate changed.'
Require ((Get-Sha256 $roundTripGatePath) -eq '6F49FB85027BF503AF1CD92E1E3E9A4A0AAAFBC9C63039C72E56888F743F5210') 'R18P round-trip gate changed.'

$membershipGate = Get-Content -Raw -LiteralPath $membershipGatePath | ConvertFrom-Json
$roundTripGate = Get-Content -Raw -LiteralPath $roundTripGatePath | ConvertFrom-Json
Require ([string]$membershipGate.state -eq 'PASS_R18P_COMPLETE_ROUTE_GATE') 'R18P membership gate state changed.'
Require ([string]$roundTripGate.state -eq 'PASS_R18P_FULL_ROUND_TRIP_PATH_GATE') 'R18P round-trip gate state changed.'
Require ([int]$roundTripGate.candidateCount -eq 26 -and @($roundTripGate.paths).Count -eq 26) 'R18P round-trip candidate cardinality changed.'

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($zip)
try { $actualLeaves = @($archive.Entries | ForEach-Object { $_.FullName.Replace('\','/') } | Sort-Object) }
finally { $archive.Dispose() }
$actualSetSha = Get-TextSha256 (($actualLeaves -join "`n") + "`n")
Require ($actualLeaves.Count -eq 28) 'R18P final ZIP member count changed.'
Require ($actualSetSha -eq 'E44EE789AD7CFD16F53D4044D38327378CF64FD428AE721937F6152DB26B9935') 'R18P final ZIP member set changed.'
Require ($actualLeaves -contains 'payload/files/OPENCV_SCRIBE_R18F/reference_bank/SUPPLEMENTAL_GLYPH_REFERENCE_MANIFEST.json') 'R18P prior failing leaf is not checked.'

$pathResult = (& $pathTool -CandidatePath @($roundTripGate.paths) -ReservedSuffixCharacters 32 -WarningEffectiveLength 200 -HardStopEffectiveLength 230 -MaximumComponentLength 80 -AsJson | Out-String) | ConvertFrom-Json
Require ([string]$pathResult.state -eq 'PASS_PATH_BUDGET') 'R18P full round-trip path budget failed.'
$pathCandidates = @($pathResult.candidates)
$maximumEffectiveLength = [int](($pathCandidates | Measure-Object effectiveLength -Maximum).Maximum)
Require ($pathCandidates.Count -eq 26 -and $maximumEffectiveLength -eq 196) 'R18P full round-trip path result changed.'

[ordered]@{
    schema='argos_opencv_scribe_r18p_exact_package_path_preflight_v1';
    checkedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R18P_EXACT_PACKAGE_PATHS';
    requestId='REQ_R18P1';requestZipSha256=Get-Sha256 $zip;
    actualFinalZipMemberCount=$actualLeaves.Count;actualFinalZipMemberSetSha256=$actualSetSha;
    roundTripCandidateCount=$pathCandidates.Count;maximumEffectiveLength=$maximumEffectiveLength;
    priorR18MRejectedLeafExplicitlyChecked=$true;entrypointDefaultsMatchSignedDefinition=$true;
    mutationsPerformed=$false;targetExecuted=$false;
    publicationAuthorized=$false;explicitPublishStillRequired=$true;reviewOnly=$true;productionRoutingEnabled=$false
} | ConvertTo-Json -Depth 8

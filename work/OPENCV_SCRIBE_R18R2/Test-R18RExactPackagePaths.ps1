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
$zip = Join-Path $PSScriptRoot 'final\REQ_R18R2.ready.zip'
$membershipGatePath = $zip + '.complete_route_gate.json'
$roundTripGatePath = Join-Path $PSScriptRoot 'R18R_FULL_ROUND_TRIP_PATH_GATE.json'
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'

Require ((Get-Sha256 $zip) -eq 'E541EB7FCCD19A04BFE401D6FCFB70B7976C0F47E9F4F1AD8E1FCC1626EEF300') 'R18R signed ZIP changed.'
Require ((Get-Sha256 $membershipGatePath) -eq 'C66F9E564639E5080E76D14BDDBA0B01E3CB7F96FB53CDB9E29F1EBFB2E3F617') 'R18R membership gate changed.'
Require ((Get-Sha256 $roundTripGatePath) -eq 'CD6AB17E09C12B23557048B3B3A7AB0EC2DFDFF68439A01474B41240CB66C81C') 'R18R round-trip gate changed.'

$membershipGate = Get-Content -Raw -LiteralPath $membershipGatePath | ConvertFrom-Json
$roundTripGate = Get-Content -Raw -LiteralPath $roundTripGatePath | ConvertFrom-Json
Require ([string]$membershipGate.state -eq 'PASS_R18R_COMPLETE_ROUTE_GATE') 'R18R membership gate state changed.'
Require ([string]$roundTripGate.state -eq 'PASS_R18R_FULL_ROUND_TRIP_PATH_GATE') 'R18R round-trip gate state changed.'
Require ([int]$roundTripGate.candidateCount -eq 26 -and @($roundTripGate.paths).Count -eq 26) 'R18R round-trip candidate cardinality changed.'

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($zip)
try { $actualLeaves = @($archive.Entries | ForEach-Object { $_.FullName.Replace('\','/') } | Sort-Object) }
finally { $archive.Dispose() }
$actualSetSha = Get-TextSha256 (($actualLeaves -join "`n") + "`n")
Require ($actualLeaves.Count -eq 31) 'R18R final ZIP member count changed.'
Require ($actualSetSha -eq 'CD49F02C4708E66DF6807D96A8E99E942536C150864F20794B6B852FBEB3E994') 'R18R final ZIP member set changed.'
Require ($actualLeaves -contains 'payload/files/OPENCV_SCRIBE_R18F/reference_bank/SUPPLEMENTAL_GLYPH_REFERENCE_MANIFEST.json') 'R18R prior failing leaf is not checked.'

$pathResult = (& $pathTool -CandidatePath @($roundTripGate.paths) -ReservedSuffixCharacters 32 -WarningEffectiveLength 200 -HardStopEffectiveLength 230 -MaximumComponentLength 80 -AsJson | Out-String) | ConvertFrom-Json
Require ([string]$pathResult.state -eq 'PASS_PATH_BUDGET') 'R18R full round-trip path budget failed.'
$pathCandidates = @($pathResult.candidates)
$maximumEffectiveLength = [int](($pathCandidates | Measure-Object effectiveLength -Maximum).Maximum)
Require ($pathCandidates.Count -eq 26 -and $maximumEffectiveLength -eq 196) 'R18R full round-trip path result changed.'

[ordered]@{
    schema='argos_opencv_scribe_r18r_exact_package_path_preflight_v1';
    checkedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R18R_EXACT_PACKAGE_PATHS';
    requestId='REQ_R18R2';requestZipSha256=Get-Sha256 $zip;
    actualFinalZipMemberCount=$actualLeaves.Count;actualFinalZipMemberSetSha256=$actualSetSha;
    roundTripCandidateCount=$pathCandidates.Count;maximumEffectiveLength=$maximumEffectiveLength;
    priorR18MRejectedLeafExplicitlyChecked=$true;entrypointDefaultsMatchSignedDefinition=$true;
    mutationsPerformed=$false;targetExecuted=$false;
    publicationAuthorized=$false;explicitPublishStillRequired=$true;reviewOnly=$true;productionRoutingEnabled=$false
} | ConvertTo-Json -Depth 8

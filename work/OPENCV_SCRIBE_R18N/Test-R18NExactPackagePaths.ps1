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
$zip = Join-Path $PSScriptRoot 'final\REQ_R18N1.ready.zip'
$membershipGatePath = $zip + '.complete_route_gate.json'
$roundTripGatePath = Join-Path $PSScriptRoot 'R18N_FULL_ROUND_TRIP_PATH_GATE.json'
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'

Require ((Get-Sha256 $zip) -eq '198F365EF1B21739A9D6D7E67628F45751641ECE17112C01CE9A3F586431BEE4') 'R18N signed ZIP changed.'
Require ((Get-Sha256 $membershipGatePath) -eq '2FA7FA6D98C7EA8320D6931FE1F9F4FD67B3E15A06A781A604CAB7C82C6552D2') 'R18N membership gate changed.'
Require ((Get-Sha256 $roundTripGatePath) -eq 'D7230106F89C80062E2C64D018441554A0ED64D5FD25959792930F3DA71C7967') 'R18N round-trip gate changed.'

$membershipGate = Get-Content -Raw -LiteralPath $membershipGatePath | ConvertFrom-Json
$roundTripGate = Get-Content -Raw -LiteralPath $roundTripGatePath | ConvertFrom-Json
Require ([string]$membershipGate.state -eq 'PASS_R18N_COMPLETE_ROUTE_GATE') 'R18N membership gate state changed.'
Require ([string]$roundTripGate.state -eq 'PASS_R18N_FULL_ROUND_TRIP_PATH_GATE') 'R18N round-trip gate state changed.'
Require ([int]$roundTripGate.candidateCount -eq 26 -and @($roundTripGate.paths).Count -eq 26) 'R18N round-trip candidate cardinality changed.'

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($zip)
try { $actualLeaves = @($archive.Entries | ForEach-Object { $_.FullName.Replace('\','/') } | Sort-Object) }
finally { $archive.Dispose() }
$actualSetSha = Get-TextSha256 (($actualLeaves -join "`n") + "`n")
Require ($actualLeaves.Count -eq 27) 'R18N final ZIP member count changed.'
Require ($actualSetSha -eq '02D888A6921BF16695C262B821FF894DE5BCF3AF42F5E192B544491C233003B8') 'R18N final ZIP member set changed.'
Require ($actualLeaves -contains 'payload/files/OPENCV_SCRIBE_R18F/reference_bank/SUPPLEMENTAL_GLYPH_REFERENCE_MANIFEST.json') 'R18N prior failing leaf is not checked.'

$pathResult = (& $pathTool -CandidatePath @($roundTripGate.paths) -ReservedSuffixCharacters 32 -WarningEffectiveLength 200 -HardStopEffectiveLength 230 -MaximumComponentLength 80 -AsJson | Out-String) | ConvertFrom-Json
Require ([string]$pathResult.state -eq 'PASS_PATH_BUDGET') 'R18N full round-trip path budget failed.'
$pathCandidates = @($pathResult.candidates)
$maximumEffectiveLength = [int](($pathCandidates | Measure-Object effectiveLength -Maximum).Maximum)
Require ($pathCandidates.Count -eq 26 -and $maximumEffectiveLength -eq 196) 'R18N full round-trip path result changed.'

[ordered]@{
    schema='argos_opencv_scribe_r18n_exact_package_path_preflight_v1';
    checkedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R18N_EXACT_PACKAGE_PATHS';
    requestId='REQ_R18N1';requestZipSha256=Get-Sha256 $zip;
    actualFinalZipMemberCount=$actualLeaves.Count;actualFinalZipMemberSetSha256=$actualSetSha;
    roundTripCandidateCount=$pathCandidates.Count;maximumEffectiveLength=$maximumEffectiveLength;
    priorR18MRejectedLeafExplicitlyChecked=$true;mutationsPerformed=$false;targetExecuted=$false;
    publicationAuthorized=$false;explicitPublishStillRequired=$true;reviewOnly=$true;productionRoutingEnabled=$false
} | ConvertTo-Json -Depth 8

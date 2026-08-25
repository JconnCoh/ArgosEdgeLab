#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Gate,
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Gate)) { throw 'Specify exactly one of -Preflight or -Gate.' }

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$guard = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
$shareRoot = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$candidatePaths = @(
    (Join-Path $shareRoot 'ARGOS_O2A3.zip'),
    (Join-Path $shareRoot 'ARGOS_O2A3_PATH_GATE.json'),
    'C:\O2A3T_195521\SUMMARY\pkg\PACKAGE_MANIFEST.json',
    'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\catalog\ALL_WAFER_CATALOG.json',
    'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\identity\proposals\62619-433_20260824005735_Slot16\scribe\multi_channel\MULTI_CHANNEL_READER_SUMMARY.json',
    'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\runtime\scribe\references\PORTABLE_GLYPH_REFERENCE_MANIFEST.json',
    'C:\ProgramData\ArgosProjectPortalRO\to_argos\pending\R_0123456789AB_20260825200000123_12345678.partial\source_json\MULTI_CHANNEL_READER_SUMMARY.json',
    'C:\ProgramData\ArgosProjectPortalRO\to_argos\pending\R_0123456789AB_20260825200000123_12345678.partial\PORTAL_RESPONSE_MANIFEST.sig',
    'C:\ProgramData\ArgosProjectPortalRO\to_argos\sent\R_0123456789AB_20260825200000123_12345678.ready\source_json\MULTI_CHANNEL_READER_SUMMARY.json',
    (Join-Path $PSScriptRoot 'final.partial\extract\PACKAGE_MANIFEST.json'),
    (Join-Path $PSScriptRoot 'final\ARGOS_O2A3.zip'),
    'D:\A2\x\O2A3_20260825T195521Z\source_json\MULTI_CHANNEL_READER_SUMMARY.json',
    'D:\A2\x\O2A3_20260825T195521Z\response_quarantine\R_0123456789AB_20260825200000123_12345678.partial\PORTAL_RESPONSE_MANIFEST.json',
    'D:\A2\x\O2A3_20260825T195521Z_LAUNCH.log',
    'D:\A2\x\O2A3R_20260825T195521Z.zip.partial',
    'D:\O2A3\ARGOS_O2A3\Invoke-O2A3Direct.ps1'
)

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Write-JsonCreateNew([string]$Path, [object]$Value, [int]$Depth = 12) {
    Assert-True (-not (Test-Path -LiteralPath $Path)) "O2A3 path gate exists: $Path"
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}

Assert-True (Test-Path -LiteralPath $guard -PathType Leaf) 'O2A3 path guard is absent.'
$guardJson = & $guard -CandidatePath $candidatePaths -ProjectRoot $project -ReservedSuffixCharacters 32 -AsJson
$guardResult = $guardJson | ConvertFrom-Json
Assert-True ([string]$guardResult.state -eq 'PASS_PATH_BUDGET') 'O2A3 complete path set failed.'
$guardRows = @($guardResult.candidates)
Assert-True ($guardRows.Count -eq $candidatePaths.Count) 'O2A3 path guard received the wrong array cardinality.'
$maximumPathLength = [int](($guardRows | Measure-Object -Property pathLength -Maximum).Maximum)
$maximumEffectiveLength = [int](($guardRows | Measure-Object -Property effectiveLength -Maximum).Maximum)
$maximumComponentLength = [int](($guardRows | Measure-Object -Property longestComponentLength -Maximum).Maximum)
$result = [ordered]@{
    schema='argos_o2a3_complete_path_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2A3_COMPLETE_DIRECT_ROUTE_PATH_GATE';mode=if($Preflight){'PREFLIGHT'}else{'GATE'}
    revision='O2A3_20260825T195521Z_SLOT16';candidateCount=$candidatePaths.Count;rows=$guardRows;maximumPathLength=$maximumPathLength;maximumEffectiveLength=$maximumEffectiveLength;maximumComponentLength=$maximumComponentLength
    reservedSuffixCharacters=32;portalInboundUsed=$false;durableDLocalResultRequired=$true;signedOutboundReturnRequired=$true;imagePathsIncluded=$false;targetExecuted=$false;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false
}
if ($Preflight) { $result | ConvertTo-Json -Depth 12; return }
Assert-True (-not [string]::IsNullOrWhiteSpace($OutputPath)) 'O2A3 path gate mode requires OutputPath.'
$resolved = [IO.Path]::GetFullPath($OutputPath)
Assert-True ($resolved.StartsWith($project.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) 'O2A3 path gate must remain inside the project.'
Write-JsonCreateNew -Path $resolved -Value $result -Depth 12
$result | ConvertTo-Json -Depth 12

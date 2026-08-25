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
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
$bundle = Join-Path $project 'work\OPENCV_SCRIBE_O2D4\final\extract\payload\O2D4_REFS.zip'
$shareRoot = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$responseLeaf = 'R_0123456789AB_20260825190855123_12345678.partial'

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Write-JsonCreateNew([string]$Path, [object]$Value) {
    Assert-True (-not (Test-Path -LiteralPath $Path)) "O2D5 path gate exists: $Path"
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 14) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}

foreach ($required in @($pathTool,$bundle)) { Assert-True (Test-Path -LiteralPath $required -PathType Leaf) "O2D5 path dependency is absent: $required" }
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($bundle)
try {
    $longestReferenceEntry = @($archive.Entries | Sort-Object { $_.FullName.Length } -Descending | Select-Object -First 1)[0].FullName.Replace('/','\')
}
finally { $archive.Dispose() }

$candidates = @(
    (Join-Path $PSScriptRoot 'final\ARGOS_O2D5.zip'),
    (Join-Path $PSScriptRoot 'final.partial\package\O2D5_REFS.zip'),
    (Join-Path $PSScriptRoot 'final.partial\extract\PACKAGE_MANIFEST.json'),
    (Join-Path $shareRoot 'ARGOS_O2D5.zip'),
    (Join-Path $shareRoot 'ARGOS_O2D5_PATH_GATE.json'),
    'D:\O2D5\Invoke-O2D5Direct.ps1',
    'D:\O2D5\INVOCATION.json',
    'D:\A2\w\ocv\O2D5_20260825T190855Z_54B4C08C.partial',
    ('D:\A2\w\ocv\O2D5_20260825T190855Z_54B4C08C\' + $longestReferenceEntry.TrimStart('\')),
    'D:\A2\o\ocv\O2D5_20260825T190855Z_54B4C08C\OUTBOUND_FAILURE.json',
    'D:\A2\x\O2D5R_20260825T190855Z_54B4C08C.zip.partial',
    'D:\A2\x\O2D5_20260825T190855Z_54B4C08C_LAUNCH.log',
    (Join-Path 'C:\ProgramData\ArgosProjectPortalRO\to_argos\pending' ($responseLeaf + '\PORTAL_RESPONSE_MANIFEST.json')),
    (Join-Path 'C:\ProgramData\ArgosProjectPortalRO\to_argos\pending' ($responseLeaf + '\PORTAL_RESPONSE_MANIFEST.sig')),
    (Join-Path 'C:\ProgramData\ArgosProjectPortalRO\to_argos\sent' ($responseLeaf.Replace('.partial','.ready') + '\PORTAL_RESPONSE_MANIFEST.json')),
    'C:\O2D5P_54B4C08C\extract\O2D5_REFS.zip'
)
$pathResult = & $pathTool -CandidatePath $candidates -ProjectRoot $project -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
Assert-True ([string]$pathResult.state -eq 'PASS_PATH_BUDGET') 'O2D5 planned path budget failed.'
$rows = @($pathResult.candidates)
$maximumPathLength = [int](($rows | Measure-Object -Property pathLength -Maximum).Maximum)
$maximumEffectiveLength = [int](($rows | Measure-Object -Property effectiveLength -Maximum).Maximum)
$maximumComponentLength = [int](($rows | Measure-Object -Property longestComponentLength -Maximum).Maximum)
$gateValue = [ordered]@{
    schema='argos_o2d5_complete_path_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D5_COMPLETE_DIRECT_ROUTE_PATH_GATE';mode=$(if($Preflight){'PREFLIGHT'}else{'GATE'})
    revision='O2D5_20260825T190855Z_54B4C08C';candidateCount=$candidates.Count;rows=$rows;longestReferenceEntry=$longestReferenceEntry
    maximumPathLength=$maximumPathLength;maximumEffectiveLength=$maximumEffectiveLength;maximumComponentLength=$maximumComponentLength;reservedSuffixCharacters=32
    portalInboundUsed=$false;durableDLocalResultRequired=$true;signedOutboundBestEffort=$true;unknownDownstreamReturnDoesNotEraseDLocalResult=$true
    targetExecuted=$false;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false
}
if ($Preflight) { $gateValue | ConvertTo-Json -Depth 14; return }
Assert-True (-not [string]::IsNullOrWhiteSpace($OutputPath)) 'O2D5 Gate mode requires OutputPath.'
$resolvedOutput = [IO.Path]::GetFullPath($OutputPath)
Assert-True ($resolvedOutput.StartsWith($project.TrimEnd('\') + '\',[StringComparison]::OrdinalIgnoreCase)) 'O2D5 path gate output escaped project.'
Write-JsonCreateNew -Path $resolvedOutput -Value $gateValue
$gateValue | ConvertTo-Json -Depth 14

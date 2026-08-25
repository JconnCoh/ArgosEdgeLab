#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
    [Parameter(Mandatory = $true)][string]$InvocationManifest,
    [switch]$Preflight,
    [switch]$Publish
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Publish)) { throw 'Specify exactly one of -Preflight or -Publish.' }

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-Sha256([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Write-JsonCreateNew([string]$Path, [object]$Value, [int]$Depth = 14) {
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes((($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine))
    $stream = New-Object IO.FileStream($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try { $stream.Write($bytes,0,$bytes.Length) } finally { $stream.Dispose() }
}

$project = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $ProjectRoot).Path).TrimEnd('\')
$invocationPath = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $InvocationManifest).Path)
Assert-True ($invocationPath.StartsWith($project+'\',[StringComparison]::OrdinalIgnoreCase)) 'O2D5 publish invocation escaped the project.'
$invocation = Get-Content -Raw -LiteralPath $invocationPath | ConvertFrom-Json
Assert-True ([string]$invocation.schema -eq 'argos_o2d5_publish_invocation_v1' -and [string]$invocation.revision -eq 'O2D5_20260825T190855Z_54B4C08C') 'O2D5 publish invocation identity changed.'
Assert-True ([bool]$invocation.singlePublicationAuthorized -and -not [bool]$invocation.overwriteAuthorized -and [bool]$invocation.reviewOnly -and -not [bool]$invocation.productionRoutingEnabled) 'O2D5 publication authority changed.'

function Resolve-ProjectPath([string]$Relative) {
    $path = [IO.Path]::GetFullPath((Join-Path $project $Relative.Replace('/','\')))
    Assert-True ($path.StartsWith($project+'\',[StringComparison]::OrdinalIgnoreCase)) "O2D5 project path escaped: $Relative"
    return $path
}

$sourceZip = Resolve-ProjectPath ([string]$invocation.sourceZip)
$sourcePathGate = Resolve-ProjectPath ([string]$invocation.sourcePathGate)
$finalPackageGate = Resolve-ProjectPath ([string]$invocation.finalPackageGate)
$publicationGate = Resolve-ProjectPath ([string]$invocation.publicationGate)
$destinationZip = [IO.Path]::GetFullPath([string]$invocation.destinationZip)
$destinationPathGate = [IO.Path]::GetFullPath([string]$invocation.destinationPathGate)
$manualReturnZip = [IO.Path]::GetFullPath([string]$invocation.manualReturnZip)
$expectedParent = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
Assert-True ((Split-Path -Parent $destinationZip).Equals($expectedParent,[StringComparison]::OrdinalIgnoreCase)) 'O2D5 destination ZIP parent changed.'
Assert-True ((Split-Path -Parent $destinationPathGate).Equals($expectedParent,[StringComparison]::OrdinalIgnoreCase)) 'O2D5 destination path-gate parent changed.'
Assert-True ((Split-Path -Parent $manualReturnZip).Equals($expectedParent,[StringComparison]::OrdinalIgnoreCase)) 'O2D5 manual return parent changed.'
Assert-True ([IO.Path]::GetFileName($destinationZip) -eq 'ARGOS_O2D5.zip' -and [IO.Path]::GetFileName($destinationPathGate) -eq 'ARGOS_O2D5_PATH_GATE.json' -and [IO.Path]::GetFileName($manualReturnZip) -eq 'O2D5R.zip') 'O2D5 share leaf changed.'

Assert-True (Test-Path -LiteralPath $sourceZip -PathType Leaf) 'O2D5 frozen ZIP is absent.'
Assert-True ((Get-Item -LiteralPath $sourceZip).Length -eq [int64]$invocation.sourceZipBytes -and (Get-Sha256 $sourceZip) -eq [string]$invocation.sourceZipSha256) 'O2D5 frozen ZIP changed.'
Assert-True (Test-Path -LiteralPath $sourcePathGate -PathType Leaf -and (Get-Sha256 $sourcePathGate) -eq [string]$invocation.sourcePathGateSha256) 'O2D5 path gate changed.'
Assert-True (Test-Path -LiteralPath $finalPackageGate -PathType Leaf -and (Get-Sha256 $finalPackageGate) -eq [string]$invocation.finalPackageGateSha256) 'O2D5 final package gate changed.'
$pathGate = Get-Content -Raw -LiteralPath $sourcePathGate | ConvertFrom-Json
$finalGate = Get-Content -Raw -LiteralPath $finalPackageGate | ConvertFrom-Json
Assert-True ([string]$pathGate.state -eq 'PASS_O2D5_COMPLETE_DIRECT_ROUTE_PATH_GATE' -and [int]$pathGate.maximumEffectiveLength -lt 200) 'O2D5 path gate is not publishable.'
Assert-True ([string]$finalGate.state -eq 'PASS_O2D5_FINAL_PACKAGE_GATE' -and [string]$finalGate.lifecycle -eq 'FROZEN' -and -not [bool]$finalGate.publicationAuthorized) 'O2D5 final package gate changed.'
Assert-True (Test-Path -LiteralPath $expectedParent -PathType Container) 'O2D5 engineering share root is unavailable.'

$branch = (& git -C $project branch --show-current | Out-String).Trim()
$localTip = (& git -C $project rev-parse HEAD | Out-String).Trim()
$remoteTip = (& git -C $project rev-parse origin/codex/fiducial-opencv-d-drive | Out-String).Trim()
$status = (& git -C $project status --porcelain=v1 | Out-String).Trim()
Assert-True ($branch -eq 'codex/fiducial-opencv-d-drive' -and $localTip -eq $remoteTip -and [string]::IsNullOrWhiteSpace($status)) 'O2D5 publication requires a clean matching local/origin branch tip.'

$zipPartial = $destinationZip + '.partial.O2D5'
$gatePartial = $destinationPathGate + '.partial.O2D5'
foreach ($fresh in @($destinationZip,$destinationPathGate,$manualReturnZip,$publicationGate,$zipPartial,$gatePartial)) { Assert-True (-not (Test-Path -LiteralPath $fresh)) "O2D5 publication path is not fresh: $fresh" }
$preflightValue = [ordered]@{
    schema='argos_o2d5_publish_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D5_PUBLISH_PREFLIGHT';revision=[string]$invocation.revision
    branch=$branch;localTip=$localTip;remoteTip=$remoteTip;sourceZip=$sourceZip;sourceZipSha256=[string]$invocation.sourceZipSha256;destinationZip=$destinationZip;destinationPathGate=$destinationPathGate
    manualReturnZip=$manualReturnZip;targetExecuted=$false;mutationsPerformed=$false;jbodContacted=$false;reviewOnly=$true;productionRoutingEnabled=$false
}
if ($Preflight) { $preflightValue | ConvertTo-Json -Depth 10; return }

$zipFinalCreated = $false
$gateFinalCreated = $false
try {
    [IO.File]::Copy($sourceZip,$zipPartial,$false)
    Assert-True ((Get-Sha256 $zipPartial) -eq [string]$invocation.sourceZipSha256) 'O2D5 staged ZIP changed.'
    [IO.File]::Move($zipPartial,$destinationZip); $zipFinalCreated=$true
    [IO.File]::Copy($sourcePathGate,$gatePartial,$false)
    Assert-True ((Get-Sha256 $gatePartial) -eq [string]$invocation.sourcePathGateSha256) 'O2D5 staged path gate changed.'
    [IO.File]::Move($gatePartial,$destinationPathGate); $gateFinalCreated=$true
    Assert-True ((Get-Sha256 $destinationZip) -eq [string]$invocation.sourceZipSha256 -and (Get-Sha256 $destinationPathGate) -eq [string]$invocation.sourcePathGateSha256) 'O2D5 publication readback changed.'
}
catch {
    if (Test-Path -LiteralPath $zipPartial -PathType Leaf) { [IO.File]::Delete($zipPartial) }
    if (Test-Path -LiteralPath $gatePartial -PathType Leaf) { [IO.File]::Delete($gatePartial) }
    if ($gateFinalCreated -and (Test-Path -LiteralPath $destinationPathGate -PathType Leaf)) { [IO.File]::Delete($destinationPathGate) }
    if ($zipFinalCreated -and (Test-Path -LiteralPath $destinationZip -PathType Leaf)) { [IO.File]::Delete($destinationZip) }
    throw
}

$result = [ordered]@{
    schema='argos_o2d5_publication_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D5_PUBLISHED';revision=[string]$invocation.revision
    branch=$branch;localTip=$localTip;remoteTip=$remoteTip;destinationZip=$destinationZip;destinationZipBytes=(Get-Item -LiteralPath $destinationZip).Length;destinationZipSha256=Get-Sha256 $destinationZip
    destinationPathGate=$destinationPathGate;destinationPathGateSha256=Get-Sha256 $destinationPathGate;manualReturnZipAbsent=(-not (Test-Path -LiteralPath $manualReturnZip))
    singlePublicationPerformed=$true;overwritePerformed=$false;portalInboundRequestCreated=$false;taskActionsPerformed=@();processActionsPerformed=@();waferActionPerformed=$false
    imageBytesDecoded=$false;targetExecuted=$false;jbodContacted=$false;reviewOnly=$true;productionRoutingEnabled=$false
}
Write-JsonCreateNew -Path $publicationGate -Value $result -Depth 12
$result | ConvertTo-Json -Depth 12

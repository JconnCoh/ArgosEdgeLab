#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Publish
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Publish)) { throw 'Specify exactly one of -Preflight or -Publish.' }

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$sourceZip = Join-Path $PSScriptRoot 'final\ARGOS_O2A3.zip'
$finalGatePath = Join-Path $PSScriptRoot 'final\O2A3_FINAL_PACKAGE_GATE.json'
$sourcePathGate = Join-Path $PSScriptRoot 'O2A3_PATH_GATE.json'
$continuityPath = Join-Path $project 'work\ARGOS_CONTINUITY_STATE.json'
$shareRoot = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$destinationZip = Join-Path $shareRoot 'ARGOS_O2A3.zip'
$destinationZipPartial = $destinationZip + '.upload'
$destinationPathGate = Join-Path $shareRoot 'ARGOS_O2A3_PATH_GATE.json'
$destinationPathGatePartial = $destinationPathGate + '.upload'
$publishGatePath = Join-Path $PSScriptRoot 'O2A3_PUBLICATION_GATE.json'
$expectedZipSha256 = '574FDA03A11C1E64451288CCB911C80558B96DE3E08EA539C51ECD4D7F1DC94B'
$expectedZipBytes = 12290
$expectedFinalGateSha256 = 'EC530B14EE3AF7CA694C0400002033BF5FA556FE6EFFF621A42C146427DDFD40'
$expectedPathGateSha256 = '9B23EC6C1A75DED33D1F15A211BB8F4E73C7BD69311659A3F5D788D8F5F6626A'
$expectedFrozenCommit = '273053f026dd8e0c521f6463dd7403c3f11e0250'
$branch = 'codex/fiducial-opencv-d-drive'

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-Sha256([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Assert-Pin([string]$Path, [string]$Sha256) {
    Assert-True (Test-Path -LiteralPath $Path -PathType Leaf) "O2A3 publication dependency is absent: $Path"
    Assert-True ((Get-Sha256 $Path) -eq $Sha256) "O2A3 publication dependency changed: $Path"
}
function Write-JsonCreateNew([string]$Path, [object]$Value, [int]$Depth = 12) {
    Assert-True (-not (Test-Path -LiteralPath $Path)) "O2A3 publication gate exists: $Path"
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}

Assert-Pin $sourceZip $expectedZipSha256
Assert-Pin $finalGatePath $expectedFinalGateSha256
Assert-Pin $sourcePathGate $expectedPathGateSha256
Assert-True ((Get-Item -LiteralPath $sourceZip).Length -eq $expectedZipBytes) 'O2A3 frozen ZIP byte count changed.'
$finalGate = Get-Content -Raw -LiteralPath $finalGatePath | ConvertFrom-Json
Assert-True ([string]$finalGate.state -eq 'PASS_O2A3_FINAL_PACKAGE_GATE' -and [string]$finalGate.lifecycle -eq 'FROZEN') 'O2A3 final package gate changed.'
Assert-True ([bool]$finalGate.oneJbodObservationAuthorized -and -not [bool]$finalGate.imageAccessAuthorized -and -not [bool]$finalGate.taskOrProcessRestartAuthorized) 'O2A3 final package authority changed.'
Assert-True ([bool]$finalGate.reviewOnly -and -not [bool]$finalGate.productionRoutingEnabled) 'O2A3 final package safety flags changed.'

$continuity = Get-Content -Raw -LiteralPath $continuityPath | ConvertFrom-Json
Assert-True ([string]$continuity.activePhase -eq 'OCV02_O2A3_EXACT_SLOT16_SCRIBE_OBSERVATION_FROZEN_READY_TO_PUBLISH') 'O2A3 continuity phase changed.'
Assert-True ([string]$continuity.openCvAllImageProcessingMigration.ocv02O2A3FinalZipSha256 -eq $expectedZipSha256) 'O2A3 continuity ZIP identity changed.'
Assert-True (-not [bool]$continuity.openCvAllImageProcessingMigration.ocv02O2A3Published -and [bool]$continuity.openCvAllImageProcessingMigration.ocv02O2A3OneJbodObservationAuthorized) 'O2A3 continuity publication/authorization state changed.'
Assert-True (-not [bool]$continuity.productionEligible -and -not [bool]$continuity.xmlEligible -and -not [bool]$continuity.trainingEligible) 'O2A3 continuity authority widened.'

$currentBranch = (& git -C $project branch --show-current | Out-String).Trim()
$localTip = (& git -C $project rev-parse HEAD | Out-String).Trim()
$remoteLine = (& git -C $project ls-remote --heads origin ('refs/heads/' + $branch) | Out-String).Trim()
$remoteTip = if ([string]::IsNullOrWhiteSpace($remoteLine)) { '' } else { ($remoteLine -split '\s+')[0] }
$statusRows = @(& git -C $project status --porcelain)
Assert-True ($currentBranch -eq $branch) 'O2A3 branch changed.'
Assert-True ($localTip -eq $remoteTip) 'O2A3 local/origin tips do not match.'
& git -C $project merge-base --is-ancestor $expectedFrozenCommit $localTip
Assert-True ($LASTEXITCODE -eq 0) 'O2A3 frozen commit is not an ancestor of the publication tip.'
Assert-True ($statusRows.Count -eq 0) 'O2A3 publication requires a clean worktree.'
Assert-True (Test-Path -LiteralPath $shareRoot -PathType Container) 'O2A3 publication share is unavailable.'
foreach ($path in @($destinationZip,$destinationZipPartial,$destinationPathGate,$destinationPathGatePartial,$publishGatePath)) {
    Assert-True (-not (Test-Path -LiteralPath $path)) "O2A3 create-new publication target exists: $path"
}

if ($Preflight) {
    [ordered]@{
        schema='argos_o2a3_publish_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2A3_PUBLISH_PREFLIGHT';revision='O2A3_20260825T195521Z_SLOT16'
        zipSha256=$expectedZipSha256;zipBytes=$expectedZipBytes;pathGateSha256=$expectedPathGateSha256;branch=$branch;frozenCommit=$expectedFrozenCommit;localTip=$localTip;remoteTip=$remoteTip
        worktreeClean=$true;destinationZipAbsent=$true;destinationPathGateAbsent=$true;jbodContacted=$false;targetExecuted=$false;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false
    } | ConvertTo-Json -Depth 8
    return
}

[IO.File]::Copy($sourceZip, $destinationZipPartial, $false)
Assert-True ((Get-Item -LiteralPath $destinationZipPartial).Length -eq $expectedZipBytes -and (Get-Sha256 $destinationZipPartial) -eq $expectedZipSha256) 'O2A3 uploaded partial ZIP changed.'
Move-Item -LiteralPath $destinationZipPartial -Destination $destinationZip -ErrorAction Stop
Assert-True ((Get-Item -LiteralPath $destinationZip).Length -eq $expectedZipBytes -and (Get-Sha256 $destinationZip) -eq $expectedZipSha256) 'O2A3 published ZIP changed.'

[IO.File]::Copy($sourcePathGate, $destinationPathGatePartial, $false)
Assert-True ((Get-Sha256 $destinationPathGatePartial) -eq $expectedPathGateSha256) 'O2A3 uploaded partial path gate changed.'
Move-Item -LiteralPath $destinationPathGatePartial -Destination $destinationPathGate -ErrorAction Stop
Assert-True ((Get-Sha256 $destinationPathGate) -eq $expectedPathGateSha256) 'O2A3 published path gate changed.'

$publishGate = [ordered]@{
    schema='argos_o2a3_publication_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2A3_PUBLISHED_ONE_OBSERVATION_PENDING';revision='O2A3_20260825T195521Z_SLOT16'
    sourceZip=$sourceZip;destinationZip=$destinationZip;zipSha256=$expectedZipSha256;zipBytes=$expectedZipBytes;destinationPathGate=$destinationPathGate;pathGateSha256=$expectedPathGateSha256
    branch=$branch;frozenCommit=$expectedFrozenCommit;localTip=$localTip;remoteTip=$remoteTip;worktreeCleanBeforePublication=$true;createNewZipVerified=$true;createNewPathGateVerified=$true
    jbodContacted=$false;jbodExecuted=$false;oneObservationExecutionAuthorized=$true;retryAuthorized=$false;imageBytesRead=$false;taskOrProcessRestarted=$false;providerActivated=$false;sourceMutationPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false
}
Write-JsonCreateNew -Path $publishGatePath -Value $publishGate -Depth 12
$publishGate | ConvertTo-Json -Depth 12

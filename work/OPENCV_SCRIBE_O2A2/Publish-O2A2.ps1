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
$source = Join-Path $PSScriptRoot 'final\ARGOS_O2A2.zip'
$finalGatePath = Join-Path $PSScriptRoot 'O2A2_FINAL_PACKAGE_GATE.json'
$prepublicationGatePath = Join-Path $PSScriptRoot 'O2A2_PREPUBLICATION_GATE.json'
$continuityPath = Join-Path $project 'work\ARGOS_CONTINUITY_STATE.json'
$shareRoot = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$destination = Join-Path $shareRoot 'ARGOS_O2A2.zip'
$partialDestination = Join-Path $shareRoot 'ARGOS_O2A2.zip.upload'
$returnPath = Join-Path $shareRoot 'O2A2R.zip'
$publishGatePath = Join-Path $PSScriptRoot 'O2A2_PUBLISH_GATE.json'
$expectedZipSha256 = 'A60926D0EC26BB44B11B47AB70023EC72C08E4F19CE5DA97431CA5212C535C47'
$expectedFinalGateSha256 = '45C7D1AF71AF028BA017F4C9331CADE146F523C4793F41B8A76DDBA7DF811766'
$expectedPrepublicationGateSha256 = 'EF759171069BB04C31FEC33B3987C2419239D8F148BCF1524391F787D82CE497'
$expectedFrozenCommit = 'e1f967e6bcf16258fcbc643b0d51a162f6bdbeb6'
$branch = 'codex/fiducial-opencv-d-drive'

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Assert-Pin([string]$Path, [string]$Sha256) {
    Assert-True (Test-Path -LiteralPath $Path -PathType Leaf) "Pinned file is absent: $Path"
    Assert-True ((Get-Sha256 $Path) -eq $Sha256) "Pinned file changed: $Path"
}

function Write-JsonCreateNew([string]$Path, [object]$Value, [int]$Depth = 12) {
    Assert-True (-not (Test-Path -LiteralPath $Path)) "Create-new JSON path exists: $Path"
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}

Assert-Pin $source $expectedZipSha256
Assert-Pin $finalGatePath $expectedFinalGateSha256
Assert-Pin $prepublicationGatePath $expectedPrepublicationGateSha256
Assert-True ((Get-Item -LiteralPath $source).Length -eq 8816) 'O2A2 frozen ZIP byte count changed.'
$finalGate = Get-Content -LiteralPath $finalGatePath -Raw | ConvertFrom-Json
Assert-True ([string]$finalGate.state -eq 'PASS_O2A2_FINAL_PACKAGE_GATE') 'O2A2 final gate is not PASS.'
Assert-True ([string]$finalGate.lifecycle -eq 'FROZEN' -and [bool]$finalGate.publicationAuthorized) 'O2A2 final gate does not authorize publication.'
Assert-True ([string]$finalGate.zipSha256 -eq $expectedZipSha256 -and [int64]$finalGate.zipBytes -eq 8816) 'O2A2 final gate ZIP identity changed.'
Assert-True ([bool]$finalGate.reviewOnly -and -not [bool]$finalGate.productionRoutingEnabled) 'O2A2 final gate authority changed.'

$continuity = Get-Content -LiteralPath $continuityPath -Raw | ConvertFrom-Json
Assert-True ([string]$continuity.activePhase -eq 'OCV02_SCRIBE_SLOT16_O2A2_DIRECT_OBSERVATION_FROZEN_READY_TO_PUBLISH') 'O2A2 continuity phase changed.'
Assert-True (-not [bool]$continuity.productionEligible -and -not [bool]$continuity.xmlEligible -and -not [bool]$continuity.trainingEligible) 'O2A2 continuity authority widened.'
Assert-True ([string]$continuity.openCvAllImageProcessingMigration.ocv02O2A2FinalZipSha256 -eq $expectedZipSha256) 'O2A2 continuity ZIP identity changed.'
Assert-True (-not [bool]$continuity.openCvAllImageProcessingMigration.ocv02O2A2Published) 'O2A2 continuity already records publication.'

$currentBranch = (& git -C $project branch --show-current | Out-String).Trim()
$localTip = (& git -C $project rev-parse HEAD | Out-String).Trim()
$remoteLine = (& git -C $project ls-remote --heads origin ('refs/heads/' + $branch) | Out-String).Trim()
$remoteTip = if ([string]::IsNullOrWhiteSpace($remoteLine)) { '' } else { ($remoteLine -split '\s+')[0] }
$statusRows = @(& git -C $project status --porcelain)
Assert-True ($currentBranch -eq $branch) 'O2A2 branch changed.'
Assert-True ($localTip -eq $remoteTip) 'O2A2 local/origin tips do not match.'
& git -C $project merge-base --is-ancestor $expectedFrozenCommit $localTip
Assert-True ($LASTEXITCODE -eq 0) 'O2A2 frozen commit is not an ancestor of the publication tip.'
Assert-True ($statusRows.Count -eq 0) 'O2A2 publication requires a clean worktree.'
Assert-True (Test-Path -LiteralPath $shareRoot -PathType Container) 'O2A2 publication share is unavailable.'
Assert-True (-not (Test-Path -LiteralPath $destination)) 'O2A2 final share destination already exists.'
Assert-True (-not (Test-Path -LiteralPath $partialDestination)) 'O2A2 partial share destination already exists.'
Assert-True (-not (Test-Path -LiteralPath $returnPath)) 'O2A2 return ZIP already exists before publication.'
Assert-True (-not (Test-Path -LiteralPath $publishGatePath)) 'O2A2 publish gate already exists.'

if ($Preflight) {
    [ordered]@{
        schema = 'argos_o2a2_publish_preflight_v1'
        createdUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_O2A2_PUBLISH_PREFLIGHT'
        sourceSha256 = $expectedZipSha256
        sourceBytes = 8816
        branch = $branch
        frozenCommit = $expectedFrozenCommit
        localTip = $localTip
        remoteTip = $remoteTip
        worktreeClean = $true
        destinationAbsent = $true
        partialDestinationAbsent = $true
        returnAbsent = $true
        targetExecuted = $false
        mutationsPerformed = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 6
    return
}

[IO.File]::Copy($source, $partialDestination, $false)
Assert-True ((Get-Sha256 $partialDestination) -eq $expectedZipSha256) 'O2A2 uploaded partial hash changed.'
Assert-True ((Get-Item -LiteralPath $partialDestination).Length -eq 8816) 'O2A2 uploaded partial byte count changed.'
Move-Item -LiteralPath $partialDestination -Destination $destination
Assert-True ((Get-Sha256 $destination) -eq $expectedZipSha256) 'O2A2 published ZIP hash changed.'
Assert-True (-not (Test-Path -LiteralPath $returnPath)) 'O2A2 return appeared during publication unexpectedly.'

$publishGate = [ordered]@{
    schema = 'argos_o2a2_publish_gate_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_O2A2_PUBLISHED_ONE_RUN_PENDING'
    revision = 'O2A2'
    sourcePath = $source
    destinationPath = $destination
    zipSha256 = $expectedZipSha256
    zipBytes = 8816
    branch = $branch
    frozenCommit = $expectedFrozenCommit
    localTip = $localTip
    remoteTip = $remoteTip
    worktreeCleanBeforePublication = $true
    finalCopyVerified = $true
    returnPresentAfterPublication = $false
    jbodExecuted = $false
    oneObservationExecutionAuthorized = $true
    retryAuthorized = $false
    targetMutationsPerformed = $false
    imageBytesRead = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
}
Write-JsonCreateNew -Path $publishGatePath -Value $publishGate -Depth 8
$publishGate | ConvertTo-Json -Depth 8

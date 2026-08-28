#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$InvocationManifest,
    [switch]$Preflight,
    [switch]$Publish
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Publish)) { throw 'Specify exactly one of -Preflight or -Publish.' }

function Assert-True([bool]$Condition,[string]$Message) {
    if (-not $Condition) { throw $Message }
}
function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}
function Assert-Pin([string]$Path,[string]$Sha256,[string]$State) {
    Assert-True (Test-Path -LiteralPath $Path -PathType Leaf) "O3N1 DATA_PULL publisher dependency is absent: $Path"
    Assert-True ((Get-Sha256 $Path) -eq $Sha256) "O3N1 DATA_PULL publisher dependency changed: $Path"
    $value = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    Assert-True ([string]$value.state -eq $State) "O3N1 DATA_PULL publisher dependency state changed: $Path"
}
function Write-NewJson([string]$Path,[object]$Value) {
    Assert-True (-not (Test-Path -LiteralPath $Path)) "O3N1 DATA_PULL publication gate exists: $Path"
    [IO.File]::WriteAllText($Path,(($Value | ConvertTo-Json -Depth 12) + [Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))
}

$expectedInvocationPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'O3N1_DATA_PULL_PUBLISH_INVOCATION.json'))
$invocationPath = [IO.Path]::GetFullPath($InvocationManifest)
Assert-True ($invocationPath.Equals($expectedInvocationPath,[StringComparison]::OrdinalIgnoreCase)) 'O3N1 DATA_PULL publisher invocation path changed.'
$invocation = Get-Content -LiteralPath $invocationPath -Raw | ConvertFrom-Json
Assert-True ([string]$invocation.schema -eq 'argos_o3n1_data_pull_publish_invocation_v1' -and [string]$invocation.state -eq 'FROZEN_EXACT_PUBLISH_ONCE') 'O3N1 DATA_PULL publisher invocation state changed.'
Assert-True ([string]$invocation.powerShellScriptSha256 -eq (Get-Sha256 $PSCommandPath)) 'O3N1 DATA_PULL publisher invocation does not pin the exact script.'

$requestId = 'REQ_20260827T235851191Z_95B56EC29E54'
$zipName = $requestId + '.ready.zip'
$zip = Join-Path $PSScriptRoot ('dpf\' + $zipName)
$expectedZipSha256 = '65CE29AE28459607BF9B6AD8217CBA957AE7F26E49499DE28B4B7AF235AAE606'
$routeGate = Join-Path $PSScriptRoot 'O3N1_DATA_PULL_COMPLETE_ROUTE_GATE.json'
$packageGate = Join-Path $PSScriptRoot 'O3N1_DATA_PULL_FINAL_PACKAGE_GATE.json'
$shareObservation = Join-Path $PSScriptRoot 'O3N1_DATA_PULL_CURRENT_SHARE_OBSERVATION.json'
$renderTerminal = Join-Path $PSScriptRoot 'O3N1_RENDER_RESPONSE_COLLECTION_R3_GATE.json'
$checkpoint = Join-Path $PSScriptRoot '..\FRONTSIDE_INSPECTION_REVIEW_ONLY\OCV03_O3N1_RENDER_TERMINAL_DATA_PULL_PUBLISH_READY_20260827.md'
$continuity = Join-Path $PSScriptRoot '..\ARGOS_CONTINUITY_STATE.json'
$publicationGate = Join-Path $PSScriptRoot 'O3N1_DATA_PULL_PUBLISH_GATE.json'
$expectedDisplayRoot = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$requestShare = 'U:\ProjectPortalRO\requests'
$upload = Join-Path $requestShare ($zipName + '.upload')
$destination = Join-Path $requestShare $zipName

Assert-True (Test-Path -LiteralPath $zip -PathType Leaf) 'O3N1 DATA_PULL request ZIP is absent.'
Assert-True ((Get-Sha256 $zip) -eq $expectedZipSha256) 'O3N1 DATA_PULL request ZIP changed.'
Assert-Pin $routeGate '4DBD062AE7D77594C6502611052B10EB40BF17EF7118D38AA48D07DEDDAEA291' 'PASS_O3N1_DATA_PULL_COMPLETE_ROUTE_GATE'
Assert-Pin $packageGate '0ACDC1850535BA9F225A6F64190DEAF82AA020AB9C1DFF10DD69D1C45AE91179' 'PASS_O3N1_DATA_PULL_FINAL_PACKAGE_GATE'
Assert-Pin $shareObservation '54E77ABC0BC9F379AF7F177E40E4B9B21C7FD775B626DEDA8D130B5A601AA7E3' 'PASS_O3N1_DATA_PULL_CURRENT_SHARE_ZERO_PENDING'
Assert-Pin $renderTerminal '4ED5AA2ABC5FCFD8F07CB7BC766AA2A02070FAA93780AEBA456D81BD9451E8BC' 'PASS_O3N1_MATCHING_SIGNED_RENDER_RESPONSE_COLLECTED_R3'
Assert-True ((Get-Sha256 $checkpoint) -eq 'B01129B5D306DF2C5D80D7405C966EDDF75BB0DD150554261DFC55143BF68618') 'O3N1 DATA_PULL checkpoint changed.'
$continuityState = Get-Content -LiteralPath $continuity -Raw | ConvertFrom-Json
Assert-True ([string]$continuityState.activePhase -eq 'OCV03_O3N1_RENDER_TERMINAL_DATA_PULL_PUBLISH_READY') 'O3N1 DATA_PULL continuity phase changed.'
Assert-True ([string]$continuityState.currentPhaseCheckpointSha256 -eq 'B01129B5D306DF2C5D80D7405C966EDDF75BB0DD150554261DFC55143BF68618') 'O3N1 DATA_PULL continuity checkpoint changed.'

$drive = Get-PSDrive -Name U -PSProvider FileSystem -ErrorAction Stop
Assert-True ([string]$drive.DisplayRoot -eq $expectedDisplayRoot) 'O3N1 DATA_PULL persistent U: mapping changed.'
Assert-True (Test-Path -LiteralPath $requestShare -PathType Container) 'O3N1 DATA_PULL request share is unavailable.'
Assert-True (@(Get-ChildItem -LiteralPath $requestShare -File -ErrorAction Stop).Count -eq 0) 'O3N1 DATA_PULL request share is not zero-pending.'
foreach ($path in @($upload,$destination,$publicationGate)) {
    Assert-True (-not (Test-Path -LiteralPath $path)) "O3N1 DATA_PULL publication target exists: $path"
}

$branch = (& git branch --show-current | Out-String).Trim()
Assert-True ($branch -eq 'codex/fiducial-opencv-d-drive') 'O3N1 DATA_PULL publisher branch changed.'
$status = @(& git status --porcelain)
Assert-True ($status.Count -eq 0) 'O3N1 DATA_PULL publisher requires a clean worktree.'
$localTip = (& git rev-parse HEAD | Out-String).Trim()
$remoteTip = (& git rev-parse origin/codex/fiducial-opencv-d-drive | Out-String).Trim()
Assert-True ($localTip -eq $remoteTip) 'O3N1 DATA_PULL publisher requires matching local and remote tips.'

if ($Preflight) {
    [ordered]@{
        schema='argos_o3n1_data_pull_publish_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o')
        state='PASS_O3N1_DATA_PULL_PUBLISH_PREFLIGHT';requestId=$requestId;requestZipSha256=$expectedZipSha256
        branch=$branch;commit=$localTip;displayRoot=$expectedDisplayRoot;share=$requestShare;zeroPending=$true;destinationAbsent=$true
        matchingSignedRenderTerminalVerified=$true;maximumPublications=1;requestRetryAuthorized=$false;mutationsPerformed=$false
        gatewayAcceptanceIsExecutionEvidence=$false;reviewOnly=$true;productionRoutingEnabled=$false
    } | ConvertTo-Json -Depth 8
    return
}

Copy-Item -LiteralPath $zip -Destination $upload -ErrorAction Stop
Assert-True ((Get-Sha256 $upload) -eq $expectedZipSha256) 'O3N1 DATA_PULL upload hash changed.'
Move-Item -LiteralPath $upload -Destination $destination -ErrorAction Stop
Assert-True ((Get-Sha256 $destination) -eq $expectedZipSha256) 'O3N1 DATA_PULL published hash changed.'
$gate = [ordered]@{
    schema='argos_o3n1_data_pull_publish_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3N1_DATA_PULL_REQUEST_PUBLISHED_ONCE'
    requestId=$requestId;requestZipSha256=$expectedZipSha256;destination=$destination;destinationSha256=Get-Sha256 $destination
    branch=$branch;commit=$localTip;publicationCount=1;requestRetryAuthorized=$false;matchingSignedTerminalResponseRequired=$true
    gatewayAcceptanceIsExecutionEvidence=$false;detectorRerunPerformed=$false;thresholdOrAlgorithmChanged=$false;providerActivated=$false
    reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false
}
Write-NewJson -Path $publicationGate -Value $gate
$gate | ConvertTo-Json -Depth 12

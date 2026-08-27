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
    Assert-True (Test-Path -LiteralPath $Path -PathType Leaf) "O3K1 DATA_PULL publisher dependency is absent: $Path"
    Assert-True ((Get-Sha256 $Path) -eq $Sha256) "O3K1 DATA_PULL publisher dependency changed: $Path"
    $value = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    Assert-True ([string]$value.state -eq $State) "O3K1 DATA_PULL publisher dependency state changed: $Path"
}
function Write-NewJson([string]$Path,[object]$Value) {
    Assert-True (-not (Test-Path -LiteralPath $Path)) "O3K1 DATA_PULL publication gate exists: $Path"
    [IO.File]::WriteAllText($Path,(($Value | ConvertTo-Json -Depth 12) + [Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))
}

$expectedInvocationPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'O3K1_DATA_PULL_PUBLISH_INVOCATION.json'))
$invocationPath = [IO.Path]::GetFullPath($InvocationManifest)
Assert-True ($invocationPath.Equals($expectedInvocationPath,[StringComparison]::OrdinalIgnoreCase)) 'O3K1 DATA_PULL publisher invocation path changed.'
$invocation = Get-Content -LiteralPath $invocationPath -Raw | ConvertFrom-Json
Assert-True ([string]$invocation.schema -eq 'argos_o3k1_data_pull_publish_invocation_v1' -and [string]$invocation.state -eq 'FROZEN_EXACT_PUBLISH_ONCE') 'O3K1 DATA_PULL publisher invocation state changed.'
Assert-True ([string]$invocation.powerShellScriptSha256 -eq (Get-Sha256 $PSCommandPath)) 'O3K1 DATA_PULL publisher invocation does not pin the exact script.'

$requestId = 'REQ_20260827T203242373Z_0DBC2A7558B3'
$zipName = $requestId + '.ready.zip'
$zip = Join-Path $PSScriptRoot ('dpf\' + $zipName)
$expectedZipSha256 = 'DD7651041B5C37B6BBBA09E069152BB2C4859D825C6BF38911E80F1DB4F173AF'
$routeGate = Join-Path $PSScriptRoot 'O3K1_DATA_PULL_COMPLETE_ROUTE_GATE.json'
$packageGate = Join-Path $PSScriptRoot 'O3K1_DATA_PULL_FINAL_PACKAGE_GATE.json'
$shareObservation = Join-Path $PSScriptRoot 'O3K1_DATA_PULL_CURRENT_SHARE_OBSERVATION.json'
$renderTerminal = Join-Path $PSScriptRoot 'O3K1_RENDER_RESPONSE_COLLECTION_GATE.json'
$checkpoint = Join-Path $PSScriptRoot '..\FRONTSIDE_INSPECTION_REVIEW_ONLY\OCV03_O3K1_RENDER_TERMINAL_DATA_PULL_PUBLISH_READY_20260827.md'
$continuity = Join-Path $PSScriptRoot '..\ARGOS_CONTINUITY_STATE.json'
$publicationGate = Join-Path $PSScriptRoot 'O3K1_DATA_PULL_PUBLISH_GATE.json'
$expectedDisplayRoot = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$requestShare = 'U:\ProjectPortalRO\requests'
$upload = Join-Path $requestShare ($zipName + '.upload')
$destination = Join-Path $requestShare $zipName

Assert-True (Test-Path -LiteralPath $zip -PathType Leaf) 'O3K1 DATA_PULL request ZIP is absent.'
Assert-True ((Get-Sha256 $zip) -eq $expectedZipSha256) 'O3K1 DATA_PULL request ZIP changed.'
Assert-Pin $routeGate 'F8AB82BB364AD6DBADF2C40AE0BFE7F18B646013D89F9A8663924E0770D06247' 'PASS_O3K1_DATA_PULL_COMPLETE_ROUTE_GATE'
Assert-Pin $packageGate '13CEED2CD3D1B3D1E983633B82BDD971F0241AEF6003F266DB2C9EA09A722C3E' 'PASS_O3K1_DATA_PULL_FINAL_PACKAGE_GATE'
Assert-Pin $shareObservation '0FD809EE0E2BEA961C9E9BA1433D8098813044E7ED9BFC14F83ED17263E9CD11' 'PASS_O3K1_DATA_PULL_CURRENT_SHARE_ZERO_PENDING'
Assert-Pin $renderTerminal '1CE3B6EC3AE63654DCA10B8113ED1DD04A9946EA40DF2A815226886967B7D4E4' 'PASS_O3K1_MATCHING_SIGNED_RENDER_RESPONSE_COLLECTED'
Assert-True ((Get-Sha256 $checkpoint) -eq 'FEDAF3EFC8A6523B4DD58AFEDEEE668284DB02A7464FE0B520FC2720D0373B0D') 'O3K1 DATA_PULL checkpoint changed.'
$continuityState = Get-Content -LiteralPath $continuity -Raw | ConvertFrom-Json
Assert-True ([string]$continuityState.activePhase -eq 'OCV03_O3K1_RENDER_TERMINAL_DATA_PULL_PUBLISH_READY') 'O3K1 DATA_PULL continuity phase changed.'
Assert-True ([string]$continuityState.currentPhaseCheckpointSha256 -eq 'FEDAF3EFC8A6523B4DD58AFEDEEE668284DB02A7464FE0B520FC2720D0373B0D') 'O3K1 DATA_PULL continuity checkpoint changed.'

$drive = Get-PSDrive -Name U -PSProvider FileSystem -ErrorAction Stop
Assert-True ([string]$drive.DisplayRoot -eq $expectedDisplayRoot) 'O3K1 DATA_PULL persistent U: mapping changed.'
Assert-True (Test-Path -LiteralPath $requestShare -PathType Container) 'O3K1 DATA_PULL request share is unavailable.'
Assert-True (@(Get-ChildItem -LiteralPath $requestShare -File -ErrorAction Stop).Count -eq 0) 'O3K1 DATA_PULL request share is not zero-pending.'
foreach ($path in @($upload,$destination,$publicationGate)) {
    Assert-True (-not (Test-Path -LiteralPath $path)) "O3K1 DATA_PULL publication target exists: $path"
}

$branch = (& git branch --show-current | Out-String).Trim()
Assert-True ($branch -eq 'codex/fiducial-opencv-d-drive') 'O3K1 DATA_PULL publisher branch changed.'
$status = @(& git status --porcelain)
Assert-True ($status.Count -eq 0) 'O3K1 DATA_PULL publisher requires a clean worktree.'
$localTip = (& git rev-parse HEAD | Out-String).Trim()
$remoteTip = (& git rev-parse origin/codex/fiducial-opencv-d-drive | Out-String).Trim()
Assert-True ($localTip -eq $remoteTip) 'O3K1 DATA_PULL publisher requires matching local and remote tips.'

if ($Preflight) {
    [ordered]@{
        schema='argos_o3k1_data_pull_publish_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o')
        state='PASS_O3K1_DATA_PULL_PUBLISH_PREFLIGHT';requestId=$requestId;requestZipSha256=$expectedZipSha256
        branch=$branch;commit=$localTip;displayRoot=$expectedDisplayRoot;share=$requestShare;zeroPending=$true;destinationAbsent=$true
        matchingSignedRenderTerminalVerified=$true;maximumPublications=1;requestRetryAuthorized=$false;mutationsPerformed=$false
        gatewayAcceptanceIsExecutionEvidence=$false;reviewOnly=$true;productionRoutingEnabled=$false
    } | ConvertTo-Json -Depth 8
    return
}

Copy-Item -LiteralPath $zip -Destination $upload -ErrorAction Stop
Assert-True ((Get-Sha256 $upload) -eq $expectedZipSha256) 'O3K1 DATA_PULL upload hash changed.'
Move-Item -LiteralPath $upload -Destination $destination -ErrorAction Stop
Assert-True ((Get-Sha256 $destination) -eq $expectedZipSha256) 'O3K1 DATA_PULL published hash changed.'
$gate = [ordered]@{
    schema='argos_o3k1_data_pull_publish_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3K1_DATA_PULL_REQUEST_PUBLISHED_ONCE'
    requestId=$requestId;requestZipSha256=$expectedZipSha256;destination=$destination;destinationSha256=Get-Sha256 $destination
    branch=$branch;commit=$localTip;publicationCount=1;requestRetryAuthorized=$false;matchingSignedTerminalResponseRequired=$true
    gatewayAcceptanceIsExecutionEvidence=$false;detectorRerunPerformed=$false;thresholdOrAlgorithmChanged=$false;providerActivated=$false
    reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false
}
Write-NewJson -Path $publicationGate -Value $gate
$gate | ConvertTo-Json -Depth 12

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

function Require([bool]$Condition,[string]$Message) {
    if (-not $Condition) { throw $Message }
}
function Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}
function Required([object]$Object,[string]$Name) {
    Require ($null -ne $Object) "Required object is null while reading $Name."
    Require ($Object.PSObject.Properties.Name -contains $Name) "Required property is absent: $Name"
    return $Object.$Name
}
function Resolve-File([string]$Project,[string]$Path,[string]$Label) {
    $resolved = $Path
    if (-not [IO.Path]::IsPathRooted($resolved)) { $resolved = Join-Path $Project $resolved.Replace('/','\') }
    $resolved = [IO.Path]::GetFullPath($resolved)
    Require (Test-Path -LiteralPath $resolved -PathType Leaf) "$Label is absent: $resolved"
    return $resolved
}
function Require-PinnedState([string]$Path,[string]$Sha256,[string]$State,[string]$Label) {
    Require ((Sha256 $Path) -eq $Sha256) "$Label hash changed: $Path"
    $value = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    Require ([string](Required $value 'state') -eq $State) "$Label state changed: $Path"
    return $value
}
function Write-NewJson([string]$Path,[object]$Value) {
    Require (-not (Test-Path -LiteralPath $Path)) "O3F15 observer publication gate exists: $Path"
    $encoding = New-Object Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($Path,(($Value | ConvertTo-Json -Depth 16) + [Environment]::NewLine),$encoding)
}

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
$invocationPath = [IO.Path]::GetFullPath($InvocationManifest)
Require (Test-Path -LiteralPath $invocationPath -PathType Leaf) 'O3F15 observer publish invocation is absent.'
$invocation = Get-Content -LiteralPath $invocationPath -Raw | ConvertFrom-Json
Require ([string](Required $invocation 'schema') -eq 'argos_ocv03_o3f15_observer_publish_invocation_v1') 'O3F15 observer publish invocation schema changed.'
Require ([string](Required $invocation 'state') -eq 'FROZEN_EXACT_PUBLISH_ONCE') 'O3F15 observer publish invocation is not frozen.'
$flow = [string](Required $invocation 'flow')
Require ($flow -in @('P1','F1','T1')) 'O3F15 observer publish flow changed.'
Require ([string](Required $invocation 'powerShellScriptSha256') -eq (Sha256 $PSCommandPath)) 'O3F15 observer publish invocation does not pin this exact publisher.'
Require ([int](Required $invocation 'maximumPublications') -eq 1 -and -not [bool](Required $invocation 'requestRetryAuthorized')) 'O3F15 observer publication/retry boundary changed.'
Require ([bool](Required $invocation 'matchingSignedTerminalResponseRequired') -and -not [bool](Required $invocation 'gatewayAcceptanceIsExecutionEvidence')) 'O3F15 observer terminal-response semantics changed.'
Require ([bool](Required $invocation 'reviewOnly') -and -not [bool](Required $invocation 'productionRoutingEnabled')) 'O3F15 observer publish authority widened.'

$requestId = [string](Required $invocation 'requestId')
Require ($requestId -match '^REQ_[0-9]{8}T[0-9]{9}Z_[A-F0-9]{12}$') 'O3F15 observer request ID is invalid.'
$zip = Resolve-File $project ([string](Required $invocation 'requestZip')) 'O3F15 observer request ZIP'
$expectedZipSha256 = [string](Required $invocation 'requestZipSha256')
Require ((Sha256 $zip) -eq $expectedZipSha256) 'O3F15 observer request ZIP changed.'
$routeGatePath = Resolve-File $project ([string](Required $invocation 'routeGate')) 'O3F15 observer route gate'
$packageGatePath = Resolve-File $project ([string](Required $invocation 'packageGate')) 'O3F15 observer package gate'
$routeGate = Require-PinnedState $routeGatePath ([string](Required $invocation 'routeGateSha256')) ('PASS_O3F15_' + $flow + '_OBSERVER_COMPLETE_ROUTE_GATE') 'O3F15 observer route gate'
$packageGate = Require-PinnedState $packageGatePath ([string](Required $invocation 'packageGateSha256')) ('PASS_O3F15_' + $flow + '_OBSERVER_FINAL_PACKAGE_GATE') 'O3F15 observer package gate'
Require ([string](Required $routeGate 'requestId') -eq $requestId -and [string](Required $routeGate 'requestZipSha256') -eq $expectedZipSha256) 'O3F15 observer route gate request identity changed.'
Require ([string](Required $packageGate 'requestId') -eq $requestId -and [string](Required $packageGate 'requestZipSha256') -eq $expectedZipSha256) 'O3F15 observer package gate request identity changed.'
Require ([string](Required $routeGate 'approvedRoot') -eq 'JBOD_KLARF_EXPORT') 'O3F15 observer approved root changed.'
Require ([string](Required $routeGate 'endpointWorkerSha256') -eq 'CB6700714E20DAC2D3C097095A2800C92ECAAC75F29878F4C86326493B246250') 'O3F15 observer endpoint worker pin changed.'
Require ([string](Required $routeGate 'installedConfigEvidenceSha256') -eq '465107D861E8D2C376A419B1C15841BE3A5757C6498C36CA56B9A95A2F0B76DB') 'O3F15 observer endpoint config evidence changed.'
Require ([string](Required $routeGate 'inheritedQueueSafetyGateSha256') -eq '170015C259C3EC8FC0B369F070748A555336F8FB312636819B7F99EBCE85A65D') 'O3F15 observer queue-safety pin changed.'
Require (-not [bool](Required $routeGate 'retryOnFailure') -and [bool](Required $routeGate 'matchingSignedTerminalResponseRequired')) 'O3F15 observer route retry/terminal boundary changed.'
Require (-not [bool](Required $routeGate 'sourceImageBytesRequested') -and -not [bool](Required $routeGate 'existingTaskOrProcessActionPerformed')) 'O3F15 observer request scope widened.'

$preactionPath = Resolve-File $project ([string](Required $invocation 'preactionContract')) 'O3F15 observer pre-action contract'
$historyPath = Join-Path $project 'work\ARGOS_HISTORY_NO_REPEAT_AUDIT_20260820.json'
$preactionTool = Join-Path $project 'utilities\Confirm-ArgosZeroRecurrencePreaction.ps1'
& $preactionTool -AuditPath $historyPath -ContractPath $preactionPath -ProjectRoot $project -Preflight | Out-Null
$preaction = Get-Content -LiteralPath $preactionPath -Raw | ConvertFrom-Json
$invocationDependencies = @((Required $preaction 'dependencies') | Where-Object { [IO.Path]::IsPathRooted([string]$_.path) -and [IO.Path]::GetFullPath([string]$_.path).Equals($invocationPath,[StringComparison]::OrdinalIgnoreCase) })
Require ($invocationDependencies.Count -eq 1 -and [string](Required $invocationDependencies[0] 'sha256') -eq (Sha256 $invocationPath)) 'O3F15 observer pre-action contract does not pin this exact publish invocation.'

$continuityTool = Join-Path $project 'utilities\Confirm-ArgosProjectContinuity.ps1'
$continuityResult = & $continuityTool -ProjectRoot $project
Require ([string](Required $continuityResult 'State') -eq 'PASS_ARGOS_PROJECT_CONTINUITY') 'O3F15 observer continuity gate failed.'
$currentBranch = (& git -C $project branch --show-current | Out-String).Trim()
$localTip = (& git -C $project rev-parse HEAD | Out-String).Trim()
$remoteTip = (& git -C $project rev-parse origin/codex/fiducial-opencv-d-drive | Out-String).Trim()
Require ($currentBranch -eq 'codex/fiducial-opencv-d-drive' -and $localTip -eq $remoteTip) 'O3F15 observer publish requires matching local/origin branch tips.'
& git -C $project diff --quiet
Require ($LASTEXITCODE -eq 0) 'O3F15 observer publish requires no unstaged tracked changes.'
& git -C $project diff --cached --quiet
Require ($LASTEXITCODE -eq 0) 'O3F15 observer publish requires no staged tracked changes.'

$expectedDisplayRoot = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$drive = Get-PSDrive -Name U -PSProvider FileSystem -ErrorAction Stop
$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='U:'" -ErrorAction Stop
Require ([string]$drive.DisplayRoot -eq $expectedDisplayRoot -and [string]$disk.ProviderName -eq $expectedDisplayRoot -and [int]$disk.DriveType -eq 4) 'O3F15 observer qualified persistent U: mapping changed.'
$requestShare = 'U:\ProjectPortalRO\requests'
Require (Test-Path -LiteralPath $requestShare -PathType Container) 'O3F15 observer request share is unavailable.'
$pending = @(Get-ChildItem -LiteralPath $requestShare -File -ErrorAction Stop)
Require ($pending.Count -eq 0) 'O3F15 observer request share is not zero-pending.'
$zipName = $requestId + '.ready.zip'
$upload = Join-Path $requestShare ($zipName + '.upload')
$destination = Join-Path $requestShare $zipName
$publicationGate = [IO.Path]::GetFullPath([string](Required $invocation 'publicationGate'))
foreach ($path in @($upload,$destination,$publicationGate)) {
    Require (-not (Test-Path -LiteralPath $path)) "O3F15 observer publication target exists: $path"
}

if ($Preflight) {
    [ordered]@{
        schema='argos_ocv03_o3f15_observer_publish_preflight_v1'; checkedUtc=[DateTime]::UtcNow.ToString('o')
        state=('PASS_O3F15_' + $flow + '_OBSERVER_PUBLISH_PREFLIGHT'); flow=$flow; requestId=$requestId
        requestZipSha256=$expectedZipSha256; branch=$currentBranch; commit=$localTip; displayRoot=$expectedDisplayRoot
        zeroPending=$true; destinationAbsent=$true; continuityState=[string]$continuityResult.State
        maximumPublications=1; requestRetryAuthorized=$false; mutationsPerformed=$false; requestPublished=$false
        gatewayAcceptanceIsExecutionEvidence=$false; reviewOnly=$true; productionRoutingEnabled=$false
    } | ConvertTo-Json -Depth 10
    return
}

Copy-Item -LiteralPath $zip -Destination $upload -ErrorAction Stop
Require ((Sha256 $upload) -eq $expectedZipSha256) 'O3F15 observer upload hash changed.'
Move-Item -LiteralPath $upload -Destination $destination -ErrorAction Stop
Require ((Sha256 $destination) -eq $expectedZipSha256) 'O3F15 observer published hash changed.'
$gate = [ordered]@{
    schema='argos_ocv03_o3f15_observer_publish_gate_v1'; createdUtc=[DateTime]::UtcNow.ToString('o')
    state=('PASS_O3F15_' + $flow + '_OBSERVER_PUBLISHED_ONCE_AWAITING_SIGNED_RESPONSE'); flow=$flow
    requestId=$requestId; requestZipPath=$zip; requestZipSha256=$expectedZipSha256
    destination=$destination; destinationSha256=Sha256 $destination; branch=$currentBranch; commit=$localTip
    publicationCount=1; requestRetryAuthorized=$false; matchingSignedTerminalResponseRequired=$true
    gatewayAcceptanceIsExecutionEvidence=$false; sourceImageBytesRequested=$false; detectorRerunPerformed=$false
    sourceMutationPerformed=$false; sourceDeletionPerformed=$false; existingTaskOrProcessActionPerformed=$false
    providerActivated=$false; automaticHoldClearancePerformed=$false; reviewOnly=$true; trainingEligible=$false
    xmlEligible=$false; productionEligible=$false; productionRoutingEnabled=$false
}
Write-NewJson -Path $publicationGate -Value $gate
$gate | ConvertTo-Json -Depth 16

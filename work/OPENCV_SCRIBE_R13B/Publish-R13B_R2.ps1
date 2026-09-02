#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$InvocationManifest,
    [switch]$Preflight,
    [switch]$Publish
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ([bool]$Preflight -eq [bool]$Publish) { throw 'Specify exactly one of -Preflight or -Publish.' }

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-Sha256([string]$Path) {
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '') }
    finally { $sha.Dispose(); $stream.Dispose() }
}

function Resolve-ProjectFile([string]$ProjectRoot, [string]$RelativePath, [string]$Label) {
    Assert-True (-not [string]::IsNullOrWhiteSpace($RelativePath)) "$Label path is empty."
    Assert-True (-not [IO.Path]::IsPathRooted($RelativePath)) "$Label path must be project-relative: $RelativePath"
    $normalized = $RelativePath.Replace('/', '\')
    Assert-True ($normalized -notmatch '(^|\\)\.\.(\\|$)') "$Label path traverses outside the project: $RelativePath"
    $prefix = [IO.Path]::GetFullPath($ProjectRoot).TrimEnd('\') + '\'
    $full = [IO.Path]::GetFullPath((Join-Path $ProjectRoot $normalized))
    Assert-True ($full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) "$Label path escapes the project: $RelativePath"
    return $full
}

function Assert-PinnedFile([string]$Path, [string]$ExpectedSha256, [string]$Label) {
    Assert-True (Test-Path -LiteralPath $Path -PathType Leaf) "$Label is absent: $Path"
    Assert-True ((Get-Sha256 $Path) -eq $ExpectedSha256.ToUpperInvariant()) "$Label hash changed: $Path"
}

function Normalize-Root([string]$Path) {
    return $Path.Replace('/', '\').TrimEnd('\')
}

function Write-JsonCreateNew([string]$Path, [object]$Value) {
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes((($Value | ConvertTo-Json -Depth 16) + [Environment]::NewLine))
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes, 0, $bytes.Length) }
    finally { $stream.Dispose() }
}

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
Assert-True (Test-Path -LiteralPath $InvocationManifest -PathType Leaf) 'R13B publication invocation manifest is absent.'
$invocationPath = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $InvocationManifest).Path)
$invocation = Get-Content -Raw -LiteralPath $invocationPath | ConvertFrom-Json
Assert-True ([string]$invocation.schema -eq 'argos_r13b_publication_r2_invocation_v1') 'R13B R2 publication invocation schema changed.'
Assert-True ([string]$invocation.requestId -eq 'REQ_20260902T204408092Z_R13B') 'R13B publication request identity changed.'
Assert-True ([string]$invocation.requiredBranch -eq 'codex/opencv-scribe-deciphering') 'R13B publication branch changed.'
Assert-True ([bool]$invocation.authority.publicationAuthorized -and [int]$invocation.authority.maximumPublications -eq 1 -and -not [bool]$invocation.authority.retryAuthorized -and [bool]$invocation.authority.matchingSignedTerminalResponseOnly) 'R13B publication authority/count boundary changed.'
Assert-True ([bool]$invocation.authority.reviewOnly -and -not [bool]$invocation.authority.automaticIdentityAuthority -and -not [bool]$invocation.authority.trainingEligible -and -not [bool]$invocation.authority.xmlEligible -and -not [bool]$invocation.authority.productionEligible -and -not [bool]$invocation.authority.productionRoutingEnabled -and -not [bool]$invocation.authority.providerActivationAllowed) 'R13B publication authority widened.'
Assert-True ((Get-Sha256 $MyInvocation.MyCommand.Path) -eq [string]$invocation.publisherSha256) 'R13B publisher self-pin changed.'

$sourceZip = Resolve-ProjectFile $project ([string]$invocation.requestZip.path) 'request ZIP'
Assert-PinnedFile $sourceZip ([string]$invocation.requestZip.sha256) 'R13B request ZIP'
Assert-True ((Get-Item -LiteralPath $sourceZip).Length -eq [int64]$invocation.requestZip.bytes) 'R13B request ZIP byte count changed.'
foreach ($gatePin in @($invocation.requiredGates)) {
    $gatePath = Resolve-ProjectFile $project ([string]$gatePin.path) 'publication gate dependency'
    Assert-PinnedFile $gatePath ([string]$gatePin.sha256) 'R13B publication gate dependency'
    $gate = Get-Content -Raw -LiteralPath $gatePath | ConvertFrom-Json
    $property = [string]$gatePin.stateProperty
    Assert-True ($gate.PSObject.Properties.Name -contains $property) "R13B publication gate property is absent: $property"
    Assert-True ([string]$gate.$property -eq [string]$gatePin.requiredState) "R13B publication gate state changed: $($gatePin.path)"
}

$responseCollectorScript = Resolve-ProjectFile $project ([string]$invocation.responseCollector.scriptPath) 'response collector script'
$responseCollectorInvocation = Resolve-ProjectFile $project ([string]$invocation.responseCollector.invocationPath) 'response collector invocation'
$responseCollectorRehearsalGate = Resolve-ProjectFile $project ([string]$invocation.responseCollector.rehearsalGatePath) 'response collector rehearsal gate'
Assert-PinnedFile $responseCollectorScript ([string]$invocation.responseCollector.scriptSha256) 'R13B response collector script'
Assert-PinnedFile $responseCollectorInvocation ([string]$invocation.responseCollector.invocationSha256) 'R13B response collector invocation'
Assert-PinnedFile $responseCollectorRehearsalGate ([string]$invocation.responseCollector.rehearsalGateSha256) 'R13B response collector rehearsal gate'
$responseCollectorGate = Get-Content -Raw -LiteralPath $responseCollectorRehearsalGate | ConvertFrom-Json
Assert-True ([string]$responseCollectorGate.state -eq 'PASS_R13B_COLLECTOR_ZIP_LOOKUP_REHEARSAL' -and [string]$responseCollectorGate.collectorSha256 -eq [string]$invocation.responseCollector.scriptSha256 -and [bool]$responseCollectorGate.exactNestedBytesRead -and [bool]$responseCollectorGate.exactNormalizedFileSetClosed -and [bool]$responseCollectorGate.undeclaredExtraEntryRejected -and [bool]$responseCollectorGate.directoryEntryRejected -and [bool]$responseCollectorGate.normalizedDuplicateEntryRejected) 'R13B response collector rehearsal binding changed.'

$observerScript = Resolve-ProjectFile $project ([string]$invocation.freshQueueObservation.scriptPath) 'queue observer script'
$observerInvocation = Resolve-ProjectFile $project ([string]$invocation.freshQueueObservation.invocationPath) 'queue observer invocation'
Assert-PinnedFile $observerScript ([string]$invocation.freshQueueObservation.scriptSha256) 'R13B queue observer script'
Assert-PinnedFile $observerInvocation ([string]$invocation.freshQueueObservation.invocationSha256) 'R13B queue observer invocation'
$observerJson = & $observerScript -InvocationManifest $observerInvocation -Preflight | Out-String
$observation = $observerJson | ConvertFrom-Json
Assert-True ([string]$observation.state -eq 'PASS_R13B_CURRENT_SHARE_OBSERVATION_PREFLIGHT' -and [string]$observation.requestId -eq [string]$invocation.requestId) 'R13B fresh queue observation did not pass for this request.'
Assert-True ([bool]$observation.safety.targetAbsentFromPendingProcessedAndResponses -and [bool]$observation.safety.zeroPendingRequests -and [bool]$observation.safety.zeroUnresolvedEarlierAcceptedRequests -and [bool]$observation.safety.stableBoundedSnapshot) 'R13B fresh queue observation is not clear.'
Assert-True ([int]$observation.scan.pendingRequestFileCount -eq 0 -and [int]$observation.scan.finalPendingRequestFileCount -eq 0 -and [int]$observation.scan.unresolvedEarlierAcceptedRequestCount -eq 0 -and [int]$observation.scan.ambiguousEarlierAcceptedRequestCount -eq 0) 'R13B fresh queue counts are not clear.'
Assert-True ([int]$observation.scan.exactRequestIdPendingMatchCount -eq 0 -and [int]$observation.scan.exactRequestIdProcessedLeafMatchCount -eq 0 -and [int]$observation.scan.exactRequestIdProcessedManifestMatchCount -eq 0 -and [int]$observation.scan.exactRequestIdResponseManifestMatchCount -eq 0) 'R13B exact request identity already exists on the route.'
$observedAt = [DateTimeOffset]::Parse([string]$observation.observedUtc, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal)
$observationAgeSeconds = ([DateTimeOffset]::UtcNow - $observedAt.ToUniversalTime()).TotalSeconds
Assert-True ($observationAgeSeconds -ge -5 -and $observationAgeSeconds -le [int]$invocation.freshQueueObservation.maximumAgeSeconds) 'R13B queue observation is stale or future-dated.'

$currentBranch = (& git -C $project branch --show-current | Out-String).Trim()
$localTip = (& git -C $project rev-parse HEAD | Out-String).Trim()
$remoteTip = (& git -C $project rev-parse ('origin/' + [string]$invocation.requiredBranch) | Out-String).Trim()
Assert-True ($currentBranch -eq [string]$invocation.requiredBranch -and $localTip -eq $remoteTip) 'R13B publication requires matching local/origin branch tips.'
$worktreeRows = @(& git -C $project status --porcelain=v1)
Assert-True ($worktreeRows.Count -eq 0) 'R13B publication requires a clean worktree.'

$shareRoot = [string]$invocation.route.inspectionRevsUnc
Assert-True ($shareRoot -eq '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs') 'R13B InspectionRevs route changed.'
$psDrive = Get-PSDrive -Name U -PSProvider FileSystem -ErrorAction Stop
$logicalDisk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='U:'" -ErrorAction Stop
Assert-True ((Normalize-Root ([string]$psDrive.DisplayRoot)).Equals((Normalize-Root $shareRoot), [StringComparison]::OrdinalIgnoreCase)) 'R13B U: PowerShell mapping changed.'
Assert-True ([int]$logicalDisk.DriveType -eq 4 -and (Normalize-Root ([string]$logicalDisk.ProviderName)).Equals((Normalize-Root $shareRoot), [StringComparison]::OrdinalIgnoreCase)) 'R13B U: is not the exact persistent network mapping.'
$requestRoot = 'U:\ProjectPortalRO\requests'
Assert-True (Test-Path -LiteralPath $requestRoot -PathType Container) 'R13B request route is unavailable.'
$readyPath = $requestRoot + '\' + [string]$invocation.requestId + '.ready.zip'
$uploadPath = $readyPath + '.upload'
$processedPath = $requestRoot + '\processed\' + [string]$invocation.requestId + '.ready.zip'
$publishGatePath = Resolve-ProjectFile $project ([string]$invocation.publishGatePath) 'publication gate output'
$pendingNow = @(Get-ChildItem -LiteralPath $requestRoot -File -ErrorAction Stop | Select-Object -First 2)
Assert-True ($pendingNow.Count -eq 0) ('R13B another request appeared after observation: ' + (($pendingNow | ForEach-Object { $_.Name }) -join ','))
foreach ($path in @($uploadPath,$readyPath,$processedPath,$publishGatePath)) { Assert-True (-not (Test-Path -LiteralPath $path)) "R13B create-new publication target exists: $path" }

$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
$pathJson = & $pathTool -CandidatePath @($sourceZip,$uploadPath,$readyPath,$processedPath,$publishGatePath,$invocationPath) -ReservedSuffixCharacters 32 -AsJson | Out-String
$pathGate = $pathJson | ConvertFrom-Json
Assert-True ([string]$pathGate.state -eq 'PASS_PATH_BUDGET') 'R13B exact publication path budget failed.'
$maximumEffectiveLength = [int]((@($pathGate.candidates) | Measure-Object effectiveLength -Maximum).Maximum)
Assert-True ($maximumEffectiveLength -lt 200) 'R13B publication path reached effective length 200.'

$preflightResult = [ordered]@{
    schema='argos_r13b_publish_preflight_v1';checkedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R13B_EXACT_ONE_TIME_PUBLISH_PREFLIGHT';requestId=[string]$invocation.requestId
    invocationManifestSha256=Get-Sha256 $invocationPath;sourceZipSha256=[string]$invocation.requestZip.sha256;sourceZipBytes=[int64]$invocation.requestZip.bytes
    branch=$currentBranch;localTip=$localTip;remoteTip=$remoteTip;worktreeRowCount=$worktreeRows.Count;freshObservationUtc=[string]$observation.observedUtc;freshObservationAgeSeconds=[Math]::Round($observationAgeSeconds,3)
    pendingShareRequestCount=0;unresolvedEarlierAcceptedRequestCount=0;exactRequestIdRouteMatchCount=0;persistentUMapping=$true;targetAndUploadAbsent=$true
    pathState=[string]$pathGate.state;maximumEffectiveLength=$maximumEffectiveLength;responseCollectorSha256=[string]$invocation.responseCollector.scriptSha256;responseCollectorInvocationSha256=[string]$invocation.responseCollector.invocationSha256;responseCollectorRehearsalGateSha256=[string]$invocation.responseCollector.rehearsalGateSha256;mutationsPerformed=$false;maximumPublications=1;retryAuthorized=$false;matchingSignedTerminalResponseOnly=$true
    targetExecuted=$false;providerActivated=$false;automaticIdentityAuthority=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false
}
if ($Preflight) { $preflightResult | ConvertTo-Json -Depth 12; return }

$uploadCreated = $false
try {
    [IO.File]::Copy($sourceZip, $uploadPath, $false)
    $uploadCreated = $true
    Assert-True ((Get-Item -LiteralPath $uploadPath).Length -eq [int64]$invocation.requestZip.bytes -and (Get-Sha256 $uploadPath) -eq [string]$invocation.requestZip.sha256) 'R13B upload copy changed.'
    [IO.File]::Move($uploadPath, $readyPath)
    $uploadCreated = $false
    Assert-True ((Get-Item -LiteralPath $readyPath).Length -eq [int64]$invocation.requestZip.bytes -and (Get-Sha256 $readyPath) -eq [string]$invocation.requestZip.sha256) 'R13B published request changed.'
    $gate = [ordered]@{
        schema='argos_r13b_publish_gate_v1';publishedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R13B_EXACT_SIGNED_REQUEST_PUBLISHED_CREATE_NEW';disposition='PENDING_GATE';requestId=[string]$invocation.requestId
        invocationManifestSha256=Get-Sha256 $invocationPath;sourceZip=$sourceZip;publishedPath=$readyPath;bytes=[int64]$invocation.requestZip.bytes;sha256=[string]$invocation.requestZip.sha256
        branch=$currentBranch;localTip=$localTip;remoteTip=$remoteTip;freshQueueObservationUtc=[string]$observation.observedUtc;createNew=$true;overwritePerformed=$false;persistentUMapping=$true;persistentUMappingRoot=$shareRoot;persistentUMappingLeftInPlace=$true
        responseCollectorSha256=[string]$invocation.responseCollector.scriptSha256;responseCollectorInvocationSha256=[string]$invocation.responseCollector.invocationSha256;responseCollectorRehearsalGateSha256=[string]$invocation.responseCollector.rehearsalGateSha256
        maximumPublications=1;retryAuthorized=$false;matchingSignedTerminalResponseOnly=$true;targetExecuted=$false;sourceDeletionPerformed=$false;sourceMutationPerformed=$false;taskOrProcessRestarted=$false
        providerActivated=$false;automaticIdentityAuthority=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false
    }
    Write-JsonCreateNew $publishGatePath $gate
    $gate | ConvertTo-Json -Depth 16
}
catch {
    if ($uploadCreated -and -not (Test-Path -LiteralPath $readyPath) -and (Test-Path -LiteralPath $uploadPath -PathType Leaf)) {
        if ((Get-Item -LiteralPath $uploadPath).Length -eq [int64]$invocation.requestZip.bytes -and (Get-Sha256 $uploadPath) -eq [string]$invocation.requestZip.sha256) { [IO.File]::Delete($uploadPath) }
    }
    throw
}

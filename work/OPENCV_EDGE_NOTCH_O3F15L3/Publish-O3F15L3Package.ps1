#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$InvocationManifest,
    [switch]$Preflight,
    [switch]$Publish
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Require([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Sha([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash }
function Write-NewJson([string]$Path, [object]$Value) {
    Require (-not (Test-Path -LiteralPath $Path)) "O3F15L3 create-new publication gate exists: $Path"
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 20) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}
function Require-Pin([object]$Pin, [string]$ExpectedState, [string]$Project) {
    $path = Join-Path $Project ([string]$Pin.path)
    Require (Test-Path -LiteralPath $path -PathType Leaf) "O3F15L3 pinned publication dependency absent: $path"
    Require ((Sha $path) -ceq [string]$Pin.sha256) "O3F15L3 pinned publication dependency changed: $path"
    $value = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    Require ([string]$value.state -ceq $ExpectedState) "O3F15L3 pinned publication state changed: $path"
    $value
}

Require ($Preflight -xor $Publish) 'Specify exactly one of -Preflight or -Publish.'
Require ([string]$PSVersionTable.PSEdition -ceq 'Desktop' -and [int]$PSVersionTable.PSVersion.Major -eq 5 -and [int]$PSVersionTable.PSVersion.Minor -eq 1) 'O3F15L3 publisher requires exact Windows PowerShell 5.1.'
$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$expectedInvocation = Join-Path $PSScriptRoot 'O3F15L3_PUBLISH_INVOCATION.json'
$invocationPath = [IO.Path]::GetFullPath($InvocationManifest)
Require ($invocationPath.Equals($expectedInvocation, [StringComparison]::OrdinalIgnoreCase)) 'O3F15L3 publish invocation path changed.'
Require (Test-Path -LiteralPath $invocationPath -PathType Leaf) 'O3F15L3 publish invocation is absent.'
$invocation = Get-Content -LiteralPath $invocationPath -Raw | ConvertFrom-Json
Require ([string]$invocation.schema -ceq 'argos_ocv03_o3f15l3_publish_invocation_v1' -and [string]$invocation.state -ceq 'FROZEN_EXACT_PUBLISH_INVOCATION') 'O3F15L3 publish invocation is not frozen.'
Require ([string]$invocation.publisherSha256 -ceq (Sha $PSCommandPath) -and [int]$invocation.maximumPublicationsAuthorized -eq 1 -and -not [bool]$invocation.requestRetryAuthorized) 'O3F15L3 publish authority changed.'
$requestId = [string]$invocation.requestId
$source = Join-Path $project ([string]$invocation.requestZip)
Require (Test-Path -LiteralPath $source -PathType Leaf) 'O3F15L3 signed request ZIP is absent.'
Require ((Get-Item -LiteralPath $source).Length -eq [int64]$invocation.requestZipBytes -and (Sha $source) -ceq [string]$invocation.requestZipSha256) 'O3F15L3 signed request ZIP changed.'
$signGate = Require-Pin $invocation.signGate 'PASS_O3F15L3_SIGNED_PREFLIGHT_DIAGNOSTIC_PACKAGE' $project
$rehearsalGate = Require-Pin $invocation.finalZipRehearsalGate 'PASS_O3F15L3_FINAL_ZIP_WINDOWS_PS51_REHEARSAL' $project
$routeGate = Require-Pin $invocation.completeRouteGate 'PASS_O3F15L3_SIGNED_AND_PATH_GATED' $project
$preactionGate = Require-Pin $invocation.preactionGate 'PASS_ARGOS_ZERO_RECURRENCE_PREACTION' $project
$priorClosure = Require-Pin $invocation.priorTerminalClosureGate 'FAIL_O3F15L2_SIGNED_RUNNER_PREFLIGHT_DIAGNOSTIC_NOT_PRESERVED' $project
Require ([string]$signGate.requestId -ceq $requestId -and [string]$rehearsalGate.requestId -ceq $requestId -and [string]$routeGate.requestId -ceq $requestId) 'O3F15L3 request identity differs across publication gates.'
Require ([string]$signGate.packageZipSha256 -ceq [string]$invocation.requestZipSha256 -and [string]$rehearsalGate.packageZipSha256 -ceq [string]$invocation.requestZipSha256 -and [string]$routeGate.packageZipSha256 -ceq [string]$invocation.requestZipSha256) 'O3F15L3 request ZIP differs across publication gates.'
Require ([bool]$routeGate.packageZipAndPathGateAdjacent -and [int]$routeGate.reservedSuffixCharacters -eq 32 -and [bool]$routeGate.matchingSignedTerminalResponseRequired -and -not [bool]$routeGate.requestRetryAuthorized) 'O3F15L3 route gate authority changed.'
Require ([string]$priorClosure.requestId -ceq 'REQ_20260903T074847542Z_A0FB32A19F06' -and -not [string]::IsNullOrWhiteSpace([string]$priorClosure.responseId)) 'O3F15L3 prior accepted request lacks terminal closure.'
Require ([bool]$preactionGate.reviewOnly -and -not [bool]$preactionGate.productionRoutingEnabled) 'O3F15L3 publication preaction authority changed.'

$expectedShare = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$drive = Get-PSDrive -Name U -PSProvider FileSystem -ErrorAction Stop
$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='U:'" -ErrorAction Stop
Require ([string]$drive.DisplayRoot -ceq $expectedShare -and [string]$disk.ProviderName -ceq $expectedShare -and [int]$disk.DriveType -eq 4) 'O3F15L3 qualified persistent U: mapping changed.'
$requests = 'U:\ProjectPortalRO\requests'
Require (Test-Path -LiteralPath $requests -PathType Container) 'O3F15L3 portal request root unavailable.'
$pending = New-Object Collections.Generic.List[string]
foreach ($path in [IO.Directory]::EnumerateFiles($requests, '*', [IO.SearchOption]::TopDirectoryOnly)) { $pending.Add($path); if ($pending.Count -ge 2) { break } }
Require ($pending.Count -eq 0) 'O3F15L3 portal request root is not zero-pending.'
$target = Join-Path $requests ($requestId + '.ready.zip')
$upload = $target + '.upload'
$publishGatePath = Join-Path $PSScriptRoot 'O3F15L3_PUBLISH_GATE.json'
foreach ($path in @($target,$upload,$publishGatePath)) { Require (-not (Test-Path -LiteralPath $path)) "O3F15L3 create-new publication path exists: $path" }
$git = Get-Command git.exe -CommandType Application -ErrorAction Stop
$branch = (& $git.Source -C $project branch --show-current).Trim()
$head = (& $git.Source -C $project rev-parse HEAD).Trim()
$origin = (& $git.Source -C $project rev-parse refs/remotes/origin/codex/fiducial-opencv-d-drive).Trim()
$trackedStatus = @(& $git.Source -C $project status --porcelain --untracked-files=no)
$scopedUntracked = @(& $git.Source -C $project ls-files --others --exclude-standard -- 'work/OPENCV_EDGE_NOTCH_O3F15L3')
$trackedRequired = @($invocation.requiredTrackedPaths | Where-Object { @(& $git.Source -C $project ls-files --error-unmatch -- ([string]$_) 2>$null).Count -eq 1 })
Require ($branch -ceq 'codex/fiducial-opencv-d-drive' -and $head -ceq $origin -and $trackedStatus.Count -eq 0 -and $scopedUntracked.Count -eq 0 -and $trackedRequired.Count -eq @($invocation.requiredTrackedPaths).Count) 'O3F15L3 publication requires the clean matching branch tip and every L3 artifact tracked.'

if ($Preflight) {
    [ordered]@{ schema='argos_ocv03_o3f15l3_publish_preflight_v1'; state='PASS_O3F15L3_PUBLISH_PREFLIGHT'; requestId=$requestId; requestZipSha256=[string]$invocation.requestZipSha256; requestZipBytes=[int64]$invocation.requestZipBytes; branch=$branch; commit=$head; requiredTrackedPathCount=$trackedRequired.Count; zeroPending=$true; priorAcceptedRequestTerminal=$true; destinationAbsent=$true; publicationCount=0; requestRetryAuthorized=$false; targetExecuted=$false; mutationsPerformed=$false; reviewOnly=$true; productionRoutingEnabled=$false } | ConvertTo-Json -Depth 8
    return
}

[IO.File]::Copy($source, $upload, $false)
Require ((Sha $upload) -ceq [string]$invocation.requestZipSha256) 'O3F15L3 upload hash changed.'
[IO.File]::Move($upload, $target)
Require ((Sha $target) -ceq [string]$invocation.requestZipSha256) 'O3F15L3 published hash changed.'
$gate = [ordered]@{ schema='argos_ocv03_o3f15l3_publish_gate_v1'; createdUtc=[DateTime]::UtcNow.ToString('o'); state='PASS_O3F15L3_PUBLISHED_EXACTLY_ONCE_AWAITING_SIGNED_DIAGNOSTIC_RESPONSE'; requestId=$requestId; publishedPath=$target; publishedSha256=[string]$invocation.requestZipSha256; publishedBytes=[int64](Get-Item -LiteralPath $target).Length; manifestSha256=[string]$signGate.manifestSha256; signatureSha256=[string]$signGate.signatureSha256; branch=$branch; commit=$head; publicationCount=1; automaticRetryAuthorized=$false; matchingSignedTerminalResponseRequired=$true; fullFrontsideHoldCount=184; currentPatternedFrontHoldCount=12; exactStage='PREFLIGHT'; selfTestAuthorized=$false; gateAuthorized=$false; runAuthorized=$false; imageReadsAuthorized=$false; resultRootCreationAuthorized=$false; reviewOnly=$true; trainingEligible=$false; xmlEligible=$false; productionEligible=$false; productionRoutingEnabled=$false }
Write-NewJson $publishGatePath $gate
$gate | ConvertTo-Json -Depth 10

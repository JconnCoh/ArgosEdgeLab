#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight, [switch]$Publish)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Publish)) { throw 'Specify exactly one of -Preflight or -Publish.' }

function Require([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-Sha256([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Require-Pin([string]$Path, [string]$Sha256) {
    Require (Test-Path -LiteralPath $Path -PathType Leaf) "R18M publication dependency absent: $Path"
    Require ((Get-Sha256 $Path) -eq $Sha256) "R18M publication dependency changed: $Path"
}
function Write-JsonCreateNew([string]$Path, [object]$Value) {
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes((($Value | ConvertTo-Json -Depth 16) + [Environment]::NewLine))
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes,0,$bytes.Length) } finally { $stream.Dispose() }
}

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$requestId = 'REQ_R18M_20260904A'
$branch = 'codex/opencv-scribe-deciphering'
$sourceZip = Join-Path $PSScriptRoot ('final\' + $requestId + '.ready.zip')
$packageGatePath = Join-Path $PSScriptRoot 'R18M_FINAL_PACKAGE_GATE.json'
$routeGatePath = $sourceZip + '.complete_route_gate.json'
$pathGatePath = $sourceZip + '.path_gate.json'
$authorityPath = Join-Path $PSScriptRoot 'R18M_PUBLICATION_AUTHORITY.json'
$preactionPath = Join-Path $PSScriptRoot 'PREACTION_R18M_FULL_KLARF_PUBLICATION.json'
$historyPath = Join-Path $project 'work\ARGOS_HISTORY_NO_REPEAT_AUDIT_20260820.json'
$preactionTool = Join-Path $project 'utilities\Confirm-ArgosZeroRecurrencePreaction.ps1'
$publishGatePath = Join-Path $PSScriptRoot 'R18M_PUBLISH_GATE.json'
$shareRoot = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$requestRoot = 'U:\ProjectPortalRO\requests'
$readyPath = $requestRoot + '\' + $requestId + '.ready.zip'
$uploadPath = $readyPath + '.upload'
$processedPath = $requestRoot + '\processed\' + $requestId + '.ready.zip'
$zipSha = 'DF7F0301AF72B88DDD620DC4A0F5E9C5380AF46B5ADB1256B93087BA840DFBF6'
$packageGateSha = 'B70F0AA27F39B20DA39020B58DC1C39AF62CA400A8F0A0D459C24DA017605FB1'
$routeGateSha = 'F58336FD6E55D59636BD0B6A0E849EA279996C9812572592B9906F2EC6E1B5A9'
$pathGateSha = '30F0BE23FC01527B4C8C88741D2AEF5E734B187DB0AAC3FB5BBDDA299B7739DE'
$authoritySha = '8F726880D7BB4F4EAB4FF885A020589A708C6F4D8367277D8632539CBD5AEC2F'
$preactionSha = 'CC20CD73E0D995FE31E86EC8B108518B55EC596CAA92479B36D8762CED71D0FA'

Require-Pin $sourceZip $zipSha
Require-Pin $packageGatePath $packageGateSha
Require-Pin $routeGatePath $routeGateSha
Require-Pin $pathGatePath $pathGateSha
Require-Pin $authorityPath $authoritySha
Require-Pin $preactionPath $preactionSha
$preaction = (& $preactionTool -AuditPath $historyPath -ContractPath $preactionPath -ProjectRoot $project -Preflight | Out-String) | ConvertFrom-Json
Require ([string]$preaction.state -eq 'PASS_ARGOS_ZERO_RECURRENCE_PREACTION') 'R18M publication preaction changed.'
$packageGate = Get-Content -Raw -LiteralPath $packageGatePath | ConvertFrom-Json
$routeGate = Get-Content -Raw -LiteralPath $routeGatePath | ConvertFrom-Json
$pathGate = Get-Content -Raw -LiteralPath $pathGatePath | ConvertFrom-Json
$authority = Get-Content -Raw -LiteralPath $authorityPath | ConvertFrom-Json
$sourceBytes = [int64](Get-Item -LiteralPath $sourceZip).Length
Require ([string]$packageGate.state -eq 'PASS_R18M_FINAL_PACKAGE_GATE' -and [string]$packageGate.requestId -eq $requestId -and [string]$packageGate.requestZipSha256 -eq $zipSha -and [int64]$packageGate.requestZipBytes -eq $sourceBytes) 'R18M package gate changed.'
Require ([string]$routeGate.state -eq 'PASS_R18M_COMPLETE_ROUTE_GATE' -and [string]$routeGate.requestId -eq $requestId -and [string]$routeGate.requestZipSha256 -eq $zipSha -and [int]$routeGate.routePathCount -eq 26 -and [bool]$routeGate.deepestPayloadLeafIncludedAtEveryExtractionHop -and [int]$routeGate.maximumEffectiveLength -lt 200 -and [int]$routeGate.pendingRequestCount -eq 0) 'R18M complete route gate changed.'
Require ([string]$pathGate.state -eq 'PASS_PATH_BUDGET' -and [string]$pathGate.requestId -eq $requestId -and [bool]$pathGate.deepestPayloadLeafIncludedAtEveryExtractionHop -and [int]$pathGate.maximumEffectiveLength -lt 200) 'R18M path gate changed.'
Require ([string]$authority.state -eq 'PASS_R18M_PUBLICATION_AUTHORITY' -and [string]$authority.shortRequestId -eq $requestId -and [int]$authority.maximumRequests -eq 1 -and -not [bool]$authority.retryAuthorized) 'R18M publication authority changed.'
Require (-not (Test-Path -LiteralPath $publishGatePath)) 'R18M publication gate already exists; republish refused.'

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($sourceZip)
try {
    $entries = @($archive.Entries)
    Require ($entries.Count -eq 27) 'R18M signed ZIP membership count changed.'
    $manifestEntry = $archive.GetEntry('PORTAL_REQUEST_MANIFEST.json')
    Require ($null -ne $manifestEntry) 'R18M signed manifest entry absent.'
    $reader = New-Object IO.StreamReader($manifestEntry.Open(), (New-Object Text.UTF8Encoding($false,$true)))
    try { $manifest = $reader.ReadToEnd() | ConvertFrom-Json } finally { $reader.Dispose() }
}
finally { $archive.Dispose() }
Require ([string]$manifest.requestId -eq $requestId -and [string]$manifest.targetRole -eq 'JBOD' -and [string]$manifest.jobClass -eq 'MAINTENANCE_PATCH') 'R18M signed manifest identity changed.'
Require (@($manifest.files).Count -eq 25 -and @($manifest.allowedTaskActions).Count -eq 0 -and @($manifest.allowedProcessActions).Count -eq 1) 'R18M signed manifest action cardinality changed.'
Require ([string]$manifest.sourceProcessingContract.proposalRoot -eq 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\identity\proposals') 'R18M signed observed proposal root changed.'
Require ([bool]$manifest.reviewOnly -and -not [bool]$manifest.trainingEligible -and -not [bool]$manifest.xmlEligible -and -not [bool]$manifest.productionEligible -and -not [bool]$manifest.productionRoutingEnabled -and -not [bool]$manifest.sourceProcessingContract.automaticIdentityAuthority -and -not [bool]$manifest.sourceProcessingContract.sourceMutationAllowed) 'R18M signed manifest authority changed.'
Require (@($manifest.changes[0].approvedPredecessorSha256).Count -eq 1 -and [string]$manifest.changes[0].approvedPredecessorSha256[0] -eq [string]$manifest.changes[0].installedSha256) 'R18M signed create-only idempotent hash boundary changed.'
Require ([DateTimeOffset]::UtcNow -lt [DateTimeOffset]::Parse([string]$manifest.expiresUtc)) 'R18M signed request expired; publication refused.'

$currentBranch = (& git -C $project branch --show-current | Out-String).Trim()
$localTip = (& git -C $project rev-parse HEAD | Out-String).Trim()
$remoteTip = (& git -C $project rev-parse ('origin/' + $branch) | Out-String).Trim()
$status = @(& git -C $project status --porcelain)
Require ($currentBranch -eq $branch -and $localTip -eq $remoteTip -and $status.Count -eq 0) 'R18M publish requires clean dedicated branch matching origin.'
$drive = Get-PSDrive -Name U -ErrorAction Stop
$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='U:'"
Require ($drive.DisplayRoot -eq $shareRoot -and [string]$disk.ProviderName -eq $shareRoot) 'R18M persistent U mapping changed.'
Require (Test-Path -LiteralPath $requestRoot -PathType Container) 'R18M portal request root unavailable.'
Require (-not (Test-Path -LiteralPath $uploadPath) -and -not (Test-Path -LiteralPath $readyPath) -and -not (Test-Path -LiteralPath $processedPath)) 'R18M request identity already exists in route.'
$pending = @(Get-ChildItem -LiteralPath $requestRoot -File -ErrorAction Stop | Where-Object { $_.Name -like '*.ready.zip' -or $_.Name -like '*.ready.zip.upload' })
Require ($pending.Count -eq 0) 'Another portal request is pending; R18M publication refused.'
if ($Preflight) {
    [ordered]@{schema='argos_opencv_scribe_r18m_publish_preflight_v1';checkedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R18M_PUBLISH_PREFLIGHT';requestId=$requestId;requestZipBytes=$sourceBytes;requestZipSha256=$zipSha;expiresUtc=[string]$manifest.expiresUtc;queueState='NEW';pendingRequestCount=0;maximumRequestsAuthorized=1;retryAuthorized=$false;branch=$branch;localTip=$localTip;remoteTip=$remoteTip;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 8
    return
}

$sourceStream = [IO.File]::Open($sourceZip,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
$targetStream = New-Object IO.FileStream($uploadPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try { $sourceStream.CopyTo($targetStream); $targetStream.Flush($true) } finally { $targetStream.Dispose(); $sourceStream.Dispose() }
Require ([int64](Get-Item -LiteralPath $uploadPath).Length -eq $sourceBytes -and (Get-Sha256 $uploadPath) -eq $zipSha) 'R18M staged upload verification failed.'
Require (-not (Test-Path -LiteralPath $readyPath)) 'R18M ready path appeared before commit.'
Move-Item -LiteralPath $uploadPath -Destination $readyPath
$gate = [ordered]@{schema='argos_opencv_scribe_r18m_publish_gate_v1';publishedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R18M_EXACT_SIGNED_MAINTENANCE_PUBLISHED_CREATE_NEW';disposition='PENDING_GATE';requestId=$requestId;publishedPath=$readyPath;bytes=$sourceBytes;sha256=$zipSha;packageGateSha256=$packageGateSha;routeGateSha256=$routeGateSha;authoritySha256=$authoritySha;preactionSha256=$preactionSha;branch=$branch;localTip=$localTip;remoteTip=$remoteTip;createNew=$true;overwritePerformed=$false;maximumRequestsAuthorized=1;retryAuthorized=$false;matchingSignedTerminalResponseCollectionOnly=$true;persistentUMapping=$true;persistentUMappingRoot=$shareRoot;persistentUMappingLeftInPlace=$true;persistentUMappingRemoved=$false;taskActions=@();processActions=@('START_ONE_OWNED_BACKGROUND_R18J_SCRIBE_CORPUS_WORKER');sourceMutationPerformed=$false;identityAccepted=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false}
Write-JsonCreateNew -Path $publishGatePath -Value $gate
$gate | ConvertTo-Json -Depth 16

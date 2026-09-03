#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight, [switch]$Publish)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Publish)) { throw 'Specify exactly one of -Preflight or -Publish.' }

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$requestId = 'REQ_20260903T220000000Z_R18G'
$branch = 'codex/opencv-scribe-deciphering'
$sourceZip = Join-Path $PSScriptRoot ('final\' + $requestId + '.ready.zip')
$packageGatePath = Join-Path $PSScriptRoot 'R18G_FINAL_PACKAGE_GATE.json'
$routeGatePath = Join-Path $PSScriptRoot 'R18G_COMPLETE_ROUTE_GATE.json'
$pathSidecar = $sourceZip + '.path_gate.json'
$authorityPath = Join-Path $PSScriptRoot 'R18G_PUBLICATION_AUTHORITY.json'
$preactionPath = Join-Path $PSScriptRoot 'PREACTION_R18G_ONE_TIME_PUBLICATION.json'
$historyPath = Join-Path $project 'work\ARGOS_HISTORY_NO_REPEAT_AUDIT_20260820.json'
$preactionTool = Join-Path $project 'utilities\Confirm-ArgosZeroRecurrencePreaction.ps1'
$publishGatePath = Join-Path $PSScriptRoot 'R18G_PUBLISH_GATE.json'
$shareRoot = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$requestRoot = 'U:\ProjectPortalRO\requests'
$readyPath = $requestRoot + '\' + $requestId + '.ready.zip'
$uploadPath = $readyPath + '.upload'
$processedPath = $requestRoot + '\processed\' + $requestId + '.ready.zip'
$sourceSha256Expected = 'B78FE1E9112FEEEB22FBDA3AA442B81237A207C26F6A62E4E1AAADFD5DA5AEE4'
$packageGateSha256 = 'B36DACA9EBBD44906EC021B48DA67D0C3F4C72436880A52880E8DFA262B19073'
$routeGateSha256 = '5F4E1434B142EED5C85517AEFD11614D0D8380424219BB5B6A9BE219403E2646'
$authoritySha256 = '448C9589C747B006746D0C3E59D6A20630F92F0A65E468D51CB05BC23A8F08AE'
$preactionSha256 = '4E3B727B4D3FF24F4D6F2EBA8D370EA6028D2610636A6C24ADF5DAC58A2E660B'

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-Sha256([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Assert-Pin([string]$Path, [string]$Sha256) {
    Assert-True (Test-Path -LiteralPath $Path -PathType Leaf) "R18G publication dependency is absent: $Path"
    Assert-True ((Get-Sha256 $Path) -eq $Sha256) "R18G publication dependency changed: $Path"
}
function Write-JsonCreateNew([string]$Path, [object]$Value) {
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes((($Value | ConvertTo-Json -Depth 16) + [Environment]::NewLine))
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
}

Assert-Pin $sourceZip $sourceSha256Expected
Assert-Pin $packageGatePath $packageGateSha256
Assert-Pin $routeGatePath $routeGateSha256
Assert-Pin $pathSidecar $routeGateSha256
Assert-Pin $authorityPath $authoritySha256
Assert-Pin $preactionPath $preactionSha256
& $preactionTool -AuditPath $historyPath -ContractPath $preactionPath -ProjectRoot $project -Preflight | Out-Null

$packageGate = Get-Content -LiteralPath $packageGatePath -Raw | ConvertFrom-Json
$routeGate = Get-Content -LiteralPath $routeGatePath -Raw | ConvertFrom-Json
$sidecar = Get-Content -LiteralPath $pathSidecar -Raw | ConvertFrom-Json
$authority = Get-Content -LiteralPath $authorityPath -Raw | ConvertFrom-Json
$sourceSha256 = Get-Sha256 $sourceZip
$sourceBytes = [int64](Get-Item -LiteralPath $sourceZip).Length
Assert-True ([string]$packageGate.state -eq 'PASS_R18G_FINAL_PACKAGE_GATE' -and [string]$routeGate.state -eq 'PASS_R18G_COMPLETE_ROUTE_GATE') 'R18G final gates are not PASS.'
Assert-True ([string]$packageGate.requestId -eq $requestId -and [string]$routeGate.requestId -eq $requestId -and [string]$sidecar.requestId -eq $requestId) 'R18G request identity changed.'
Assert-True ([string]$packageGate.requestZipSha256 -eq $sourceSha256 -and [string]$routeGate.requestZipSha256 -eq $sourceSha256 -and [string]$sidecar.requestZipSha256 -eq $sourceSha256) 'R18G ZIP pin changed.'
Assert-True ([int64]$packageGate.requestZipBytes -eq $sourceBytes -and -not [bool]$packageGate.publicationAuthorized -and [bool]$packageGate.explicitPublishRequired) 'R18G frozen local-package authority record changed.'
Assert-True (-not [bool]$routeGate.publicationAuthorized -and [bool]$routeGate.explicitPublishRequired -and [int]$routeGate.maximumRequestsAfterExplicitPublish -eq 1 -and -not [bool]$routeGate.retryOnFailure) 'R18G frozen route publication bounds changed.'
Assert-True ([string]$authority.state -eq 'OPERATOR_AUTHORIZED_R18G_PUBLISH_ONCE' -and [string]$authority.requestId -eq $requestId -and [string]$authority.requestZipSha256 -eq $sourceSha256 -and [bool]$authority.publicationAuthorized -and [int]$authority.maximumPublications -eq 1 -and -not [bool]$authority.retryAuthorized) 'R18G explicit publication authority is absent or changed.'
Assert-True ([int]$routeGate.maximumFiles -eq 24 -and [int64]$routeGate.maximumBytes -eq 50331648 -and [int]$routeGate.maximumEffectiveLength -lt 200) 'R18G route/path bounds changed.'
Assert-True (-not (Test-Path -LiteralPath $publishGatePath)) 'R18G publication gate already exists; republish refused.'

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($sourceZip)
try {
    $entries = @($archive.Entries)
    Assert-True ($entries.Count -eq 2 -and @($entries.FullName | Sort-Object) -join '|' -eq 'PORTAL_REQUEST_MANIFEST.json|PORTAL_REQUEST_MANIFEST.sig') 'R18G exact signed ZIP membership changed.'
    $manifestEntry = $archive.GetEntry('PORTAL_REQUEST_MANIFEST.json')
    $reader = New-Object IO.StreamReader($manifestEntry.Open(), (New-Object Text.UTF8Encoding($false, $true)))
    try { $manifest = $reader.ReadToEnd() | ConvertFrom-Json } finally { $reader.Dispose() }
} finally { $archive.Dispose() }
Assert-True ([string]$manifest.requestId -eq $requestId -and [string]$manifest.targetRole -eq 'JBOD' -and [string]$manifest.jobClass -eq 'DATA_PULL') 'R18G signed manifest identity changed.'
Assert-True ([DateTimeOffset]::UtcNow -lt [DateTimeOffset]::Parse([string]$manifest.expiresUtc)) 'R18G signed request has expired; publication refused.'

$currentBranch = (& git -C $project branch --show-current | Out-String).Trim()
$localTip = (& git -C $project rev-parse HEAD | Out-String).Trim()
$remoteTip = (& git -C $project rev-parse ('origin/' + $branch) | Out-String).Trim()
$status = @(& git -C $project status --porcelain)
Assert-True ($currentBranch -eq $branch -and $localTip -eq $remoteTip -and $status.Count -eq 0) 'R18G publish requires a clean dedicated branch matching origin.'
$drive = Get-PSDrive -Name U -ErrorAction Stop
$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='U:'"
Assert-True ($drive.DisplayRoot -eq $shareRoot -and [string]$disk.ProviderName -eq $shareRoot) 'Persistent U mapping changed.'
Assert-True (Test-Path -LiteralPath $requestRoot -PathType Container) 'Portal request root unavailable.'
Assert-True (-not (Test-Path -LiteralPath $uploadPath) -and -not (Test-Path -LiteralPath $readyPath) -and -not (Test-Path -LiteralPath $processedPath)) 'R18G request identity already exists in the publication route.'
$pending = @(Get-ChildItem -LiteralPath $requestRoot -File -ErrorAction Stop | Where-Object { $_.Name -like '*.ready.zip' -or $_.Name -like '*.ready.zip.upload' })
Assert-True ($pending.Count -eq 0) 'Another portal request is pending; R18G publication refused.'

if ($Preflight) {
    [ordered]@{schema='argos_r18g_publish_preflight_v1';checkedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R18G_PUBLISH_PREFLIGHT';requestId=$requestId;requestZipBytes=$sourceBytes;requestZipSha256=$sourceSha256;expiresUtc=[string]$manifest.expiresUtc;queueState='NEW';pendingRequestCount=0;maximumRequestsAuthorized=1;retryAuthorized=$false;branch=$branch;localTip=$localTip;remoteTip=$remoteTip;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 8
    return
}

$sourceStream = [IO.File]::Open($sourceZip, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
$targetStream = New-Object IO.FileStream($uploadPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
try { $sourceStream.CopyTo($targetStream); $targetStream.Flush($true) } finally { $targetStream.Dispose(); $sourceStream.Dispose() }
Assert-True ([int64](Get-Item -LiteralPath $uploadPath).Length -eq $sourceBytes -and (Get-Sha256 $uploadPath) -eq $sourceSha256) 'R18G staged upload verification failed.'
Assert-True (-not (Test-Path -LiteralPath $readyPath)) 'R18G ready path appeared before commit.'
Move-Item -LiteralPath $uploadPath -Destination $readyPath
$gate = [ordered]@{schema='argos_r18g_publish_gate_v1';publishedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R18G_EXACT_SIGNED_DATA_PULL_PUBLISHED_CREATE_NEW';disposition='PENDING_GATE';requestId=$requestId;publishedPath=$readyPath;bytes=$sourceBytes;sha256=$sourceSha256;packageGateSha256=$packageGateSha256;routeGateSha256=$routeGateSha256;authoritySha256=$authoritySha256;preactionSha256=$preactionSha256;branch=$branch;localTip=$localTip;remoteTip=$remoteTip;createNew=$true;overwritePerformed=$false;maximumRequestsAuthorized=1;retryAuthorized=$false;matchingSignedTerminalResponseCollectionOnly=$true;persistentUMapping=$true;persistentUMappingRoot=$shareRoot;persistentUMappingLeftInPlace=$true;persistentUMappingRemoved=$false;requestedFileCount=24;imageFilesRequested=16;pixelsDecoded=$false;taskActions=@();processActions=@();sourceMutationPerformed=$false;waferActionPerformed=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false}
Write-JsonCreateNew -Path $publishGatePath -Value $gate
$gate | ConvertTo-Json -Depth 16

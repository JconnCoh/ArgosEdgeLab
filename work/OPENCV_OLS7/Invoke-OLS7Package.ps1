#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateSet('BuildSign', 'Publish')][string]$Action,
    [switch]$Preflight,
    [switch]$Apply
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (([bool]$Preflight) -eq ([bool]$Apply)) { throw 'Specify exactly one of -Preflight or -Apply.' }

function Require([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Sha([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash }
function New-Json([string]$Path, [object]$Value) {
    Require (-not (Test-Path -LiteralPath $Path)) "Create-new JSON exists: $Path"
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 32) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}
function Repo([string]$Root, [string]$Relative) {
    Require (-not [IO.Path]::IsPathRooted($Relative)) "Repository dependency must be relative: $Relative"
    $prefix = [IO.Path]::GetFullPath($Root).TrimEnd('\') + '\'
    $path = [IO.Path]::GetFullPath((Join-Path $prefix $Relative.Replace('/', '\')))
    Require ($path.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) "Repository dependency escapes root: $Relative"
    $path
}
function Pin([string]$Path, [string]$Hash, [string]$Label) {
    Require (Test-Path -LiteralPath $Path -PathType Leaf) "$Label absent: $Path"
    Require ((Sha $Path) -ceq $Hash) "$Label hash changed: $Path"
}
function Require-Preaction([string]$Path, [string]$ExpectedAction, [string]$Project) {
    Require (Test-Path -LiteralPath $Path -PathType Leaf) "Preaction absent: $Path"
    $value = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    Require ([string]$value.schema -ceq 'argos_zero_recurrence_preaction_v2' -and [string]$value.state -ceq 'PASS_PREACTION_CONTRACT') 'Preaction identity changed.'
    Require ([string]$value.actionType -ceq $ExpectedAction) 'Preaction action type changed.'
    foreach ($row in @($value.dependencies)) { Pin (Repo $Project ([string]$row.path)) ([string]$row.sha256) 'Preaction dependency' }
    $value
}
function Read-ZipManifest([string]$Path) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead($Path)
    try {
        $entry = $zip.GetEntry('PORTAL_REQUEST_MANIFEST.json')
        Require ($null -ne $entry -and $entry.Length -ge 2 -and $entry.Length -le 1048576) 'Request manifest ZIP entry absent or oversized.'
        $reader = New-Object IO.StreamReader($entry.Open(), (New-Object Text.UTF8Encoding($false, $true)), $true)
        try { $reader.ReadToEnd() | ConvertFrom-Json } finally { $reader.Dispose() }
    } finally { $zip.Dispose() }
}
function Pending([string]$Root) { @((Get-ChildItem -LiteralPath $Root -File -ErrorAction Stop) | Where-Object { $_.Name -cmatch '\.ready\.zip(?:\.upload)?$' }) }
function Verify-U([string]$Share) {
    $ps = Get-PSDrive -Name U -PSProvider FileSystem -ErrorAction Stop
    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='U:'" -ErrorAction Stop
    Require ([string]$ps.DisplayRoot -ceq $Share) 'Persistent U: DisplayRoot changed.'
    Require ([string]$disk.ProviderName -ceq $Share -and [int]$disk.DriveType -eq 4) 'Persistent U: provider identity changed.'
}

Require ([string]$PSVersionTable.PSEdition -ceq 'Desktop' -and [int]$PSVersionTable.PSVersion.Major -eq 5 -and [int]$PSVersionTable.PSVersion.Minor -eq 1) 'OLS7 package driver requires Windows PowerShell 5.1.'
$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$contractPath = Join-Path $PSScriptRoot 'OLS7_BUILD_CONTRACT.json'
Require (Test-Path -LiteralPath $contractPath -PathType Leaf) 'OLS7 build contract is absent.'
$contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
Require ([string]$contract.schema -ceq 'argos_ols7_build_contract_v1' -and [string]$contract.state -ceq 'FROZEN_FOR_BUILD_SIGN_PUBLISH') 'OLS7 build contract identity changed.'
foreach ($row in @($contract.dependencies)) { Pin (Repo $project ([string]$row.path)) ([string]$row.sha256) 'Build dependency' }

Push-Location $project
try {
    $branch = [string](& git branch --show-current); Require ($LASTEXITCODE -eq 0) 'Cannot read branch.'
    $head = [string](& git rev-parse HEAD); Require ($LASTEXITCODE -eq 0) 'Cannot read HEAD.'
    $origin = [string](& git rev-parse origin/codex/fiducial-opencv-d-drive); Require ($LASTEXITCODE -eq 0) 'Cannot read origin tip.'
} finally { Pop-Location }
Require ($branch.Trim() -ceq 'codex/fiducial-opencv-d-drive' -and $head.Trim() -ceq [string]$contract.gitTip -and $origin.Trim() -ceq [string]$contract.gitTip) 'Branch, HEAD, or origin tip changed.'

$definitionPath = Repo $project 'work/OPENCV_OLS7/MAINTENANCE_DEFINITION.json'
$endpointPath = Repo $project 'work/OPENCV_OLS7/Invoke-OLS7ThreeLotInventory.ps1'
$targetsPath = Repo $project 'work/OPENCV_OLS7/OLS7_TARGETS.json'
$providerPath = Repo $project 'work/OPENCV_OLS4/Invoke-OCV00DeepestAliasInventory.ps1'
$definition = Get-Content -LiteralPath $definitionPath -Raw | ConvertFrom-Json
Require ([string]$definition.state -ceq 'FROZEN_FOR_SIGNING' -and [string]$definition.targetRole -ceq 'JBOD' -and [string]$definition.jobClass -ceq 'MAINTENANCE_PATCH') 'OLS7 definition identity changed.'
Require ([string]$definition.entryPoint -ceq 'payload/Invoke-OLS7ThreeLotInventory.ps1' -and @($definition.changes).Count -eq 1 -and @($definition.entryPointOutputs).Count -eq 1) 'OLS7 entry/output contract changed.'
Require (@($definition.allowedTaskActions).Count -eq 0 -and @($definition.allowedProcessActions).Count -eq 0 -and -not [bool]$definition.requestRetryAuthorized) 'OLS7 action authority widened.'
Require (-not [bool]$definition.metadataReadContract.fileContentReadAllowed -and -not [bool]$definition.metadataReadContract.imageBytesReadAllowed -and -not [bool]$definition.metadataReadContract.sourceHashingAllowed -and -not [bool]$definition.metadataReadContract.taskOrProcessActionAllowed) 'OLS7 metadata-only contract widened.'

$identityPath = Repo $project 'work/PROJECT_PORTAL_REVIEW_ONLY/state/LAPTOP_SIGNING_IDENTITY.json'
$certificatePath = Repo $project 'work/PROJECT_PORTAL_REVIEW_ONLY/enrollment/ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$packageTester = Repo $project 'work/PROJECT_PORTAL_REVIEW_ONLY/scripts/Test-SignedPortalPackage.ps1'
$pathTool = Repo $project 'utilities/Confirm-ArgosPathBudget.ps1'
$stageRoot = Join-Path $PSScriptRoot 'signed_stage'
$finalRoot = Join-Path $PSScriptRoot 'final_ols7'
$packageGatePath = Join-Path $PSScriptRoot 'OLS7_FINAL_PACKAGE_GATE.json'
$routeGatePath = Join-Path $finalRoot 'OLS7_PREPUBLICATION_PATH_GATE.json'
$buildPreaction = Join-Path $PSScriptRoot 'PREACTION_OLS7_BUILD_SIGN.json'
$publishPreaction = Join-Path $PSScriptRoot 'PREACTION_OLS7_PUBLISH.json'
$rehearsalGatePath = Join-Path $PSScriptRoot 'OLS7_EXACT_PACKAGED_REHEARSAL_GATE.json'
$publishAttemptPath = Join-Path $PSScriptRoot 'OLS7_PUBLISH_ATTEMPT.json'
$publishGatePath = Join-Path $PSScriptRoot 'OLS7_PUBLISH_GATE.json'

function Get-BuildPlan {
    [void](Require-Preaction $buildPreaction 'LOCAL_WINDOWS_POWERSHELL51_OLS7_BUILD_SIGN_AND_ROUTE' $project)
    foreach ($path in @($stageRoot, $finalRoot, $packageGatePath)) { Require (-not (Test-Path -LiteralPath $path)) "OLS7 build target exists: $path" }
    $placeholder = 'REQ_20260911T120000111Z_0123456789AB'
    $planned = @($stageRoot, (Join-Path $stageRoot ($placeholder + '.ready\payload\Invoke-OLS7ThreeLotInventory.ps1')), (Join-Path $finalRoot ($placeholder + '.ready.zip')), $routeGatePath, $packageGatePath)
    $pathCheck = & $pathTool -CandidatePath $planned -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
    Require ([string]$pathCheck.state -ceq 'PASS_PATH_BUDGET') 'OLS7 local package path budget failed.'
    $identity = Get-Content -LiteralPath $identityPath -Raw | ConvertFrom-Json
    $thumb = ([string]$identity.thumbprint).Replace(' ', '').ToUpperInvariant()
    $cert = Get-Item -LiteralPath ("Cert:\CurrentUser\My\$thumb") -ErrorAction Stop
    Require ([bool]$cert.HasPrivateKey) 'OLS7 signer private key is unavailable.'
    [pscustomobject]@{ PathCheck = $pathCheck; Thumb = $thumb; Certificate = $cert }
}

function Get-PublishPlan {
    $publishContract = Require-Preaction $publishPreaction 'PROJECT_PORTAL_OLS7_EXACTLY_ONCE_PUBLISH' $project
    $packageDependency = @($publishContract.dependencies | Where-Object { [string]$_.path -ceq 'work/OPENCV_OLS7/OLS7_FINAL_PACKAGE_GATE.json' })
    Require ($packageDependency.Count -eq 1) 'Publish preaction package-gate dependency cardinality changed.'
    Pin $packageGatePath ([string]$packageDependency[0].sha256) 'Package gate'
    $packageGate = Get-Content -LiteralPath $packageGatePath -Raw | ConvertFrom-Json
    Require ([string]$packageGate.state -ceq 'PASS_OLS7_SIGNED_PACKAGE_AND_COMPLETE_ROUTE' -and [int]$packageGate.payloadFileCount -eq 3) 'OLS7 package gate changed.'
    Pin ([string]$packageGate.routeGatePath) ([string]$packageGate.routeGateSha256) 'Route gate'
    $rehearsalDependency = @($publishContract.dependencies | Where-Object { [string]$_.path -ceq 'work/OPENCV_OLS7/OLS7_EXACT_PACKAGED_REHEARSAL_GATE.json' })
    Require ($rehearsalDependency.Count -eq 1) 'Publish preaction rehearsal-gate dependency cardinality changed.'
    Pin $rehearsalGatePath ([string]$rehearsalDependency[0].sha256) 'Packaged rehearsal gate'
    $source = [IO.Path]::GetFullPath([string]$packageGate.sourceZip)
    Pin $source ([string]$packageGate.sourceZipSha256) 'Source ZIP'
    Require ((Get-Item -LiteralPath $source).Length -eq [int64]$packageGate.sourceZipBytes) 'OLS7 source ZIP bytes changed.'
    $manifest = Read-ZipManifest $source
    $requestId = [string]$packageGate.requestId
    Require ([string]$manifest.requestId -ceq $requestId -and [string]$manifest.targetRole -ceq 'JBOD' -and [string]$manifest.jobClass -ceq 'MAINTENANCE_PATCH' -and @($manifest.files).Count -eq 3) 'OLS7 ZIP request identity changed.'
    Require ([bool]$manifest.reviewOnly -and -not [bool]$manifest.trainingEligible -and -not [bool]$manifest.xmlEligible -and -not [bool]$manifest.productionEligible -and -not [bool]$manifest.productionRoutingEnabled -and -not [bool]$manifest.requestRetryAuthorized) 'OLS7 ZIP authority widened.'
    $share = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
    Verify-U $share
    $requestRoot = 'U:\ProjectPortalRO\requests'
    Require (Test-Path -LiteralPath $requestRoot -PathType Container) 'Project Portal request root unavailable.'
    $readyShare = Join-Path $requestRoot ($requestId + '.ready.zip')
    $uploadShare = $readyShare + '.upload'
    Require (-not (Test-Path -LiteralPath $publishAttemptPath) -and -not (Test-Path -LiteralPath $publishGatePath)) 'OLS7 publication attempt already consumed.'
    $pending = @(Pending $requestRoot)
    Require ($pending.Count -eq 0) ('OLS7 publication blocked by pending request: ' + (($pending | ForEach-Object { $_.Name }) -join ', '))
    Require (-not (Test-Path -LiteralPath $readyShare) -and -not (Test-Path -LiteralPath $uploadShare)) 'OLS7 exact request path already exists.'
    [pscustomobject]@{ PackageGate = $packageGate; Source = $source; Manifest = $manifest; RequestId = $requestId; Share = $share; RequestRoot = $requestRoot; ReadyShare = $readyShare; UploadShare = $uploadShare }
}

if ($Preflight) {
    if ($Action -ceq 'BuildSign') {
        $plan = Get-BuildPlan
        [ordered]@{ schema = 'argos_ols7_build_preflight_v1'; state = 'PASS_OLS7_BUILD_SIGN_ROUTE_PREFLIGHT'; gitTip = $head.Trim(); payloadFileCount = 3; pathState = [string]$plan.PathCheck.state; mutationsPerformed = $false; targetExecuted = $false; reviewOnly = $true; productionRoutingEnabled = $false } | ConvertTo-Json -Depth 6
    }
    else {
        $plan = Get-PublishPlan
        [ordered]@{ schema = 'argos_ols7_publish_preflight_v1'; state = 'PASS_OLS7_EXACTLY_ONCE_PUBLICATION_PREFLIGHT'; requestId = [string]$plan.RequestId; sourceZipSha256 = [string]$plan.PackageGate.sourceZipSha256; sourceZipBytes = [int64]$plan.PackageGate.sourceZipBytes; persistentUMappingVerified = $true; pendingRequestCount = 0; publicationCountMaximum = 1; requestRetryAuthorized = $false; mutationsPerformed = $false; reviewOnly = $true; productionRoutingEnabled = $false } | ConvertTo-Json -Depth 6
    }
    return
}

if ($Action -ceq 'BuildSign') {
    $buildPlan = Get-BuildPlan
    $thumb = [string]$buildPlan.Thumb
    $cert = $buildPlan.Certificate
    [void](New-Item -ItemType Directory -Path $stageRoot)
    [void](New-Item -ItemType Directory -Path $finalRoot)
    $created = [DateTimeOffset]::UtcNow
    $requestId = 'REQ_' + $created.ToString('yyyyMMddTHHmmssfffZ') + '_' + ([Guid]::NewGuid().ToString('N').Substring(0, 12).ToUpperInvariant())
    $partial = Join-Path $stageRoot ($requestId + '.partial')
    $ready = Join-Path $stageRoot ($requestId + '.ready')
    [void](New-Item -ItemType Directory -Path (Join-Path $partial 'payload') -Force)
    $sources = @(
        [pscustomobject]@{ source = $endpointPath; relative = 'payload/Invoke-OLS7ThreeLotInventory.ps1' },
        [pscustomobject]@{ source = $providerPath; relative = 'payload/OCV03_MetadataProviderV1.ps1' },
        [pscustomobject]@{ source = $targetsPath; relative = 'payload/OLS7_TARGETS.json' }
    )
    foreach ($source in $sources) { [IO.File]::Copy([string]$source.source, (Join-Path $partial ([string]$source.relative).Replace('/', '\')), $false) }
    $files = @($sources | ForEach-Object { $item = Get-Item -LiteralPath $_.source; [ordered]@{ path = $_.relative; bytes = [int64]$item.Length; sha256 = Sha $item.FullName } })
    $manifest = [ordered]@{
        schema = 'argos_project_portal_request_manifest_v1'; requestId = $requestId; createdUtc = $created.ToString('o'); expiresUtc = $created.AddHours(24).ToString('o')
        targetRole = 'JBOD'; jobClass = 'MAINTENANCE_PATCH'; handler = ''; maxResultBytes = [int64]$definition.maxResultBytes
        reviewOnly = $true; trainingEligible = $false; xmlEligible = $false; productionEligible = $false; productionRoutingEnabled = $false; credentialsIncluded = $false
        signerThumbprint = $thumb; signatureAlgorithm = 'RSA-SHA256-PKCS1'; files = $files; entryPoint = [string]$definition.entryPoint
        changes = @($definition.changes); entryPointMutations = @($definition.entryPointMutations); entryPointOutputs = @($definition.entryPointOutputs)
        metadataReadContract = $definition.metadataReadContract; allowedTaskActions = @(); allowedProcessActions = @(); rehearsal = $definition.rehearsal; requestRetryAuthorized = $false
    }
    $manifestBytes = (New-Object Text.UTF8Encoding($false)).GetBytes(($manifest | ConvertTo-Json -Depth 32))
    [IO.File]::WriteAllBytes((Join-Path $partial 'PORTAL_REQUEST_MANIFEST.json'), $manifestBytes)
    $rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($cert)
    try { $signature = $rsa.SignData($manifestBytes, [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1) } finally { $rsa.Dispose() }
    [IO.File]::WriteAllBytes((Join-Path $partial 'PORTAL_REQUEST_MANIFEST.sig'), $signature)
    Move-Item -LiteralPath $partial -Destination $ready
    & $packageTester -PackagePath $ready -SignerCertificatePath $certificatePath -ExpectedTargetRole JBOD -ExpectedJobClass MAINTENANCE_PATCH | Out-Null
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zipPath = Join-Path $finalRoot ($requestId + '.ready.zip')
    [IO.Compression.ZipFile]::CreateFromDirectory($ready, $zipPath, [IO.Compression.CompressionLevel]::Optimal, $false)
    $verifyRoot = Join-Path $finalRoot ($requestId + '.verified')
    [IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $verifyRoot)
    & $packageTester -PackagePath $verifyRoot -SignerCertificatePath $certificatePath -ExpectedTargetRole JBOD -ExpectedJobClass MAINTENANCE_PATCH | Out-Null
    foreach ($file in $files) { Pin (Join-Path $verifyRoot ([string]$file.path).Replace('/', '\')) ([string]$file.sha256) 'Extracted payload' }
    $template = Get-Content -LiteralPath (Repo $project ([string]$contract.routeTemplatePath)) -Raw | ConvertFrom-Json
    $oldId = [string]$template.requestId
    $oldRepo = [IO.Path]::GetFullPath((Repo $project 'work/OPENCV_EDGE_NOTCH_O3C1'))
    $routeRows = New-Object Collections.Generic.List[string]
    foreach ($row in @($template.rows)) {
        $p = [string]$row.path
        $p = $p.Replace($oldId, $requestId).Replace($oldRepo, $PSScriptRoot).Replace('O3C1', 'OLS7').Replace('o3c1', 'ols7')
        $p = $p.Replace('Invoke-OCV03HotspotMetadataEndpoint.ps1', 'Invoke-OLS7ThreeLotInventory.ps1').Replace('OCV03_O3C1_HOTSPOT_INVENTORY.json', 'OCV03_OLS7_THREE_LOT_INVENTORY.json')
        $routeRows.Add($p)
        if ($p.EndsWith('OCV03_MetadataProviderV1.ps1', [StringComparison]::OrdinalIgnoreCase)) { $routeRows.Add((Join-Path (Split-Path -Parent $p) 'OLS7_TARGETS.json')) }
    }
    $normalized = @($routeRows.ToArray() | ForEach-Object { [IO.Path]::GetFullPath($_) } | Sort-Object -Unique)
    $budget = & $pathTool -CandidatePath $normalized -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
    Require ([string]$budget.state -ceq 'PASS_PATH_BUDGET') 'OLS7 complete route path budget failed.'
    $max = @($budget.candidates | Sort-Object effectiveLength -Descending)[0]
    Require ([int]$max.effectiveLength -lt 200 -and @($budget.candidates | Where-Object { [int]$_.longestComponentLength -gt 80 }).Count -eq 0) 'OLS7 complete route exceeds path limits.'
    $routeGate = [ordered]@{ schema = 'argos_ols7_complete_route_gate_v1'; createdUtc = [DateTime]::UtcNow.ToString('o'); state = 'PASS_OLS7_COMPLETE_ROUTE_PATH_GATE'; requestId = $requestId; manifestSha256 = Sha (Join-Path $ready 'PORTAL_REQUEST_MANIFEST.json'); zipSha256 = Sha $zipPath; endpointWorkerSha256 = [string]$contract.endpointWorkerSha256; installedConfigEvidenceSha256 = [string]$contract.installedConfigEvidenceSha256; queueSafetyGateSha256 = [string]$contract.queueSafetyGateSha256; inheritedCompleteRouteGateSha256 = [string]$contract.inheritedCompleteRouteGateSha256; routeImplementationChanged = $false; routePathCount = @($budget.candidates).Count; maximumEffectiveLength = [int]$max.effectiveLength; maximumComponentLength = (@($budget.candidates | Measure-Object longestComponentLength -Maximum)[0].Maximum); reservedSuffixCharacters = 32; rows = @($budget.candidates); disposition = 'PASS'; published = $false; targetExecuted = $false; reviewOnly = $true; productionRoutingEnabled = $false }
    New-Json $routeGatePath $routeGate
    $packageGate = [ordered]@{ schema = 'argos_ols7_final_package_gate_v1'; createdUtc = [DateTime]::UtcNow.ToString('o'); state = 'PASS_OLS7_SIGNED_PACKAGE_AND_COMPLETE_ROUTE'; requestId = $requestId; packagePath = $ready; verifiedPackagePath = $verifyRoot; sourceZip = $zipPath; sourceZipBytes = [int64](Get-Item $zipPath).Length; sourceZipSha256 = Sha $zipPath; manifestSha256 = Sha (Join-Path $ready 'PORTAL_REQUEST_MANIFEST.json'); signatureSha256 = Sha (Join-Path $ready 'PORTAL_REQUEST_MANIFEST.sig'); payloadFileCount = 3; endpointSha256 = Sha $endpointPath; providerSha256 = Sha $providerPath; targetManifestSha256 = Sha $targetsPath; routeGatePath = $routeGatePath; routeGateSha256 = Sha $routeGatePath; exactZipExtractionPassed = $true; exactZipSignaturePassed = $true; signed = $true; published = $false; targetExecuted = $false; reviewOnly = $true; productionRoutingEnabled = $false }
    New-Json $packageGatePath $packageGate
    $packageGate | ConvertTo-Json -Depth 10
    return
}

$publishPlan = Get-PublishPlan
$packageGate = $publishPlan.PackageGate
$source = [string]$publishPlan.Source
$requestId = [string]$publishPlan.RequestId
$share = [string]$publishPlan.Share
$requestRoot = [string]$publishPlan.RequestRoot
$readyShare = [string]$publishPlan.ReadyShare
$uploadShare = [string]$publishPlan.UploadShare
$attempt = [ordered]@{ schema = 'argos_ols7_publish_attempt_v1'; createdUtc = [DateTime]::UtcNow.ToString('o'); state = 'STARTED_OLS7_SINGLE_PUBLICATION_ATTEMPT'; requestId = $requestId; sourceZipSha256 = [string]$packageGate.sourceZipSha256; attemptCount = 1; committedBeforeExternalWrite = $true; requestRetryAuthorized = $false }
New-Json $publishAttemptPath $attempt
$input = [IO.File]::Open($source, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
$output = $null
try { $output = New-Object IO.FileStream($uploadShare, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None); $input.CopyTo($output, 1048576); $output.Flush() }
finally { if ($null -ne $output) { $output.Dispose() }; $input.Dispose() }
Require ((Get-Item -LiteralPath $uploadShare).Length -eq [int64]$packageGate.sourceZipBytes -and (Sha $uploadShare) -ceq [string]$packageGate.sourceZipSha256) 'OLS7 upload verification failed; retained as no-retry hold.'
Verify-U $share
$transition = @(Pending $requestRoot)
Require ($transition.Count -eq 1 -and $transition[0].FullName.Equals($uploadShare, [StringComparison]::OrdinalIgnoreCase) -and -not (Test-Path -LiteralPath $readyShare)) 'OLS7 queue changed before commit; upload retained as no-retry hold.'
[IO.File]::Move($uploadShare, $readyShare)
$readyObserved = Test-Path -LiteralPath $readyShare -PathType Leaf
if ($readyObserved) { Require ((Get-Item -LiteralPath $readyShare).Length -eq [int64]$packageGate.sourceZipBytes -and (Sha $readyShare) -ceq [string]$packageGate.sourceZipSha256) 'OLS7 published request verification failed; no retry authorized.' }
$gate = [ordered]@{ schema = 'argos_ols7_publish_gate_v1'; createdUtc = [DateTime]::UtcNow.ToString('o'); state = 'PASS_OLS7_PUBLISHED_EXACTLY_ONCE_AWAITING_MATCHING_SIGNED_RESPONSE'; disposition = 'PENDING_GATE'; requestId = $requestId; sourceZip = $source; publishedPath = $readyShare; publishedBytes = [int64]$packageGate.sourceZipBytes; publishedSha256 = [string]$packageGate.sourceZipSha256; publicationCount = 1; createNewUpload = $true; atomicSameDirectoryUploadToReadyRename = $true; readyObservedAfterCommit = $readyObserved; overwritePerformed = $false; automaticRetryAuthorized = $false; mappingCreatedOrRemoved = $false; sourceMutationOrDeletionPerformed = $false; existingTaskOrProcessActionCount = 0; imageBytesRead = $false; providerActivated = $false; holdsAutomaticallyCleared = $false; reviewOnly = $true; trainingEligible = $false; xmlEligible = $false; productionEligible = $false; productionRoutingEnabled = $false }
New-Json $publishGatePath $gate
$gate | ConvertTo-Json -Depth 10

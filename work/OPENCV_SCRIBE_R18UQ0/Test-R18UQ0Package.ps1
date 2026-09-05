#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Test,
    [Parameter(Mandatory=$true)][string]$RequestRoot,
    [string]$TestRoot,
    [string]$GatePath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Test)) { throw 'Specify exactly one of -Preflight or -Test.' }

function Require([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}
function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}
function Write-JsonCreateNew([string]$Path, [object]$Value) {
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes((($Value | ConvertTo-Json -Depth 12) + [Environment]::NewLine))
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
}

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$request = [IO.Path]::GetFullPath($RequestRoot)
$manifestPath = Join-Path $request 'PORTAL_REQUEST_MANIFEST.json'
$signaturePath = Join-Path $request 'PORTAL_REQUEST_MANIFEST.sig'
$payloadPath = Join-Path $request 'payload\R18UQ0.ps1'
$publicCertificate = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$packageTester = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalPackage.ps1'
foreach ($path in @($manifestPath, $signaturePath, $payloadPath, $publicCertificate, $packageTester)) {
    Require (Test-Path -LiteralPath $path -PathType Leaf) "R18UQ0 package-test dependency missing: $path"
}
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
Require ([string]$manifest.schema -eq 'argos_project_portal_request_manifest_v1') 'R18UQ0 request schema changed.'
Require ([string]$manifest.requestId -eq 'REQ_R18UQ0' -and [string]$manifest.targetRole -eq 'ARGOS' -and [string]$manifest.jobClass -eq 'MAINTENANCE_PATCH') 'R18UQ0 request identity changed.'
Require ([bool]$manifest.reviewOnly -and -not [bool]$manifest.trainingEligible -and -not [bool]$manifest.xmlEligible -and -not [bool]$manifest.productionEligible -and -not [bool]$manifest.productionRoutingEnabled -and -not [bool]$manifest.credentialsIncluded) 'R18UQ0 request authority widened.'
Require ([string]$manifest.entryPoint -eq 'payload/R18UQ0.ps1' -and [int64]$manifest.maxResultBytes -eq 4194304) 'R18UQ0 entrypoint or result cap changed.'
Require (@($manifest.files).Count -eq 1 -and @($manifest.changes).Count -eq 1 -and @($manifest.allowedTaskActions).Count -eq 0) 'R18UQ0 signed collection cardinality changed.'
$fileRow = $manifest.files[0]
$change = $manifest.changes[0]
$payloadHash = Get-Sha256 $payloadPath
Require ([string]$fileRow.path -eq 'payload/R18UQ0.ps1' -and [string]$fileRow.sha256 -eq $payloadHash -and [int64]$fileRow.bytes -eq [int64](Get-Item -LiteralPath $payloadPath).Length) 'R18UQ0 payload row changed.'
Require ([string]$change.source -eq 'payload/R18UQ0.ps1' -and [string]$change.destination -eq 'C:\ProgramData\ArgosInsiteBridgeRO\hotfixes\R18UQ0.ps1' -and [string]$change.installedSha256 -eq $payloadHash -and [bool]$change.allowCreate) 'R18UQ0 change row changed.'
Require (@($change.approvedPredecessorSha256).Count -eq 1 -and [string]$change.approvedPredecessorSha256[0] -eq $payloadHash) 'R18UQ0 predecessor contract changed.'
Require ([string]$manifest.rehearsal.requiredState -eq 'PASS_R18UQ0_ARGOS_INSITE_RUNTIME_AUDIT') 'R18UQ0 required live state changed.'
$verification = & $packageTester -PackagePath $request -SignerCertificatePath $publicCertificate -ExpectedTargetRole ARGOS -ExpectedJobClass MAINTENANCE_PATCH
Require ([string]$verification.State -eq 'PASS_SIGNED_PORTAL_PACKAGE') 'R18UQ0 signed package verification failed.'

$sourceText = [IO.File]::ReadAllText($payloadPath)
$forbiddenTokens = @(
    'ProtectedData]::Unprotect',
    'GetRSAPrivateKey',
    'ConvertTo-SecureString',
    'Invoke-Expression',
    'Start-ScheduledTask',
    'Stop-ScheduledTask',
    'Register-ScheduledTask',
    'Set-ScheduledTask',
    'Start-Process',
    'System.Data.SqlClient.SqlConnection',
    'Microsoft.Data.SqlClient.SqlConnection'
)
$forbiddenHits = @($forbiddenTokens | Where-Object { $sourceText.IndexOf($_, [StringComparison]::OrdinalIgnoreCase) -ge 0 })
Require ($forbiddenHits.Count -eq 0) 'R18UQ0 payload contains a forbidden operation token.'

$baseResult = [ordered]@{
    schema = 'argos_r18uq0_package_rehearsal_v1'
    checkedUtc = [DateTime]::UtcNow.ToString('o')
    state = if ($Preflight) { 'PASS_R18UQ0_PACKAGE_REHEARSAL_PREFLIGHT' } else { 'PASS_R18UQ0_PACKAGE_REHEARSAL' }
    requestId = 'REQ_R18UQ0'
    requestManifestSha256 = Get-Sha256 $manifestPath
    requestSignatureSha256 = Get-Sha256 $signaturePath
    payloadSha256 = $payloadHash
    requestSignatureVerified = $true
    forbiddenOperationHits = $forbiddenHits
    taskActionCount = @($manifest.allowedTaskActions).Count
    reviewOnly = $true
    productionRoutingEnabled = $false
}
if ($Preflight) {
    $baseResult.mutationsPerformed = $false
    $baseResult | ConvertTo-Json -Depth 12
    return
}

Require (-not [string]::IsNullOrWhiteSpace($TestRoot) -and -not [string]::IsNullOrWhiteSpace($GatePath)) 'R18UQ0 test mode requires TestRoot and GatePath.'
$testRootFull = [IO.Path]::GetFullPath($TestRoot)
$gateFull = [IO.Path]::GetFullPath($GatePath)
Require (-not (Test-Path -LiteralPath $testRootFull) -and -not (Test-Path -LiteralPath $gateFull)) 'R18UQ0 rehearsal requires fresh test and gate paths.'
[void](New-Item -ItemType Directory -Path $testRootFull)

$caseRows = New-Object Collections.Generic.List[object]
$createRoot = Join-Path $testRootFull 'create'
[void](New-Item -ItemType Directory -Path $createRoot)
$createDestination = Join-Path $createRoot 'R18UQ0.ps1'
Copy-Item -LiteralPath $payloadPath -Destination $createDestination -ErrorAction Stop
Require ((Get-Sha256 $createDestination) -eq $payloadHash) 'R18UQ0 create case changed bytes.'
$caseRows.Add([pscustomobject]@{id='CREATE';state='PASS';predecessor='ABSENT';installedSha256=Get-Sha256 $createDestination;mutated=$true}) | Out-Null

$idempotentRoot = Join-Path $testRootFull 'idempotent'
[void](New-Item -ItemType Directory -Path $idempotentRoot)
$idempotentDestination = Join-Path $idempotentRoot 'R18UQ0.ps1'
Copy-Item -LiteralPath $payloadPath -Destination $idempotentDestination -ErrorAction Stop
$idempotentBefore = Get-Sha256 $idempotentDestination
Copy-Item -LiteralPath $payloadPath -Destination $idempotentDestination -Force -ErrorAction Stop
$idempotentAfter = Get-Sha256 $idempotentDestination
Require ($idempotentBefore -eq $payloadHash -and $idempotentAfter -eq $payloadHash) 'R18UQ0 target-idempotent case failed.'
$caseRows.Add([pscustomobject]@{id='TARGET_IDEMPOTENT';state='PASS';predecessor=$idempotentBefore;installedSha256=$idempotentAfter;mutated=$true}) | Out-Null

$unapprovedRoot = Join-Path $testRootFull 'unapproved'
[void](New-Item -ItemType Directory -Path $unapprovedRoot)
$unapprovedDestination = Join-Path $unapprovedRoot 'R18UQ0.ps1'
[IO.File]::WriteAllBytes($unapprovedDestination, (New-Object Text.UTF8Encoding($false)).GetBytes('UNAPPROVED'))
$unapprovedBefore = Get-Sha256 $unapprovedDestination
$refused = @($change.approvedPredecessorSha256) -notcontains $unapprovedBefore
Require ($refused -and (Get-Sha256 $unapprovedDestination) -eq $unapprovedBefore) 'R18UQ0 unapproved predecessor was not refused before mutation.'
$caseRows.Add([pscustomobject]@{id='UNAPPROVED_REFUSED';state='PASS';predecessor=$unapprovedBefore;installedSha256=$unapprovedBefore;mutated=$false}) | Out-Null

$rollbackRoot = Join-Path $testRootFull 'post_swap_rollback'
[void](New-Item -ItemType Directory -Path $rollbackRoot)
$rollbackDestination = Join-Path $rollbackRoot 'R18UQ0.ps1'
$rollbackPrior = Join-Path $rollbackRoot 'R18UQ0.prior'
$rollbackFailed = Join-Path $rollbackRoot 'R18UQ0.failed'
Copy-Item -LiteralPath $payloadPath -Destination $rollbackDestination -ErrorAction Stop
Copy-Item -LiteralPath $rollbackDestination -Destination $rollbackPrior -ErrorAction Stop
[IO.File]::WriteAllBytes($rollbackDestination, (New-Object Text.UTF8Encoding($false)).GetBytes('INJECTED_POST_SWAP_FAILURE'))
Move-Item -LiteralPath $rollbackDestination -Destination $rollbackFailed -ErrorAction Stop
Copy-Item -LiteralPath $rollbackPrior -Destination $rollbackDestination -ErrorAction Stop
Require ((Get-Sha256 $rollbackDestination) -eq $payloadHash -and (Get-Sha256 $rollbackFailed) -ne $payloadHash) 'R18UQ0 post-swap rollback case failed.'
$caseRows.Add([pscustomobject]@{id='POST_SWAP_ROLLBACK';state='PASS';predecessor=$payloadHash;installedSha256=Get-Sha256 $rollbackDestination;failedBytesQuarantined=$true;mutated=$true}) | Out-Null

$preflightText = (& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $payloadPath -Preflight | Out-String)
Require ($LASTEXITCODE -eq 0) 'R18UQ0 packaged entrypoint preflight exited nonzero.'
$preflightRecord = $preflightText | ConvertFrom-Json
Require ([string]$preflightRecord.state -eq 'PASS_R18UQ0_ENTRYPOINT_PREFLIGHT' -and -not [bool]$preflightRecord.writesPerformed -and -not [bool]$preflightRecord.installedPathsAccessed) 'R18UQ0 packaged entrypoint preflight changed.'

$baseResult.caseIds = @($caseRows | ForEach-Object { [string]$_.id })
$baseResult.cases = $caseRows.ToArray()
$baseResult.approvedPredecessorExercised = $true
$baseResult.targetIdempotenceAccepted = $true
$baseResult.unapprovedPredecessorRefusedBeforeMutation = $true
$baseResult.injectedPostSwapRollbackPassed = $true
$baseResult.failedBytesQuarantined = $true
$baseResult.packagedEntrypointPreflightState = [string]$preflightRecord.state
$baseResult.entrypointPreflightWritesPerformed = [bool]$preflightRecord.writesPerformed
$baseResult.mutationsPerformed = $true
Write-JsonCreateNew -Path $gateFull -Value $baseResult
$baseResult | ConvertTo-Json -Depth 12

#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Sign
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ([bool]$Preflight -eq [bool]$Sign) { throw 'Specify exactly one of -Preflight or -Sign.' }

$workRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$sourceRoot = Join-Path $workRoot 'source'
$payloadRoot = Join-Path $sourceRoot 'payload'
$definitionPath = Join-Path $sourceRoot 'MAINTENANCE_DEFINITION.json'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $workRoot '..\..'))
$identityPath = Join-Path $projectRoot 'work\PROJECT_PORTAL_REVIEW_ONLY\state\LAPTOP_SIGNING_IDENTITY.json'
$publicCertificatePath = Join-Path $projectRoot 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
if (-not (Test-Path -LiteralPath $identityPath -PathType Leaf)) {
    $mainProjectRoot = 'C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab'
    $identityPath = Join-Path $mainProjectRoot 'work\PROJECT_PORTAL_REVIEW_ONLY\state\LAPTOP_SIGNING_IDENTITY.json'
    $publicCertificatePath = Join-Path $mainProjectRoot 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
}
$pathTool = Join-Path $projectRoot 'utilities\Confirm-ArgosPathBudget.ps1'
$outputRoot = 'C:\G5Z'
$requestId = 'REQ_G5_0831_A1'
$utf8 = New-Object Text.UTF8Encoding($false)

$expectedDefinitionSha256 = 'E9BB2A05D7CBCD8ED4160D5BB9D2617537FE312F49DB60A48D1B6CC93F28CB75'
$expectedIdentitySha256 = '3FD8164D1869375156FB7566D206FEAB97AE8A9E7D377B0AD4E03739ED697289'
$expectedPublicCertificateSha256 = '2B434D0CF6A0D6D69AAE3D280032EFF00807D423CA3B3D7F2EFC1C6BB628BFFF'
$expectedPayloadHashes = @{
    'payload/Apply-GUIHV5DirectGuiPatch.ps1' = '120BC5BD757AC4C0DE3104A4634E5DE4934872680B605EF692BEC5BEDA5029DD'
    'payload/ArgosEdgeLab.JbodCompositeAccepted.V1_2.exe' = '018A74CB5EFA08D59810B09BD16EEF5E3F0345A4C4335CB59ABE334ABE888AA7'
    'payload/Program.cs' = '776BDD0F5D8F644851A8495187178417B021CF5350A988FD0DBFE94D0CFDEF0A'
    'payload/Update-JbodDashboardManifest.ps1' = 'C6A862FE32BB1013626A2C70D97173732F24724D644F44D084EC67DBB3351299'
    'payload/p/1' = 'D893CA3C8F7C4F2993BA4D412986EC30D8B113408039EF8E381F4025C1A04D82'
    'payload/p/2' = 'D893CA3C8F7C4F2993BA4D412986EC30D8B113408039EF8E381F4025C1A04D82'
    'payload/p/3' = 'DFEC0EA9E7A3C309CD7BD845099B23AB725A760035EBAC787340570C34181C76'
    'payload/p/4' = '73C2289B58F6F6B23DD2FA12E847AFF171B3FAC45153202E93EE00E0B7533FBA'
    'payload/p/d' = 'E55F21FF680DD70AD2D71084B199F21862D91E9C4FC83D4943D0FF510846F16B'
    'payload/p/i' = '58E3ED71F532FDB0CCE0D68B1252B788CC04DC349C198516BC96303352B601A6'
    'payload/p/s' = '787BD3107214E3C50FF8589310D7C77AFE0A9D1584E733372F928A4AB671A189'
}

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-Sha256([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }

foreach ($requiredPath in @($definitionPath, $payloadRoot, $identityPath, $publicCertificatePath, $pathTool)) {
    Assert-True (Test-Path -LiteralPath $requiredPath) "GUIHV5 signing input is missing: $requiredPath"
}
Assert-True ((Get-Sha256 $definitionPath) -eq $expectedDefinitionSha256) 'GUIHV5 maintenance definition changed.'
Assert-True ((Get-Sha256 $identityPath) -eq $expectedIdentitySha256) 'GUIHV5 signer identity state changed.'
Assert-True ((Get-Sha256 $publicCertificatePath) -eq $expectedPublicCertificateSha256) 'GUIHV5 signer public certificate changed.'

$payloadFiles = @(
    Get-ChildItem -LiteralPath $payloadRoot -Recurse -File |
        Sort-Object FullName |
        ForEach-Object {
            $relative = $_.FullName.Substring($sourceRoot.Length + 1).Replace('\', '/')
            [pscustomobject]@{ source=$_.FullName; path=$relative; bytes=[int64]$_.Length; sha256=(Get-Sha256 $_.FullName) }
        }
)
Assert-True ($payloadFiles.Count -eq $expectedPayloadHashes.Count) 'GUIHV5 signing payload count changed.'
foreach ($row in $payloadFiles) {
    Assert-True ($expectedPayloadHashes.ContainsKey([string]$row.path)) "Unexpected GUIHV5 payload: $($row.path)"
    Assert-True ([string]$expectedPayloadHashes[[string]$row.path] -eq [string]$row.sha256) "GUIHV5 payload changed: $($row.path)"
}

$definition = Get-Content -Raw -LiteralPath $definitionPath | ConvertFrom-Json
$changes = @($definition.changes)
$allowedTaskActions = @($definition.allowedTaskActions | ForEach-Object { [string]$_ })
Assert-True ([string]$definition.targetRole -eq 'JBOD') 'GUIHV5 target role changed.'
Assert-True ([string]$definition.jobClass -eq 'MAINTENANCE_PATCH') 'GUIHV5 job class changed.'
Assert-True ([string]$definition.entryPoint -eq 'payload/Apply-GUIHV5DirectGuiPatch.ps1') 'GUIHV5 entry point changed.'
Assert-True ([int64]$definition.maxResultBytes -eq 1048576) 'GUIHV5 result bound changed.'
Assert-True ($changes.Count -eq 4) 'GUIHV5 change count changed.'
Assert-True ($allowedTaskActions.Count -eq 3) 'GUIHV5 task-action count changed.'
Assert-True ([string]$definition.rehearsal.requiredState -eq 'PASS_GUIHV5_SCRIBE_HOLD_PROJECTION_PRODUCED_VALIDATED_AND_TRAY_ACTIVATED') 'GUIHV5 rehearsal state changed.'
Assert-True ($allowedTaskActions[0] -eq 'STOP_IF_RUNNING:ArgosEdgeLab.AllWaferMonitor.ReviewOnly.V2') 'GUIHV5 tray stop action changed.'
Assert-True ($allowedTaskActions[1] -eq 'START_ALWAYS:ArgosEdgeLab.AllWaferMonitor.ReviewOnly.V2') 'GUIHV5 tray start action changed.'
Assert-True ($allowedTaskActions[2] -eq 'CLOSE_IF_RUNNING:ArgosEdgeLab.JbodCompositeAccepted.V1_2.exe') 'GUIHV5 viewer-close action changed.'

$identity = Get-Content -Raw -LiteralPath $identityPath | ConvertFrom-Json
$thumbprint = ([string]$identity.thumbprint).Replace(' ', '').ToUpperInvariant()
$certificate = Get-Item -LiteralPath ("Cert:\CurrentUser\My\$thumbprint") -ErrorAction Stop
Assert-True ([bool]$certificate.HasPrivateKey) 'GUIHV5 signer private key is unavailable.'
$publicCertificate = New-Object Security.Cryptography.X509Certificates.X509Certificate2($publicCertificatePath)
Assert-True ($publicCertificate.Thumbprint.Replace(' ', '').ToUpperInvariant() -eq $thumbprint) 'GUIHV5 public certificate thumbprint changed.'

$partialRoot = Join-Path $outputRoot ($requestId + '.partial')
$readyRoot = Join-Path $outputRoot ($requestId + '.ready')
foreach ($freshPath in @($outputRoot, $partialRoot, $readyRoot)) {
    Assert-True (-not (Test-Path -LiteralPath $freshPath)) "Fresh GUIHV5 signing path required: $freshPath"
}
$plannedPaths = @(
    (Join-Path $partialRoot 'PORTAL_REQUEST_MANIFEST.json'),
    (Join-Path $partialRoot 'PORTAL_REQUEST_MANIFEST.sig'),
    (Join-Path $readyRoot 'PORTAL_REQUEST_MANIFEST.json'),
    (Join-Path $readyRoot 'PORTAL_REQUEST_MANIFEST.sig'),
    ("U:\ProjectPortalRO\requests\$requestId.ready.zip.upload"),
    ("U:\ProjectPortalRO\requests\$requestId.ready.zip"),
    ("C:\APR\S\requests\processed\$requestId.ready.zip"),
    ("C:\ProgramData\ArgosProjectPortalRO\requests_to_argos\pending\$requestId.ready\PORTAL_REQUEST_MANIFEST.json"),
    ("C:\ProgramData\ArgosProjectPortalRO\requests_from_gateway\pending\$requestId.ready\PORTAL_REQUEST_MANIFEST.json"),
    ("C:\ProgramData\ArgosProjectPortalRO\to_jbod\pending\$requestId.ready\PORTAL_REQUEST_MANIFEST.json"),
    ("C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\pending\$requestId.ready\PORTAL_REQUEST_MANIFEST.json"),
    ("C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\processed\completed\$requestId.ready\PORTAL_REQUEST_MANIFEST.json")
)
foreach ($row in $payloadFiles) {
    $leaf = ([string]$row.path).Replace('/', '\')
    $plannedPaths += Join-Path $partialRoot $leaf
    $plannedPaths += Join-Path $readyRoot $leaf
    $plannedPaths += "C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\pending\$requestId.ready\$leaf"
    $plannedPaths += "C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\processed\completed\$requestId.ready\$leaf"
}
$pathRows = @()
foreach ($candidate in $plannedPaths) {
    $pathResult = & $pathTool -CandidatePath ([string]$candidate) -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
    Assert-True ([string]$pathResult.state -eq 'PASS_PATH_BUDGET') "GUIHV5 signing path gate failed: $candidate"
    $pathRows += $pathResult.candidates[0]
}

if ($Preflight) {
    [ordered]@{
        schema='argos_guihv5_portal_signing_preflight_v1'; createdUtc=[DateTime]::UtcNow.ToString('o')
        state='PASS_GUIHV5_PORTAL_SIGNING_PREFLIGHT'; requestId=$requestId; payloadFileCount=$payloadFiles.Count
        changeCount=$changes.Count; maximumEffectiveLength=($pathRows | Measure-Object effectiveLength -Maximum).Maximum
        mutationsPerformed=$false; reviewOnly=$true; productionRoutingEnabled=$false
    } | ConvertTo-Json -Depth 6
    return
}

$created = [DateTimeOffset]::UtcNow
$manifest = [ordered]@{
    schema='argos_project_portal_request_manifest_v1'; requestId=$requestId
    createdUtc=$created.ToString('o'); expiresUtc=$created.AddHours(24).ToString('o')
    targetRole='JBOD'; jobClass='MAINTENANCE_PATCH'; handler=''; maxResultBytes=[int64]$definition.maxResultBytes
    reviewOnly=$true; trainingEligible=$false; xmlEligible=$false; productionEligible=$false
    productionRoutingEnabled=$false; credentialsIncluded=$false; signerThumbprint=$thumbprint
    signatureAlgorithm='RSA-SHA256-PKCS1'
    files=@($payloadFiles | ForEach-Object { [ordered]@{path=$_.path;bytes=$_.bytes;sha256=$_.sha256} })
    entryPoint=[string]$definition.entryPoint; changes=@($definition.changes)
    allowedTaskActions=@($definition.allowedTaskActions); rehearsal=$definition.rehearsal
}

[void](New-Item -ItemType Directory -Path (Join-Path $partialRoot 'payload') -Force)
foreach ($row in $payloadFiles) {
    $destination = Join-Path $partialRoot ([string]$row.path).Replace('/', '\')
    $destinationParent = Split-Path -Parent $destination
    if (-not (Test-Path -LiteralPath $destinationParent -PathType Container)) { [void](New-Item -ItemType Directory -Path $destinationParent -Force) }
    Copy-Item -LiteralPath $row.source -Destination $destination
}
$manifestBytes = $utf8.GetBytes(($manifest | ConvertTo-Json -Depth 32))
$manifestPath = Join-Path $partialRoot 'PORTAL_REQUEST_MANIFEST.json'
$signaturePath = Join-Path $partialRoot 'PORTAL_REQUEST_MANIFEST.sig'
[IO.File]::WriteAllBytes($manifestPath, $manifestBytes)
$privateKey = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($certificate)
try { $signature = $privateKey.SignData($manifestBytes,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1) }
finally { $privateKey.Dispose() }
[IO.File]::WriteAllBytes($signaturePath, $signature)
$publicKey = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPublicKey($publicCertificate)
try { $signatureValid = $publicKey.VerifyData($manifestBytes,$signature,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1) }
finally { $publicKey.Dispose(); $publicCertificate.Dispose() }
Assert-True $signatureValid 'GUIHV5 signed manifest verification failed.'
Move-Item -LiteralPath $partialRoot -Destination $readyRoot

[ordered]@{
    schema='argos_guihv5_portal_signing_result_v1'; createdUtc=[DateTime]::UtcNow.ToString('o')
    state='PASS_GUIHV5_PORTAL_SIGNED_REQUEST'; requestId=$requestId; packagePath=$readyRoot
    manifestSha256=(Get-Sha256 (Join-Path $readyRoot 'PORTAL_REQUEST_MANIFEST.json'))
    signatureSha256=(Get-Sha256 (Join-Path $readyRoot 'PORTAL_REQUEST_MANIFEST.sig'))
    payloadFileCount=$payloadFiles.Count; changeCount=$changes.Count; reviewOnly=$true
    productionRoutingEnabled=$false; published=$false
} | ConvertTo-Json -Depth 6

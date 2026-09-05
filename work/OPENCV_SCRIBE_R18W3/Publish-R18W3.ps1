#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight, [switch]$Publish)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Publish)) { throw 'Specify exactly one of -Preflight or -Publish.' }
if ([string]$PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5 -or $PSVersionTable.PSVersion.Minor -ne 1) { throw 'R18W3 publisher requires Windows PowerShell 5.1 exactly.' }

function Require([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-Sha256([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Require-Pin([string]$Path, [string]$Sha256) {
    Require (Test-Path -LiteralPath $Path -PathType Leaf) "R18W3 publication dependency absent: $Path"
    Require ((Get-Sha256 $Path) -eq $Sha256) "R18W3 publication dependency changed: $Path"
}
function Normalize-Root([string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return '' }
    return $Value.Trim().TrimEnd('\').Replace('/', '\')
}
function Read-ZipEntryBytes([IO.Compression.ZipArchive]$Zip, [string]$Name, [int64]$MaximumBytes) {
    $matches = @($Zip.Entries | Where-Object { [string]::Equals(([string]$_.FullName).Replace('\','/'), $Name, [StringComparison]::OrdinalIgnoreCase) })
    Require ($matches.Count -eq 1 -and [int64]$matches[0].Length -le $MaximumBytes) "Missing, duplicated, or oversized request entry: $Name"
    $input = $matches[0].Open(); $memory = New-Object IO.MemoryStream
    try { $input.CopyTo($memory); return ,([byte[]]$memory.ToArray()) } finally { $memory.Dispose(); $input.Dispose() }
}
function Write-JsonCreateNew([string]$Path, [object]$Value) {
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes((($Value | ConvertTo-Json -Depth 16) + [Environment]::NewLine))
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
}

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$requestId = 'REQ_R18W3'; $branch = 'codex/opencv-scribe-deciphering'; $requiredTip = 'bb5769b2ea70ebabef44e1abc68f55b11118a484'
$zipSha = '41113CE44CFB56D64EC2253D475CDD764EC84D759B5F360BE81D6CD325DCCCD6'
$sourceZip = Join-Path $PSScriptRoot 'final\REQ_R18W3.ready.zip'
$packageGatePath = Join-Path $PSScriptRoot 'R18W3_FINAL_PACKAGE_GATE.json'
$routeGatePath = Join-Path $PSScriptRoot 'R18W3_COMPLETE_ROUTE_GATE.json'
$freezeGatePath = Join-Path $PSScriptRoot 'R18W3_PRESIGNATURE_FREEZE_GATE.json'
$definitionPath = Join-Path $PSScriptRoot 'R18W3_DATA_PULL_DEFINITION.json'
$authorityPath = Join-Path $PSScriptRoot 'R18W3_PUBLICATION_AUTHORITY.json'
$preactionPath = Join-Path $PSScriptRoot 'PREACTION_R18W3_PUBLICATION.json'
$handoffGatePath = Join-Path $project 'work\OPENCV_SCRIBE_R18W2\R18W2_POST_RESPONSE_ROLLOVER_GATE.json'
$priorTerminalPath = Join-Path $project 'work\OPENCV_SCRIBE_R18W2\R18W2_SIGNED_TERMINAL_RESPONSE_GATE.json'
$historyPath = Join-Path $project 'work\ARGOS_HISTORY_NO_REPEAT_AUDIT_20260820.json'
$preactionTool = Join-Path $project 'utilities\Confirm-ArgosZeroRecurrencePreaction.ps1'
$signerCertificatePath = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$publishGatePath = Join-Path $PSScriptRoot 'R18W3_PUBLISH_GATE.json'
$shareRoot = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$requestRoot = 'U:\ProjectPortalRO\requests'; $responseRoot = 'U:\ProjectPortalRO\responses'
$readyPath = $requestRoot + '\' + $requestId + '.ready.zip'; $uploadPath = $readyPath + '.upload'
$processedPath = $requestRoot + '\processed\' + $requestId + '.ready.zip'

Require-Pin $sourceZip $zipSha
Require-Pin $packageGatePath '452558FCFBCDCBC9949D1947A300EE3E67B12DE52CB6C861669B25F55DCCAB40'
Require-Pin $routeGatePath 'EF3601249B470A7B50DEC85F380855BE6444E72731D0D9CF5FB1DA5F24895931'
Require-Pin $freezeGatePath 'C7CBDD0A361771D9DE43E8FDDD048F21CF41BC2C80A92713E01131E0575629B0'
Require-Pin $definitionPath '5D7A8B30462AED9B29CE1C94BB5559305283E5D1E694DF1D22BE9723A0747372'
Require-Pin $handoffGatePath 'E8A81E19CCB55034A786159FC282D3B67957DD5CF401BFC8699F3E2A8A7C3B38'
Require-Pin $priorTerminalPath '05DE952D776A885BBC7BE3A26BB9861092566D0804B76AD3A1DC0B4B96098465'
Require-Pin $authorityPath 'D124F4031DE2359E902ACA0837E29EB83AA97C21F7C94AF57F84815982462D61'
Require-Pin $preactionPath 'B21A2C17E7672458136AC0E3C2E202C14606019654303977C707D62447D30630'
Require-Pin $signerCertificatePath '2B434D0CF6A0D6D69AAE3D280032EFF00807D423CA3B3D7F2EFC1C6BB628BFFF'

$preactionJson = (& $preactionTool -AuditPath $historyPath -ContractPath $preactionPath -ProjectRoot $project -Preflight | Out-String)
Require ([string](($preactionJson | ConvertFrom-Json).state) -eq 'PASS_ARGOS_ZERO_RECURRENCE_PREACTION') 'R18W3 publication preaction changed.'
$packageGate = Get-Content -LiteralPath $packageGatePath -Raw | ConvertFrom-Json
$routeGate = Get-Content -LiteralPath $routeGatePath -Raw | ConvertFrom-Json
$freezeGate = Get-Content -LiteralPath $freezeGatePath -Raw | ConvertFrom-Json
$definition = Get-Content -LiteralPath $definitionPath -Raw | ConvertFrom-Json
$authority = Get-Content -LiteralPath $authorityPath -Raw | ConvertFrom-Json
$handoffGate = Get-Content -LiteralPath $handoffGatePath -Raw | ConvertFrom-Json
$priorTerminal = Get-Content -LiteralPath $priorTerminalPath -Raw | ConvertFrom-Json
Require ([string]$packageGate.state -eq 'PASS_R18W3_FINAL_PACKAGE_GATE_SIGNED_UNPUBLISHED' -and [string]$packageGate.requestId -eq $requestId -and [string]$packageGate.requestZipSha256 -eq $zipSha -and [int]$packageGate.requestedFileCount -eq 24 -and [int]$packageGate.selectedAcquisitionCount -eq 8 -and [int]$packageGate.independentPhysicalLineageCount -eq 8 -and -not [bool]$packageGate.retryAuthorized) 'R18W3 final package gate changed.'
Require ([string]$routeGate.state -eq 'PASS_R18W3_COMPLETE_ROUTE_GATE_SIGNED_UNPUBLISHED' -and [string]$routeGate.requestId -eq $requestId -and [int]$routeGate.routePathCount -eq 60 -and [int]$routeGate.maximumEffectiveLength -lt 200 -and [int]$routeGate.maximumComponentLength -le 80 -and [int]$routeGate.reservedSuffixCharacters -eq 32 -and @($routeGate.routeRows | Where-Object { [string]$_.state -ne 'PASS_PATH_BUDGET' }).Count -eq 0) 'R18W3 complete route gate changed.'
Require ([string]$freezeGate.state -eq 'PASS_R18W3_PRESIGNATURE_FREEZE' -and [string]$freezeGate.requestId -eq $requestId) 'R18W3 freeze gate changed.'
Require ([string]$authority.state -eq 'PASS_R18W3_PUBLICATION_AUTHORITY' -and [string]$authority.operatorAuthority -eq 'PUBLISH for REQ_R18W3' -and [bool]$authority.successorAuditAccepted -and [bool]$authority.r18w2SequencingPrerequisiteSatisfied -and [int]$authority.maximumPublications -eq 1 -and -not [bool]$authority.retryAuthorized) 'R18W3 publication authority changed.'
Require ([string]$handoffGate.state -eq 'PASS_R18W2_POST_RESPONSE_ROLLOVER_GATE' -and [bool]$handoffGate.r18w2.signedTerminalResponseVerified -and [int]$handoffGate.r18w2.crosswalkResolved -eq 2 -and -not [bool]$handoffGate.r18w3.publicationAuthorized) 'Accepted handoff gate changed.'
Require ([string]$priorTerminal.state -eq 'PASS_R18W2_SIGNED_TERMINAL_RESPONSE_CHECKPOINT_GATE' -and [string]$priorTerminal.terminalResponse.requestId -eq 'REQ_R18W2' -and [string]$priorTerminal.terminalResponse.responseId -eq 'R_FADCA24C1D79_20260905191141560_093c0c66' -and [string]$priorTerminal.terminalResponse.state -eq 'PASS_DATA_PULL' -and [bool]$priorTerminal.terminalResponse.signedResponseVerified -and [bool]$priorTerminal.controls.requestPublishedExactlyOnce -and -not [bool]$priorTerminal.controls.requestRetried) 'R18W2 sequencing prerequisite changed.'
Require ([string]$definition.targetRole -eq 'JBOD' -and [string]$definition.jobClass -eq 'DATA_PULL' -and [string]$definition.parameters.approvedRoot -eq 'JBOD_PROCESSOR_REVIEW' -and [int]$definition.parameters.maximumFiles -eq 24 -and [int64]$definition.parameters.maximumBytes -eq 50331648 -and @($definition.parameters.relativePaths).Count -eq 24) 'R18W3 data-pull definition changed.'
Require (-not (Test-Path -LiteralPath $publishGatePath)) 'R18W3 publication gate already exists; republish refused.'

Add-Type -AssemblyName System.IO.Compression; Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead($sourceZip)
try { Require (@($zip.Entries).Count -eq 2) 'R18W3 ZIP membership changed.'; $manifestBytes = Read-ZipEntryBytes $zip 'PORTAL_REQUEST_MANIFEST.json' 1048576; $signatureBytes = Read-ZipEntryBytes $zip 'PORTAL_REQUEST_MANIFEST.sig' 8192 } finally { $zip.Dispose() }
$manifest = (New-Object Text.UTF8Encoding($false,$true)).GetString($manifestBytes) | ConvertFrom-Json
$certificate = New-Object Security.Cryptography.X509Certificates.X509Certificate2($signerCertificatePath)
$rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPublicKey($certificate)
try { $signatureValid = $rsa.VerifyData($manifestBytes,$signatureBytes,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1) } finally { $rsa.Dispose() }
Require ($signatureValid) 'R18W3 request signature verification failed.'
Require ([string]$manifest.requestId -eq $requestId -and [string]$manifest.targetRole -eq 'JBOD' -and [string]$manifest.jobClass -eq 'DATA_PULL' -and @($manifest.files).Count -eq 0) 'R18W3 signed manifest identity changed.'
Require ([DateTimeOffset]::UtcNow -lt [DateTimeOffset]::Parse([string]$manifest.expiresUtc)) 'R18W3 signed request expired; publication refused.'
Require ([bool]$manifest.reviewOnly -and -not [bool]$manifest.trainingEligible -and -not [bool]$manifest.xmlEligible -and -not [bool]$manifest.productionEligible -and -not [bool]$manifest.productionRoutingEnabled -and -not [bool]$manifest.credentialsIncluded) 'R18W3 signed authority widened.'
$expectedPaths = @($definition.parameters.relativePaths | ForEach-Object { [string]$_ })
$manifestPaths = @($manifest.parameters.relativePaths | ForEach-Object { [string]$_ })
Require ([string]$manifest.parameters.approvedRoot -eq 'JBOD_PROCESSOR_REVIEW' -and [int]$manifest.parameters.maximumFiles -eq 24 -and [int64]$manifest.parameters.maximumBytes -eq 50331648 -and $manifestPaths.Count -eq 24 -and @(Compare-Object -ReferenceObject $expectedPaths -DifferenceObject $manifestPaths -SyncWindow 0).Count -eq 0) 'R18W3 signed data-pull scope changed.'

$currentBranch = (& git -C $project branch --show-current | Out-String).Trim(); $localTip = (& git -C $project rev-parse HEAD | Out-String).Trim(); $remoteTip = (& git -C $project rev-parse ('origin/' + $branch) | Out-String).Trim(); $status = @(& git -C $project status --porcelain=v1 --untracked-files=all)
Require ($currentBranch -eq $branch -and $localTip -eq $requiredTip -and $remoteTip -eq $requiredTip) 'R18W3 publish requires the pinned dedicated branch and matching recorded origin.'
$allowedLocal = @('?? work/OPENCV_SCRIBE_R18W3/PREACTION_R18W3_PUBLICATION.json','?? work/OPENCV_SCRIBE_R18W3/Publish-R18W3.ps1','?? work/OPENCV_SCRIBE_R18W3/R18W3_PUBLICATION_AUTHORITY.json','?? work/OPENCV_SCRIBE_R18W3/R18W3_PUBLICATION_CLONE_LITERAL_REMEDIATION.json','?? work/OPENCV_SCRIBE_R18W3/R18W3_PUBLICATION_CLONE_LITERAL_GATE.json','?? work/OPENCV_SCRIBE_R18W3/R18W3_PUBLICATION_TOOLING_GATE.json')
Require (@($status | Where-Object { $_ -notin $allowedLocal }).Count -eq 0) 'R18W3 publish found unrelated worktree changes.'
$drive = Get-PSDrive -Name U -ErrorAction Stop; $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='U:'"
Require ($null -ne $disk -and [int]$disk.DriveType -eq 4 -and (Normalize-Root ([string]$drive.DisplayRoot)).Equals((Normalize-Root $shareRoot),[StringComparison]::OrdinalIgnoreCase) -and (Normalize-Root ([string]$disk.ProviderName)).Equals((Normalize-Root $shareRoot),[StringComparison]::OrdinalIgnoreCase)) 'R18W3 persistent U mapping changed.'
Require (Test-Path -LiteralPath $requestRoot -PathType Container) 'R18W3 request root unavailable.'; Require (Test-Path -LiteralPath $responseRoot -PathType Container) 'R18W3 response root unavailable.'
Require (-not (Test-Path -LiteralPath $uploadPath) -and -not (Test-Path -LiteralPath $readyPath) -and -not (Test-Path -LiteralPath $processedPath)) 'R18W3 request identity already exists in route.'
$pending = @(Get-ChildItem -LiteralPath $requestRoot -File -ErrorAction Stop | Where-Object { $_.Name -like '*.ready.zip' -or $_.Name -like '*.ready.zip.upload' })
Require ($pending.Count -eq 0) 'Another portal request is pending; R18W3 publication refused.'

$sourceBytes = [int64](Get-Item -LiteralPath $sourceZip).Length
$result = [ordered]@{schema='argos_opencv_scribe_r18w3_publish_gate_v1';publishedUtc=[DateTime]::UtcNow.ToString('o');state=$(if($Preflight){'PASS_R18W3_PUBLISH_PREFLIGHT'}else{'PASS_R18W3_EXACT_SIGNED_DATA_PULL_PUBLISHED_CREATE_NEW'});requestId=$requestId;publishedPath=$readyPath;bytes=$sourceBytes;sha256=$zipSha;signatureVerified=$true;expiresUtc=[string]$manifest.expiresUtc;queueState='NEW';pendingRequestCount=0;r18w2SequencingPrerequisiteSatisfied=$true;priorResponseId='R_FADCA24C1D79_20260905191141560_093c0c66';branch=$branch;localTip=$localTip;remoteTip=$remoteTip;createNew=$true;overwritePerformed=$false;maximumPublicationsAuthorized=1;retryAuthorized=$false;matchingSignedTerminalResponseCollectionOnly=$true;expectedResponseSourceRole='JBOD';expectedResponseSignerThumbprint='DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC';persistentUMapping=$true;persistentUMappingRoot=$shareRoot;persistentUMappingLeftInPlace=$true;requestedRelativePaths=$manifestPaths;selectedAcquisitions=8;independentPhysicalLineages=8;maximumFiles=24;maximumBytes=50331648;taskActions=@();processActions=@();imageBytesRead=$false;sourceMutationPerformed=$false;identityAccepted=$false;referenceAdmissionPerformed=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false;mutationsPerformed=$false}
if ($Preflight) { $result | ConvertTo-Json -Depth 16; return }
$sourceStream = [IO.File]::Open($sourceZip,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read); $targetStream = New-Object IO.FileStream($uploadPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try { $sourceStream.CopyTo($targetStream); $targetStream.Flush($true) } finally { $targetStream.Dispose(); $sourceStream.Dispose() }
Require ([int64](Get-Item -LiteralPath $uploadPath).Length -eq $sourceBytes -and (Get-Sha256 $uploadPath) -eq $zipSha) 'R18W3 staged upload verification failed.'
Require (-not (Test-Path -LiteralPath $readyPath)) 'R18W3 ready path appeared before atomic commit.'
Move-Item -LiteralPath $uploadPath -Destination $readyPath; $result.mutationsPerformed = $true
Write-JsonCreateNew $publishGatePath $result
$result | ConvertTo-Json -Depth 16

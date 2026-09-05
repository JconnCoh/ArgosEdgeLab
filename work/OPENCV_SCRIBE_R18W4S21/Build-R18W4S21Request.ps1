#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight, [switch]$Freeze, [switch]$Build)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (@(@($Preflight,$Freeze,$Build) | Where-Object { [bool]$_ }).Count -ne 1) { throw 'Specify exactly one of -Preflight, -Freeze, or -Build.' }

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$requestId = 'REQ_S21_20260905212322_S9RHWN0X00G4K59QB7Q1120VDR'
$branch = 'codex/opencv-scribe-deciphering'
$definitionPath = Join-Path $PSScriptRoot 'R18W4S21_DATA_PULL_DEFINITION.json'
$bindingPath = Join-Path $PSScriptRoot 'R18W4S21_SLOT21_BINDING.json'
$routePinsPath = Join-Path $PSScriptRoot 'R18W4S21_ROUTE_PINS.json'
$preactionPath = Join-Path $PSScriptRoot 'PREACTION_R18W4S21_LOCAL_PACKAGE_PREPARATION.json'
$cloneManifestPath = Join-Path $PSScriptRoot 'R18W4S21_BUILD_CLONE_LITERAL_REMEDIATION.json'
$cloneGatePath = Join-Path $PSScriptRoot 'R18W4S21_BUILD_CLONE_LITERAL_GATE.json'
$harnessGatePath = Join-Path $PSScriptRoot 'R18W4S21_BUILD_HARNESS_GATE.json'
$wrapperGatePath = Join-Path $PSScriptRoot 'R18W4S21_WRAPPER_APPLICABILITY_GATE.json'
$uniquenessScriptPath = Join-Path $PSScriptRoot 'Test-R18W4S21RequestIdUniqueness.ps1'
$uniquenessGatePath = Join-Path $PSScriptRoot 'R18W4S21_REQUEST_ID_UNIQUENESS_GATE.json'
$presignatureGatePath = Join-Path $PSScriptRoot 'R18W4S21_PRESIGNATURE_FREEZE_GATE.json'
$historyPath = Join-Path $project 'work\ARGOS_HISTORY_NO_REPEAT_AUDIT_20260820.json'
$identityPath = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\state\LAPTOP_SIGNING_IDENTITY.json'
$publicCertificatePath = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$packageTester = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalPackage.ps1'
$preactionTool = Join-Path $project 'utilities\Confirm-ArgosZeroRecurrencePreaction.ps1'
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
$stageRoot = 'C:\R18W4S21B'
$verifyRoot = 'C:\R18W4S21V'
$responseExtractRoot = 'C:\R18W4S21R'
$localExtractRoot = 'C:\R18W4S21'
$frozenRoot = Join-Path $PSScriptRoot 'frozen'
$frozenManifestPath = Join-Path $frozenRoot 'PORTAL_REQUEST_MANIFEST.json'
$finalPartial = Join-Path $PSScriptRoot 'final.partial'
$finalRoot = Join-Path $PSScriptRoot 'final'
$finalZip = Join-Path $finalRoot ($requestId + '.ready.zip')
$packageGatePath = Join-Path $PSScriptRoot 'R18W4S21_FINAL_PACKAGE_GATE.json'
$routeGatePath = Join-Path $PSScriptRoot 'R18W4S21_COMPLETE_ROUTE_GATE.json'
$pathSidecar = Join-Path $finalRoot 'R18W4S21_PATH_GATE.json'
$maximumBytes = [int64]50331648
$definitionSha256 = '0FC0E85CB455FA4201BA8DBDEEAC85F553204F7C66867216BBC853B9152F8044'
$bindingSha256 = '11DDD4CCF3B05FA3EC061B9994586117E36ACC3C41C086F0117AD48CF7EE676E'
$routePinsSha256 = 'D1CDD46C70BFF4003E46D35BFC77754F9A9A742E51CA14D5AEAD2377E75B1D5E'
$preactionSha256 = '355ED64AB9778319F8D3076A66ABC01F2DDF99375C524CDA17DD1EFB0C1712DE'
$cloneManifestSha256 = 'F7D8ABCDA9C3E682450E240F8CD85458999CA674C11FC16272A1EBA880D5A0B9'
$uniquenessScriptSha256 = '21DAD58056AA2AAC3D2210885B551D487172DF8CBFFF7C2D117BB599C3EBF588'
$r18gRouteSha256 = '5F4E1434B142EED5C85517AEFD11614D0D8380424219BB5B6A9BE219403E2646'
$r18w3RouteSha256 = 'EF3601249B470A7B50DEC85F380855BE6444E72731D0D9CF5FB1DA5F24895931'
$inheritedRouteSha256 = 'E0EAE7BBECDE766E6E78D86074A098465F3117B737146DDF4FF32D1D4953ED2C'
$queueSafetySha256 = '170015C259C3EC8FC0B369F070748A555336F8FB312636819B7F99EBCE85A65D'
$capabilityInventorySha256 = '381D3E9C4F17218DF37D8E8CE029853216E9BEA5A2FBDABC6AEB7861A29DC8A2'
$installedWorkerSha256 = 'CB6700714E20DAC2D3C097095A2800C92ECAAC75F29878F4C86326493B246250'
$shareRoot = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$packageMembers = @('PORTAL_REQUEST_MANIFEST.json','PORTAL_REQUEST_MANIFEST.sig')

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-Sha256([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Get-StringSha256([string]$Value) {
    $bytes=(New-Object Text.UTF8Encoding($false)).GetBytes($Value); $sha=[Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','') } finally { $sha.Dispose() }
}
function Assert-Pin([string]$Path,[string]$Sha256) {
    Assert-True (Test-Path -LiteralPath $Path -PathType Leaf) "R18W4S21 dependency absent: $Path"
    Assert-True ((Get-Sha256 $Path) -eq $Sha256) "R18W4S21 dependency changed: $Path"
}
function Assert-StringArrayExact([object[]]$Actual,[object[]]$Expected,[string]$Message) {
    $a=@($Actual|ForEach-Object{[string]$_}); $e=@($Expected|ForEach-Object{[string]$_}); Assert-True ($a.Count -eq $e.Count) $Message
    for($i=0;$i -lt $e.Count;$i++){Assert-True ($a[$i] -ceq $e[$i]) $Message}
}
function Write-JsonCreateNew([string]$Path,[object]$Value,[int]$Depth=24) {
    $bytes=(New-Object Text.UTF8Encoding($false)).GetBytes((($Value|ConvertTo-Json -Depth $Depth)+[Environment]::NewLine))
    $stream=New-Object IO.FileStream($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try{$stream.Write($bytes,0,$bytes.Length)}finally{$stream.Dispose()}
}

Assert-Pin $definitionPath $definitionSha256
Assert-Pin $bindingPath $bindingSha256
Assert-Pin $routePinsPath $routePinsSha256
Assert-Pin $preactionPath $preactionSha256
Assert-Pin $cloneManifestPath $cloneManifestSha256
Assert-Pin $uniquenessScriptPath $uniquenessScriptSha256
$definition=Get-Content -LiteralPath $definitionPath -Raw|ConvertFrom-Json
$binding=Get-Content -LiteralPath $bindingPath -Raw|ConvertFrom-Json
$routePins=Get-Content -LiteralPath $routePinsPath -Raw|ConvertFrom-Json
$expectedPaths=@([string]$binding.bf.relativePath,[string]$binding.df.relativePath)
$relativePaths=@($definition.parameters.relativePaths|ForEach-Object{[string]$_})
Assert-True ([string]$binding.state -eq 'PASS_R18W4S21_EXACT_CURRENT_SLOT21_BINDING') 'Slot21 binding state changed.'
Assert-True ([string]$binding.physicalIdentity -ceq '62546-481_20260707164232_Slot21' -and [string]$binding.exactTruth -ceq '13HFX135SUE3') 'Slot21 identity/truth changed.'
Assert-True ([string]$binding.bf.sha256 -eq '96046D91BBD6DF81E678224525560BD9C77C0DC09DD89A25992B07F8D1213B93' -and [string]$binding.df.sha256 -eq '8DFD50AE1E0958CE01D7E32E0936978F157C2FECD0CB910BCC27DF9F7CE63CB8') 'Slot21 source pins changed.'
Assert-True (-not [bool]$binding.sourceBytesAvailableLocally -and -not [bool]$binding.evaluatedByR18z -and -not [bool]$binding.identityAccepted -and -not [bool]$binding.referenceAdmissionAuthorized) 'Slot21 authority widened.'
Assert-StringArrayExact $relativePaths $expectedPaths 'DATA_PULL leaves are not exact BF-then-DF Slot21 order.'
Assert-True ([string]$definition.targetRole -eq 'JBOD' -and [string]$definition.jobClass -eq 'DATA_PULL' -and [string]$definition.parameters.approvedRoot -eq 'JBOD_PROCESSOR_REVIEW') 'Route changed.'
Assert-True ($relativePaths.Count -eq 2 -and @($relativePaths|Sort-Object -Unique).Count -eq 2 -and [int]$definition.parameters.maximumFiles -eq 2 -and [int64]$definition.parameters.maximumBytes -eq $maximumBytes -and [int64]$definition.maxResultBytes -eq $maximumBytes) 'Two-file bounds changed.'
Assert-True (@($relativePaths|Where-Object{$_ -like '*/SCRIBE_PROPOSAL.json' -or $_ -like '*OVERLAY*'}).Count -eq 0) 'Proposal, overlay, or incidental leaf entered request.'
Assert-True ([string]$routePins.state -eq 'PASS_R18W4S21_INHERITED_ROUTE_PINS' -and [string]$routePins.requestId -eq $requestId) 'Route pins changed.'
Assert-True (-not [bool]$routePins.authority.publicationAuthorized -and [int]$routePins.authority.maximumPublications -eq 0 -and -not [bool]$routePins.authority.retryAuthorized) 'Publication authority widened.'
Assert-Pin (Join-Path $project ([string]$routePins.route.r18gCompleteRouteGate.path)) $r18gRouteSha256
Assert-Pin (Join-Path $project ([string]$routePins.route.r18w3CompleteRouteGate.path)) $r18w3RouteSha256
Assert-Pin (Join-Path $project ([string]$routePins.route.r15eInheritedRouteGate.path)) $inheritedRouteSha256
Assert-Pin (Join-Path $project ([string]$routePins.route.c1eQueueSafetyGate.path)) $queueSafetySha256
Assert-Pin (Join-Path $project ([string]$routePins.route.c1eReadOnlyCapabilityInventory.path)) $capabilityInventorySha256
Assert-Pin (Join-Path $project ([string]$routePins.route.workerSource.path)) ([string]$routePins.route.workerSource.sha256)
Assert-Pin (Join-Path $project ([string]$routePins.prerequisite.r18zRolloverGate.path)) ([string]$routePins.prerequisite.r18zRolloverGate.sha256)
Assert-Pin (Join-Path $project ([string]$routePins.prerequisite.nextDesign.path)) ([string]$routePins.prerequisite.nextDesign.sha256)
Assert-Pin $identityPath ([string]$routePins.signing.identitySha256)
Assert-Pin $publicCertificatePath ([string]$routePins.signing.publicCertificateSha256)
Assert-Pin $packageTester ([string]$routePins.signing.packageVerifierSha256)
$r18g=Get-Content -LiteralPath (Join-Path $project ([string]$routePins.route.r18gCompleteRouteGate.path)) -Raw|ConvertFrom-Json
$r18w3=Get-Content -LiteralPath (Join-Path $project ([string]$routePins.route.r18w3CompleteRouteGate.path)) -Raw|ConvertFrom-Json
$r15e=Get-Content -LiteralPath (Join-Path $project ([string]$routePins.route.r15eInheritedRouteGate.path)) -Raw|ConvertFrom-Json
$queue=Get-Content -LiteralPath (Join-Path $project ([string]$routePins.route.c1eQueueSafetyGate.path)) -Raw|ConvertFrom-Json
$capability=Get-Content -LiteralPath (Join-Path $project ([string]$routePins.route.c1eReadOnlyCapabilityInventory.path)) -Raw|ConvertFrom-Json
Assert-True ([string]$r18g.state -eq 'PASS_R18G_COMPLETE_ROUTE_GATE' -and [string]$r18w3.state -eq 'PASS_R18W3_COMPLETE_ROUTE_GATE_SIGNED_UNPUBLISHED' -and [string]$r15e.state -eq 'PASS_R15E_COMPLETE_ROUTE_GATE' -and [string]$queue.state -eq 'PASS_JBOD_PORTAL_QUEUE_RECOVERY_V2_1_REHEARSAL') 'Inherited route state changed.'
$dataPullCapability=@($capability.routes|Where-Object{[string]$_.type -eq 'DATA_PULL'})
Assert-True ($dataPullCapability.Count -eq 1 -and @($dataPullCapability[0].capabilities) -contains 'approvedRootExactFiles') 'DATA_PULL exact-file capability absent.'
$preactionResult=(& $preactionTool -AuditPath $historyPath -ContractPath $preactionPath -ProjectRoot $project -Preflight)|ConvertFrom-Json
Assert-True ([string]$preactionResult.state -eq 'PASS_ARGOS_ZERO_RECURRENCE_PREACTION') 'Preaction gate failed.'

$currentBranch=(& git -C $project branch --show-current|Out-String).Trim()
$localTip=(& git -C $project rev-parse HEAD|Out-String).Trim()
$remoteTip=(& git -C $project rev-parse ('refs/remotes/origin/'+$branch)|Out-String).Trim()
$status=@(& git -C $project status --porcelain=v1)
Assert-True ($currentBranch -eq $branch -and $localTip -eq $remoteTip) 'Dedicated branch must match recorded origin before signing preparation.'

$responseId='R_0123456789AB_20260905235959999_a1b2c3d4'; $responseReady=$responseId+'.ready'; $requestReady=$requestId+'.ready'
$plannedMembership=@($packageMembers|Sort-Object); $plannedMembershipSha256=Get-StringSha256 (($plannedMembership -join "`n")+"`n")
$routePaths=New-Object Collections.Generic.List[string]
foreach($member in $packageMembers){
    $routePaths.Add((Join-Path $stageRoot $member)); $routePaths.Add((Join-Path $verifyRoot $member))
    $routePaths.Add(('C:\ProgramData\ArgosProjectPortalRO\requests_to_argos\pending\'+$requestReady+'\'+$member))
    $routePaths.Add(('C:\ProgramData\ArgosProjectPortalRO\requests_from_gateway\pending\'+$requestReady+'\'+$member))
    $routePaths.Add(('C:\ProgramData\ArgosProjectPortalRO\to_jbod\pending\'+$requestReady+'\'+$member))
    $routePaths.Add(('C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\pending\'+$requestReady+'\'+$member))
    $routePaths.Add(('C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\processed\completed\'+$requestReady+'\'+$member))
}
$routePaths.Add((Join-Path $finalPartial ($requestId+'.ready.zip'))); $routePaths.Add((Join-Path $finalPartial 'R18W4S21_PATH_GATE.json'))
$routePaths.Add($finalZip); $routePaths.Add($pathSidecar); $routePaths.Add($packageGatePath); $routePaths.Add($routeGatePath)
$routePaths.Add(('U:\ProjectPortalRO\requests\'+$requestId+'.ready.zip.upload')); $routePaths.Add(('U:\ProjectPortalRO\requests\'+$requestId+'.ready.zip'))
$routePaths.Add(('C:\APR\S\requests\processed\'+$requestId+'.ready.zip'))
$routePaths.Add('C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\state\work\J_0123456789AB_a1b2c3d4\DATA_PULL_PAYLOAD.zip.partial')
$routePaths.Add('C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\state\work\J_0123456789AB_a1b2c3d4\DATA_PULL_PAYLOAD.zip')
$routePaths.Add('C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\state\work\J_0123456789AB_a1b2c3d4\RESULT.json')
$routePaths.Add(('C:\ProgramData\ArgosProjectPortalRO\to_argos\pending\'+$responseId+'.partial\PORTAL_RESPONSE_MANIFEST.json'))
$routePaths.Add(('C:\ProgramData\ArgosProjectPortalRO\to_argos\pending\'+$responseId+'.partial\PORTAL_RESPONSE_MANIFEST.sig'))
$routePaths.Add(('C:\ProgramData\ArgosProjectPortalRO\to_argos\pending\'+$responseId+'.partial\DATA_PULL_PAYLOAD.zip'))
$routePaths.Add(('C:\ProgramData\ArgosProjectPortalRO\to_argos\sent\'+$responseReady+'\DATA_PULL_PAYLOAD.zip'))
$routePaths.Add(('C:\ProgramData\ArgosProjectPortalRO\from_jbod\pending\'+$responseReady+'\PORTAL_RESPONSE_MANIFEST.json'))
$routePaths.Add(('C:\ProgramData\ArgosProjectPortalRO\to_gateway\pending\'+$responseReady+'\PORTAL_RESPONSE_MANIFEST.json'))
$routePaths.Add(('C:\APR\R\pending\'+$responseReady+'\DATA_PULL_PAYLOAD.zip')); $routePaths.Add(('C:\APR\A\'+$responseReady+'\PORTAL_RESPONSE_MANIFEST.json'))
$routePaths.Add(('U:\ProjectPortalRO\responses\'+$responseReady+'.zip'))
$routePaths.Add((Join-Path $responseExtractRoot 'PORTAL_RESPONSE_MANIFEST.json')); $routePaths.Add((Join-Path $responseExtractRoot 'PORTAL_RESPONSE_MANIFEST.sig')); $routePaths.Add((Join-Path $responseExtractRoot 'DATA_PULL_PAYLOAD.zip'))
foreach($relativePath in $relativePaths){$routePaths.Add(($localExtractRoot+'\data\JBOD_PROCESSOR_REVIEW\'+$relativePath.Replace('/','\')))}
$pathGate=(& $pathTool -CandidatePath $routePaths.ToArray() -ReservedSuffixCharacters 32 -AsJson)|ConvertFrom-Json
Assert-True ([string]$pathGate.state -eq 'PASS_PATH_BUDGET') 'Complete route path budget failed.'
$maximumEffective=[int](($pathGate.candidates|Measure-Object effectiveLength -Maximum).Maximum); $maximumComponent=[int](($pathGate.candidates|Measure-Object longestComponentLength -Maximum).Maximum)
Assert-True ($routePaths.Count -eq 40 -and $maximumEffective -lt 200 -and $maximumComponent -le 80) 'Route model changed or requires a shorter namespace.'

$selfHash=Get-Sha256 $PSCommandPath
if($Preflight){
    [ordered]@{schema='argos_r18w4s21_build_preflight_v1';checkedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R18W4S21_BUILD_PREFLIGHT_LOCAL_ONLY';requestId=$requestId;requestedFileCount=2;bfFileCount=1;dfFileCount=1;proposalFileCount=0;overlayFileCount=0;maximumFiles=2;maximumBytes=$maximumBytes;plannedPackageMembership=$plannedMembership;plannedPackageMembershipSha256=$plannedMembershipSha256;routePathCount=$routePaths.Count;finalPartialIncluded=$true;maximumEffectiveLength=$maximumEffective;maximumComponentLength=$maximumComponent;branch=$branch;localTip=$localTip;recordedOriginTip=$remoteTip;worktreeStatusRowCount=$status.Count;publicationAuthorized=$false;retryAuthorized=$false;externalRouteContacted=$false;imageFilesOpened=$false;mutationsPerformed=$false}|ConvertTo-Json -Depth 8
    return
}

foreach($gatePath in @($cloneGatePath,$harnessGatePath,$wrapperGatePath,$uniquenessGatePath)){Assert-True (Test-Path -LiteralPath $gatePath -PathType Leaf) "Prerequisite gate absent: $gatePath"}
$cloneGate=Get-Content -LiteralPath $cloneGatePath -Raw|ConvertFrom-Json; $harnessGate=Get-Content -LiteralPath $harnessGatePath -Raw|ConvertFrom-Json; $wrapperGate=Get-Content -LiteralPath $wrapperGatePath -Raw|ConvertFrom-Json; $uniquenessGate=Get-Content -LiteralPath $uniquenessGatePath -Raw|ConvertFrom-Json
Assert-True ([string]$cloneGate.state -eq 'PASS_ARGOS_CLONE_LITERAL_REMEDIATION' -and [string]$cloneGate.pairs[0].generatedSha256 -eq $selfHash) 'Clone gate stale.'
Assert-True ([string]$harnessGate.state -eq 'PASS_R18W4S21_SOURCE_AND_GENERATED_HARNESS_SAFETY' -and [string]$harnessGate.generatedPowerShellScriptSha256 -eq $selfHash) 'Harness gate stale.'
Assert-True ([string]$wrapperGate.state -eq 'PASS_R18W4S21_WRAPPER_NOT_APPLICABLE' -and -not [bool]$wrapperGate.cmdWrapperCreated) 'Wrapper gate changed.'
Assert-True ([string]$uniquenessGate.state -eq 'PASS_R18W4S21_REQUEST_ID_UNIQUENESS_ZERO_COLLISIONS' -and [int]$uniquenessGate.collisionCount -eq 0 -and [bool]$uniquenessGate.responseArchiveScanned -and [bool]$uniquenessGate.endpointLedgerNamespaceChecked -and [bool]$uniquenessGate.allAccessibleNamespacesScanned) 'Pre-signature collision gate failed.'

if($Freeze){
    Assert-True (-not (Test-Path -LiteralPath $frozenRoot)) 'Frozen manifest root already exists.'
    [void](New-Item -ItemType Directory -Path $frozenRoot)
    $created=[DateTimeOffset]::UtcNow
    $manifest=[ordered]@{schema='argos_project_portal_request_manifest_v1';requestId=$requestId;createdUtc=$created.ToString('o');expiresUtc=$created.AddHours(24).ToString('o');targetRole='JBOD';jobClass='DATA_PULL';handler='';maxResultBytes=$maximumBytes;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false;credentialsIncluded=$false;signerThumbprint=[string]$routePins.signing.signerThumbprint;signatureAlgorithm='RSA-SHA256-PKCS1';files=@();parameters=$definition.parameters}
    $bytes=(New-Object Text.UTF8Encoding($false)).GetBytes(($manifest|ConvertTo-Json -Depth 24))
    [IO.File]::WriteAllBytes($frozenManifestPath,$bytes)
    [ordered]@{schema='argos_r18w4s21_freeze_result_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R18W4S21_EXACT_UNSIGNED_MANIFEST_FROZEN';requestId=$requestId;frozenManifest=$frozenManifestPath;bytes=$bytes.Length;sha256=(Get-Sha256 $frozenManifestPath);builderSha256=$selfHash;uniquenessGateSha256=(Get-Sha256 $uniquenessGatePath);publicationAuthorized=$false;mutationsPerformed=$true}|ConvertTo-Json -Depth 6
    return
}

Assert-True (Test-Path -LiteralPath $presignatureGatePath -PathType Leaf) 'Presignature freeze gate absent.'
$presignatureGate=Get-Content -LiteralPath $presignatureGatePath -Raw|ConvertFrom-Json
Assert-True ([string]$presignatureGate.state -eq 'PASS_R18W4S21_PRESIGNATURE_FREEZE' -and [string]$presignatureGate.requestId -eq $requestId -and [string]$presignatureGate.builderSha256 -eq $selfHash -and [string]$presignatureGate.frozenManifestSha256 -eq (Get-Sha256 $frozenManifestPath) -and [string]$presignatureGate.uniquenessGateSha256 -eq (Get-Sha256 $uniquenessGatePath)) 'Presignature freeze gate stale.'
foreach($path in @($stageRoot,$verifyRoot,$finalPartial,$finalRoot,$packageGatePath,$routeGatePath,$pathSidecar)){Assert-True (-not (Test-Path -LiteralPath $path)) "Fresh output exists: $path"}
$identity=Get-Content -LiteralPath $identityPath -Raw|ConvertFrom-Json; $thumbprint=([string]$identity.thumbprint).Replace(' ','').ToUpperInvariant()
Assert-True ($thumbprint -eq [string]$routePins.signing.signerThumbprint) 'Signer thumbprint changed.'
$certificate=Get-Item -LiteralPath ("Cert:\CurrentUser\My\$thumbprint") -ErrorAction Stop; Assert-True ([bool]$certificate.HasPrivateKey) 'Signer private key unavailable.'
$manifestBytes=[IO.File]::ReadAllBytes($frozenManifestPath); $manifest=$null; $manifestText=(New-Object Text.UTF8Encoding($false,$true)).GetString($manifestBytes); $manifest=$manifestText|ConvertFrom-Json
Assert-True ([string]$manifest.requestId -eq $requestId -and [DateTimeOffset]::UtcNow -lt [DateTimeOffset]::Parse([string]$manifest.expiresUtc)) 'Frozen manifest identity changed or expired.'
[void](New-Item -ItemType Directory -Path $stageRoot); [IO.File]::WriteAllBytes((Join-Path $stageRoot 'PORTAL_REQUEST_MANIFEST.json'),$manifestBytes)
$rsa=[Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($certificate)
try{$signature=$rsa.SignData($manifestBytes,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1)}finally{$rsa.Dispose()}
[IO.File]::WriteAllBytes((Join-Path $stageRoot 'PORTAL_REQUEST_MANIFEST.sig'),$signature)
$folderTest=& $packageTester -PackagePath $stageRoot -SignerCertificatePath $publicCertificatePath -ExpectedTargetRole JBOD -ExpectedJobClass DATA_PULL
Assert-True ([string]$folderTest.State -eq 'PASS_SIGNED_PORTAL_PACKAGE') 'Signed folder validation failed.'
Add-Type -AssemblyName System.IO.Compression.FileSystem; [void](New-Item -ItemType Directory -Path $finalPartial)
$zipPartial=Join-Path $finalPartial ($requestId+'.ready.zip'); [IO.Compression.ZipFile]::CreateFromDirectory($stageRoot,$zipPartial,[IO.Compression.CompressionLevel]::Optimal,$false)
$archive=[IO.Compression.ZipFile]::OpenRead($zipPartial); try{$actualMembership=@($archive.Entries|ForEach-Object{[string]$_.FullName.Replace('\','/')}|Sort-Object)}finally{$archive.Dispose()}
Assert-StringArrayExact $actualMembership $plannedMembership 'Final ZIP membership changed.'; $actualMembershipSha256=Get-StringSha256 (($actualMembership -join "`n")+"`n"); Assert-True ($actualMembershipSha256 -eq $plannedMembershipSha256) 'Membership fingerprint changed.'
[IO.Compression.ZipFile]::ExtractToDirectory($zipPartial,$verifyRoot); $extractTest=& $packageTester -PackagePath $verifyRoot -SignerCertificatePath $publicCertificatePath -ExpectedTargetRole JBOD -ExpectedJobClass DATA_PULL
Assert-True ([string]$extractTest.State -eq 'PASS_SIGNED_PORTAL_PACKAGE' -and @(Get-ChildItem -LiteralPath $verifyRoot -File).Count -eq 2) 'Exact ZIP signature/membership validation failed.'
$zipSha=Get-Sha256 $zipPartial; $zipBytes=[int64](Get-Item -LiteralPath $zipPartial).Length; $manifestSha=Get-Sha256 (Join-Path $verifyRoot 'PORTAL_REQUEST_MANIFEST.json'); $signatureSha=Get-Sha256 (Join-Path $verifyRoot 'PORTAL_REQUEST_MANIFEST.sig')
$routeRows=@($pathGate.candidates|ForEach-Object{[ordered]@{path=[string]$_.path;pathLength=[int]$_.pathLength;effectiveLength=[int]$_.effectiveLength;longestComponentLength=[int]$_.longestComponentLength;state='PASS_PATH_BUDGET'}})
$packageGate=[ordered]@{schema='argos_r18w4s21_final_package_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R18W4S21_FINAL_PACKAGE_GATE_SIGNED_UNPUBLISHED';requestId=$requestId;requestZip='work/OPENCV_SCRIBE_R18W4S21/final/'+$requestId+'.ready.zip';requestZipBytes=$zipBytes;requestZipSha256=$zipSha;requestManifestSha256=$manifestSha;requestSignatureSha256=$signatureSha;packageMembership=$actualMembership;packageMembershipSha256=$actualMembershipSha256;frozenManifestSha256=(Get-Sha256 $frozenManifestPath);definitionSha256=$definitionSha256;bindingSha256=$bindingSha256;routePinsSha256=$routePinsSha256;preactionSha256=$preactionSha256;cloneManifestSha256=$cloneManifestSha256;cloneGateSha256=(Get-Sha256 $cloneGatePath);harnessGateSha256=(Get-Sha256 $harnessGatePath);wrapperApplicabilityGateSha256=(Get-Sha256 $wrapperGatePath);uniquenessScriptSha256=$uniquenessScriptSha256;uniquenessGateSha256=(Get-Sha256 $uniquenessGatePath);presignatureFreezeGateSha256=(Get-Sha256 $presignatureGatePath);builderSha256=$selfHash;exactFinalZipExtractionPassed=$true;exactFinalZipSignaturePassed=$true;exactFinalZipMembershipPassed=$true;requestedFileCount=2;bfFileCount=1;dfFileCount=1;proposalFileCount=0;overlayFileCount=0;maximumFiles=2;maximumBytes=$maximumBytes;publicationAuthorized=$false;maximumPublications=0;retryAuthorized=$false;externalCollisionReadsPerformed=$true;externalPublicationPerformed=$false;imageFilesOpened=$false;sourceMutation=$false;taskProcessOrQueueManagement=$false;identityAccepted=$false;referenceAdmissionPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}
$routeGate=[ordered]@{schema='argos_r18w4s21_complete_route_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R18W4S21_COMPLETE_ROUTE_GATE_SIGNED_UNPUBLISHED';requestId=$requestId;targetRole='JBOD';jobClass='DATA_PULL';approvedRoot='JBOD_PROCESSOR_REVIEW';requestZipSha256=$zipSha;requestManifestSha256=$manifestSha;requestSignatureSha256=$signatureSha;installedEndpointWorkerSha256=$installedWorkerSha256;inheritedR18gRouteGateSha256=$r18gRouteSha256;inheritedR18w3RouteGateSha256=$r18w3RouteSha256;inheritedR15eRouteGateSha256=$inheritedRouteSha256;c1eQueueSafetyGateSha256=$queueSafetySha256;c1eCapabilityInventorySha256=$capabilityInventorySha256;packageMembership=$actualMembership;packageMembershipSha256=$actualMembershipSha256;slot21BindingSha256=$bindingSha256;relativePaths=$relativePaths;requestedFileCount=2;bfFileCount=1;dfFileCount=1;proposalFileCount=0;overlayFileCount=0;maximumFiles=2;maximumBytes=$maximumBytes;maxResultBytes=$maximumBytes;routePathCount=$routeRows.Count;routeRows=$routeRows;finalPartialIncluded=$true;maximumEffectiveLength=$maximumEffective;maximumComponentLength=$maximumComponent;reservedSuffixCharacters=32;exactFinalZipExtractionPassed=$true;exactFinalZipSignaturePassed=$true;exactFinalZipMembershipPassed=$true;deepSourcePathsPreserved=$true;filesystemReturnPathsFlattened=$false;publicationAuthorized=$false;maximumRequests=0;retryOnFailure=$false;matchingSignedTerminalResponseCollectionOnly=$true;externalCollisionReadsPerformed=$true;externalPublicationPerformed=$false;imageFilesOpened=$false;sourceMutation=$false;taskProcessOrQueueManagement=$false;identityAccepted=$false;reviewOnly=$true;productionRoutingEnabled=$false}
Write-JsonCreateNew (Join-Path $finalPartial 'R18W4S21_PATH_GATE.json') $routeGate
[IO.Directory]::Move($finalPartial,$finalRoot); Write-JsonCreateNew $packageGatePath $packageGate; Write-JsonCreateNew $routeGatePath $routeGate
[IO.Directory]::Delete($stageRoot,$true); [IO.Directory]::Delete($verifyRoot,$true)
Assert-True ((Get-Sha256 $finalZip) -eq $zipSha) 'Final ZIP changed after finalization.'
[ordered]@{schema='argos_r18w4s21_build_result_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R18W4S21_EXACT_SIGNED_TWO_FILE_DATA_PULL_LOCAL_ONLY_UNPUBLISHED';requestId=$requestId;requestZip=$finalZip;requestZipBytes=$zipBytes;requestZipSha256=$zipSha;packageGate=$packageGatePath;routeGate=$routeGatePath;requestedFileCount=2;bfFileCount=1;dfFileCount=1;publicationAuthorized=$false;retryAuthorized=$false;externalPublicationPerformed=$false;imageFilesOpened=$false;sourceMutation=$false;taskProcessOrQueueManagement=$false;temporaryRootsRemoved=@($stageRoot,$verifyRoot);reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 8

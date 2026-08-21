[CmdletBinding()]
param([switch]$Preflight,[switch]$Apply)

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if(([bool]$Preflight)-eq([bool]$Apply)){throw 'Specify exactly one of -Preflight or -Apply.'}
$project='C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab'
$root=Join-Path $project 'work\R8'
$requestId='REQ_R8'
$localRoot='C:\R8S'
$publishGatePath=Join-Path $root 'R8_PUBLISH_GATE.json'
$publishGateSha='172411037BB901E5D8428FACE1C9C2BECC525BF18AF107AA7D9AB1947ADE3A54'
$routeGatePath=Join-Path $root 'R8_RESPONSE_ROUTE_GATE.json'
$terminalGatePath=Join-Path $root 'R8_TERMINAL_RESPONSE_GATE.json'
$pathTool=Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
$certPath=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\active\JBOD_ENDPOINT_SIGNER.cer'
$share='\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$requestRoot=Join-Path $share 'ProjectPortalRO\requests'
$responseRoot=Join-Path $share 'ProjectPortalRO\responses'
$shortResponseRoot='U:\ProjectPortalRO\responses'
$utf8=New-Object Text.UTF8Encoding($false,$true)
$utf8NoBom=New-Object Text.UTF8Encoding($false)
function Sha([string]$Path){return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash}
function Bytes-Sha([byte[]]$Bytes){$sha=[Security.Cryptography.SHA256]::Create();try{return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-','')}finally{$sha.Dispose()}}
function Exact-Entry([IO.Compression.ZipArchive]$Archive,[string]$Name){$entries=@($Archive.Entries|Where-Object{[string]$_.FullName-eq$Name});if($entries.Count-ne1){throw "C2R expected one response entry: $Name"};return $entries[0]}
function Read-Entry([IO.Compression.ZipArchiveEntry]$Entry,[int64]$Maximum){if($Entry.Length-gt$Maximum){throw "C2R response entry too large: $($Entry.FullName)"};$stream=$Entry.Open();try{$memory=New-Object IO.MemoryStream;try{$stream.CopyTo($memory);return ,$memory.ToArray()}finally{$memory.Dispose()}}finally{$stream.Dispose()}}
function Write-NewJson([string]$Path,[object]$Value){if(Test-Path -LiteralPath $Path){throw "C2R evidence already exists: $Path"};$partial=$Path+'.partial';if(Test-Path -LiteralPath $partial){throw "C2R evidence partial exists: $partial"};[IO.File]::WriteAllText($partial,(($Value|ConvertTo-Json -Depth 14)+[Environment]::NewLine),$utf8NoBom);Move-Item -LiteralPath $partial -Destination $Path}
foreach($path in @($publishGatePath,$pathTool,$certPath)){if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "C2R response prerequisite missing: $path"}}
if((Sha $publishGatePath)-ne$publishGateSha){throw 'C2R publish gate changed.'}
$publish=Get-Content -LiteralPath $publishGatePath -Raw|ConvertFrom-Json
if([string]$publish.requestId-ne$requestId-or[string]$publish.state-ne'PASS_R8_EXACT_SIGNED_REQUEST_PUBLISHED_CREATE_NEW'-or[bool]$publish.overwritePerformed-or[int]$publish.pendingRequestsAtApply-ne0){throw 'R8 publication contract changed.'}
if(Test-Path -LiteralPath $terminalGatePath){throw 'C2R terminal gate already exists.'}
if(-not(Test-Path -LiteralPath $responseRoot -PathType Container)){throw 'C2R response share unavailable.'}
Add-Type -AssemblyName System.IO.Compression.FileSystem
$pending=@(Get-ChildItem -LiteralPath $requestRoot -File -ErrorAction Stop|Where-Object{$_.Name-match'\.ready\.zip(\.upload)?$'})
$candidates=New-Object Collections.Generic.List[object]
foreach($item in @(Get-ChildItem -LiteralPath $responseRoot -File -Filter '*.ready.zip' -ErrorAction Stop)){
    $archive=[IO.Compression.ZipFile]::OpenRead($item.FullName)
    try{
        try{$manifestBytes=Read-Entry (Exact-Entry $archive 'PORTAL_RESPONSE_MANIFEST.json') 1048576}catch{continue}
        $manifest=$utf8.GetString($manifestBytes)|ConvertFrom-Json
        if([string]$manifest.requestId-eq$requestId){$signatureBytes=Read-Entry (Exact-Entry $archive 'PORTAL_RESPONSE_MANIFEST.sig') 4096;$candidates.Add([pscustomobject]@{item=$item;manifest=$manifest;manifestBytes=$manifestBytes;signatureBytes=$signatureBytes})}
    }finally{$archive.Dispose()}
}
if($candidates.Count-eq0){if($Preflight){[ordered]@{schema='argos_r8_response_pending_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PENDING_R8_SIGNED_TERMINAL_RESPONSE';requestId=$requestId;pendingRequests=$pending.Count;responseCandidates=0;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 5;return};throw 'R8 response unavailable.'}
if($candidates.Count-ne1){throw "Expected one C2R response; found $($candidates.Count)."}
if($pending.Count-ne0){throw ('Portal request remains pending: '+(($pending|Select-Object -First 5|ForEach-Object{$_.Name})-join', '))}
$candidate=$candidates[0]
if([string]$candidate.manifest.sourceRole-ne'JBOD'){throw 'C2R source role changed.'}
$certificate=New-Object Security.Cryptography.X509Certificates.X509Certificate2($certPath)
$rsa=[Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPublicKey($certificate)
try{$signatureVerified=$rsa.VerifyData($candidate.manifestBytes,$candidate.signatureBytes,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1)}finally{$rsa.Dispose();$certificate.Dispose()}
if(-not$signatureVerified){throw 'C2R response signature failed.'}
$archive=[IO.Compression.ZipFile]::OpenRead($candidate.item.FullName)
try{
    foreach($file in @($candidate.manifest.files)){$entry=Exact-Entry $archive ([string]$file.path);$bytes=Read-Entry $entry ([int64]$file.bytes);if([int64]$entry.Length-ne[int64]$file.bytes-or(Bytes-Sha $bytes)-ne[string]$file.sha256){throw "C2R response file changed: $($file.path)"}}
    $stdoutBytes=Read-Entry (Exact-Entry $archive 'MAINTENANCE.stdout.txt') 4194304;$stdoutText=$utf8.GetString($stdoutBytes);$stdout=if([string]::IsNullOrWhiteSpace($stdoutText)){$null}else{$stdoutText|ConvertFrom-Json}
    $stderrBytes=Read-Entry (Exact-Entry $archive 'MAINTENANCE.stderr.txt') 4194304;$stderrText=$utf8.GetString($stderrBytes)
    $failure=if([string]$candidate.manifest.state-eq'FAILED'){$utf8.GetString((Read-Entry (Exact-Entry $archive 'FAILURE.json') 1048576))|ConvertFrom-Json}else{$null}
}finally{$archive.Dispose()}
$zipSha=Sha $candidate.item.FullName;$zipBytes=[int64]$candidate.item.Length;$zipName=[string]$candidate.item.Name;$dirName=$zipName.Substring(0,$zipName.Length-4)
$targetZip=Join-Path $localRoot $zipName;$targetZipPartial=$targetZip+'.partial';$targetDir=Join-Path $localRoot $dirName;$targetDirPartial=$targetDir+'.partial'
$planned=@($targetZip,$targetZipPartial,$targetDir,$targetDirPartial,$routeGatePath,$terminalGatePath)
foreach($file in @($candidate.manifest.files)){$planned+=Join-Path $targetDir ([string]$file.path).Replace('/','\')}
$pathGate=&$pathTool -CandidatePath $planned -ReservedSuffixCharacters 32 -AsJson|ConvertFrom-Json
if([string]$pathGate.state-ne'PASS_PATH_BUDGET'){throw 'C2R response path gate failed.'}
$longest=@($pathGate.candidates|Sort-Object effectiveLength -Descending|Select-Object -First 1)[0]
$route=[ordered]@{schema='argos_r8_response_route_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R8_RESPONSE_ROUTE_GATE';requestId=$requestId;responseId=[string]$candidate.manifest.responseId;responseZipSha256=$zipSha;responseZipBytes=$zipBytes;declaredResponseFiles=@($candidate.manifest.files).Count;maximumEffectiveLength=[int]$longest.effectiveLength;maximumComponentLength=[int](($pathGate.candidates|Measure-Object longestComponentLength -Maximum).Maximum);localExtractionRoot=$localRoot;localRootFresh=(-not(Test-Path -LiteralPath $localRoot));pathState=[string]$pathGate.state;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}
if($Preflight){$route|ConvertTo-Json -Depth 6;return}
if(Test-Path -LiteralPath $localRoot){throw "Fresh C2R response root required: $localRoot"}
Write-NewJson $routeGatePath $route
$createdDrive=$false
try{
    $drive=Get-PSDrive U -ErrorAction SilentlyContinue
    if($null-eq$drive){[void](New-PSDrive -Name U -PSProvider FileSystem -Root $share -Scope Global);$createdDrive=$true;$drive=Get-PSDrive U -ErrorAction Stop}
    if(-not([IO.Path]::GetFullPath([string]$drive.Root).TrimEnd('\')).Equals([IO.Path]::GetFullPath($share).TrimEnd('\'),[StringComparison]::OrdinalIgnoreCase)){throw 'C2R U: mapping changed.'}
    [void](New-Item -ItemType Directory -Path $localRoot)
    Copy-Item -LiteralPath ($shortResponseRoot.TrimEnd('\')+'\'+$zipName) -Destination $targetZipPartial
    if([int64](Get-Item -LiteralPath $targetZipPartial).Length-ne$zipBytes-or(Sha $targetZipPartial)-ne$zipSha){throw 'C2R copied ZIP changed.'}
    Move-Item -LiteralPath $targetZipPartial -Destination $targetZip
    [IO.Compression.ZipFile]::ExtractToDirectory($targetZip,$targetDirPartial)
    foreach($file in @($candidate.manifest.files)){$path=Join-Path $targetDirPartial ([string]$file.path).Replace('/','\');if(-not(Test-Path -LiteralPath $path -PathType Leaf)-or[int64](Get-Item -LiteralPath $path).Length-ne[int64]$file.bytes-or(Sha $path)-ne[string]$file.sha256){throw "C2R extracted file changed: $($file.path)"}}
    Move-Item -LiteralPath $targetDirPartial -Destination $targetDir
}finally{if($createdDrive){Remove-PSDrive U -Force -Scope Global -ErrorAction SilentlyContinue}}
if([string]$candidate.manifest.state-eq'FAILED'){
    $terminal=[ordered]@{schema='argos_r8_terminal_failure_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='FAIL_R8_SIGNED_TERMINAL_RESPONSE';disposition='WITHDRAWN';requestId=$requestId;responseId=[string]$candidate.manifest.responseId;responseState=[string]$candidate.manifest.state;responseZip=$targetZip;responseZipBytes=$zipBytes;responseZipSha256=$zipSha;signatureVerified=$true;failureState=if($null-eq$failure){''}else{[string]$failure.state};stderrSha256=Bytes-Sha $stderrBytes;sourceDeletionPerformed=$false;otherInspectionTasksChanged=$false;waferAborted=$false;reviewOnly=$true;productionRoutingEnabled=$false}
    Write-NewJson $terminalGatePath $terminal;$terminal|ConvertTo-Json -Depth 8;return
}
$pass=(
    [string]$candidate.manifest.state-eq'PASS_MAINTENANCE_PATCH'-and$null-ne$stdout-and
    [string]$stdout.state-eq'PASS_JBOD_PROCESSOR_RUNNER_FIX_AND_REFRESH_R8'-and-not[bool]$stdout.rehearsal-and
    [string]$stdout.taskName-eq'ArgosEdgeLab.AllWaferProcessor.ReviewOnly.V2'-and
    [string]$stdout.runnerBeforeSha256-eq'46661DB0FC7F12AE7146067403390AF7CC7D0DD933A67C601C56E0EECB4FE9A4'-and
    [string]$stdout.runnerSha256-eq'46661DB0FC7F12AE7146067403390AF7CC7D0DD933A67C601C56E0EECB4FE9A4'-and-not[bool]$stdout.runnerChanged-and
    [string]$stdout.inventorySha256-eq'8919C3DD4AC04FD662B57E356AC6E1A70BD614E97AFC270EB4B8FF617D705160'-and
    [string]$stdout.importerSha256-eq'45965930699A0F0C38098B65E5A153C5DE360103BC9FED345AC5811B6F1FBD0D'-and
    [string]$stdout.configSha256-eq'CDFD888129D0144C9942D027B0C4583FEEF3619D6D65B060B3001686357879D8'-and
    [string]$stdout.metadataSnapshotRoot-eq'D:\A2\m\verified'-and
    [string]$stdout.lot-eq'62631-586'-and[string]$stdout.scan-eq'20260819173317'-and
    [int]$stdout.currentQueueRows-eq10-and[int]$stdout.confirmedPhysicalAcquisitions-eq10-and
    [int]$stdout.overlayPhysicalMatches-eq10-and[int]$stdout.metadataMatchedCatalogRows-eq20-and
    [int]$stdout.staleMatchedInsiteRowsBefore-eq0-and[int]$stdout.staleMatchedInsiteRowsAfter-eq0-and
    [int]$stdout.notReadyMatchedRowsBefore-eq20-and[int]$stdout.notReadyMatchedRowsAfter-eq0-and
    [int]$stdout.scribeHoldRowsAfter-eq0-and
    [int]$stdout.exactProcessCountAfter-eq1-and
    (([bool]$stdout.processorTaskRestarted)-xor([bool]$stdout.restartSkippedFresh))-and
    ([DateTime]$stdout.newProcessCreationUtc).ToUniversalTime()-ge([DateTime]$stdout.dRootBoundaryUtc).ToUniversalTime()-and
    ([DateTime]$stdout.newProcessCreationUtc).ToUniversalTime()-ge([DateTime]$stdout.runnerLastWriteUtc).ToUniversalTime()-and
    -not[bool]$stdout.protectedTaskDefinitionsChanged-and-not[bool]$stdout.protectedTaskPrincipalsChanged-and
    -not[bool]$stdout.otherInspectionTasksChanged-and-not[bool]$stdout.requestOrResponseDeleted-and
    -not[bool]$stdout.waferAborted-and[bool]$stdout.reviewOnly-and-not[bool]$stdout.xmlExportEnabled-and
    -not[bool]$stdout.productionRoutingEnabled
)
if(-not$pass){throw 'C2R signed terminal contract failed.'}
$terminal=[ordered]@{
    schema='argos_r8_terminal_response_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R8_SIGNED_TERMINAL_RESPONSE';disposition='PENDING_GATE'
    requestId=$requestId;responseId=[string]$candidate.manifest.responseId;responseState=[string]$candidate.manifest.state;responseZip=$targetZip;responseZipBytes=$zipBytes;responseZipSha256=$zipSha
    responseManifestSha256=Sha (Join-Path $targetDir 'PORTAL_RESPONSE_MANIFEST.json');responseSignatureSha256=Sha (Join-Path $targetDir 'PORTAL_RESPONSE_MANIFEST.sig');signatureVerified=$true;declaredResponseFilesVerified=@($candidate.manifest.files).Count
    taskName=[string]$stdout.taskName;taskPrincipal=[string]$stdout.taskPrincipal;taskDefinitionSha256=[string]$stdout.taskDefinitionSha256;dRootBoundaryUtc=[string]$stdout.dRootBoundaryUtc;runnerLastWriteUtc=[string]$stdout.runnerLastWriteUtc;inventoryLastWriteUtc=[string]$stdout.inventoryLastWriteUtc
    restartStartedUtc=[string]$stdout.restartStartedUtc;processorTaskRestarted=[bool]$stdout.processorTaskRestarted;restartSkippedFresh=[bool]$stdout.restartSkippedFresh;oldProcessId=$stdout.oldProcessId;oldProcessCreationUtc=[string]$stdout.oldProcessCreationUtc;newProcessId=[int]$stdout.newProcessId;newProcessCreationUtc=[string]$stdout.newProcessCreationUtc;exactProcessCountAfter=[int]$stdout.exactProcessCountAfter
    runnerBeforeSha256=[string]$stdout.runnerBeforeSha256;runnerSha256=[string]$stdout.runnerSha256;runnerChanged=[bool]$stdout.runnerChanged;runnerEvidenceRoot=[string]$stdout.runnerEvidenceRoot;runnerPriorArchive=[string]$stdout.runnerPriorArchive;inventorySha256=[string]$stdout.inventorySha256;importerSha256=[string]$stdout.importerSha256;configSha256=[string]$stdout.configSha256;metadataSnapshotRoot=[string]$stdout.metadataSnapshotRoot
    lot=[string]$stdout.lot;scan=[string]$stdout.scan;currentQueueRows=[int]$stdout.currentQueueRows;confirmedPhysicalAcquisitions=[int]$stdout.confirmedPhysicalAcquisitions;overlayPhysicalMatches=[int]$stdout.overlayPhysicalMatches;metadataMatchedCatalogRows=[int]$stdout.metadataMatchedCatalogRows
    catalogGeneratedUtc=[string]$stdout.catalogGeneratedUtc;staleMatchedInsiteRowsBefore=[int]$stdout.staleMatchedInsiteRowsBefore;staleMatchedInsiteRowsAfter=[int]$stdout.staleMatchedInsiteRowsAfter;notReadyMatchedRowsBefore=[int]$stdout.notReadyMatchedRowsBefore;notReadyMatchedRowsAfter=[int]$stdout.notReadyMatchedRowsAfter;scribeHoldRowsAfter=[int]$stdout.scribeHoldRowsAfter;routeStatesAfter=@($stdout.routeStatesAfter)
    protectedTaskCount=[int]$stdout.protectedTaskCount;protectedTaskDefinitionsChanged=[bool]$stdout.protectedTaskDefinitionsChanged;protectedTaskPrincipalsChanged=[bool]$stdout.protectedTaskPrincipalsChanged;requestOrResponseDeleted=[bool]$stdout.requestOrResponseDeleted;sourceDeletionPerformed=$false;otherInspectionTasksChanged=[bool]$stdout.otherInspectionTasksChanged;waferAborted=[bool]$stdout.waferAborted;reviewOnly=[bool]$stdout.reviewOnly;xmlExportEnabled=[bool]$stdout.xmlExportEnabled;productionRoutingEnabled=[bool]$stdout.productionRoutingEnabled
}
Write-NewJson $terminalGatePath $terminal
$terminal|ConvertTo-Json -Depth 10

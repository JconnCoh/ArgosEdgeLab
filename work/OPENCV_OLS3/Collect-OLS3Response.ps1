[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Collect,
    [Parameter(Mandatory = $true)][string]$InvocationManifest
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Collect)) { throw 'Specify exactly one of -Preflight or -Collect.' }

function Get-ArgosFileHash {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$LiteralPath)
    $stream=[IO.File]::Open([IO.Path]::GetFullPath($LiteralPath),[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
    $sha=[Security.Cryptography.SHA256]::Create()
    try{return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','')}
    finally{$sha.Dispose();$stream.Dispose()}
}

function Get-RequiredProperty {
    param([Parameter(Mandatory=$true)][object]$InputObject,[Parameter(Mandatory=$true)][string]$Name)
    $property=$InputObject.PSObject.Properties[$Name]
    if($null-eq$property){throw "Required property is absent: $Name"}
    return $property.Value
}

$project='C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab'
$workRoot=Join-Path $project 'work\OPENCV_OLS3'
$requestId='REQ_OLS3'
$invocationPath=[IO.Path]::GetFullPath($InvocationManifest)
$invocation=Get-Content -LiteralPath $invocationPath -Raw | ConvertFrom-Json
if([string](Get-RequiredProperty $invocation 'schema')-ne'argos_ols3_response_collection_invocation_v1'-or[string](Get-RequiredProperty $invocation 'requestId')-ne$requestId){throw 'OLS3 response collection invocation contract changed.'}
$sourceZip=[IO.Path]::GetFullPath([string](Get-RequiredProperty $invocation 'sourceZip'))
$approvedResponseRoot=[IO.Path]::GetFullPath('U:\ProjectPortalRO\responses').TrimEnd('\')
if(-not$sourceZip.StartsWith($approvedResponseRoot+'\',[StringComparison]::OrdinalIgnoreCase)-or-not([IO.Path]::GetDirectoryName($sourceZip)).Equals($approvedResponseRoot,[StringComparison]::OrdinalIgnoreCase)-or[IO.Path]::GetExtension($sourceZip)-ine'.zip'){throw 'OLS3 response source is outside the exact approved response root.'}
$responseToken=[IO.Path]::GetFileNameWithoutExtension($sourceZip)
if($responseToken-notmatch'^R_[0-9A-F]{12}_[0-9]{17}_[0-9a-f]{8}\.ready$'){throw 'OLS3 response token format changed.'}
$expectedZipBytes=[int64](Get-RequiredProperty $invocation 'expectedZipBytes')
$expectedZipSha256=([string](Get-RequiredProperty $invocation 'expectedZipSha256')).ToUpperInvariant()
if($expectedZipBytes-lt1-or$expectedZipBytes-gt10485760-or$expectedZipSha256-notmatch'^[0-9A-F]{64}$'){throw 'OLS3 response invocation size or hash is invalid.'}

$collectionRoot='C:\A3R'
$localZip=$collectionRoot.TrimEnd('\')+'\'+$responseToken+'.zip'
$readyRoot=$collectionRoot.TrimEnd('\')+'\'+$responseToken
$partialRoot=$readyRoot+'.partial'
$terminalGatePath=Join-Path $workRoot 'OLS3_TERMINAL_RESPONSE_GATE.json'
$responseVerifier=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalResponse.ps1'
$endpointCertificate=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\active\JBOD_ENDPOINT_SIGNER.cer'
$pathTool=Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
foreach($path in @($sourceZip,$responseVerifier,$endpointCertificate,$pathTool)){if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "OLS3 response prerequisite is missing: $path"}}
if((Get-Item -LiteralPath $sourceZip).Length-ne$expectedZipBytes-or(Get-ArgosFileHash $sourceZip)-ne$expectedZipSha256){throw 'OLS3 source response ZIP changed.'}
foreach($path in @($localZip,$readyRoot,$partialRoot,$terminalGatePath)){if(Test-Path -LiteralPath $path){throw "OLS3 response output already exists: $path"}}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive=[IO.Compression.ZipFile]::OpenRead($sourceZip)
try{
    $manifestEntry=$archive.GetEntry('PORTAL_RESPONSE_MANIFEST.json')
    if($null-eq$manifestEntry-or$manifestEntry.Length-gt1048576){throw 'OLS3 bounded response manifest entry is missing or too large.'}
    $stream=$manifestEntry.Open()
    $reader=New-Object IO.StreamReader($stream,(New-Object Text.UTF8Encoding($false,$true)))
    try{$manifest=$reader.ReadToEnd()|ConvertFrom-Json}finally{$reader.Dispose();$stream.Dispose()}
}finally{$archive.Dispose()}
$endpointState=[string](Get-RequiredProperty $manifest 'state')
if([string](Get-RequiredProperty $manifest 'requestId')-ne$requestId-or[string](Get-RequiredProperty $manifest 'sourceRole')-ne'JBOD'-or$endpointState-notin @('PASS_MAINTENANCE_PATCH','FAILED')-or-not[bool](Get-RequiredProperty $manifest 'reviewOnly')-or[bool](Get-RequiredProperty $manifest 'productionRoutingEnabled')){throw 'OLS3 response manifest terminal contract changed.'}

$planned=@($localZip,$readyRoot+'\PORTAL_RESPONSE_MANIFEST.json',$readyRoot+'\PORTAL_RESPONSE_MANIFEST.sig',$readyRoot+'\MAINTENANCE.stdout.txt',$readyRoot+'\MAINTENANCE.stderr.txt',$partialRoot+'\PORTAL_RESPONSE_MANIFEST.json',$terminalGatePath)
$pathGate=& $pathTool -CandidatePath $planned -ReservedSuffixCharacters 32 -AsJson|ConvertFrom-Json
if([string]$pathGate.state-ne'PASS_PATH_BUDGET'){throw "OLS3 response collection path gate failed: $($pathGate.state)"}

if($Preflight){
    [ordered]@{
        schema='argos_ols3_response_collection_preflight_v1'
        createdUtc=[DateTime]::UtcNow.ToString('o')
        state='PASS_OLS3_RESPONSE_COLLECTION_PREFLIGHT'
        requestId=$requestId
        responseToken=$responseToken
        endpointState=$endpointState
        sourceZipBytes=$expectedZipBytes
        sourceZipSha256=$expectedZipSha256
        pathState=[string]$pathGate.state
        mutationsPerformed=$false
        reviewOnly=$true
        productionRoutingEnabled=$false
    }|ConvertTo-Json -Depth 6
    return
}

[void](New-Item -ItemType Directory -Path $collectionRoot)
Copy-Item -LiteralPath $sourceZip -Destination $localZip -ErrorAction Stop
if((Get-Item -LiteralPath $localZip).Length-ne$expectedZipBytes-or(Get-ArgosFileHash $localZip)-ne$expectedZipSha256){throw 'OLS3 local response ZIP changed during copy.'}
[void](New-Item -ItemType Directory -Path $partialRoot)
[IO.Compression.ZipFile]::ExtractToDirectory($localZip,$partialRoot)
& $responseVerifier -PackagePath $partialRoot -EndpointCertificatePath $endpointCertificate -ExpectedSourceRole JBOD -ExpectedRequestId $requestId|Out-Null
if($LASTEXITCODE-ne0){throw 'OLS3 signed response verification failed.'}
$extractedManifest=Get-Content -LiteralPath (Join-Path $partialRoot 'PORTAL_RESPONSE_MANIFEST.json') -Raw|ConvertFrom-Json
$extractedState=[string](Get-RequiredProperty $extractedManifest 'state')
if($extractedState-ne$endpointState){throw 'OLS3 extracted response state changed.'}
$responseFileCount=@(Get-RequiredProperty $extractedManifest 'files').Count

$gate=[ordered]@{
    schema='argos_ols3_terminal_response_gate_v1'
    collectedUtc=[DateTime]::UtcNow.ToString('o')
    state=$null
    disposition='PENDING_GATE'
    requestId=$requestId
    responseToken=$responseToken
    endpointState=$extractedState
    sourceRole=[string](Get-RequiredProperty $extractedManifest 'sourceRole')
    signedResponseVerified=$true
    responseFileCount=$responseFileCount
    sourceZipBytes=$expectedZipBytes
    sourceZipSha256=$expectedZipSha256
    inventoryDisposition=$null
    holdReasons=@()
    inventorySummary=$null
    bmpRelativePathPreview=@()
    maintenanceStdoutPath=$null
    maintenanceStdoutBytes=0
    maintenanceStdoutSha256=$null
    maintenanceStderrPath=$null
    maintenanceStderrBytes=0
    maintenanceStderrSha256=$null
    terminalFailureDetail=$null
    metadataOnly=$true
    filesRead=$false
    imageBytesRead=$false
    sourceHashingPerformed=$false
    collectedRoot=$readyRoot
    pathState=[string]$pathGate.state
    endpointCapabilityImprovementExecuted=$true
    inspectionTasksChanged=$false
    processorTaskChanged=$false
    processActions=@()
    sourceDeletionPerformed=$false
    currentWaferAborted=$false
    reviewOnly=$true
    productionRoutingEnabled=$false
}

if($extractedState-eq'PASS_MAINTENANCE_PATCH'){
    if($responseFileCount-ne3){throw 'OLS3 successful response file count changed.'}
    $stdoutPath=Join-Path $partialRoot 'MAINTENANCE.stdout.txt'
    if(-not(Test-Path -LiteralPath $stdoutPath -PathType Leaf)-or(Get-Item -LiteralPath $stdoutPath).Length-gt8388608){throw 'OLS3 bounded maintenance stdout is missing or too large.'}
    $entryResult=Get-Content -LiteralPath $stdoutPath -Raw|ConvertFrom-Json
    $subtree=Get-RequiredProperty $entryResult 'boundedSubtreeInventory'
    $directories=@(Get-RequiredProperty $subtree 'directories')
    $bmpLeaves=@(Get-RequiredProperty $subtree 'bmpLeaves')
    if([string](Get-RequiredProperty $entryResult 'schema')-ne'argos_ols3_entrypoint_result_v1'-or[string](Get-RequiredProperty $entryResult 'state')-ne'PASS_OCV00_BOUNDED_LOT_SUBTREE_OBSERVED_OLS3'-or-not[bool](Get-RequiredProperty $entryResult 'metadataOnly')-or-not[bool](Get-RequiredProperty $entryResult 'pathsEnumerated')-or[bool](Get-RequiredProperty $entryResult 'filesRead')-or[bool](Get-RequiredProperty $entryResult 'imageBytesRead')-or[bool](Get-RequiredProperty $entryResult 'sourceHashingPerformed')-or[bool](Get-RequiredProperty $entryResult 'inspectionTasksChanged')-or[bool](Get-RequiredProperty $entryResult 'processorTaskChanged')-or@(Get-RequiredProperty $entryResult 'processActions').Count-ne0-or[bool](Get-RequiredProperty $entryResult 'sourceDeletionPerformed')-or[bool](Get-RequiredProperty $entryResult 'waferActionPerformed')){throw 'OLS3 signed maintenance stdout violated the exact metadata-only terminal contract.'}
    $subtreeState=[string](Get-RequiredProperty $subtree 'state')
    if([string](Get-RequiredProperty $subtree 'schema')-ne'argos_bounded_subtree_inventory_v1'-or$subtreeState-notin @('COMPLETE','HOLD_INCOMPLETE')-or([bool](Get-RequiredProperty $subtree 'complete')-ne($subtreeState-eq'COMPLETE'))-or[string](Get-RequiredProperty $subtree 'relativeRoot')-ne'PatternedFront\Lot_62619-433'-or[string](Get-RequiredProperty $subtree 'aliasReadRoot')-ne'F:\PatternedFront\Lot_62619-433'-or$directories.Count-ne[int](Get-RequiredProperty $subtree 'directoryCount')-or$bmpLeaves.Count-ne[int](Get-RequiredProperty $subtree 'bmpLeafCount')){throw 'OLS3 signed bounded subtree inventory contract changed.'}
    for($index=0;$index-lt$directories.Count;$index++){
        $row=$directories[$index]
        if(-not[bool](Get-RequiredProperty $row 'containedByApprovedRoot')-or-not([string](Get-RequiredProperty $row 'relativePath')).StartsWith('PatternedFront\Lot_62619-433\',[StringComparison]::OrdinalIgnoreCase)-or-not([string](Get-RequiredProperty $row 'aliasReadPath')).StartsWith('F:\PatternedFront\Lot_62619-433\',[StringComparison]::OrdinalIgnoreCase)-or[int](Get-RequiredProperty $row 'canonicalEffectiveLength')-ge230-or[int](Get-RequiredProperty $row 'aliasEffectiveLength')-ge200-or[bool](Get-RequiredProperty $row 'reparsePoint')-or[bool](Get-RequiredProperty $row 'filesRead')-or[bool](Get-RequiredProperty $row 'imageBytesRead')-or[bool](Get-RequiredProperty $row 'sourceHashingPerformed')-or[bool](Get-RequiredProperty $row 'mutationsPerformed')){throw "OLS3 signed directory metadata row contract failed at index $index."}
    }
    for($index=0;$index-lt$bmpLeaves.Count;$index++){
        $row=$bmpLeaves[$index]
        if(-not[bool](Get-RequiredProperty $row 'containedByApprovedRoot')-or-not([string](Get-RequiredProperty $row 'relativePath')).StartsWith('PatternedFront\Lot_62619-433\',[StringComparison]::OrdinalIgnoreCase)-or-not([string](Get-RequiredProperty $row 'aliasReadPath')).StartsWith('F:\PatternedFront\Lot_62619-433\',[StringComparison]::OrdinalIgnoreCase)-or[string](Get-RequiredProperty $row 'extension')-ne'.bmp'-or[int](Get-RequiredProperty $row 'canonicalEffectiveLength')-ge230-or[int](Get-RequiredProperty $row 'aliasEffectiveLength')-ge200-or[bool](Get-RequiredProperty $row 'reparsePoint')-or[bool](Get-RequiredProperty $row 'filesRead')-or[bool](Get-RequiredProperty $row 'imageBytesRead')-or[bool](Get-RequiredProperty $row 'sourceHashingPerformed')-or[bool](Get-RequiredProperty $row 'mutationsPerformed')){throw "OLS3 signed BMP metadata row contract failed at index $index."}
    }
    $computedHoldReasons=@()
    if(-not[bool](Get-RequiredProperty $subtree 'rootExists')){$computedHoldReasons+='ROOT_MISSING'}
    if([bool](Get-RequiredProperty $subtree 'truncated')){$computedHoldReasons+='TRUNCATED'}
    if([int](Get-RequiredProperty $subtree 'accessErrorCount')-gt0){$computedHoldReasons+='ACCESS_ERRORS'}
    if([int](Get-RequiredProperty $subtree 'skippedReparseSubtrees')-gt0){$computedHoldReasons+='REPARSE_SUBTREES_SKIPPED'}
    if([int](Get-RequiredProperty $subtree 'skippedUnsafePathSubtrees')-gt0){$computedHoldReasons+='UNSAFE_PATH_SUBTREES_SKIPPED'}
    if([int](Get-RequiredProperty $subtree 'depthBoundaryDirectoryCount')-gt0){$computedHoldReasons+='DEPTH_BOUNDARY_DIRECTORIES'}
    $reportedHoldReasons=@(Get-RequiredProperty $entryResult 'holdReasons'|ForEach-Object{[string]$_})
    $inventoryDisposition=[string](Get-RequiredProperty $entryResult 'inventoryDisposition')
    if(($computedHoldReasons-join'|')-ne($reportedHoldReasons-join'|')-or$inventoryDisposition-ne$(if($computedHoldReasons.Count-eq0-and$subtreeState-eq'COMPLETE'){'COMPLETE'}else{'HOLD_INCOMPLETE'})){throw 'OLS3 inventory disposition or hold reasons changed.'}
    $gate.state=if($inventoryDisposition-eq'COMPLETE'){'PASS_OLS3_SIGNED_TERMINAL_RESPONSE_COMPLETE'}else{'PASS_OLS3_SIGNED_TERMINAL_RESPONSE_HOLD_INCOMPLETE'}
    $gate.inventoryDisposition=$inventoryDisposition
    $gate.holdReasons=$reportedHoldReasons
    $gate.inventorySummary=[ordered]@{
        subtreeState=$subtreeState
        rootExists=[bool](Get-RequiredProperty $subtree 'rootExists')
        complete=[bool](Get-RequiredProperty $subtree 'complete')
        truncated=[bool](Get-RequiredProperty $subtree 'truncated')
        directoryCount=[int](Get-RequiredProperty $subtree 'directoryCount')
        bmpLeafCount=[int](Get-RequiredProperty $subtree 'bmpLeafCount')
        accessErrorCount=[int](Get-RequiredProperty $subtree 'accessErrorCount')
        skippedReparseSubtrees=[int](Get-RequiredProperty $subtree 'skippedReparseSubtrees')
        skippedUnsafePathSubtrees=[int](Get-RequiredProperty $subtree 'skippedUnsafePathSubtrees')
        depthBoundaryDirectoryCount=[int](Get-RequiredProperty $subtree 'depthBoundaryDirectoryCount')
    }
    $gate.bmpRelativePathPreview=@($bmpLeaves|Sort-Object{[string](Get-RequiredProperty $_ 'relativePath')}|Select-Object -First 64|ForEach-Object{[string](Get-RequiredProperty $_ 'relativePath')})
    $gate.maintenanceStdoutPath=$readyRoot+'\MAINTENANCE.stdout.txt'
    $gate.maintenanceStdoutBytes=[int64](Get-Item -LiteralPath $stdoutPath).Length
    $gate.maintenanceStdoutSha256=Get-ArgosFileHash $stdoutPath
}else{
    $stderrPath=Join-Path $partialRoot 'MAINTENANCE.stderr.txt'
    if(-not(Test-Path -LiteralPath $stderrPath -PathType Leaf)-or(Get-Item -LiteralPath $stderrPath).Length-gt1048576){throw 'OLS3 bounded maintenance stderr is missing or too large.'}
    $detail=(Get-Content -LiteralPath $stderrPath -Raw).Trim()
    if($detail.Length-gt2048){$detail=$detail.Substring(0,2048)}
    $gate.state='SIGNED_OLS3_TERMINAL_FAILURE'
    $gate.inventoryDisposition='UNAVAILABLE_ENDPOINT_FAILURE'
    $gate.holdReasons=@('ENDPOINT_FAILURE')
    $gate.maintenanceStderrPath=$readyRoot+'\MAINTENANCE.stderr.txt'
    $gate.maintenanceStderrBytes=[int64](Get-Item -LiteralPath $stderrPath).Length
    $gate.maintenanceStderrSha256=Get-ArgosFileHash $stderrPath
    $gate.terminalFailureDetail=$detail
}

Move-Item -LiteralPath $partialRoot -Destination $readyRoot
[IO.File]::WriteAllText($terminalGatePath,(($gate|ConvertTo-Json -Depth 8)+[Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))
$gate|ConvertTo-Json -Depth 8

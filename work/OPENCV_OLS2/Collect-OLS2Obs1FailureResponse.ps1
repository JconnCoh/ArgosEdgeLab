[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Collect,
    [Parameter(Mandatory = $true)][string]$InvocationManifest
)

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if(([bool]$Preflight)-eq([bool]$Collect)){throw 'Specify exactly one of -Preflight or -Collect.'}

function Get-FileHash{
    [CmdletBinding()]param([Parameter(Mandatory=$true)][string]$LiteralPath,[ValidateSet('SHA256')][string]$Algorithm='SHA256')
    $sha=[Security.Cryptography.SHA256]::Create()
    try{Get-Content -LiteralPath $LiteralPath -Encoding Byte -ReadCount 1048576|ForEach-Object{[byte[]]$block=@($_);if($block.Length-gt0){[void]$sha.TransformBlock($block,0,$block.Length,$block,0)}};[void]$sha.TransformFinalBlock([byte[]]@(),0,0);[pscustomobject]@{Algorithm='SHA256';Hash=([BitConverter]::ToString($sha.Hash)).Replace('-','');Path=$LiteralPath}}finally{$sha.Dispose()}
}
function Get-OptionalString([object]$Object,[string]$Name){if($null-eq$Object -or -not($Object.PSObject.Properties.Name-contains$Name)){return $null};[string]$Object.$Name}
$absent=[pscustomobject]@{state='FAILED'};$present=[pscustomobject]@{state='FAILED';detail='CONTROL'}
if($null-ne(Get-OptionalString $absent 'detail')-or(Get-OptionalString $present 'detail')-ne'CONTROL'){throw 'OBS1 optional-property controls failed.'}

$project='C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab'
$requestId='REQ_O2OBS1'
$invocation=Get-Content -LiteralPath ([IO.Path]::GetFullPath($InvocationManifest)) -Raw|ConvertFrom-Json
if([string]$invocation.schema-ne'argos_ols2_obs1_failure_collection_invocation_v1'-or[string]$invocation.requestId-ne$requestId){throw 'OBS1 failure collection invocation changed.'}
$sourceZip=[IO.Path]::GetFullPath([string]$invocation.sourceZip)
$approvedRoot=[IO.Path]::GetFullPath('U:\ProjectPortalRO\responses').TrimEnd('\')
if(-not$sourceZip.StartsWith($approvedRoot+'\',[StringComparison]::OrdinalIgnoreCase)-or-not([IO.Path]::GetDirectoryName($sourceZip)).Equals($approvedRoot,[StringComparison]::OrdinalIgnoreCase)-or[IO.Path]::GetExtension($sourceZip)-ine'.zip'){throw 'OBS1 response is outside the approved root.'}
$responseToken=[IO.Path]::GetFileNameWithoutExtension($sourceZip)
if($responseToken-notmatch'^R_[0-9A-F]{12}_[0-9]{17}_[0-9a-f]{8}\.ready$'){throw 'OBS1 response token changed.'}
$expectedBytes=[int64]$invocation.expectedZipBytes;$expectedSha=([string]$invocation.expectedZipSha256).ToUpperInvariant()
if($expectedBytes-lt1-or$expectedBytes-gt2097152-or$expectedSha-notmatch'^[0-9A-F]{64}$'){throw 'OBS1 response size/hash contract changed.'}
$collectionRoot=[IO.Path]::GetFullPath([string]$invocation.collectionRoot).TrimEnd('\')
if(-not$collectionRoot.Equals('C:\O2F',[StringComparison]::OrdinalIgnoreCase)){throw 'OBS1 collection root changed.'}
$terminalGate=[IO.Path]::GetFullPath([string]$invocation.terminalGatePath)
$expectedGate=Join-Path $project 'work\OPENCV_OLS2\OBS1_SIGNED_FAILURE_GATE.json'
if(-not$terminalGate.Equals($expectedGate,[StringComparison]::OrdinalIgnoreCase)){throw 'OBS1 terminal gate path changed.'}
$localZip=$collectionRoot+'\'+$responseToken+'.zip';$readyRoot=$collectionRoot+'\'+$responseToken;$partialRoot=$readyRoot+'.partial'
$verifier=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalResponse.ps1'
$certificate=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\active\JBOD_ENDPOINT_SIGNER.cer'
$pathTool=Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
foreach($path in @($sourceZip,$verifier,$certificate,$pathTool)){if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "OBS1 prerequisite missing: $path"}}
if((Get-Item -LiteralPath $sourceZip).Length-ne$expectedBytes-or(Get-FileHash -LiteralPath $sourceZip -Algorithm SHA256).Hash-ne$expectedSha){throw 'OBS1 response ZIP changed.'}
foreach($path in @($collectionRoot,$localZip,$readyRoot,$partialRoot,$terminalGate)){if(Test-Path -LiteralPath $path){throw "OBS1 output already exists: $path"}}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive=[IO.Compression.ZipFile]::OpenRead($sourceZip)
try{$entries=@($archive.Entries);if($entries.Count-ne3){throw 'OBS1 response entry count changed.'};$entry=$archive.GetEntry('PORTAL_RESPONSE_MANIFEST.json');if($null-eq$entry-or$entry.Length-gt1048576){throw 'OBS1 response manifest missing/large.'};$reader=New-Object IO.StreamReader($entry.Open(),(New-Object Text.UTF8Encoding($false,$true)));try{$manifest=$reader.ReadToEnd()|ConvertFrom-Json}finally{$reader.Dispose()}}finally{$archive.Dispose()}
if([string]$manifest.requestId-ne$requestId-or[string]$manifest.sourceRole-ne'JBOD'-or[string]$manifest.state-ne'FAILED'-or-not[bool]$manifest.reviewOnly-or[bool]$manifest.productionRoutingEnabled){throw 'OBS1 terminal response contract changed.'}
$declared=@($manifest.files|ForEach-Object{[string]$_.path}|Sort-Object);$expectedFiles=@('FAILURE.json')
if(@(Compare-Object -ReferenceObject $expectedFiles -DifferenceObject $declared).Count-ne0){throw 'OBS1 failure file set changed.'}
$planned=@($localZip,$readyRoot+'\PORTAL_RESPONSE_MANIFEST.json',$readyRoot+'\PORTAL_RESPONSE_MANIFEST.sig',$readyRoot+'\FAILURE.json',$partialRoot+'\PORTAL_RESPONSE_MANIFEST.json',$terminalGate)
$pathGate=& $pathTool -CandidatePath $planned -ReservedSuffixCharacters 32 -AsJson|ConvertFrom-Json
if([string]$pathGate.state-ne'PASS_PATH_BUDGET'){throw 'OBS1 collection path gate failed.'}
if($Preflight){[ordered]@{schema='argos_ols2_obs1_failure_collection_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_OLS2_OBS1_FAILURE_COLLECTION_PREFLIGHT';requestId=$requestId;responseToken=$responseToken;untrustedEndpointState=[string]$manifest.state;sourceZipBytes=$expectedBytes;sourceZipSha256=$expectedSha;responseFiles=$declared.Count;optionalPropertyCasesPassed=2;pathState=[string]$pathGate.state;mutationsPerformed=$false;signedResponseVerified=$false;imageBytesRead=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 6;return}

[void](New-Item -ItemType Directory -Path $collectionRoot)
Copy-Item -LiteralPath $sourceZip -Destination $localZip -ErrorAction Stop
if((Get-Item -LiteralPath $localZip).Length-ne$expectedBytes-or(Get-FileHash -LiteralPath $localZip -Algorithm SHA256).Hash-ne$expectedSha){throw 'OBS1 local ZIP changed.'}
[void](New-Item -ItemType Directory -Path $partialRoot)
[IO.Compression.ZipFile]::ExtractToDirectory($localZip,$partialRoot)
& $verifier -PackagePath $partialRoot -EndpointCertificatePath $certificate -ExpectedSourceRole JBOD -ExpectedRequestId $requestId|Out-Null
if($LASTEXITCODE-ne0){throw 'OBS1 signed response verification failed.'}
$extracted=Get-Content -LiteralPath (Join-Path $partialRoot 'PORTAL_RESPONSE_MANIFEST.json') -Raw|ConvertFrom-Json
if([string]$extracted.state-ne'FAILED'-or@($extracted.files).Count-ne1){throw 'OBS1 extracted terminal contract changed.'}
$rows=New-Object Collections.Generic.List[object]
foreach($name in $expectedFiles){$path=Join-Path $partialRoot $name;if(-not(Test-Path -LiteralPath $path -PathType Leaf)-or(Get-Item -LiteralPath $path).Length-gt1048576){throw "OBS1 failure file missing/large: $name"};$rows.Add([pscustomobject]@{path=$name;bytes=[int64](Get-Item -LiteralPath $path).Length;sha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash})}
$failure=Get-Content -LiteralPath (Join-Path $partialRoot 'FAILURE.json') -Raw|ConvertFrom-Json;$detail=Get-OptionalString $failure 'detail'
Move-Item -LiteralPath $partialRoot -Destination $readyRoot
$gate=[ordered]@{schema='argos_ols2_obs1_signed_failure_gate_v1';collectedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_OLS2_OBS1_SIGNED_TERMINAL_FAILURE_COLLECTED';disposition='SIGNED_TERMINAL_FAILURE';requestId=$requestId;responseToken=$responseToken;endpointState=[string]$extracted.state;sourceRole=[string]$extracted.sourceRole;signedResponseVerified=$true;failureSchema=[string]$failure.schema;failureState=[string]$failure.state;failureDetail=$detail;responseFileCount=@($extracted.files).Count;responseFiles=$rows.ToArray();sourceZipBytes=$expectedBytes;sourceZipSha256=$expectedSha;collectedRoot=$readyRoot;optionalPropertyCasesPassed=2;pathState=[string]$pathGate.state;observationPassClaimed=$false;endpointMutationPerformed=$false;lotFileContentRead=$false;imageBytesRead=$false;sourceHashingPerformed=$false;taskOrProcessActionPerformed=$false;sourceDeletionPerformed=$false;waferActionPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}
[IO.File]::WriteAllText($terminalGate,(($gate|ConvertTo-Json -Depth 8)+[Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))
$gate|ConvertTo-Json -Depth 8

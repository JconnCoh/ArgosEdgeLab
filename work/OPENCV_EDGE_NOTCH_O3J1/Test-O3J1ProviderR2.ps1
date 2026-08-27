#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Gate,
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$InvocationManifest
)

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if(([bool]$Preflight)-eq([bool]$Gate)){throw 'Specify exactly one of -Preflight or -Gate.'}

function Assert-True([bool]$Condition,[string]$Message){if(-not$Condition){throw $Message}}
function Get-Sha([string]$Path){return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash}
function Resolve-ControlPath([string]$Root,[string]$Value){
    Assert-True (-not[string]::IsNullOrWhiteSpace($Value)-and$Value.IndexOfAny([char[]]'*?')-lt0) 'Unsafe test control path.'
    if([IO.Path]::IsPathRooted($Value)){return [IO.Path]::GetFullPath($Value)}
    return [IO.Path]::GetFullPath((Join-Path $Root $Value))
}
function Assert-Pin([string]$Path,[string]$Hash){
    Assert-True (Test-Path -LiteralPath $Path -PathType Leaf) "Pinned dependency is absent: $Path"
    Assert-True ((Get-Sha $Path)-eq$Hash) "Pinned dependency changed: $Path"
}
function Write-NewUtf8([string]$Path,[string]$Text){
    Assert-True (-not(Test-Path -LiteralPath $Path)) "Test refuses overwrite: $Path"
    [IO.File]::WriteAllText($Path,$Text,(New-Object Text.UTF8Encoding($false)))
}
function Write-NewJson([string]$Path,[object]$Value){
    Write-NewUtf8 $Path (($Value|ConvertTo-Json -Depth 12)+[Environment]::NewLine)
}
function New-Case([string]$Name,[string[]]$Allowed,[string[]]$Requested,[hashtable]$Contents,[int64]$MaximumFileBytes=4096,[int64]$MaximumTotalBytes=65536){
    $caseRoot=Join-Path $fixtureRoot $Name
    [void](New-Item -ItemType Directory -Path $caseRoot)
    foreach($key in @($Contents.Keys)){
        $leaf=Join-Path $caseRoot $key.Replace('/','\')
        [void](New-Item -ItemType Directory -Path (Split-Path -Parent $leaf) -Force)
        Write-NewUtf8 $leaf ([string]$Contents[$key])
    }
    $configPath=Join-Path $fixtureRoot ($Name+'.config.json')
    $invocationPath=Join-Path $fixtureRoot ($Name+'.invocation.json')
    Write-NewJson $configPath ([ordered]@{
        schema='argos_ocv03_review_json_provider_config_v1';revision=('TEST_'+$Name);state='FROZEN_CONFIG';approvedRootName=('TEST_'+$Name);approvedRootPath=$caseRoot;allowedExtension='.json';maximumFiles=[Math]::Max(1,$Allowed.Count);maximumFileBytes=$MaximumFileBytes;maximumTotalBytes=$MaximumTotalBytes;allowedRelativePaths=$Allowed;imageExtensionsAllowed=$false;sourceMutationAllowed=$false;taskOrProcessActionAllowed=$false;providerActivationAllowed=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false
    })
    Write-NewJson $invocationPath ([ordered]@{
        schema='argos_ocv03_review_json_provider_invocation_v1';revision=('TEST_'+$Name);approvedRootName=('TEST_'+$Name);relativePaths=$Requested;expectedFileCount=$Requested.Count;returnRawJsonText=$true;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false
    })
    return [pscustomobject]@{root=$caseRoot;config=$configPath;invocation=$invocationPath}
}
function Invoke-Positive([string]$Id,[object]$Case,[int]$ExpectedCount){
    $result=(& $provider -Collect -ConfigurationPath $Case.config -InvocationPath $Case.invocation)|ConvertFrom-Json
    Assert-True ([string]$result.state-eq'PASS_O3J1_EXACT_RESULT_JSON_COLLECTED') "$Id did not pass."
    Assert-True ([int]$result.fileCount-eq$ExpectedCount-and@($result.files).Count-eq$ExpectedCount) "$Id count changed."
    Assert-True ([bool]$result.exactAllowlistConsumed-and-not[bool]$result.imageBytesRead-and-not[bool]$result.sourceMutationPerformed-and-not[bool]$result.taskOrProcessActionPerformed-and-not[bool]$result.providerActivated) "$Id authority changed."
    return [ordered]@{caseId=$Id;state=[string]$result.state;fileCount=[int]$result.fileCount;totalBytes=[int64]$result.totalBytes;passed=$true}
}
function Invoke-Negative([string]$Id,[object]$Case,[string]$Pattern){
    $captured=$false;$message=''
    try{[void](& $provider -Collect -ConfigurationPath $Case.config -InvocationPath $Case.invocation)}catch{$message=[string]$_.Exception.Message;$captured=$message-match$Pattern}
    Assert-True $captured "$Id negative control was not rejected as expected. Observed: $message"
    return [ordered]@{caseId=$Id;rejected=$true;message=$message}
}

$projectRoot=Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
$controlPath=Resolve-ControlPath $projectRoot $InvocationManifest
$control=Get-Content -LiteralPath $controlPath -Raw|ConvertFrom-Json
Assert-True ([string]$control.schema-eq'argos_o3j1_provider_test_control_v1'-and[string]$control.state-eq'FROZEN_TEST_INPUT') 'Provider test control changed.'
Assert-True ([bool]$control.reviewOnly-and-not[bool]$control.trainingEligible-and-not[bool]$control.xmlEligible-and-not[bool]$control.productionEligible-and-not[bool]$control.productionRoutingEnabled) 'Provider test authority changed.'
$provider=Resolve-ControlPath $projectRoot ([string]$control.providerPath)
$liveConfig=Resolve-ControlPath $projectRoot ([string]$control.liveConfigurationPath)
$liveInvocation=Resolve-ControlPath $projectRoot ([string]$control.liveInvocationPath)
$gateOutput=Resolve-ControlPath $projectRoot ([string]$control.gateOutputPath)
$fixtureRoot=[IO.Path]::GetFullPath([string]$control.fixtureRoot)
Assert-Pin $provider ([string]$control.providerSha256)
Assert-Pin $liveConfig ([string]$control.liveConfigurationSha256)
Assert-Pin $liveInvocation ([string]$control.liveInvocationSha256)
Assert-True (-not(Test-Path -LiteralPath $fixtureRoot)) 'Provider test fixture root already exists.'
Assert-True (-not(Test-Path -LiteralPath $gateOutput)) 'Provider gate output already exists.'
Assert-True (($fixtureRoot.Length+32)-lt200) 'Provider fixture path budget failed.'
$tokens=$null;$parseErrors=$null
[void][Management.Automation.Language.Parser]::ParseFile($provider,[ref]$tokens,[ref]$parseErrors)
Assert-True (@($parseErrors).Count-eq0) 'Provider parser gate failed.'
$livePreflight=(& $provider -Preflight -ConfigurationPath $liveConfig -InvocationPath $liveInvocation)|ConvertFrom-Json
Assert-True ([string]$livePreflight.state-eq'PASS_O3J1_RESULT_JSON_PROVIDER_PREFLIGHT'-and[int]$livePreflight.requestedFileCount-eq13) 'Live provider preflight changed.'
Assert-True (-not[bool]$livePreflight.sourceFilesRead-and-not[bool]$livePreflight.imageBytesRead-and-not[bool]$livePreflight.mutationsPerformed) 'Live provider preflight mutated or read sources.'

if($Preflight){
    [ordered]@{schema='argos_o3j1_provider_test_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3J1_PROVIDER_TEST_PREFLIGHT';providerSha256=[string]$control.providerSha256;liveConfigurationSha256=[string]$control.liveConfigurationSha256;liveInvocationSha256=[string]$control.liveInvocationSha256;fixtureRoot=$fixtureRoot;gateOutput=$gateOutput;sourceFilesRead=$false;imageBytesRead=$false;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 6
    return
}

[void](New-Item -ItemType Directory -Path $fixtureRoot)
$positive=@();$negative=@()
$empty=@{}
$zero=New-Case 'ZERO' @() @() $empty
$positive+=Invoke-Positive 'ZERO' $zero 0
$oneContent=@{'one.json'="{`"case`":`"ONE`",`"value`":1}"}
$one=New-Case 'ONE' @('one.json') @('one.json') $oneContent
$positive+=Invoke-Positive 'ONE' $one 1
$manyAllowed=@();$manyContent=@{}
for($i=1;$i-le13;$i++){$relative=('slot{0:D2}/result.json'-f$i);$manyAllowed+=$relative;$manyContent[$relative]=('{"case":"MANY_13","index":'+$i+'}')}
$many=New-Case 'MANY_13' $manyAllowed $manyAllowed $manyContent
$positive+=Invoke-Positive 'MANY_13' $many 13

$rooted=New-Case 'ROOTED' @('C:\outside.json') @('C:\outside.json') $empty
$negative+=Invoke-Negative 'ROOTED' $rooted 'rooted relative path'
$traversal=New-Case 'TRAVERSAL' @('../outside.json') @('../outside.json') $empty
$negative+=Invoke-Negative 'TRAVERSAL' $traversal 'Traversal is not allowed'
$wildcard=New-Case 'WILDCARD' @('*.json') @('*.json') $empty
$negative+=Invoke-Negative 'WILDCARD' $wildcard 'wildcard relative path'
$nonJson=New-Case 'NON_JSON' @('note.txt') @('note.txt') $empty
$negative+=Invoke-Negative 'NON_JSON' $nonJson 'not JSON'
$unapprovedContent=@{'a.json'='{}';'b.json'='{}'}
$unapproved=New-Case 'UNAPPROVED' @('a.json') @('b.json') $unapprovedContent
$negative+=Invoke-Negative 'UNAPPROVED' $unapproved 'unapproved JSON path'
$duplicateContent=@{'a.json'='{}'}
$duplicate=New-Case 'DUPLICATE' @('a.json','a.json') @('a.json','a.json') $duplicateContent
$negative+=Invoke-Negative 'DUPLICATE' $duplicate 'contain duplicates'
$missing=New-Case 'MISSING' @('missing.json') @('missing.json') $empty
$negative+=Invoke-Negative 'MISSING' $missing 'Required JSON source is absent'
$malformedContent=@{'bad.json'='{not-json'}
$malformed=New-Case 'MALFORMED' @('bad.json') @('bad.json') $malformedContent
$negative+=Invoke-Negative 'MALFORMED' $malformed 'Invalid object passed|Invalid JSON primitive|Unexpected character|ConvertFrom-Json'
$oversizeContent=@{'large.json'=('x'*128)}
$oversize=New-Case 'OVERSIZE' @('large.json') @('large.json') $oversizeContent 16 64
$negative+=Invoke-Negative 'OVERSIZE' $oversize 'exceeds its byte limit'

$positiveIds=@($positive|ForEach-Object{[string]$_.caseId})
$negativeIds=@($negative|ForEach-Object{[string]$_.caseId})
Assert-True (@($control.requiredPositiveCases|Where-Object{$positiveIds-inotcontains[string]$_}).Count-eq0-and$positiveIds.Count-eq@($control.requiredPositiveCases).Count) 'Positive case set changed.'
Assert-True (@($control.requiredNegativeCases|Where-Object{$negativeIds-inotcontains[string]$_}).Count-eq0-and$negativeIds.Count-eq@($control.requiredNegativeCases).Count) 'Negative case set changed.'
$record=[ordered]@{schema='argos_o3j1_provider_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3J1_RESULT_JSON_PROVIDER_GATE';lifecycle='FROZEN_LOCAL_EVIDENCE';providerSha256=[string]$control.providerSha256;controlSha256=Get-Sha $controlPath;liveConfigurationSha256=[string]$control.liveConfigurationSha256;liveInvocationSha256=[string]$control.liveInvocationSha256;livePreflightState=[string]$livePreflight.state;positiveCases=$positive;negativeCases=$negative;positiveCaseCount=$positive.Count;negativeCaseCount=$negative.Count;zeroOneManyProven=$true;exactAllowlistProven=$true;pathTraversalRejected=$true;invalidJsonRejected=$true;missingJsonRejected=$true;oversizeJsonRejected=$true;fixtureRoot=$fixtureRoot;fixturePreserved=$true;jbodContacted=$false;sourceImageBytesRead=$false;imageBytesRead=$false;sourceMutationPerformed=$false;taskActions=0;processActions=0;providerActivationPerformed=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false}
Write-NewUtf8 $gateOutput (($record|ConvertTo-Json -Depth 12)+[Environment]::NewLine)
[ordered]@{schema='argos_o3j1_provider_gate_result_v1';state='PASS_O3J1_RESULT_JSON_PROVIDER_GATE';gateOutput=$gateOutput;gateSha256=Get-Sha $gateOutput;fixtureRoot=$fixtureRoot;fixturePreserved=$true;jbodContacted=$false;imageBytesRead=$false}|ConvertTo-Json -Depth 5

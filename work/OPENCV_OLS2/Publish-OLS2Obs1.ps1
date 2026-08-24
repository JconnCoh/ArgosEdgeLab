[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Publish
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Publish)) { throw 'Specify exactly one of -Preflight or -Publish.' }

function Get-FileHash {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$LiteralPath,[ValidateSet('SHA256')][string]$Algorithm='SHA256')
    $sha=[Security.Cryptography.SHA256]::Create()
    try{
        Get-Content -LiteralPath $LiteralPath -Encoding Byte -ReadCount 1048576|ForEach-Object{
            [byte[]]$block=@($_)
            if($block.Length-gt0){[void]$sha.TransformBlock($block,0,$block.Length,$block,0)}
        }
        [void]$sha.TransformFinalBlock([byte[]]@(),0,0)
        return [pscustomobject]@{Algorithm='SHA256';Hash=([BitConverter]::ToString($sha.Hash)).Replace('-','');Path=$LiteralPath}
    }finally{$sha.Dispose()}
}
function Write-NewJson([string]$Path,[object]$Value) {
    if (Test-Path -LiteralPath $Path) { throw "Refusing existing OBS1 publish evidence: $Path" }
    $temporary=$Path+'.partial'
    if (Test-Path -LiteralPath $temporary) { throw "Refusing existing OBS1 publish partial: $temporary" }
    [IO.File]::WriteAllText($temporary,(($Value|ConvertTo-Json -Depth 12)+[Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))
    Move-Item -LiteralPath $temporary -Destination $Path
}

$projectRoot='C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab'
$requestId='REQ_O2OBS1'
$workRoot=Join-Path $projectRoot 'work\OPENCV_OLS2'
$source='C:\O2Z\REQ_O2OBS1.ready.zip'
$pathGatePath=Join-Path $workRoot 'OBS1_PREPUBLICATION_PATH_GATE.json'
$packageGatePath=Join-Path $workRoot 'OBS1_EXACT_PACKAGE_GATE.json'
$preactionPath=Join-Path $workRoot 'PREACTION_OBS1_PUBLISH.json'
$priorFailurePath=Join-Path $workRoot 'OLS2_SIGNED_FAILURE_GATE_R2.json'
$intentPath=Join-Path $workRoot 'POST_FAILURE_OBSERVATION_INTENT_R2.json'
$historyPath=Join-Path $projectRoot 'work\ARGOS_HISTORY_NO_REPEAT_AUDIT_20260820.json'
$preactionTool=Join-Path $projectRoot 'utilities\Confirm-ArgosZeroRecurrencePreaction.ps1'
$intentTool=Join-Path $projectRoot 'utilities\Confirm-ArgosRecoveryIntent.ps1'
$pathTool=Join-Path $projectRoot 'utilities\Confirm-ArgosPathBudget.ps1'
$shareRoot='\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$queueRoot='U:\ProjectPortalRO\requests'
$processedPath=Join-Path (Join-Path $queueRoot 'processed') ($requestId+'.ready.zip')
$readyPath=Join-Path $queueRoot ($requestId+'.ready.zip')
$uploadPath=$readyPath+'.upload'
$archiveRoot=Join-Path $workRoot 'obs1_published'
$archivePath=Join-Path $archiveRoot ($requestId+'.ready.zip')
$publishGatePath=Join-Path $workRoot 'OBS1_PUBLISH_GATE.json'

foreach($path in @($source,$pathGatePath,$packageGatePath,$preactionPath,$priorFailurePath,$intentPath,$historyPath,$preactionTool,$intentTool,$pathTool)){
    if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "OLS2 OBS1 publish input missing: $path"}
}
if(-not(Test-Path -LiteralPath $queueRoot -PathType Container)){throw 'OLS2 OBS1 request queue is unavailable.'}
foreach($path in @($processedPath,$readyPath,$uploadPath,$archivePath,$publishGatePath)){if(Test-Path -LiteralPath $path){throw "OLS2 OBS1 one-shot publication path already exists: $path"}}

& $intentTool -IntentPath $intentPath -ProjectRoot $projectRoot -Preflight | Out-Null
& $preactionTool -AuditPath $historyPath -ContractPath $preactionPath -ProjectRoot $projectRoot -Preflight | Out-Null
$sourceSha256=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
$sourceBytes=[int64](Get-Item -LiteralPath $source).Length
$pathGate=Get-Content -LiteralPath $pathGatePath -Raw|ConvertFrom-Json
$packageGate=Get-Content -LiteralPath $packageGatePath -Raw|ConvertFrom-Json
$priorFailure=Get-Content -LiteralPath $priorFailurePath -Raw|ConvertFrom-Json
if([string]$pathGate.state -ne 'PASS_PROJECT_PORTAL_PREPUBLICATION_PATH_GATE' -or [string]$pathGate.requestId -ne $requestId -or [string]$pathGate.requestZipSha256 -ne $sourceSha256 -or [int64]$pathGate.requestZipBytes -ne $sourceBytes -or -not[bool]$pathGate.publicationAuthorized -or [int]$pathGate.maximumRequestsAuthorized -ne 1 -or [bool]$pathGate.retryOnFailure){throw 'OLS2 OBS1 prepublication path contract changed.'}
if([string]$packageGate.state -ne 'PASS_OLS2_OBS1_EXACT_SIGNED_DATA_PULL_PACKAGE' -or [string]$packageGate.requestId -ne $requestId -or [string]$packageGate.finalZipSha256 -ne $sourceSha256 -or [int64]$packageGate.finalZipBytes -ne $sourceBytes -or -not[bool]$packageGate.exactExtractedSignaturePassed -or [int]$packageGate.requestedImageOrBinaryFiles -ne 0){throw 'OLS2 OBS1 exact package contract changed.'}
if([string]$priorFailure.state -ne 'PASS_OLS2_SIGNED_TERMINAL_FAILURE_R2_COLLECTED' -or [string]$priorFailure.endpointState -ne 'FAILED' -or -not[bool]$priorFailure.signedResponseVerified -or -not[bool]$priorFailure.terminalFailureRequiresDirectObservationBeforeMutation){throw 'OLS2 prior signed failure evidence changed.'}
$queueItems=@(Get-ChildItem -LiteralPath $queueRoot -File -ErrorAction Stop|Where-Object{$_.Name -match '\.ready\.zip(?:\.upload)?$'})
if($queueItems.Count -ne 0){throw ('OLS2 OBS1 refuses a nonempty portal queue: '+(($queueItems|Select-Object -First 5|ForEach-Object Name)-join ', '))}
$paths=@($source,$uploadPath,$readyPath,$processedPath,$archivePath,$publishGatePath)
$pathBudget=& $pathTool -CandidatePath $paths -ReservedSuffixCharacters 32 -AsJson|ConvertFrom-Json
if([string]$pathBudget.state -ne 'PASS_PATH_BUDGET'){throw 'OLS2 OBS1 publication path budget failed.'}
$existingU=Get-PSDrive U -ErrorAction SilentlyContinue
if($null -eq $existingU -or [string]$existingU.Provider.Name -ne 'FileSystem' -or [string]::IsNullOrWhiteSpace([string]$existingU.DisplayRoot) -or -not([IO.Path]::GetFullPath([string]$existingU.DisplayRoot).TrimEnd('\')).Equals([IO.Path]::GetFullPath($shareRoot).TrimEnd('\'),[StringComparison]::OrdinalIgnoreCase)){throw 'OLS2 OBS1 U: mapping is absent or not the pinned engineering share.'}

if($Preflight){
    [ordered]@{schema='argos_ols2_obs1_publish_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_OLS2_OBS1_ONE_SHOT_PUBLISH_PREFLIGHT';requestId=$requestId;sourceSha256=$sourceSha256;sourceBytes=$sourceBytes;pendingRequests=$queueItems.Count;mappedDriveRoot=[string]$existingU.Root;mappedDriveDisplayRoot=[string]$existingU.DisplayRoot;priorTerminalRequestId=[string]$priorFailure.requestId;priorTerminalResponseId=[string]$priorFailure.responseToken;mutationsPerformed=$false;installedChanges=0;imageBytesRequested=0;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 5
    return
}

[void](New-Item -ItemType Directory -Path $archiveRoot -Force)
Copy-Item -LiteralPath $source -Destination $uploadPath -ErrorAction Stop
if([int64](Get-Item -LiteralPath $uploadPath).Length -ne $sourceBytes -or (Get-FileHash -LiteralPath $uploadPath -Algorithm SHA256).Hash -ne $sourceSha256){throw 'OLS2 OBS1 uploaded bytes changed.'}
Move-Item -LiteralPath $uploadPath -Destination $readyPath -ErrorAction Stop
if([int64](Get-Item -LiteralPath $readyPath).Length -ne $sourceBytes -or (Get-FileHash -LiteralPath $readyPath -Algorithm SHA256).Hash -ne $sourceSha256){throw 'OLS2 OBS1 published ready bytes changed.'}
Copy-Item -LiteralPath $source -Destination $archivePath -ErrorAction Stop
if((Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash -ne $sourceSha256){throw 'OLS2 OBS1 publication archive changed.'}
$result=[ordered]@{schema='argos_ols2_obs1_publish_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_OLS2_OBS1_EXACT_SIGNED_READ_ONLY_REQUEST_PUBLISHED_CREATE_NEW';requestId=$requestId;source=$source;sourceSha256=$sourceSha256;sourceBytes=$sourceBytes;publishedPath=$readyPath;publishedSha256=(Get-FileHash -LiteralPath $readyPath -Algorithm SHA256).Hash;archivePath=$archivePath;pendingBefore=$queueItems.Count;mappedDriveRoot=[string]$existingU.Root;mappedDriveDisplayRoot=[string]$existingU.DisplayRoot;maximumRequests=1;retryOnFailure=$false;overwritePerformed=$false;taskActions=@();processActions=@();installedChanges=0;imageBytesRequested=0;reviewOnly=$true;productionRoutingEnabled=$false}
Write-NewJson $publishGatePath $result
$result|ConvertTo-Json -Depth 7

#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight)

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if(-not$Preflight){throw 'O3F15L2 response discovery is preflight-only.'}
function Require([bool]$Condition,[string]$Message){if(-not$Condition){throw $Message}}
function Sha([string]$Path){$stream=[IO.File]::Open($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite);$hash=[Security.Cryptography.SHA256]::Create();try{return([BitConverter]::ToString($hash.ComputeHash($stream))).Replace('-','')}finally{$hash.Dispose();$stream.Dispose()}}

$signGatePath=Join-Path $PSScriptRoot 'O3F15L2_SIGN_GATE.json'
$publishGatePath=Join-Path $PSScriptRoot 'O3F15L2_PUBLISH_GATE.json'
foreach($path in @($signGatePath,$publishGatePath)){Require (Test-Path -LiteralPath $path -PathType Leaf) "O3F15L2 response-discovery dependency absent: $path"}
$signGate=Get-Content -LiteralPath $signGatePath -Raw|ConvertFrom-Json
$publishGate=Get-Content -LiteralPath $publishGatePath -Raw|ConvertFrom-Json
$requestId=[string]$signGate.requestId
Require ([string]$signGate.state-eq'PASS_O3F15L2_SIGNED_EXACT_978_FRONT_LAUNCH_PACKAGE') 'O3F15L2 sign gate changed.'
Require ([string]$publishGate.state-eq'PASS_O3F15L2_PUBLISHED_EXACTLY_ONCE_AWAITING_SIGNED_LAUNCH_RESPONSE'-and[string]$publishGate.requestId-eq$requestId-and[string]$publishGate.publishedSha256-eq[string]$signGate.packageZipSha256) 'O3F15L2 publication gate changed.'
$publishedUtc=[DateTime]::Parse([string]$publishGate.createdUtc).ToUniversalTime()
$cohortStartUtc=$publishedUtc.AddMinutes(-1)
$expectedShare='\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$psDrive=Get-PSDrive U -ErrorAction Stop
$disk=Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='U:'" -ErrorAction Stop
Require ([string]$psDrive.DisplayRoot-eq$expectedShare-and[string]$disk.ProviderName-eq$expectedShare-and[int]$disk.DriveType-eq4) 'O3F15L2 qualified persistent U: mapping changed.'
$root='U:\ProjectPortalRO\responses'
Require (Test-Path -LiteralPath $root -PathType Container) 'O3F15L2 response root unavailable.'
$candidates=New-Object Collections.Generic.List[string]
foreach($path in [IO.Directory]::EnumerateFiles($root,'*.ready.zip',[IO.SearchOption]::TopDirectoryOnly)){
    $item=Get-Item -LiteralPath $path
    if($item.LastWriteTimeUtc-lt$cohortStartUtc){continue}
    $candidates.Add($item.FullName)
    if($candidates.Count-ge21){break}
}
Require ($candidates.Count-le20) 'O3F15L2 post-publication response cohort exceeded 20 ZIPs.'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$matches=New-Object Collections.Generic.List[object]
foreach($path in @($candidates)){
    $item=Get-Item -LiteralPath $path
    $archive=[IO.Compression.ZipFile]::OpenRead($item.FullName)
    try{
        $entry=$archive.GetEntry('PORTAL_RESPONSE_MANIFEST.json')
        if($null-eq$entry-or$entry.Length-gt65536){continue}
        $reader=New-Object IO.StreamReader($entry.Open(),[Text.Encoding]::UTF8,$true)
        try{$manifest=$reader.ReadToEnd()|ConvertFrom-Json}finally{$reader.Dispose()}
        if([string]$manifest.requestId-eq$requestId){$matches.Add([pscustomobject]@{responseId=[string]$manifest.responseId;requestId=[string]$manifest.requestId;sourceRole=[string]$manifest.sourceRole;endpointState=[string]$manifest.state;sourceZip=$item.FullName;sourceZipBytes=[int64]$item.Length;sourceZipSha256=Sha $item.FullName;lastWriteUtc=$item.LastWriteTimeUtc.ToString('o');manifestEntryBytes=[int64]$entry.Length})}
    }finally{$archive.Dispose()}
}
Require ($matches.Count-le1) 'O3F15L2 found multiple matching response ZIPs.'
[ordered]@{schema='argos_ocv03_o3f15l2_response_discovery_v1';observedUtc=[DateTime]::UtcNow.ToString('o');state=$(if($matches.Count-eq1){'PASS_O3F15L2_ONE_MATCHING_RESPONSE_LOCATED'}else{'PENDING_O3F15L2_MATCHING_RESPONSE'});requestId=$requestId;publishedUtc=$publishedUtc.ToString('o');boundedCandidateZipCount=$candidates.Count;matchingResponseCount=$matches.Count;match=$(if($matches.Count-eq1){$matches[0]}else{$null});remoteMutationsPerformed=$false;requestRepublished=$false;requestRetryAuthorized=$false;imageBytesRead=$false;existingProcessesQueried=$false;taskActions=0;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 8

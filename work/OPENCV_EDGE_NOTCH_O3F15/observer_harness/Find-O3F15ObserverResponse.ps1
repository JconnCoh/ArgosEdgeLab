#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$InvocationManifest,
    [switch]$Preflight
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (-not $Preflight) { throw 'O3F15 observer response discovery is preflight-only.' }

function Require([bool]$Condition,[string]$Message) {
    if (-not $Condition) { throw $Message }
}
function Required([object]$Object,[string]$Name) {
    Require ($null -ne $Object) "Required object is null while reading $Name."
    Require ($Object.PSObject.Properties.Name -contains $Name) "Required property is absent: $Name"
    return $Object.$Name
}
function Sha256([string]$Path) {
    $stream = [IO.File]::Open($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
    $hash = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($hash.ComputeHash($stream))).Replace('-','') }
    finally { $hash.Dispose(); $stream.Dispose() }
}
function Resolve-File([string]$Project,[string]$Path,[string]$Label) {
    $resolved = $Path
    if (-not [IO.Path]::IsPathRooted($resolved)) { $resolved = Join-Path $Project $resolved.Replace('/','\') }
    $resolved = [IO.Path]::GetFullPath($resolved)
    Require (Test-Path -LiteralPath $resolved -PathType Leaf) "$Label is absent: $resolved"
    return $resolved
}

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
$invocationPath = [IO.Path]::GetFullPath($InvocationManifest)
Require (Test-Path -LiteralPath $invocationPath -PathType Leaf) 'O3F15 observer response-discovery invocation is absent.'
$invocation = Get-Content -LiteralPath $invocationPath -Raw | ConvertFrom-Json
Require ([string](Required $invocation 'schema') -eq 'argos_ocv03_o3f15_observer_response_discovery_invocation_v1') 'O3F15 observer discovery invocation schema changed.'
Require ([string](Required $invocation 'state') -eq 'FROZEN_EXACT_RESPONSE_DISCOVERY') 'O3F15 observer discovery invocation is not frozen.'
$flow = [string](Required $invocation 'flow')
Require ($flow -in @('P1','F1','T1')) 'O3F15 observer discovery flow changed.'
Require ([string](Required $invocation 'powerShellScriptSha256') -eq (Sha256 $PSCommandPath)) 'O3F15 observer discovery invocation does not pin this exact script.'
Require (-not [bool](Required $invocation 'requestRetryAuthorized') -and -not [bool](Required $invocation 'requestRepublishAuthorized')) 'O3F15 observer discovery changed retry authority.'
Require ([bool](Required $invocation 'reviewOnly') -and -not [bool](Required $invocation 'productionRoutingEnabled')) 'O3F15 observer discovery authority widened.'

$publicationPath = Resolve-File $project ([string](Required $invocation 'publicationGate')) 'O3F15 observer publication gate'
Require ((Sha256 $publicationPath) -eq [string](Required $invocation 'publicationGateSha256')) 'O3F15 observer publication gate changed.'
$publication = Get-Content -LiteralPath $publicationPath -Raw | ConvertFrom-Json
$requestId = [string](Required $invocation 'requestId')
Require ([string](Required $publication 'state') -eq ('PASS_O3F15_' + $flow + '_OBSERVER_PUBLISHED_ONCE_AWAITING_SIGNED_RESPONSE')) 'O3F15 observer publication state changed.'
Require ([string](Required $publication 'requestId') -eq $requestId -and [int](Required $publication 'publicationCount') -eq 1) 'O3F15 observer publication identity changed.'
Require (-not [bool](Required $publication 'requestRetryAuthorized') -and -not [bool](Required $publication 'gatewayAcceptanceIsExecutionEvidence')) 'O3F15 observer publication semantics changed.'
$publishedUtc = [DateTime]::Parse([string](Required $publication 'createdUtc')).ToUniversalTime()
$cohortStartUtc = $publishedUtc.AddMinutes(-1)

$expectedShare = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$drive = Get-PSDrive -Name U -PSProvider FileSystem -ErrorAction Stop
$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='U:'" -ErrorAction Stop
Require ([string]$drive.DisplayRoot -eq $expectedShare -and [string]$disk.ProviderName -eq $expectedShare -and [int]$disk.DriveType -eq 4) 'O3F15 observer qualified persistent U: mapping changed.'
$responseRoot = 'U:\ProjectPortalRO\responses'
Require (Test-Path -LiteralPath $responseRoot -PathType Container) 'O3F15 observer response root is unavailable.'
$candidates = New-Object Collections.Generic.List[string]
foreach ($path in [IO.Directory]::EnumerateFiles($responseRoot,'*.ready.zip',[IO.SearchOption]::TopDirectoryOnly)) {
    $item = Get-Item -LiteralPath $path
    if ($item.LastWriteTimeUtc -lt $cohortStartUtc) { continue }
    $candidates.Add($item.FullName)
    if ($candidates.Count -ge 21) { break }
}
Require ($candidates.Count -le 20) 'O3F15 observer post-publication response cohort exceeded 20 ZIPs.'

Add-Type -AssemblyName System.IO.Compression.FileSystem
$matches = New-Object Collections.Generic.List[object]
foreach ($path in @($candidates)) {
    $item = Get-Item -LiteralPath $path
    $archive = [IO.Compression.ZipFile]::OpenRead($item.FullName)
    try {
        $entry = $archive.GetEntry('PORTAL_RESPONSE_MANIFEST.json')
        if ($null -eq $entry -or [int64]$entry.Length -gt 65536) { continue }
        $reader = New-Object IO.StreamReader($entry.Open(),[Text.Encoding]::UTF8,$true)
        try { $manifest = $reader.ReadToEnd() | ConvertFrom-Json }
        finally { $reader.Dispose() }
        if ([string](Required $manifest 'requestId') -eq $requestId) {
            $matches.Add([pscustomobject]@{
                responseId=[string](Required $manifest 'responseId'); requestId=$requestId
                sourceRole=[string](Required $manifest 'sourceRole'); endpointState=[string](Required $manifest 'state')
                sourceZip=$item.FullName; sourceZipBytes=[int64]$item.Length; sourceZipSha256=Sha256 $item.FullName
                lastWriteUtc=$item.LastWriteTimeUtc.ToString('o'); manifestEntryBytes=[int64]$entry.Length
            })
        }
    }
    finally { $archive.Dispose() }
}
Require ($matches.Count -le 1) 'O3F15 observer found multiple matching response ZIPs.'
$state = 'PENDING_O3F15_' + $flow + '_OBSERVER_MATCHING_RESPONSE'
$match = $null
if ($matches.Count -eq 1) {
    $state = 'PASS_O3F15_' + $flow + '_OBSERVER_ONE_MATCHING_RESPONSE_LOCATED'
    $match = $matches[0]
}
[ordered]@{
    schema='argos_ocv03_o3f15_observer_response_discovery_v1'; observedUtc=[DateTime]::UtcNow.ToString('o')
    state=$state; flow=$flow; requestId=$requestId; publishedUtc=$publishedUtc.ToString('o')
    boundedCandidateZipCount=$candidates.Count; matchingResponseCount=$matches.Count; match=$match
    remoteMutationsPerformed=$false; requestRepublished=$false; requestRetryAuthorized=$false
    imageBytesRead=$false; existingProcessesQueried=$false; taskActions=0; providerActivated=$false
    reviewOnly=$true; productionRoutingEnabled=$false
} | ConvertTo-Json -Depth 10

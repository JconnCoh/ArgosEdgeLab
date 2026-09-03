#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Require([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Sha-Shared([string]$Path) {
    $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try { ([BitConverter]::ToString($algorithm.ComputeHash($stream))).Replace('-','') }
    finally { $algorithm.Dispose(); $stream.Dispose() }
}

Require $Preflight 'O3F15L3 response discovery is preflight-only.'
Require ([string]$PSVersionTable.PSEdition -ceq 'Desktop' -and [int]$PSVersionTable.PSVersion.Major -eq 5 -and [int]$PSVersionTable.PSVersion.Minor -eq 1) 'O3F15L3 response discovery requires exact Windows PowerShell 5.1.'
$signGatePath = Join-Path $PSScriptRoot 'O3F15L3_SIGN_GATE.json'
$publishGatePath = Join-Path $PSScriptRoot 'O3F15L3_PUBLISH_GATE.json'
foreach ($path in @($signGatePath,$publishGatePath)) { Require (Test-Path -LiteralPath $path -PathType Leaf) "O3F15L3 response-discovery dependency absent: $path" }
$signGate = Get-Content -LiteralPath $signGatePath -Raw | ConvertFrom-Json
$publishGate = Get-Content -LiteralPath $publishGatePath -Raw | ConvertFrom-Json
$requestId = [string]$signGate.requestId
Require ([string]$signGate.state -ceq 'PASS_O3F15L3_SIGNED_PREFLIGHT_DIAGNOSTIC_PACKAGE') 'O3F15L3 sign gate changed.'
Require ([string]$publishGate.state -ceq 'PASS_O3F15L3_PUBLISHED_EXACTLY_ONCE_AWAITING_SIGNED_DIAGNOSTIC_RESPONSE' -and [string]$publishGate.requestId -ceq $requestId -and [string]$publishGate.publishedSha256 -ceq [string]$signGate.packageZipSha256 -and [int]$publishGate.publicationCount -eq 1 -and -not [bool]$publishGate.automaticRetryAuthorized) 'O3F15L3 publication gate changed.'
$publishedUtc = [DateTime]::Parse([string]$publishGate.createdUtc).ToUniversalTime()
$cohortStartUtc = $publishedUtc.AddMinutes(-1)
$expectedShare = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$drive = Get-PSDrive -Name U -PSProvider FileSystem -ErrorAction Stop
$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='U:'" -ErrorAction Stop
Require ([string]$drive.DisplayRoot -ceq $expectedShare -and [string]$disk.ProviderName -ceq $expectedShare -and [int]$disk.DriveType -eq 4) 'O3F15L3 qualified persistent U: mapping changed.'
$root = 'U:\ProjectPortalRO\responses'
Require (Test-Path -LiteralPath $root -PathType Container) 'O3F15L3 response root unavailable.'
$candidates = New-Object Collections.Generic.List[string]
foreach ($path in [IO.Directory]::EnumerateFiles($root, '*.ready.zip', [IO.SearchOption]::TopDirectoryOnly)) {
    $item = Get-Item -LiteralPath $path
    if ($item.LastWriteTimeUtc -lt $cohortStartUtc) { continue }
    $candidates.Add($item.FullName)
    if ($candidates.Count -ge 21) { break }
}
Require ($candidates.Count -le 20) 'O3F15L3 post-publication response cohort exceeded 20 ZIPs.'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$matches = New-Object Collections.Generic.List[object]
foreach ($path in @($candidates)) {
    $item = Get-Item -LiteralPath $path
    $archive = [IO.Compression.ZipFile]::OpenRead($item.FullName)
    try {
        $entry = $archive.GetEntry('PORTAL_RESPONSE_MANIFEST.json')
        if ($null -eq $entry -or $entry.Length -gt 65536) { continue }
        $reader = New-Object IO.StreamReader($entry.Open(), [Text.Encoding]::UTF8, $true)
        try { $manifest = $reader.ReadToEnd() | ConvertFrom-Json } finally { $reader.Dispose() }
        if ([string]$manifest.requestId -ceq $requestId) {
            $matches.Add([pscustomobject]@{ responseId=[string]$manifest.responseId; requestId=[string]$manifest.requestId; sourceRole=[string]$manifest.sourceRole; endpointState=[string]$manifest.state; sourceZip=$item.FullName; sourceZipBytes=[int64]$item.Length; sourceZipSha256=Sha-Shared $item.FullName; lastWriteUtc=$item.LastWriteTimeUtc.ToString('o'); manifestEntryBytes=[int64]$entry.Length })
        }
    } finally { $archive.Dispose() }
}
Require ($matches.Count -le 1) 'O3F15L3 found multiple matching response ZIPs.'
[ordered]@{ schema='argos_ocv03_o3f15l3_response_discovery_v1'; observedUtc=[DateTime]::UtcNow.ToString('o'); state=$(if ($matches.Count -eq 1) {'PASS_O3F15L3_ONE_MATCHING_RESPONSE_LOCATED'} else {'PENDING_O3F15L3_MATCHING_RESPONSE'}); requestId=$requestId; publishedUtc=$publishedUtc.ToString('o'); boundedCandidateZipCount=$candidates.Count; matchingResponseCount=$matches.Count; match=$(if ($matches.Count -eq 1) {$matches[0]} else {$null}); remoteMutationsPerformed=$false; requestRepublished=$false; requestRetryAuthorized=$false; imageBytesRead=$false; existingProcessesQueried=$false; taskActions=0; providerActivated=$false; reviewOnly=$true; productionRoutingEnabled=$false } | ConvertTo-Json -Depth 8

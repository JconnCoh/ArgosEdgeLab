#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (-not $Preflight) { throw 'Specify -Preflight.' }

$requestId = 'REQ_R18R2'
$requestSha256 = 'E541EB7FCCD19A04BFE401D6FCFB70B7976C0F47E9F4F1AD8E1FCC1626EEF300'
$shareRoot = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$requestRoot = 'U:\ProjectPortalRO\requests'
$responseRoot = 'U:\ProjectPortalRO\responses'
$processedPath = Join-Path (Join-Path $requestRoot 'processed') ($requestId + '.ready.zip')

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Read-ZipEntryText([IO.Compression.ZipArchive]$Archive, [string]$Name) {
    $entry = $Archive.GetEntry($Name)
    if ($null -eq $entry -or [int64]$entry.Length -gt 1048576) { return $null }
    $reader = New-Object IO.StreamReader($entry.Open(), (New-Object Text.UTF8Encoding($false, $true)))
    try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
}

$drive = Get-PSDrive -Name U -ErrorAction Stop
$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='U:'"
Assert-True ($drive.DisplayRoot -eq $shareRoot -and [string]$disk.ProviderName -eq $shareRoot -and [int]$disk.DriveType -eq 4) 'R18R2 persistent U mapping changed.'
Assert-True (Test-Path -LiteralPath $processedPath -PathType Leaf) 'Processed R18R2 request copy is absent.'
Assert-True ((Get-FileHash -LiteralPath $processedPath -Algorithm SHA256).Hash -eq $requestSha256) 'Processed R18R2 request hash changed.'
Assert-True (Test-Path -LiteralPath $responseRoot -PathType Container) 'Portal response root is unavailable.'

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$responseFiles = @(Get-ChildItem -LiteralPath $responseRoot -File -Filter '*.ready.zip' -ErrorAction Stop | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 500)
$matches = New-Object Collections.Generic.List[object]
foreach ($candidate in $responseFiles) {
    try {
        $archive = [IO.Compression.ZipFile]::OpenRead($candidate.FullName)
        try {
            $text = Read-ZipEntryText -Archive $archive -Name 'PORTAL_RESPONSE_MANIFEST.json'
            if ($null -eq $text) { continue }
            $manifest = $text | ConvertFrom-Json
            if ([string]$manifest.requestId -eq $requestId) {
                $matches.Add([pscustomobject]@{
                    responseId = [string]$manifest.responseId
                    requestId = [string]$manifest.requestId
                    sourceRole = [string]$manifest.sourceRole
                    state = [string]$manifest.state
                    signerThumbprint = ([string]$manifest.signerThumbprint).Replace(' ','').ToUpperInvariant()
                    path = $candidate.FullName
                    bytes = [int64]$candidate.Length
                    sha256 = (Get-FileHash -LiteralPath $candidate.FullName -Algorithm SHA256).Hash
                })
            }
        } finally { $archive.Dispose() }
    } catch { continue }
}
Assert-True ($matches.Count -le 1) 'Multiple responses match R18R2.'
[ordered]@{
    schema = 'argos_r18r2_response_discovery_v1'
    checkedUtc = [DateTime]::UtcNow.ToString('o')
    state = $(if ($matches.Count -eq 1) { 'PASS_R18R2_MATCHING_RESPONSE_FOUND' } else { 'WAIT_R18R2_MATCHING_RESPONSE' })
    requestId = $requestId
    responseFilesScanned = $responseFiles.Count
    matchingResponses = $matches.Count
    match = $(if ($matches.Count -eq 1) { $matches[0] } else { $null })
    mutationsPerformed = $false
    requestRetried = $false
    pixelsDecoded = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
} | ConvertTo-Json -Depth 8

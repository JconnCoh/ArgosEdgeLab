#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Gate
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ([bool]$Preflight -eq [bool]$Gate) {
    throw 'Specify exactly one of -Preflight or -Gate.'
}

$requestId = 'REQ_20260827T185500111Z_62629419O3J1'
$expectedShareRoot = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$responsesRoot = 'U:\ProjectPortalRO\responses'
$observationPath = Join-Path $PSScriptRoot 'O3J1_MATCHING_RESPONSE_OBSERVATION.json'
$publishGatePath = Join-Path $PSScriptRoot 'O3J1_PUBLISH_GATE.json'
$expectedPublishGateSha256 = '4CB3D072893470744C49E79C160E4452E93CC38DF2DAB909459811F609721828'
$maximumResponseZips = 500
$maximumResponseZipBytes = 16777216
$maximumManifestBytes = 65536

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw $Message
    }
}

function Normalize-UncRoot {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ''
    }
    return $Value.Trim().TrimEnd('\')
}

function Get-Sha256 {
    param([string]$Path)
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '')
    }
    finally {
        $sha.Dispose()
        $stream.Dispose()
    }
}

function Write-JsonCreateNew {
    param([string]$Path, [object]$Value)
    $json = ($Value | ConvertTo-Json -Depth 12) + [Environment]::NewLine
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes($json)
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush()
    }
    finally {
        $stream.Dispose()
    }
}

Assert-True (Test-Path -LiteralPath $publishGatePath -PathType Leaf) 'O3J1 publication gate is absent.'
Assert-True ((Get-Sha256 -Path $publishGatePath) -eq $expectedPublishGateSha256) 'O3J1 publication gate changed.'
$publishGate = Get-Content -LiteralPath $publishGatePath -Raw | ConvertFrom-Json
Assert-True ([string]$publishGate.state -eq 'PASS_O3J1_PUBLISHED_ONCE' -and [string]$publishGate.requestId -eq $requestId) 'O3J1 publication identity changed.'
Assert-True ([int]$publishGate.publicationCount -eq 1 -and -not [bool]$publishGate.requestRetryAuthorized) 'O3J1 publication count or retry authority changed.'

$psDrive = Get-PSDrive -Name U -PSProvider FileSystem -ErrorAction Stop
$displayRoot = Normalize-UncRoot -Value ([string]$psDrive.DisplayRoot)
Assert-True ($displayRoot.Equals((Normalize-UncRoot -Value $expectedShareRoot), [StringComparison]::OrdinalIgnoreCase)) 'Persistent U: PowerShell DisplayRoot changed.'
$logicalDisk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='U:'" -ErrorAction Stop
Assert-True ($null -ne $logicalDisk) 'Persistent U: operating-system logical disk is absent.'
$providerName = Normalize-UncRoot -Value ([string]$logicalDisk.ProviderName)
Assert-True ($providerName.Equals((Normalize-UncRoot -Value $expectedShareRoot), [StringComparison]::OrdinalIgnoreCase)) 'Persistent U: logical-disk ProviderName changed.'
Assert-True ([int]$logicalDisk.DriveType -eq 4) 'Persistent U: logical disk is not a network drive.'
Assert-True (Test-Path -LiteralPath $responsesRoot -PathType Container) 'Persistent U: response root is absent.'

$responseZips = @(Get-ChildItem -LiteralPath $responsesRoot -File -Filter '*.ready.zip' -Force -ErrorAction Stop)
Assert-True ($responseZips.Count -le $maximumResponseZips) 'Response ZIP count exceeds the bounded observation limit.'

Add-Type -AssemblyName System.IO.Compression.FileSystem
$matches = New-Object Collections.Generic.List[object]
foreach ($responseZip in $responseZips) {
    if ([int64]$responseZip.Length -gt $maximumResponseZipBytes) {
        continue
    }
    $archive = [IO.Compression.ZipFile]::OpenRead($responseZip.FullName)
    try {
        $manifestEntry = $archive.GetEntry('PORTAL_RESPONSE_MANIFEST.json')
        if ($null -eq $manifestEntry -or [int64]$manifestEntry.Length -gt $maximumManifestBytes) {
            continue
        }
        $reader = New-Object IO.StreamReader($manifestEntry.Open(), [Text.Encoding]::UTF8, $true)
        try {
            $manifest = $reader.ReadToEnd() | ConvertFrom-Json
        }
        finally {
            $reader.Dispose()
        }
        if ([string]$manifest.requestId -ne $requestId) {
            continue
        }
        $matches.Add([pscustomobject]@{
            responseId = [string]$manifest.responseId
            sourceZip = $responseZip.FullName
            sourceZipBytes = [int64]$responseZip.Length
            sourceZipSha256 = Get-Sha256 -Path $responseZip.FullName
            manifestState = [string]$manifest.state
            sourceRole = [string]$manifest.sourceRole
            manifestFileCount = @($manifest.files).Count
            zipEntryCount = @($archive.Entries).Count
        })
    }
    finally {
        $archive.Dispose()
    }
}

Assert-True ($matches.Count -eq 1) "Expected exactly one response manifest for $requestId; observed $($matches.Count)."
$match = $matches[0]
Assert-True ([string]$match.responseId -match '^R_[A-Z0-9]+_[0-9]{17}_[a-f0-9]{8}$') 'Matching response ID is malformed.'
Assert-True ([string]$match.manifestState -eq 'PASS_MAINTENANCE_PATCH') 'Matching response is not terminal PASS_MAINTENANCE_PATCH.'
Assert-True ([string]$match.sourceRole -eq 'JBOD') 'Matching response source role is not JBOD.'

$result = [ordered]@{
    schema = 'argos_o3j1_matching_response_observation_v1'
    observedUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_O3J1_EXACT_MATCHING_RESPONSE_OBSERVED'
    requestId = $requestId
    responseId = [string]$match.responseId
    sourceZip = [string]$match.sourceZip
    sourceZipBytes = [int64]$match.sourceZipBytes
    sourceZipSha256 = [string]$match.sourceZipSha256
    manifestState = [string]$match.manifestState
    sourceRole = [string]$match.sourceRole
    manifestFileCount = [int]$match.manifestFileCount
    zipEntryCount = [int]$match.zipEntryCount
    responseZipCountExamined = $responseZips.Count
    matchingResponseCount = $matches.Count
    maximumResponseZips = $maximumResponseZips
    maximumResponseZipBytes = $maximumResponseZipBytes
    maximumManifestBytes = $maximumManifestBytes
    powerShellDriveDisplayRoot = $displayRoot
    logicalDiskProviderName = $providerName
    logicalDiskDriveType = [int]$logicalDisk.DriveType
    signatureVerified = $false
    gatewayAcceptanceIsExecutionEvidence = $false
    matchingSignedTerminalResponseRequired = $true
    imageBytesRead = $false
    sourceHashingPerformed = $false
    mutationsPerformed = $false
    requestRetryAuthorized = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
}

if ($Preflight) {
    $result | ConvertTo-Json -Depth 12
    return
}

Assert-True (-not (Test-Path -LiteralPath $observationPath)) 'O3J1 matching-response observation already exists.'
Write-JsonCreateNew -Path $observationPath -Value $result
$result | ConvertTo-Json -Depth 12

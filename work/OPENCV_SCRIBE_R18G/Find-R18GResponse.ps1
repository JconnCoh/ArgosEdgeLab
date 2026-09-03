#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (-not $Preflight) { throw 'Specify -Preflight.' }

$requestId = 'REQ_20260903T220000000Z_R18G'
$requestSha256 = 'B78FE1E9112FEEEB22FBDA3AA442B81237A207C26F6A62E4E1AAADFD5DA5AEE4'
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

Assert-True (Test-Path -LiteralPath $processedPath -PathType Leaf) 'Processed request copy is absent.'
Assert-True ((Get-FileHash -LiteralPath $processedPath -Algorithm SHA256).Hash -eq $requestSha256) 'Processed request hash changed.'
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
                    path = $candidate.FullName
                    bytes = [int64]$candidate.Length
                    sha256 = (Get-FileHash -LiteralPath $candidate.FullName -Algorithm SHA256).Hash
                })
            }
        } finally { $archive.Dispose() }
    } catch { continue }
}
Assert-True ($matches.Count -le 1) 'Multiple responses match R18G.'
[ordered]@{
    schema = 'argos_r18g_response_discovery_v1'
    checkedUtc = [DateTime]::UtcNow.ToString('o')
    state = $(if ($matches.Count -eq 1) { 'PASS_R18G_MATCHING_RESPONSE_FOUND' } else { 'WAIT_R18G_MATCHING_RESPONSE' })
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

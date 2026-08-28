#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (-not $Preflight) { throw 'O3Q4 response discovery is preflight-only.' }

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-Sha256([string]$Path) {
    $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '') }
    finally { $sha.Dispose(); $stream.Dispose() }
}

$requestId = 'REQ_20260828T152800444Z_62629419O3Q4'
$responseRoot = 'U:\ProjectPortalRO\responses'
Assert-True (Test-Path -LiteralPath $responseRoot -PathType Container) 'O3Q4 response share is unavailable.'
$candidateZips = @(Get-ChildItem -LiteralPath $responseRoot -File -Force | Where-Object { $_.Name -match '^R_[A-Za-z0-9_\-]+\.ready\.zip$' } | Sort-Object LastWriteTimeUtc, Name | Select-Object -First 21)
Assert-True ($candidateZips.Count -le 20) 'O3Q4 response root exceeded the bounded 20-ZIP discovery limit.'

Add-Type -AssemblyName System.IO.Compression.FileSystem
$matches = New-Object Collections.Generic.List[object]
foreach ($candidate in $candidateZips) {
    $zip = [IO.Compression.ZipFile]::OpenRead($candidate.FullName)
    try {
        $entry = $zip.GetEntry('PORTAL_RESPONSE_MANIFEST.json')
        if ($null -eq $entry -or $entry.Length -gt 65536) { continue }
        $reader = New-Object IO.StreamReader($entry.Open(), [Text.Encoding]::UTF8, $true)
        try { $manifest = $reader.ReadToEnd() | ConvertFrom-Json }
        finally { $reader.Dispose() }
        if ([string]$manifest.requestId -eq $requestId) {
            $matches.Add([pscustomobject]@{
                responseId = [string]$manifest.responseId
                requestId = [string]$manifest.requestId
                sourceRole = [string]$manifest.sourceRole
                endpointState = [string]$manifest.state
                sourceZip = $candidate.FullName
                sourceZipBytes = [int64]$candidate.Length
                sourceZipSha256 = Get-Sha256 $candidate.FullName
                manifestEntryBytes = [int64]$entry.Length
            })
        }
    }
    finally { $zip.Dispose() }
}
Assert-True ($matches.Count -le 1) 'O3Q4 found multiple matching response ZIPs.'
$state = if ($matches.Count -eq 1) { 'PASS_O3Q4_ONE_MATCHING_RESPONSE_LOCATED' } else { 'PENDING_O3Q4_MATCHING_RESPONSE' }
[ordered]@{
    schema = 'argos_o3q4_response_discovery_v1'
    observedUtc = [DateTime]::UtcNow.ToString('o')
    state = $state
    requestId = $requestId
    boundedCandidateZipCount = $candidateZips.Count
    matchingResponseCount = $matches.Count
    match = if ($matches.Count -eq 1) { $matches[0] } else { $null }
    remoteMutationsPerformed = $false
    requestRetryAuthorized = $false
    imageBytesRead = $false
    sourceImageHashingPerformed = $false
    existingProcessesQueried = $false
    taskActions = 0
    protectedProcessorTouched = $false
    providerActivated = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
} | ConvertTo-Json -Depth 8

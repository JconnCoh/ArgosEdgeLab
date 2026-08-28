#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (-not $Preflight) { throw 'O3Q4 R2 response discovery is preflight-only.' }

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-Sha256([string]$Path) {
    $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '') }
    finally { $sha.Dispose(); $stream.Dispose() }
}

$requestId = 'REQ_20260828T152800444Z_62629419O3Q4'
$publishedUtc = [DateTime]::Parse('2026-08-28T15:57:47.2407846Z').ToUniversalTime()
$cohortStartUtc = $publishedUtc.AddMinutes(-1)
$responseRoot = 'U:\ProjectPortalRO\responses'
Assert-True (Test-Path -LiteralPath $responseRoot -PathType Container) 'O3Q4 R2 response share is unavailable.'

$candidatePaths = New-Object Collections.Generic.List[string]
foreach ($path in [IO.Directory]::EnumerateFiles($responseRoot, '*.ready.zip', [IO.SearchOption]::TopDirectoryOnly)) {
    $leaf = [IO.Path]::GetFileName($path)
    if ($leaf -notmatch '^R_[A-Za-z0-9_\-]+\.ready\.zip$') { continue }
    $item = Get-Item -LiteralPath $path
    if ($item.LastWriteTimeUtc -lt $cohortStartUtc) { continue }
    $candidatePaths.Add($item.FullName)
    if ($candidatePaths.Count -ge 21) { break }
}
Assert-True ($candidatePaths.Count -le 20) 'O3Q4 R2 post-publication response cohort exceeded 20 ZIPs.'

Add-Type -AssemblyName System.IO.Compression.FileSystem
$matches = New-Object Collections.Generic.List[object]
foreach ($candidatePath in @($candidatePaths)) {
    $candidate = Get-Item -LiteralPath $candidatePath
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
                lastWriteUtc = $candidate.LastWriteTimeUtc.ToString('o')
                manifestEntryBytes = [int64]$entry.Length
            })
        }
    }
    finally { $zip.Dispose() }
}
Assert-True ($matches.Count -le 1) 'O3Q4 R2 found multiple matching response ZIPs.'
$state = if ($matches.Count -eq 1) { 'PASS_O3Q4_R2_ONE_MATCHING_RESPONSE_LOCATED' } else { 'PENDING_O3Q4_R2_MATCHING_RESPONSE' }
[ordered]@{
    schema = 'argos_o3q4_response_discovery_r2_v1'
    observedUtc = [DateTime]::UtcNow.ToString('o')
    state = $state
    requestId = $requestId
    publishedUtc = $publishedUtc.ToString('o')
    cohortStartUtc = $cohortStartUtc.ToString('o')
    boundedCandidateZipCount = $candidatePaths.Count
    matchingResponseCount = $matches.Count
    match = if ($matches.Count -eq 1) { $matches[0] } else { $null }
    remoteMutationsPerformed = $false
    requestRepublished = $false
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

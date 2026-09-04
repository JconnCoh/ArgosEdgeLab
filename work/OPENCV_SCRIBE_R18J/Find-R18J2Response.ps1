#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (-not $Preflight) { throw 'Specify -Preflight.' }
$requestId = 'REQ_20260904T014700000Z_R18J2'
$requestSha = '5014D4C117042AFDB23C9E2E02A83B1135227D6FCCCBE474FC203C86F8DB825E'
$requestRoot = 'U:\ProjectPortalRO\requests'
$responseRoot = 'U:\ProjectPortalRO\responses'
$processedPath = Join-Path (Join-Path $requestRoot 'processed') ($requestId + '.ready.zip')

function Require([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Read-ZipText([IO.Compression.ZipArchive]$Archive, [string]$Name) {
    $entry = $Archive.GetEntry($Name)
    if ($null -eq $entry -or [int64]$entry.Length -gt 1048576) { return $null }
    $reader = New-Object IO.StreamReader($entry.Open(), (New-Object Text.UTF8Encoding($false,$true)))
    try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
}

$processed = Test-Path -LiteralPath $processedPath -PathType Leaf
if ($processed) { Require ((Get-FileHash -LiteralPath $processedPath -Algorithm SHA256).Hash -eq $requestSha) 'R18J2 processed request hash changed.' }
Require (Test-Path -LiteralPath $responseRoot -PathType Container) 'R18J2 response root unavailable.'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$responseFiles = @(Get-ChildItem -LiteralPath $responseRoot -File -Filter '*.ready.zip' -ErrorAction Stop | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 500)
$matches = New-Object Collections.Generic.List[object]
foreach ($candidate in $responseFiles) {
    try {
        $archive = [IO.Compression.ZipFile]::OpenRead($candidate.FullName)
        try {
            $text = Read-ZipText -Archive $archive -Name 'PORTAL_RESPONSE_MANIFEST.json'
            if ($null -eq $text) { continue }
            $manifest = $text | ConvertFrom-Json
            if ([string]$manifest.requestId -eq $requestId) {
                $matches.Add([pscustomobject]@{responseId=[string]$manifest.responseId;requestId=[string]$manifest.requestId;sourceRole=[string]$manifest.sourceRole;state=[string]$manifest.state;path=$candidate.FullName;bytes=[int64]$candidate.Length;sha256=(Get-FileHash -LiteralPath $candidate.FullName -Algorithm SHA256).Hash})
            }
        }
        finally { $archive.Dispose() }
    }
    catch { continue }
}
Require ($matches.Count -le 1) 'Multiple responses match R18J2.'
[ordered]@{schema='argos_opencv_scribe_r18j2_response_discovery_v1';checkedUtc=[DateTime]::UtcNow.ToString('o');state=$(if ($matches.Count -eq 1) {'PASS_R18J2_MATCHING_RESPONSE_FOUND'} elseif ($processed) {'WAIT_R18J2_MATCHING_RESPONSE'} else {'WAIT_R18J2_REQUEST_IMPORT'});requestId=$requestId;processedRequestPresent=$processed;responseFilesScanned=$responseFiles.Count;matchingResponses=$matches.Count;match=$(if ($matches.Count -eq 1) {$matches[0]} else {$null});mutationsPerformed=$false;requestRetried=$false;pixelsDecoded=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 8

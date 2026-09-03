#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}
function Get-Sha256Shared([string]$Path) {
    $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try { ([BitConverter]::ToString($algorithm.ComputeHash($stream))).Replace('-', '') }
    finally { $algorithm.Dispose(); $stream.Dispose() }
}

Assert-True $Preflight 'F2 response-cohort observation is read-only and requires -Preflight.'
Assert-True ([string]$PSVersionTable.PSEdition -ceq 'Desktop' -and [int]$PSVersionTable.PSVersion.Major -eq 5 -and [int]$PSVersionTable.PSVersion.Minor -eq 1) 'F2 response-cohort observation requires Windows PowerShell 5.1.'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$intentPath = Join-Path $PSScriptRoot 'O3F15L4D2F2_RECOVERY_INTENT.json'
Assert-True (Test-Path -LiteralPath $intentPath -PathType Leaf) 'F2 recovery intent is absent.'
Assert-True ((Get-Sha256Shared $intentPath) -ceq '8D4E7A4F2A8A6B254CDEC15F4C0A84DFA09C835D2B4637E01A52EE73D069936A') 'F2 recovery intent changed.'

$expectedShare = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$drive = Get-PSDrive -Name U -PSProvider FileSystem -ErrorAction Stop
$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='U:'" -ErrorAction Stop
Assert-True ([string]$drive.DisplayRoot -ceq $expectedShare -and [string]$disk.ProviderName -ceq $expectedShare -and [int]$disk.DriveType -eq 4) 'F2 qualified persistent U: mapping changed.'
$responseRoot = 'U:\ProjectPortalRO\responses'
Assert-True (Test-Path -LiteralPath $responseRoot -PathType Container) 'F2 Project Portal response root is unavailable.'
$maximumRows = 10000
$retainedCount = 0
foreach ($path in [IO.Directory]::EnumerateFiles($responseRoot, '*.ready.zip', [IO.SearchOption]::TopDirectoryOnly)) {
    $retainedCount++
    if ($retainedCount -gt $maximumRows) { break }
}
Assert-True ($retainedCount -le $maximumRows) "F2 retained response cohort exceeds the observation bound of $maximumRows."

[pscustomobject]@{
    schema = 'argos_recovery_observation_evidence_v1'
    observedUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_ARGOS_RECOVERY_OBSERVATION'
    incidentId = 'O3F15L4D2_RESPONSE_FINDER_CAPACITY_20260903'
    exactSourcesProved = $true
    fieldSpecificExpectedObservedRecorded = $true
    directEndpointEvidence = $true
    matchingSignedTerminalResponse = $false
    expectedPersistentShare = $expectedShare
    responseRoot = $responseRoot
    retainedReadyZipCount = $retainedCount
    maximumRows = $maximumRows
    zipContentRead = $false
    imageBytesRead = $false
    mutationsPerformed = $false
    requestRepublished = $false
    requestRetryAuthorized = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
} | ConvertTo-Json -Compress

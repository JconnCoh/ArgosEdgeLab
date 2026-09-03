#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$InvocationManifest,
    [switch]$Preflight
)

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

function Get-RequiredProperty([object]$Value, [string]$Name) {
    $property = $Value.PSObject.Properties[$Name]
    if ($null -eq $property) { throw "D2 response-finder invocation is missing $Name." }
    $property.Value
}

function Resolve-RepositoryFile([string]$ProjectRoot, [string]$RelativePath) {
    Assert-True (-not [IO.Path]::IsPathRooted($RelativePath)) "D2 response-finder dependency must be repository-relative: $RelativePath"
    $root = [IO.Path]::GetFullPath($ProjectRoot).TrimEnd('\') + '\'
    $resolved = [IO.Path]::GetFullPath((Join-Path $root $RelativePath.Replace('/', '\')))
    Assert-True ($resolved.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) "D2 response-finder dependency escapes the repository: $RelativePath"
    $resolved
}

function Read-BoundedResponseIdentity([string]$ZipPath, [int64]$MaximumManifestBytes) {
    $archive = [IO.Compression.ZipFile]::OpenRead($ZipPath)
    try {
        $entry = $archive.GetEntry('PORTAL_RESPONSE_MANIFEST.json')
        if ($null -eq $entry -or $entry.Length -lt 2 -or $entry.Length -gt $MaximumManifestBytes) { return $null }
        $reader = New-Object IO.StreamReader($entry.Open(), (New-Object Text.UTF8Encoding($false, $true)), $true)
        try { $text = $reader.ReadToEnd() } finally { $reader.Dispose() }
        try { $manifest = $text | ConvertFrom-Json } catch { return $null }
        if ([string]$manifest.schema -cne 'argos_project_portal_response_manifest_v1') { return $null }
        [pscustomobject]@{
            requestId = [string]$manifest.requestId
            responseId = [string]$manifest.responseId
            sourceRole = [string]$manifest.sourceRole
            endpointState = [string]$manifest.state
            manifestEntryBytes = [int64]$entry.Length
        }
    } finally {
        $archive.Dispose()
    }
}

Assert-True $Preflight 'D2 response discovery is read-only and requires -Preflight.'
Assert-True ([string]$PSVersionTable.PSEdition -ceq 'Desktop' -and [int]$PSVersionTable.PSVersion.Major -eq 5 -and [int]$PSVersionTable.PSVersion.Minor -eq 1) 'D2 response finder requires Windows PowerShell 5.1.'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$expectedInvocation = Join-Path $PSScriptRoot 'O3F15L4D2_RESPONSE_FIND_INVOCATION.json'
$invocationPath = [IO.Path]::GetFullPath($InvocationManifest)
Assert-True ($invocationPath.Equals($expectedInvocation, [StringComparison]::OrdinalIgnoreCase)) 'D2 response-finder invocation path changed.'
Assert-True (Test-Path -LiteralPath $invocationPath -PathType Leaf) 'D2 response-finder invocation is absent.'
$invocation = Get-Content -LiteralPath $invocationPath -Raw | ConvertFrom-Json
Assert-True ([string](Get-RequiredProperty $invocation 'schema') -ceq 'argos_ocv03_o3f15l4d2_response_find_invocation_v1') 'D2 response-finder invocation schema changed.'
Assert-True ([string](Get-RequiredProperty $invocation 'state') -ceq 'FROZEN_O3F15L4D2_RESPONSE_FIND_INVOCATION') 'D2 response-finder invocation is not frozen.'
Assert-True ([string](Get-RequiredProperty $invocation 'finderSha256') -ceq (Get-Sha256Shared $PSCommandPath)) 'D2 response finder is not the frozen byte set.'
Assert-True (-not [bool](Get-RequiredProperty $invocation 'requestRetryAuthorized')) 'D2 response finder cannot authorize a request retry.'
$requestId = [string](Get-RequiredProperty $invocation 'requestId')
Assert-True ($requestId -cmatch '^REQ_[0-9]{8}T[0-9]{9}Z_[0-9A-F]{12}$') 'D2 response-finder request ID shape changed.'
$maximumCandidates = [int](Get-RequiredProperty $invocation 'maximumCandidateResponseZips')
$maximumManifestBytes = [int64](Get-RequiredProperty $invocation 'maximumManifestEntryBytes')
Assert-True ($maximumCandidates -ge 1 -and $maximumCandidates -le 512 -and $maximumManifestBytes -eq 65536) 'D2 response-finder bounds changed.'

$publishGatePath = Resolve-RepositoryFile $projectRoot ([string](Get-RequiredProperty $invocation 'publishGatePath'))
Assert-True (Test-Path -LiteralPath $publishGatePath -PathType Leaf) 'D2 publication gate is absent.'
Assert-True ((Get-Sha256Shared $publishGatePath) -ceq [string](Get-RequiredProperty $invocation 'publishGateSha256')) 'D2 publication gate hash changed.'
$publishGate = Get-Content -LiteralPath $publishGatePath -Raw | ConvertFrom-Json
Assert-True ([string]$publishGate.state -ceq 'PASS_O3F15L4D2_PUBLISHED_EXACTLY_ONCE_AWAITING_MATCHING_SIGNED_RESPONSE' -and [string]$publishGate.requestId -ceq $requestId -and [int]$publishGate.publicationCount -eq 1 -and -not [bool]$publishGate.automaticRetryAuthorized) 'D2 publication evidence changed.'

$expectedShare = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
Assert-True ([string](Get-RequiredProperty $invocation 'expectedPersistentShare') -ceq $expectedShare) 'D2 response-finder share pin changed.'
$drive = Get-PSDrive -Name U -PSProvider FileSystem -ErrorAction Stop
$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='U:'" -ErrorAction Stop
Assert-True ([string]$drive.DisplayRoot -ceq $expectedShare -and [string]$disk.ProviderName -ceq $expectedShare -and [int]$disk.DriveType -eq 4) 'D2 qualified persistent U: mapping changed.'
$responseRoot = 'U:\ProjectPortalRO\responses'
Assert-True (Test-Path -LiteralPath $responseRoot -PathType Container) 'D2 Project Portal response root is unavailable.'
$candidateZips = @(Get-ChildItem -LiteralPath $responseRoot -File -Filter '*.ready.zip' -ErrorAction Stop | Sort-Object LastWriteTimeUtc, Name)
Assert-True ($candidateZips.Count -le $maximumCandidates) "D2 response cohort exceeds the frozen bound of $maximumCandidates."
$matches = New-Object Collections.Generic.List[object]
foreach ($item in $candidateZips) {
    if ($item.Length -gt 16777216) { continue }
    $identity = Read-BoundedResponseIdentity $item.FullName $maximumManifestBytes
    if ($null -ne $identity -and [string]$identity.requestId -ceq $requestId) {
        Assert-True ([string]$identity.sourceRole -ceq 'JBOD') 'D2 matching response has the wrong source role.'
        Assert-True ([string]$identity.responseId -cmatch '^R_[0-9A-F]{12}_[0-9]{17}_[0-9a-f]{8}$') 'D2 matching response ID shape changed.'
        $matches.Add([pscustomobject]@{
            requestId = $requestId
            responseId = [string]$identity.responseId
            endpointState = [string]$identity.endpointState
            sourceZip = $item.FullName
            sourceZipBytes = [int64]$item.Length
            sourceZipSha256 = Get-Sha256Shared $item.FullName
            manifestEntryBytes = [int64]$identity.manifestEntryBytes
            lastWriteUtc = $item.LastWriteTimeUtc.ToString('o')
        })
    }
}
Assert-True ($matches.Count -le 1) 'D2 response finder located multiple ZIPs for the exact request ID.'
$state = if ($matches.Count -eq 1) { 'PASS_O3F15L4D2_ONE_EXACT_RESPONSE_LOCATED' } else { 'PENDING_O3F15L4D2_EXACT_RESPONSE' }
[ordered]@{
    schema = 'argos_ocv03_o3f15l4d2_response_discovery_v1'
    observedUtc = [DateTime]::UtcNow.ToString('o')
    state = $state
    requestId = $requestId
    boundedCandidateZipCount = $candidateZips.Count
    matchingResponseCount = $matches.Count
    match = $(if ($matches.Count -eq 1) { $matches[0] } else { $null })
    exactRequestIdentityMatchRequired = $true
    responseFilenameOrTimestampMatchAllowed = $false
    remoteMutationsPerformed = $false
    requestRepublished = $false
    requestRetryAuthorized = $false
    imageBytesRead = $false
    existingTasksOrProcessesQueried = $false
    persistentMappingChanged = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
} | ConvertTo-Json -Depth 10

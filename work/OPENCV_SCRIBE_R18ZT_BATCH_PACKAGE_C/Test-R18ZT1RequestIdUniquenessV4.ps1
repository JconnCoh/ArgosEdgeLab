#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Gate,
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Gate)) { throw 'Specify exactly one of -Preflight or -Gate.' }
if ($Gate -and [string]::IsNullOrWhiteSpace($OutputPath)) { throw '-Gate requires -OutputPath.' }

$requestId = 'REQ_R18ZT1'
$bindingRecordSha256 = '23F68B7A1C744E57508D89FE10B48ADF07C50E641EC70CBA1213EDE0388C5E86'
$shareRoot = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$namespaces = @(
    [ordered]@{ id='SHARE_REQUEST_UPLOAD_PROCESSED_ARCHIVE'; path='U:\ProjectPortalRO\requests'; required=$true },
    [ordered]@{ id='SHARE_RESPONSE_ARCHIVE'; path='U:\ProjectPortalRO\responses'; required=$true },
    [ordered]@{ id='LOCAL_ROUTE_REQUEST_TO_ARGOS'; path='C:\ProgramData\ArgosProjectPortalRO\requests_to_argos'; required=$false },
    [ordered]@{ id='LOCAL_ROUTE_REQUEST_FROM_GATEWAY'; path='C:\ProgramData\ArgosProjectPortalRO\requests_from_gateway'; required=$false },
    [ordered]@{ id='LOCAL_ROUTE_TO_JBOD'; path='C:\ProgramData\ArgosProjectPortalRO\to_jbod'; required=$false },
    [ordered]@{ id='LOCAL_ENDPOINT_LEDGER'; path='C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod'; required=$false },
    [ordered]@{ id='LOCAL_ROUTE_TO_ARGOS'; path='C:\ProgramData\ArgosProjectPortalRO\to_argos'; required=$false },
    [ordered]@{ id='LOCAL_ROUTE_FROM_JBOD'; path='C:\ProgramData\ArgosProjectPortalRO\from_jbod'; required=$false },
    [ordered]@{ id='LOCAL_ROUTE_TO_GATEWAY'; path='C:\ProgramData\ArgosProjectPortalRO\to_gateway'; required=$false }
)
$scannerPath = [IO.Path]::GetFullPath($MyInvocation.MyCommand.Path)
$scannerSha256 = (Get-FileHash -LiteralPath $scannerPath -Algorithm SHA256).Hash

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Write-JsonAtomicCreateNew([string]$Path, [object]$Value) {
    $partialPath = $Path + '.partial'
    Assert-True (-not (Test-Path -LiteralPath $Path) -and -not (Test-Path -LiteralPath $partialPath)) 'Uniqueness gate or retained partial already exists.'
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes((($Value | ConvertTo-Json -Depth 12) + [Environment]::NewLine))
    $stream = New-Object IO.FileStream($partialPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush($true)
    }
    finally { $stream.Dispose() }
    [IO.File]::Move($partialPath, $Path)
}
function Read-BoundedText([string]$Path, [int64]$MaximumBytes) {
    $item = Get-Item -LiteralPath $Path -ErrorAction Stop
    if ([int64]$item.Length -gt $MaximumBytes) { return $null }
    $bytes = [IO.File]::ReadAllBytes($Path)
    return (New-Object Text.UTF8Encoding($false, $false)).GetString($bytes)
}

$psDrive = Get-PSDrive -Name U -PSProvider FileSystem -ErrorAction Stop
$logicalDisk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='U:'" -ErrorAction Stop
Assert-True ([string]$psDrive.DisplayRoot -eq $shareRoot) 'U: PowerShell mapping root changed.'
Assert-True ([string]$logicalDisk.ProviderName -eq $shareRoot) 'U: operating-system mapping root changed.'

$plan = @($namespaces | ForEach-Object { [ordered]@{id=$_.id;path=$_.path;required=[bool]$_.required;available=(Test-Path -LiteralPath $_.path -PathType Container)} })
if ($Preflight) {
    [ordered]@{
        schema='argos_r18zt1_request_id_uniqueness_preflight_v2'
        checkedUtc=[DateTime]::UtcNow.ToString('o')
        state='PASS_R18ZT1_REQUEST_ID_UNIQUENESS_PREFLIGHT'
        requestId=$requestId
        bindingRecordSha256=$bindingRecordSha256
        scannerSha256=$scannerSha256
        namespaces=$plan
        recursiveEntryCapPerNamespace=10000
        boundedTextBytesPerFile=1048576
        zipJsonSelectionIncludesRequestManifest=$true
        zipJsonSelectionIncludesResponseManifest=$true
        zipJsonSelectionIncludesResultPayload=$true
        imageMembersRead=$false
        mutationsPerformed=$false
    } | ConvertTo-Json -Depth 8
    return
}

$resolvedOutput = [IO.Path]::GetFullPath($OutputPath)
Assert-True (-not (Test-Path -LiteralPath $resolvedOutput) -and -not (Test-Path -LiteralPath ($resolvedOutput + '.partial'))) 'Uniqueness gate output or retained partial already exists.'
foreach ($row in $plan) { if ([bool]$row.required) { Assert-True ([bool]$row.available) "Required collision namespace unavailable: $($row.path)" } }

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$collisions = New-Object Collections.Generic.List[object]
$scanRows = New-Object Collections.Generic.List[object]
foreach ($namespace in $namespaces) {
    $root = [string]$namespace.path
    if (-not (Test-Path -LiteralPath $root -PathType Container)) {
        $scanRows.Add([pscustomobject]@{
            id=$namespace.id
            path=$root
            available=$false
            entries=0
            textFilesRead=0
            zipMetadataJsonMembersRead=0
            zipPayloadJsonMembersRead=0
            imageMembersRead=0
            errors=0
        })
        continue
    }
    $entries = @(Get-ChildItem -LiteralPath $root -Force -Recurse -ErrorAction Stop)
    Assert-True ($entries.Count -le 10000) "Collision namespace exceeded 10000-entry cap: $root"
    $textRead = 0
    $zipMetadataRead = 0
    $zipPayloadRead = 0
    foreach ($entry in $entries) {
        if ([string]$entry.FullName -like ('*' + $requestId + '*')) {
            $collisions.Add([pscustomobject]@{namespace=$namespace.id;kind='PATH_NAME';path=[string]$entry.FullName})
        }
        if ([bool]$entry.PSIsContainer) { continue }
        $extension = [IO.Path]::GetExtension([string]$entry.Name)
        if ($extension -in @('.json','.txt','.log','.csv')) {
            $text = Read-BoundedText -Path ([string]$entry.FullName) -MaximumBytes 1048576
            if ($null -ne $text) {
                $textRead++
                if ($text.IndexOf($requestId, [StringComparison]::Ordinal) -ge 0) {
                    $collisions.Add([pscustomobject]@{namespace=$namespace.id;kind='TEXT_CONTENT';path=[string]$entry.FullName})
                }
            }
        }
        elseif ($extension -ieq '.zip') {
            $archive = $null
            try {
                $archive = [IO.Compression.ZipFile]::OpenRead([string]$entry.FullName)
                foreach ($member in @($archive.Entries | Where-Object { ([string]$_.FullName).Replace('\','/') -match '(^|/)(PORTAL_REQUEST_MANIFEST|PORTAL_RESPONSE_MANIFEST|RESULT)\.json$' })) {
                    if ([int64]$member.Length -gt 1048576) { continue }
                    $reader = New-Object IO.StreamReader($member.Open(), (New-Object Text.UTF8Encoding($false, $false)), $true)
                    try { $memberText = $reader.ReadToEnd() } finally { $reader.Dispose() }
                    $memberName = ([string]$member.FullName).Replace('\','/').Split('/')[-1]
                    if ($memberName -ceq 'RESULT.json') { $zipPayloadRead++ } else { $zipMetadataRead++ }
                    if ($memberText.IndexOf($requestId, [StringComparison]::Ordinal) -ge 0) {
                        $collisionKind = if ($memberName -ceq 'RESULT.json') { 'ZIP_PAYLOAD_CONTENT' } else { 'ZIP_MANIFEST_CONTENT' }
                        $collisions.Add([pscustomobject]@{namespace=$namespace.id;kind=$collisionKind;path=([string]$entry.FullName + '!' + [string]$member.FullName)})
                    }
                }
            } finally { if ($null -ne $archive) { $archive.Dispose() } }
        }
    }
    $scanRows.Add([pscustomobject]@{
        id=$namespace.id
        path=$root
        available=$true
        entries=$entries.Count
        textFilesRead=$textRead
        zipMetadataJsonMembersRead=$zipMetadataRead
        zipPayloadJsonMembersRead=$zipPayloadRead
        imageMembersRead=0
        errors=0
    })
}

$zipMetadataJsonMemberReadCount = [int](@($scanRows | Measure-Object -Property zipMetadataJsonMembersRead -Sum).Sum)
$zipPayloadJsonMemberReadCount = [int](@($scanRows | Measure-Object -Property zipPayloadJsonMembersRead -Sum).Sum)
$imageMemberReadCount = [int](@($scanRows | Measure-Object -Property imageMembersRead -Sum).Sum)
$zipPayloadMembersRead = $zipPayloadJsonMemberReadCount -gt 0
$imageMembersRead = $imageMemberReadCount -gt 0

$result = [ordered]@{
    schema='argos_r18zt1_request_id_uniqueness_gate_v2'
    checkedUtc=[DateTime]::UtcNow.ToString('o')
    state=$(if($collisions.Count -eq 0){'PASS_R18ZT1_REQUEST_ID_UNIQUENESS_ZERO_COLLISIONS'}else{'FAIL_R18ZT1_REQUEST_ID_COLLISION'})
    requestId=$requestId
    bindingRecordSha256=$bindingRecordSha256
    scannerSha256=$scannerSha256
    sharePowerShellDisplayRoot=[string]$psDrive.DisplayRoot
    shareOsProviderName=[string]$logicalDisk.ProviderName
    namespaceCount=$scanRows.Count
    namespaces=$scanRows.ToArray()
    collisionCount=$collisions.Count
    collisions=$collisions.ToArray()
    requestUploadProcessedAndArchiveScanned=$true
    responseArchiveScanned=$true
    endpointLedgerNamespaceChecked=$true
    endpointLedgerNamespaceAvailable=[bool](@($scanRows | Where-Object { $_.id -eq 'LOCAL_ENDPOINT_LEDGER' })[0].available)
    allAccessibleNamespacesScanned=$true
    zipMetadataJsonMemberReadCount=$zipMetadataJsonMemberReadCount
    zipPayloadJsonMemberReadCount=$zipPayloadJsonMemberReadCount
    imageMemberReadCount=$imageMemberReadCount
    zipPayloadMembersRead=$zipPayloadMembersRead
    imageMembersRead=$imageMembersRead
    zipPayloadOrImageMembersRead=([bool]$zipPayloadMembersRead -or [bool]$imageMembersRead)
    queueTaskProcessActions=@()
    mutationsPerformed=$false
}
Write-JsonAtomicCreateNew -Path $resolvedOutput -Value $result
if ($collisions.Count -ne 0) { throw "Request ID collision detected: $($collisions.Count)" }
$result | ConvertTo-Json -Depth 12

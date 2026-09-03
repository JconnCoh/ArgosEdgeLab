#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$InvocationManifest,
    [switch]$Preflight,
    [switch]$Collect
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = New-Object Text.UTF8Encoding($false, $true)
$classNames = @('DIRECT_SAFE', 'VERIFIED_SHORT_ALIAS_REQUIRED', 'DIRECT_USE_HARD_STOP_ALIAS_ONLY')

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-RequiredProperty([object]$Value, [string]$Name) {
    $property = $Value.PSObject.Properties[$Name]
    if ($null -eq $property) { throw "D2 collection required property is absent: $Name" }
    $property.Value
}

function Assert-ExactProperties([object]$Value, [string[]]$Names, [string]$Label) {
    $actual = @($Value.PSObject.Properties | ForEach-Object { $_.Name } | Sort-Object)
    $expected = @($Names | Sort-Object)
    Assert-True (($actual -join '|') -ceq ($expected -join '|')) "$Label property set changed."
}

function Get-Sha256Bytes([byte[]]$Bytes) {
    if ($null -eq $Bytes) { $Bytes = [byte[]]::new(0) }
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try { ([BitConverter]::ToString($algorithm.ComputeHash([byte[]]$Bytes))).Replace('-', '') }
    finally { $algorithm.Dispose() }
}

function Get-Sha256File([string]$Path) {
    $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try { ([BitConverter]::ToString($algorithm.ComputeHash($stream))).Replace('-', '') }
    finally { $algorithm.Dispose(); $stream.Dispose() }
}

function Get-Sha256Text([string]$Text) {
    Get-Sha256Bytes ([Text.Encoding]::UTF8.GetBytes($Text))
}

function Assert-UpperSha256([string]$Value, [string]$Label) {
    Assert-True ($Value -cmatch '^[0-9A-F]{64}$') "$Label is not uppercase SHA-256."
}

function Resolve-RepositoryFile([string]$ProjectRoot, [string]$RelativePath) {
    Assert-True (-not [IO.Path]::IsPathRooted($RelativePath)) "D2 collection dependency must be repository-relative: $RelativePath"
    $root = [IO.Path]::GetFullPath($ProjectRoot).TrimEnd('\') + '\'
    $resolved = [IO.Path]::GetFullPath((Join-Path $root $RelativePath.Replace('/', '\')))
    Assert-True ($resolved.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) "D2 collection dependency escapes the repository: $RelativePath"
    $resolved
}

function Read-ZipEntryBytes([IO.Compression.ZipArchiveEntry]$Entry, [int64]$MaximumBytes) {
    Assert-True ($Entry.Length -ge 0 -and $Entry.Length -le $MaximumBytes) "D2 response entry exceeds its bound: $($Entry.FullName)"
    $source = $Entry.Open()
    $buffer = New-Object IO.MemoryStream
    try {
        $source.CopyTo($buffer)
        return ,([byte[]]$buffer.ToArray())
    } finally {
        $buffer.Dispose()
        $source.Dispose()
    }
}

function Get-WindowsLeaf([string]$Path) {
    $separator = [Math]::Max($Path.LastIndexOf([char]92), $Path.LastIndexOf([char]47))
    if ($separator -lt 0) { return $Path }
    if ($separator -eq $Path.Length - 1) { return '' }
    $Path.Substring($separator + 1)
}

function Normalize-WindowsPath([string]$Path) {
    $Path.Replace('/', '\').TrimEnd('\')
}

function Get-MaximumComponentLength([string]$Path) {
    $maximum = 0
    foreach ($part in @($Path -split '[\\/]' | Where-Object { -not [string]::IsNullOrEmpty($_) })) {
        if ($part.Length -gt $maximum) { $maximum = $part.Length }
    }
    $maximum
}

function Confirm-Classification([object]$Classification, [object]$Contract) {
    Assert-ExactProperties $Classification @(
        'classificationLeafIdentitySha256', 'complete', 'corpus', 'hardStopIdentities',
        'identityCount', 'orderedClassificationRecordSha256', 'orderedIdentitySha256',
        'orderedSourceLeafRecordSha256', 'pairClassificationCounts', 'pairCount',
        'serializedCoreBytes', 'serializedEvidenceLimitBytes', 'sourceLeafClassificationCounts',
        'sourceLeafCount', 'sourceLeavesByClass', 'uniqueOrderedSourceLeafCount'
    ) 'D2 classification'
    Assert-True ([string]$Classification.corpus -ceq 'ACTUAL_FROZEN_978' -and [bool]$Classification.complete) 'D2 actual frozen corpus classification is incomplete.'
    Assert-True ([int64]$Classification.pairCount -eq 978 -and [int64]$Classification.identityCount -eq 978 -and [int64]$Classification.sourceLeafCount -eq 1956 -and [int64]$Classification.uniqueOrderedSourceLeafCount -eq 1956) 'D2 actual frozen corpus cardinality changed.'
    Assert-True ([int64]$Classification.serializedEvidenceLimitBytes -eq [int64]$Contract.classification.maximumSerializedCoreBytes -and [int64]$Classification.serializedCoreBytes -ge 1 -and [int64]$Classification.serializedCoreBytes -le [int64]$Contract.classification.maximumSerializedCoreBytes) 'D2 classification serialization bound changed.'

    foreach ($map in @($Classification.pairClassificationCounts, $Classification.sourceLeafClassificationCounts, $Classification.sourceLeavesByClass, $Classification.classificationLeafIdentitySha256)) {
        Assert-ExactProperties $map $classNames 'D2 classification class map'
    }
    $sourceRoot = 'D:\KLARFExport'
    $leafKeys = New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    $identityKeys = New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    $identities = @{}
    $slotRoots = @{}
    $channels = @{}
    $pairClasses = @{}
    $leafCounts = @{ DIRECT_SAFE = 0L; VERIFIED_SHORT_ALIAS_REQUIRED = 0L; DIRECT_USE_HARD_STOP_ALIAS_ONLY = 0L }
    $pairCounts = @{ DIRECT_SAFE = 0L; VERIFIED_SHORT_ALIAS_REQUIRED = 0L; DIRECT_USE_HARD_STOP_ALIAS_ONLY = 0L }
    $severity = @{ DIRECT_SAFE = 0; VERIFIED_SHORT_ALIAS_REQUIRED = 1; DIRECT_USE_HARD_STOP_ALIAS_ONLY = 2 }
    $classIdentityLines = @{}
    $allLeaves = New-Object Collections.Generic.List[object]
    foreach ($name in $classNames) { $classIdentityLines[$name] = New-Object Collections.Generic.List[string] }

    foreach ($name in $classNames) {
        $rows = @($Classification.sourceLeavesByClass.$name)
        Assert-True ($rows.Count -eq [int64]$Classification.sourceLeafClassificationCounts.$name) "D2 class-list cardinality changed: $name"
        $priorOrder = -1
        foreach ($row in $rows) {
            $baseProperties = @('canonicalPath', 'channel', 'class', 'effectiveLength', 'identity', 'maximumComponentLength', 'ordinal', 'rawLength')
            $expectedProperties = @(if ($name -ceq 'DIRECT_SAFE') { $baseProperties } else { $baseProperties + @('aliasPath', 'aliasPlannedEffectiveLength', 'aliasPlannedMaximumComponentLength', 'aliasPlannedRawLength') })
            Assert-ExactProperties $row $expectedProperties "D2 $name source leaf"
            $ordinal = [int]$row.ordinal
            $identity = [string]$row.identity
            $channel = [string]$row.channel
            Assert-True ($ordinal -ge 1 -and $ordinal -le 978 -and $channel -cin @('BF', 'DF') -and [string]$row.class -ceq $name) 'D2 source-leaf identity/class changed.'
            $order = 2 * $ordinal + $(if ($channel -ceq 'BF') { 0 } else { 1 })
            Assert-True ($order -gt $priorOrder) "D2 class leaf order changed: $name"
            $priorOrder = $order

            $markerIndex = $identity.IndexOf('|FRONT', [StringComparison]::Ordinal)
            Assert-True ($markerIndex -gt 0 -and $markerIndex + 6 -eq $identity.Length -and $identity.IndexOf('|FRONT', $markerIndex + 6, [StringComparison]::Ordinal) -lt 0) 'D2 source identity lacks one terminal |FRONT marker.'
            $identityAnchor = $identity.Substring(0, $markerIndex).Replace('/', '\').Trim('\')
            $anchorParts = @($identityAnchor -split '\\')
            Assert-True ($anchorParts.Count -ge 2 -and @($anchorParts | Where-Object { [string]::IsNullOrWhiteSpace($_) -or $_ -in @('.', '..') }).Count -eq 0) 'D2 source identity anchor is unsafe.'

            $canonical = [string]$row.canonicalPath
            $directory = if ($channel -ceq 'BF') { 'BrightfieldFrontsideWafer' } else { 'DarkfieldFrontsideWafer' }
            $filename = Get-WindowsLeaf $canonical
            $suffix = '\' + $directory + '\resizedImage\' + $filename
            $normalized = Normalize-WindowsPath $canonical
            Assert-True (-not [string]::IsNullOrWhiteSpace($filename) -and $normalized.EndsWith($suffix, [StringComparison]::OrdinalIgnoreCase)) 'D2 canonical source suffix changed.'
            $slotRoot = $normalized.Substring(0, $normalized.Length - $suffix.Length)
            Assert-True ($slotRoot.Equals(($sourceRoot + '\' + $identityAnchor), [StringComparison]::OrdinalIgnoreCase)) 'D2 canonical source is not bound to its identity.'
            $rawLength = [int64]$row.rawLength
            $effectiveLength = [int64]$row.effectiveLength
            $componentLength = [int64]$row.maximumComponentLength
            Assert-True ($rawLength -eq $canonical.Length -and $effectiveLength -eq $rawLength + 32 -and $componentLength -eq (Get-MaximumComponentLength $canonical) -and $componentLength -le 80) 'D2 canonical source metrics changed.'
            if ($name -ceq 'DIRECT_SAFE') { Assert-True ($effectiveLength -lt 200) 'D2 direct-safe threshold changed.' }
            elseif ($name -ceq 'VERIFIED_SHORT_ALIAS_REQUIRED') { Assert-True ($effectiveLength -ge 200 -and $effectiveLength -le 229) 'D2 alias-required threshold changed.' }
            else { Assert-True ($effectiveLength -ge 230) 'D2 direct-use hard-stop threshold changed.' }

            if ($name -cne 'DIRECT_SAFE') {
                $alias = [string]$row.aliasPath
                $expectedAlias = 'Q:\' + $directory + '\resizedImage\' + $filename
                Assert-True ((Normalize-WindowsPath $alias).Equals($expectedAlias, [StringComparison]::OrdinalIgnoreCase)) 'D2 planned alias identity changed.'
                Assert-True ([int64]$row.aliasPlannedRawLength -eq $alias.Length -and [int64]$row.aliasPlannedEffectiveLength -eq $alias.Length + 32 -and [int64]$row.aliasPlannedEffectiveLength -lt 200 -and [int64]$row.aliasPlannedMaximumComponentLength -eq (Get-MaximumComponentLength $alias) -and [int64]$row.aliasPlannedMaximumComponentLength -le 80) 'D2 planned alias metrics changed.'
            }

            $leafKey = "$ordinal|$identity|$channel"
            Assert-True ($leafKeys.Add($leafKey)) 'D2 classification contains a duplicate source leaf.'
            if ($identities.ContainsKey($ordinal)) {
                Assert-True ([string]$identities[$ordinal] -ceq $identity -and [string]$slotRoots[$ordinal] -ceq $slotRoot) 'D2 BF/DF identity or slot-root binding changed.'
            } else {
                Assert-True ($identityKeys.Add($identity)) 'D2 identity is reused by another ordinal.'
                $identities[$ordinal] = $identity
                $slotRoots[$ordinal] = $slotRoot
                $channels[$ordinal] = New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
            }
            Assert-True ($channels[$ordinal].Add($channel)) 'D2 ordinal contains a duplicate channel.'
            if (-not $pairClasses.ContainsKey($ordinal) -or $severity[$name] -gt $severity[[string]$pairClasses[$ordinal]]) { $pairClasses[$ordinal] = $name }
            $leafCounts[$name] = [int64]$leafCounts[$name] + 1
            $classIdentityLines[$name].Add("$identity|$channel")
            $allLeaves.Add($row)
        }
    }

    Assert-True ($leafKeys.Count -eq 1956 -and $identityKeys.Count -eq 978 -and $identities.Count -eq 978) 'D2 classification uniqueness changed.'
    $orderedIdentities = New-Object Collections.Generic.List[string]
    foreach ($ordinal in 1..978) {
        Assert-True ($identities.ContainsKey($ordinal) -and $channels[$ordinal].SetEquals([string[]]@('BF', 'DF'))) "D2 BF/DF coverage changed at ordinal $ordinal."
        $orderedIdentities.Add([string]$identities[$ordinal])
        $pairCounts[[string]$pairClasses[$ordinal]] = [int64]$pairCounts[[string]$pairClasses[$ordinal]] + 1
    }
    foreach ($name in $classNames) {
        Assert-True ([int64]$Classification.pairClassificationCounts.$name -eq [int64]$pairCounts[$name] -and [int64]$Classification.sourceLeafClassificationCounts.$name -eq [int64]$leafCounts[$name]) "D2 reconstructed class counts changed: $name"
        $classHash = [string]$Classification.classificationLeafIdentitySha256.$name
        Assert-UpperSha256 $classHash "D2 class hash $name"
        $classText = if ($classIdentityLines[$name].Count -eq 0) { '' } else { ($classIdentityLines[$name].ToArray() -join "`n") + "`n" }
        Assert-True ((Get-Sha256Text $classText) -ceq $classHash) "D2 class identity hash changed: $name"
    }
    $orderedIdentityHash = [string]$Classification.orderedIdentitySha256
    $orderedLeafHash = [string]$Classification.orderedSourceLeafRecordSha256
    $orderedClassificationHash = [string]$Classification.orderedClassificationRecordSha256
    foreach ($hashRow in @(@($orderedIdentityHash, 'ordered identity'), @($orderedLeafHash, 'ordered source leaf'), @($orderedClassificationHash, 'ordered classification'))) { Assert-UpperSha256 ([string]$hashRow[0]) "D2 $($hashRow[1]) hash" }
    Assert-True ((Get-Sha256Text (($orderedIdentities.ToArray() -join "`n") + "`n")) -ceq $orderedIdentityHash) 'D2 ordered identity hash changed.'
    $orderedLeaves = @($allLeaves.ToArray() | Sort-Object @{ Expression = { [int]$_.ordinal } }, @{ Expression = { if ([string]$_.channel -ceq 'BF') { 0 } else { 1 } } })
    Assert-True ((Get-Sha256Text (($orderedLeaves | ConvertTo-Json -Depth 16 -Compress) + "`n")) -ceq $orderedLeafHash) 'D2 ordered source-leaf hash changed.'

    $hardStops = @($Classification.hardStopIdentities)
    $hardOrdinals = @($orderedLeaves | Where-Object { [string]$_.class -ceq 'DIRECT_USE_HARD_STOP_ALIAS_ONLY' } | ForEach-Object { [int]$_.ordinal } | Sort-Object -Unique)
    Assert-True ($hardStops.Count -eq $hardOrdinals.Count) 'D2 hard-stop identity cardinality changed.'
    for ($index = 0; $index -lt $hardStops.Count; $index++) {
        $hard = $hardStops[$index]
        Assert-ExactProperties $hard @('channels', 'identity', 'ordinal') 'D2 hard-stop identity'
        $ordinal = $hardOrdinals[$index]
        $expectedChannels = @($orderedLeaves | Where-Object { [int]$_.ordinal -eq $ordinal -and [string]$_.class -ceq 'DIRECT_USE_HARD_STOP_ALIAS_ONLY' } | ForEach-Object { [string]$_.channel })
        Assert-True ([int]$hard.ordinal -eq $ordinal -and [string]$hard.identity -ceq [string]$identities[$ordinal] -and (@($hard.channels) -join '|') -ceq ($expectedChannels -join '|')) 'D2 hard-stop identity list changed.'
    }

    [ordered]@{
        pairCounts = [ordered]@{ DIRECT_SAFE = [int64]$pairCounts.DIRECT_SAFE; VERIFIED_SHORT_ALIAS_REQUIRED = [int64]$pairCounts.VERIFIED_SHORT_ALIAS_REQUIRED; DIRECT_USE_HARD_STOP_ALIAS_ONLY = [int64]$pairCounts.DIRECT_USE_HARD_STOP_ALIAS_ONLY }
        sourceLeafCounts = [ordered]@{ DIRECT_SAFE = [int64]$leafCounts.DIRECT_SAFE; VERIFIED_SHORT_ALIAS_REQUIRED = [int64]$leafCounts.VERIFIED_SHORT_ALIAS_REQUIRED; DIRECT_USE_HARD_STOP_ALIAS_ONLY = [int64]$leafCounts.DIRECT_USE_HARD_STOP_ALIAS_ONLY }
        identityCount = $identityKeys.Count
        sourceLeafCount = $leafKeys.Count
        orderedIdentitySha256 = $orderedIdentityHash
        orderedSourceLeafRecordSha256 = $orderedLeafHash
        orderedClassificationRecordSha256 = $orderedClassificationHash
    }
}

function Confirm-DiagnosticAuthority([object]$Diagnostic) {
    Assert-True (-not [bool](Get-RequiredProperty $Diagnostic 'selectorOrThresholdChanged')) 'D2 selector or threshold changed.'
    Assert-True (-not [bool](Get-RequiredProperty $Diagnostic 'sourceImageBytesRead') -and -not [bool](Get-RequiredProperty $Diagnostic 'detectorResultRootCreated')) 'D2 image bytes or detector result root were used.'
    foreach ($name in @('qSubstUsed', 'selfTestUsed', 'focusedTestUsed', 'gateUsed', 'runUsed', 'backgroundLaunchUsed', 'providerActivated', 'sourceMutationPerformed', 'sourceDeletionPerformed', 'holdCleared', 'retryUsed', 'mutationsPerformed')) {
        Assert-True (-not [bool](Get-RequiredProperty $Diagnostic $name)) "D2 prohibited action flag is true: $name"
    }
    Assert-True ([int](Get-RequiredProperty $Diagnostic 'existingTaskActionCount') -eq 0 -and [int](Get-RequiredProperty $Diagnostic 'existingProcessActionCount') -eq 0) 'D2 existing task/process action count changed.'
    Assert-True ([bool](Get-RequiredProperty $Diagnostic 'reviewOnly') -and -not [bool](Get-RequiredProperty $Diagnostic 'trainingEligible') -and -not [bool](Get-RequiredProperty $Diagnostic 'xmlEligible') -and -not [bool](Get-RequiredProperty $Diagnostic 'productionEligible') -and -not [bool](Get-RequiredProperty $Diagnostic 'productionRoutingEnabled')) 'D2 diagnostic authority widened.'
}

function Write-NewUtf8Json([string]$Path, [object]$Value) {
    Assert-True (-not (Test-Path -LiteralPath $Path)) "D2 response collection gate already exists: $Path"
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 24) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}

Assert-True ($Preflight -xor $Collect) 'Specify exactly one of -Preflight or -Collect.'
Assert-True ([string]$PSVersionTable.PSEdition -ceq 'Desktop' -and [int]$PSVersionTable.PSVersion.Major -eq 5 -and [int]$PSVersionTable.PSVersion.Minor -eq 1) 'D2 response collector requires Windows PowerShell 5.1.'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$expectedInvocation = Join-Path $PSScriptRoot 'O3F15L4D2_RESPONSE_COLLECTION_INVOCATION.json'
$invocationPath = [IO.Path]::GetFullPath($InvocationManifest)
Assert-True ($invocationPath.Equals($expectedInvocation, [StringComparison]::OrdinalIgnoreCase)) 'D2 response collection invocation path changed.'
Assert-True (Test-Path -LiteralPath $invocationPath -PathType Leaf) 'D2 response collection invocation is absent.'
$invocation = Get-Content -LiteralPath $invocationPath -Raw | ConvertFrom-Json
Assert-True ([string](Get-RequiredProperty $invocation 'schema') -ceq 'argos_ocv03_o3f15l4d2_response_collection_invocation_v1' -and [string](Get-RequiredProperty $invocation 'state') -ceq 'FROZEN_O3F15L4D2_RESPONSE_COLLECTION_INVOCATION') 'D2 response collection invocation changed.'
Assert-True ([string](Get-RequiredProperty $invocation 'collectorSha256') -ceq (Get-Sha256File $PSCommandPath)) 'D2 response collector is not the frozen byte set.'
Assert-True (-not [bool](Get-RequiredProperty $invocation 'requestRetryAuthorized')) 'D2 response collection cannot authorize a request retry.'

$contractPath = Resolve-RepositoryFile $projectRoot ([string](Get-RequiredProperty $invocation 'contractPath'))
$publishGatePath = Resolve-RepositoryFile $projectRoot ([string](Get-RequiredProperty $invocation 'publishGatePath'))
$certificatePath = Resolve-RepositoryFile $projectRoot ([string](Get-RequiredProperty $invocation 'endpointCertificatePath'))
foreach ($pin in @(
    @($contractPath, [string](Get-RequiredProperty $invocation 'contractSha256'), 'contract'),
    @($publishGatePath, [string](Get-RequiredProperty $invocation 'publishGateSha256'), 'publication gate'),
    @($certificatePath, [string](Get-RequiredProperty $invocation 'endpointCertificateSha256'), 'endpoint certificate')
)) {
    Assert-True (Test-Path -LiteralPath ([string]$pin[0]) -PathType Leaf) "D2 collection $($pin[2]) is absent."
    Assert-True ((Get-Sha256File ([string]$pin[0])) -ceq [string]$pin[1]) "D2 collection $($pin[2]) hash changed."
}
$contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
$publishGate = Get-Content -LiteralPath $publishGatePath -Raw | ConvertFrom-Json
Assert-True ([string]$contract.schema -ceq 'argos_ocv03_o3f15l4d2_diagnostic_contract_v1' -and [string]$contract.lifecycle -ceq 'FROZEN') 'D2 frozen contract changed.'
$requestId = [string](Get-RequiredProperty $invocation 'requestId')
$responseId = [string](Get-RequiredProperty $invocation 'responseId')
Assert-True ($requestId -cmatch '^REQ_[0-9]{8}T[0-9]{9}Z_[0-9A-F]{12}$' -and $responseId -cmatch '^R_[0-9A-F]{12}_[0-9]{17}_[0-9a-f]{8}$') 'D2 response collection identity shape changed.'
Assert-True ([string]$publishGate.state -ceq 'PASS_O3F15L4D2_PUBLISHED_EXACTLY_ONCE_AWAITING_MATCHING_SIGNED_RESPONSE' -and [string]$publishGate.requestId -ceq $requestId -and [int]$publishGate.publicationCount -eq 1 -and -not [bool]$publishGate.automaticRetryAuthorized) 'D2 publication gate changed.'

$expectedThumbprint = 'DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC'
Assert-True (([string](Get-RequiredProperty $invocation 'expectedSignerThumbprint')).Replace(' ', '').ToUpperInvariant() -ceq $expectedThumbprint) 'D2 endpoint signer thumbprint pin changed.'
$certificate = New-Object Security.Cryptography.X509Certificates.X509Certificate2($certificatePath)
Assert-True ($certificate.Thumbprint.ToUpperInvariant() -ceq $expectedThumbprint) 'D2 endpoint certificate thumbprint changed.'
$maximumEntryBytes = [int64](Get-RequiredProperty $invocation 'maximumZipEntryBytes')
$maximumResponseBytes = [int64](Get-RequiredProperty $invocation 'maximumSignedResultBytes')
Assert-True ($maximumEntryBytes -eq 8388608 -and $maximumResponseBytes -eq 8388608 -and [int64]$contract.response.maximumConstructedResponseBytes -eq $maximumResponseBytes) 'D2 response collection byte bounds changed.'

$expectedShare = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$drive = Get-PSDrive -Name U -PSProvider FileSystem -ErrorAction Stop
$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='U:'" -ErrorAction Stop
Assert-True ([string]$drive.DisplayRoot -ceq $expectedShare -and [string]$disk.ProviderName -ceq $expectedShare -and [int]$disk.DriveType -eq 4) 'D2 qualified persistent U: mapping changed.'
$sourceZip = [IO.Path]::GetFullPath([string](Get-RequiredProperty $invocation 'sourceZip'))
$responseRoot = [IO.Path]::GetFullPath('U:\ProjectPortalRO\responses').TrimEnd('\') + '\'
Assert-True ($sourceZip.StartsWith($responseRoot, [StringComparison]::OrdinalIgnoreCase)) 'D2 response ZIP is outside the qualified response root.'
Assert-True (Test-Path -LiteralPath $sourceZip -PathType Leaf) 'D2 exact response ZIP is absent.'
$sourceZipBytes = [int64](Get-RequiredProperty $invocation 'sourceZipBytes')
$sourceZipHash = [string](Get-RequiredProperty $invocation 'sourceZipSha256')
Assert-True ((Get-Item -LiteralPath $sourceZip).Length -eq $sourceZipBytes -and (Get-Sha256File $sourceZip) -ceq $sourceZipHash) 'D2 exact response ZIP changed.'

$localRoot = [IO.Path]::GetFullPath([string](Get-RequiredProperty $invocation 'localRoot'))
$gatePath = [IO.Path]::GetFullPath([string](Get-RequiredProperty $invocation 'collectionGatePath'))
Assert-True ($localRoot -ceq 'C:\O3F15D2C' -and $gatePath.Equals((Join-Path $PSScriptRoot 'O3F15L4D2_RESPONSE_COLLECTION_GATE.json'), [StringComparison]::OrdinalIgnoreCase)) 'D2 create-new response destinations changed.'
Assert-True (-not (Test-Path -LiteralPath $localRoot) -and -not (Test-Path -LiteralPath $gatePath)) 'D2 create-new response collection target already exists.'
$localZip = Join-Path $localRoot ([IO.Path]::GetFileName($sourceZip))
$partialRoot = Join-Path $localRoot ($responseId + '.partial')
$readyRoot = Join-Path $localRoot ($responseId + '.ready')
$pathTool = Join-Path $projectRoot 'utilities\Confirm-ArgosPathBudget.ps1'
$pathGate = & $pathTool -CandidatePath @($localZip, (Join-Path $partialRoot 'MAINTENANCE.stdout.txt'), (Join-Path $partialRoot 'PORTAL_RESPONSE_MANIFEST.json'), (Join-Path $readyRoot 'RESULT.json'), $gatePath) -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
Assert-True ([string]$pathGate.state -ceq 'PASS_PATH_BUDGET') 'D2 response collection path budget failed.'

$entryBytes = @{}
$archive = [IO.Compression.ZipFile]::OpenRead($sourceZip)
try {
    $fileEntries = @($archive.Entries | Where-Object { -not [string]::IsNullOrEmpty($_.Name) })
    Assert-True ($fileEntries.Count -ge 3 -and $fileEntries.Count -le 8) 'D2 response ZIP file cardinality is outside its bound.'
    $seenPaths = New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($entry in $fileEntries) {
        Assert-True (-not [IO.Path]::IsPathRooted($entry.FullName) -and $entry.FullName -notmatch '(^|[\\/])\.\.([\\/]|$)' -and $entry.FullName -notmatch '[\\/]' -and $entry.FullName.Length -le 80 -and $seenPaths.Add($entry.FullName)) "D2 response ZIP path is unsafe or duplicated: $($entry.FullName)"
        $entryBytes[$entry.FullName] = [byte[]](Read-ZipEntryBytes $entry $maximumEntryBytes)
    }
} finally {
    $archive.Dispose()
}
Assert-True ($entryBytes.ContainsKey('PORTAL_RESPONSE_MANIFEST.json') -and $entryBytes.ContainsKey('PORTAL_RESPONSE_MANIFEST.sig')) 'D2 signed response manifest or signature is absent.'
$manifestBytes = [byte[]]$entryBytes['PORTAL_RESPONSE_MANIFEST.json']
$signatureBytes = [byte[]]$entryBytes['PORTAL_RESPONSE_MANIFEST.sig']
Assert-True ($manifestBytes.Length -le 65536 -and $signatureBytes.Length -le 16384) 'D2 response manifest/signature exceeds its bound.'
$rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPublicKey($certificate)
try { $signatureVerified = $rsa.VerifyData($manifestBytes, $signatureBytes, [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1) }
finally { $rsa.Dispose() }
Assert-True $signatureVerified 'D2 response manifest RSA-SHA256-PKCS1 signature is invalid.'
$responseManifest = $utf8.GetString($manifestBytes) | ConvertFrom-Json
Assert-True ([string]$responseManifest.schema -ceq 'argos_project_portal_response_manifest_v1' -and [string]$responseManifest.requestId -ceq $requestId -and [string]$responseManifest.responseId -ceq $responseId -and [string]$responseManifest.sourceRole -ceq 'JBOD') 'D2 response manifest identity changed.'
Assert-True ([string]$responseManifest.signatureAlgorithm -ceq 'RSA-SHA256-PKCS1' -and ([string]$responseManifest.signerThumbprint).Replace(' ', '').ToUpperInvariant() -ceq $expectedThumbprint) 'D2 response signature declaration changed.'
Assert-True ([bool]$responseManifest.reviewOnly -and -not [bool]$responseManifest.trainingEligible -and -not [bool]$responseManifest.xmlEligible -and -not [bool]$responseManifest.productionEligible -and -not [bool]$responseManifest.productionRoutingEnabled -and -not [bool]$responseManifest.credentialsIncluded) 'D2 response manifest authority widened.'
$endpointState = [string]$responseManifest.state
Assert-True ($endpointState -cin @('PASS_MAINTENANCE_PATCH', 'FAILED', 'FAILED_RESPONSE_CONSTRUCTION')) 'D2 response is not terminal.'
$declaredFiles = @($responseManifest.files)
$expectedEntryNames = @('PORTAL_RESPONSE_MANIFEST.json', 'PORTAL_RESPONSE_MANIFEST.sig') + @($declaredFiles | ForEach-Object { [string]$_.path })
Assert-True ($expectedEntryNames.Count -eq $fileEntries.Count -and @(Compare-Object ($expectedEntryNames | Sort-Object) ($fileEntries.FullName | Sort-Object)).Count -eq 0) 'D2 response ZIP entry set differs from its signed manifest.'
$signedResultBytes = 0L
foreach ($record in $declaredFiles) {
    $relative = [string]$record.path
    Assert-True ($entryBytes.ContainsKey($relative)) "D2 signed response entry is absent: $relative"
    $bytes = [byte[]]$entryBytes[$relative]
    Assert-True ($bytes.Length -eq [int64]$record.bytes -and (Get-Sha256Bytes $bytes) -ceq [string]$record.sha256) "D2 signed response entry changed: $relative"
    $signedResultBytes += $bytes.Length
}
$constructedResponseBytes = [int64]$signedResultBytes + [int64]$manifestBytes.Length + [int64]$signatureBytes.Length
Assert-True ($constructedResponseBytes -le $maximumResponseBytes) 'D2 complete signed constructed response exceeds its bound.'

$classificationValidated = $false
$classificationSummary = $null
$diagnosticState = $null
$failureCode = $null
if ($entryBytes.ContainsKey('MAINTENANCE.stdout.txt') -and ([byte[]]$entryBytes['MAINTENANCE.stdout.txt']).Length -gt 0) {
    $stdoutText = $utf8.GetString([byte[]]$entryBytes['MAINTENANCE.stdout.txt'])
    Assert-True ([Text.Encoding]::UTF8.GetByteCount($stdoutText) -le [int64]$contract.response.maximumEmittedJsonBytes) 'D2 maintenance stdout exceeds the diagnostic JSON bound.'
    try { $diagnostic = $stdoutText.Trim() | ConvertFrom-Json } catch { throw "D2 diagnostic JSON is malformed: $($_.Exception.Message)" }
    Assert-True ([string](Get-RequiredProperty $diagnostic 'schema') -ceq 'argos_ocv03_o3f15l4d2_metadata_diagnostic_v1') 'D2 diagnostic schema changed.'
    $diagnosticState = [string](Get-RequiredProperty $diagnostic 'state')
    Assert-True ($diagnosticState -cin @('COMPLETE_O3F15L4D2_METADATA_DIAGNOSTIC', 'HOLD_O3F15L4D2_METADATA_DIAGNOSTIC')) 'D2 diagnostic terminal state changed.'
    Confirm-DiagnosticAuthority $diagnostic
    if ($diagnosticState -ceq 'COMPLETE_O3F15L4D2_METADATA_DIAGNOSTIC') {
        Assert-True ($endpointState -ceq 'PASS_MAINTENANCE_PATCH') 'D2 complete diagnostic was not returned by a passing endpoint transaction.'
        Assert-True ([string](Get-RequiredProperty $diagnostic 'runnerSchema') -ceq 'argos_ocv03_o3f15l4_preflight_v1' -and [string](Get-RequiredProperty $diagnostic 'runnerState') -ceq 'PASS_O3F15L4_FRONT_RECONCILE_PREFLIGHT') 'D2 runner terminal contract changed.'
        Assert-True ([string](Get-RequiredProperty $diagnostic 'runnerSha256') -ceq [string]$contract.pins.runner.sha256 -and [string](Get-RequiredProperty $diagnostic 'focusedTestSha256') -ceq [string]$contract.pins.focusedTest.sha256) 'D2 runner provenance changed.'
        $cohorts = Get-RequiredProperty $diagnostic 'cohortCounts'
        Assert-True ([int]$cohorts.HOLDOUT18 -eq 18 -and [int]$cohorts.CURRENT_TAIL -eq 247 -and [int]$cohorts.FULL_TAIL -eq 713 -and [int]$cohorts.FULL978 -eq 978) 'D2 cohort counts changed.'
        $child = Get-RequiredProperty $diagnostic 'child'
        Assert-True ([bool]$child.started -and [int]$child.exitCode -eq 0 -and -not [bool]$child.timedOut -and -not [bool]$child.outputExceededBound -and [int64]$child.stderrBytes -eq 0 -and [int64]$child.combinedBytes -le [int64]$contract.child.maximumCombinedStdoutStderrBytes) 'D2 sole child outcome changed.'
        Assert-True ([string]$child.executable -ceq 'D:/AFCV1/rt/python.exe' -and (@($child.arguments) -join '|') -ceq '-I|-B|Run-O3F15L4FrontReconcile.py|PREFLIGHT') 'D2 sole child invocation changed.'
        $holds = Get-RequiredProperty $diagnostic 'holds'
        Assert-ExactProperties $holds @('fullFrontside', 'laterPrerequisitesPreserved', 'patternedFront', 'slot02MultipleCandidateAmbiguity', 'slot16RareHotspot') 'D2 holds'
        Assert-True ([int]$holds.fullFrontside -eq 184 -and [int]$holds.patternedFront -eq 12 -and [bool]$holds.slot02MultipleCandidateAmbiguity -and [bool]$holds.slot16RareHotspot -and [bool]$holds.laterPrerequisitesPreserved) 'D2 holds were not preserved.'
        $classificationSummary = Confirm-Classification (Get-RequiredProperty $diagnostic 'classification') $contract
        $projection = Get-RequiredProperty $diagnostic 'classificationProjection'
        Assert-True ([int]$projection.validatedIdentityCount -eq 978 -and [int]$projection.validatedSourceLeafCount -eq 1956 -and [string]$projection.orderedIdentitySha256 -ceq [string]$classificationSummary.orderedIdentitySha256 -and [string]$projection.orderedSourceLeafRecordSha256 -ceq [string]$classificationSummary.orderedSourceLeafRecordSha256 -and [string]$projection.orderedClassificationRecordSha256 -ceq [string]$classificationSummary.orderedClassificationRecordSha256) 'D2 classification projection changed.'
        $classificationValidated = $true
    } else {
        $failureCode = [string](Get-RequiredProperty $diagnostic 'failureCode')
    }
}

if ($endpointState -ceq 'PASS_MAINTENANCE_PATCH') {
    Assert-True ($classificationValidated -and $entryBytes.ContainsKey('MAINTENANCE.stderr.txt') -and ([byte[]]$entryBytes['MAINTENANCE.stderr.txt']).Length -eq 0 -and $entryBytes.ContainsKey('RESULT.json')) 'D2 passing endpoint response lacks the exact successful diagnostic leaves.'
    $maintenance = $utf8.GetString([byte[]]$entryBytes['RESULT.json']) | ConvertFrom-Json
    Assert-True ([string]$maintenance.schema -ceq 'argos_project_portal_maintenance_result_v1' -and [string]$maintenance.state -ceq 'PASS_MAINTENANCE_PATCH' -and [int]$maintenance.exitCode -eq 0 -and [int]$maintenance.changedFiles -eq 1 -and [string]$maintenance.entryPoint -ceq 'payload/Invoke-O3F15L4D2.ps1' -and [bool]$maintenance.reviewOnly -and -not [bool]$maintenance.productionRoutingEnabled) 'D2 maintenance result changed.'
} else {
    Assert-True ($entryBytes.ContainsKey('FAILURE.json')) 'D2 signed endpoint failure lacks FAILURE.json.'
    $failure = $utf8.GetString([byte[]]$entryBytes['FAILURE.json']) | ConvertFrom-Json
    Assert-True ([string]$failure.state -cin @('FAILED', 'FAILED_RESPONSE_CONSTRUCTION') -and [bool]$failure.reviewOnly -and -not [bool]$failure.productionRoutingEnabled) 'D2 signed endpoint failure authority changed.'
}

$preflightResult = [ordered]@{
    schema = 'argos_ocv03_o3f15l4d2_response_collection_preflight_v1'
    observedUtc = [DateTime]::UtcNow.ToString('o')
    state = $(if ($classificationValidated) { 'PASS_O3F15L4D2_RESPONSE_COLLECTION_PREFLIGHT' } else { 'HOLD_O3F15L4D2_SIGNED_TERMINAL_RESPONSE_PREFLIGHT' })
    requestId = $requestId
    responseId = $responseId
    responseZipBytes = $sourceZipBytes
    responseZipSha256 = $sourceZipHash
    responseManifestSha256 = Get-Sha256Bytes $manifestBytes
    responseSignatureVerified = $true
    responseSignatureAlgorithm = 'RSA-SHA256-PKCS1'
    endpointSignerThumbprint = $expectedThumbprint
    endpointState = $endpointState
    diagnosticState = $diagnosticState
    failureCode = $failureCode
    classificationValidated = $classificationValidated
    classificationSummary = $classificationSummary
    signedResultBytes = $signedResultBytes
    constructedResponseBytes = $constructedResponseBytes
    responseManifestBytes = [int64]$manifestBytes.Length
    responseSignatureBytes = [int64]$signatureBytes.Length
    maximumSignedResultBytes = $maximumResponseBytes
    maximumZipEntryBytes = $maximumEntryBytes
    pathState = [string]$pathGate.state
    mutationsPerformed = $false
    requestRepublished = $false
    requestRetryAuthorized = $false
    persistentMappingChanged = $false
    imageBytesRead = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
}
if ($Preflight) {
    $preflightResult | ConvertTo-Json -Depth 18
    return
}

[void](New-Item -ItemType Directory -Path $localRoot)
$inputStream = [IO.File]::Open($sourceZip, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
$outputStream = New-Object IO.FileStream($localZip, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
try { $inputStream.CopyTo($outputStream, 1048576); $outputStream.Flush() }
finally { $outputStream.Dispose(); $inputStream.Dispose() }
Assert-True ((Get-Sha256File $localZip) -ceq $sourceZipHash) 'D2 local response ZIP changed during copy.'
[void](New-Item -ItemType Directory -Path $partialRoot)
foreach ($entryName in @($entryBytes.Keys | Sort-Object)) {
    $destination = Join-Path $partialRoot $entryName
    Assert-True (-not (Test-Path -LiteralPath $destination)) "D2 create-new extracted response leaf exists: $entryName"
    [IO.File]::WriteAllBytes($destination, [byte[]]$entryBytes[$entryName])
}
Assert-True ((Get-Sha256File (Join-Path $partialRoot 'PORTAL_RESPONSE_MANIFEST.json')) -ceq (Get-Sha256Bytes $manifestBytes)) 'D2 extracted response manifest changed.'
$verifier = Join-Path $projectRoot 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalResponse.ps1'
& $verifier -PackagePath $partialRoot -EndpointCertificatePath $certificatePath -ExpectedSourceRole JBOD -ExpectedRequestId $requestId | Out-Null
[IO.Directory]::Move($partialRoot, $readyRoot)

$gate = [ordered]@{
    schema = 'argos_ocv03_o3f15l4d2_response_collection_gate_v1'
    collectedUtc = [DateTime]::UtcNow.ToString('o')
    state = $(if ($classificationValidated) { 'PASS_O3F15L4D2_MATCHING_SIGNED_METADATA_CLASSIFICATION_COLLECTED' } else { 'HOLD_O3F15L4D2_MATCHING_SIGNED_TERMINAL_RESPONSE_COLLECTED' })
    disposition = $(if ($classificationValidated) { 'PENDING_GATE' } else { 'DIAGNOSTIC_ONLY' })
    requestId = $requestId
    responseId = $responseId
    responseZipPath = $localZip
    responseZipBytes = $sourceZipBytes
    responseZipSha256 = $sourceZipHash
    responseManifestSha256 = Get-Sha256Bytes $manifestBytes
    responseSignatureVerified = $true
    responseSignatureAlgorithm = 'RSA-SHA256-PKCS1'
    endpointSignerThumbprint = $expectedThumbprint
    endpointState = $endpointState
    diagnosticState = $diagnosticState
    failureCode = $failureCode
    classificationValidated = $classificationValidated
    classificationSummary = $classificationSummary
    extractedResponseRoot = $readyRoot
    signedResultBytes = $signedResultBytes
    constructedResponseBytes = $constructedResponseBytes
    responseManifestBytes = [int64]$manifestBytes.Length
    responseSignatureBytes = [int64]$signatureBytes.Length
    maximumConstructedResponseBytes = $maximumResponseBytes
    fullFrontsideHoldCountPreserved = 184
    patternedFrontHoldCountPreserved = 12
    slot02AmbiguityPreserved = $true
    slot16RareHotspotPreserved = $true
    sourceImageBytesRead = $false
    detectorResultRootCreated = $false
    sourceMutationOrDeletionPerformed = $false
    existingTaskOrProcessActionCount = 0
    providerActivated = $false
    selectorOrThresholdChanged = $false
    holdsAutomaticallyCleared = $false
    requestRepublished = $false
    requestRetryAuthorized = $false
    persistentMappingChanged = $false
    reviewOnly = $true
    trainingEligible = $false
    xmlEligible = $false
    productionEligible = $false
    productionRoutingEnabled = $false
}
Write-NewUtf8Json $gatePath $gate
$gate | ConvertTo-Json -Depth 20

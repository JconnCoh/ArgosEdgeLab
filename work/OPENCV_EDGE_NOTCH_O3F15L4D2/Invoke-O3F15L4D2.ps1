#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$PackageRoot = '',
    [switch]$Preflight,
    [switch]$Rehearsal,
    [string]$RuntimePath = '',
    [string]$RunnerPath = '',
    [string]$ExpectedRunnerSha256 = '',
    [ValidateRange(1, 600)][int]$RehearsalTimeoutSeconds = 3
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = New-Object Text.UTF8Encoding($false)
$sourceRoot = 'D:\KLARFExport'
$classNames = @(
    'DIRECT_SAFE',
    'VERIFIED_SHORT_ALIAS_REQUIRED',
    'DIRECT_USE_HARD_STOP_ALIAS_ONLY'
)
$severity = @{
    DIRECT_SAFE = 0
    VERIFIED_SHORT_ALIAS_REQUIRED = 1
    DIRECT_USE_HARD_STOP_ALIAS_ONLY = 2
}
$process = $null
$stdoutTask = $null
$stderrTask = $null
$stdout = ''
$stderr = ''
$childStarted = $false
$childPid = $null
$childStartedUtc = $null
$timedOut = $false
$outputExceeded = $false
$effectivePackageRoot = $PackageRoot
$effectiveRuntimePath = $RuntimePath
$effectiveRunnerPath = $RunnerPath

function Require([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-Sha256([string]$Path) {
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash.ToUpperInvariant()
}

function Get-TextSha256([string]$Value) {
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try {
        ([BitConverter]::ToString($algorithm.ComputeHash($utf8.GetBytes($Value)))).Replace('-', '')
    } finally {
        $algorithm.Dispose()
    }
}

function Get-Property([object]$Value, [string]$Name) {
    $property = $Value.PSObject.Properties[$Name]
    Require ($null -ne $property) "Required property absent: $Name"
    $property.Value
}

function Assert-ExactProperties([object]$Value, [string[]]$Expected, [string]$Label) {
    $actual = @($Value.PSObject.Properties | ForEach-Object { $_.Name } | Sort-Object)
    $wanted = @($Expected | Sort-Object)
    Require (($actual -join '|') -ceq ($wanted -join '|')) "$Label property set changed."
}

function Get-ExactInt64([object]$Value, [string]$Label) {
    $integerTypes = @([byte], [sbyte], [int16], [uint16], [int32], [uint32], [int64], [uint64])
    $isInteger = $false
    foreach ($type in $integerTypes) {
        if ($Value -is $type) { $isInteger = $true; break }
    }
    Require $isInteger "$Label is not an integer."
    [int64]$Value
}

function Assert-HexSha256([object]$Value, [string]$Label) {
    Require ($Value -is [string] -and [string]$Value -cmatch '^[0-9A-F]{64}$') "$Label is not uppercase SHA-256."
}

function Normalize-WindowsPath([string]$Value) {
    $Value.Replace('/', '\').TrimEnd('\')
}

function Get-MaximumComponentLength([string]$Value) {
    $maximum = 0
    foreach ($component in @($Value -split '[\\/]' | Where-Object { -not [string]::IsNullOrEmpty($_) })) {
        if ($component.Length -gt $maximum) { $maximum = $component.Length }
    }
    $maximum
}

function Get-WindowsLeafName([string]$Value) {
    $separator = [Math]::Max($Value.LastIndexOf([char]92), $Value.LastIndexOf([char]47))
    if ($separator -lt 0) { return $Value }
    if ($separator + 1 -ge $Value.Length) { return '' }
    $Value.Substring($separator + 1)
}

function Get-BoundedTail([string]$Value, [int]$MaximumCharacters, [int]$MaximumBytes) {
    $tail = if ($Value.Length -le $MaximumCharacters) { $Value } else { $Value.Substring($Value.Length - $MaximumCharacters) }
    while ($tail.Length -gt 0 -and $utf8.GetByteCount($tail) -gt $MaximumBytes) {
        $tail = $tail.Substring(1)
    }
    [ordered]@{
        value = $tail
        characters = $tail.Length
        bytes = $utf8.GetByteCount($tail)
        truncated = ($tail.Length -ne $Value.Length)
    }
}

function Write-TerminalJson([object]$Value, [int64]$MaximumBytes, [int]$ExitCode) {
    $json = $Value | ConvertTo-Json -Depth 32 -Compress
    $line = $json + [Environment]::NewLine
    Require ($utf8.GetByteCount($line) -le $MaximumBytes) 'Terminal JSON exceeded its exact byte bound.'
    [Console]::Out.Write($line)
    exit $ExitCode
}

function Assert-PayloadAndTargetPins([object]$Contract, [string]$Root) {
    $payloadFiles = @(Get-Property $Contract 'payloadFiles')
    Require ($payloadFiles.Count -eq 17) 'Payload pin cardinality changed.'
    $payloadNames = New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    foreach ($record in $payloadFiles) {
        Assert-ExactProperties $record @('relativePath', 'sha256') 'Payload pin'
        $relative = [string](Get-Property $record 'relativePath')
        Require (-not [string]::IsNullOrWhiteSpace($relative) -and -not [IO.Path]::IsPathRooted($relative) -and $relative -notmatch '[\\/]' -and $relative -notmatch '^\.') "Unsafe payload pin: $relative"
        Require ($payloadNames.Add($relative)) "Duplicate payload pin: $relative"
        $path = Join-Path $Root $relative
        Require (Test-Path -LiteralPath $path -PathType Leaf) "Payload file absent: $relative"
        Require ((Get-Sha256 $path) -ceq [string](Get-Property $record 'sha256')) "Payload file changed: $relative"
    }
    foreach ($required in @('Invoke-O3F15L4D2.ps1', 'Run-O3F15L4FrontReconcile.py', 'Test-O3F15L4PathHolds.py', 'FullPerimeterWaferTopologyOpenCvR11.py', 'OCV03_NotchReviewOpenCvV1.py')) {
        Require ($payloadNames.Contains($required)) "Required payload pin absent: $required"
    }
    $targetPins = @(Get-Property $Contract 'targetPins')
    Require ($targetPins.Count -eq 9) 'Target pin cardinality changed.'
    foreach ($pin in $targetPins) {
        Assert-ExactProperties $pin @('label', 'path', 'sha256') 'Target pin'
        $path = [string](Get-Property $pin 'path')
        Require (Test-Path -LiteralPath $path -PathType Leaf) "Target pin absent: $path"
        Require ((Get-Sha256 $path) -ceq [string](Get-Property $pin 'sha256')) "Target pin changed: $path"
    }
}

function Assert-Classification([object]$Classification, [int64]$MaximumCoreBytes) {
    Assert-ExactProperties $Classification @(
        'classificationLeafIdentitySha256', 'complete', 'corpus', 'hardStopIdentities',
        'identityCount', 'orderedClassificationRecordSha256', 'orderedIdentitySha256',
        'orderedSourceLeafRecordSha256', 'pairClassificationCounts', 'pairCount',
        'serializedCoreBytes', 'serializedEvidenceLimitBytes', 'sourceLeafClassificationCounts',
        'sourceLeafCount', 'sourceLeavesByClass', 'uniqueOrderedSourceLeafCount'
    ) 'Classification'
    Require ((Get-Property $Classification 'corpus') -is [string] -and [string]$Classification.corpus -ceq 'ACTUAL_FROZEN_978') 'Classification corpus changed.'
    Require ((Get-Property $Classification 'complete') -is [bool] -and [bool]$Classification.complete) 'Classification completeness changed.'
    foreach ($row in @(
        @('pairCount', 978), @('identityCount', 978), @('sourceLeafCount', 1956), @('uniqueOrderedSourceLeafCount', 1956)
    )) {
        Require ((Get-ExactInt64 (Get-Property $Classification $row[0]) $row[0]) -eq [int64]$row[1]) "Classification cardinality changed: $($row[0])"
    }
    $coreBytes = Get-ExactInt64 (Get-Property $Classification 'serializedCoreBytes') 'serializedCoreBytes'
    $declaredLimit = Get-ExactInt64 (Get-Property $Classification 'serializedEvidenceLimitBytes') 'serializedEvidenceLimitBytes'
    Require ($coreBytes -ge 1 -and $coreBytes -le $MaximumCoreBytes -and $declaredLimit -eq $MaximumCoreBytes) 'Producer compact classification bound changed.'

    $pairCounts = Get-Property $Classification 'pairClassificationCounts'
    $leafCounts = Get-Property $Classification 'sourceLeafClassificationCounts'
    $classLists = Get-Property $Classification 'sourceLeavesByClass'
    $classHashes = Get-Property $Classification 'classificationLeafIdentitySha256'
    foreach ($value in @($pairCounts, $leafCounts, $classLists, $classHashes)) {
        Assert-ExactProperties $value $classNames 'Classification class map'
    }

    $leafKeys = New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    $identityKeys = New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    $identityByOrdinal = @{}
    $channelsByOrdinal = @{}
    $pairClassByOrdinal = @{}
    $slotRootByOrdinal = @{}
    $classKeyLists = @{}
    $allLeaves = New-Object Collections.Generic.List[object]
    $reconstructedLeafCounts = @{}
    foreach ($className in $classNames) {
        $classKeyLists[$className] = New-Object Collections.Generic.List[string]
        $reconstructedLeafCounts[$className] = 0
    }

    foreach ($className in $classNames) {
        $rows = @((Get-Property $classLists $className))
        $declaredLeafCount = Get-ExactInt64 (Get-Property $leafCounts $className) "sourceLeafClassificationCounts.$className"
        Require ($declaredLeafCount -ge 0 -and $rows.Count -eq $declaredLeafCount) "Class-list cardinality changed: $className"
        $lastOrderKey = -1
        foreach ($row in $rows) {
            $directFields = @('canonicalPath', 'channel', 'class', 'effectiveLength', 'identity', 'maximumComponentLength', 'ordinal', 'rawLength')
            $expectedFields = @(if ($className -ceq 'DIRECT_SAFE') { $directFields } else { $directFields + @('aliasPath', 'aliasPlannedEffectiveLength', 'aliasPlannedMaximumComponentLength', 'aliasPlannedRawLength') })
            Assert-ExactProperties $row $expectedFields "Classification leaf $className"
            $ordinal = [int](Get-ExactInt64 (Get-Property $row 'ordinal') 'leaf.ordinal')
            $identity = Get-Property $row 'identity'
            $channel = Get-Property $row 'channel'
            Require ($ordinal -ge 1 -and $ordinal -le 978) 'Leaf ordinal is outside the frozen corpus.'
            Require ($identity -is [string] -and -not [string]::IsNullOrWhiteSpace([string]$identity)) 'Leaf identity is invalid.'
            Require ($channel -is [string] -and [string]$channel -cin @('BF', 'DF')) 'Leaf channel is invalid.'
            Require ((Get-Property $row 'class') -is [string] -and [string]$row.class -ceq $className) 'Leaf class changed.'
            $orderKey = ([int]$ordinal * 2) + $(if ([string]$channel -ceq 'BF') { 0 } else { 1 })
            Require ($orderKey -gt $lastOrderKey) "Class-list order changed: $className"
            $lastOrderKey = $orderKey

            $marker = '|FRONT'
            $firstMarker = ([string]$identity).IndexOf($marker, [StringComparison]::Ordinal)
            Require ($firstMarker -gt 0 -and $firstMarker + $marker.Length -eq ([string]$identity).Length -and ([string]$identity).IndexOf($marker, $firstMarker + $marker.Length, [StringComparison]::Ordinal) -lt 0) 'Identity lacks one terminal |FRONT marker.'
            $anchor = ([string]$identity).Substring(0, $firstMarker).Replace('/', '\').Trim('\')
            $anchorParts = @($anchor -split '\\')
            Require ($anchorParts.Count -ge 2 -and @($anchorParts | Where-Object { [string]::IsNullOrWhiteSpace($_) -or $_ -in @('.', '..') }).Count -eq 0) 'Identity slot anchor is unsafe.'

            $canonical = Get-Property $row 'canonicalPath'
            Require ($canonical -is [string] -and -not [string]::IsNullOrWhiteSpace([string]$canonical)) 'Canonical path is invalid.'
            $canonicalText = [string]$canonical
            $directory = if ([string]$channel -ceq 'BF') { 'BrightfieldFrontsideWafer' } else { 'DarkfieldFrontsideWafer' }
            $leafName = Get-WindowsLeafName $canonicalText
            Require (-not [string]::IsNullOrWhiteSpace($leafName)) 'Canonical filename is absent.'
            $suffix = '\' + $directory + '\resizedImage\' + $leafName
            $canonicalNormalized = Normalize-WindowsPath $canonicalText
            $expectedSlotRoot = $sourceRoot + '\' + $anchor
            Require ($canonicalNormalized.EndsWith($suffix, [StringComparison]::OrdinalIgnoreCase)) 'Canonical BF/DF suffix changed.'
            $slotRoot = $canonicalNormalized.Substring(0, $canonicalNormalized.Length - $suffix.Length)
            Require ($slotRoot.Equals($expectedSlotRoot, [StringComparison]::OrdinalIgnoreCase)) 'Canonical path is not bound to its identity slot root.'

            $rawLength = Get-ExactInt64 (Get-Property $row 'rawLength') 'leaf.rawLength'
            $effectiveLength = Get-ExactInt64 (Get-Property $row 'effectiveLength') 'leaf.effectiveLength'
            $maximumComponentLength = Get-ExactInt64 (Get-Property $row 'maximumComponentLength') 'leaf.maximumComponentLength'
            $computedMaximum = Get-MaximumComponentLength $canonicalText
            Require ($rawLength -eq $canonicalText.Length -and $effectiveLength -eq $rawLength + 32 -and $maximumComponentLength -eq $computedMaximum -and $computedMaximum -le 80) 'Canonical path metrics changed.'
            if ($className -ceq 'DIRECT_SAFE') {
                Require ($effectiveLength -lt 200) 'DIRECT_SAFE boundary changed.'
            } elseif ($className -ceq 'VERIFIED_SHORT_ALIAS_REQUIRED') {
                Require ($effectiveLength -ge 200 -and $effectiveLength -lt 230) 'Alias-required boundary changed.'
            } else {
                Require ($effectiveLength -ge 230) 'Direct-use hard-stop boundary changed.'
            }

            if ($className -cne 'DIRECT_SAFE') {
                $alias = Get-Property $row 'aliasPath'
                Require ($alias -is [string]) 'Alias path is invalid.'
                $aliasText = [string]$alias
                $expectedAlias = 'Q:\' + $directory + '\resizedImage\' + $leafName
                Require ((Normalize-WindowsPath $aliasText).Equals($expectedAlias, [StringComparison]::OrdinalIgnoreCase)) 'Alias path is not bound to the canonical suffix.'
                $aliasRaw = Get-ExactInt64 (Get-Property $row 'aliasPlannedRawLength') 'leaf.aliasPlannedRawLength'
                $aliasEffective = Get-ExactInt64 (Get-Property $row 'aliasPlannedEffectiveLength') 'leaf.aliasPlannedEffectiveLength'
                $aliasMaximum = Get-ExactInt64 (Get-Property $row 'aliasPlannedMaximumComponentLength') 'leaf.aliasPlannedMaximumComponentLength'
                $computedAliasMaximum = Get-MaximumComponentLength $aliasText
                Require ($aliasRaw -eq $aliasText.Length -and $aliasEffective -eq $aliasRaw + 32 -and $aliasEffective -lt 200 -and $aliasMaximum -eq $computedAliasMaximum -and $computedAliasMaximum -le 80) 'Alias path metrics changed.'
            }

            $leafKey = "$ordinal|$identity|$channel"
            Require ($leafKeys.Add($leafKey)) 'Duplicate ordered source leaf.'
            if ($identityByOrdinal.ContainsKey($ordinal)) {
                Require ([string]$identityByOrdinal[$ordinal] -ceq [string]$identity) 'One ordinal maps to multiple identities.'
                Require ([string]$slotRootByOrdinal[$ordinal] -ceq [string]$slotRoot) 'BF/DF slot roots differ.'
            } else {
                $identityByOrdinal[$ordinal] = [string]$identity
                $slotRootByOrdinal[$ordinal] = [string]$slotRoot
                $channelsByOrdinal[$ordinal] = New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
                Require ($identityKeys.Add([string]$identity)) 'Identity is reused by multiple ordinals.'
            }
            Require ($channelsByOrdinal[$ordinal].Add([string]$channel)) 'Duplicate ordinal channel.'
            if (-not $pairClassByOrdinal.ContainsKey($ordinal) -or $severity[$className] -gt $severity[[string]$pairClassByOrdinal[$ordinal]]) {
                $pairClassByOrdinal[$ordinal] = $className
            }
            $reconstructedLeafCounts[$className] = [int64]$reconstructedLeafCounts[$className] + 1
            $classKeyLists[$className].Add("$identity|$channel")
            $allLeaves.Add($row)
        }
    }

    Require ($leafKeys.Count -eq 1956 -and $identityKeys.Count -eq 978 -and $identityByOrdinal.Count -eq 978) 'Frozen classification uniqueness changed.'
    $orderedIdentities = New-Object Collections.Generic.List[string]
    $reconstructedPairCounts = @{ DIRECT_SAFE = 0; VERIFIED_SHORT_ALIAS_REQUIRED = 0; DIRECT_USE_HARD_STOP_ALIAS_ONLY = 0 }
    foreach ($ordinal in 1..978) {
        Require ($identityByOrdinal.ContainsKey($ordinal) -and $channelsByOrdinal[$ordinal].SetEquals([string[]]@('BF', 'DF'))) "BF/DF coverage changed at ordinal $ordinal."
        $orderedIdentities.Add([string]$identityByOrdinal[$ordinal])
        $pairClass = [string]$pairClassByOrdinal[$ordinal]
        $reconstructedPairCounts[$pairClass] = [int64]$reconstructedPairCounts[$pairClass] + 1
    }
    foreach ($className in $classNames) {
        $declaredPairCount = Get-ExactInt64 (Get-Property $pairCounts $className) "pairClassificationCounts.$className"
        $declaredLeafCount = Get-ExactInt64 (Get-Property $leafCounts $className) "sourceLeafClassificationCounts.$className"
        Require ($declaredPairCount -eq [int64]$reconstructedPairCounts[$className] -and $declaredLeafCount -eq [int64]$reconstructedLeafCounts[$className]) "Reconstructed classification counts changed: $className"
        $classHash = [string](Get-Property $classHashes $className)
        Assert-HexSha256 $classHash "classificationLeafIdentitySha256.$className"
        $classText = if ($classKeyLists[$className].Count -gt 0) { ($classKeyLists[$className].ToArray() -join "`n") + "`n" } else { '' }
        Require ((Get-TextSha256 $classText) -ceq $classHash) "Class identity hash changed: $className"
    }

    $orderedIdentityHash = [string](Get-Property $Classification 'orderedIdentitySha256')
    Assert-HexSha256 $orderedIdentityHash 'orderedIdentitySha256'
    Require ((Get-TextSha256 (($orderedIdentities.ToArray() -join "`n") + "`n")) -ceq $orderedIdentityHash) 'Ordered identity hash changed.'
    $orderedLeaves = @($allLeaves.ToArray() | Sort-Object @{Expression = {[int]$_.ordinal}}, @{Expression = {if ([string]$_.channel -ceq 'BF') { 0 } else { 1 }}})
    $orderedLeafHash = [string](Get-Property $Classification 'orderedSourceLeafRecordSha256')
    Assert-HexSha256 $orderedLeafHash 'orderedSourceLeafRecordSha256'
    $orderedLeafJson = $orderedLeaves | ConvertTo-Json -Depth 16 -Compress
    Require ((Get-TextSha256 ($orderedLeafJson + "`n")) -ceq $orderedLeafHash) 'Ordered source-leaf record hash changed.'
    Assert-HexSha256 ([string](Get-Property $Classification 'orderedClassificationRecordSha256')) 'orderedClassificationRecordSha256'

    $hardStops = @((Get-Property $Classification 'hardStopIdentities'))
    $hardOrdinals = @($orderedLeaves | Where-Object { [string]$_.class -ceq 'DIRECT_USE_HARD_STOP_ALIAS_ONLY' } | ForEach-Object { [int]$_.ordinal } | Sort-Object -Unique)
    Require ($hardStops.Count -eq $hardOrdinals.Count) 'Hard-stop identity count changed.'
    for ($index = 0; $index -lt $hardStops.Count; $index++) {
        $record = $hardStops[$index]
        Assert-ExactProperties $record @('channels', 'identity', 'ordinal') 'Hard-stop identity'
        $ordinal = $hardOrdinals[$index]
        $expectedChannels = @($orderedLeaves | Where-Object { [int]$_.ordinal -eq $ordinal -and [string]$_.class -ceq 'DIRECT_USE_HARD_STOP_ALIAS_ONLY' } | ForEach-Object { [string]$_.channel })
        Require ((Get-ExactInt64 $record.ordinal 'hardStop.ordinal') -eq $ordinal -and [string]$record.identity -ceq [string]$identityByOrdinal[$ordinal] -and (@($record.channels) -join '|') -ceq ($expectedChannels -join '|')) 'Hard-stop identity list changed.'
    }

    [ordered]@{
        validatedIdentityCount = $orderedIdentities.Count
        validatedSourceLeafCount = $orderedLeaves.Count
        pairClassificationCounts = [ordered]@{
            DIRECT_SAFE = [int64]$reconstructedPairCounts.DIRECT_SAFE
            VERIFIED_SHORT_ALIAS_REQUIRED = [int64]$reconstructedPairCounts.VERIFIED_SHORT_ALIAS_REQUIRED
            DIRECT_USE_HARD_STOP_ALIAS_ONLY = [int64]$reconstructedPairCounts.DIRECT_USE_HARD_STOP_ALIAS_ONLY
        }
        sourceLeafClassificationCounts = [ordered]@{
            DIRECT_SAFE = [int64]$reconstructedLeafCounts.DIRECT_SAFE
            VERIFIED_SHORT_ALIAS_REQUIRED = [int64]$reconstructedLeafCounts.VERIFIED_SHORT_ALIAS_REQUIRED
            DIRECT_USE_HARD_STOP_ALIAS_ONLY = [int64]$reconstructedLeafCounts.DIRECT_USE_HARD_STOP_ALIAS_ONLY
        }
        orderedIdentitySha256 = $orderedIdentityHash
        orderedClassificationRecordSha256 = [string]$Classification.orderedClassificationRecordSha256
        orderedSourceLeafRecordSha256 = $orderedLeafHash
        producerCompactCoreBytes = $coreBytes
    }
}

function New-FailureEnvelope([string]$Code, [string]$Detail, [object]$Contract) {
    $detailText = [string]$Detail
    $tailCharacters = 16384
    $tailBytes = 65536
    if ($null -ne $Contract) {
        try {
            $tailCharacters = [int](Get-ExactInt64 $Contract.child.maximumFailureTailCharacters 'maximumFailureTailCharacters')
            $tailBytes = [int](Get-ExactInt64 $Contract.child.maximumFailureTailBytes 'maximumFailureTailBytes')
        } catch {}
    }
    $stdoutTail = Get-BoundedTail $stdout $tailCharacters $tailBytes
    $stderrTail = Get-BoundedTail $stderr $tailCharacters $tailBytes
    $exitCode = $null
    if ($childStarted -and $null -ne $process) {
        try { if ($process.HasExited) { $exitCode = [int]$process.ExitCode } } catch {}
    }
    $reportedExecutable = $effectiveRuntimePath
    if ([string]::IsNullOrWhiteSpace($reportedExecutable) -and $null -ne $Contract) {
        try { $reportedExecutable = [string]$Contract.child.executable } catch {}
    }
    $reportedRunnerLeaf = 'Run-O3F15L4FrontReconcile.py'
    if (-not [string]::IsNullOrWhiteSpace($effectiveRunnerPath)) {
        $reportedRunnerLeaf = Get-WindowsLeafName $effectiveRunnerPath
    } elseif ($null -ne $Contract) {
        try { $reportedRunnerLeaf = [string]$Contract.pins.runner.relativePath } catch {}
    }
    $reportedWorkingDirectory = $null
    if (-not [string]::IsNullOrWhiteSpace($effectiveRunnerPath)) {
        try { $reportedWorkingDirectory = [IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($effectiveRunnerPath)) } catch {}
    } elseif (-not [string]::IsNullOrWhiteSpace($effectivePackageRoot)) {
        $reportedWorkingDirectory = $effectivePackageRoot
    }
    [ordered]@{
        schema = 'argos_ocv03_o3f15l4d2_metadata_diagnostic_v1'
        state = 'HOLD_O3F15L4D2_METADATA_DIAGNOSTIC'
        failureCode = $Code
        detail = if ($detailText.Length -le 2048) { $detailText } else { $detailText.Substring(0, 2048) }
        child = [ordered]@{
            started = $childStarted
            pid = $childPid
            startedUtc = $childStartedUtc
            executable = $reportedExecutable
            arguments = @('-I', '-B', $reportedRunnerLeaf, 'PREFLIGHT')
            workingDirectory = $reportedWorkingDirectory
            exitCode = $exitCode
            timedOut = $timedOut
            outputExceededBound = $outputExceeded
            stdoutBytes = [int64]$utf8.GetByteCount($stdout)
            stderrBytes = [int64]$utf8.GetByteCount($stderr)
            combinedBytes = [int64]$utf8.GetByteCount($stdout) + [int64]$utf8.GetByteCount($stderr)
            stdoutSha256 = Get-TextSha256 $stdout
            stderrSha256 = Get-TextSha256 $stderr
            stdoutTail = [string]$stdoutTail.value
            stdoutTailBytes = [int]$stdoutTail.bytes
            stdoutTruncated = [bool]$stdoutTail.truncated
            stderrTail = [string]$stderrTail.value
            stderrTailBytes = [int]$stderrTail.bytes
            stderrTruncated = [bool]$stderrTail.truncated
        }
        selectorOrThresholdChanged = $false
        sourceImageBytesRead = $false
        detectorResultRootCreated = $false
        qSubstUsed = $false
        selfTestUsed = $false
        focusedTestUsed = $false
        gateUsed = $false
        runUsed = $false
        backgroundLaunchUsed = $false
        providerActivated = $false
        sourceMutationPerformed = $false
        sourceDeletionPerformed = $false
        existingTaskActionCount = 0
        existingProcessActionCount = 0
        holdCleared = $false
        retryUsed = $false
        mutationsPerformed = $false
        reviewOnly = $true
        trainingEligible = $false
        xmlEligible = $false
        productionEligible = $false
        productionRoutingEnabled = $false
    }
}

$contract = $null
try {
    if ([string]::IsNullOrWhiteSpace($effectivePackageRoot)) { $effectivePackageRoot = $PSScriptRoot }
    $effectivePackageRoot = [IO.Path]::GetFullPath($effectivePackageRoot)
    $contractPath = Join-Path $effectivePackageRoot 'O3F15L4D2_DIAGNOSTIC_CONTRACT.json'
    Require (Test-Path -LiteralPath $contractPath -PathType Leaf) 'D2 diagnostic contract is absent.'
    $contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
    Assert-ExactProperties $contract @(
        'child', 'classification', 'createdUtc', 'expectedComputerName', 'holds', 'lifecycle',
        'mode', 'payloadFiles', 'pins', 'productionEligible', 'productionRoutingEnabled',
        'prohibitions', 'response', 'reviewOnly', 'revision', 'routePins', 'schema', 'state',
        'targetPins', 'trainingEligible', 'xmlEligible'
    ) 'D2 diagnostic contract'
    Require ([string]$contract.schema -ceq 'argos_ocv03_o3f15l4d2_diagnostic_contract_v1' -and [string]$contract.revision -ceq 'O3F15L4D2') 'D2 diagnostic contract identity changed.'
    if ($Rehearsal) {
        $draftContract = [string]$contract.lifecycle -ceq 'DRAFT' -and [string]$contract.state -ceq 'DRAFT_O3F15L4D2_METADATA_DIAGNOSTIC_CONTRACT'
        $frozenContract = [string]$contract.lifecycle -ceq 'FROZEN' -and [string]$contract.state -ceq 'FROZEN_O3F15L4D2_METADATA_DIAGNOSTIC_CONTRACT'
        Require ($draftContract -or $frozenContract) 'D2 rehearsal requires a consistently paired draft or frozen contract.'
    } else {
        Require ([string]$contract.lifecycle -ceq 'FROZEN' -and [string]$contract.state -ceq 'FROZEN_O3F15L4D2_METADATA_DIAGNOSTIC_CONTRACT') 'D2 live execution requires the once-frozen contract.'
    }
    Require ([bool]$contract.reviewOnly -and -not [bool]$contract.trainingEligible -and -not [bool]$contract.xmlEligible -and -not [bool]$contract.productionEligible -and -not [bool]$contract.productionRoutingEnabled) 'D2 authority widened.'
    foreach ($property in @($contract.prohibitions.PSObject.Properties)) { Require ($property.Value -is [bool] -and [bool]$property.Value) "D2 prohibition changed: $($property.Name)" }
    Require ((Get-ExactInt64 $contract.child.maximumCount 'child.maximumCount') -eq 1 -and [string]::Join('|', @($contract.child.arguments)) -ceq '-I|-B|Run-O3F15L4FrontReconcile.py|PREFLIGHT') 'D2 sole-child selector changed.'
    $maximumChildBytes = Get-ExactInt64 $contract.child.maximumCombinedStdoutStderrBytes 'maximumCombinedStdoutStderrBytes'
    $maximumCoreBytes = Get-ExactInt64 $contract.classification.maximumSerializedCoreBytes 'maximumSerializedCoreBytes'
    $maximumJsonBytes = Get-ExactInt64 $contract.response.maximumEmittedJsonBytes 'maximumEmittedJsonBytes'
    Require ($maximumChildBytes -eq 5242880 -and $maximumCoreBytes -eq 4194304 -and $maximumJsonBytes -eq 7340032 -and (Get-ExactInt64 $contract.response.maximumConstructedResponseBytes 'maximumConstructedResponseBytes') -eq 8388608) 'D2 byte contract changed.'

    if ([string]::IsNullOrWhiteSpace($effectiveRuntimePath)) { $effectiveRuntimePath = [string]$contract.child.executable }
    if ([string]::IsNullOrWhiteSpace($effectiveRunnerPath)) { $effectiveRunnerPath = Join-Path $effectivePackageRoot ([string]$contract.pins.runner.relativePath) }
    $effectiveRuntimePath = [IO.Path]::GetFullPath($effectiveRuntimePath)
    $effectiveRunnerPath = [IO.Path]::GetFullPath($effectiveRunnerPath)
    if ($Rehearsal) {
        Require (-not [string]::IsNullOrWhiteSpace($ExpectedRunnerSha256)) 'D2 rehearsal runner hash is absent.'
        $expectedRunnerHash = $ExpectedRunnerSha256.ToUpperInvariant()
    } else {
        Require ([Environment]::MachineName -ceq [string]$contract.expectedComputerName) 'D2 request reached the wrong endpoint.'
        Require ($effectiveRuntimePath.Equals([IO.Path]::GetFullPath([string]$contract.child.executable), [StringComparison]::OrdinalIgnoreCase)) 'D2 live runtime path changed.'
        Require ($effectiveRunnerPath.Equals([IO.Path]::GetFullPath((Join-Path $effectivePackageRoot ([string]$contract.pins.runner.relativePath))), [StringComparison]::OrdinalIgnoreCase)) 'D2 live runner path changed.'
        Assert-PayloadAndTargetPins $contract $effectivePackageRoot
        Require ((Get-Sha256 $effectiveRuntimePath) -ceq [string]$contract.pins.runtime.sha256) 'D2 runtime hash changed.'
        $expectedRunnerHash = [string]$contract.pins.runner.sha256
    }
    Require (Test-Path -LiteralPath $effectiveRuntimePath -PathType Leaf) 'D2 runtime is absent.'
    Require (Test-Path -LiteralPath $effectiveRunnerPath -PathType Leaf) 'D2 runner is absent.'
    Require ((Get-Sha256 $effectiveRunnerPath) -ceq $expectedRunnerHash) 'D2 runner hash changed.'

    if ($Preflight) {
        Write-TerminalJson ([ordered]@{
            schema = 'argos_ocv03_o3f15l4d2_entrypoint_preflight_v1'
            state = 'PASS_O3F15L4D2_ENTRYPOINT_PREFLIGHT'
            rehearsal = [bool]$Rehearsal
            childStarted = $false
            mutationsPerformed = $false
            reviewOnly = $true
            productionRoutingEnabled = $false
        }) $maximumJsonBytes 0
    }

    $start = New-Object Diagnostics.ProcessStartInfo
    $start.FileName = $effectiveRuntimePath
    $start.WorkingDirectory = [IO.Path]::GetDirectoryName($effectiveRunnerPath)
    $start.Arguments = '-I -B "' + (Get-WindowsLeafName $effectiveRunnerPath) + '" PREFLIGHT'
    $start.UseShellExecute = $false
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.CreateNoWindow = $true
    $start.EnvironmentVariables['PYTHONDONTWRITEBYTECODE'] = '1'
    $start.EnvironmentVariables['PYTHONNOUSERSITE'] = '1'
    $start.EnvironmentVariables['PYTHONUTF8'] = '1'
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $start
    Require $process.Start() 'D2 PREFLIGHT child did not start.'
    $childStarted = $true
    $childPid = [int]$process.Id
    $childStartedUtc = $process.StartTime.ToUniversalTime().ToString('o')
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $timeoutSeconds = if ($Rehearsal) { $RehearsalTimeoutSeconds } else { [int](Get-ExactInt64 $contract.child.timeoutSeconds 'child.timeoutSeconds') }
    $timedOut = -not $process.WaitForExit($timeoutSeconds * 1000)
    if ($timedOut) {
        try { $process.Kill() } catch {}
        [void]$process.WaitForExit(5000)
    }
    try { $stdout = [string]$stdoutTask.GetAwaiter().GetResult() } catch {}
    try { $stderr = [string]$stderrTask.GetAwaiter().GetResult() } catch {}
    $combinedBytes = [int64]$utf8.GetByteCount($stdout) + [int64]$utf8.GetByteCount($stderr)
    $outputExceeded = $combinedBytes -gt $maximumChildBytes
    Require (-not $timedOut) 'D2 PREFLIGHT child timed out.'
    Require (-not $outputExceeded) 'D2 PREFLIGHT child output exceeded its combined bound.'
    Require ([int]$process.ExitCode -eq 0) "D2 PREFLIGHT child exited $($process.ExitCode)."
    Require ([string]::IsNullOrEmpty($stderr)) 'D2 PREFLIGHT child emitted stderr.'

    try { $runnerResult = $stdout | ConvertFrom-Json } catch { throw "D2 child JSON parse failed: $($_.Exception.Message)" }
    Assert-ExactProperties $runnerResult @('actualFrozen978LexicalClassification', 'cohortCounts', 'focusedTestSha256', 'mutationsPerformed', 'runnerPath', 'runnerSha256', 'schema', 'state') 'D2 runner result'
    Require ([string]$runnerResult.schema -ceq 'argos_ocv03_o3f15l4_preflight_v1' -and [string]$runnerResult.state -ceq 'PASS_O3F15L4_FRONT_RECONCILE_PREFLIGHT') 'D2 runner schema/state changed.'
    Require ([string]$runnerResult.runnerSha256 -ceq [string]$contract.pins.runner.sha256 -and [string]$runnerResult.focusedTestSha256 -ceq [string]$contract.pins.focusedTest.sha256 -and $runnerResult.mutationsPerformed -is [bool] -and -not [bool]$runnerResult.mutationsPerformed) 'D2 runner provenance changed.'
    if (-not $Rehearsal) {
        Require ([IO.Path]::GetFullPath([string]$runnerResult.runnerPath).Equals($effectiveRunnerPath, [StringComparison]::OrdinalIgnoreCase)) 'D2 runner reported a different execution path.'
    } else {
        Require ((Split-Path -Leaf ([string]$runnerResult.runnerPath)) -ceq 'Run-O3F15L4FrontReconcile.py') 'D2 rehearsal runner basename changed.'
    }
    Assert-ExactProperties $runnerResult.cohortCounts @('CURRENT_TAIL', 'FULL978', 'FULL_TAIL', 'HOLDOUT18') 'D2 cohort counts'
    foreach ($row in @(@('HOLDOUT18', 18), @('CURRENT_TAIL', 247), @('FULL_TAIL', 713), @('FULL978', 978))) {
        Require ((Get-ExactInt64 (Get-Property $runnerResult.cohortCounts $row[0]) "cohortCounts.$($row[0])") -eq [int64]$row[1]) "D2 cohort count changed: $($row[0])"
    }
    $projection = Assert-Classification $runnerResult.actualFrozen978LexicalClassification $maximumCoreBytes
    $result = [ordered]@{
        schema = 'argos_ocv03_o3f15l4d2_metadata_diagnostic_v1'
        state = 'COMPLETE_O3F15L4D2_METADATA_DIAGNOSTIC'
        runnerSchema = [string]$runnerResult.schema
        runnerState = [string]$runnerResult.state
        runnerPath = [string]$runnerResult.runnerPath
        runnerSha256 = [string]$runnerResult.runnerSha256
        focusedTestSha256 = [string]$runnerResult.focusedTestSha256
        cohortCounts = $runnerResult.cohortCounts
        classification = $runnerResult.actualFrozen978LexicalClassification
        classificationProjection = $projection
        child = [ordered]@{
            started = $true
            pid = $childPid
            startedUtc = $childStartedUtc
            executable = $effectiveRuntimePath
            arguments = @('-I', '-B', (Get-WindowsLeafName $effectiveRunnerPath), 'PREFLIGHT')
            workingDirectory = [IO.Path]::GetDirectoryName($effectiveRunnerPath)
            exitCode = 0
            timedOut = $false
            outputExceededBound = $false
            stdoutBytes = [int64]$utf8.GetByteCount($stdout)
            stderrBytes = 0
            combinedBytes = $combinedBytes
            stdoutSha256 = Get-TextSha256 $stdout
            stderrSha256 = Get-TextSha256 ''
        }
        selectorOrThresholdChanged = $false
        sourceImageBytesRead = $false
        detectorResultRootCreated = $false
        qSubstUsed = $false
        selfTestUsed = $false
        focusedTestUsed = $false
        gateUsed = $false
        runUsed = $false
        backgroundLaunchUsed = $false
        providerActivated = $false
        sourceMutationPerformed = $false
        sourceDeletionPerformed = $false
        existingTaskActionCount = 0
        existingProcessActionCount = 0
        holdCleared = $false
        retryUsed = $false
        mutationsPerformed = $false
        holds = [ordered]@{
            fullFrontside = 184
            patternedFront = 12
            slot02MultipleCandidateAmbiguity = $true
            slot16RareHotspot = $true
            laterPrerequisitesPreserved = $true
        }
        reviewOnly = $true
        trainingEligible = $false
        xmlEligible = $false
        productionEligible = $false
        productionRoutingEnabled = $false
    }
    Write-TerminalJson $result $maximumJsonBytes 0
} catch {
    if ($childStarted -and $null -ne $process) {
        try {
            if (-not $process.HasExited) { $process.Kill(); [void]$process.WaitForExit(5000) }
        } catch {}
        if ([string]::IsNullOrEmpty($stdout) -and $null -ne $stdoutTask) { try { $stdout = [string]$stdoutTask.GetAwaiter().GetResult() } catch {} }
        if ([string]::IsNullOrEmpty($stderr) -and $null -ne $stderrTask) { try { $stderr = [string]$stderrTask.GetAwaiter().GetResult() } catch {} }
    }
    $message = [string]$_.Exception.Message
    $code = if ($timedOut) {
        'CHILD_TIMEOUT'
    } elseif ($outputExceeded) {
        'CHILD_OUTPUT_OVERSIZE'
    } elseif ($message -like 'D2 child JSON parse failed:*') {
        'CHILD_JSON_MALFORMED'
    } elseif ($childStarted -and $null -ne $process -and $process.HasExited -and [int]$process.ExitCode -ne 0) {
        'CHILD_NONZERO'
    } elseif ($childStarted -and -not [string]::IsNullOrEmpty($stderr)) {
        'CHILD_STDERR'
    } elseif ($childStarted) {
        'CLASSIFICATION_INVALID'
    } else {
        'PRECHILD_PIN_OR_CONTRACT_FAILURE'
    }
    $maximumFailureJson = 7340032
    if ($null -ne $contract) { try { $maximumFailureJson = [int64]$contract.response.maximumEmittedJsonBytes } catch {} }
    $failure = New-FailureEnvelope $code $message $contract
    Write-TerminalJson $failure $maximumFailureJson 23
}

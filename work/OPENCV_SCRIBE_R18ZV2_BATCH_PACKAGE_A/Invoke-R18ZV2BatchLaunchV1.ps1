#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Rehearsal,
    [switch]$PackageValidationOnly,
    [switch]$JunctionGate,
    [string]$PayloadRoot = '',
    [string]$WorkRoot = 'D:\A2\w\ocv\R18ZV2',
    [string]$OutputRoot = 'D:\A2\o\ocv\R18ZV2',
    [string]$CanonicalProposalRoot = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\identity\proposals',
    [string]$PythonPath = 'D:\AFCV1\rt\python.exe',
    [string]$ExpectedPythonSha256 = '7D96A4ED35D6E596CD9DD8933FEAFC66349CC21F75BE3B15C89FD336E50140C1',
    [string]$ReferenceBundlePath = 'D:\O2D5\ARGOS_O2D5\O2D5_REFS.zip',
    [string]$ExpectedComputerName = 'A1025645101'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$packageRevision = 'R18ZV2_EXISTING_ORIENTED_CROPS_BATCH_CACHE_SEAM_CORRECTION_20260911A'
$runnerRevision = 'R18ZT_EXISTING_ORIENTED_CROPS_PUBLIC_PROVIDER_BATCH_20260908D'
$envelopeRevision = 'R18ZU_EXISTING_ORIENTED_CROPS_ASYNC_REVIEW_ONLY_20260908A'
$payloadManifestSha = '9B08BD74B8DBDB81600BA44AAF0063BA67195C1D6BCF1908225F4C6866F2B1E3'
$configurationSha = 'D68EFB2E0AD585970950B428B776BC4674E1F2DBDCE72CB4EA9232032F29B8AE'
$envelopeSha = '96E8BB3DC4CE86B2BA5D9FF894C001DF1632F79440DBB922991F19A64B8C1E62'
$delegateSha = 'F3B465F433ADB58F1C37C5673999FD03A4315EFA5A3128EFF8E192E9C3D58AE2'
$providerSha = '4914B20364AC62F9E3152C4C40E2B06CC96A80CA1299E6E56CBF3287B07A34C7'
$providerRevision = 'ARGOS_OPENCV_SCRIBE_V1R18ZV1_GENERIC_ENVELOPE_BOUNDARY_DIAGNOSTIC_20260910'
$r11AnalyzerSha = '7C6632B2D1C56DA4CA565DAB5BF7D46A366BCAE6663793CE5AB1ABB4739F72C9'
$referenceBundleSha = '56DF00E37A195E7BC3E026E4950DFB5A0AA7E7AF49A6FF39020B071840CCFBD6'
$installationSha = '1289EC11F092233D3AAB5ACF416B0212F1874F698F9BBC2B474829939BCDF596'
$baseManifestSha = 'AECAF49BD0ACFC07C4B2973AF1889ABD9F3708C1411820A667FD6330B90F1229'
$supplementalManifestSha = 'C7BD53925A522C21B8BAAE3E7A9B8B3817234A0665239FC1629CA3B09C9741DD'
$crosswalkSha = '84637040AF7920706616C6769D9AFEEC969895FBCE5070C52AA2ADAD1FF1ABA2'
$looGateSha = 'D8F0C0923BFDD6B82C4B0B0C57142825C08C0DB3F5395210A5DD7FE2E6E8DAD8'
$installedLauncher = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV02_R18ZV2.ps1'
$configuredWorkRoot = 'D:\A2\w\ocv\R18ZV2'
$configuredOutputRoot = 'D:\A2\o\ocv\R18ZV2'
$configuredCanonicalProposalRoot = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\identity\proposals'
$configuredProposalAlias = 'D:\A2\w\ocv\R18ZV2\p'
$configuredProviderPath = 'D:\A2\w\ocv\R18ZV2\OPENCV_SCRIBE_R18ZV1\ArgosOpenCvScribeV1R18ZV1BatchAdapter.py'
$configuredR11AnalyzerPath = 'D:\A2\w\ocv\R18ZV2\OPENCV_SCRIBE_R11A\ArgosOpenCvScribeV1R11.py'
$launcherScriptPath = [IO.Path]::GetFullPath($MyInvocation.MyCommand.Path)

function Require([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Require-FinalSha([string]$Value, [string]$Label) {
    Require ($Value -cmatch '^[A-F0-9]{64}$') "R18ZT final hash is absent: $Label"
}

function Get-Sha256([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    $hasher = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($hasher.ComputeHash($stream))).Replace('-', '') }
    finally { $hasher.Dispose(); $stream.Dispose() }
}

function Get-StreamSha256([IO.Stream]$Stream) {
    $hasher = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($hasher.ComputeHash($Stream))).Replace('-', '') }
    finally { $hasher.Dispose() }
}

function Get-TextSha256([string]$Text) {
    $hasher = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes($Text)
        return ([BitConverter]::ToString($hasher.ComputeHash($bytes))).Replace('-', '')
    }
    finally { $hasher.Dispose() }
}

function Get-PathBudgetMeasure([string]$Path, [int]$Reserve = 32) {
    $full = [IO.Path]::GetFullPath($Path)
    $parts = @($full.Split([char[]]@('\', '/'), [StringSplitOptions]::RemoveEmptyEntries))
    $longest = 0
    if ($parts.Count -gt 0) {
        $longest = [int](($parts | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum)
    }
    return [pscustomobject]@{
        path = $full
        pathLength = [int]$full.Length
        reservedSuffixCharacters = $Reserve
        effectiveLength = [int]($full.Length + $Reserve)
        longestComponentLength = $longest
    }
}

function Assert-PathBudget([string]$Path, [int]$Reserve = 32) {
    $measure = Get-PathBudgetMeasure $Path $Reserve
    Require ([int]$measure.effectiveLength -lt 200) "R18ZT unsafe effective path: $($measure.path)"
    Require ([int]$measure.longestComponentLength -le 80) "R18ZT unsafe path component: $($measure.path)"
}

function Get-ActualProposalPathBudget([string]$CanonicalRoot, [string]$AliasRoot) {
    Require (Test-Path -LiteralPath $CanonicalRoot -PathType Container) "R18ZT canonical proposal root absent: $CanonicalRoot"
    $canonicalItem = Get-Item -LiteralPath $CanonicalRoot -Force
    Require (-not $canonicalItem.Attributes.HasFlag([IO.FileAttributes]::ReparsePoint)) 'R18ZT canonical proposal root may not be a reparse point.'
    $entries = @(Get-ChildItem -LiteralPath $CanonicalRoot -Force -ErrorAction Stop)
    Require ($entries.Count -le 10000) 'R18ZT direct proposal-root child bound exceeded before launch.'
    $directories = @($entries | Where-Object { $_.PSIsContainer })
    $relativeLeaves = @(
        'SCRIBE_PROPOSAL.json',
        'scribe\multi_channel\MULTI_CHANNEL_READER_SUMMARY.json',
        'scribe\BF_SCRIBE_ORIENTED_DETECTOR_INPUT.png',
        'scribe\DF_SCRIBE_ORIENTED_DETECTOR_INPUT.png'
    )
    $leafPaths = New-Object Collections.Generic.List[string]
    $maximumEffectiveLength = 0
    $maximumComponentLength = 0
    foreach ($directory in $directories) {
        $identity = [string]$directory.Name
        Require ($identity.Length -ge 1 -and $identity.Length -le 80) "R18ZT proposal identity exceeds the frozen 80-character bound: $identity"
        foreach ($relativeLeaf in $relativeLeaves) {
            $leaf = Join-Path (Join-Path $AliasRoot $identity) $relativeLeaf
            $measure = Get-PathBudgetMeasure $leaf 32
            Require ([int]$measure.effectiveLength -lt 200) "R18ZT actual proposal alias leaf is unsafe: $leaf"
            Require ([int]$measure.longestComponentLength -le 80) "R18ZT actual proposal alias component is unsafe: $leaf"
            $maximumEffectiveLength = [Math]::Max($maximumEffectiveLength, [int]$measure.effectiveLength)
            $maximumComponentLength = [Math]::Max($maximumComponentLength, [int]$measure.longestComponentLength)
            $leafPaths.Add([IO.Path]::GetFullPath($leaf))
        }
    }
    $sortedLeaves = @($leafPaths.ToArray() | Sort-Object)
    return [pscustomobject]@{
        directChildCount = $entries.Count
        directoryChildCount = $directories.Count
        actualFourSourceLeafCount = $sortedLeaves.Count
        actualFourSourceLeafSetSha256 = Get-TextSha256 (($sortedLeaves -join "`n") + "`n")
        maximumEffectiveLength = $maximumEffectiveLength
        maximumComponentLength = $maximumComponentLength
        identityCharacterLimit = 80
        suffixReserveCharacters = 32
        sourceImageBytesRead = $false
    }
}

function Assert-ProposalJunctionTarget([string]$Alias, [string]$CanonicalRoot) {
    Require (Test-Path -LiteralPath $Alias -PathType Container) "R18ZT proposal alias absent: $Alias"
    $item = Get-Item -LiteralPath $Alias -Force
    Require ($item.Attributes.HasFlag([IO.FileAttributes]::ReparsePoint) -and [string]$item.LinkType -eq 'Junction') "R18ZT proposal alias is not a directory junction: $Alias"
    $targets = @($item.Target)
    Require ($targets.Count -eq 1) "R18ZT proposal junction target count changed: $Alias"
    $target = [IO.Path]::GetFullPath([string]$targets[0]).TrimEnd('\')
    $expected = [IO.Path]::GetFullPath($CanonicalRoot).TrimEnd('\')
    Require ($target.Equals($expected, [StringComparison]::OrdinalIgnoreCase)) "R18ZT proposal junction target changed: $target"
}

function New-VerifiedProposalJunction([string]$Alias, [string]$CanonicalRoot) {
    Require (-not (Test-Path -LiteralPath $Alias)) "R18ZT proposal alias already exists: $Alias"
    [void](New-Item -ItemType Junction -Path $Alias -Target $CanonicalRoot -ErrorAction Stop)
    Assert-ProposalJunctionTarget $Alias $CanonicalRoot
}

function Remove-OwnedProposalJunction([string]$Alias, [string]$CanonicalRoot) {
    Assert-ProposalJunctionTarget $Alias $CanonicalRoot
    [IO.Directory]::Delete([IO.Path]::GetFullPath($Alias), $false)
    Require (-not (Test-Path -LiteralPath $Alias)) "R18ZT owned proposal junction rollback failed: $Alias"
}

function Get-SafeRelativePath([string]$Value, [string]$Label) {
    Require (-not [string]::IsNullOrWhiteSpace($Value)) "$Label is empty."
    $relative = $Value.Replace('/', '\')
    Require (-not [IO.Path]::IsPathRooted($relative)) "$Label is rooted: $Value"
    $parts = @($relative.Split([char[]]@('\'), [StringSplitOptions]::None))
    Require ($parts.Count -gt 0) "$Label is empty."
    foreach ($part in $parts) {
        Require (-not [string]::IsNullOrWhiteSpace($part) -and $part -ne '.' -and $part -ne '..') "$Label contains an unsafe component: $Value"
        Require ($part.Length -le 80) "$Label contains an overlong component: $Value"
    }
    return $relative
}

function Assert-ContainedPath([string]$Root, [string]$Candidate, [string]$Label) {
    $rootFull = [IO.Path]::GetFullPath($Root).TrimEnd('\')
    $candidateFull = [IO.Path]::GetFullPath($Candidate)
    Require ($candidateFull.StartsWith($rootFull + '\', [StringComparison]::OrdinalIgnoreCase)) "$Label escaped its root: $candidateFull"
}

function Assert-ReviewOnlyAuthority([object]$Authority, [string]$Label) {
    Require ($null -ne $Authority -and [bool]$Authority.reviewOnly) "$Label is not review-only."
    foreach ($field in @(
        'identityAcceptanceAuthorized',
        'automaticReferenceAdmissionAuthorized',
        'holdClearanceAuthorized',
        'trainingAuthorized',
        'activationAuthorized',
        'xmlAuthorized',
        'productionAuthorized',
        'sourceMutationAuthorized',
        'sourceDeletionAuthorized'
    )) {
        $property = $Authority.PSObject.Properties[$field]
        Require ($null -ne $property -and $property.Value -is [bool] -and -not [bool]$property.Value) "$Label authority changed: $field"
    }
}

function Assert-RunnerAuthority([object]$Authority) {
    Require ($null -ne $Authority -and [bool]$Authority.reviewOnly) 'R18ZT runner configuration is not review-only.'
    foreach ($field in @(
        'automaticIdentityAuthority',
        'automaticReferenceAdmissionAuthorized',
        'trainingEligible',
        'activationAuthorized',
        'xmlEligible',
        'productionEligible',
        'mayClearHolds',
        'sourceMutationAllowed',
        'automaticRetryAllowed'
    )) {
        $property = $Authority.PSObject.Properties[$field]
        Require ($null -ne $property -and $property.Value -is [bool] -and -not [bool]$property.Value) "R18ZT runner authority changed: $field"
    }
}

function Assert-ExactFieldSet([object]$Value, [string[]]$Expected, [string]$Label) {
    Require ($null -ne $Value) "$Label is absent."
    $actual = @($Value.PSObject.Properties.Name | Sort-Object)
    $expectedSorted = @($Expected | Sort-Object)
    Require ($actual.Count -eq $expectedSorted.Count -and ($actual -join "`n") -ceq ($expectedSorted -join "`n")) "$Label field set changed."
}

function Assert-NoRuntimeEnvironmentOverrides {
    $forbidden = @([Environment]::GetEnvironmentVariables().Keys |
        ForEach-Object { [string]$_ } |
        Where-Object { $_ -match '^(PYTHONPATH|PYTHONHOME|PYTHONSTARTUP|PYTHONINSPECT)$' } |
        Sort-Object -Unique)
    Require ($forbidden.Count -eq 0) ('R18ZT forbidden Python runtime environment variable(s): ' + ($forbidden -join ', '))
}

function Quote-ProcessArgument([string]$Value) {
    Require ($Value.IndexOf('"') -lt 0) 'R18ZT process argument contains a quote.'
    return '"' + $Value + '"'
}

function Write-JsonNew([string]$Path, [object]$Value, [int]$Depth = 20) {
    Require (-not (Test-Path -LiteralPath $Path)) "R18ZT create-new JSON exists: $Path"
    $json = ($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine
    [IO.File]::WriteAllText($Path, $json, (New-Object Text.UTF8Encoding($false)))
}

function Assert-R18ZTFreshLaunchRoots([string[]]$Paths) {
    foreach ($path in $Paths) {
        Require (-not (Test-Path -LiteralPath $path)) "R18ZT fresh target exists: $path"
    }
}

function Get-R18ZTExactCompleteValidation([string]$OutputRoot, [string]$ConfigurationPath) {
    $completePath = Join-Path $OutputRoot 'COMPLETE.json'
    if (-not (Test-Path -LiteralPath $completePath -PathType Leaf)) {
        return [pscustomobject]@{present=$false;exact=$false;detail='COMPLETE_ABSENT'}
    }
    try {
        $complete = Get-Content -LiteralPath $completePath -Raw | ConvertFrom-Json
        $configuration = Get-Content -LiteralPath $ConfigurationPath -Raw | ConvertFrom-Json
        $expectedScalars = [ordered]@{
            schema = 'argos_opencv_scribe_r18zt_batch_complete_v2'
            state = 'COMPLETE_R18ZT_EXISTING_ORIENTED_CROPS_REVIEW_ONLY'
            revision = 'R18ZT_EXISTING_ORIENTED_CROPS_PUBLIC_PROVIDER_BATCH_20260908D'
            batchId = [string]$configuration.batchId
            proposalRoot = [IO.Path]::GetFullPath([string]$configuration.proposalRoot)
            canonicalProposalRoot = [IO.Path]::GetFullPath([string]$configuration.canonicalProposalRoot)
            proposalAliasResolvedTarget = [IO.Path]::GetFullPath([string]$configuration.canonicalProposalRoot)
            exactProgressPointer = [IO.Path]::GetFullPath((Join-Path $OutputRoot 'RUNNING.json'))
        }
        foreach ($field in $expectedScalars.Keys) {
            $actual = [string]$complete.$field
            $expected = [string]$expectedScalars[$field]
            if ($field -in @('proposalRoot','canonicalProposalRoot','proposalAliasResolvedTarget','exactProgressPointer')) {
                if (-not [IO.Path]::GetFullPath($actual).Equals($expected, [StringComparison]::OrdinalIgnoreCase)) { return [pscustomobject]@{present=$true;exact=$false;detail="COMPLETE_FIELD_MISMATCH:$field"} }
            }
            elseif ($actual -cne $expected) { return [pscustomobject]@{present=$true;exact=$false;detail="COMPLETE_FIELD_MISMATCH:$field"} }
        }
        foreach ($pair in @(
            [pscustomobject]@{field='recursiveResultScanRequired';value=$false},
            [pscustomobject]@{field='truthOrChecksumUsedByRunnerForSelection';value=$false},
            [pscustomobject]@{field='sourceMutationPerformed';value=$false},
            [pscustomobject]@{field='automaticRetryPerformed';value=$false},
            [pscustomobject]@{field='reviewOnly';value=$true}
        )) {
            $property = $complete.PSObject.Properties[[string]$pair.field]
            if ($null -eq $property -or $property.Value -isnot [bool] -or [bool]$property.Value -ne [bool]$pair.value) { return [pscustomobject]@{present=$true;exact=$false;detail="COMPLETE_BOOLEAN_MISMATCH:$($pair.field)"} }
        }
        $countFields = @('qualifiedCaseCount','inventoryHoldCount','completedCount','providerInvocationAttemptCount','providerRunJobEnteredCount','providerRunJobReturnedCount','providerRunCount','comparableResultCount','noncomparableOrFailedCount','identityAcceptedCount')
        $counts = @{}
        foreach ($field in $countFields) {
            $property = $complete.PSObject.Properties[$field]
            if ($null -eq $property -or ($property.Value -isnot [int] -and $property.Value -isnot [long]) -or [int64]$property.Value -lt 0) { return [pscustomobject]@{present=$true;exact=$false;detail="COMPLETE_COUNT_INVALID:$field"} }
            $counts[$field] = [int64]$property.Value
        }
        if ($counts.qualifiedCaseCount -lt 1 -or $counts.completedCount -ne $counts.qualifiedCaseCount -or $counts.providerInvocationAttemptCount -ne $counts.qualifiedCaseCount -or $counts.providerRunJobEnteredCount -gt $counts.providerInvocationAttemptCount -or $counts.providerRunJobReturnedCount -gt $counts.providerRunJobEnteredCount -or $counts.providerRunCount -ne $counts.providerRunJobEnteredCount -or ($counts.comparableResultCount + $counts.noncomparableOrFailedCount) -ne $counts.qualifiedCaseCount -or $counts.identityAcceptedCount -ne 0) {
            return [pscustomobject]@{present=$true;exact=$false;detail='COMPLETE_COUNT_RELATION_INVALID'}
        }
        $expectedDisposition = if ($counts.comparableResultCount -eq $counts.qualifiedCaseCount -and $counts.noncomparableOrFailedCount -eq 0) {
            'COMPLETE_ALL_QUALIFIED_CASES_COMPARABLE'
        }
        else {
            'COMPLETE_WITH_NONCOMPARABLE_OR_FAILED_CASE_HOLDS'
        }
        if ([string]$complete.disposition -cne $expectedDisposition) { return [pscustomobject]@{present=$true;exact=$false;detail='COMPLETE_DISPOSITION_INVALID'} }
        $pinnedValues = @{}
        foreach ($pin in @(
            [pscustomobject]@{field='aggregate';leaf='AGGREGATE.json'},
            [pscustomobject]@{field='inventory';leaf='INVENTORY.json'},
            [pscustomobject]@{field='caseIndex';leaf='CASE_INDEX.json'}
        )) {
            $value = $complete.([string]$pin.field)
            $expectedPath = [IO.Path]::GetFullPath((Join-Path $OutputRoot ([string]$pin.leaf)))
            if ($null -eq $value -or @($value.PSObject.Properties.Name).Count -ne 2 -or @($value.PSObject.Properties.Name) -notcontains 'path' -or @($value.PSObject.Properties.Name) -notcontains 'sha256') { return [pscustomobject]@{present=$true;exact=$false;detail="COMPLETE_PIN_SHAPE_INVALID:$($pin.field)"} }
            if (-not [IO.Path]::GetFullPath([string]$value.path).Equals($expectedPath, [StringComparison]::OrdinalIgnoreCase) -or [string]$value.sha256 -cnotmatch '^[A-F0-9]{64}$' -or -not (Test-Path -LiteralPath $expectedPath -PathType Leaf) -or (Get-Sha256 $expectedPath) -ne [string]$value.sha256) { return [pscustomobject]@{present=$true;exact=$false;detail="COMPLETE_PIN_INVALID:$($pin.field)"} }
            $pinnedValues[[string]$pin.field] = Get-Content -LiteralPath $expectedPath -Raw | ConvertFrom-Json
        }

        $inventory = $pinnedValues.inventory
        foreach ($pair in @(
            [pscustomobject]@{field='schema';value='argos_opencv_scribe_r18zt_batch_inventory_v2'},
            [pscustomobject]@{field='state';value='PASS_R18ZT_BOUNDED_DIRECT_CHILD_INVENTORY'},
            [pscustomobject]@{field='revision';value='R18ZT_EXISTING_ORIENTED_CROPS_PUBLIC_PROVIDER_BATCH_20260908D'}
        )) {
            if ([string]$inventory.([string]$pair.field) -cne [string]$pair.value) { return [pscustomobject]@{present=$true;exact=$false;detail="INVENTORY_FIELD_MISMATCH:$($pair.field)"} }
        }
        foreach ($pair in @(
            [pscustomobject]@{field='proposalRoot';value=[string]$configuration.proposalRoot},
            [pscustomobject]@{field='canonicalProposalRoot';value=[string]$configuration.canonicalProposalRoot},
            [pscustomobject]@{field='proposalAliasResolvedTarget';value=[string]$configuration.canonicalProposalRoot}
        )) {
            if (-not [IO.Path]::GetFullPath([string]$inventory.([string]$pair.field)).Equals([IO.Path]::GetFullPath([string]$pair.value), [StringComparison]::OrdinalIgnoreCase)) { return [pscustomobject]@{present=$true;exact=$false;detail="INVENTORY_PATH_MISMATCH:$($pair.field)"} }
        }
        foreach ($pair in @(
            [pscustomobject]@{field='recursiveEnumerationPerformed';value=$false},
            [pscustomobject]@{field='wholeWaferImagesRead';value=$false},
            [pscustomobject]@{field='sourcePixelsDecodedByInventory';value=$false},
            [pscustomobject]@{field='sourceMutationPerformed';value=$false},
            [pscustomobject]@{field='identityAccepted';value=$false},
            [pscustomobject]@{field='reviewOnly';value=$true},
            [pscustomobject]@{field='proposalRootIsRequiredAlias';value=$true}
        )) {
            $property = $inventory.PSObject.Properties[[string]$pair.field]
            if ($null -eq $property -or $property.Value -isnot [bool] -or [bool]$property.Value -ne [bool]$pair.value) { return [pscustomobject]@{present=$true;exact=$false;detail="INVENTORY_BOOLEAN_MISMATCH:$($pair.field)"} }
        }
        $inventoryCounts = @{}
        foreach ($field in @('qualifiedCaseCount','inventoryHoldCount','directChildCount','ignoredNonDirectoryCount')) {
            $property = $inventory.PSObject.Properties[$field]
            if ($null -eq $property -or ($property.Value -isnot [int] -and $property.Value -isnot [long]) -or [int64]$property.Value -lt 0) { return [pscustomobject]@{present=$true;exact=$false;detail="INVENTORY_COUNT_INVALID:$field"} }
            $inventoryCounts[$field] = [int64]$property.Value
        }
        $inventoryQualified = [int64]$inventoryCounts.qualifiedCaseCount
        $inventoryHolds = [int64]$inventoryCounts.inventoryHoldCount
        $directChildren = [int64]$inventoryCounts.directChildCount
        $ignoredNonDirectories = [int64]$inventoryCounts.ignoredNonDirectoryCount
        if ($inventoryQualified -ne $counts.qualifiedCaseCount -or $inventoryHolds -ne $counts.inventoryHoldCount -or @($inventory.cases).Count -ne $inventoryQualified -or @($inventory.holds).Count -ne $inventoryHolds -or $directChildren -ne ($inventoryQualified + $inventoryHolds + $ignoredNonDirectories)) { return [pscustomobject]@{present=$true;exact=$false;detail='INVENTORY_COUNT_RELATION_INVALID'} }
        $inventoryCaseIds = @($inventory.cases | ForEach-Object { [string]$_.caseId })
        if (@($inventoryCaseIds | Where-Object { [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 1).Count -ne 0 -or @($inventoryCaseIds | Sort-Object -Unique).Count -ne $inventoryCaseIds.Count) { return [pscustomobject]@{present=$true;exact=$false;detail='INVENTORY_CASE_ID_SET_INVALID'} }

        $caseIndex = $pinnedValues.caseIndex
        foreach ($pair in @(
            [pscustomobject]@{field='schema';value='argos_opencv_scribe_r18zt_batch_case_index_v2'},
            [pscustomobject]@{field='state';value='PASS_R18ZT_CASE_INDEX_COMPLETE'},
            [pscustomobject]@{field='revision';value='R18ZT_EXISTING_ORIENTED_CROPS_PUBLIC_PROVIDER_BATCH_20260908D'},
            [pscustomobject]@{field='batchId';value=[string]$configuration.batchId}
        )) {
            if ([string]$caseIndex.([string]$pair.field) -cne [string]$pair.value) { return [pscustomobject]@{present=$true;exact=$false;detail="CASE_INDEX_FIELD_MISMATCH:$($pair.field)"} }
        }
        foreach ($pair in @(
            [pscustomobject]@{field='identityAcceptedCount';value=0},
            [pscustomobject]@{field='sourceMutationPerformed';value=$false},
            [pscustomobject]@{field='automaticRetryPerformed';value=$false},
            [pscustomobject]@{field='reviewOnly';value=$true}
        )) {
            $property = $caseIndex.PSObject.Properties[[string]$pair.field]
            if ($null -eq $property -or [string]$property.Value -cne [string]$pair.value) { return [pscustomobject]@{present=$true;exact=$false;detail="CASE_INDEX_FIELD_MISMATCH:$($pair.field)"} }
        }
        $indexRows = @($caseIndex.rows)
        if ([int64]$caseIndex.caseCount -ne $counts.qualifiedCaseCount -or $indexRows.Count -ne $counts.qualifiedCaseCount) { return [pscustomobject]@{present=$true;exact=$false;detail='CASE_INDEX_COUNT_RELATION_INVALID'} }
        $indexInvocationAttempts = [int64]0
        $indexRunJobEntered = [int64]0
        $indexRunJobReturned = [int64]0
        $indexRunCount = [int64]0
        $indexComparableCount = [int64]0
        $indexCaseIds = New-Object Collections.Generic.List[string]
        foreach ($row in $indexRows) {
            $caseId = [string]$row.caseId
            if ([string]::IsNullOrWhiteSpace($caseId)) { return [pscustomobject]@{present=$true;exact=$false;detail='CASE_INDEX_CASE_ID_INVALID'} }
            $indexCaseIds.Add($caseId)
            $comparableProperty = $row.PSObject.Properties['providerResultComparable']
            if ($null -eq $comparableProperty -or $comparableProperty.Value -isnot [bool]) { return [pscustomobject]@{present=$true;exact=$false;detail='CASE_INDEX_COMPARABLE_FLAG_INVALID'} }
            if ([bool]$comparableProperty.Value) { $indexComparableCount++ }
            foreach ($field in @('providerInvocationAttemptCount','providerRunJobEnteredCount','providerRunJobReturnedCount','providerRunCount')) {
                $property = $row.PSObject.Properties[$field]
                if ($null -eq $property -or ($property.Value -isnot [int] -and $property.Value -isnot [long]) -or [int64]$property.Value -lt 0) { return [pscustomobject]@{present=$true;exact=$false;detail="CASE_INDEX_ROW_COUNT_INVALID:$field"} }
            }
            $retryProperty = $row.PSObject.Properties['automaticRetryPerformed']
            if ($null -eq $retryProperty -or $retryProperty.Value -isnot [bool] -or [bool]$retryProperty.Value) { return [pscustomobject]@{present=$true;exact=$false;detail='CASE_INDEX_ROW_RETRY_INVALID'} }
            if ([int64]$row.providerInvocationAttemptCount -ne 1 -or [int64]$row.providerRunJobEnteredCount -gt 1 -or [int64]$row.providerRunJobReturnedCount -gt [int64]$row.providerRunJobEnteredCount -or [int64]$row.providerRunCount -ne [int64]$row.providerRunJobEnteredCount) { return [pscustomobject]@{present=$true;exact=$false;detail='CASE_INDEX_ROW_INVOCATION_RELATION_INVALID'} }
            $indexInvocationAttempts += [int64]$row.providerInvocationAttemptCount
            $indexRunJobEntered += [int64]$row.providerRunJobEnteredCount
            $indexRunJobReturned += [int64]$row.providerRunJobReturnedCount
            $indexRunCount += [int64]$row.providerRunCount
        }
        if ($indexInvocationAttempts -ne $counts.providerInvocationAttemptCount -or $indexRunJobEntered -ne $counts.providerRunJobEnteredCount -or $indexRunJobReturned -ne $counts.providerRunJobReturnedCount -or $indexRunCount -ne $counts.providerRunCount -or $indexComparableCount -ne $counts.comparableResultCount) { return [pscustomobject]@{present=$true;exact=$false;detail='CASE_INDEX_ROW_SUM_INVALID'} }
        $sortedInventoryCaseIds = @($inventoryCaseIds | Sort-Object)
        $sortedIndexCaseIds = @($indexCaseIds.ToArray() | Sort-Object)
        if ($sortedIndexCaseIds.Count -ne @($sortedIndexCaseIds | Sort-Object -Unique).Count -or ($sortedInventoryCaseIds -join "`n") -cne ($sortedIndexCaseIds -join "`n")) { return [pscustomobject]@{present=$true;exact=$false;detail='CASE_INDEX_INVENTORY_CASE_ID_SET_MISMATCH'} }

        $aggregate = $pinnedValues.aggregate
        foreach ($pair in @(
            [pscustomobject]@{field='schema';value='argos_opencv_scribe_r18zt_batch_aggregate_v2'},
            [pscustomobject]@{field='state';value='PASS_R18ZT_EXISTING_ORIENTED_CROPS_REVIEW_ONLY_AGGREGATE'},
            [pscustomobject]@{field='disposition';value=$expectedDisposition},
            [pscustomobject]@{field='revision';value='R18ZT_EXISTING_ORIENTED_CROPS_PUBLIC_PROVIDER_BATCH_20260908D'},
            [pscustomobject]@{field='batchId';value=[string]$configuration.batchId}
        )) {
            if ([string]$aggregate.([string]$pair.field) -cne [string]$pair.value) { return [pscustomobject]@{present=$true;exact=$false;detail="AGGREGATE_FIELD_MISMATCH:$($pair.field)"} }
        }
        foreach ($pair in @(
            [pscustomobject]@{field='proposalRoot';value=[string]$configuration.proposalRoot},
            [pscustomobject]@{field='canonicalProposalRoot';value=[string]$configuration.canonicalProposalRoot},
            [pscustomobject]@{field='proposalAliasResolvedTarget';value=[string]$configuration.canonicalProposalRoot},
            [pscustomobject]@{field='outputRoot';value=$OutputRoot},
            [pscustomobject]@{field='exactProgressPointer';value=(Join-Path $OutputRoot 'RUNNING.json')}
        )) {
            if (-not [IO.Path]::GetFullPath([string]$aggregate.([string]$pair.field)).Equals([IO.Path]::GetFullPath([string]$pair.value), [StringComparison]::OrdinalIgnoreCase)) { return [pscustomobject]@{present=$true;exact=$false;detail="AGGREGATE_PATH_MISMATCH:$($pair.field)"} }
        }
        foreach ($field in $countFields) {
            $property = $aggregate.PSObject.Properties[$field]
            if ($null -eq $property -or ($property.Value -isnot [int] -and $property.Value -isnot [long]) -or [int64]$property.Value -ne [int64]$counts[$field]) { return [pscustomobject]@{present=$true;exact=$false;detail="AGGREGATE_COUNT_MISMATCH:$field"} }
        }
        $aggregateDirectChildren = $aggregate.PSObject.Properties['directChildCount']
        if ($null -eq $aggregateDirectChildren -or ($aggregateDirectChildren.Value -isnot [int] -and $aggregateDirectChildren.Value -isnot [long]) -or [int64]$aggregateDirectChildren.Value -ne $directChildren) { return [pscustomobject]@{present=$true;exact=$false;detail='AGGREGATE_DIRECT_CHILD_COUNT_MISMATCH'} }
        foreach ($pair in @(
            [pscustomobject]@{field='recursiveResultScanRequired';value=$false},
            [pscustomobject]@{field='wholeWaferImagesRead';value=$false},
            [pscustomobject]@{field='truthOrChecksumUsedByRunnerForSelection';value=$false},
            [pscustomobject]@{field='sourceMutationPerformed';value=$false},
            [pscustomobject]@{field='automaticRetryPerformed';value=$false},
            [pscustomobject]@{field='reviewOnly';value=$true}
        )) {
            $property = $aggregate.PSObject.Properties[[string]$pair.field]
            if ($null -eq $property -or $property.Value -isnot [bool] -or [bool]$property.Value -ne [bool]$pair.value) { return [pscustomobject]@{present=$true;exact=$false;detail="AGGREGATE_BOOLEAN_MISMATCH:$($pair.field)"} }
        }
        foreach ($pin in @(
            [pscustomobject]@{field='inventory';completeField='inventory'},
            [pscustomobject]@{field='caseIndex';completeField='caseIndex'}
        )) {
            $aggregatePin = $aggregate.([string]$pin.field)
            $completePin = $complete.([string]$pin.completeField)
            if ([string]$aggregatePin.path -cne [string]$completePin.path -or [string]$aggregatePin.sha256 -cne [string]$completePin.sha256) { return [pscustomobject]@{present=$true;exact=$false;detail="AGGREGATE_PIN_MISMATCH:$($pin.field)"} }
        }
        return [pscustomobject]@{present=$true;exact=$true;detail='EXACT_COMPLETE'}
    }
    catch { return [pscustomobject]@{present=$true;exact=$false;detail=('COMPLETE_VALIDATION_ERROR:' + $_.Exception.Message)} }
}

function New-R18ZTExactCompleteGateFixture([string]$OutputRoot, [string]$ConfigurationPath, [string]$ProposalRoot, [string]$CanonicalProposalRoot) {
    $revision = 'R18ZT_EXISTING_ORIENTED_CROPS_PUBLIC_PROVIDER_BATCH_20260908D'
    $batchId = 'R18ZV2'
    Write-JsonNew $ConfigurationPath ([ordered]@{batchId=$batchId;proposalRoot=$ProposalRoot;canonicalProposalRoot=$CanonicalProposalRoot}) 4
    $inventoryPath = Join-Path $OutputRoot 'INVENTORY.json'
    $indexPath = Join-Path $OutputRoot 'CASE_INDEX.json'
    $aggregatePath = Join-Path $OutputRoot 'AGGREGATE.json'
    $runningPath = Join-Path $OutputRoot 'RUNNING.json'
    Write-JsonNew $inventoryPath ([ordered]@{
        schema='argos_opencv_scribe_r18zt_batch_inventory_v2';createdUtc='2026-09-06T00:00:00Z';state='PASS_R18ZT_BOUNDED_DIRECT_CHILD_INVENTORY';revision=$revision;proposalRoot=$ProposalRoot;canonicalProposalRoot=$CanonicalProposalRoot;proposalAliasResolvedTarget=$CanonicalProposalRoot;proposalRootIsRequiredAlias=$true;directChildCount=1;ignoredNonDirectoryCount=0;qualifiedCaseCount=1;inventoryHoldCount=0;cases=@([ordered]@{caseId='FIXTURE_CASE'});holds=@();recursiveEnumerationPerformed=$false;wholeWaferImagesRead=$false;sourcePixelsDecodedByInventory=$false;sourceMutationPerformed=$false;identityAccepted=$false;reviewOnly=$true
    }) 8
    Write-JsonNew $indexPath ([ordered]@{
        schema='argos_opencv_scribe_r18zt_batch_case_index_v2';createdUtc='2026-09-06T00:00:00Z';state='PASS_R18ZT_CASE_INDEX_COMPLETE';revision=$revision;batchId=$batchId;caseCount=1;rows=@([ordered]@{caseId='FIXTURE_CASE';state='PASS_R18ZT_CASE_PROVIDER_RESULT_COMPARABLE';providerState='PASS_R18ZT_PROVIDER_RESULT_COMPARABLE';providerResultComparable=$true;providerInvocationAttemptCount=1;providerRunJobEnteredCount=1;providerRunJobReturnedCount=1;providerRunCount=1;automaticRetryPerformed=$false});identityAcceptedCount=0;sourceMutationPerformed=$false;automaticRetryPerformed=$false;reviewOnly=$true
    }) 8
    $inventoryPin = [ordered]@{path=$inventoryPath;sha256=Get-Sha256 $inventoryPath}
    $indexPin = [ordered]@{path=$indexPath;sha256=Get-Sha256 $indexPath}
    Write-JsonNew $aggregatePath ([ordered]@{
        schema='argos_opencv_scribe_r18zt_batch_aggregate_v2';createdUtc='2026-09-06T00:00:00Z';state='PASS_R18ZT_EXISTING_ORIENTED_CROPS_REVIEW_ONLY_AGGREGATE';disposition='COMPLETE_ALL_QUALIFIED_CASES_COMPARABLE';revision=$revision;batchId=$batchId;proposalRoot=$ProposalRoot;canonicalProposalRoot=$CanonicalProposalRoot;proposalAliasResolvedTarget=$CanonicalProposalRoot;outputRoot=$OutputRoot;directChildCount=1;qualifiedCaseCount=1;inventoryHoldCount=0;completedCount=1;providerInvocationAttemptCount=1;providerRunJobEnteredCount=1;providerRunJobReturnedCount=1;providerRunCount=1;comparableResultCount=1;noncomparableOrFailedCount=0;inventory=$inventoryPin;caseIndex=$indexPin;exactProgressPointer=$runningPath;recursiveResultScanRequired=$false;wholeWaferImagesRead=$false;truthOrChecksumUsedByRunnerForSelection=$false;identityAcceptedCount=0;sourceMutationPerformed=$false;automaticRetryPerformed=$false;reviewOnly=$true
    }) 8
    $aggregatePin = [ordered]@{path=$aggregatePath;sha256=Get-Sha256 $aggregatePath}
    Write-JsonNew (Join-Path $OutputRoot 'COMPLETE.json') ([ordered]@{
        schema='argos_opencv_scribe_r18zt_batch_complete_v2';createdUtc='2026-09-06T00:00:00Z';state='COMPLETE_R18ZT_EXISTING_ORIENTED_CROPS_REVIEW_ONLY';disposition='COMPLETE_ALL_QUALIFIED_CASES_COMPARABLE';revision=$revision;batchId=$batchId;proposalRoot=$ProposalRoot;canonicalProposalRoot=$CanonicalProposalRoot;proposalAliasResolvedTarget=$CanonicalProposalRoot;qualifiedCaseCount=1;inventoryHoldCount=0;completedCount=1;providerInvocationAttemptCount=1;providerRunJobEnteredCount=1;providerRunJobReturnedCount=1;providerRunCount=1;comparableResultCount=1;noncomparableOrFailedCount=0;aggregate=$aggregatePin;inventory=$inventoryPin;caseIndex=$indexPin;exactProgressPointer=$runningPath;recursiveResultScanRequired=$false;truthOrChecksumUsedByRunnerForSelection=$false;identityAcceptedCount=0;sourceMutationPerformed=$false;automaticRetryPerformed=$false;reviewOnly=$true
    }) 8
}

function Resolve-R18ZTLaunchFailure {
    param(
        [object]$OwnedProcess,
        [bool]$OwnedProcessStarted,
        [string]$Detail,
        [string]$WorkRoot,
        [string]$PartialRoot,
        [string]$FailedRoot,
        [string]$OutputRoot,
        [string]$FailurePath,
        [string]$ProposalAlias,
        [string]$CanonicalProposalRoot,
        [bool]$ProposalAliasCreated,
        [string]$ConfigurationPath
    )
    $workerExitConfirmed = -not $OwnedProcessStarted
    $workerTerminatedByLauncher = $false
    if ($null -ne $OwnedProcess) {
        try {
            $OwnedProcess.Refresh()
            if (-not $OwnedProcess.HasExited) {
                $OwnedProcess.Kill()
                $workerTerminatedByLauncher = $true
            }
            Require ($OwnedProcess.WaitForExit(10000)) 'R18ZT owned worker did not terminate within the bounded rollback wait.'
            $OwnedProcess.Refresh()
            Require ($OwnedProcess.HasExited) 'R18ZT owned worker exit could not be confirmed before rollback.'
            $workerExitConfirmed = $true
        }
        catch { $Detail = $Detail + '; OWNED_WORKER_EXIT_NOT_CONFIRMED: ' + $_.Exception.Message }
        finally { $OwnedProcess.Dispose() }
    }

    $completePath = Join-Path $OutputRoot 'COMPLETE.json'
    $completeValidation = Get-R18ZTExactCompleteValidation $OutputRoot $ConfigurationPath
    $completePresent = [bool]$completeValidation.present
    $completeExact = [bool]$completeValidation.exact

    $reportingErrorWritten = $false
    $proposalAliasRemoved = $false
    $workQuarantined = $false
    $failureWritten = $false
    $invalidCompleteQuarantined = $false
    $invalidCompleteQuarantinePath = ''
    if ($completeExact) {
        $reportingErrorPath = Join-Path $OutputRoot 'LAUNCH_REPORTING_ERROR.json'
        if (-not (Test-Path -LiteralPath $reportingErrorPath)) {
            try {
                Write-JsonNew $reportingErrorPath ([ordered]@{
                    schema = 'argos_opencv_scribe_r18zt_launch_reporting_error_v1'
                    createdUtc = [DateTime]::UtcNow.ToString('o')
                    state = 'HOLD_R18ZT_LAUNCH_REPORTING_ERROR_AFTER_EXACT_COMPLETE_PRESERVED'
                    detail = $Detail
                    completePresent = $true
                    completeExact = $true
                    failureCreated = $false
                    workAndProposalAliasPreserved = $true
                    automaticRetryAllowed = $false
                    completionClaimedByLauncher = $false
                    sourceMutationPerformed = $false
                    identityAccepted = $false
                    reviewOnly = $true
                    productionRoutingEnabled = $false
                }) 8
                $reportingErrorWritten = $true
            }
            catch {}
        }
    }
    elseif ($workerExitConfirmed) {
        if ($completePresent) {
            $invalidCompleteQuarantinePath = Join-Path $OutputRoot 'COMPLETE.invalid.json'
            Require (-not (Test-Path -LiteralPath $invalidCompleteQuarantinePath)) 'R18ZT invalid COMPLETE quarantine already exists.'
            Move-Item -LiteralPath $completePath -Destination $invalidCompleteQuarantinePath -ErrorAction Stop
            $invalidCompleteQuarantined = $true
            $completePresent = $false
        }
        if ($ProposalAliasCreated -and (Test-Path -LiteralPath $ProposalAlias)) {
            Remove-OwnedProposalJunction $ProposalAlias $CanonicalProposalRoot
            $proposalAliasRemoved = $true
        }
        if ((Test-Path -LiteralPath $PartialRoot) -and -not (Test-Path -LiteralPath $FailedRoot)) {
            Move-Item -LiteralPath $PartialRoot -Destination $FailedRoot -ErrorAction Stop
            $workQuarantined = $true
        }
        if ((Test-Path -LiteralPath $WorkRoot -PathType Container) -and -not (Test-Path -LiteralPath $FailedRoot) -and -not (Test-Path -LiteralPath $ProposalAlias)) {
            Move-Item -LiteralPath $WorkRoot -Destination $FailedRoot -ErrorAction Stop
            $workQuarantined = $true
        }
        if ((Test-Path -LiteralPath $OutputRoot -PathType Container) -and -not (Test-Path -LiteralPath $FailurePath) -and -not (Test-Path -LiteralPath $completePath)) {
            Write-JsonNew $FailurePath ([ordered]@{
                schema = 'argos_opencv_scribe_r18zt_batch_launch_failure_v2'
                createdUtc = [DateTime]::UtcNow.ToString('o')
                state = 'HOLD_R18ZT_BATCH_LAUNCH_FAILURE'
                detail = $Detail
                completeValidation = [string]$completeValidation.detail
                invalidCompleteQuarantined = $invalidCompleteQuarantined
                invalidCompleteQuarantinePath = $invalidCompleteQuarantinePath
                ownedProcessStarted = $OwnedProcessStarted
                ownedWorkerTerminatedByLauncher = $workerTerminatedByLauncher
                ownedWorkerExitConfirmedBeforeRollback = $workerExitConfirmed
                proposalAliasRemovedOnFailure = $proposalAliasRemoved
                workQuarantined = $workQuarantined
                automaticRetryAllowed = $false
                completionClaimed = $false
                publicationAuthorized = $false
                publicationPerformed = $false
                sourceMutationPerformed = $false
                identityAccepted = $false
                reviewOnly = $true
                productionRoutingEnabled = $false
            }) 8
            $failureWritten = $true
        }
    }

    return [pscustomobject]@{
        workerExitConfirmed = $workerExitConfirmed
        workerTerminatedByLauncher = $workerTerminatedByLauncher
        completeOriginallyPresent = [bool]$completeValidation.present
        completePresent = [bool](Test-Path -LiteralPath $completePath -PathType Leaf)
        completeExact = $completeExact
        completeValidation = [string]$completeValidation.detail
        invalidCompleteQuarantined = $invalidCompleteQuarantined
        invalidCompleteQuarantinePath = $invalidCompleteQuarantinePath
        reportingErrorWritten = $reportingErrorWritten
        proposalAliasRemoved = $proposalAliasRemoved
        workQuarantined = $workQuarantined
        failureWritten = $failureWritten
        resourcesPreserved = ($completeExact -or -not $workerExitConfirmed)
        terminalLeafCoexistenceCreated = $false
        detail = $Detail
    }
}

Require (-not $JunctionGate -or (-not $Preflight -and -not $Rehearsal -and -not $PackageValidationOnly)) 'R18ZT junction gate is a distinct bounded test mode.'
Require (-not $PackageValidationOnly -or ($Preflight -and $Rehearsal -and -not $JunctionGate)) 'R18ZT package-only validation requires both -Preflight and -Rehearsal.'
Require (-not $Rehearsal -or ($Preflight -and -not $JunctionGate)) 'R18ZT rehearsal is non-mutating and requires -Preflight.'
Require ($env:COMPUTERNAME.Equals($ExpectedComputerName, [StringComparison]::OrdinalIgnoreCase)) "R18ZT wrong computer: $($env:COMPUTERNAME)"
function Invoke-R18ZTProposalJunctionGate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$GatePythonPath,
        [Parameter(Mandatory = $true)][string]$GatePythonSha256,
        [Parameter(Mandatory = $true)][string]$GatePackageRevision,
        [Parameter(Mandatory = $true)][string]$GateLauncherScriptPath
    )

    $junctionGateRoot = 'C:\RZV2A1JG'
    Require (-not (Test-Path -LiteralPath $junctionGateRoot)) "R18ZT fresh junction-gate root exists: $junctionGateRoot"
    Require (Test-Path -LiteralPath $GatePythonPath -PathType Leaf) 'R18ZT junction gate Python runtime is absent.'
    Require ((Get-Sha256 $GatePythonPath) -eq $GatePythonSha256) 'R18ZT junction gate Python runtime changed.'
    [void](New-Item -ItemType Directory -Path $junctionGateRoot)
    $sleepRoot = Join-Path $junctionGateRoot 'sleep'
    $sleepCanonical = Join-Path $sleepRoot 'canonical'
    $sleepWork = Join-Path $sleepRoot 'work'
    $sleepAlias = Join-Path $sleepWork 'p'
    $sleepOutput = Join-Path $sleepRoot 'output'
    $sleepFailed = Join-Path $sleepRoot 'work.failed'
    $sleepPartial = Join-Path $sleepRoot 'work.partial'
    $sleepFailure = Join-Path $sleepOutput 'FAILURE.json'
    $sleepConfiguration = Join-Path $sleepRoot 'configuration.json'
    $sleepScript = Join-Path $sleepRoot 'owned_worker.py'
    $sleepProcess = $null
    $sleepResolution = $null
    $fastRoot = Join-Path $junctionGateRoot 'fast'
    $fastCanonical = Join-Path $fastRoot 'canonical'
    $fastWork = Join-Path $fastRoot 'work'
    $fastAlias = Join-Path $fastWork 'p'
    $fastOutput = Join-Path $fastRoot 'output'
    $fastFailed = Join-Path $fastRoot 'work.failed'
    $fastPartial = Join-Path $fastRoot 'work.partial'
    $fastFailure = Join-Path $fastOutput 'FAILURE.json'
    $fastConfiguration = Join-Path $fastRoot 'configuration.json'
    $fastScript = Join-Path $fastRoot 'owned_worker.py'
    $fastProcess = $null
    $fastResolution = $null
    $invalidRoot = Join-Path $junctionGateRoot 'invalid'
    $invalidCanonical = Join-Path $invalidRoot 'canonical'
    $invalidWork = Join-Path $invalidRoot 'work'
    $invalidAlias = Join-Path $invalidWork 'p'
    $invalidOutput = Join-Path $invalidRoot 'output'
    $invalidFailed = Join-Path $invalidRoot 'work.failed'
    $invalidPartial = Join-Path $invalidRoot 'work.partial'
    $invalidFailure = Join-Path $invalidOutput 'FAILURE.json'
    $invalidConfiguration = Join-Path $invalidRoot 'configuration.json'
    $invalidScript = Join-Path $invalidRoot 'owned_worker.py'
    $invalidProcess = $null
    $invalidResolution = $null
    $collisionRoot = Join-Path $junctionGateRoot 'collision'
    $collisionWork = Join-Path $collisionRoot 'work'
    $collisionPartial = Join-Path $collisionRoot 'work.partial'
    $collisionFailed = Join-Path $collisionRoot 'work.failed'
    $collisionOutput = Join-Path $collisionRoot 'output'
    $collisionRejected = $false
    try {
        foreach ($directory in @($sleepRoot,$sleepCanonical,$sleepWork,$sleepOutput)) { [void](New-Item -ItemType Directory -Path $directory) }
        New-VerifiedProposalJunction $sleepAlias $sleepCanonical
        [IO.File]::WriteAllText($sleepScript, "import time`ntime.sleep(60)`n", (New-Object Text.UTF8Encoding($false)))
        $sleepStartInfo = New-Object Diagnostics.ProcessStartInfo
        $sleepStartInfo.FileName = $GatePythonPath
        $sleepStartInfo.Arguments = Quote-ProcessArgument $sleepScript
        $sleepStartInfo.WorkingDirectory = $sleepRoot
        $sleepStartInfo.UseShellExecute = $false
        $sleepStartInfo.CreateNoWindow = $true
        $sleepProcess = New-Object Diagnostics.Process
        $sleepProcess.StartInfo = $sleepStartInfo
        Require ($sleepProcess.Start()) 'R18ZT rollback gate sleeping worker did not start.'
        Start-Sleep -Milliseconds 250
        $sleepProcess.Refresh()
        Require (-not $sleepProcess.HasExited) 'R18ZT rollback gate sleeping worker exited before failure injection.'
        $sleepResolution = Resolve-R18ZTLaunchFailure -OwnedProcess $sleepProcess -OwnedProcessStarted $true -Detail 'EXPECTED_R18ZT_POST_START_SLEEPING_WORKER_FAILURE' -WorkRoot $sleepWork -PartialRoot $sleepPartial -FailedRoot $sleepFailed -OutputRoot $sleepOutput -FailurePath $sleepFailure -ProposalAlias $sleepAlias -CanonicalProposalRoot $sleepCanonical -ProposalAliasCreated $true -ConfigurationPath $sleepConfiguration
        $sleepProcess = $null
        Require ([bool]$sleepResolution.workerExitConfirmed -and [bool]$sleepResolution.workerTerminatedByLauncher -and [bool]$sleepResolution.proposalAliasRemoved -and [bool]$sleepResolution.workQuarantined -and [bool]$sleepResolution.failureWritten -and -not [bool]$sleepResolution.completePresent) 'R18ZT production catch sleeping-worker rollback case failed.'

        foreach ($directory in @($fastRoot,$fastCanonical,$fastWork,$fastOutput)) { [void](New-Item -ItemType Directory -Path $directory) }
        New-VerifiedProposalJunction $fastAlias $fastCanonical
        [IO.File]::WriteAllText($fastScript, "pass`n", (New-Object Text.UTF8Encoding($false)))
        $fastStartInfo = New-Object Diagnostics.ProcessStartInfo
        $fastStartInfo.FileName = $GatePythonPath
        $fastStartInfo.Arguments = Quote-ProcessArgument $fastScript
        $fastStartInfo.WorkingDirectory = $fastRoot
        $fastStartInfo.UseShellExecute = $false
        $fastStartInfo.CreateNoWindow = $true
        $fastProcess = New-Object Diagnostics.Process
        $fastProcess.StartInfo = $fastStartInfo
        Require ($fastProcess.Start()) 'R18ZT rollback gate fast worker did not start.'
        Require ($fastProcess.WaitForExit(10000)) 'R18ZT rollback gate fast worker did not exit.'
        New-R18ZTExactCompleteGateFixture $fastOutput $fastConfiguration $fastAlias $fastCanonical
        $fastResolution = Resolve-R18ZTLaunchFailure -OwnedProcess $fastProcess -OwnedProcessStarted $true -Detail 'EXPECTED_R18ZT_POST_COMPLETE_LAUNCH_REPORTING_FAILURE' -WorkRoot $fastWork -PartialRoot $fastPartial -FailedRoot $fastFailed -OutputRoot $fastOutput -FailurePath $fastFailure -ProposalAlias $fastAlias -CanonicalProposalRoot $fastCanonical -ProposalAliasCreated $true -ConfigurationPath $fastConfiguration
        $fastProcess = $null
        Require ([bool]$fastResolution.workerExitConfirmed -and [bool]$fastResolution.completePresent -and [bool]$fastResolution.completeExact -and [bool]$fastResolution.reportingErrorWritten -and [bool]$fastResolution.resourcesPreserved -and -not [bool]$fastResolution.failureWritten -and -not (Test-Path -LiteralPath $fastFailure)) 'R18ZT production catch post-COMPLETE arbitration case failed.'

        foreach ($directory in @($invalidRoot,$invalidCanonical,$invalidWork,$invalidOutput)) { [void](New-Item -ItemType Directory -Path $directory) }
        New-VerifiedProposalJunction $invalidAlias $invalidCanonical
        [IO.File]::WriteAllText($invalidScript, "pass`n", (New-Object Text.UTF8Encoding($false)))
        $invalidStartInfo = New-Object Diagnostics.ProcessStartInfo
        $invalidStartInfo.FileName = $GatePythonPath
        $invalidStartInfo.Arguments = Quote-ProcessArgument $invalidScript
        $invalidStartInfo.WorkingDirectory = $invalidRoot
        $invalidStartInfo.UseShellExecute = $false
        $invalidStartInfo.CreateNoWindow = $true
        $invalidProcess = New-Object Diagnostics.Process
        $invalidProcess.StartInfo = $invalidStartInfo
        Require ($invalidProcess.Start()) 'R18ZT rollback gate invalid-COMPLETE worker did not start.'
        Require ($invalidProcess.WaitForExit(10000)) 'R18ZT rollback gate invalid-COMPLETE worker did not exit.'
        Write-JsonNew $invalidConfiguration ([ordered]@{batchId='R18ZV2';proposalRoot=$invalidAlias;canonicalProposalRoot=$invalidCanonical}) 4
        Write-JsonNew (Join-Path $invalidOutput 'COMPLETE.json') ([ordered]@{schema='argos_opencv_scribe_r18zt_batch_complete_v2';state='COMPLETE_R18ZT_EXISTING_ORIENTED_CROPS_REVIEW_ONLY'}) 4
        $invalidResolution = Resolve-R18ZTLaunchFailure -OwnedProcess $invalidProcess -OwnedProcessStarted $true -Detail 'EXPECTED_R18ZT_INVALID_COMPLETE_FAILURE' -WorkRoot $invalidWork -PartialRoot $invalidPartial -FailedRoot $invalidFailed -OutputRoot $invalidOutput -FailurePath $invalidFailure -ProposalAlias $invalidAlias -CanonicalProposalRoot $invalidCanonical -ProposalAliasCreated $true -ConfigurationPath $invalidConfiguration
        $invalidProcess = $null
        Require ([bool]$invalidResolution.workerExitConfirmed -and [bool]$invalidResolution.completeOriginallyPresent -and -not [bool]$invalidResolution.completePresent -and -not [bool]$invalidResolution.completeExact -and [bool]$invalidResolution.invalidCompleteQuarantined -and [bool]$invalidResolution.proposalAliasRemoved -and [bool]$invalidResolution.workQuarantined -and [bool]$invalidResolution.failureWritten -and -not [bool]$invalidResolution.resourcesPreserved) 'R18ZT production catch invalid-COMPLETE quarantine case failed.'
        Require ((Test-Path -LiteralPath (Join-Path $invalidOutput 'COMPLETE.invalid.json') -PathType Leaf) -and (Test-Path -LiteralPath $invalidFailure -PathType Leaf) -and -not (Test-Path -LiteralPath (Join-Path $invalidOutput 'COMPLETE.json'))) 'R18ZT invalid-COMPLETE gate terminal leaves are inconsistent.'

        [void](New-Item -ItemType Directory -Path $collisionWork -Force)
        try { Assert-R18ZTFreshLaunchRoots -Paths @($collisionWork,$collisionPartial,$collisionFailed,$collisionOutput) }
        catch { $collisionRejected = $_.Exception.Message -like 'R18ZT fresh target exists:*' }
        Require $collisionRejected 'R18ZT pre-existing launch-root collision was not rejected.'
        [IO.Directory]::Delete($collisionWork, $false)
        Assert-R18ZTFreshLaunchRoots -Paths @((Join-Path $collisionRoot 'control.work'),(Join-Path $collisionRoot 'control.partial'),(Join-Path $collisionRoot 'control.failed'),(Join-Path $collisionRoot 'control.output'))
    }
    finally {
        foreach ($remainingProcess in @($sleepProcess,$fastProcess,$invalidProcess)) {
            if ($null -eq $remainingProcess) { continue }
            try {
                if (-not $remainingProcess.HasExited) {
                    $remainingProcess.Kill()
                    [void]$remainingProcess.WaitForExit(10000)
                }
            }
            catch {}
            $remainingProcess.Dispose()
        }
        if (Test-Path -LiteralPath $fastAlias) {
            try { Remove-OwnedProposalJunction $fastAlias $fastCanonical } catch {}
        }
        if (Test-Path -LiteralPath $invalidAlias) {
            try { Remove-OwnedProposalJunction $invalidAlias $invalidCanonical } catch {}
        }
        foreach ($file in @($sleepScript,$sleepFailure,$sleepConfiguration,$fastScript,$fastConfiguration,(Join-Path $fastOutput 'COMPLETE.json'),(Join-Path $fastOutput 'LAUNCH_REPORTING_ERROR.json'),(Join-Path $fastOutput 'AGGREGATE.json'),(Join-Path $fastOutput 'INVENTORY.json'),(Join-Path $fastOutput 'CASE_INDEX.json'),$invalidScript,$invalidConfiguration,$invalidFailure,(Join-Path $invalidOutput 'COMPLETE.json'),(Join-Path $invalidOutput 'COMPLETE.invalid.json'))) {
            if (Test-Path -LiteralPath $file -PathType Leaf) { [IO.File]::Delete($file) }
        }
        foreach ($directory in @($sleepFailed,$sleepOutput,$sleepCanonical,$sleepRoot,$fastWork,$fastOutput,$fastCanonical,$fastRoot,$invalidFailed,$invalidOutput,$invalidCanonical,$invalidRoot,$collisionRoot,$junctionGateRoot)) {
            if (Test-Path -LiteralPath $directory -PathType Container) { [IO.Directory]::Delete($directory, $false) }
        }
    }
    Require (-not (Test-Path -LiteralPath $junctionGateRoot)) 'R18ZT production catch gate did not close cleanly.'
    [ordered]@{
        schema = 'argos_opencv_scribe_r18zt_proposal_junction_gate_v1'
        checkedUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_R18ZT_PROPOSAL_JUNCTION_CREATION_AND_ROLLBACK'
        packageRevision = $GatePackageRevision
        testRoot = $junctionGateRoot
        exactJunctionCreationExercised = $true
        exactTargetVerificationExercised = $true
        injectedPrelaunchFailureExercised = $true
        soleOwnedWorkerStarted = $true
        soleOwnedWorkerTerminationVerified = [bool]$sleepResolution.workerExitConfirmed
        workerTerminatedBeforeAliasRollback = ([bool]$sleepResolution.workerExitConfirmed -and [bool]$sleepResolution.proposalAliasRemoved)
        exactOwnedJunctionRollbackExercised = $true
        actualProductionCatchFunctionExercised = $true
        sleepingWorkerRollbackCasePassed = $true
        fastCompleteReportingFailureCasePassed = $true
        postCompleteFailurePreservedExactComplete = $true
        invalidCompleteQuarantineCasePassed = $true
        invalidCompleteRemovedBeforeFailureCommit = $true
        preexistingRootCollisionRejectedBeforeProcess = $collisionRejected
        secondFreshControlPassed = $true
        completeFailureCoexistenceCount = 0
        delegateSubprocessCount = 0
        launcherSha256 = Get-Sha256 $GateLauncherScriptPath
        residualTestRootPresent = $false
        canonicalSourceAccessed = $false
        sourceImageBytesRead = $false
        targetExecuted = $false
        publicationPerformed = $false
        sourceMutationPerformed = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 8
    return
}
if ($JunctionGate) {
    Invoke-R18ZTProposalJunctionGate -GatePythonPath $PythonPath -GatePythonSha256 $ExpectedPythonSha256 -GatePackageRevision $packageRevision -GateLauncherScriptPath $launcherScriptPath
    return
}
if (-not $PackageValidationOnly) {
    Require ([IO.Path]::GetFullPath($WorkRoot).Equals($configuredWorkRoot, [StringComparison]::OrdinalIgnoreCase)) 'R18ZT live work root override is refused.'
    Require ([IO.Path]::GetFullPath($OutputRoot).Equals($configuredOutputRoot, [StringComparison]::OrdinalIgnoreCase)) 'R18ZT live output root override is refused.'
    Require ([IO.Path]::GetFullPath($CanonicalProposalRoot).Equals($configuredCanonicalProposalRoot, [StringComparison]::OrdinalIgnoreCase)) 'R18ZT live canonical proposal root override is refused.'
}
foreach ($pin in @(
    [pscustomobject]@{value=$payloadManifestSha;label='payload manifest'},
    [pscustomobject]@{value=$configurationSha;label='configuration'},
    [pscustomobject]@{value=$envelopeSha;label='execution envelope'},
    [pscustomobject]@{value=$delegateSha;label='batch runner'},
    [pscustomobject]@{value=$providerSha;label='provider'}
)) { Require-FinalSha ([string]$pin.value) ([string]$pin.label) }
Require ($providerRevision -notmatch '^PENDING_') 'R18ZT provider revision is not finalized.'

$payload = if ([string]::IsNullOrWhiteSpace($PayloadRoot)) { $PSScriptRoot } else { [IO.Path]::GetFullPath($PayloadRoot) }
$payloadFilesRoot = Join-Path $payload 'files'
$payloadManifestPath = Join-Path $payload 'R18ZT_PAYLOAD_MANIFEST.json'
$partialRoot = $WorkRoot + '.partial'
$failedRoot = $WorkRoot + '.failed'
$configurationRelative = 'OPENCV_SCRIBE_R18ZT_BATCH\R18ZT_BATCH_CONFIGURATION.json'
$envelopeRelative = 'OPENCV_SCRIBE_R18ZT_BATCH\Run-R18ZTBatchExecutionEnvelope.py'
$delegateRelative = 'OPENCV_SCRIBE_R18ZT_BATCH\Run-R18ZTExistingOrientedCrops.py'
$providerRelative = 'OPENCV_SCRIBE_R18ZV1\ArgosOpenCvScribeV1R18ZV1BatchAdapter.py'
$r11AnalyzerRelative = 'OPENCV_SCRIBE_R11A\ArgosOpenCvScribeV1R11.py'
$configurationPath = Join-Path $WorkRoot $configurationRelative
$envelopePath = Join-Path $WorkRoot $envelopeRelative
$delegatePath = Join-Path $WorkRoot $delegateRelative
$providerPath = Join-Path $WorkRoot $providerRelative
$r11AnalyzerPath = Join-Path $WorkRoot $r11AnalyzerRelative
$proposalAlias = Join-Path $WorkRoot 'p'
$launchPath = Join-Path $OutputRoot 'LAUNCH.json'
$failurePath = Join-Path $OutputRoot 'FAILURE.json'

$requiredDependencies = @($payloadManifestPath, $payloadFilesRoot, $PythonPath, $ReferenceBundlePath)
if (-not $PackageValidationOnly) { $requiredDependencies += $CanonicalProposalRoot }
foreach ($path in $requiredDependencies) {
    Require (Test-Path -LiteralPath $path) "R18ZT dependency absent: $path"
    Assert-PathBudget $path
}
$proposalPathBudget = $null
if (-not $PackageValidationOnly) {
    Require ([IO.Path]::GetFullPath($proposalAlias).Equals($configuredProposalAlias, [StringComparison]::OrdinalIgnoreCase)) 'R18ZT computed proposal alias changed.'
    $proposalPathBudget = Get-ActualProposalPathBudget $CanonicalProposalRoot $proposalAlias
}
Require ((Get-Sha256 $payloadManifestPath) -eq $payloadManifestSha) 'R18ZT payload manifest changed.'
Require ((Get-Sha256 $PythonPath) -eq $ExpectedPythonSha256) 'R18ZT Python runtime changed.'
Require ((Get-Sha256 $ReferenceBundlePath) -eq $referenceBundleSha) 'R18ZT reference bundle changed.'
if (-not $Rehearsal) {
    $installationPath = 'D:\AFCV1\INSTALLATION.json'
    Require (Test-Path -LiteralPath $installationPath -PathType Leaf) 'R18ZT runtime installation evidence absent.'
    Require ((Get-Sha256 $installationPath) -eq $installationSha) 'R18ZT runtime installation evidence changed.'
}

$manifest = Get-Content -LiteralPath $payloadManifestPath -Raw | ConvertFrom-Json
Require ([string]$manifest.schema -eq 'argos_opencv_scribe_r18zt_payload_manifest_v2' -and [string]$manifest.revision -eq $packageRevision) 'R18ZT payload manifest contract changed.'
Require ([string]$manifest.state -eq 'FROZEN_UNPUBLISHED' -and [bool]$manifest.finalizationComplete) 'R18ZT payload manifest is not finalized.'
Assert-ReviewOnlyAuthority $manifest.authority 'R18ZT payload manifest'
foreach ($field in @(
    'providerTransitiveClosureComplete',
    'runnerHashPinned',
    'providerHashPinned',
    'configurationHashPinned',
    'executionEnvelopeHashPinned',
    'allPayloadBytesAndHashesPinned',
    'allDevelopmentAndRegressionGatesPinned'
)) {
    $property = $manifest.finalization.PSObject.Properties[$field]
    Require ($null -ne $property -and [bool]$property.Value) "R18ZT payload finalization is incomplete: $field"
}

$files = @($manifest.files)
Require ($files.Count -ge 4 -and $files.Count -le 96) 'R18ZT payload manifest file count is outside the bounded range.'
$payloadPathSet = New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
$payloadRows = New-Object Collections.Generic.List[object]
foreach ($file in $files) {
    $relative = Get-SafeRelativePath ([string]$file.installRelativePath) 'R18ZT payload path'
    Require ($payloadPathSet.Add($relative)) "R18ZT duplicate payload path: $relative"
    Require ($relative -notmatch '(^|\\)(__pycache__|tests?|fixtures?)(\\|$)' -and $relative -notmatch '\.(pyc|pyo)$') "R18ZT prohibited runtime payload member: $relative"
    $expectedHash = [string]$file.sha256
    Require-FinalSha $expectedHash "payload member $relative"
    Require ([int64]$file.bytes -gt 0 -and [int64]$file.bytes -le 67108864) "R18ZT payload member byte bound changed: $relative"
    $source = Join-Path $payloadFilesRoot $relative
    $destination = Join-Path $partialRoot $relative
    Assert-ContainedPath $payloadFilesRoot $source 'R18ZT payload source'
    Assert-ContainedPath $partialRoot $destination 'R18ZT payload destination'
    Require (Test-Path -LiteralPath $source -PathType Leaf) "R18ZT payload file absent: $relative"
    $sourceItem = Get-Item -LiteralPath $source -Force
    Require (-not $sourceItem.Attributes.HasFlag([IO.FileAttributes]::ReparsePoint)) "R18ZT payload reparse file: $relative"
    Require ($sourceItem.Length -eq [int64]$file.bytes) "R18ZT payload length changed: $relative"
    Require ((Get-Sha256 $source) -eq $expectedHash) "R18ZT payload hash changed: $relative"
    Assert-PathBudget $source
    Assert-PathBudget $destination
    $payloadRows.Add([pscustomobject]@{relativePath=$relative;source=$source;destination=$destination;sha256=$expectedHash})
}

$requiredPayloadHashes = [ordered]@{
    $configurationRelative = $configurationSha
    $envelopeRelative = $envelopeSha
    $delegateRelative = $delegateSha
    $providerRelative = $providerSha
    $r11AnalyzerRelative = $r11AnalyzerSha
}
foreach ($required in $requiredPayloadHashes.GetEnumerator()) {
    $matches = @($payloadRows | Where-Object { $_.relativePath.Equals([string]$required.Key, [StringComparison]::OrdinalIgnoreCase) })
    Require ($matches.Count -eq 1) "R18ZT required payload member changed: $($required.Key)"
    Require ([string]$matches[0].sha256 -eq [string]$required.Value) "R18ZT required payload hash changed: $($required.Key)"
}

$requiredExternal = [ordered]@{
    'D:\O2D5\ARGOS_O2D5\O2D5_REFS.zip' = $referenceBundleSha
    'D:\AFCV1\rt\python.exe' = '7D96A4ED35D6E596CD9DD8933FEAFC66349CC21F75BE3B15C89FD336E50140C1'
    'D:\AFCV1\INSTALLATION.json' = $installationSha
}
$externalRows = @($manifest.externalDependencies)
Require ($externalRows.Count -eq $requiredExternal.Count) 'R18ZT external dependency count changed.'
foreach ($required in $requiredExternal.GetEnumerator()) {
    $matches = @($externalRows | Where-Object { [IO.Path]::GetFullPath(([string]$_.path).Replace('/', '\')).Equals([IO.Path]::GetFullPath([string]$required.Key), [StringComparison]::OrdinalIgnoreCase) })
    Require ($matches.Count -eq 1 -and [string]$matches[0].sha256 -eq [string]$required.Value) "R18ZT external dependency changed: $($required.Key)"
}

$configurationSource = Join-Path $payloadFilesRoot $configurationRelative
$configuration = Get-Content -LiteralPath $configurationSource -Raw | ConvertFrom-Json
Require ((Get-Sha256 $configurationSource) -eq $configurationSha) 'R18ZT configuration changed.'
Assert-ExactFieldSet $configuration @('schema','batchId','revision','canonicalProposalRoot','proposalRoot','outputRoot','provider','references','limits','authority') 'R18ZT configuration'
Assert-ExactFieldSet $configuration.provider @('path','sha256','revision','r11AnalyzerPath','r11AnalyzerSha256') 'R18ZT provider binding'
Assert-ExactFieldSet $configuration.references @('manifestPath','manifestSha256','roots','supplementalManifestPath','supplementalManifestSha256','r18zExactLineageLooGatePath','r18zExactLineageLooGateSha256','exactScribeLineageCrosswalkPath','exactScribeLineageCrosswalkSha256') 'R18ZT references'
Assert-ExactFieldSet $configuration.limits @('maximumDirectChildren','maximumIdentityCharacters','maximumJsonBytes','maximumOrientedInputBytes','maximumProviderResultBytes') 'R18ZT limits'
Assert-ExactFieldSet $configuration.authority @('reviewOnly','automaticIdentityAuthority','automaticReferenceAdmissionAuthorized','trainingEligible','activationAuthorized','xmlEligible','productionEligible','mayClearHolds','sourceMutationAllowed','automaticRetryAllowed') 'R18ZT runner authority'
Require ([string]$configuration.schema -eq 'argos_opencv_scribe_r18zt_batch_configuration_v2' -and [string]$configuration.batchId -eq 'R18ZV2' -and [string]$configuration.revision -eq $runnerRevision) 'R18ZT configuration contract changed.'
Require ([IO.Path]::GetFullPath([string]$configuration.outputRoot).Equals($configuredOutputRoot, [StringComparison]::OrdinalIgnoreCase) -and [IO.Path]::GetFullPath([string]$configuration.canonicalProposalRoot).Equals($configuredCanonicalProposalRoot, [StringComparison]::OrdinalIgnoreCase) -and [IO.Path]::GetFullPath([string]$configuration.proposalRoot).Equals($configuredProposalAlias, [StringComparison]::OrdinalIgnoreCase)) 'R18ZT configuration roots changed.'
Require ([IO.Path]::GetFullPath([string]$configuration.provider.path).Equals($configuredProviderPath, [StringComparison]::OrdinalIgnoreCase) -and [string]$configuration.provider.sha256 -eq $providerSha -and [string]$configuration.provider.revision -eq $providerRevision) 'R18ZT provider binding changed.'
Require ([IO.Path]::GetFullPath([string]$configuration.provider.r11AnalyzerPath).Equals($configuredR11AnalyzerPath, [StringComparison]::OrdinalIgnoreCase) -and [string]$configuration.provider.r11AnalyzerSha256 -eq $r11AnalyzerSha) 'R18ZT frozen R11 analyze_images binding changed.'
Require ([string]$configuration.references.manifestSha256 -eq $baseManifestSha -and [string]$configuration.references.supplementalManifestSha256 -eq $supplementalManifestSha -and [string]$configuration.references.exactScribeLineageCrosswalkSha256 -eq $crosswalkSha -and [string]$configuration.references.r18zExactLineageLooGateSha256 -eq $looGateSha) 'R18ZT reference pins changed.'
Require ([int]$configuration.limits.maximumDirectChildren -eq 10000 -and [int]$configuration.limits.maximumIdentityCharacters -eq 80 -and [int64]$configuration.limits.maximumJsonBytes -eq 16777216 -and [int64]$configuration.limits.maximumOrientedInputBytes -eq 67108864 -and [int64]$configuration.limits.maximumProviderResultBytes -eq 67108864) 'R18ZT bounded runner limits changed.'
Assert-RunnerAuthority $configuration.authority
Assert-NoRuntimeEnvironmentOverrides

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($ReferenceBundlePath)
$archiveEntryCount = 0
$archivePathSet = New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
$baseManifestEntries = New-Object Collections.Generic.List[object]
try {
    foreach ($entry in $archive.Entries) {
        Require ($archiveEntryCount -lt 10000) 'R18ZT reference archive entry bound exceeded.'
        $entryName = ([string]$entry.FullName).Replace('/', '\').TrimEnd('\')
        $relative = Get-SafeRelativePath $entryName 'R18ZT reference archive path'
        Require ($archivePathSet.Add($relative)) "R18ZT duplicate reference archive path: $relative"
        $destination = Join-Path $partialRoot $relative
        Assert-ContainedPath $partialRoot $destination 'R18ZT reference archive destination'
        Assert-PathBudget $destination
        $archiveEntryCount++
        if ($relative.Equals('refs\PORTABLE_GLYPH_REFERENCE_MANIFEST.json', [StringComparison]::OrdinalIgnoreCase)) { $baseManifestEntries.Add($entry) }
    }
    Require ($archiveEntryCount -gt 0) 'R18ZT reference archive is empty.'
    Require ($baseManifestEntries.Count -eq 1) 'R18ZT base reference manifest member changed.'
    $baseManifestStream = $baseManifestEntries[0].Open()
    try { Require ((Get-StreamSha256 $baseManifestStream) -eq $baseManifestSha) 'R18ZT base reference manifest changed.' }
    finally { $baseManifestStream.Dispose() }
}
finally { $archive.Dispose() }

foreach ($path in @(
    $WorkRoot,
    $partialRoot,
    $failedRoot,
    $OutputRoot,
    $configurationPath,
    $envelopePath,
    $delegatePath,
    $providerPath,
    $r11AnalyzerPath,
    $proposalAlias,
    $installedLauncher
)) { Assert-PathBudget $path 32 }
foreach ($path in @(
    $launchPath,
    $failurePath,
    (Join-Path $OutputRoot 'STATUS.json'),
    (Join-Path $OutputRoot 'RUNNING.json'),
    (Join-Path $OutputRoot 'COMPLETE.json'),
    (Join-Path $OutputRoot 'COMPLETE.invalid.json'),
    (Join-Path $OutputRoot 'LAUNCH_REPORTING_ERROR.json'),
    (Join-Path $OutputRoot 'WORKER.stdout.log'),
    (Join-Path $OutputRoot 'WORKER.stderr.log'),
    (Join-Path $OutputRoot 'INVENTORY.json'),
    (Join-Path $OutputRoot 'CASE_INDEX.json'),
    (Join-Path $OutputRoot 'AGGREGATE.json'),
    (Join-Path $OutputRoot 'cases\0123456789ABCDEF0123\SCRIBE_JOB.json'),
    (Join-Path $OutputRoot 'cases\0123456789ABCDEF0123\CASE_RESULT.json'),
    (Join-Path $OutputRoot 'cases\0123456789ABCDEF0123\PROVIDER_RESULT.json'),
    (Join-Path $OutputRoot 'cases\0123456789ABCDEF0123\PROVIDER_RESULT.json.partial'),
    (Join-Path $OutputRoot 'cases\0123456789ABCDEF0123\PROVIDER_RESULT_FAILED.json')
)) { Assert-PathBudget $path 52 }
Assert-R18ZTFreshLaunchRoots -Paths @($WorkRoot, $partialRoot, $failedRoot, $OutputRoot)
$pythonCommand = Get-Command -Name $PythonPath -CommandType Application -ErrorAction Stop
Require ([IO.Path]::GetFullPath($pythonCommand.Source).Equals([IO.Path]::GetFullPath($PythonPath), [StringComparison]::OrdinalIgnoreCase)) 'R18ZT Python resolution changed.'
$outputDriveName = [IO.Path]::GetPathRoot([IO.Path]::GetFullPath($OutputRoot)).Substring(0, 1)
$outputDrive = Get-PSDrive -Name $outputDriveName -ErrorAction Stop
Require ([int64]$outputDrive.Free -ge 10737418240) 'R18ZT output drive has less than the required free space.'

if ($Preflight) {
    [ordered]@{
        schema = 'argos_opencv_scribe_r18zt_batch_launch_preflight_v1'
        createdUtc = [DateTime]::UtcNow.ToString('o')
        state = $(if ($PackageValidationOnly) { 'PASS_R18ZT_STATIC_PACKAGE_PREFLIGHT' } else { 'PASS_R18ZT_BATCH_LAUNCH_PREFLIGHT' })
        revision = $packageRevision
        runnerRevision = $runnerRevision
        envelopeRevision = $envelopeRevision
        rehearsal = [bool]$Rehearsal
        packageValidationOnly = [bool]$PackageValidationOnly
        installedLauncher = $installedLauncher
        payloadManifestSha256 = $payloadManifestSha
        payloadFileCount = $files.Count
        pythonSha256 = $ExpectedPythonSha256
        referenceBundleSha256 = $referenceBundleSha
        referenceArchiveEntryCount = $archiveEntryCount
        canonicalProposalRoot = $CanonicalProposalRoot
        proposalAlias = $proposalAlias
        workRoot = $WorkRoot
        outputRoot = $OutputRoot
        actualProposalPathBudgetPerformed = ($null -ne $proposalPathBudget)
        actualDirectChildCount = $(if ($null -eq $proposalPathBudget) { 0 } else { [int]$proposalPathBudget.directChildCount })
        actualFourSourceLeafCount = $(if ($null -eq $proposalPathBudget) { 0 } else { [int]$proposalPathBudget.actualFourSourceLeafCount })
        actualFourSourceLeafSetSha256 = $(if ($null -eq $proposalPathBudget) { '' } else { [string]$proposalPathBudget.actualFourSourceLeafSetSha256 })
        maximumActualSourceEffectiveLength = $(if ($null -eq $proposalPathBudget) { 0 } else { [int]$proposalPathBudget.maximumEffectiveLength })
        sourceLeafSuffixReserveCharacters = 32
        outputAtomicSuffixReserveCharacters = 52
        sourceInventoryAndHashingDeferredToOwnedWorker = $true
        sourceImageBytesHashed = $false
        pixelsDecoded = $false
        targetWritesPerformed = $false
        processInspectionPerformed = $false
        processStarted = $false
        taskActionsPerformed = $false
        automaticRetryAllowed = $false
        completionClaimed = $false
        publicationAuthorized = $false
        publicationPerformed = $false
        sourceMutationPerformed = $false
        identityAccepted = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 12
    return
}

$ownedProcess = $null
$ownedProcessStarted = $false
$ownedWorkerTerminatedByLauncher = $false
$ownedWorkerExitConfirmed = $false
$workerCompletedBeforeConfirmation = $false
$proposalAliasCreated = $false
$proposalAliasRemovedOnFailure = $false
try {
    [void](New-Item -ItemType Directory -Path $partialRoot)
    [IO.Compression.ZipFile]::ExtractToDirectory($ReferenceBundlePath, $partialRoot)
    foreach ($row in $payloadRows) {
        $destinationParent = Split-Path -Parent $row.destination
        [void](New-Item -ItemType Directory -Path $destinationParent -Force)
        Copy-Item -LiteralPath $row.source -Destination $row.destination -ErrorAction Stop
        Require ((Get-Sha256 $row.destination) -eq $row.sha256) "R18ZT staged payload changed: $($row.relativePath)"
    }
    Move-Item -LiteralPath $partialRoot -Destination $WorkRoot -ErrorAction Stop
    foreach ($row in $payloadRows) {
        $staged = Join-Path $WorkRoot $row.relativePath
        Require ((Get-Sha256 $staged) -eq $row.sha256) "R18ZT committed payload changed: $($row.relativePath)"
    }
    Require ((Get-Sha256 $configurationPath) -eq $configurationSha) 'R18ZT staged configuration changed.'
    Require ((Get-Sha256 $envelopePath) -eq $envelopeSha) 'R18ZT staged execution envelope changed.'
    Require ((Get-Sha256 $delegatePath) -eq $delegateSha) 'R18ZT staged batch runner changed.'
    Require ((Get-Sha256 $providerPath) -eq $providerSha) 'R18ZT staged provider changed.'
    Require ((Get-Sha256 $r11AnalyzerPath) -eq $r11AnalyzerSha) 'R18ZT staged R11 analyzer changed.'
    New-VerifiedProposalJunction $proposalAlias $CanonicalProposalRoot
    $proposalAliasCreated = $true
    [void](New-Item -ItemType Directory -Path $OutputRoot)

    $arguments = @(
        (Quote-ProcessArgument $envelopePath),
        '--delegate', (Quote-ProcessArgument $delegatePath),
        '--delegate-sha256', (Quote-ProcessArgument $delegateSha),
        '--configuration', (Quote-ProcessArgument $configurationPath),
        '--output-root', (Quote-ProcessArgument $OutputRoot)
    ) -join ' '
    $startInfo = New-Object Diagnostics.ProcessStartInfo
    $startInfo.FileName = $PythonPath
    $startInfo.Arguments = $arguments
    $startInfo.WorkingDirectory = $WorkRoot
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $false
    $startInfo.RedirectStandardError = $false
    $ownedProcess = New-Object Diagnostics.Process
    $ownedProcess.StartInfo = $startInfo
    Require ($ownedProcess.Start()) 'R18ZT batch worker did not start.'
    $ownedProcessStarted = $true
    $ownedProcessId = [int]$ownedProcess.Id
    $ownedProcessStartTimeUtc = $ownedProcess.StartTime.ToUniversalTime().ToString('o')
    Start-Sleep -Seconds 2
    $ownedProcess.Refresh()
    if ($ownedProcess.HasExited) {
        $ownedWorkerExitConfirmed = $true
        Require ([int]$ownedProcess.ExitCode -eq 0) 'R18ZT batch worker exited nonzero before launch confirmation.'
        $fastCompleteValidation = Get-R18ZTExactCompleteValidation $OutputRoot $configurationPath
        Require ([bool]$fastCompleteValidation.present -and [bool]$fastCompleteValidation.exact) "R18ZT fast completion terminal contract changed: $($fastCompleteValidation.detail)"
        $workerCompletedBeforeConfirmation = $true
    }

    $launch = [ordered]@{
        schema = 'argos_opencv_scribe_r18zt_batch_launch_v2'
        createdUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_R18ZT_BATCH_WORKER_STARTED'
        proves = 'ASYNC_WORKER_LAUNCH_ONLY'
        completionClaimed = $false
        terminalStatusStateExpected = 'COMPLETE_R18ZT_EXISTING_ORIENTED_CROPS_REVIEW_ONLY'
        terminalPointerLeaf = 'COMPLETE.json'
        revision = $packageRevision
        runnerRevision = $runnerRevision
        envelopeRevision = $envelopeRevision
        computerName = $env:COMPUTERNAME
        processId = $ownedProcessId
        processStartTimeUtc = $ownedProcessStartTimeUtc
        workerStateAtConfirmation = $(if ($workerCompletedBeforeConfirmation) { 'COMPLETED_EXACT_TERMINAL' } else { 'RUNNING' })
        fastCompletionValidated = $workerCompletedBeforeConfirmation
        installedLauncher = $installedLauncher
        workRoot = $WorkRoot
        outputRoot = $OutputRoot
        canonicalProposalRoot = $CanonicalProposalRoot
        proposalAlias = $proposalAlias
        proposalAliasType = 'DIRECTORY_JUNCTION'
        proposalAliasTargetVerified = $true
        actualDirectChildCount = [int]$proposalPathBudget.directChildCount
        actualFourSourceLeafCount = [int]$proposalPathBudget.actualFourSourceLeafCount
        actualFourSourceLeafSetSha256 = [string]$proposalPathBudget.actualFourSourceLeafSetSha256
        maximumActualSourceEffectiveLength = [int]$proposalPathBudget.maximumEffectiveLength
        actualSourcePathSuffixReserveCharacters = 32
        payloadManifestSha256 = $payloadManifestSha
        payloadFileCount = $files.Count
        pythonSha256 = $ExpectedPythonSha256
        referenceBundleSha256 = $referenceBundleSha
        providerSha256 = $providerSha
        delegateSha256 = $delegateSha
        executionEnvelopeSha256 = $envelopeSha
        sourceInventoryDeferredToOwnedWorker = $true
        sourceImageBytesHashedByLauncher = $false
        pixelsDecodedByLauncher = $false
        processInspectionPerformed = $false
        taskActionCount = 0
        existingProcessActionCount = 0
        ownedProcessStarted = $true
        automaticRetryAllowed = $false
        publicationAuthorized = $false
        publicationPerformed = $false
        sourceMutationPerformed = $false
        identityAccepted = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    }
    Write-JsonNew $launchPath $launch 12
    Write-Output -InputObject ($launch | ConvertTo-Json -Compress -Depth 12)
    $ownedProcess.Dispose()
    $ownedProcess = $null
}
catch {
    $detail = $_.Exception.Message
    $failureResolution = Resolve-R18ZTLaunchFailure -OwnedProcess $ownedProcess -OwnedProcessStarted $ownedProcessStarted -Detail $detail -WorkRoot $WorkRoot -PartialRoot $partialRoot -FailedRoot $failedRoot -OutputRoot $OutputRoot -FailurePath $failurePath -ProposalAlias $proposalAlias -CanonicalProposalRoot $CanonicalProposalRoot -ProposalAliasCreated $proposalAliasCreated -ConfigurationPath $configurationPath
    $ownedProcess = $null
    if ([bool]$failureResolution.completeExact) {
        Write-Output -InputObject ([ordered]@{
            schema = 'argos_opencv_scribe_r18zt_launch_reporting_hold_v1'
            state = 'HOLD_R18ZT_LAUNCH_REPORTING_ERROR_AFTER_EXACT_COMPLETE_PRESERVED'
            completeExact = $true
            failureCreated = $false
            resourcesPreserved = $true
            automaticRetryAllowed = $false
            completionClaimedByLauncher = $false
            reviewOnly = $true
        } | ConvertTo-Json -Compress -Depth 6)
    }
    throw
}

#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$InvocationManifest,
    [switch]$Preflight,
    [switch]$Apply
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Require([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-Sha256([string]$Path) {
    $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '') }
    finally { $sha.Dispose(); $stream.Dispose() }
}

function Get-BytesSha256([byte[]]$Bytes) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-', '') }
    finally { $sha.Dispose() }
}

function Read-JsonFile([string]$Path, [int64]$MaximumBytes) {
    $item = Get-Item -LiteralPath $Path -ErrorAction Stop
    Require ($item.PSIsContainer -eq $false -and [int64]$item.Length -le $MaximumBytes) "Missing or oversized JSON file: $Path"
    $bytes = [IO.File]::ReadAllBytes($Path)
    $text = (New-Object Text.UTF8Encoding($false, $true)).GetString($bytes)
    try { return ($text | ConvertFrom-Json) }
    catch { throw "Invalid JSON file: $Path :: $($_.Exception.Message)" }
}

function Resolve-DeclaredLocalPath([string]$ProjectRoot, [string]$Declared, [string[]]$AllowedAbsoluteRoots) {
    Require (-not [string]::IsNullOrWhiteSpace($Declared)) 'A declared local path is empty.'
    if ([IO.Path]::IsPathRooted($Declared)) {
        $full = [IO.Path]::GetFullPath($Declared)
        $allowed = $false
        foreach ($root in @($AllowedAbsoluteRoots)) {
            $rootFull = [IO.Path]::GetFullPath([string]$root).TrimEnd('\')
            if ($full.Equals($rootFull, [StringComparison]::OrdinalIgnoreCase) -or
                $full.StartsWith($rootFull + '\', [StringComparison]::OrdinalIgnoreCase)) {
                $allowed = $true
                break
            }
        }
        Require $allowed "Absolute local dependency is outside the frozen read roots: $Declared"
        return $full
    }
    Require ($Declared -notmatch '(^|[/\\])\.\.([/\\]|$)') "Project-relative dependency contains traversal: $Declared"
    $projectFull = [IO.Path]::GetFullPath($ProjectRoot).TrimEnd('\')
    $full = [IO.Path]::GetFullPath((Join-Path $projectFull $Declared.Replace('/', '\')))
    Require ($full.StartsWith($projectFull + '\', [StringComparison]::OrdinalIgnoreCase)) "Dependency escaped the project root: $Declared"
    return $full
}

function Require-PinnedFile([string]$Path, [string]$Sha256, [object]$Bytes, [string]$Label) {
    Require ($Sha256 -cmatch '^[A-F0-9]{64}$') "$Label SHA-256 is not finalized."
    Require (Test-Path -LiteralPath $Path -PathType Leaf) "$Label is absent: $Path"
    $item = Get-Item -LiteralPath $Path -ErrorAction Stop
    if ($null -ne $Bytes) {
        Require ([string]$Bytes -match '^\d+$' -and [int64]$item.Length -eq [int64]$Bytes) "$Label byte length changed."
    }
    Require ((Get-Sha256 $Path) -ceq $Sha256) "$Label SHA-256 changed."
}

function Get-NestedValue([object]$Object, [string]$PropertyPath, [string]$Label) {
    Require (-not [string]::IsNullOrWhiteSpace($PropertyPath)) "$Label property path is empty."
    $current = $Object
    foreach ($segment in $PropertyPath.Split('.')) {
        Require ($null -ne $current) "$Label property is absent: $PropertyPath"
        $property = $current.PSObject.Properties[$segment]
        Require ($null -ne $property) "$Label property is absent: $PropertyPath"
        $current = $property.Value
    }
    return $current
}

function Read-ZipEntryBytes([IO.Compression.ZipArchive]$Zip, [string]$Name, [int64]$MaximumBytes) {
    $matches = @($Zip.Entries | Where-Object {
        [string]::Equals(([string]$_.FullName).Replace('\', '/'), $Name, [StringComparison]::Ordinal)
    })
    Require ($matches.Count -eq 1) "Missing or duplicated ZIP member: $Name"
    Require ([int64]$matches[0].Length -le $MaximumBytes) "Oversized ZIP member: $Name"
    $input = $matches[0].Open()
    $memory = New-Object IO.MemoryStream
    try {
        $input.CopyTo($memory)
        return ,([byte[]]$memory.ToArray())
    }
    finally { $memory.Dispose(); $input.Dispose() }
}

function Get-ZipEntrySha256([IO.Compression.ZipArchiveEntry]$Entry) {
    $stream = $Entry.Open()
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '') }
    finally { $sha.Dispose(); $stream.Dispose() }
}

function Write-JsonCreateNew([string]$Path, [object]$Value) {
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes((($Value | ConvertTo-Json -Depth 32) + [Environment]::NewLine))
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush($true)
    }
    finally { $stream.Dispose() }
}

function Write-JsonAtomicCreateNew([string]$PartialPath, [string]$FinalPath, [object]$Value) {
    Require (-not (Test-Path -LiteralPath $PartialPath) -and -not (Test-Path -LiteralPath $FinalPath)) 'R18ZT atomic JSON destination already exists.'
    Write-JsonCreateNew $PartialPath $Value
    [IO.File]::Move($PartialPath, $FinalPath)
}

Require (([bool]$Preflight) -ne ([bool]$Apply)) 'Specify exactly one of -Preflight or -Apply.'
Require ($PSVersionTable.PSEdition -eq 'Desktop' -and $PSVersionTable.PSVersion.Major -eq 5 -and $PSVersionTable.PSVersion.Minor -eq 1) 'R18ZT publication requires Windows PowerShell 5.1 Desktop exactly.'

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$fixedInvocationPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'R18ZV1_PUBLICATION_INVOCATION.json'))
$providedInvocationPath = [IO.Path]::GetFullPath($InvocationManifest)
Require ($providedInvocationPath.Equals($fixedInvocationPath, [StringComparison]::OrdinalIgnoreCase)) 'Only the fixed R18ZT publication invocation manifest is accepted.'
Require (Test-Path -LiteralPath $fixedInvocationPath -PathType Leaf) 'The fixed R18ZT publication invocation manifest is absent.'
$invocationSha256 = Get-Sha256 $fixedInvocationPath
$invocation = Read-JsonFile $fixedInvocationPath 1048576
Require ([string]$invocation.schema -ceq 'argos_opencv_scribe_r18zv1_publication_invocation_v1') 'R18ZV1 invocation schema changed.'
Require ([string]$invocation.state -ceq 'FROZEN_R18ZV1_PUBLICATION_INVOCATION_V1') 'R18ZV1 invocation is not frozen.'
Require ([string]$invocation.requestId -ceq 'REQ_RZV1') 'R18ZT publication request identity changed.'
Require ([string]$invocation.lifecycle -ceq 'FROZEN') 'R18ZT publication invocation lifecycle changed.'
Require (-not [bool]$invocation.authority.retryAuthorized -and [int]$invocation.authority.maximumPublications -eq 1) 'R18ZT publication retry/count authority changed.'
Require ([bool]$invocation.authority.reviewOnly -and -not [bool]$invocation.authority.identityAcceptanceAuthorized -and
    -not [bool]$invocation.authority.trainingAuthorized -and -not [bool]$invocation.authority.xmlAuthorized -and
    -not [bool]$invocation.authority.productionAuthorized) 'R18ZT publication authority widened.'

$allowedAbsoluteRoots = @($invocation.allowedAbsoluteLocalReadRoots | ForEach-Object { [string]$_ })
Require ($allowedAbsoluteRoots.Count -ge 1) 'R18ZT invocation has no absolute local evidence-root allowlist.'
$validated = @{}
foreach ($dependency in @($invocation.dependencies)) {
    $name = [string]$dependency.name
    Require ($name -cmatch '^[A-Za-z][A-Za-z0-9]*$' -and -not $validated.ContainsKey($name)) "Invalid or duplicated R18ZT dependency name: $name"
    $path = Resolve-DeclaredLocalPath $projectRoot ([string]$dependency.path) $allowedAbsoluteRoots
    Require-PinnedFile $path ([string]$dependency.sha256) $dependency.bytes "R18ZT dependency $name"
    $validated[$name] = [pscustomobject]@{ row=$dependency; path=$path; sha256=[string]$dependency.sha256 }
}

function Get-ValidatedDependency([string]$Name) {
    Require ($validated.ContainsKey($Name)) "Required R18ZT dependency is not declared: $Name"
    return $validated[$Name]
}

$selfPath = [IO.Path]::GetFullPath([string]$MyInvocation.MyCommand.Path)
$selfSha256 = Get-Sha256 $selfPath
$publisherDependency = Get-ValidatedDependency ([string]$invocation.tools.publisherDependency)
Require ($selfPath.Equals([string]$publisherDependency.path, [StringComparison]::OrdinalIgnoreCase)) 'R18ZT publisher runtime path differs from the frozen publisher path.'
Require ($selfSha256 -ceq [string]$publisherDependency.sha256) 'R18ZT publisher runtime self-hash differs from the invocation pin.'
$collectorDependency = Get-ValidatedDependency ([string]$invocation.tools.collectorDependency)

function Invoke-GitScalar([string[]]$Arguments, [string]$Label) {
    $text = (& git -C $projectRoot @Arguments | Out-String).Trim()
    Require ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($text)) "R18ZT git read failed: $Label"
    return $text
}
$currentBranch = Invoke-GitScalar -Arguments @('branch','--show-current') -Label 'branch'
$localTip = Invoke-GitScalar -Arguments @('rev-parse','HEAD') -Label 'local HEAD'
$originTip = Invoke-GitScalar -Arguments @('rev-parse',('origin/' + [string]$invocation.git.branch)) -Label 'recorded origin tip'
$statusRows = @(& git -C $projectRoot status --porcelain=v1 --untracked-files=all)
Require ($LASTEXITCODE -eq 0) 'R18ZT git status read failed.'
Require ([string]$invocation.git.branch -ceq 'codex/opencv-scribe-deciphering') 'R18ZT publication branch declaration changed.'
Require (-not [bool]$invocation.git.fetchAuthorized -and $currentBranch -ceq [string]$invocation.git.branch -and
    $localTip -ceq $originTip -and $statusRows.Count -eq 0) 'R18ZT publication requires the frozen clean dedicated branch matching its locally recorded origin tip without fetch.'

# The post-freeze tooling gate is intentionally not hash-pinned by the
# invocation that it hashes. Clean local Git equality is the integrity anchor;
# the gate then binds this exact invocation, scripts, scanner, and every named
# pre-invocation P8 artifact without a circular expected hash.
$postFreezeContract = $invocation.postFreezeToolingGate
Require ([string]$postFreezeContract.path -ceq 'work/OPENCV_SCRIBE_R18ZV1_BATCH_PACKAGE_B/R18ZV1_P8_FINAL_TOOL.json') 'R18ZT post-freeze tooling-gate path changed.'
$postFreezeToolingPath = Resolve-DeclaredLocalPath $projectRoot ([string]$postFreezeContract.path) $allowedAbsoluteRoots
Require (Test-Path -LiteralPath $postFreezeToolingPath -PathType Leaf) 'R18ZT post-freeze tooling gate is absent.'
$postFreezeToolingSha256 = Get-Sha256 $postFreezeToolingPath
$postFreezeTooling = Read-JsonFile $postFreezeToolingPath 1048576
Require ([string]$postFreezeTooling.schema -ceq [string]$postFreezeContract.expectedSchema -and
    [string]$postFreezeTooling.state -ceq [string]$postFreezeContract.expectedState -and
    [string]$postFreezeTooling.requestId -ceq 'REQ_RZV1' -and
    [string]$postFreezeTooling.invocationSha256 -ceq $invocationSha256 -and
    [int64]$postFreezeTooling.invocationBytes -eq (Get-Item -LiteralPath $fixedInvocationPath -ErrorAction Stop).Length) 'R18ZT post-freeze tooling gate does not bind this invocation.'
$requiredPostFreezePins = @($postFreezeContract.requiredDependencyPins | ForEach-Object { [string]$_ })
Require ($requiredPostFreezePins.Count -gt 0 -and @($requiredPostFreezePins | Sort-Object -Unique).Count -eq $requiredPostFreezePins.Count) 'R18ZT post-freeze dependency-pin contract is empty or duplicated.'
foreach ($dependencyName in $requiredPostFreezePins) {
    $dependency = Get-ValidatedDependency $dependencyName
    $pinRows = @($postFreezeTooling.dependencyPins | Where-Object { [string]$_.name -ceq $dependencyName })
    Require ($pinRows.Count -eq 1 -and [string]$pinRows[0].path -ceq [string]$dependency.row.path -and
        [int64]$pinRows[0].bytes -eq [int64]$dependency.row.bytes -and
        [string]$pinRows[0].sha256 -ceq [string]$dependency.sha256) "R18ZT post-freeze dependency pin changed: $dependencyName"
}
$wrapperRows = @($postFreezeTooling.wrapperChecks)
$expectedWrapperRoles = @('collector','publisher')
$actualWrapperRoles = @($wrapperRows | ForEach-Object { [string]$_.role } | Sort-Object)
Require ($wrapperRows.Count -eq 2 -and ($actualWrapperRoles -join "`n") -ceq ($expectedWrapperRoles -join "`n")) 'R18ZT post-freeze wrapper role set changed.'
foreach ($wrapperRow in $wrapperRows) {
    $scriptDependency = Get-ValidatedDependency ([string]$wrapperRow.scriptDependency)
    Require ([string]$wrapperRow.state -ceq 'PASS_ARGOS_POWERSHELL_WRAPPER_PREFLIGHT' -and
        [string]$wrapperRow.scriptSha256 -ceq [string]$scriptDependency.sha256 -and
        [string]$wrapperRow.invocationSha256 -ceq $invocationSha256 -and
        [string]$wrapperRow.powerShellEdition -ceq 'Desktop' -and [int]$wrapperRow.powerShellMajor -eq 5 -and
        [int]$wrapperRow.powerShellMinor -eq 1) "R18ZT post-freeze wrapper evidence changed: $($wrapperRow.role)"
}
Require ([bool]$postFreezeTooling.windowsPowerShell51Passed -and [bool]$postFreezeTooling.postFreezeInvocationWrapperChecksPassed -and
    -not [bool]$postFreezeTooling.externalAccessPerformed -and -not [bool]$postFreezeTooling.publicationPerformed) 'R18ZT post-freeze tooling safety state changed.'

$bindingDependency = Get-ValidatedDependency ([string]$invocation.packageBinding.dependency)
$binding = Read-JsonFile ([string]$bindingDependency.path) 2097152
Require ([string]$invocation.packageBinding.expectedSchema -notmatch '_v[12]$' -and [string]$invocation.packageBinding.expectedSchema -notmatch '^PENDING') 'Fresh package binding schema is not finalized or regressed to V1/V2.'
Require ([string]$binding.schema -ceq [string]$invocation.packageBinding.expectedSchema) 'Fresh package binding schema changed.'
Require ([string]$binding.state -ceq [string]$invocation.packageBinding.expectedState -and [string]$binding.requestId -ceq 'REQ_RZV1') 'Fresh package binding identity/state changed.'
Require ([string]$binding.packageRevision -ceq [string]$invocation.packageRevision) 'Fresh package binding revision changed.'
foreach ($forbidden in @($invocation.packageBinding.forbiddenSchemas)) {
    Require ([string]$binding.schema -cne [string]$forbidden) "Withdrawn package binding schema was re-admitted: $forbidden"
}

foreach ($consumer in @($invocation.bindingConsumers)) {
    $consumerDependency = Get-ValidatedDependency ([string]$consumer.dependency)
    $consumerObject = Read-JsonFile ([string]$consumerDependency.path) 4194304
    Require ([string](Get-NestedValue $consumerObject ([string]$consumer.stateProperty) "Binding consumer $($consumer.dependency)") -ceq [string]$consumer.expectedState) "Binding consumer state changed: $($consumer.dependency)"
    Require ([string](Get-NestedValue $consumerObject ([string]$consumer.bindingHashProperty) "Binding consumer $($consumer.dependency)") -ceq [string]$bindingDependency.sha256) "Binding consumer does not bind the fresh package record: $($consumer.dependency)"
    Require ([string](Get-NestedValue $consumerObject ([string]$consumer.requestIdProperty) "Binding consumer $($consumer.dependency)") -ceq 'REQ_RZV1') "Binding consumer request ID changed: $($consumer.dependency)"
}

function Get-GateSemanticContract([string]$Name) {
    $rows = @($invocation.gateSemantics | Where-Object { [string]$_.name -ceq $Name })
    Require ($rows.Count -eq 1) "Missing or duplicated R18ZT gate semantic contract: $Name"
    return $rows[0]
}

function Read-SemanticGate([object]$Contract) {
    $dependency = Get-ValidatedDependency ([string]$Contract.dependency)
    return (Read-JsonFile ([string]$dependency.path) 4194304)
}

$requiredSemanticContracts = @('FINAL_PACKAGE','COMPLETE_ROUTE','PATH_BUDGET','SCIENCE','SIGNED_UNPUBLISHED','PUBLICATION_TOOLING')
Require (@($invocation.gateSemantics).Count -eq $requiredSemanticContracts.Count) 'R18ZT gate semantic contract count changed.'
foreach ($name in $requiredSemanticContracts) { [void](Get-GateSemanticContract $name) }

$requestZipForGates = Get-ValidatedDependency 'requestZip'
$finalPackageContract = Get-GateSemanticContract 'FINAL_PACKAGE'
$finalPackageGate = Read-SemanticGate $finalPackageContract
Require ([string](Get-NestedValue $finalPackageGate ([string]$finalPackageContract.requestZipSha256Property) 'R18ZT final package gate') -ceq [string]$requestZipForGates.sha256 -and
    [int64](Get-NestedValue $finalPackageGate ([string]$finalPackageContract.requestZipBytesProperty) 'R18ZT final package gate') -eq [int64]$requestZipForGates.row.bytes -and
    [bool](Get-NestedValue $finalPackageGate ([string]$finalPackageContract.signatureVerifiedProperty) 'R18ZT final package gate') -and
    -not [bool](Get-NestedValue $finalPackageGate ([string]$finalPackageContract.publishedProperty) 'R18ZT final package gate') -and
    -not [bool](Get-NestedValue $finalPackageGate ([string]$finalPackageContract.completionClaimedProperty) 'R18ZT final package gate') -and
    -not [bool](Get-NestedValue $finalPackageGate ([string]$finalPackageContract.retryAuthorizedProperty) 'R18ZT final package gate')) 'R18ZT final package gate semantic contract changed.'

$routeContract = Get-GateSemanticContract 'COMPLETE_ROUTE'
$routeGate = Read-SemanticGate $routeContract
Require ([string](Get-NestedValue $routeGate ([string]$routeContract.requestZipSha256Property) 'R18ZT route gate') -ceq [string]$requestZipForGates.sha256 -and
    [bool](Get-NestedValue $routeGate ([string]$routeContract.publicationCollisionRecheckProperty) 'R18ZT route gate') -and
    [int](Get-NestedValue $routeGate ([string]$routeContract.maximumEffectiveLengthProperty) 'R18ZT route gate') -lt 200 -and
    [int](Get-NestedValue $routeGate ([string]$routeContract.maximumComponentLengthProperty) 'R18ZT route gate') -le 80 -and
    [int](Get-NestedValue $routeGate ([string]$routeContract.unsafePathCountProperty) 'R18ZT route gate') -eq 0 -and
    -not [bool](Get-NestedValue $routeGate ([string]$routeContract.completionClaimedProperty) 'R18ZT route gate')) 'R18ZT complete route gate semantic contract changed.'

$pathContract = Get-GateSemanticContract 'PATH_BUDGET'
$pathGate = Read-SemanticGate $pathContract
Require ([int](Get-NestedValue $pathGate ([string]$pathContract.maximumEffectiveLengthProperty) 'R18ZT path gate') -lt 200 -and
    [int](Get-NestedValue $pathGate ([string]$pathContract.maximumComponentLengthProperty) 'R18ZT path gate') -le 80 -and
    [int](Get-NestedValue $pathGate ([string]$pathContract.unsafePathCountProperty) 'R18ZT path gate') -eq 0 -and
    [int](Get-NestedValue $pathGate ([string]$pathContract.maximumSuffixReserveProperty) 'R18ZT path gate') -ge 52) 'R18ZT path-budget gate semantic contract changed.'
$routeCoverageProperties = @($pathContract.requiredRouteCoverageProperties | ForEach-Object { [string]$_ })
Require ($routeCoverageProperties.Count -eq 13) 'R18ZT required route-coverage property count changed.'
foreach ($property in $routeCoverageProperties) {
    Require ([bool](Get-NestedValue $pathGate $property 'R18ZT path gate route coverage')) "R18ZT required route coverage is absent: $property"
}

$scienceContract = Get-GateSemanticContract 'SCIENCE'
$scienceGate = Read-SemanticGate $scienceContract
Require ([string](Get-NestedValue $scienceGate ([string]$scienceContract.imageFirstStringProperty) 'R18ZT science gate') -ceq '13HFX135SUE3' -and
    [bool](Get-NestedValue $scienceGate ([string]$scienceContract.exactFinishPassedProperty) 'R18ZT science gate') -and
    [int](Get-NestedValue $scienceGate ([string]$scienceContract.wrongAcceptedCountProperty) 'R18ZT science gate') -eq 0 -and
    -not [bool](Get-NestedValue $scienceGate ([string]$scienceContract.providerRerunProperty) 'R18ZT science gate')) 'R18ZT science gate semantic contract changed.'
$scienceAdjudicationRows = @($scienceGate.artifacts | Where-Object { [string]$_.name -ceq 'r18zv1Slot21CompactGate' })
Require ($scienceAdjudicationRows.Count -eq 1 -and
    [string]$scienceAdjudicationRows[0].sha256 -ceq '114F3A7B4D2E66FC8B730BD8572B083073FFB68FEEC6111F215DB3623AEB8442') 'R18ZV1 science pin changed.'
Require ([string]$scienceGate.heldOutZImageFirstString -ceq '147Z6157SUA5' -and
    [string]$scienceGate.heldOutZPosition4 -ceq 'Z' -and
    [bool]$scienceGate.heldOutZCanonicalGeometryPassed -and
    [int]$scienceGate.r18zuRealNonZFalseAcceptances -eq 0 -and
    [int]$scienceGate.r18zuRenderedNonZFalseAcceptances -eq 0 -and [int]$scienceGate.developmentAcceptedCorrect -eq 312 -and
    [int]$scienceGate.developmentAcceptedWrong -eq 0 -and [int]$scienceGate.developmentHeld -eq 163 -and -not [bool]$scienceGate.newSingleTargetImageFirstGain -and
    -not [bool]$scienceGate.strictEightRetainedHypothesisQualificationSatisfied -and
    -not [bool]$scienceGate.overallProviderQualificationClaimed -and
    -not [bool]$scienceGate.identityAccepted) 'R18ZU package science gate changed.'

$signedContract = Get-GateSemanticContract 'SIGNED_UNPUBLISHED'
$signedGate = Read-SemanticGate $signedContract
Require ([string](Get-NestedValue $signedGate ([string]$signedContract.requestZipSha256Property) 'R18ZT signed-unpublished gate') -ceq [string]$requestZipForGates.sha256 -and
    [bool](Get-NestedValue $signedGate ([string]$signedContract.signatureVerifiedProperty) 'R18ZT signed-unpublished gate') -and
    -not [bool](Get-NestedValue $signedGate ([string]$signedContract.publishedProperty) 'R18ZT signed-unpublished gate') -and
    -not [bool](Get-NestedValue $signedGate ([string]$signedContract.completionClaimedProperty) 'R18ZT signed-unpublished gate') -and
    -not [bool](Get-NestedValue $signedGate ([string]$signedContract.retryAuthorizedProperty) 'R18ZT signed-unpublished gate')) 'R18ZT signed-unpublished gate semantic contract changed.'

$toolingContract = Get-GateSemanticContract 'PUBLICATION_TOOLING'
$toolingGate = Read-SemanticGate $toolingContract
Require ([string](Get-NestedValue $toolingGate ([string]$toolingContract.publisherSha256Property) 'R18ZT publication tooling gate') -ceq $selfSha256 -and
    [string](Get-NestedValue $toolingGate ([string]$toolingContract.collectorSha256Property) 'R18ZT publication tooling gate') -ceq [string]$collectorDependency.sha256 -and
    [bool](Get-NestedValue $toolingGate ([string]$toolingContract.windowsPowerShell51PassedProperty) 'R18ZT publication tooling gate') -and
    [bool](Get-NestedValue $toolingGate ([string]$toolingContract.cloneGatesPassedProperty) 'R18ZT publication tooling gate') -and
    [bool](Get-NestedValue $toolingGate ([string]$toolingContract.harnessGatesPassedProperty) 'R18ZT publication tooling gate') -and
    [bool](Get-NestedValue $toolingGate ([string]$toolingContract.preactionCycleAbsentProperty) 'R18ZT publication tooling gate')) 'R18ZT publication tooling gate semantic contract changed.'

$currentResultDependency = Get-ValidatedDependency 'r18zv1Slot21Result'
$currentResult = Read-JsonFile ([string]$currentResultDependency.path) 2097152
Require ([string]$currentResult.state -ceq 'SCRIBE_M12_AMBIGUOUS_MULTIPLE_VALID' -and [string]$currentResult.imageFirstString -ceq '13HFX135SUE3' -and [string]$currentResult.selectedHypothesis.channel -ceq 'BF' -and [string]$currentResult.selectedHypothesis.polarity -ceq 'DARK' -and [string]$currentResult.selectedHypothesis.direction -ceq 'FORWARD' -and [decimal]$currentResult.selectedHypothesis.selectionScore -eq [decimal]::Parse('0.9117836040446633',[Globalization.CultureInfo]::InvariantCulture) -and [bool]$currentResult.selectedHypothesis.envelopePassed -and @($currentResult.selectedHypothesis.heldPositions).Count -eq 0) 'R18ZV1 Slot21 result changed.'
Require (@($currentResult.holds).Count -eq 1 -and [string]$currentResult.holds[0].code -ceq 'SCRIBE_REFERENCE_COVERAGE_HOLD' -and -not [bool]$currentResult.eligibleIdentity -and [string]$currentResult.ambiguityResolution.state -ceq 'PASS_REVIEW_ONLY_IMAGE_FIRST_SCRIBE') 'R18ZV1 hold boundary changed.'
$currentGateDependency = Get-ValidatedDependency 'r18zv1Slot21CompactGate'
$currentGate = Read-JsonFile ([string]$currentGateDependency.path) 1048576
$currentAttemptOrder = @($currentGate.fullChain.attempts|ForEach-Object{([string]$_.channel)+'|'+([string]$_.polarity)+'|'+([string]$_.direction)})
Require ([string]$currentGate.state -ceq 'PASS_R18ZV1_SLOT21_EXACT_IMAGE_FIRST_DIAGNOSTIC' -and [bool]$currentGate.fullChain.allEightNormalViewsPresent -and [int]$currentGate.fullChain.attemptCount -eq 8 -and [int]$currentGate.fullChain.analyzeImagesCallCount -eq 1 -and [int]$currentGate.fullChain.directStructuralEvaluatorCallsByHarness -eq 0 -and [int]$currentGate.providerRunCount -eq 1 -and [bool]$currentGate.fullChain.orderedAttemptKeysExact -and [string]$currentGate.fullChain.publicEntryPoint -ceq 'run_job' -and ($currentAttemptOrder -join [Environment]::NewLine) -ceq (@('BF|DARK|FORWARD','BF|DARK|REVERSE_180','BF|BRIGHT|FORWARD','BF|BRIGHT|REVERSE_180','DF|DARK|FORWARD','DF|DARK|REVERSE_180','DF|BRIGHT|FORWARD','DF|BRIGHT|REVERSE_180') -join [Environment]::NewLine) -and -not [bool]$currentGate.wrongAccepted) 'R18ZV1 full chain changed.'
Require ([bool]$currentGate.runtimeRestoration.analyze -and [bool]$currentGate.runtimeRestoration.apply -and [bool]$currentGate.runtimeRestoration.enforce -and [bool]$currentGate.runtimeRestoration.evaluate -and [bool]$currentGate.runtimeRestoration.loader -and [bool]$currentGate.runtimeRestoration.revision -and [bool]$currentGate.runtimeRestoration.validate -and [bool]$currentGate.runtimeRestoration.sharedLockAvailable -and [bool]$currentGate.runtimeRestoration.wrapperLockAvailable -and -not [bool]$currentGate.authority.identityAccepted -and -not [bool]$currentGate.authority.productionAuthorized) 'R18ZV1 restoration/authority changed.'
$currentCorrectionDependency = Get-ValidatedDependency 'r18zv1Slot21CorrectionGate'
$currentCorrection = Read-JsonFile ([string]$currentCorrectionDependency.path) 1048576
$currentJobDependency = Get-ValidatedDependency 'r18zv1Slot21Job'
Require ([string]$currentCorrection.state -ceq 'PASS_CORRECTION_A_FIRST_COMPLETED_B_DUPLICATE_EXCLUDED_SCIENCE_UNCHANGED' -and [string]$currentCorrection.authoritativeFirstCompletion.job.sha256 -ceq [string]$currentJobDependency.sha256 -and [string]$currentCorrection.authoritativeFirstCompletion.result.sha256 -ceq [string]$currentResultDependency.sha256 -and [string]$currentCorrection.authoritativeFirstCompletion.compactGate.sha256 -ceq [string]$currentGateDependency.sha256 -and [int]$currentCorrection.authoritativeFirstCompletion.providerRunCount -eq 1 -and [int]$currentCorrection.authoritativeFirstCompletion.attemptCount -eq 8 -and [bool]$currentCorrection.authoritativeFirstCompletion.exact -and -not [bool]$currentCorrection.correctedOutcome.newSingleTargetImageFirstGain -and -not [bool]$currentCorrection.authority.productionAuthorized) 'R18ZV1 correction changed.'
$currentDevelopmentDependency = Get-ValidatedDependency 'r18zv1DevelopmentFreeze'
$currentDevelopment = Read-JsonFile ([string]$currentDevelopmentDependency.path) 1048576
Require ([string]$currentDevelopment.state -ceq 'PASS_R18ZV1_TARGET_EXCLUDED_GENERIC_BOUNDARY_FROZEN_BEFORE_BATCH_VALIDATION' -and [int]$currentDevelopment.developmentPartition.referenceQueryCount -eq 475 -and [int]$currentDevelopment.developmentPartition.exactLineageFoldCount -eq 49 -and [decimal]$currentDevelopment.boundaryDerivation.frozenMaximumNormalizedDistance -eq [decimal]::Parse('0.83',[Globalization.CultureInfo]::InvariantCulture) -and [int]$currentDevelopment.developmentOutcomeAtFrozenBoundary.r18ztAcceptedCorrect -eq 312 -and [int]$currentDevelopment.developmentOutcomeAtFrozenBoundary.r18ztAcceptedWrong -eq 0 -and [int]$currentDevelopment.developmentOutcomeAtFrozenBoundary.r18ztHeld -eq 163 -and -not [bool]$currentDevelopment.runtimeRule.sparseOrUnobservedAdmissionAdded -and -not [bool]$currentDevelopment.runtimeRule.newLabelSpecificRule -and -not [bool]$currentDevelopment.authority.productionAuthorized) 'R18ZV1 development changed.'
foreach($name in @('provider','r18zv1DevelopmentFreeze','r18zv1Slot21Job','r18zv1Slot21Result','r18zv1Slot21CompactGate','r18zv1Slot21CorrectionGate')){$d=Get-ValidatedDependency $name;$br=@($binding.artifacts|Where-Object name -ceq $name);$sr=@($scienceGate.artifacts|Where-Object name -ceq $name);Require($br.Count -eq 1 -and $sr.Count -eq 1 -and [string]$br[0].sha256 -ceq [string]$d.sha256 -and [string]$sr[0].sha256 -ceq [string]$d.sha256) "R18ZV1 pin changed: $name"}

$adjudicationDependency = Get-ValidatedDependency 'slot21Adjudication'
$adjudication = Read-JsonFile ([string]$adjudicationDependency.path) 1048576
Require ([string]$adjudication.state -ceq 'PASS_R18ZT_SLOT21_EXACT_DECIPHERING_FINISH_POST_RESULT_ADJUDICATION' -and [string]$adjudication.decipheringFinish.imageFirstString -ceq '13HFX135SUE3' -and [bool]$adjudication.decipheringFinish.exact -and [int]$adjudication.decipheringFinish.wrongImageFirstAcceptedCount -eq 0 -and [int]$adjudication.executedRun.providerRunCount -eq 1 -and [int]$adjudication.executedRun.attemptCount -eq 8 -and -not [bool]$adjudication.invariants.truthOrChecksumUsedForSelection -and -not [bool]$adjudication.authority.publicationSelfAuthority -and @($adjudication.holdsAndAuthority.resultHoldsPreserved).Count -eq 1 -and [string]$adjudication.holdsAndAuthority.resultHoldsPreserved[0].code -ceq 'SCRIBE_REFERENCE_COVERAGE_HOLD') 'R18ZT inherited Slot21 evidence changed.'
$developmentGateDependency = Get-ValidatedDependency 'developmentGate'
$developmentGate = Read-JsonFile ([string]$developmentGateDependency.path) 1048576
Require ([string]$developmentGate.state -ceq 'PASS_R18ZT_GENERIC_HOLD_RESCUE_FROZEN_BEFORE_VALIDATION' -and [int]$developmentGate.leaveOneExactScribeLineageOut.referenceQueries -eq 475 -and [int]$developmentGate.leaveOneExactScribeLineageOut.exactFoldCount -eq 49 -and [int]$developmentGate.leaveOneExactScribeLineageOut.acceptedCorrect -eq 312 -and [int]$developmentGate.leaveOneExactScribeLineageOut.acceptedWrong -eq 0 -and [int]$developmentGate.leaveOneExactScribeLineageOut.held -eq 163 -and [bool]$developmentGate.criteria.k25vDiagnosticHoldPreserved -and [bool]$developmentGate.criteria.k25vWrongPositions2And4NotRescued -and -not [bool]$developmentGate.criteria.resultAuthorityExpanded -and -not [bool]$developmentGate.invariants.checksumUsedForSelectionOrAcceptance) 'R18ZT inherited regression changed.'
$r18zuScienceDependency = Get-ValidatedDependency 'r18zuReviewBatchScienceGate'
$r18zuScience = Read-JsonFile ([string]$r18zuScienceDependency.path) 1048576
Require ([string]$r18zuScience.state -ceq 'PASS_R18ZU_REVIEW_BATCH_SCIENCE_WITH_STRICT_RETENTION_HOLD' -and [string]$r18zuScience.decipheringFinish.slot21.imageFirstString -ceq '13HFX135SUE3' -and [string]$r18zuScience.decipheringFinish.heldOutZ.imageFirstString -ceq '147Z6157SUA5' -and [string]$r18zuScience.decipheringFinish.heldOutZ.position4 -ceq 'Z' -and [bool]$r18zuScience.decipheringFinish.heldOutZ.canonicalGeometryPassed -and [int]$r18zuScience.boundedRegression.acceptedWrong -eq 0 -and [int]$r18zuScience.boundedRegression.r18zuRealNonZFalseAcceptances -eq 0 -and [int]$r18zuScience.boundedRegression.r18zuRenderedNonZFalseAcceptances -eq 0 -and -not [bool]$r18zuScience.adjudication.strictEightRetainedHypothesisQualificationSatisfied -and -not [bool]$r18zuScience.adjudication.overallProviderQualificationClaimed -and -not [bool]$r18zuScience.adjudication.productionAuthorized) 'R18ZU inherited science changed.'
foreach ($pin in @(
    [pscustomobject]@{dependency='batchRunner';artifact='batchRunner';scienceField='batchRunner'},
    [pscustomobject]@{dependency='r18zuProvider';artifact='r18zuProvider';scienceField='provider'},
    [pscustomobject]@{dependency='runnerNonImageTestGate';artifact='runnerNonImageTestGate';scienceField='batchRunnerTestGate'},
    [pscustomobject]@{dependency='canonicalZDevelopmentGate';artifact='canonicalZDevelopmentGate';scienceField='canonicalZDevelopmentGate'},
    [pscustomobject]@{dependency='r18zuNonImageRegressionGate';artifact='r18zuNonImageRegressionGate';scienceField='nonImageRegressionGate'},
    [pscustomobject]@{dependency='heldOutZDiagnosticGate';artifact='heldOutZDiagnosticGate';scienceField='heldOutZDiagnosticGate'}
)) {
    $dependency = Get-ValidatedDependency ([string]$pin.dependency)
    $bindingRows = @($binding.artifacts | Where-Object { [string]$_.name -ceq [string]$pin.artifact })
    $sciencePin = $r18zuScience.artifacts.([string]$pin.scienceField)
    Require ($bindingRows.Count -eq 1 -and [string]$bindingRows[0].sha256 -ceq [string]$dependency.sha256 -and [string]$sciencePin.sha256 -ceq [string]$dependency.sha256) "R18ZU pin changed: $($pin.dependency)"
}

$preactionDependency = Get-ValidatedDependency ([string]$invocation.preaction.contractDependency)
$preaction = Read-JsonFile ([string]$preactionDependency.path) 1048576
$selfRows = New-Object Collections.Generic.List[object]
foreach ($row in @($preaction.dependencies)) {
    $resolved = Resolve-DeclaredLocalPath $projectRoot ([string]$row.path) $allowedAbsoluteRoots
    Require (-not $resolved.Equals($fixedInvocationPath, [StringComparison]::OrdinalIgnoreCase)) 'Preaction must not pin the invocation file; that would create a hash cycle.'
    if ($resolved.Equals($selfPath, [StringComparison]::OrdinalIgnoreCase)) { $selfRows.Add($row) }
}
Require ($selfRows.Count -eq 1 -and [string]$selfRows[0].sha256 -ceq $selfSha256) 'Preaction does not directly pin this publisher runtime hash.'
$preactionToolDependency = Get-ValidatedDependency ([string]$invocation.preaction.toolDependency)
$historyDependency = Get-ValidatedDependency ([string]$invocation.preaction.historyDependency)
$preactionText = (& ([string]$preactionToolDependency.path) -AuditPath ([string]$historyDependency.path) -ContractPath ([string]$preactionDependency.path) -ProjectRoot $projectRoot -Preflight | Out-String)
$preactionResult = $preactionText | ConvertFrom-Json
Require ([string]$preactionResult.state -ceq 'PASS_ARGOS_ZERO_RECURRENCE_PREACTION') 'R18ZT publication preaction failed.'

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$requestZipDependency = Get-ValidatedDependency 'requestZip'
$requestZipPath = [string]$requestZipDependency.path
$requestZipBytes = [int64](Get-Item -LiteralPath $requestZipPath).Length
Require ($requestZipBytes -le [int64]$invocation.signedRequest.maximumZipBytes) 'R18ZT signed request ZIP exceeds the frozen byte cap.'
$zip = [IO.Compression.ZipFile]::OpenRead($requestZipPath)
try {
    Require ($zip.Entries.Count -le [int]$invocation.signedRequest.maximumEntryCount) 'R18ZT signed request ZIP exceeds the frozen entry cap.'
    $normalizedNames = @($zip.Entries | ForEach-Object { ([string]$_.FullName).Replace('\', '/') })
    Require (@($normalizedNames | Sort-Object -Unique).Count -eq $normalizedNames.Count) 'R18ZT signed request ZIP has duplicate members.'
    foreach ($name in $normalizedNames) {
        Require (-not [string]::IsNullOrWhiteSpace($name) -and -not [IO.Path]::IsPathRooted($name) -and $name -notmatch '(^|/)\.\.(/|$)') "Unsafe R18ZT ZIP member: $name"
    }
    $manifestBytes = Read-ZipEntryBytes $zip 'PORTAL_REQUEST_MANIFEST.json' 1048576
    $signatureBytes = Read-ZipEntryBytes $zip 'PORTAL_REQUEST_MANIFEST.sig' 8192
    $manifest = (New-Object Text.UTF8Encoding($false, $true)).GetString($manifestBytes) | ConvertFrom-Json
    $signerDependency = Get-ValidatedDependency 'requestSignerCertificate'
    $certificate = New-Object Security.Cryptography.X509Certificates.X509Certificate2([string]$signerDependency.path)
    $rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPublicKey($certificate)
    Require ($null -ne $rsa) 'R18ZT request signer certificate has no RSA key.'
    try { $signatureValid = $rsa.VerifyData($manifestBytes, $signatureBytes, [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1) }
    finally { $rsa.Dispose() }
    Require $signatureValid 'R18ZT signed request signature verification failed.'
    Require ([string]$manifest.schema -ceq 'argos_project_portal_request_manifest_v1' -and [string]$manifest.requestId -ceq 'REQ_RZV1' -and
        [string]$manifest.targetRole -ceq 'JBOD' -and [string]$manifest.jobClass -ceq 'MAINTENANCE_PATCH') 'R18ZT signed request identity changed.'
    Require ([string]$manifest.signatureAlgorithm -ceq 'RSA-SHA256-PKCS1' -and
        ([string]$manifest.signerThumbprint).Replace(' ', '').ToUpperInvariant() -ceq $certificate.Thumbprint.ToUpperInvariant()) 'R18ZT signed request signer changed.'
    Require ([DateTimeOffset]::UtcNow -lt [DateTimeOffset]::Parse([string]$manifest.expiresUtc)) 'R18ZT signed request is expired; publication refused.'
    Require ([bool]$manifest.reviewOnly -and -not [bool]$manifest.trainingEligible -and -not [bool]$manifest.xmlEligible -and
        -not [bool]$manifest.productionEligible -and -not [bool]$manifest.productionRoutingEnabled -and -not [bool]$manifest.credentialsIncluded) 'R18ZT signed request authority widened.'
    Require ([bool]$manifest.timeoutContract.corpusWorkerPersistsAfterPortalResponse -and
        [bool]$manifest.timeoutContract.corpusCompletionNotRequiredForLaunchResponse -and
        [bool]$manifest.timeoutContract.portalResponseProvesLaunchOnly -and -not [bool]$manifest.rehearsal.completionClaimed) 'R18ZT signed request launch-only contract changed.'
    Require (@($manifest.allowedTaskActions).Count -eq 0 -and @($manifest.allowedProcessActions).Count -eq 1 -and
        [string]$manifest.allowedProcessActions[0] -ceq 'START_ONE_OWNED_BACKGROUND_R18ZT_BATCH_WORKER') 'R18ZT signed request action set changed.'
    Require (@($manifest.changes).Count -eq 1) 'R18ZT signed request must contain exactly one installed-file declaration.'
    $change = $manifest.changes[0]
    $expectedChangeFields = @('allowCreate','approvedPredecessorSha256','destination','installedSha256','source')
    $actualChangeFields = @($change.PSObject.Properties.Name | Sort-Object)
    Require ($actualChangeFields.Count -eq $expectedChangeFields.Count -and ($actualChangeFields -join "`n") -ceq ($expectedChangeFields -join "`n")) 'R18ZT signed request installed launcher declaration field set changed.'
    $launcherDependency = Get-ValidatedDependency ([string]$invocation.signedRequest.change.launcherDependency)
    Require ([string]$change.source -ceq 'payload/Invoke-R18ZTBatchLaunch.ps1' -and
        [string]$change.destination -ceq 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV02_R18ZV1.ps1' -and
        [string]$change.source -ceq [string]$invocation.signedRequest.change.source -and
        [string]$change.destination -ceq [string]$invocation.signedRequest.change.destination -and
        [string]$change.installedSha256 -ceq [string]$launcherDependency.sha256 -and
        [string]$change.installedSha256 -ceq [string]$invocation.signedRequest.change.installedSha256 -and
        $change.allowCreate -is [bool] -and [bool]$change.allowCreate -and [bool]$invocation.signedRequest.change.allowCreate) 'R18ZT signed request installed launcher declaration changed.'
    $expectedPredecessors = @($invocation.signedRequest.change.approvedPredecessorSha256 | Sort-Object)
    $actualPredecessors = @($change.approvedPredecessorSha256 | Sort-Object)
    Require ($expectedPredecessors.Count -ge 1 -and $expectedPredecessors.Count -eq $actualPredecessors.Count -and
        @($expectedPredecessors | Where-Object { [string]$_ -cnotmatch '^[A-F0-9]{64}$' }).Count -eq 0 -and
        ($expectedPredecessors -join "`n") -ceq ($actualPredecessors -join "`n")) 'R18ZT signed request predecessor set changed.'

    $payloadNames = @($normalizedNames | Where-Object { $_ -cne 'PORTAL_REQUEST_MANIFEST.json' -and $_ -cne 'PORTAL_REQUEST_MANIFEST.sig' })
    $records = @($manifest.files)
    Require ($records.Count -eq $payloadNames.Count) 'R18ZT signed request payload membership count changed.'
    $seen = @{}
    foreach ($record in $records) {
        $relative = [string]$record.path
        Require (-not $seen.ContainsKey($relative)) "Duplicate signed request payload record: $relative"
        $seen[$relative] = $true
        $entryMatches = @($zip.Entries | Where-Object { ([string]$_.FullName).Replace('\', '/') -ceq $relative })
        Require ($entryMatches.Count -eq 1 -and [int64]$entryMatches[0].Length -eq [int64]$record.bytes -and
            (Get-ZipEntrySha256 $entryMatches[0]) -ceq [string]$record.sha256) "R18ZT signed request payload changed: $relative"
    }
}
finally { $zip.Dispose() }

$priorTerminalDependency = Get-ValidatedDependency 'priorRequestTerminalRouteGate'
$priorTerminal = Read-JsonFile ([string]$priorTerminalDependency.path) 1048576
Require ([string]$priorTerminal.state -ceq 'PASS_R18ZU1_ENDPOINT_REQUEST_TERMINAL_SIGNED_RETURN_AUTHENTICATED' -and
    [string]$priorTerminal.priorRequestId -ceq 'REQ_R18ZU1' -and [string]$priorTerminal.result.state -ceq 'PASS_MAINTENANCE_PATCH' -and
    [bool]$priorTerminal.observation.signedResponseVerified -and [bool]$priorTerminal.conclusion.priorEndpointRequestTerminal -and
    [bool]$priorTerminal.conclusion.signedTerminalResponseReturnedToShare -and [bool]$priorTerminal.conclusion.returnRouteHealthy -and
    -not [bool]$priorTerminal.externalMutationPerformed -and -not [bool]$priorTerminal.imageBytesRead) 'R18ZU1 terminal route is not healthy.'

$shareRoot = [string]$invocation.route.shareRoot
$requestRoot = [string]$invocation.route.requestRoot
$responseRoot = [string]$invocation.route.responseRoot
$readyPath = [string]$invocation.route.readyPath
$uploadPath = [string]$invocation.route.uploadPath
$processedPath = [string]$invocation.route.processedPath
$publishGatePath = Resolve-DeclaredLocalPath $projectRoot ([string]$invocation.outputs.publishGatePath) $allowedAbsoluteRoots
$publishGatePartialPath = Resolve-DeclaredLocalPath $projectRoot ([string]$invocation.outputs.publishGatePartialPath) $allowedAbsoluteRoots
$applyIntentPath = Resolve-DeclaredLocalPath $projectRoot ([string]$invocation.outputs.applyIntentPath) $allowedAbsoluteRoots
Require ([string]$invocation.route.shareRoot -ceq '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs') 'R18ZT share root declaration changed.'
Require ($requestRoot -ceq 'U:\ProjectPortalRO\requests' -and $responseRoot -ceq 'U:\ProjectPortalRO\responses' -and
    $readyPath -ceq 'U:\ProjectPortalRO\requests\REQ_RZV1.ready.zip' -and $uploadPath -ceq 'U:\ProjectPortalRO\requests\REQ_RZV1.ready.zip.upload' -and
    $processedPath -ceq 'U:\ProjectPortalRO\requests\processed\REQ_RZV1.ready.zip') 'R18ZT exact publication route changed.'
Require (-not (Test-Path -LiteralPath $publishGatePath)) 'R18ZT V8 publication gate already exists; republish refused.'
Require (-not (Test-Path -LiteralPath $publishGatePartialPath)) 'R18ZT V8 publication gate partial already exists; repeat publication refused.'
Require (-not (Test-Path -LiteralPath $applyIntentPath)) 'R18ZT V8 apply intent already exists; repeat publication refused.'
$drive = Get-PSDrive -Name U -PSProvider FileSystem -ErrorAction Stop
$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='U:'" -ErrorAction Stop
Require ([string]$drive.DisplayRoot -ceq $shareRoot -and [string]$disk.ProviderName -ceq $shareRoot -and [int]$disk.DriveType -eq 4) 'R18ZT persistent U: mapping changed.'
Require (Test-Path -LiteralPath $requestRoot -PathType Container) 'R18ZT portal request root is unavailable.'
Require (Test-Path -LiteralPath $responseRoot -PathType Container) 'R18ZT portal response root is unavailable.'
Require (-not (Test-Path -LiteralPath $uploadPath) -and -not (Test-Path -LiteralPath $readyPath) -and -not (Test-Path -LiteralPath $processedPath)) 'R18ZT request identity already exists in the live route.'
$pending = @([IO.Directory]::EnumerateFiles($requestRoot, '*.ready.zip', [IO.SearchOption]::TopDirectoryOnly) | Select-Object -First 2)
$pendingUploads = @([IO.Directory]::EnumerateFiles($requestRoot, '*.ready.zip.upload', [IO.SearchOption]::TopDirectoryOnly) | Select-Object -First 2)
Require ($pending.Count -eq 0 -and $pendingUploads.Count -eq 0) 'Another portal request is pending; R18ZT publication refused.'

# Apply snapshots and re-hashes the already validated local source before the
# collision scan so that the scan can be the literal final read before write.
$publicationBytes = $null
if ($Apply) {
    $publicationBytes = [IO.File]::ReadAllBytes($requestZipPath)
    Require ([int64]$publicationBytes.Length -eq $requestZipBytes -and (Get-BytesSha256 $publicationBytes) -ceq [string]$requestZipDependency.sha256) 'R18ZT local request ZIP changed before the publication collision scan.'
}

$applyIntent = [ordered]@{
    schema = 'argos_opencv_scribe_r18zv1_publication_apply_intent_v1'
    createdUtc = [DateTimeOffset]::UtcNow.ToString('o')
    state = 'FROZEN_R18ZV1_APPLY_INTENT_BEFORE_EXTERNAL_WRITE'
    requestId = 'REQ_RZV1'
    invocationManifestSha256 = $invocationSha256
    postFreezeToolingGatePath = [string]$postFreezeContract.path
    postFreezeToolingGateSha256 = $postFreezeToolingSha256
    publisherSha256 = $selfSha256
    collectorSha256 = [string]$collectorDependency.sha256
    requestZipBytes = $requestZipBytes
    requestZipSha256 = [string]$requestZipDependency.sha256
    uploadPath = $uploadPath
    readyPath = $readyPath
    processedPath = $processedPath
    publishGatePath = [string]$invocation.outputs.publishGatePath
    publishGatePartialPath = [string]$invocation.outputs.publishGatePartialPath
    maximumPublications = 1
    retryAuthorized = $false
    externalWritePerformedAtCreation = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
}
$applyIntentSha256 = $null
if ($Apply) {
    Write-JsonCreateNew $applyIntentPath $applyIntent
    $applyIntentSha256 = Get-Sha256 $applyIntentPath
}

# Apply performs the fresh all-accessible-namespace scan immediately before the
# first external write. The scanner deliberately creates one fresh local gate;
# preflight only validates its exact namespace plan and performs no scan/write.
$collisionScannerDependency = Get-ValidatedDependency ([string]$invocation.collision.scannerDependency)
$publicationCollisionGatePath = Resolve-DeclaredLocalPath $projectRoot ([string]$invocation.collision.gateOutputPath) $allowedAbsoluteRoots
$publicationCollisionGatePartialPath = Resolve-DeclaredLocalPath $projectRoot ([string]$invocation.collision.gatePartialPath) $allowedAbsoluteRoots
Require ($publicationCollisionGatePartialPath.Equals($publicationCollisionGatePath + '.partial', [StringComparison]::OrdinalIgnoreCase)) 'R18ZT publication collision-gate partial path changed.'
Require (-not (Test-Path -LiteralPath $publicationCollisionGatePath) -and
    -not (Test-Path -LiteralPath $publicationCollisionGatePartialPath)) 'R18ZT publication collision gate or retained partial already exists; repeat publication refused.'
$scanStarted = [DateTimeOffset]::UtcNow
$collisionText = if ($Preflight) {
    (& ([string]$collisionScannerDependency.path) -Preflight | Out-String)
}
else {
    (& ([string]$collisionScannerDependency.path) -Gate -OutputPath $publicationCollisionGatePath | Out-String)
}
$scanFinished = [DateTimeOffset]::UtcNow
$collisionBytes = (New-Object Text.UTF8Encoding($false)).GetBytes($collisionText)
Require ($collisionBytes.Length -le [int]$invocation.collision.maximumStdoutBytes) 'R18ZT collision scan stdout exceeded the frozen cap.'
$collision = $collisionText | ConvertFrom-Json
Require ([string]$collision.requestId -ceq 'REQ_RZV1' -and
    [string]$collision.bindingRecordSha256 -ceq [string]$bindingDependency.sha256 -and
    [string]$collision.scannerSha256 -ceq [string]$collisionScannerDependency.sha256) 'R18ZT collision scanner identity/binding changed.'
$requiredNamespaceIds = @($invocation.collision.requiredNamespaceIds | ForEach-Object { [string]$_ })
$optionalNamespaceIds = @($invocation.collision.optionalNamespaceIds | ForEach-Object { [string]$_ })
$expectedNamespaceIds = @($requiredNamespaceIds + $optionalNamespaceIds | Sort-Object)
$namespaceRows = @($collision.namespaces)
$actualNamespaceIds = @($namespaceRows | ForEach-Object { [string]$_.id } | Sort-Object)
Require ($requiredNamespaceIds.Count -eq 2 -and $optionalNamespaceIds.Count -eq 7 -and $namespaceRows.Count -eq 9 -and
    ($actualNamespaceIds -join "`n") -ceq ($expectedNamespaceIds -join "`n")) 'R18ZT collision namespace contract changed.'
foreach ($namespaceId in $requiredNamespaceIds) {
    $matches = @($namespaceRows | Where-Object { [string]$_.id -ceq $namespaceId })
    Require ($matches.Count -eq 1 -and [bool]$matches[0].available) "R18ZT required collision namespace is unavailable: $namespaceId"
}
if ($Preflight) {
    Require ([string]$collision.schema -ceq [string]$invocation.collision.expectedPreflightSchema -and
        [string]$collision.state -ceq [string]$invocation.collision.expectedPreflightState -and
        [bool]$collision.zipJsonSelectionIncludesRequestManifest -and
        [bool]$collision.zipJsonSelectionIncludesResponseManifest -and
        [bool]$collision.zipJsonSelectionIncludesResultPayload -and
        -not [bool]$collision.imageMembersRead -and
        -not [bool]$collision.localGateMutationPerformed -and
        -not [bool]$collision.externalMutationsPerformed -and
        -not [bool]$collision.mutationsPerformed) 'R18ZT collision scanner preflight changed.'
}
else {
    Require ([string]$collision.schema -ceq [string]$invocation.collision.expectedGateSchema -and
        [string]$collision.state -ceq [string]$invocation.collision.expectedGateState -and
        [int]$collision.namespaceCount -eq 9 -and [int]$collision.collisionCount -eq 0 -and
        [bool]$collision.requestUploadProcessedAndArchiveScanned -and [bool]$collision.responseArchiveScanned -and
        [bool]$collision.endpointLedgerNamespaceChecked -and [bool]$collision.allAccessibleNamespacesScanned -and
        [int]$collision.zipMetadataJsonMemberReadCount -ge 0 -and [int]$collision.zipPayloadJsonMemberReadCount -ge 0 -and
        [int]$collision.imageMemberReadCount -eq 0 -and
        [bool]$collision.zipPayloadMembersRead -eq ([int]$collision.zipPayloadJsonMemberReadCount -gt 0) -and
        -not [bool]$collision.imageMembersRead -and
        [bool]$collision.zipPayloadOrImageMembersRead -eq [bool]$collision.zipPayloadMembersRead -and
        [int]$collision.scanErrorCount -eq 0 -and [int]$collision.maximumRecordedErrors -eq 32 -and
        [int]$collision.pendingReadyCount -eq 0 -and [int]$collision.pendingUploadCount -eq 0 -and
        [bool]$collision.noOtherPendingRequests -and @($collision.pendingCheckExcludedRequestIds).Count -eq 0 -and
        @($collision.queueTaskProcessActions).Count -eq 0 -and
        [bool]$collision.localGateMutationPerformed -and -not [bool]$collision.externalMutationsPerformed -and
        [bool]$collision.mutationsPerformed) 'R18ZT fresh collision scan did not prove zero collisions in all accessible namespaces.'
    foreach ($row in $namespaceRows) {
        Require ((-not [bool]$row.available) -or [int]$row.errors -eq 0) "R18ZT accessible collision namespace scan failed: $($row.id)"
    }
    Require ((Test-Path -LiteralPath $publicationCollisionGatePath -PathType Leaf) -and
        -not (Test-Path -LiteralPath $publicationCollisionGatePartialPath)) 'R18ZT publication collision gate was not atomically committed or retained its partial.'
    $checkedUtc = [DateTimeOffset]::Parse([string]$collision.checkedUtc)
    Require ($checkedUtc -ge $scanStarted.AddSeconds(-[int]$invocation.collision.clockSkewAllowanceSeconds) -and
        $checkedUtc -le $scanFinished.AddSeconds([int]$invocation.collision.clockSkewAllowanceSeconds) -and
        ($scanFinished - $scanStarted).TotalSeconds -le [int]$invocation.collision.maximumDurationSeconds -and
        ([DateTimeOffset]::UtcNow - $checkedUtc).TotalSeconds -le [int]$invocation.collision.maximumAgeSeconds) 'R18ZT collision scan is not fresh enough for publication.'
}
$collisionEvidenceSha256 = Get-BytesSha256 $collisionBytes

$result = [ordered]@{
    schema = 'argos_opencv_scribe_r18zv1_publish_gate_v1'
    publishedUtc = [DateTimeOffset]::UtcNow.ToString('o')
    state = $(if ($Preflight) { 'PASS_R18ZV1_PUBLICATION_PREFLIGHT_PENDING_APPLY_COLLISION_GATE' } else { 'PASS_R18ZV1_EXACT_SIGNED_MAINTENANCE_PUBLISHED_CREATE_NEW' })
    requestId = 'REQ_RZV1'
    packageRevision = [string]$invocation.packageRevision
    publishedPath = $readyPath
    requestZipBytes = $requestZipBytes
    requestZipSha256 = [string]$requestZipDependency.sha256
    packageBindingSha256 = [string]$bindingDependency.sha256
    invocationManifestPath = [string]$invocation.outputs.invocationPath
    invocationManifestSha256 = $invocationSha256
    postFreezeToolingGatePath = [string]$postFreezeContract.path
    postFreezeToolingGateSha256 = $postFreezeToolingSha256
    applyIntentPath = [string]$invocation.outputs.applyIntentPath
    applyIntentSha256 = $applyIntentSha256
    publisherPath = [string]$publisherDependency.row.path
    publisherSha256 = $selfSha256
    collectorPath = [string]$collectorDependency.row.path
    collectorSha256 = [string]$collectorDependency.sha256
    signatureVerified = $true
    requestExpiresUtc = [string]$manifest.expiresUtc
    collisionEvidence = $collision
    collisionStdoutSha256 = $collisionEvidenceSha256
    publicationCollisionGatePath = [string]$invocation.collision.gateOutputPath
    publicationCollisionGatePartialPath = [string]$invocation.collision.gatePartialPath
    publicationCollisionGateSha256 = $(if ($Apply) { Get-Sha256 $publicationCollisionGatePath } else { $null })
    collisionScanPendingApply = [bool]$Preflight
    allAccessibleNamespacesScanned = [bool]$Apply
    requiredShareNamespacesAvailable = $true
    optionalNamespaceUnavailableAccepted = $true
    collisionCount = $(if ($Apply) { [int]$collision.collisionCount } else { $null })
    firstWriteMode = 'CREATE_NEW_UPLOAD'
    atomicCommitMode = 'SAME_DIRECTORY_RENAME_UPLOAD_TO_READY'
    overwritePerformed = $false
    maximumPublicationsAuthorized = 1
    retryAuthorized = $false
    matchingSignedLaunchResponseCollectionOnly = $true
    persistentUMapping = $true
    persistentUMappingRoot = $shareRoot
    persistentUMappingLeftInPlace = $true
    taskActions = @()
    processActions = @('START_ONE_OWNED_BACKGROUND_R18ZT_BATCH_WORKER')
    asynchronousLaunchOnly = $true
    completionClaimed = $false
    sourceMutationPerformed = $false
    identityAccepted = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
    mutationsPerformed = $false
}
if ($Preflight) {
    $result | ConvertTo-Json -Depth 32
    return
}

# Exactly one publication attempt. There is no cleanup/retry loop. Any partial
# .upload or committed .ready.zip is a permanent stop for this request ID.
$targetStream = New-Object IO.FileStream($uploadPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
try {
    $targetStream.Write($publicationBytes, 0, $publicationBytes.Length)
    $targetStream.Flush($true)
}
finally { $targetStream.Dispose() }
Require ([int64](Get-Item -LiteralPath $uploadPath).Length -eq $requestZipBytes -and (Get-Sha256 $uploadPath) -ceq [string]$requestZipDependency.sha256) 'R18ZT staged upload verification failed; retry is not authorized.'
Require (-not (Test-Path -LiteralPath $readyPath)) 'R18ZT ready path appeared before atomic commit; retry is not authorized.'
[IO.File]::Move($uploadPath, $readyPath)
$result.mutationsPerformed = $true
$result.publishedUtc = [DateTimeOffset]::UtcNow.ToString('o')
Write-JsonAtomicCreateNew $publishGatePartialPath $publishGatePath $result
$result | ConvertTo-Json -Depth 32

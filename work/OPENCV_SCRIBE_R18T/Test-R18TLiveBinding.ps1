#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight, [switch]$Gate)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Gate)) { throw 'Specify exactly one of -Preflight or -Gate.' }

$modulePath = Join-Path $PSScriptRoot 'R18T.LiveBinding.psm1'
if (-not (Test-Path -LiteralPath $modulePath -PathType Leaf)) { throw 'R18T live-binding module is absent.' }
Import-Module -Name $modulePath -Force

if ($Preflight) {
    [ordered]@{
        schema = 'argos_opencv_scribe_r18t_live_binding_test_preflight_v1'
        state = 'PASS_R18T_LIVE_BINDING_TEST_PREFLIGHT'
        moduleSha256 = Get-R18TSha256 $modulePath
        fixtureCreated = $false
        mutationsPerformed = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 8
    return
}

function Write-NewUtf8([string]$Path, [string]$Text) {
    if (Test-Path -LiteralPath $Path) { throw "Create-new fixture exists: $Path" }
    [IO.File]::WriteAllText($Path, $Text, (New-Object Text.UTF8Encoding($false)))
}

function Write-Cohort([string]$Path, [object[]]$Rows) {
    $value = [ordered]@{
        schema = 'argos_opencv_scribe_r18t_binding_fixture_v1'
        caseCount = @($Rows).Count
        reviewCases = @($Rows)
        authority = [ordered]@{
            reviewOnly = $true
            identityAcceptanceAuthorized = $false
            automaticReferenceAdmissionAuthorized = $false
            trainingAuthorized = $false
            activationAuthorized = $false
            xmlAuthorized = $false
            productionAuthorized = $false
        }
    }
    Write-NewUtf8 $Path (($value | ConvertTo-Json -Depth 10) + [Environment]::NewLine)
}

function New-SourceRow([string]$Root, [string]$Identity, [string]$BfText, [string]$DfText, [bool]$CreateFiles = $true) {
    $scribe = Join-Path (Join-Path $Root $Identity) 'scribe'
    if ($CreateFiles) {
        [void](New-Item -ItemType Directory -Path $scribe)
        Write-NewUtf8 (Join-Path $scribe 'BF_SCRIBE_ORIENTED_DETECTOR_INPUT.png') $BfText
        Write-NewUtf8 (Join-Path $scribe 'DF_SCRIBE_ORIENTED_DETECTOR_INPUT.png') $DfText
    }
    $utf8 = New-Object Text.UTF8Encoding($false)
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $bfHash = ([BitConverter]::ToString($sha.ComputeHash($utf8.GetBytes($BfText)))).Replace('-', '')
        $dfHash = ([BitConverter]::ToString($sha.ComputeHash($utf8.GetBytes($DfText)))).Replace('-', '')
    }
    finally { $sha.Dispose() }
    return [pscustomobject][ordered]@{physicalIdentity=$Identity;bfSha256=$bfHash;dfSha256=$dfHash;classification='SYNTHETIC_NON_IMAGE_ENVELOPE_FIXTURE'}
}

function Require-Failure([scriptblock]$Action, [string]$Pattern) {
    $message = ''
    try { & $Action; throw 'Expected failure did not occur.' }
    catch { $message = $_.Exception.Message }
    if ($message -notlike $Pattern) { throw "Unexpected failure: $message" }
    return $message
}

$root = 'C:\R18TLB1'
if (Test-Path -LiteralPath $root) { throw "Fresh gate root already exists: $root" }
Assert-R18TPathBudget $root
$results = New-Object Collections.Generic.List[object]
try {
    [void](New-Item -ItemType Directory -Path $root)

    $oneRoot = Join-Path $root 'one'
    [void](New-Item -ItemType Directory -Path $oneRoot)
    $oneRow = New-SourceRow $oneRoot 'CASE_A' 'BF-ONE' 'DF-ONE'
    $oneCohort = Join-Path $root 'one.json'
    Write-Cohort $oneCohort @($oneRow)
    $one = Get-R18TLiveBinding -CohortPath $oneCohort -ProposalRoot $oneRoot
    if ([int]$one.caseCount -ne @($one.rows).Count -or [int]$one.uniqueCasefoldIdentityCount -ne @($one.rows).Count) { throw 'ONE binding cardinality failed.' }
    $results.Add([pscustomobject]@{caseId='ONE';state='PASS';actualCount=[int]$one.caseCount;bindingSha256=[string]$one.bindingSha256})

    $manyRoot = Join-Path $root 'many'
    [void](New-Item -ItemType Directory -Path $manyRoot)
    $manyRows = @(
        New-SourceRow $manyRoot 'CASE_A' 'BF-A' 'DF-A'
        New-SourceRow $manyRoot 'CASE_B' 'BF-B' 'DF-B'
        New-SourceRow $manyRoot 'CASE_C' 'BF-C' 'DF-C'
    )
    $manyCohort = Join-Path $root 'many.json'
    Write-Cohort $manyCohort $manyRows
    $manyFirst = Get-R18TLiveBinding -CohortPath $manyCohort -ProposalRoot $manyRoot
    $manySecond = Get-R18TLiveBinding -CohortPath $manyCohort -ProposalRoot $manyRoot
    if ([string]$manyFirst.bindingSha256 -ne [string]$manySecond.bindingSha256) { throw 'Repeated binding changed without source drift.' }
    $results.Add([pscustomobject]@{caseId='MANY';state='PASS';actualCount=[int]$manyFirst.caseCount;bindingSha256=[string]$manyFirst.bindingSha256})

    $zeroRoot = Join-Path $root 'zero'
    [void](New-Item -ItemType Directory -Path $zeroRoot)
    $zeroCohort = Join-Path $root 'zero.json'
    Write-Cohort $zeroCohort @()
    $zeroMessage = Require-Failure { Get-R18TLiveBinding -CohortPath $zeroCohort -ProposalRoot $zeroRoot } '*at least one*'
    $results.Add([pscustomobject]@{caseId='ZERO';state='PASS_EXPECTED_REJECTION';detail=$zeroMessage})

    $missingRoot = Join-Path $root 'missing'
    [void](New-Item -ItemType Directory -Path $missingRoot)
    $present = New-SourceRow $missingRoot 'CASE_PRESENT' 'BF-PRESENT' 'DF-PRESENT'
    $absent = New-SourceRow $missingRoot 'CASE_OMITTED' 'BF-OMITTED' 'DF-OMITTED' $false
    $missingCohort = Join-Path $root 'missing.json'
    Write-Cohort $missingCohort @($present, $absent)
    $workSentinel = Join-Path $root 'work-must-not-exist'
    $outputSentinel = Join-Path $root 'output-must-not-exist'
    $missingMessage = Require-Failure { Get-R18TLiveBinding -CohortPath $missingCohort -ProposalRoot $missingRoot } '*Required live input is absent*'
    if ((Test-Path -LiteralPath $workSentinel) -or (Test-Path -LiteralPath $outputSentinel)) { throw 'Missing-input rejection wrote a work/output sentinel.' }
    $results.Add([pscustomobject]@{caseId='DYNAMIC_OMISSION';state='PASS_REJECTED_BEFORE_TARGET_WRITE_OR_PROCESS';detail=$missingMessage})

    $duplicateRoot = Join-Path $root 'duplicate'
    [void](New-Item -ItemType Directory -Path $duplicateRoot)
    $upper = New-SourceRow $duplicateRoot 'CASE_DUP' 'BF-DUP-A' 'DF-DUP-A'
    $lower = [pscustomobject][ordered]@{physicalIdentity='case_dup';bfSha256=$upper.bfSha256;dfSha256=$upper.dfSha256;classification='SYNTHETIC_NON_IMAGE_ENVELOPE_FIXTURE'}
    $duplicateCohort = Join-Path $root 'duplicate.json'
    Write-Cohort $duplicateCohort @($upper, $lower)
    $duplicateMessage = Require-Failure { Get-R18TLiveBinding -CohortPath $duplicateCohort -ProposalRoot $duplicateRoot } '*Duplicate case-insensitive*'
    $results.Add([pscustomobject]@{caseId='CASEFOLD_DUPLICATE';state='PASS_EXPECTED_REJECTION';detail=$duplicateMessage})

    [ordered]@{
        schema = 'argos_opencv_scribe_r18t_live_binding_gate_v1'
        state = 'PASS_R18T_LIVE_BINDING_GATE'
        moduleSha256 = Get-R18TSha256 $modulePath
        caseResults = $results.ToArray()
        caseResultCount = $results.Count
        allCardinalitiesDerivedFromCollections = $true
        dynamicOmissionRejectedBeforeTargetWriteOrProcess = $true
        sourceImageBytesHashed = $false
        syntheticNonImageBytesOnly = $true
        pixelsDecoded = $false
        externalAccess = $false
        sourceMutationPerformed = $false
        identityAccepted = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 12
}
finally {
    if (Test-Path -LiteralPath $root) {
        $resolved = [IO.Path]::GetFullPath($root)
        if (-not $resolved.Equals('C:\R18TLB1', [StringComparison]::OrdinalIgnoreCase)) { throw "Unsafe fixture cleanup target: $resolved" }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}

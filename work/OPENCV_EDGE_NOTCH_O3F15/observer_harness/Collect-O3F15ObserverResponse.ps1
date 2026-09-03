#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$InvocationManifest,
    [switch]$Preflight,
    [switch]$Collect
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Collect)) { throw 'Specify exactly one of -Preflight or -Collect.' }

function Require([bool]$Condition,[string]$Message) {
    if (-not $Condition) { throw $Message }
}
function Required([object]$Object,[string]$Name) {
    Require ($null -ne $Object) "Required object is null while reading $Name."
    Require ($Object.PSObject.Properties.Name -contains $Name) "Required property is absent: $Name"
    return $Object.$Name
}
function Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}
function Resolve-File([string]$Project,[string]$Path,[string]$Label) {
    $resolved = $Path
    if (-not [IO.Path]::IsPathRooted($resolved)) { $resolved = Join-Path $Project $resolved.Replace('/','\') }
    $resolved = [IO.Path]::GetFullPath($resolved)
    Require (Test-Path -LiteralPath $resolved -PathType Leaf) "$Label is absent: $resolved"
    return $resolved
}
function Read-BoundedZipEntry([IO.Compression.ZipArchive]$Archive,[string]$Name,[int64]$MaximumBytes) {
    $entry = $Archive.GetEntry($Name)
    Require ($null -ne $entry -and [int64]$entry.Length -le $MaximumBytes) "O3F15 observer ZIP entry is absent or unbounded: $Name"
    $stream = $entry.Open()
    try {
        $memory = New-Object IO.MemoryStream
        try { $stream.CopyTo($memory); return $memory.ToArray() }
        finally { $memory.Dispose() }
    }
    finally { $stream.Dispose() }
}
function Write-NewJson([string]$Path,[object]$Value) {
    Require (-not (Test-Path -LiteralPath $Path)) "O3F15 observer collection gate exists: $Path"
    $encoding = New-Object Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($Path,(($Value | ConvertTo-Json -Depth 20) + [Environment]::NewLine),$encoding)
}
function Get-ExpectedRelativePaths([string]$FlowId) {
    if ($FlowId -eq 'P1') { return @('_ArgosReview/F15S/PROGRESS.json') }
    if ($FlowId -eq 'F1') { return @('_ArgosReview/F15S/PROGRESS.json','_ArgosReview/F15S/SUMMARY.json','_ArgosReview/F15S/RESULTS.json') }
    return @('_ArgosReview/F15S/TERMINAL_FAILURE.json')
}
function Read-ReturnedJson([string]$PayloadRoot,[string]$RelativePath,[int64]$MaximumBytes) {
    $entryPath = ('data/JBOD_KLARF_EXPORT/' + $RelativePath).Replace('/','\')
    $path = [IO.Path]::GetFullPath((Join-Path $PayloadRoot $entryPath))
    $contained = [IO.Path]::GetFullPath($PayloadRoot).TrimEnd('\') + '\'
    Require ($path.StartsWith($contained,[StringComparison]::OrdinalIgnoreCase)) 'O3F15 observer returned JSON escaped its payload root.'
    Require (Test-Path -LiteralPath $path -PathType Leaf) "O3F15 observer returned JSON is absent: $RelativePath"
    Require ([int64](Get-Item -LiteralPath $path).Length -le $MaximumBytes) "O3F15 observer returned JSON exceeded its bound: $RelativePath"
    return Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
}

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
$invocationPath = [IO.Path]::GetFullPath($InvocationManifest)
Require (Test-Path -LiteralPath $invocationPath -PathType Leaf) 'O3F15 observer response-collection invocation is absent.'
$invocation = Get-Content -LiteralPath $invocationPath -Raw | ConvertFrom-Json
Require ([string](Required $invocation 'schema') -eq 'argos_ocv03_o3f15_observer_response_collection_invocation_v1') 'O3F15 observer response-collection invocation schema changed.'
Require ([string](Required $invocation 'state') -eq 'FROZEN_EXACT_MATCHING_RESPONSE') 'O3F15 observer response-collection invocation is not frozen.'
$flow = [string](Required $invocation 'flow')
Require ($flow -in @('P1','F1','T1')) 'O3F15 observer response-collection flow changed.'
Require ([string](Required $invocation 'collectorScriptSha256') -eq (Sha256 $PSCommandPath)) 'O3F15 observer collection invocation does not pin this exact collector.'
Require ([bool](Required $invocation 'matchingSignedTerminalResponseOnly') -and -not [bool](Required $invocation 'requestRetryAuthorized')) 'O3F15 observer response selection or retry boundary changed.'
Require (-not [bool](Required $invocation 'imagePixelsDecodedByCollector') -and -not [bool](Required $invocation 'sourceMutationPerformed')) 'O3F15 observer collector crossed an image/source boundary.'
Require (-not [bool](Required $invocation 'existingTaskOrProcessActionPerformed') -and -not [bool](Required $invocation 'providerActivated')) 'O3F15 observer collector crossed a runtime boundary.'
Require ([bool](Required $invocation 'reviewOnly') -and -not [bool](Required $invocation 'productionRoutingEnabled')) 'O3F15 observer collector authority widened.'

$requestId = [string](Required $invocation 'requestId')
$responseId = [string](Required $invocation 'responseId')
Require ($requestId -match '^REQ_[0-9]{8}T[0-9]{9}Z_[A-F0-9]{12}$') 'O3F15 observer collection request ID is invalid.'
Require ($responseId -match '^R_[A-F0-9]{12}_[0-9]{8}T[0-9]{9}_[a-f0-9]{8}$') 'O3F15 observer collection response ID is invalid.'
$publicationPath = Resolve-File $project ([string](Required $invocation 'publicationGate')) 'O3F15 observer publication gate'
Require ((Sha256 $publicationPath) -eq [string](Required $invocation 'publicationGateSha256')) 'O3F15 observer publication gate changed.'
$publication = Get-Content -LiteralPath $publicationPath -Raw | ConvertFrom-Json
Require ([string](Required $publication 'state') -eq ('PASS_O3F15_' + $flow + '_OBSERVER_PUBLISHED_ONCE_AWAITING_SIGNED_RESPONSE')) 'O3F15 observer publication state changed.'
Require ([string](Required $publication 'requestId') -eq $requestId -and [int](Required $publication 'publicationCount') -eq 1) 'O3F15 observer publication identity changed.'
Require (-not [bool](Required $publication 'requestRetryAuthorized')) 'O3F15 observer publication retry boundary changed.'

$verifier = Resolve-File $project ([string](Required $invocation 'verifier')) 'O3F15 observer response verifier'
$certificate = Resolve-File $project ([string](Required $invocation 'endpointCertificate')) 'O3F15 observer endpoint certificate'
Require ((Sha256 $verifier) -eq [string](Required $invocation 'verifierSha256')) 'O3F15 observer response verifier changed.'
Require ((Sha256 $certificate) -eq [string](Required $invocation 'endpointCertificateSha256')) 'O3F15 observer endpoint certificate changed.'
$sourceZip = [IO.Path]::GetFullPath([string](Required $invocation 'sourceZip'))
Require (Test-Path -LiteralPath $sourceZip -PathType Leaf) 'O3F15 observer matching response ZIP is absent.'
Require ([int64](Get-Item -LiteralPath $sourceZip).Length -eq [int64](Required $invocation 'sourceZipBytes')) 'O3F15 observer matching response ZIP byte count changed.'
Require ((Sha256 $sourceZip) -eq [string](Required $invocation 'sourceZipSha256')) 'O3F15 observer matching response ZIP hash changed.'

$responseRoot = [IO.Path]::GetFullPath([string](Required $invocation 'temporaryResponseRoot'))
$responseZip = [IO.Path]::GetFullPath([string](Required $invocation 'temporaryResponseZip'))
$responseExtract = [IO.Path]::GetFullPath([string](Required $invocation 'temporaryResponseExtractionRoot'))
$payloadExtract = [IO.Path]::GetFullPath([string](Required $invocation 'temporaryPayloadExtractionRoot'))
Require ($responseZip.StartsWith($responseRoot.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)) 'O3F15 observer temporary response ZIP escaped its root.'
Require ($responseExtract.StartsWith($responseRoot.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)) 'O3F15 observer temporary response extraction escaped its root.'
Require ($payloadExtract.Length -lt 80 -and $responseRoot.Length -lt 80) 'O3F15 observer local collection roots are not short.'
Require (-not $responseRoot.Equals([IO.Path]::GetPathRoot($responseRoot),[StringComparison]::OrdinalIgnoreCase)) 'O3F15 observer response root cannot be a drive root.'
Require (-not $payloadExtract.Equals([IO.Path]::GetPathRoot($payloadExtract),[StringComparison]::OrdinalIgnoreCase)) 'O3F15 observer payload root cannot be a drive root.'
$expectedGateRelative = 'work/OPENCV_EDGE_NOTCH_O3F15/observer_harness/O3F15_' + $flow + '_SIGNED_RESPONSE_GATE.json'
$expectedGate = [IO.Path]::GetFullPath((Join-Path $project $expectedGateRelative.Replace('/','\')))
$gatePath = [IO.Path]::GetFullPath([string](Required $invocation 'collectionGate'))
Require ($gatePath.Equals($expectedGate,[StringComparison]::OrdinalIgnoreCase)) 'O3F15 observer collection gate path changed.'
foreach ($target in @($responseRoot,$payloadExtract,$gatePath)) {
    Require (-not (Test-Path -LiteralPath $target)) "O3F15 observer create-new collection target exists: $target"
}

$expectedRelativePaths = @(Get-ExpectedRelativePaths $flow)
$expectedFiles = @((Required $invocation 'expectedFiles'))
Require ($expectedFiles.Count -eq $expectedRelativePaths.Count) 'O3F15 observer expected returned-file count changed.'
$expectedByRelative = @{}
foreach ($row in $expectedFiles) {
    $relative = [string](Required $row 'relativePath')
    Require ($expectedRelativePaths -contains $relative) "O3F15 observer unexpected returned file: $relative"
    Require (-not $expectedByRelative.ContainsKey($relative)) "O3F15 observer duplicate expected returned file: $relative"
    Require ([string](Required $row 'entryPath') -eq ('data/JBOD_KLARF_EXPORT/' + $relative)) "O3F15 observer returned entry path changed: $relative"
    Require ([int64](Required $row 'bytes') -gt 0 -and [int64]$row.bytes -le 2097152) "O3F15 observer returned JSON byte bound changed: $relative"
    Require ([string](Required $row 'sha256') -match '^[A-F0-9]{64}$') "O3F15 observer returned JSON hash is invalid: $relative"
    $expectedByRelative[$relative] = $row
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($sourceZip)
try {
    $names = @($archive.Entries | ForEach-Object { [string]$_.FullName } | Sort-Object)
    $expectedNames = @('DATA_PULL_PAYLOAD.zip','PORTAL_RESPONSE_MANIFEST.json','PORTAL_RESPONSE_MANIFEST.sig','RESULT.json') | Sort-Object
    Require ($names.Count -eq 4 -and @(Compare-Object -ReferenceObject $expectedNames -DifferenceObject $names).Count -eq 0) 'O3F15 observer response ZIP entry set changed.'
    $manifestBytes = Read-BoundedZipEntry -Archive $archive -Name 'PORTAL_RESPONSE_MANIFEST.json' -MaximumBytes 65536
    $manifest = [Text.Encoding]::UTF8.GetString($manifestBytes) | ConvertFrom-Json
}
finally { $archive.Dispose() }
Require ([string](Required $manifest 'requestId') -eq $requestId -and [string](Required $manifest 'responseId') -eq $responseId) 'O3F15 observer response manifest correlation changed.'
Require ([string](Required $manifest 'sourceRole') -eq 'JBOD' -and [string](Required $manifest 'state') -eq 'PASS_DATA_PULL') 'O3F15 observer response is not the expected JBOD DATA_PULL pass.'

if ($Preflight) {
    [ordered]@{
        schema='argos_ocv03_o3f15_observer_response_collection_preflight_v1'; checkedUtc=[DateTime]::UtcNow.ToString('o')
        state=('PASS_O3F15_' + $flow + '_OBSERVER_RESPONSE_COLLECTION_PREFLIGHT'); flow=$flow
        requestId=$requestId; responseId=$responseId; sourceZipSha256=[string]$invocation.sourceZipSha256
        expectedFileCount=$expectedFiles.Count; manifestState='PASS_DATA_PULL'; signatureVerified=$false
        mutationsPerformed=$false; imagePixelsDecoded=$false; requestRetryAuthorized=$false
        reviewOnly=$true; productionRoutingEnabled=$false
    } | ConvertTo-Json -Depth 10
    return
}

[void][IO.Directory]::CreateDirectory($responseRoot)
[IO.File]::Copy($sourceZip,$responseZip,$false)
Require ((Sha256 $responseZip) -eq [string]$invocation.sourceZipSha256) 'O3F15 observer temporary response copy changed.'
[IO.Compression.ZipFile]::ExtractToDirectory($responseZip,$responseExtract)
$verification = & $verifier -PackagePath $responseExtract -EndpointCertificatePath $certificate -ExpectedSourceRole JBOD -ExpectedRequestId $requestId
Require ([string](Required $verification 'State') -eq 'PASS_SIGNED_PORTAL_RESPONSE') 'O3F15 observer JBOD response signature failed.'
Require ([string](Required $verification 'EndpointState') -eq 'PASS_DATA_PULL') 'O3F15 observer signed endpoint state changed.'
Require ([string](Required $verification 'SignerThumbprint') -eq 'DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC') 'O3F15 observer endpoint signer changed.'

$payloadZip = Join-Path $responseExtract 'DATA_PULL_PAYLOAD.zip'
$resultPath = Join-Path $responseExtract 'RESULT.json'
Require ([int64](Get-Item -LiteralPath $payloadZip).Length -eq [int64](Required $invocation 'expectedPayloadBytes')) 'O3F15 observer payload byte count changed.'
Require ((Sha256 $payloadZip) -eq [string](Required $invocation 'expectedPayloadSha256')) 'O3F15 observer payload hash changed.'
Require ([int64](Get-Item -LiteralPath $resultPath).Length -eq [int64](Required $invocation 'expectedResultJsonBytes')) 'O3F15 observer RESULT.json byte count changed.'
Require ((Sha256 $resultPath) -eq [string](Required $invocation 'expectedResultJsonSha256')) 'O3F15 observer RESULT.json hash changed.'
$result = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
Require ([string](Required $result 'schema') -eq 'argos_project_portal_data_pull_result_v2' -and [string](Required $result 'state') -eq 'PASS_DATA_PULL') 'O3F15 observer DATA_PULL result state changed.'
Require ([string](Required $result 'approvedRoot') -eq 'JBOD_KLARF_EXPORT') 'O3F15 observer DATA_PULL approved root changed.'
Require ([string](Required $result 'container') -eq 'DATA_PULL_PAYLOAD.zip') 'O3F15 observer DATA_PULL container identity changed.'
Require ([int64](Required $result 'containerBytes') -eq [int64](Get-Item -LiteralPath $payloadZip).Length -and [string](Required $result 'containerSha256') -eq (Sha256 $payloadZip)) 'O3F15 observer DATA_PULL container binding changed.'
Require ([bool](Required $result 'sourcePathsPreservedAsZipEntries') -and [bool](Required $result 'filesystemReturnPathsFlattened')) 'O3F15 observer DATA_PULL provenance semantics changed.'
Require ([bool](Required $result 'reviewOnly') -and -not [bool](Required $result 'productionRoutingEnabled')) 'O3F15 observer DATA_PULL authority widened.'
$resultFiles = @((Required $result 'files'))
Require ($resultFiles.Count -eq $expectedFiles.Count) 'O3F15 observer signed returned-file count changed.'
$resultTotalSourceBytes = [int64]0
foreach ($row in $resultFiles) {
    $relative = [string](Required $row 'relativePath')
    Require ($expectedByRelative.ContainsKey($relative)) "O3F15 observer signed result added a file: $relative"
    $expected = $expectedByRelative[$relative]
    Require ([string](Required $row 'entryPath') -eq [string]$expected.entryPath) "O3F15 observer signed entry path changed: $relative"
    Require ([int64](Required $row 'bytes') -eq [int64]$expected.bytes -and [string](Required $row 'sha256') -eq [string]$expected.sha256) "O3F15 observer signed returned identity changed: $relative"
    $resultTotalSourceBytes += [int64]$row.bytes
}
Require ([int64](Required $result 'totalSourceBytes') -eq $resultTotalSourceBytes) 'O3F15 observer DATA_PULL total source bytes changed.'

[IO.Compression.ZipFile]::ExtractToDirectory($payloadZip,$payloadExtract)
$returnedFiles = @(Get-ChildItem -LiteralPath $payloadExtract -Recurse -File -ErrorAction Stop)
Require ($returnedFiles.Count -eq $expectedFiles.Count) 'O3F15 observer extracted payload file cardinality changed.'
foreach ($relative in $expectedRelativePaths) {
    $expected = $expectedByRelative[$relative]
    $returnedPath = Join-Path $payloadExtract ([string]$expected.entryPath).Replace('/','\')
    Require (Test-Path -LiteralPath $returnedPath -PathType Leaf) "O3F15 observer returned file is absent: $relative"
    Require ([int64](Get-Item -LiteralPath $returnedPath).Length -eq [int64]$expected.bytes -and (Sha256 $returnedPath) -eq [string]$expected.sha256) "O3F15 observer extracted returned identity changed: $relative"
}

$terminalStates = @('COMPLETE_O3F15_FULL978','HOLD_O3F15_EXECUTION_STOPPED')
$progressState = $null
$summaryState = $null
$resultsState = $null
$fullPullEligible = $false
$terminalFailurePullEligible = $false
$executedCount = $null
$recordedCount = $null
$resultsRowCount = $null
if ($flow -eq 'P1') {
    $progress = Read-ReturnedJson -PayloadRoot $payloadExtract -RelativePath '_ArgosReview/F15S/PROGRESS.json' -MaximumBytes 262144
    Require ([string](Required $progress 'schema') -eq 'argos_ocv03_o3f15_progress_v1') 'O3F15 P1 progress schema changed.'
    $progressState = [string](Required $progress 'state')
    Require ($progressState -in @('RUNNING_O3F15_FULL978','COMPLETE_O3F15_FULL978','HOLD_O3F15_EXECUTION_STOPPED')) 'O3F15 P1 progress state is outside the frozen execution states.'
    Require ([int](Required $progress 'scheduledCount') -eq 978) 'O3F15 P1 scheduled count changed.'
    $executedCount = [int](Required $progress 'executedCount')
    $recordedCount = [int](Required $progress 'recordedCount')
    Require (-not [bool](Required $progress 'retryAuthorized') -and -not [bool](Required $progress 'sourceMutation') -and -not [bool](Required $progress 'providerActivated')) 'O3F15 P1 progress crossed a protected boundary.'
    $fullPullEligible = $progressState -in $terminalStates
}
elseif ($flow -eq 'F1') {
    $progress = Read-ReturnedJson -PayloadRoot $payloadExtract -RelativePath '_ArgosReview/F15S/PROGRESS.json' -MaximumBytes 262144
    $summary = Read-ReturnedJson -PayloadRoot $payloadExtract -RelativePath '_ArgosReview/F15S/SUMMARY.json' -MaximumBytes 262144
    $results = Read-ReturnedJson -PayloadRoot $payloadExtract -RelativePath '_ArgosReview/F15S/RESULTS.json' -MaximumBytes 2097152
    Require ([string](Required $progress 'schema') -eq 'argos_ocv03_o3f15_progress_v1') 'O3F15 F1 progress schema changed.'
    Require ([string](Required $summary 'schema') -eq 'argos_ocv03_o3f15_front_reconciliation_summary_v1') 'O3F15 F1 summary schema changed.'
    Require ([string](Required $results 'schema') -eq 'argos_ocv03_o3f15_front_reconciliation_results_v1') 'O3F15 F1 results schema changed.'
    $progressState = [string](Required $progress 'state')
    $summaryState = [string](Required $summary 'state')
    $resultsState = [string](Required $results 'state')
    Require ($progressState -in $terminalStates -and $summaryState -eq $progressState -and $resultsState -eq $progressState) 'O3F15 F1 terminal states disagree.'
    Require ([int](Required $progress 'scheduledCount') -eq 978 -and [int](Required $summary 'scheduledCount') -eq 978) 'O3F15 F1 scheduled count changed.'
    $executedCount = [int](Required $summary 'executedCount')
    $recordedCount = [int](Required $progress 'recordedCount')
    $resultsRowCount = [int](Required $results 'rowCount')
    Require ($resultsRowCount -eq 978 -and @((Required $results 'rows')).Count -eq 978) 'O3F15 F1 result cardinality changed.'
    $resultsFile = Join-Path $payloadExtract 'data\JBOD_KLARF_EXPORT\_ArgosReview\F15S\RESULTS.json'
    Require ([string](Required $summary 'resultsSha256') -eq (Sha256 $resultsFile)) 'O3F15 F1 summary/result hash binding changed.'
    Require ([int64](Required $summary 'resultsBytes') -eq [int64](Get-Item -LiteralPath $resultsFile).Length) 'O3F15 F1 summary/result byte binding changed.'
    Require ([bool](Required $summary 'ordinaryDetectorHoldsPreserved')) 'O3F15 F1 ordinary detector holds were not preserved.'
    Require (-not [bool](Required $summary 'retryAuthorized') -and -not [bool](Required $summary 'sourceMutation') -and -not [bool](Required $summary 'providerActivated')) 'O3F15 F1 summary crossed a protected boundary.'
    Require (-not [bool](Required $summary 'numericThresholdRelaxationPerformed') -and -not [bool](Required $summary 'postResultSelectorRelaxationPerformed')) 'O3F15 F1 changed frozen detector selection semantics.'
    Require ([bool](Required $summary 'reviewOnly') -and -not [bool](Required $summary 'productionRoutingEnabled')) 'O3F15 F1 authority widened.'
}
else {
    $failure = Read-ReturnedJson -PayloadRoot $payloadExtract -RelativePath '_ArgosReview/F15S/TERMINAL_FAILURE.json' -MaximumBytes 262144
    Require ([string](Required $failure 'schema') -eq 'argos_ocv03_o3f15_terminal_failure_v1') 'O3F15 T1 terminal-failure schema changed.'
    $summaryState = [string](Required $failure 'state')
    Require ($summaryState -eq 'HOLD_O3F15_ARTIFACT_COMMIT_FAILURE') 'O3F15 T1 is not an artifact-commit failure.'
    Require ([int](Required $failure 'scheduledCount') -eq 978) 'O3F15 T1 scheduled count changed.'
    $executedCount = [int](Required $failure 'validatedExecutionCount')
    $recordedCount = [int](Required $failure 'recordedCount')
    Require (-not [bool](Required $failure 'retryAuthorized') -and -not [bool](Required $failure 'sourceMutation') -and -not [bool](Required $failure 'providerActivated')) 'O3F15 T1 failure crossed a protected boundary.'
    Require ([bool](Required $failure 'reviewOnly') -and -not [bool](Required $failure 'productionRoutingEnabled')) 'O3F15 T1 authority widened.'
}

$gateState = 'PASS_O3F15_' + $flow + '_SIGNED_DATA_PULL_COLLECTED'
$gate = [ordered]@{
    schema='argos_ocv03_o3f15_observer_signed_response_gate_v1'; collectedUtc=[DateTime]::UtcNow.ToString('o')
    state=$gateState; flow=$flow; requestId=$requestId; responseId=$responseId
    responseZipPath=$responseZip; responseZipBytes=[int64]$invocation.sourceZipBytes; responseZipSha256=[string]$invocation.sourceZipSha256
    signatureVerified=$true; signerThumbprint=[string]$verification.SignerThumbprint; endpointState=[string]$verification.EndpointState
    payloadZipSha256=[string]$invocation.expectedPayloadSha256; resultJsonSha256=[string]$invocation.expectedResultJsonSha256
    returnedFiles=$expectedFiles; progressState=$progressState; summaryState=$summaryState; resultsState=$resultsState
    executedCount=$executedCount; recordedCount=$recordedCount; resultsRowCount=$resultsRowCount
    fullPullEligible=$fullPullEligible; terminalFailurePullEligible=$terminalFailurePullEligible
    imagePixelsDecodedByCollector=$false; detectorRerunPerformed=$false; sourceMutationPerformed=$false
    sourceDeletionPerformed=$false; existingTaskOrProcessActionPerformed=$false; providerActivated=$false
    automaticHoldClearancePerformed=$false; requestRetryAuthorized=$false; gatewayAcceptanceIsExecutionEvidence=$false
    reviewOnly=$true; trainingEligible=$false; xmlEligible=$false; productionEligible=$false; productionRoutingEnabled=$false
}
Write-NewJson -Path $gatePath -Value $gate
$gate | ConvertTo-Json -Depth 20

#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$DesignPath,
    [string]$TimeoutGatePath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ([string]::IsNullOrWhiteSpace($DesignPath)) {
    $DesignPath = Join-Path $PSScriptRoot 'R21_OUTPUT_RECOVERY_CAPABILITY_DESIGN.json'
}
if ([string]::IsNullOrWhiteSpace($TimeoutGatePath)) {
    $TimeoutGatePath = Join-Path $PSScriptRoot 'R21_SIGNED_TIMEOUT_RESPONSE_VALIDATION_GATE.json'
}

function Require([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

$design = Get-Content -LiteralPath $DesignPath -Raw | ConvertFrom-Json
$timeout = Get-Content -LiteralPath $TimeoutGatePath -Raw | ConvertFrom-Json
Require ([string]$design.state -eq 'DRAFT_LOCAL_DESIGN_BLOCKED_BY_MUTATION_STOP_LOSS_AND_CURRENT_CONFIG_PIN') 'Design state changed.'
Require ([string]$timeout.state -eq 'PASS_R21_EXACT_SIGNED_TIMEOUT_RESPONSE_FROZEN') 'Timeout response is not frozen.'
Require ([string]$timeout.requestId -eq 'REQ_20260831T135113536Z_EE76925FE71B') 'Timeout request identity changed.'
Require (-not [bool]$timeout.detectorGatePassed) 'Timeout evidence cannot pass the detector gate.'
Require ([bool]$design.stopLoss.active) 'Mutation stop-loss was cleared without review.'
Require (-not [bool]$design.stopLoss.payloadConstructed -and -not [bool]$design.stopLoss.packageConstructed) 'A mutation artifact already exists.'
Require (-not [bool]$design.installedEndpointWorker.codeChangeRequired) 'The design must not change endpoint worker code.'
Require (-not [bool]$design.configurationDelta.newHandlerInstalled) 'The design must not add a handler.'
Require ([string]$design.configurationDelta.addApprovedDataRoot.path -eq 'D:/R21TG1') 'Approved root changed.'

$formats = @($design.configurationDelta.appendStatusHashInventory.relativePathFormats)
Require ($formats.Count -eq 6) 'Expected-leaf format cardinality changed.'
$leaves = New-Object Collections.Generic.List[string]
for ($index = 0; $index -le 33; $index++) {
    $token = '{0:D2}' -f $index
    foreach ($format in $formats) {
        $leaf = ([string]$format).Replace('{index}', $token)
        Require (-not [IO.Path]::IsPathRooted($leaf)) "Expected leaf became rooted: $leaf"
        Require ($leaf -notmatch '(^|[\\/])\.\.([\\/]|$)') "Expected leaf traverses: $leaf"
        $leaves.Add($leaf)
    }
}
$unique = @($leaves | Sort-Object -Unique)
Require ($leaves.Count -eq 204 -and $unique.Count -eq 204) 'Expected-leaf expansion is not exactly 204 unique paths.'
Require ([int]$design.configurationDelta.appendStatusHashInventory.exactExpectedLeafCount -eq 204) 'Declared leaf count changed.'
Require ([int]$design.worstCaseDataPull.endpointMaximumFilesPerRequest -eq 128) 'Endpoint maximum changed.'
Require (@($design.worstCaseDataPull.chunkSizesWhenAllLeavesExist).Count -eq 2) 'Worst-case chunk count changed.'
Require ([int]$design.worstCaseDataPull.chunkSizesWhenAllLeavesExist[0] -eq 128) 'First chunk changed.'
Require ([int]$design.worstCaseDataPull.chunkSizesWhenAllLeavesExist[1] -eq 76) 'Second chunk changed.'

$root = 'D:\R21TG1'
$longest = $null
foreach ($leaf in $leaves) {
    $full = $root.TrimEnd('\') + '\' + $leaf.Replace('/', '\')
    $effective = $full.Length + 32
    Require ($effective -lt 200) "Source path requires shortening: $full"
    if ($null -eq $longest -or $effective -gt $longest.effectiveLength) {
        $longest = [pscustomobject]@{ path = $full; pathLength = $full.Length; effectiveLength = $effective }
    }
}

[pscustomobject][ordered]@{
    schema = 'argos_o3b21_r21_output_recovery_design_gate_v1'
    state = 'PASS_LOCAL_DESIGN_ONLY_BLOCKED_BEFORE_MUTATION'
    expandedExpectedLeafCount = $leaves.Count
    uniqueExpectedLeafCount = $unique.Count
    worstCaseDataPullRequestCount = 2
    worstCaseDataPullChunkSizes = @(128, 76)
    longestSourcePath = $longest.path
    longestSourcePathLength = $longest.pathLength
    longestSourceEffectiveLength = $longest.effectiveLength
    endpointWorkerCodeChangeRequired = $false
    newHandlerRequired = $false
    currentConfigPremisePinned = $false
    mutationStopLossActive = $true
    payloadConstructed = $false
    packageConstructed = $false
    signed = $false
    published = $false
    deployed = $false
    r21Rerun = $false
    sourceImageBytesRead = $false
    existingTaskOrProcessActionPerformed = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
} | ConvertTo-Json -Depth 6 -Compress

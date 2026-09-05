[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Rehearsal,
    [string]$InvocationManifest=''
)

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($Preflight -and $Rehearsal){throw 'Preflight and Rehearsal are mutually exclusive.'}

$expectedQuerySha='54EBD1A13B3EEAFE810378A1684917AC8461545FC5C89462C5E6352EAA13BD00'
$queryPath='C:\ProgramData\ArgosInsiteBridgeRO\query\Invoke-ArgosPendingInsiteRequest.ps1'
if($Rehearsal){
    if([string]::IsNullOrWhiteSpace($InvocationManifest)){throw 'A18 rehearsal manifest is required.'}
    $manifestPath=[IO.Path]::GetFullPath($InvocationManifest)
    if(-not(Test-Path -LiteralPath $manifestPath -PathType Leaf)){throw 'A18 rehearsal manifest is missing.'}
    $manifest=Get-Content -LiteralPath $manifestPath -Raw|ConvertFrom-Json
    if([string]$manifest.schema-ne'argos_a18_install_verifier_rehearsal_v1' -or
       -not[bool]$manifest.rehearsal){throw 'A18 rehearsal manifest contract refused.'}
    $queryPath=[IO.Path]::GetFullPath([string]$manifest.installedQueryPath)
}

if(-not(Test-Path -LiteralPath $queryPath -PathType Leaf)){throw "A18 installed query is missing: $queryPath"}
$actualQuerySha=(Get-FileHash -LiteralPath $queryPath -Algorithm SHA256).Hash
if($actualQuerySha-ne$expectedQuerySha){throw "A18 installed query hash refused: $actualQuerySha"}
$source=Get-Content -LiteralPath $queryPath -Raw
foreach($token in @(
    'FRONTSIDE_SCRATCH_TEST_ROUTE_V3',
    'LATEST_QUALIFYING_NUMBERED_SACRIFICIAL_NITRIDE_DEP_ANCHOR_AT_OR_BEFORE_EXACT_SCAN',
    "-match '^SACRIFICIAL NITRIDE DEP \{[1-9][0-9]*\}$'",
    '$isSameDepositionFlow=$processBlock -eq $anchorProcessBlock',
    "-match '(?i)^6-4-CVD-[0-9]+$'"
)){
    if(-not$source.Contains($token)){throw "A18 installed classifier token missing: $token"}
}
if($source.Contains("ProcessBlockName).Trim() -eq 'SACRIFICIAL NITRIDE DEP {1}'")){throw 'A18 fixed first-cycle anchor survived.'}
if($source.Contains("(Resource-FromSummary `$row.TxnSummary) -eq '6-4-CVD-02'")){throw 'A18 single-tool anchor equality survived.'}
if($source -match '(?i)62631|slot0?[1-9]|slot10'){throw 'A18 identity-specific classifier text refused.'}

[ordered]@{
    schema='argos_a18_install_verifier_result_v1'
    createdUtc=[DateTime]::UtcNow.ToString('o')
    state=if($Preflight){'PASS_A18_PREFLIGHT'}else{'PASS_A18_QUALIFIED_CVD_TOOL_FAMILY_CLASSIFIER_INSTALLED'}
    rehearsal=[bool]$Rehearsal
    installedQueryPath=$queryPath
    installedQuerySha256=$actualQuerySha
    fingerprintVersion='FRONTSIDE_SCRATCH_TEST_ROUTE_V3'
    mutationsPerformed=$false
    inspectionTasksChanged=$false
    reviewOnly=$true
    productionRoutingEnabled=$false
}|ConvertTo-Json -Depth 5

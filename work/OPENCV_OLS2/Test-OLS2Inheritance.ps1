[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Gate
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Gate)) { throw 'Specify exactly one of -Preflight or -Gate.' }

$project = 'C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab'
$workRoot = Join-Path $project 'work\OPENCV_OLS2'
$sourcePath = Join-Path $project 'work\OPENCV_OEL1\pkg\payload\W.ps1'
$targetPath = Join-Path $workRoot 'pkg\payload\W.ps1'
$fic1RouteGatePath = Join-Path $project 'work\OPENCV_OEL1\OEL1_COMPLETE_ROUTE_GATE.json'
$outputPath = Join-Path $workRoot 'OLS2_WORKER_INHERITANCE_GATE.json'
$sourceSha256 = '1CE01F67083A989CB92AE3824DB0AE2CB6532FD6B674E74456CC495F06DCDDF8'
$targetSha256 = 'CB6700714E20DAC2D3C097095A2800C92ECAAC75F29878F4C86326493B246250'
$fic1RouteGateSha256 = '30E2A04438770BF9D1515BF9515FC91584EF8A84ACD9C2EF05BBF789F21C95B3'

function Get-Sha([string]$Path) {
    $full=[IO.Path]::GetFullPath($Path)
    $stream=[IO.File]::Open($full,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
    $sha=[Security.Cryptography.SHA256]::Create()
    try{return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','')}
    finally{$sha.Dispose();$stream.Dispose()}
}
function Get-TextSha([string]$Text) {
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes($Text)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '') }
    finally { $sha.Dispose() }
}
function Get-FunctionMap([string]$Path) {
    $tokens = $null
    $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)
    if (@($errors).Count -ne 0) { throw "OLS2 inheritance parser failure: $Path" }
    $map = @{}
    foreach ($node in @($ast.FindAll({ param($candidate) $candidate -is [Management.Automation.Language.FunctionDefinitionAst] }, $true))) {
        if ($map.ContainsKey($node.Name)) { throw "Duplicate function in OLS2 worker: $($node.Name)" }
        $map[$node.Name] = Get-TextSha $node.Extent.Text
    }
    return $map
}

$required = @($sourcePath, $targetPath, $fic1RouteGatePath)
foreach ($path in $required) { if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "OLS2 inheritance prerequisite is missing: $path" } }
if ((Get-Sha $sourcePath) -ne $sourceSha256) { throw 'OLS2 inheritance source worker changed.' }
if ((Get-Sha $targetPath) -ne $targetSha256) { throw 'OLS2 inheritance target worker changed.' }
if ((Get-Sha $fic1RouteGatePath) -ne $fic1RouteGateSha256) { throw 'OLS2 inherited FIC1 route gate changed.' }
$fic1Gate = Get-Content -LiteralPath $fic1RouteGatePath -Raw | ConvertFrom-Json
if ([string]$fic1Gate.state -ne 'PASS_OEL1_COMPLETE_ROUTE_GATE' -or [string]$fic1Gate.endpointWorkerTargetSha256 -ne $sourceSha256 -or -not [bool]$fic1Gate.exactFinalZipExtractionPassed -or -not [bool]$fic1Gate.exactFinalZipSignaturePassed) { throw 'OLS2 inherited OEL1 endpoint qualification changed.' }

$sourceFunctions = Get-FunctionMap $sourcePath
$targetFunctions = Get-FunctionMap $targetPath
$sourceNames = @($sourceFunctions.Keys | Sort-Object)
$targetNames = @($targetFunctions.Keys | Sort-Object)
$addedNames = @($targetNames | Where-Object { -not $sourceFunctions.ContainsKey($_) })
$removedNames = @($sourceNames | Where-Object { -not $targetFunctions.ContainsKey($_) })
$changedNames = @($sourceNames | Where-Object { $targetFunctions.ContainsKey($_) -and [string]$sourceFunctions[$_] -ne [string]$targetFunctions[$_] })
if ($addedNames.Count -ne 1 -or $addedNames[0] -ne 'Get-FileHash') { throw 'OLS2 added-function set escaped the script-local PS5 hash dependency.' }
if ($removedNames.Count -ne 0) { throw 'OLS2 removed a predecessor worker function.' }
if ($changedNames.Count -ne 1 -or $changedNames[0] -ne 'Get-EnvironmentInventory') { throw 'OLS2 changed-function set escaped the generic metadata inventory provider.' }
$unchangedNames = @($sourceNames | Where-Object { $_ -ne 'Get-EnvironmentInventory' })
if ($unchangedNames.Count -ne 22) { throw "OLS2 unchanged-function cardinality changed: $($unchangedNames.Count)" }
if ([string]$sourceFunctions['Invoke-DataPullHandler'] -ne [string]$targetFunctions['Invoke-DataPullHandler']) { throw 'OLS2 DATA_PULL handler changed.' }
if ([string]$sourceFunctions['Process-One'] -ne [string]$targetFunctions['Process-One']) { throw 'OLS2 queue state machine changed.' }
if ([string]$sourceFunctions['New-SignedResponse'] -ne [string]$targetFunctions['New-SignedResponse']) { throw 'OLS2 response construction changed.' }

$result = [ordered]@{
    schema = 'argos_ols2_worker_inheritance_gate_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = if ($Preflight) { 'PASS_OLS2_WORKER_INHERITANCE_PREFLIGHT' } else { 'PASS_OLS2_WORKER_INHERITANCE_GATE' }
    sourceWorkerSha256 = $sourceSha256
    targetWorkerSha256 = $targetSha256
    exactChangedFunctionCount = $changedNames.Count
    addedFunctions = $addedNames
    changedFunctions = $changedNames
    removedFunctions = $removedNames
    unchangedFunctionCount = $unchangedNames.Count
    dataPullHandlerSha256 = [string]$targetFunctions['Invoke-DataPullHandler']
    inheritedFic1RouteGateSha256 = $fic1RouteGateSha256
    inheritedQueueAndResponseImplementation = $true
    dataPullImplementationUnchanged = $true
    mutationsPerformed = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
}
if ($Preflight) { $result | ConvertTo-Json -Depth 8; return }
if (Test-Path -LiteralPath $outputPath) { throw "OLS2 inheritance gate already exists: $outputPath" }
[IO.File]::WriteAllText($outputPath, (($result | ConvertTo-Json -Depth 8) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
$result.mutationsPerformed = $true
$result | ConvertTo-Json -Depth 8

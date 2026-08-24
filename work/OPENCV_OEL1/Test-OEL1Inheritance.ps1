[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Gate
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Gate)) { throw 'Specify exactly one of -Preflight or -Gate.' }

$project = 'C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab'
$workRoot = Join-Path $project 'work\OPENCV_OEL1'
$sourcePath = Join-Path $project 'work\FIDUCIAL_JBOD_INVENTORY_CAPABILITY_FIC1\pkg\payload\W.ps1'
$targetPath = Join-Path $workRoot 'pkg\payload\W.ps1'
$fic1RouteGatePath = Join-Path $project 'work\FIDUCIAL_JBOD_INVENTORY_CAPABILITY_FIC1\FIC1_COMPLETE_ROUTE_GATE.json'
$outputPath = Join-Path $workRoot 'OEL1_WORKER_INHERITANCE_GATE.json'
$sourceSha256 = '750022568C62C2C049D04CE0D49E2FD52B5030A9701D8E453152129EB48D6F08'
$targetSha256 = '1CE01F67083A989CB92AE3824DB0AE2CB6532FD6B674E74456CC495F06DCDDF8'
$fic1RouteGateSha256 = '32AFF1FD7DCC1FA96A9C245FB3385EC7C01484B03B6A70C01C3F92064C0C8C83'

function Get-Sha([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
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
    if (@($errors).Count -ne 0) { throw "OEL1 inheritance parser failure: $Path" }
    $map = @{}
    foreach ($node in @($ast.FindAll({ param($candidate) $candidate -is [Management.Automation.Language.FunctionDefinitionAst] }, $true))) {
        if ($map.ContainsKey($node.Name)) { throw "Duplicate function in OEL1 worker: $($node.Name)" }
        $map[$node.Name] = Get-TextSha $node.Extent.Text
    }
    return $map
}

$required = @($sourcePath, $targetPath, $fic1RouteGatePath)
foreach ($path in $required) { if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "OEL1 inheritance prerequisite is missing: $path" } }
if ((Get-Sha $sourcePath) -ne $sourceSha256) { throw 'OEL1 inheritance source worker changed.' }
if ((Get-Sha $targetPath) -ne $targetSha256) { throw 'OEL1 inheritance target worker changed.' }
if ((Get-Sha $fic1RouteGatePath) -ne $fic1RouteGateSha256) { throw 'OEL1 inherited FIC1 route gate changed.' }
$fic1Gate = Get-Content -LiteralPath $fic1RouteGatePath -Raw | ConvertFrom-Json
if ([string]$fic1Gate.state -ne 'PASS_FIC1_COMPLETE_ROUTE_GATE' -or [string]$fic1Gate.endpointWorkerTargetSha256 -ne $sourceSha256 -or -not [bool]$fic1Gate.exactFinalZipExtractionPassed -or -not [bool]$fic1Gate.exactFinalZipSignaturePassed) { throw 'OEL1 inherited FIC1 endpoint qualification changed.' }

$sourceFunctions = Get-FunctionMap $sourcePath
$targetFunctions = Get-FunctionMap $targetPath
$sourceNames = @($sourceFunctions.Keys | Sort-Object)
$targetNames = @($targetFunctions.Keys | Sort-Object)
$addedNames = @($targetNames | Where-Object { -not $sourceFunctions.ContainsKey($_) })
$removedNames = @($sourceNames | Where-Object { -not $targetFunctions.ContainsKey($_) })
$changedNames = @($sourceNames | Where-Object { $targetFunctions.ContainsKey($_) -and [string]$sourceFunctions[$_] -ne [string]$targetFunctions[$_] })
if ($addedNames.Count -ne 0) { throw 'OEL1 added a predecessor worker function.' }
if ($removedNames.Count -ne 0) { throw 'OEL1 removed a predecessor worker function.' }
if ($changedNames.Count -ne 1 -or $changedNames[0] -ne 'Get-EnvironmentInventory') { throw 'OEL1 changed-function set escaped the generic metadata inventory provider.' }
$unchangedNames = @($sourceNames | Where-Object { $_ -ne 'Get-EnvironmentInventory' })
if ($unchangedNames.Count -ne 22) { throw "OEL1 unchanged-function cardinality changed: $($unchangedNames.Count)" }
if ([string]$sourceFunctions['Invoke-DataPullHandler'] -ne [string]$targetFunctions['Invoke-DataPullHandler']) { throw 'OEL1 DATA_PULL handler changed.' }
if ([string]$sourceFunctions['Process-One'] -ne [string]$targetFunctions['Process-One']) { throw 'OEL1 queue state machine changed.' }
if ([string]$sourceFunctions['New-SignedResponse'] -ne [string]$targetFunctions['New-SignedResponse']) { throw 'OEL1 response construction changed.' }

$result = [ordered]@{
    schema = 'argos_oel1_worker_inheritance_gate_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = if ($Preflight) { 'PASS_OEL1_WORKER_INHERITANCE_PREFLIGHT' } else { 'PASS_OEL1_WORKER_INHERITANCE_GATE' }
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
if (Test-Path -LiteralPath $outputPath) { throw "OEL1 inheritance gate already exists: $outputPath" }
[IO.File]::WriteAllText($outputPath, (($result | ConvertTo-Json -Depth 8) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
$result.mutationsPerformed = $true
$result | ConvertTo-Json -Depth 8

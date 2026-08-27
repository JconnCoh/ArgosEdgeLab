#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$InvocationManifest,
    [switch]$Preflight,
    [switch]$Build
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Build)) { throw 'Specify exactly one of -Preflight or -Build.' }

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$source = Join-Path $project 'work\OPENCV_SCRIBE_O2D22\Test-O2D22Endpoint.ps1'
$target = Join-Path $PSScriptRoot 'Test-O2D23Endpoint.ps1'
$selfPinGate = Join-Path $PSScriptRoot 'O2D23_SELF_PIN_AND_LIVE_BRANCH_GATE.json'
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
$utf8 = New-Object Text.UTF8Encoding($false)

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-Sha256([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    $sha256 = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha256.ComputeHash($stream))).Replace('-','') }
    finally { $sha256.Dispose(); $stream.Dispose() }
}

$manifestPath = [IO.Path]::GetFullPath($InvocationManifest)
Assert-True ($manifestPath.StartsWith($PSScriptRoot.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) 'O2D23 endpoint-test builder manifest must remain under the exact draft root.'
Assert-True (Test-Path -LiteralPath $manifestPath -PathType Leaf) 'O2D23 endpoint-test builder manifest absent.'
$invocation = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
Assert-True ([string]$invocation.schema -eq 'argos_o2d23_endpoint_test_builder_invocation_v1') 'O2D23 endpoint-test builder invocation schema changed.'
Assert-True ([string]$invocation.revision -eq 'O2D23_20260827T035500000Z_3C97863D') 'O2D23 endpoint-test builder invocation revision changed.'
Assert-True (@($invocation.allowedActions).Count -eq 2 -and @($invocation.allowedActions) -contains 'Preflight' -and @($invocation.allowedActions) -contains 'Build') 'O2D23 endpoint-test builder action set changed.'
Assert-True (-not [bool]$invocation.jbodExecution -and [bool]$invocation.reviewOnly -and -not [bool]$invocation.productionRoutingEnabled) 'O2D23 endpoint-test builder authority changed.'

Assert-True (Test-Path -LiteralPath $source -PathType Leaf) 'O2D23 endpoint-test source absent.'
Assert-True ((Get-Sha256 $source) -eq 'F2EF5DE483B6B3033F5B582373AB9DC116138256C66B4E3DF706E06D4989F0EF') 'O2D23 endpoint-test source changed.'
Assert-True (Test-Path -LiteralPath $selfPinGate -PathType Leaf) 'O2D23 self-pin gate absent.'
Assert-True ((Get-Sha256 $selfPinGate) -eq 'F00DED7060A9E8FB269670B0D89AEEA50241A82D1E6C0D5B74571B9AB91E1FD5') 'O2D23 self-pin gate changed.'
Assert-True (-not (Test-Path -LiteralPath $target)) 'O2D23 endpoint-test target already exists.'

$text = [IO.File]::ReadAllText($source)
$pairs = @(
    @('O2D22_20260827T030200000Z_6C5C7F1F','O2D23_20260827T035500000Z_3C97863D'),
    @('6C5C7F1F','3C97863D'),
    @('O2D22','O2D23'),
    @('o2d22','o2d23'),
    @('Slot24','Slot25'),
    @('slot24','slot25'),
    @('SLOT24','SLOT25'),
    @('C3046E59AF78DC59C28B9557AE108BD62DBBF6528877D53981E27319566316C6','159BD82528E505DE69BDEEE4C3A3B29402BA9281939C57F6187587E9047D9740'),
    @('4E7F8287C426AF092B7432EFCC353C69A9FB73C06402FA4E513BA0AC57620D58','F00DED7060A9E8FB269670B0D89AEEA50241A82D1E6C0D5B74571B9AB91E1FD5')
)
foreach ($pair in $pairs) { $text = $text.Replace([string]$pair[0], [string]$pair[1]) }
$text = $text.Replace(
    "function Get-Sha256([string]`$Path) { return (Get-FileHash -LiteralPath `$Path -Algorithm SHA256).Hash }",
    "function Get-Sha256([string]`$Path) {`r`n    `$stream = [IO.File]::OpenRead(`$Path)`r`n    `$sha256 = [Security.Cryptography.SHA256]::Create()`r`n    try { return ([BitConverter]::ToString(`$sha256.ComputeHash(`$stream))).Replace('-','') }`r`n    finally { `$sha256.Dispose(); `$stream.Dispose() }`r`n}"
)

$pathResult = & $pathTool -CandidatePath $target -ProjectRoot $project -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
Assert-True ([string]$pathResult.state -eq 'PASS_PATH_BUDGET' -and @($pathResult.candidates).Count -eq 1) 'O2D23 endpoint-test path budget failed.'
$sha = [Security.Cryptography.SHA256]::Create()
try { $targetSha = ([BitConverter]::ToString($sha.ComputeHash([byte[]]$utf8.GetBytes($text)))).Replace('-','') }
finally { $sha.Dispose() }

if ($Preflight) {
    [ordered]@{schema='argos_o2d23_endpoint_test_builder_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D23_ENDPOINT_TEST_BUILDER_PREFLIGHT';targetSha256=$targetSha;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 4
    return
}

[IO.File]::WriteAllText($target, $text, $utf8)
Assert-True ((Get-Sha256 $target) -eq $targetSha) 'O2D23 endpoint-test target write changed.'
[ordered]@{schema='argos_o2d23_endpoint_test_builder_result_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D23_ENDPOINT_TEST_DRAFT_CREATED';targetSha256=$targetSha;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 4

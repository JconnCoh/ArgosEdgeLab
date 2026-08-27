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
$source = Join-Path $project 'work\OPENCV_SCRIBE_O2D22\MAINTENANCE_DEFINITION.json'
$target = Join-Path $PSScriptRoot 'MAINTENANCE_DEFINITION.json'
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
Assert-True ($manifestPath.StartsWith($PSScriptRoot.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) 'O2D23 definition-builder manifest must remain under the exact draft root.'
Assert-True (Test-Path -LiteralPath $manifestPath -PathType Leaf) 'O2D23 definition-builder manifest absent.'
$invocation = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
Assert-True ([string]$invocation.schema -eq 'argos_o2d23_definition_builder_invocation_v1') 'O2D23 definition-builder invocation schema changed.'
Assert-True ([string]$invocation.revision -eq 'O2D23_20260827T035500000Z_3C97863D') 'O2D23 definition-builder invocation revision changed.'
Assert-True (@($invocation.allowedActions).Count -eq 2 -and @($invocation.allowedActions) -contains 'Preflight' -and @($invocation.allowedActions) -contains 'Build') 'O2D23 definition-builder action set changed.'
Assert-True (-not [bool]$invocation.jbodExecution -and [bool]$invocation.reviewOnly -and -not [bool]$invocation.productionRoutingEnabled) 'O2D23 definition-builder authority changed.'

Assert-True (Test-Path -LiteralPath $source -PathType Leaf) 'O2D23 definition source absent.'
Assert-True ((Get-Sha256 $source) -eq '682F29824F052CFDF6C469473040309E6736D806015B50E9578B4CC8839FADC3') 'O2D23 definition source changed.'
$pins = @{
    'O2D23_SLOT25_JOB.json' = '08B84D4FD74F96E47548DDB5C38FA7F808D6002ADFC22BF8159F2654E74A3029'
    'Invoke-O2D23ScribeEndpoint.ps1' = '159BD82528E505DE69BDEEE4C3A3B29402BA9281939C57F6187587E9047D9740'
    'O2D23_ENTRYPOINT_TEST_GATE_R2.json' = '17EFFBE2B9557688BFD4181B3DC6F8F3E01687E0FF9FBC59DDA0967370B40CF1'
    'O2D23_SELF_PIN_AND_LIVE_BRANCH_GATE.json' = 'F00DED7060A9E8FB269670B0D89AEEA50241A82D1E6C0D5B74571B9AB91E1FD5'
}
foreach ($item in $pins.GetEnumerator()) {
    $path = Join-Path $PSScriptRoot $item.Key
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "O2D23 definition dependency absent: $path"
    Assert-True ((Get-Sha256 $path) -eq [string]$item.Value) "O2D23 definition dependency changed: $path"
}
Assert-True (-not (Test-Path -LiteralPath $target)) 'O2D23 definition target already exists.'

$text = [IO.File]::ReadAllText($source)
$pairs = @(
    @('O2D22_20260827T030200000Z_6C5C7F1F','O2D23_20260827T035500000Z_3C97863D'),
    @('6C5C7F1F2F9B83DB52DE57FDEA100A9724FA4DBEF11E7087AAD790BFD5F8A1AA','3C97863D38BAC782ED3C19EA314F40E83C6201C22AA2E13AE3B076AFD40506E1'),
    @('D709717C8BAFBF544DE2616262E2E7DF57A7D8B71F0B46163740AC1D5CA529F7','41678156414CA7E601FF65CC5098D4A5E2DFF02710C0D1288C498849635B7782'),
    @('227BF3F6409B3AB822E9D2091263F0BCA3A2B60F01C964816B0815B678F92EE5','08B84D4FD74F96E47548DDB5C38FA7F808D6002ADFC22BF8159F2654E74A3029'),
    @('C3046E59AF78DC59C28B9557AE108BD62DBBF6528877D53981E27319566316C6','159BD82528E505DE69BDEEE4C3A3B29402BA9281939C57F6187587E9047D9740'),
    @('B5881EA13C82A0D7D4F9D27C61846A63361C2D134A385905DB0B08E9B240FD48','17EFFBE2B9557688BFD4181B3DC6F8F3E01687E0FF9FBC59DDA0967370B40CF1'),
    @('4E7F8287C426AF092B7432EFCC353C69A9FB73C06402FA4E513BA0AC57620D58','F00DED7060A9E8FB269670B0D89AEEA50241A82D1E6C0D5B74571B9AB91E1FD5'),
    @('6C5C7F1F','3C97863D'),
    @('O2D22','O2D23'),
    @('o2d22','o2d23'),
    @('Slot24','Slot25'),
    @('slot24','slot25'),
    @('SLOT24','SLOT25')
)
foreach ($pair in $pairs) { $text = $text.Replace([string]$pair[0], [string]$pair[1]) }

$pathResult = & $pathTool -CandidatePath $target -ProjectRoot $project -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
Assert-True ([string]$pathResult.state -eq 'PASS_PATH_BUDGET') 'O2D23 definition path budget failed.'
$sha = [Security.Cryptography.SHA256]::Create()
try { $targetSha = ([BitConverter]::ToString($sha.ComputeHash([byte[]]$utf8.GetBytes($text)))).Replace('-','') }
finally { $sha.Dispose() }

if ($Preflight) {
    [ordered]@{schema='argos_o2d23_definition_builder_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D23_DEFINITION_BUILDER_PREFLIGHT';targetSha256=$targetSha;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 4
    return
}

[IO.File]::WriteAllText($target, $text, $utf8)
Assert-True ((Get-Sha256 $target) -eq $targetSha) 'O2D23 definition write changed.'
[ordered]@{schema='argos_o2d23_definition_builder_result_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D23_DEFINITION_DRAFT_CREATED';targetSha256=$targetSha;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 4

#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight, [switch]$Build)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Build)) { throw 'Specify exactly one of -Preflight or -Build.' }

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$source = Join-Path $project 'work\OPENCV_SCRIBE_O2D21\Test-O2D21Endpoint.ps1'
$target = Join-Path $PSScriptRoot 'Test-O2D22Endpoint.ps1'
$selfPinGate = Join-Path $PSScriptRoot 'O2D22_SELF_PIN_AND_LIVE_BRANCH_GATE.json'
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
$utf8 = New-Object Text.UTF8Encoding($false)

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-Sha256([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }

Assert-True (Test-Path -LiteralPath $source -PathType Leaf) 'O2D22 endpoint-test source absent.'
Assert-True ((Get-Sha256 $source) -eq 'E0013B2F5778F1642976559035EEA86771B41AFFAA9F5376E81CB78D5BDADF92') 'O2D22 endpoint-test source changed.'
Assert-True (Test-Path -LiteralPath $selfPinGate -PathType Leaf) 'O2D22 self-pin gate absent.'
Assert-True ((Get-Sha256 $selfPinGate) -eq '4E7F8287C426AF092B7432EFCC353C69A9FB73C06402FA4E513BA0AC57620D58') 'O2D22 self-pin gate changed.'
Assert-True (-not (Test-Path -LiteralPath $target)) 'O2D22 endpoint-test target already exists.'

$text = [IO.File]::ReadAllText($source)
$pairs = @(
    @('O2D21_20260827T023200000Z_8A9CFF90','O2D22_20260827T030200000Z_6C5C7F1F'),
    @('8A9CFF90','6C5C7F1F'),
    @('O2D21','O2D22'),
    @('o2d21','o2d22'),
    @('Slot23','Slot24'),
    @('slot23','slot24'),
    @('SLOT23','SLOT24'),
    @('7862116EA2520FE6E3EE1AF03DCFED1A9E926BB8375D80BCE658206DC3E48CEC','C3046E59AF78DC59C28B9557AE108BD62DBBF6528877D53981E27319566316C6'),
    @('81CC2310488026B8F30FB9F66C4C66CEBC17389AA4866E71E176135199789B44','4E7F8287C426AF092B7432EFCC353C69A9FB73C06402FA4E513BA0AC57620D58')
)
foreach ($pair in $pairs) { $text = $text.Replace([string]$pair[0], [string]$pair[1]) }

$pathResult = & $pathTool -CandidatePath $target -ProjectRoot $project -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
Assert-True ([string]$pathResult.state -eq 'PASS_PATH_BUDGET' -and @($pathResult.candidates).Count -eq 1) 'O2D22 endpoint-test path budget failed.'
$sha = [Security.Cryptography.SHA256]::Create()
try { $targetSha = ([BitConverter]::ToString($sha.ComputeHash([byte[]]$utf8.GetBytes($text)))).Replace('-','') }
finally { $sha.Dispose() }

if ($Preflight) {
    [ordered]@{schema='argos_o2d22_endpoint_test_builder_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D22_ENDPOINT_TEST_BUILDER_PREFLIGHT';targetSha256=$targetSha;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 4
    return
}

[IO.File]::WriteAllText($target, $text, $utf8)
Assert-True ((Get-Sha256 $target) -eq $targetSha) 'O2D22 endpoint-test target write changed.'
[ordered]@{schema='argos_o2d22_endpoint_test_builder_result_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D22_ENDPOINT_TEST_DRAFT_CREATED';targetSha256=$targetSha;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 4

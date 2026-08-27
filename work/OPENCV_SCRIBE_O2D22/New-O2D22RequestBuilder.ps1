#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight, [switch]$Build)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Build)) { throw 'Specify exactly one of -Preflight or -Build.' }

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$source = Join-Path $project 'work\OPENCV_SCRIBE_O2D21\Build-O2D21Request.ps1'
$target = Join-Path $PSScriptRoot 'Build-O2D22Request.ps1'
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
$utf8 = New-Object Text.UTF8Encoding($false)

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-Sha256([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }

Assert-True (Test-Path -LiteralPath $source -PathType Leaf) 'O2D22 request-builder source absent.'
Assert-True ((Get-Sha256 $source) -eq 'FEAAE4F901C5C6B0CE0BEB5D94FDCC525B7E833531155EFF28B43D4ECE706B62') 'O2D22 request-builder source changed.'
Assert-True (-not (Test-Path -LiteralPath $target)) 'O2D22 request-builder target already exists.'

$text = [IO.File]::ReadAllText($source)
$pairs = @(
    @('REQ_20260827T023200111Z_8A9CFF90BF26','REQ_20260827T030200111Z_6C5C7F1FBF26'),
    @('O2D21_20260827T023200000Z_8A9CFF90','O2D22_20260827T030200000Z_6C5C7F1F'),
    @('8A9CFF90BE426453220BEAE550016CF80C61FF5D782D24F2EF4C717CFE8ECF6A','6C5C7F1F2F9B83DB52DE57FDEA100A9724FA4DBEF11E7087AAD790BFD5F8A1AA'),
    @('CA82C2B0068F5DF847BAEC33AE6BE884C5CF1D5E43A45E910CA8818B4C5F5118','D709717C8BAFBF544DE2616262E2E7DF57A7D8B71F0B46163740AC1D5CA529F7'),
    @('7862116EA2520FE6E3EE1AF03DCFED1A9E926BB8375D80BCE658206DC3E48CEC','C3046E59AF78DC59C28B9557AE108BD62DBBF6528877D53981E27319566316C6'),
    @('2F0AE52E25459D4D64A698DF3AA10CAC670E640ED13068211F360400D4FBE233','227BF3F6409B3AB822E9D2091263F0BCA3A2B60F01C964816B0815B678F92EE5'),
    @('8E40FCFCC9D7BE6EEFEE7D3382E51F59C667D06074F095F7074C7C7CB189372D','682F29824F052CFDF6C469473040309E6736D806015B50E9578B4CC8839FADC3'),
    @('6737C358531CD06AFB4D513C3A3333E85905116292A581B5EFE3425275AAC2FB','B5881EA13C82A0D7D4F9D27C61846A63361C2D134A385905DB0B08E9B240FD48'),
    @('81CC2310488026B8F30FB9F66C4C66CEBC17389AA4866E71E176135199789B44','4E7F8287C426AF092B7432EFCC353C69A9FB73C06402FA4E513BA0AC57620D58'),
    @('6CCFAA254BFF4BC95E293A32B8F6D076F4808F97D9CA427A2D6A4ADDAE1201DF','78A8F884E3877C6677A1028E23BBD54F890172C7D706A4FFF31921E5AF5C22A9'),
    @('8A29FCBFC83F85E6BA514577619B71E072670416C71959D2EE1091EFDE705D7F','40A6A70324BF3D22AFD681CEBAF242B1ECBCA8C6656398B0687E8313054605FC'),
    @('C5141FFC6395C1D4B8E1286A964F397E084A832FC4BAF31151D534C3B1BBBC21','94019610E1E16397DDE1632177418C0C47682AE1A25790D54E4532B0EED80E7C'),
    @('7CBA5201FF661A016F96D5C1949C7FC894479211C7E288B7037B7DD8D3413B83','58C66C356CD19C73F7BA450BD6C9231E4E38C806BE3D086889D1F7ADBCBEC900'),
    @('8A9CFF90','6C5C7F1F'),
    @('O2D21','O2D22'),
    @('o2d21','o2d22'),
    @('O2D20','O2D21'),
    @('o2d20','o2d21'),
    @('Slot23','Slot24'),
    @('slot23','slot24'),
    @('SLOT23','SLOT24'),
    @('Slot22','Slot23'),
    @('slot22','slot23'),
    @('SLOT22','SLOT23')
)
foreach ($pair in $pairs) { $text = $text.Replace([string]$pair[0], [string]$pair[1]) }

$pathResult = & $pathTool -CandidatePath $target -ProjectRoot $project -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
Assert-True ([string]$pathResult.state -eq 'PASS_PATH_BUDGET') 'O2D22 request-builder path budget failed.'
$sha = [Security.Cryptography.SHA256]::Create()
try { $targetSha = ([BitConverter]::ToString($sha.ComputeHash([byte[]]$utf8.GetBytes($text)))).Replace('-','') }
finally { $sha.Dispose() }

if ($Preflight) {
    [ordered]@{schema='argos_o2d22_request_builder_generator_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D22_REQUEST_BUILDER_GENERATOR_PREFLIGHT';targetSha256=$targetSha;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 4
    return
}

[IO.File]::WriteAllText($target, $text, $utf8)
Assert-True ((Get-Sha256 $target) -eq $targetSha) 'O2D22 request-builder write changed.'
[ordered]@{schema='argos_o2d22_request_builder_generator_result_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D22_REQUEST_BUILDER_DRAFT_CREATED';targetSha256=$targetSha;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 4

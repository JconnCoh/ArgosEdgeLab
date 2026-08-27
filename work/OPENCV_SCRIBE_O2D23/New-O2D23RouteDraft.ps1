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
$sourceRoot = Join-Path $project 'work\OPENCV_SCRIBE_O2D22'
$routeSource = Join-Path $sourceRoot 'Test-O2D22Routes.ps1'
$shareSource = Join-Path $sourceRoot 'Get-O2D22CurrentShareObservation.ps1'
$routeTarget = Join-Path $PSScriptRoot 'Test-O2D23Routes.ps1'
$shareTarget = Join-Path $PSScriptRoot 'Get-O2D23CurrentShareObservation.ps1'
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
Assert-True ($manifestPath.StartsWith($PSScriptRoot.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) 'O2D23 route-draft invocation manifest must remain under the exact draft root.'
Assert-True (Test-Path -LiteralPath $manifestPath -PathType Leaf) 'O2D23 route-draft invocation manifest absent.'
$invocation = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
Assert-True ([string]$invocation.schema -eq 'argos_o2d23_route_draft_invocation_v1') 'O2D23 route-draft invocation schema changed.'
Assert-True ([string]$invocation.revision -eq 'O2D23_20260827T035500000Z_3C97863D') 'O2D23 route-draft invocation revision changed.'
Assert-True (@($invocation.allowedActions).Count -eq 2 -and @($invocation.allowedActions) -contains 'Preflight' -and @($invocation.allowedActions) -contains 'Build') 'O2D23 route-draft invocation action set changed.'
Assert-True ([int]$invocation.maximumPublications -eq 1 -and -not [bool]$invocation.retryAuthorized -and [bool]$invocation.reviewOnly -and -not [bool]$invocation.productionRoutingEnabled) 'O2D23 route-draft authority changed.'

Assert-True ((Get-Sha256 $routeSource) -eq 'F0A934DFE5B0AFC02D5523985E72916EB315A65AA060C582DF73FA56B79DEF89') 'O2D23 route-test source changed.'
Assert-True ((Get-Sha256 $shareSource) -eq '67762122FE56E688535125DC9C7222025AFD0107CA3B691BDF49C552C034CC97') 'O2D23 share-observation source changed.'
Assert-True ((Get-Sha256 (Join-Path $PSScriptRoot 'O2D23_FINAL_PACKAGE_GATE.json')) -eq '532CCF66A5BC1ACE7B2C3FBE844D50B876E13F91CEC04C20D953D494604C8B50') 'O2D23 final package gate changed.'
Assert-True (-not (Test-Path -LiteralPath $routeTarget) -and -not (Test-Path -LiteralPath $shareTarget)) 'O2D23 route-draft target already exists.'

function Convert-Common([string]$Text) {
    $value = $Text
    $pairs = @(
        @('REQ_20260827T030200111Z_6C5C7F1FBF26','REQ_20260827T035500111Z_3C97863DBF26'),
        @('O2D22_20260827T030200000Z_6C5C7F1F','O2D23_20260827T035500000Z_3C97863D'),
        @('12B1BB2C91E7663A7115231FCC0B2FEBC2112AA03D47551A1ECDD6E44BBF5EEC','532CCF66A5BC1ACE7B2C3FBE844D50B876E13F91CEC04C20D953D494604C8B50'),
        @('C3046E59AF78DC59C28B9557AE108BD62DBBF6528877D53981E27319566316C6','159BD82528E505DE69BDEEE4C3A3B29402BA9281939C57F6187587E9047D9740'),
        @('B5881EA13C82A0D7D4F9D27C61846A63361C2D134A385905DB0B08E9B240FD48','17EFFBE2B9557688BFD4181B3DC6F8F3E01687E0FF9FBC59DDA0967370B40CF1'),
        @('4E7F8287C426AF092B7432EFCC353C69A9FB73C06402FA4E513BA0AC57620D58','F00DED7060A9E8FB269670B0D89AEEA50241A82D1E6C0D5B74571B9AB91E1FD5'),
        @('6C5C7F1F2F9B83DB52DE57FDEA100A9724FA4DBEF11E7087AAD790BFD5F8A1AA','3C97863D38BAC782ED3C19EA314F40E83C6201C22AA2E13AE3B076AFD40506E1'),
        @('D709717C8BAFBF544DE2616262E2E7DF57A7D8B71F0B46163740AC1D5CA529F7','41678156414CA7E601FF65CC5098D4A5E2DFF02710C0D1288C498849635B7782'),
        @('6C5C7F1F','3C97863D'),
        @('O2D22','O2D23'),
        @('o2d22','o2d23'),
        @('O2D21','O2D22'),
        @('o2d21','o2d22'),
        @('Slot24','Slot25'),
        @('slot24','slot25'),
        @('SLOT24','SLOT25'),
        @('Slot23','Slot24'),
        @('slot23','slot24'),
        @('SLOT23','SLOT24')
    )
    foreach ($pair in $pairs) { $value = $value.Replace([string]$pair[0], [string]$pair[1]) }
    return $value.Replace(
        "function Get-Sha256([string]`$Path) { return (Get-FileHash -LiteralPath `$Path -Algorithm SHA256).Hash }",
        "function Get-Sha256([string]`$Path) {`r`n    `$stream = [IO.File]::OpenRead(`$Path)`r`n    `$sha256 = [Security.Cryptography.SHA256]::Create()`r`n    try { return ([BitConverter]::ToString(`$sha256.ComputeHash(`$stream))).Replace('-','') }`r`n    finally { `$sha256.Dispose(); `$stream.Dispose() }`r`n}"
    )
}

$routeText = Convert-Common ([IO.File]::ReadAllText($routeSource))
$routeText = $routeText.Replace(
    "function Write-JsonNew([string]`$Path, [object]`$Value, [int]`$Depth = 24) {",
    "function Get-FileHash {`r`n    param([Parameter(Mandatory=`$true)][string]`$LiteralPath,[Parameter(Mandatory=`$true)][ValidateSet('SHA256')][string]`$Algorithm)`r`n    return [pscustomobject]@{ Hash = Get-Sha256 `$LiteralPath; Algorithm = `$Algorithm; Path = `$LiteralPath }`r`n}`r`nfunction Write-JsonNew([string]`$Path, [object]`$Value, [int]`$Depth = 24) {"
)
$shareText = Convert-Common ([IO.File]::ReadAllText($shareSource))
$shareText = $shareText.Replace('R_0625466C6A6C_20260827024747655_661acb16','R_C74B050C0F51_20260827034006298_4d459405').Replace('8A249AD8ACDFCFBA75F2815FF1EFCC1B0A9762C447BB9DC7A777F39629FCF491','D68EF3002168396B993A25C4BD37C4EDB7A54BC6811129936FBCA8A82E33BD42').Replace('Length -eq 3686','Length -eq 3736').Replace('priorO2D22ResponseBytes=3686','priorO2D22ResponseBytes=3736')

$pathResult = & $pathTool -CandidatePath @($routeTarget,$shareTarget) -ProjectRoot $project -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
Assert-True ([string]$pathResult.state -eq 'PASS_PATH_BUDGET' -and @($pathResult.candidates).Count -eq 2) 'O2D23 route-draft path budget failed.'
function Get-TextSha([string]$Text) {
    $sha256 = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha256.ComputeHash([byte[]]$utf8.GetBytes($Text)))).Replace('-','') }
    finally { $sha256.Dispose() }
}
$routeSha = Get-TextSha $routeText
$shareSha = Get-TextSha $shareText

if ($Preflight) {
    [ordered]@{schema='argos_o2d23_route_draft_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D23_ROUTE_DRAFT_PREFLIGHT';routeSha256=$routeSha;shareSha256=$shareSha;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 4
    return
}

[IO.File]::WriteAllText($routeTarget, $routeText, $utf8)
[IO.File]::WriteAllText($shareTarget, $shareText, $utf8)
Assert-True ((Get-Sha256 $routeTarget) -eq $routeSha -and (Get-Sha256 $shareTarget) -eq $shareSha) 'O2D23 route-draft write changed.'
[ordered]@{schema='argos_o2d23_route_draft_result_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D23_ROUTE_DRAFT_CREATED';routeSha256=$routeSha;shareSha256=$shareSha;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 4

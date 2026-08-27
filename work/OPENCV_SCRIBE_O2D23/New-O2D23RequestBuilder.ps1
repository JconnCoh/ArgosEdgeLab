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
$source = Join-Path $project 'work\OPENCV_SCRIBE_O2D22\Build-O2D22Request.ps1'
$target = Join-Path $PSScriptRoot 'Build-O2D23Request.ps1'
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
Assert-True ($manifestPath.StartsWith($PSScriptRoot.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) 'O2D23 request-builder generator manifest must remain under the exact draft root.'
Assert-True (Test-Path -LiteralPath $manifestPath -PathType Leaf) 'O2D23 request-builder generator manifest absent.'
$invocation = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
Assert-True ([string]$invocation.schema -eq 'argos_o2d23_request_builder_generator_invocation_v1') 'O2D23 request-builder generator invocation schema changed.'
Assert-True ([string]$invocation.revision -eq 'O2D23_20260827T035500000Z_3C97863D') 'O2D23 request-builder generator revision changed.'
Assert-True (@($invocation.allowedActions).Count -eq 2 -and @($invocation.allowedActions) -contains 'Preflight' -and @($invocation.allowedActions) -contains 'Build') 'O2D23 request-builder generator action set changed.'
Assert-True (-not [bool]$invocation.jbodExecution -and [bool]$invocation.reviewOnly -and -not [bool]$invocation.productionRoutingEnabled) 'O2D23 request-builder generator authority changed.'

Assert-True (Test-Path -LiteralPath $source -PathType Leaf) 'O2D23 request-builder source absent.'
Assert-True ((Get-Sha256 $source) -eq '3A6082D8EC86E8D6F6EA3D0D99D5D1A0E4DCFC63498B01A94FD5A1FB126653B7') 'O2D23 request-builder source changed.'
Assert-True (-not (Test-Path -LiteralPath $target)) 'O2D23 request-builder target already exists.'

$text = [IO.File]::ReadAllText($source)
$pairs = @(
    @('REQ_20260827T030200111Z_6C5C7F1FBF26','REQ_20260827T035500111Z_3C97863DBF26'),
    @('O2D22_20260827T030200000Z_6C5C7F1F','O2D23_20260827T035500000Z_3C97863D'),
    @('6C5C7F1F2F9B83DB52DE57FDEA100A9724FA4DBEF11E7087AAD790BFD5F8A1AA','3C97863D38BAC782ED3C19EA314F40E83C6201C22AA2E13AE3B076AFD40506E1'),
    @('D709717C8BAFBF544DE2616262E2E7DF57A7D8B71F0B46163740AC1D5CA529F7','41678156414CA7E601FF65CC5098D4A5E2DFF02710C0D1288C498849635B7782'),
    @('C3046E59AF78DC59C28B9557AE108BD62DBBF6528877D53981E27319566316C6','159BD82528E505DE69BDEEE4C3A3B29402BA9281939C57F6187587E9047D9740'),
    @('227BF3F6409B3AB822E9D2091263F0BCA3A2B60F01C964816B0815B678F92EE5','08B84D4FD74F96E47548DDB5C38FA7F808D6002ADFC22BF8159F2654E74A3029'),
    @('682F29824F052CFDF6C469473040309E6736D806015B50E9578B4CC8839FADC3','17C3D8046E4C74383B3985AACDFDEA1E8FDF61EE215B290A44587083D2AA95AF'),
    @('B5881EA13C82A0D7D4F9D27C61846A63361C2D134A385905DB0B08E9B240FD48','17EFFBE2B9557688BFD4181B3DC6F8F3E01687E0FF9FBC59DDA0967370B40CF1'),
    @('4E7F8287C426AF092B7432EFCC353C69A9FB73C06402FA4E513BA0AC57620D58','F00DED7060A9E8FB269670B0D89AEEA50241A82D1E6C0D5B74571B9AB91E1FD5'),
    @('78A8F884E3877C6677A1028E23BBD54F890172C7D706A4FFF31921E5AF5C22A9','E83611A70DE1DEF20DC11F8036AB2224E088E96C410817B5D38723ECB2D07B7E'),
    @('40A6A70324BF3D22AFD681CEBAF242B1ECBCA8C6656398B0687E8313054605FC','90ABE4E37A74EED80EC7D2F82296D1B101E2F655A2AB7F909D5D525F5B34D7F2'),
    @('94019610E1E16397DDE1632177418C0C47682AE1A25790D54E4532B0EED80E7C','58F7D5412EB39872C19F31332E261EFA5E99B4161EDDDF6498F07BD70651FF35'),
    @('58C66C356CD19C73F7BA450BD6C9231E4E38C806BE3D086889D1F7ADBCBEC900','4219177E0B2F1CBE9FAF36B53F5108D749D302E09A9A2806CBDA066EB9CEDBD7'),
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
foreach ($pair in $pairs) { $text = $text.Replace([string]$pair[0], [string]$pair[1]) }
$text = $text.Replace(
    "function Get-Sha256([string]`$Path) { return (Get-FileHash -LiteralPath `$Path -Algorithm SHA256).Hash }",
    "function Get-Sha256([string]`$Path) {`r`n    `$stream = [IO.File]::OpenRead(`$Path)`r`n    `$sha256 = [Security.Cryptography.SHA256]::Create()`r`n    try { return ([BitConverter]::ToString(`$sha256.ComputeHash(`$stream))).Replace('-','') }`r`n    finally { `$sha256.Dispose(); `$stream.Dispose() }`r`n}`r`nfunction Get-FileHash {`r`n    param([Parameter(Mandatory=`$true)][string]`$LiteralPath,[Parameter(Mandatory=`$true)][ValidateSet('SHA256')][string]`$Algorithm)`r`n    return [pscustomobject]@{ Hash = Get-Sha256 `$LiteralPath; Algorithm = `$Algorithm; Path = `$LiteralPath }`r`n}"
)
$text = $text.Replace(
    "`$cloneGatePath = Join-Path `$root 'O2D23_CLONE_LITERAL_GATE_FINAL.json'",
    "`$cloneGatePath = Join-Path `$root 'O2D23_CLONE_LITERAL_GATE_FINAL_R3.json'"
).Replace(
    "`$preactionJson = & `$windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File `$preactionTool",
    "`$preactionJson = & `$preactionTool"
)
$text = $text.Replace(
    "`$certificate = Get-Item -LiteralPath (`"Cert:\CurrentUser\My\`$thumbprint`") -ErrorAction Stop`r`nAssert-True (`$certificate.HasPrivateKey) 'O2D23 signer private key unavailable.'",
    "`$store = New-Object Security.Cryptography.X509Certificates.X509Store('My', [Security.Cryptography.X509Certificates.StoreLocation]::CurrentUser)`r`n`$store.Open([Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)`r`ntry {`r`n    `$certificateMatches = @(`$store.Certificates | Where-Object { ([string]`$_.Thumbprint).Replace(' ', '').ToUpperInvariant() -eq `$thumbprint })`r`n    Assert-True (`$certificateMatches.Count -eq 1) 'O2D23 signer certificate cardinality changed.'`r`n    `$certificate = `$certificateMatches[0]`r`n}`r`nfinally {`r`n    `$store.Close()`r`n    `$store.Dispose()`r`n}`r`nAssert-True (`$certificate.HasPrivateKey) 'O2D23 signer private key unavailable.'"
)
$text = $text.Replace(
    'publicationRequiresCompleteRouteGate=$true;publicationAuthorized=$false;targetExecuted=$false;sourceImageBytesRead=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false',
    "validationQualification='INDEPENDENT_VALIDATION_OUTCOME_BLIND_METADATA_DISCLOSED';slot25SourceMetadataPrematurelyExposed=`$true;slot25ImageBytesRead=`$false;slot25OutcomeSeen=`$false;maximumPublications=1;retryAuthorized=`$false;publicationRequiresCompleteRouteGate=`$true;publicationAuthorized=`$false;targetExecuted=`$false;sourceImageBytesRead=`$false;providerActivated=`$false;reviewOnly=`$true;productionRoutingEnabled=`$false"
)

$pathResult = & $pathTool -CandidatePath $target -ProjectRoot $project -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
Assert-True ([string]$pathResult.state -eq 'PASS_PATH_BUDGET') 'O2D23 request-builder path budget failed.'
$sha = [Security.Cryptography.SHA256]::Create()
try { $targetSha = ([BitConverter]::ToString($sha.ComputeHash([byte[]]$utf8.GetBytes($text)))).Replace('-','') }
finally { $sha.Dispose() }

if ($Preflight) {
    [ordered]@{schema='argos_o2d23_request_builder_generator_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D23_REQUEST_BUILDER_GENERATOR_PREFLIGHT';targetSha256=$targetSha;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 4
    return
}

[IO.File]::WriteAllText($target, $text, $utf8)
Assert-True ((Get-Sha256 $target) -eq $targetSha) 'O2D23 request-builder write changed.'
[ordered]@{schema='argos_o2d23_request_builder_generator_result_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D23_REQUEST_BUILDER_DRAFT_CREATED';targetSha256=$targetSha;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 4

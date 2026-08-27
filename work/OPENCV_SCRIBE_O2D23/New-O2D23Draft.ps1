#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$InvocationManifest,
    [switch]$Preflight,
    [switch]$Core
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Core)) { throw 'Specify exactly one of -Preflight or -Core.' }

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$sourceRoot = Join-Path $project 'work\OPENCV_SCRIBE_O2D22'
$targetRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
$utf8 = New-Object Text.UTF8Encoding($false)

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-Sha256([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    $sha256 = [Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($sha256.ComputeHash($stream))).Replace('-','')
    }
    finally {
        $sha256.Dispose()
        $stream.Dispose()
    }
}

$manifestPath = [IO.Path]::GetFullPath($InvocationManifest)
Assert-True ($manifestPath.StartsWith($targetRoot.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) 'O2D23 invocation manifest must remain under the exact draft root.'
Assert-True (Test-Path -LiteralPath $manifestPath -PathType Leaf) 'O2D23 invocation manifest is absent.'
Assert-True ((Get-Item -LiteralPath $manifestPath).Length -le 16384) 'O2D23 invocation manifest exceeds 16 KiB.'
$invocation = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
Assert-True ([string]$invocation.schema -eq 'argos_o2d23_draft_invocation_v1') 'O2D23 invocation schema changed.'
Assert-True ([string]$invocation.revision -eq 'O2D23_20260827T035500000Z_3C97863D') 'O2D23 invocation revision changed.'
Assert-True ([string]$invocation.script -eq 'work/OPENCV_SCRIBE_O2D23/New-O2D23Draft.ps1') 'O2D23 invocation script changed.'
Assert-True (@($invocation.allowedActions).Count -eq 2 -and @($invocation.allowedActions) -contains 'Preflight' -and @($invocation.allowedActions) -contains 'Core') 'O2D23 invocation action set changed.'
Assert-True (-not [bool]$invocation.jbodExecution -and [bool]$invocation.reviewOnly -and -not [bool]$invocation.productionRoutingEnabled) 'O2D23 invocation authority changed.'

function Read-Pinned([string]$RelativePath, [string]$Sha256) {
    $path = Join-Path $sourceRoot $RelativePath
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "O2D23 source absent: $path"
    Assert-True ((Get-Sha256 $path) -eq $Sha256) "O2D23 source changed: $path"
    return [IO.File]::ReadAllText($path)
}

function Convert-O2D22Text([string]$Text) {
    $value = $Text
    $pairs = @(
        @('REQ_20260827T030200111Z_6C5C7F1FBF26','REQ_20260827T035500111Z_3C97863DBF26'),
        @('O2D22_20260827T030200000Z_6C5C7F1F','O2D23_20260827T035500000Z_3C97863D'),
        @('6C5C7F1F2F9B83DB52DE57FDEA100A9724FA4DBEF11E7087AAD790BFD5F8A1AA','3C97863D38BAC782ED3C19EA314F40E83C6201C22AA2E13AE3B076AFD40506E1'),
        @('D709717C8BAFBF544DE2616262E2E7DF57A7D8B71F0B46163740AC1D5CA529F7','41678156414CA7E601FF65CC5098D4A5E2DFF02710C0D1288C498849635B7782'),
        @('2026-08-27T01:25:05Z','2026-08-27T03:55:00Z'),
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
    return $value
}

function Write-NewUtf8([string]$Path, [string]$Text) {
    Assert-True (-not (Test-Path -LiteralPath $Path)) "O2D23 create-new target exists: $Path"
    [IO.File]::WriteAllText($Path, $Text, $utf8)
}

$jobSource = Read-Pinned 'O2D22_SLOT24_JOB.json' '227BF3F6409B3AB822E9D2091263F0BCA3A2B60F01C964816B0815B678F92EE5'
$endpointSource = Read-Pinned 'Invoke-O2D22ScribeEndpoint.ps1' 'C3046E59AF78DC59C28B9557AE108BD62DBBF6528877D53981E27319566316C6'
$installationSource = Read-Pinned 'fixtures\INSTALLATION.json' 'EFCD91F32037ADA1276AB54BE0E1A0D9B7E5F16AE433A1C9F2CE627150DDDE71'
$goodSource = Read-Pinned 'fixtures\LIVE_CONTRACT_GOOD.json' 'C069184E4C3F9B951FCE96BBF6627EB5F03DF526C186F731FF2D0634FED4602F'
$badJobSource = Read-Pinned 'fixtures\LIVE_CONTRACT_BAD_JOB.json' 'C8B05681574FF0EFEB9E074C3FA939306374A601B6EDB61483EF8571B30138C9'
$badInstallationSource = Read-Pinned 'fixtures\LIVE_CONTRACT_BAD_INSTALLATION.json' 'FC3EFE390C3B92AE93C9C9A5B3CBED7BBE4766ED1890FE5FBF2CD6EECD8CDEAA'
$selfPinsSource = Read-Pinned 'Test-O2D22SelfPins.ps1' '5A083CDFE0A3B4244EA7A630544D1AAD541EB8C4B827EF4EDE7431FC4E6B5C47'
$noArgumentSource = Read-Pinned 'Test-O2D22NoArgumentFile.ps1' 'F27309CD676E924C4C4A1D137A9706770E007D7AEC516EE28E9791CA5983668F'

$jobTarget = Join-Path $targetRoot 'O2D23_SLOT25_JOB.json'
$endpointTarget = Join-Path $targetRoot 'Invoke-O2D23ScribeEndpoint.ps1'
$fixtureRoot = Join-Path $targetRoot 'fixtures'
$installationTarget = Join-Path $fixtureRoot 'INSTALLATION.json'
$goodTarget = Join-Path $fixtureRoot 'LIVE_CONTRACT_GOOD.json'
$badJobTarget = Join-Path $fixtureRoot 'LIVE_CONTRACT_BAD_JOB.json'
$badInstallationTarget = Join-Path $fixtureRoot 'LIVE_CONTRACT_BAD_INSTALLATION.json'
$selfPinsTarget = Join-Path $targetRoot 'Test-O2D23SelfPins.ps1'
$noArgumentTarget = Join-Path $targetRoot 'Test-O2D23NoArgumentFile.ps1'
$targets = @($jobTarget,$endpointTarget,$installationTarget,$goodTarget,$badJobTarget,$badInstallationTarget,$selfPinsTarget,$noArgumentTarget)
foreach ($path in $targets) { Assert-True (-not (Test-Path -LiteralPath $path)) "O2D23 create-new target exists: $path" }

$pathResult = & $pathTool -CandidatePath $targets -ProjectRoot $project -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
Assert-True ([string]$pathResult.state -eq 'PASS_PATH_BUDGET' -and @($pathResult.candidates).Count -eq $targets.Count) 'O2D23 core path budget failed.'

$jobText = Convert-O2D22Text $jobSource
$jobBytes = $utf8.GetBytes($jobText)
$sha = [Security.Cryptography.SHA256]::Create()
try { $jobSha = ([BitConverter]::ToString($sha.ComputeHash([byte[]]$jobBytes))).Replace('-','') }
finally { $sha.Dispose() }

$endpointText = (Convert-O2D22Text $endpointSource).Replace(
    '227BF3F6409B3AB822E9D2091263F0BCA3A2B60F01C964816B0815B678F92EE5',
    $jobSha
)
$endpointBytes = $utf8.GetBytes($endpointText)
$sha = [Security.Cryptography.SHA256]::Create()
try { $endpointSha = ([BitConverter]::ToString($sha.ComputeHash([byte[]]$endpointBytes))).Replace('-','') }
finally { $sha.Dispose() }

$installationText = Convert-O2D22Text $installationSource
$installationBytes = $utf8.GetBytes($installationText)
$sha = [Security.Cryptography.SHA256]::Create()
try { $installationSha = ([BitConverter]::ToString($sha.ComputeHash([byte[]]$installationBytes))).Replace('-','') }
finally { $sha.Dispose() }

function Convert-Fixture([string]$Text) {
    return (Convert-O2D22Text $Text).Replace(
        '227BF3F6409B3AB822E9D2091263F0BCA3A2B60F01C964816B0815B678F92EE5',
        $jobSha
    ).Replace(
        'EFCD91F32037ADA1276AB54BE0E1A0D9B7E5F16AE433A1C9F2CE627150DDDE71',
        $installationSha
    )
}

$selfPinsText = (Convert-O2D22Text $selfPinsSource).Replace(
    "function Get-Sha256([string]`$Path) { return (Get-FileHash -LiteralPath `$Path -Algorithm SHA256).Hash }",
    "function Get-Sha256([string]`$Path) {`r`n    `$stream = [IO.File]::OpenRead(`$Path)`r`n    `$sha256 = [Security.Cryptography.SHA256]::Create()`r`n    try { return ([BitConverter]::ToString(`$sha256.ComputeHash(`$stream))).Replace('-','') }`r`n    finally { `$sha256.Dispose(); `$stream.Dispose() }`r`n}"
)
$noArgumentText = (Convert-O2D22Text $noArgumentSource).Replace(
    'C3046E59AF78DC59C28B9557AE108BD62DBBF6528877D53981E27319566316C6',
    $endpointSha
)
$noArgumentText = $noArgumentText.Replace(
    "function Write-JsonNew([string]`$Path, [object]`$Value) {",
    "function Get-Sha256([string]`$Path) {`r`n    `$stream = [IO.File]::OpenRead(`$Path)`r`n    `$sha256 = [Security.Cryptography.SHA256]::Create()`r`n    try { return ([BitConverter]::ToString(`$sha256.ComputeHash(`$stream))).Replace('-','') }`r`n    finally { `$sha256.Dispose(); `$stream.Dispose() }`r`n}`r`nfunction Write-JsonNew([string]`$Path, [object]`$Value) {"
).Replace(
    '(Get-FileHash -LiteralPath $endpoint -Algorithm SHA256).Hash',
    '(Get-Sha256 $endpoint)'
)

if ($Preflight) {
    [ordered]@{
        schema='argos_o2d23_draft_generator_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D23_DRAFT_GENERATOR_PREFLIGHT'
        phase='CORE';targetCount=$targets.Count;jobSha256=$jobSha;endpointSha256=$endpointSha;installationFixtureSha256=$installationSha
        pathState=[string]$pathResult.state;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false
    } | ConvertTo-Json -Depth 5
    return
}

[void][IO.Directory]::CreateDirectory($fixtureRoot)
Write-NewUtf8 $jobTarget $jobText
Write-NewUtf8 $endpointTarget $endpointText
Write-NewUtf8 $installationTarget $installationText
Write-NewUtf8 $goodTarget (Convert-Fixture $goodSource)
Write-NewUtf8 $badJobTarget (Convert-Fixture $badJobSource)
Write-NewUtf8 $badInstallationTarget (Convert-Fixture $badInstallationSource)
Write-NewUtf8 $selfPinsTarget $selfPinsText
Write-NewUtf8 $noArgumentTarget $noArgumentText

[ordered]@{
    schema='argos_o2d23_draft_generator_result_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D23_CORE_DRAFT_CREATED'
    targetCount=$targets.Count;jobSha256=Get-Sha256 $jobTarget;endpointSha256=Get-Sha256 $endpointTarget
    installationFixtureSha256=Get-Sha256 $installationTarget;reviewOnly=$true;productionRoutingEnabled=$false
} | ConvertTo-Json -Depth 5

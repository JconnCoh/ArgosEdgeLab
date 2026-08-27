#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Core
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Core)) { throw 'Specify exactly one of -Preflight or -Core.' }

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$sourceRoot = Join-Path $project 'work\OPENCV_SCRIBE_O2D21'
$targetRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
$utf8 = New-Object Text.UTF8Encoding($false)

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Read-Pinned([string]$RelativePath, [string]$Sha256) {
    $path = Join-Path $sourceRoot $RelativePath
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "O2D22 source absent: $path"
    Assert-True ((Get-Sha256 $path) -eq $Sha256) "O2D22 source changed: $path"
    return [IO.File]::ReadAllText($path)
}

function Convert-O2D21Text([string]$Text) {
    $value = $Text
    $pairs = @(
        @('REQ_20260827T023200111Z_8A9CFF90BF26','REQ_20260827T030200111Z_6C5C7F1FBF26'),
        @('O2D21_20260827T023200000Z_8A9CFF90','O2D22_20260827T030200000Z_6C5C7F1F'),
        @('8A9CFF90BE426453220BEAE550016CF80C61FF5D782D24F2EF4C717CFE8ECF6A','6C5C7F1F2F9B83DB52DE57FDEA100A9724FA4DBEF11E7087AAD790BFD5F8A1AA'),
        @('CA82C2B0068F5DF847BAEC33AE6BE884C5CF1D5E43A45E910CA8818B4C5F5118','D709717C8BAFBF544DE2616262E2E7DF57A7D8B71F0B46163740AC1D5CA529F7'),
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
    foreach ($pair in $pairs) { $value = $value.Replace([string]$pair[0], [string]$pair[1]) }
    return $value
}

function Write-NewUtf8([string]$Path, [string]$Text) {
    Assert-True (-not (Test-Path -LiteralPath $Path)) "O2D22 create-new target exists: $Path"
    [IO.File]::WriteAllText($Path, $Text, $utf8)
}

$jobSource = Read-Pinned 'O2D21_SLOT23_JOB.json' '2F0AE52E25459D4D64A698DF3AA10CAC670E640ED13068211F360400D4FBE233'
$endpointSource = Read-Pinned 'Invoke-O2D21ScribeEndpoint.ps1' '7862116EA2520FE6E3EE1AF03DCFED1A9E926BB8375D80BCE658206DC3E48CEC'
$installationSource = Read-Pinned 'fixtures\INSTALLATION.json' 'C3659F4B6DBB65943B48F145D56A93D9EA3BD7B01250E40E2504CB621382CB6B'
$goodSource = Read-Pinned 'fixtures\LIVE_CONTRACT_GOOD.json' 'E219C143A9A28FB655D36B04D393951EEB5EBA1A902AFA1E7E1214AE59BB4634'
$badJobSource = Read-Pinned 'fixtures\LIVE_CONTRACT_BAD_JOB.json' '247E8909F4196F2F5E72C7194B3DA512AD6474C79E7B3B2A578A9238098A2BC5'
$badInstallationSource = Read-Pinned 'fixtures\LIVE_CONTRACT_BAD_INSTALLATION.json' 'C4D636BD765B99B318FD90739AC84B939881EA3D348E89CE49E9E38A72F00AAF'
$selfPinsSource = Read-Pinned 'Test-O2D21SelfPins.ps1' '659443B7216F2712A34E647FCB0EC390C35FD4044BE324FCD34116C1A03543F1'
$noArgumentSource = Read-Pinned 'Test-O2D21NoArgumentFile.ps1' 'C5E72823D8CD510FC62B5DBE0BF7CA9C4F739F560B8CA2D3CD91250C8484A5C5'

$jobTarget = Join-Path $targetRoot 'O2D22_SLOT24_JOB.json'
$endpointTarget = Join-Path $targetRoot 'Invoke-O2D22ScribeEndpoint.ps1'
$fixtureRoot = Join-Path $targetRoot 'fixtures'
$installationTarget = Join-Path $fixtureRoot 'INSTALLATION.json'
$goodTarget = Join-Path $fixtureRoot 'LIVE_CONTRACT_GOOD.json'
$badJobTarget = Join-Path $fixtureRoot 'LIVE_CONTRACT_BAD_JOB.json'
$badInstallationTarget = Join-Path $fixtureRoot 'LIVE_CONTRACT_BAD_INSTALLATION.json'
$selfPinsTarget = Join-Path $targetRoot 'Test-O2D22SelfPins.ps1'
$noArgumentTarget = Join-Path $targetRoot 'Test-O2D22NoArgumentFile.ps1'
$targets = @($jobTarget,$endpointTarget,$installationTarget,$goodTarget,$badJobTarget,$badInstallationTarget,$selfPinsTarget,$noArgumentTarget)
foreach ($path in $targets) { Assert-True (-not (Test-Path -LiteralPath $path)) "O2D22 create-new target exists: $path" }

$pathResult = & $pathTool -CandidatePath $targets -ProjectRoot $project -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
Assert-True ([string]$pathResult.state -eq 'PASS_PATH_BUDGET' -and @($pathResult.candidates).Count -eq $targets.Count) 'O2D22 core path budget failed.'

$jobText = Convert-O2D21Text $jobSource
$jobBytes = $utf8.GetBytes($jobText)
$sha = [Security.Cryptography.SHA256]::Create()
try { $jobSha = ([BitConverter]::ToString($sha.ComputeHash([byte[]]$jobBytes))).Replace('-','') }
finally { $sha.Dispose() }

$endpointText = (Convert-O2D21Text $endpointSource).Replace(
    '2F0AE52E25459D4D64A698DF3AA10CAC670E640ED13068211F360400D4FBE233',
    $jobSha
)
$endpointBytes = $utf8.GetBytes($endpointText)
$sha = [Security.Cryptography.SHA256]::Create()
try { $endpointSha = ([BitConverter]::ToString($sha.ComputeHash([byte[]]$endpointBytes))).Replace('-','') }
finally { $sha.Dispose() }

$installationText = Convert-O2D21Text $installationSource
$installationBytes = $utf8.GetBytes($installationText)
$sha = [Security.Cryptography.SHA256]::Create()
try { $installationSha = ([BitConverter]::ToString($sha.ComputeHash([byte[]]$installationBytes))).Replace('-','') }
finally { $sha.Dispose() }

function Convert-Fixture([string]$Text) {
    return (Convert-O2D21Text $Text).Replace(
        '2F0AE52E25459D4D64A698DF3AA10CAC670E640ED13068211F360400D4FBE233',
        $jobSha
    ).Replace(
        'C3659F4B6DBB65943B48F145D56A93D9EA3BD7B01250E40E2504CB621382CB6B',
        $installationSha
    )
}

$selfPinsText = Convert-O2D21Text $selfPinsSource
$noArgumentText = (Convert-O2D21Text $noArgumentSource).Replace(
    '7862116EA2520FE6E3EE1AF03DCFED1A9E926BB8375D80BCE658206DC3E48CEC',
    $endpointSha
)

if ($Preflight) {
    [ordered]@{
        schema='argos_o2d22_draft_generator_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D22_DRAFT_GENERATOR_PREFLIGHT'
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
    schema='argos_o2d22_draft_generator_result_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D22_CORE_DRAFT_CREATED'
    targetCount=$targets.Count;jobSha256=Get-Sha256 $jobTarget;endpointSha256=Get-Sha256 $endpointTarget
    installationFixtureSha256=Get-Sha256 $installationTarget;reviewOnly=$true;productionRoutingEnabled=$false
} | ConvertTo-Json -Depth 5

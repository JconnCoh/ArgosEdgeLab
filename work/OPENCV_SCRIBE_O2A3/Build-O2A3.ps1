#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Build
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Build)) { throw 'Specify exactly one of -Preflight or -Build.' }

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$sourceRoot = Join-Path $PSScriptRoot 'pkg'
$partialRoot = Join-Path $PSScriptRoot 'final.partial'
$finalRoot = Join-Path $PSScriptRoot 'final'
$packageRoot = Join-Path $partialRoot 'package'
$zipPath = Join-Path $partialRoot 'ARGOS_O2A3.zip'
$extractRoot = Join-Path $partialRoot 'extract'
$windowsPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$harnessGuard = Join-Path $project 'utilities\Confirm-ArgosPowerShellHarnessSafety.ps1'
$wrapperGuard = Join-Path $project 'utilities\Confirm-ArgosPowerShellWrapper.ps1'
$recoveryGuard = Join-Path $project 'utilities\Confirm-ArgosRecoveryIntent.ps1'
$entrySha = 'E09E4AC81ED6CB4BA7B7D71C5499992434CF84D93D69CD3C051D8C6EE6132BE2'
$wrapperSha = '17D7B3DBB91356022BB729DFA86A6C527F5883A3327AA70CCCBD2D6FBD60F93C'
$invocationSha = '38CEF552D701589CB0238E261AA7469496445D76BFE463996FD8B4DD66C2252A'
$readmeSha = '317AD84DF4078DA3F1D8600597C6B84950AECEEAA9EC7B7456DB7EEC7B346069'
$testGateSha = '560F77BB31B2046C0AC5A8B0C4DD0B7A1A9D28BBD22EF380A9EAAD6BDE5AB015'
$cloneGateSha = 'DE143AB8FF1F34939D4F2E045B41150AF9570429D4EEED5BF46E8B6CF0F6433B'
$pathGateSha = '9B23EC6C1A75DED33D1F15A211BB8F4E73C7BD69311659A3F5D788D8F5F6626A'
$recoveryIntentSha = '0739D7A5BDD65001ACDED7301E5F0AD7991A214A56E71CDA6F967407BDD5AEE2'
$capabilitySha = 'BB0119D10FB5F137424C2F333EE635FC4046CA7F00F2227909CEE73BFA3D6306'
$authorizationSha = '645255A64859FF9EE35BB359D6B12A791F7F5A24C5D7CD96DA9670A2D578D556'

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-Sha256([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Assert-Pin([string]$Path, [string]$Sha256, [string]$RequiredState = '') {
    Assert-True (Test-Path -LiteralPath $Path -PathType Leaf) "O2A3 build dependency is absent: $Path"
    Assert-True ((Get-Sha256 $Path) -eq $Sha256) "O2A3 build dependency changed: $Path"
    if (-not [string]::IsNullOrWhiteSpace($RequiredState)) {
        $value = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
        Assert-True ([string]$value.state -eq $RequiredState) "O2A3 build dependency state changed: $Path"
    }
}
function Write-JsonCreateNew([string]$Path, [object]$Value, [int]$Depth = 16) {
    Assert-True (-not (Test-Path -LiteralPath $Path)) "O2A3 build create-new path exists: $Path"
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}

$sources = [ordered]@{
    'Invoke-O2A3Direct.ps1'=(Join-Path $sourceRoot 'Invoke-O2A3Direct.ps1')
    'RUN_O2A3.cmd'=(Join-Path $sourceRoot 'RUN_O2A3.cmd')
    'INVOCATION.json'=(Join-Path $sourceRoot 'INVOCATION.json')
    'README_FIRST.txt'=(Join-Path $sourceRoot 'README_FIRST.txt')
}
Assert-Pin $sources['Invoke-O2A3Direct.ps1'] $entrySha
Assert-Pin $sources['RUN_O2A3.cmd'] $wrapperSha
Assert-Pin $sources['INVOCATION.json'] $invocationSha
Assert-Pin $sources['README_FIRST.txt'] $readmeSha
Assert-Pin (Join-Path $PSScriptRoot 'O2A3_DIRECT_TEST_GATE.json') $testGateSha 'PASS_O2A3_DIRECT_PACKAGE_SHAPED_TEST_GATE'
Assert-Pin (Join-Path $PSScriptRoot 'O2A3_CLONE_LITERAL_GATE.json') $cloneGateSha 'PASS_ARGOS_CLONE_LITERAL_REMEDIATION'
Assert-Pin (Join-Path $PSScriptRoot 'O2A3_PATH_GATE.json') $pathGateSha 'PASS_O2A3_COMPLETE_DIRECT_ROUTE_PATH_GATE'
Assert-Pin (Join-Path $PSScriptRoot 'O2A3_RECOVERY_INTENT.json') $recoveryIntentSha
Assert-Pin (Join-Path $PSScriptRoot 'O2A3_DIRECT_ADMIN_CAPABILITY_INVENTORY.json') $capabilitySha 'PASS_ARGOS_ENDPOINT_STATIC_CAPABILITY_INVENTORY'
Assert-Pin (Join-Path $PSScriptRoot 'O2A3_DIRECT_ADMIN_READ_ONLY_AUTHORIZATION_GATE.json') $authorizationSha 'PASS_ARGOS_DIRECT_ADMIN_READ_ONLY_AUTHORIZATION'
foreach ($path in @($windowsPowerShell,$harnessGuard,$wrapperGuard,$recoveryGuard)) { Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "O2A3 build tool is absent: $path" }
Assert-True (-not (Test-Path -LiteralPath $partialRoot) -and -not (Test-Path -LiteralPath $finalRoot)) 'O2A3 build output root is not fresh.'

$wrapperJson = & $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File $wrapperGuard -PowerShellScript $sources['Invoke-O2A3Direct.ps1'] -CmdWrapper $sources['RUN_O2A3.cmd'] -InvocationManifest $sources['INVOCATION.json'] -RequirePreflightSwitch -AsJson
Assert-True ($LASTEXITCODE -eq 0) 'O2A3 source wrapper guard failed.'
$wrapperResult = $wrapperJson | ConvertFrom-Json
$harnessJson = & $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File $harnessGuard -PowerShellScript $sources['Invoke-O2A3Direct.ps1'] -Preflight -AsJson
Assert-True ($LASTEXITCODE -eq 0) 'O2A3 source harness guard failed.'
$harnessResult = $harnessJson | ConvertFrom-Json
$recoveryJson = & $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File $recoveryGuard -IntentPath (Join-Path $PSScriptRoot 'O2A3_RECOVERY_INTENT.json') -ProjectRoot $project -Preflight -AsJson
Assert-True ($LASTEXITCODE -eq 0) 'O2A3 recovery-intent gate failed.'
$recoveryResult = $recoveryJson | ConvertFrom-Json
Assert-True ([string]$wrapperResult.state -eq 'PASS_ARGOS_POWERSHELL_WRAPPER_PREFLIGHT' -and [string]$harnessResult.state -eq 'PASS_ARGOS_POWERSHELL_HARNESS_SAFETY' -and [string]$recoveryResult.state -eq 'PASS_ARGOS_RECOVERY_INTENT') 'O2A3 source prepublication guard state changed.'

if ($Preflight) {
    [ordered]@{
        schema='argos_o2a3_build_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2A3_BUILD_PREFLIGHT';revision='O2A3_20260825T195521Z_SLOT16';sourceFileCount=$sources.Count
        entrySha256=$entrySha;testGateSha256=$testGateSha;pathGateSha256=$pathGateSha;recoveryIntentSha256=$recoveryIntentSha;capabilitySha256=$capabilitySha
        wrapperState=[string]$wrapperResult.state;harnessState=[string]$harnessResult.state;recoveryIntentState=[string]$recoveryResult.state
        targetExecuted=$false;mutationsPerformed=$false;imageBytesRead=$false;reviewOnly=$true;productionRoutingEnabled=$false
    } | ConvertTo-Json -Depth 10
    return
}

[void](New-Item -ItemType Directory -Path $packageRoot)
$manifestRows = New-Object Collections.Generic.List[object]
foreach ($name in $sources.Keys) {
    $source = [string]$sources[$name]
    $destination = Join-Path $packageRoot $name
    Copy-Item -LiteralPath $source -Destination $destination -ErrorAction Stop
    Assert-True ((Get-Sha256 $destination) -eq (Get-Sha256 $source)) "O2A3 staged package file changed: $name"
    $manifestRows.Add([pscustomobject]@{path=$name;bytes=(Get-Item -LiteralPath $destination).Length;sha256=Get-Sha256 $destination})
}
$packageManifest = [ordered]@{
    schema='argos_o2a3_direct_package_manifest_v1';revision='O2A3_20260825T195521Z_SLOT16';createdUtc=[DateTime]::UtcNow.ToString('o');lifecycle='FROZEN';files=@($manifestRows.ToArray() | Sort-Object path)
    exactTarget='62619-433_20260824005735_Slot16';exactEvidenceJsonLeafBound=3;installedDependencyHashBound=6;declaredMetadataRowBound=256
    portalInboundUsed=$false;durableDLocalResultRequired=$true;hostAuthenticSignedOutboundReturnRequired=$true;imageAccessAuthorized=$false;taskOrProcessRestartAuthorized=$false;providerActivationAuthorized=$false;sourceMutationAuthorized=$false;holdClearanceAuthorized=$false
    reviewOnly=$true;productionRoutingEnabled=$false
}
Write-JsonCreateNew -Path (Join-Path $packageRoot 'PACKAGE_MANIFEST.json') -Value $packageManifest -Depth 12

Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::CreateFromDirectory($packageRoot, $zipPath, [IO.Compression.CompressionLevel]::Optimal, $false)
[void](New-Item -ItemType Directory -Path $extractRoot)
[IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $extractRoot)
$extracted = @((New-Object IO.DirectoryInfo($extractRoot)).EnumerateFiles())
Assert-True ($extracted.Count -eq 5 -and @((New-Object IO.DirectoryInfo($extractRoot)).EnumerateDirectories()).Count -eq 0) 'O2A3 exact final ZIP file set changed.'
foreach ($row in @($packageManifest.files)) {
    $path = Join-Path $extractRoot ([string]$row.path)
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "O2A3 extracted file is absent: $($row.path)"
    Assert-True ((Get-Item -LiteralPath $path).Length -eq [int64]$row.bytes -and (Get-Sha256 $path) -eq [string]$row.sha256) "O2A3 extracted file changed: $($row.path)"
}
$extractedManifestPath = Join-Path $extractRoot 'PACKAGE_MANIFEST.json'
Assert-True ((Get-Sha256 $extractedManifestPath) -eq (Get-Sha256 (Join-Path $packageRoot 'PACKAGE_MANIFEST.json'))) 'O2A3 extracted package manifest changed.'

$extractedEntry = Join-Path $extractRoot 'Invoke-O2A3Direct.ps1'
$extractedWrapper = Join-Path $extractRoot 'RUN_O2A3.cmd'
$extractedInvocation = Join-Path $extractRoot 'INVOCATION.json'
$extractedHarnessJson = & $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File $harnessGuard -PowerShellScript $extractedEntry -Preflight -AsJson
Assert-True ($LASTEXITCODE -eq 0) 'O2A3 extracted harness guard failed.'
$extractedWrapperJson = & $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File $wrapperGuard -PowerShellScript $extractedEntry -CmdWrapper $extractedWrapper -InvocationManifest $extractedInvocation -RequirePreflightSwitch -AsJson
Assert-True ($LASTEXITCODE -eq 0) 'O2A3 extracted wrapper guard failed.'
$extractedHarness = $extractedHarnessJson | ConvertFrom-Json
$extractedWrapperResult = $extractedWrapperJson | ConvertFrom-Json
Assert-True ([string]$extractedHarness.state -eq 'PASS_ARGOS_POWERSHELL_HARNESS_SAFETY' -and [string]$extractedWrapperResult.state -eq 'PASS_ARGOS_POWERSHELL_WRAPPER_PREFLIGHT') 'O2A3 extracted source guard state changed.'

$priorPreference = $ErrorActionPreference
try { $ErrorActionPreference='Continue'; $refusalRows=@(& $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File $extractedEntry -InvocationManifest $extractedInvocation -Preflight 2>&1); $refusalExit=$LASTEXITCODE }
finally { $ErrorActionPreference=$priorPreference }
$refusalText = $refusalRows -join [Environment]::NewLine
Assert-True ($refusalExit -ne 0 -and $refusalText.Contains('O2A3 refuses this computer:')) 'O2A3 extracted laptop refusal changed.'
Assert-True (-not (Test-Path -LiteralPath 'D:\A2\x\O2A3_20260825T195521Z') -and -not (Test-Path -LiteralPath 'D:\A2\x\O2A3R_20260825T195521Z.zip')) 'O2A3 laptop refusal wrote a live result.'

$finalGate = [ordered]@{
    schema='argos_o2a3_final_package_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2A3_FINAL_PACKAGE_GATE';lifecycle='FROZEN';revision='O2A3_20260825T195521Z_SLOT16'
    zipPath='final/ARGOS_O2A3.zip';zipBytes=(Get-Item -LiteralPath $zipPath).Length;zipSha256=Get-Sha256 $zipPath;zipEntryCount=5;packageManifestSha256=Get-Sha256 (Join-Path $packageRoot 'PACKAGE_MANIFEST.json')
    entrySha256=$entrySha;wrapperSha256=$wrapperSha;invocationSha256=$invocationSha;testGateSha256=$testGateSha;cloneGateSha256=$cloneGateSha;pathGateSha256=$pathGateSha;recoveryIntentSha256=$recoveryIntentSha;capabilitySha256=$capabilitySha;authorizationSha256=$authorizationSha
    exactExtractionVerified=$true;extractedHarnessState=[string]$extractedHarness.state;extractedWrapperState=[string]$extractedWrapperResult.state;extractedLaptopRefusalPassed=$true
    windowsPowerShell51SummaryHoldAbsentAndInjectedOutboundFailurePassed=$true;lockedImageNegativeControlPassed=$true;localResultRetainedBeforeOutboundReturn=$true;hostAuthenticSignerAccessPreflightRequired=$true
    oneJbodObservationAuthorized=$true;portalInboundUsed=$false;imageAccessAuthorized=$false;taskOrProcessRestartAuthorized=$false;providerActivationAuthorized=$false;sourceMutationAuthorized=$false;holdClearanceAuthorized=$false
    jbodContacted=$false;targetExecuted=$false;reviewOnly=$true;productionRoutingEnabled=$false;publicationAuthorized=$false
}
Write-JsonCreateNew -Path (Join-Path $partialRoot 'O2A3_FINAL_PACKAGE_GATE.json') -Value $finalGate -Depth 16
Remove-Item -LiteralPath $packageRoot -Recurse -Force
Move-Item -LiteralPath $partialRoot -Destination $finalRoot -ErrorAction Stop
$finalGate | ConvertTo-Json -Depth 16

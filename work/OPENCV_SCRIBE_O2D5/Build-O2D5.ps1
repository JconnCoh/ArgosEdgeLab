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
$partialRoot = Join-Path $PSScriptRoot 'final.partial'
$finalRoot = Join-Path $PSScriptRoot 'final'
$packageRoot = Join-Path $partialRoot 'package'
$zipPath = Join-Path $partialRoot 'ARGOS_O2D5.zip'
$extractRoot = Join-Path $partialRoot 'extract'
$engineSource = Join-Path $project 'work\OPENCV_SCRIBE_V1\ArgosOpenCvScribeV1.py'
$bundleSource = Join-Path $project 'work\OPENCV_SCRIBE_O2D4\final\extract\payload\O2D4_REFS.zip'
$windowsPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$harnessGuard = Join-Path $project 'utilities\Confirm-ArgosPowerShellHarnessSafety.ps1'
$wrapperGuard = Join-Path $project 'utilities\Confirm-ArgosPowerShellWrapper.ps1'
$recoveryGuard = Join-Path $project 'utilities\Confirm-ArgosRecoveryIntent.ps1'
$entrySha = 'BE70D3B41EB8983F7D193BF5E33858A69FEB890A27DA6B0A7A39CDB662C03F93'
$wrapperSha = '0C960BC8A76601CB7B512AC5368B8FD4E3619918AED62E30474F3B5EDDC0E470'
$invocationSha = '0A51EAE43DAE15D0B4D5FC7756FE399A5B43B1CB7DD60D62C44DC47B48DAE05E'
$readmeSha = 'F6AA9DA7166D3FF4668D4F3948DEDAEF26581AFBE1AA11952B37675D85A1E2B1'
$jobSha = 'C05B48D1FFF96B28BC6D5C3393FB7E1F8F84844DA92DAF90FC04F983BA5C2A98'
$engineSha = '3CE7E93B9C922B02DE8E8BF712FC715BE24FF7D232B7EC3DDBB86EC7A05273B9'
$bundleSha = '56DF00E37A195E7BC3E026E4950DFB5A0AA7E7AF49A6FF39020B071840CCFBD6'
$testGateSha = 'A5B1E520629825AEA70B81BF309BF1895B8365A0CE024BA5026D1B241677F260'
$cloneGateSha = '6D9F4438F75FECF5D413E180C2E8B02ABE04750775C6DC1D8DF13B3E7A543824'
$pathGateSha = '2DAD77D5D6C689F6345E93BA2527F6FD2AEF8B328295EE6A6C3C083E116A095F'
$recoveryIntentSha = '5BCAF67325328E5819F502095F298D9A3A2E70CFBBD21F110B4428FA822A7FF2'

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-Sha256([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Assert-Pin([string]$Path, [string]$Sha256, [string]$RequiredState = '') {
    Assert-True (Test-Path -LiteralPath $Path -PathType Leaf) "O2D5 build dependency is absent: $Path"
    Assert-True ((Get-Sha256 $Path) -eq $Sha256) "O2D5 build dependency changed: $Path"
    if (-not [string]::IsNullOrWhiteSpace($RequiredState)) {
        $value = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
        Assert-True ([string]$value.state -eq $RequiredState) "O2D5 build dependency state changed: $Path"
    }
}
function Write-JsonCreateNew([string]$Path, [object]$Value, [int]$Depth = 16) {
    Assert-True (-not (Test-Path -LiteralPath $Path)) "O2D5 build create-new path exists: $Path"
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}

$sources = [ordered]@{
    'Invoke-O2D5Direct.ps1'=(Join-Path $PSScriptRoot 'Invoke-O2D5Direct.ps1')
    'RUN_O2D5.cmd'=(Join-Path $PSScriptRoot 'RUN_O2D5.cmd')
    'INVOCATION.json'=(Join-Path $PSScriptRoot 'INVOCATION.json')
    'README_FIRST.txt'=(Join-Path $PSScriptRoot 'README_FIRST.txt')
    'O2D5_SLOT16_JOB.json'=(Join-Path $PSScriptRoot 'O2D5_SLOT16_JOB.json')
    'ArgosOpenCvScribeV1.py'=$engineSource
    'O2D5_REFS.zip'=$bundleSource
}
Assert-Pin $sources['Invoke-O2D5Direct.ps1'] $entrySha
Assert-Pin $sources['RUN_O2D5.cmd'] $wrapperSha
Assert-Pin $sources['INVOCATION.json'] $invocationSha
Assert-Pin $sources['README_FIRST.txt'] $readmeSha
Assert-Pin $sources['O2D5_SLOT16_JOB.json'] $jobSha
Assert-Pin $engineSource $engineSha
Assert-Pin $bundleSource $bundleSha
Assert-Pin (Join-Path $PSScriptRoot 'O2D5_DIRECT_TEST_GATE.json') $testGateSha 'PASS_O2D5_DIRECT_PACKAGE_SHAPED_TEST_GATE'
Assert-Pin (Join-Path $PSScriptRoot 'O2D5_CLONE_LITERAL_GATE.json') $cloneGateSha 'PASS_ARGOS_CLONE_LITERAL_REMEDIATION'
Assert-Pin (Join-Path $PSScriptRoot 'O2D5_PATH_GATE.json') $pathGateSha 'PASS_O2D5_COMPLETE_DIRECT_ROUTE_PATH_GATE'
Assert-Pin (Join-Path $PSScriptRoot 'O2D5_RECOVERY_INTENT.json') $recoveryIntentSha
foreach ($path in @($windowsPowerShell,$harnessGuard,$wrapperGuard,$recoveryGuard)) { Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "O2D5 build tool is absent: $path" }
Assert-True (-not (Test-Path -LiteralPath $partialRoot) -and -not (Test-Path -LiteralPath $finalRoot)) 'O2D5 build output root is not fresh.'

$wrapperJson = & $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File $wrapperGuard -PowerShellScript $sources['Invoke-O2D5Direct.ps1'] -CmdWrapper $sources['RUN_O2D5.cmd'] -InvocationManifest $sources['INVOCATION.json'] -RequirePreflightSwitch -AsJson
Assert-True ($LASTEXITCODE -eq 0) 'O2D5 source wrapper guard failed.'
$wrapperResult = $wrapperJson | ConvertFrom-Json
$harnessJson = & $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File $harnessGuard -PowerShellScript $sources['Invoke-O2D5Direct.ps1'] -Preflight -AsJson
Assert-True ($LASTEXITCODE -eq 0) 'O2D5 source harness guard failed.'
$harnessResult = $harnessJson | ConvertFrom-Json
$recoveryJson = & $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File $recoveryGuard -IntentPath (Join-Path $PSScriptRoot 'O2D5_RECOVERY_INTENT.json') -ProjectRoot $project -Preflight -AsJson
Assert-True ($LASTEXITCODE -eq 0) 'O2D5 recovery-intent gate failed.'
$recoveryResult = $recoveryJson | ConvertFrom-Json
Assert-True ([string]$wrapperResult.state -eq 'PASS_ARGOS_POWERSHELL_WRAPPER_PREFLIGHT' -and [string]$harnessResult.state -eq 'PASS_ARGOS_POWERSHELL_HARNESS_SAFETY' -and [string]$recoveryResult.state -eq 'PASS_ARGOS_RECOVERY_INTENT') 'O2D5 source prepublication gate state changed.'

if ($Preflight) {
    [ordered]@{
        schema='argos_o2d5_build_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D5_BUILD_PREFLIGHT';revision='O2D5_20260825T190855Z_54B4C08C'
        sourceFileCount=$sources.Count;entrySha256=$entrySha;engineSha256=$engineSha;referenceBundleSha256=$bundleSha;jobSha256=$jobSha
        wrapperState=[string]$wrapperResult.state;harnessState=[string]$harnessResult.state;recoveryIntentState=[string]$recoveryResult.state
        targetExecuted=$false;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false
    } | ConvertTo-Json -Depth 8
    return
}

[void](New-Item -ItemType Directory -Path $packageRoot)
$manifestRows = New-Object Collections.Generic.List[object]
foreach ($name in $sources.Keys) {
    $source = [string]$sources[$name]
    $destination = Join-Path $packageRoot $name
    Copy-Item -LiteralPath $source -Destination $destination -ErrorAction Stop
    Assert-True ((Get-Sha256 $destination) -eq (Get-Sha256 $source)) "O2D5 staged package file changed: $name"
    $manifestRows.Add([pscustomobject]@{path=$name;bytes=(Get-Item -LiteralPath $destination).Length;sha256=Get-Sha256 $destination})
}
$packageManifest = [ordered]@{
    schema='argos_o2d5_direct_package_manifest_v1';revision='O2D5_20260825T190855Z_54B4C08C';createdUtc=[DateTime]::UtcNow.ToString('o');lifecycle='FROZEN'
    files=@($manifestRows.ToArray() | Sort-Object path);engineSha256=$engineSha;referenceBundleSha256=$bundleSha;jobSha256=$jobSha
    exactSlot='Slot16';portalInboundUsed=$false;durableDLocalResultRequired=$true;hostAuthenticSignedOutboundReturnRequired=$true
    taskOrProcessRestartAuthorized=$false;providerActivationAuthorized=$false;sourceMutationAuthorized=$false;holdClearanceAuthorized=$false
    reviewOnly=$true;productionRoutingEnabled=$false
}
Write-JsonCreateNew -Path (Join-Path $packageRoot 'PACKAGE_MANIFEST.json') -Value $packageManifest -Depth 12

Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::CreateFromDirectory($packageRoot, $zipPath, [IO.Compression.CompressionLevel]::Optimal, $false)
[void](New-Item -ItemType Directory -Path $extractRoot)
[IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $extractRoot)
$extracted = @((New-Object IO.DirectoryInfo($extractRoot)).EnumerateFiles())
Assert-True ($extracted.Count -eq 8 -and @((New-Object IO.DirectoryInfo($extractRoot)).EnumerateDirectories()).Count -eq 0) 'O2D5 exact final ZIP file set changed.'
foreach ($row in @($packageManifest.files)) {
    $path = Join-Path $extractRoot ([string]$row.path)
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "O2D5 extracted file is absent: $($row.path)"
    Assert-True ((Get-Item -LiteralPath $path).Length -eq [int64]$row.bytes -and (Get-Sha256 $path) -eq [string]$row.sha256) "O2D5 extracted file changed: $($row.path)"
}
$extractedManifestPath = Join-Path $extractRoot 'PACKAGE_MANIFEST.json'
Assert-True ((Get-Sha256 $extractedManifestPath) -eq (Get-Sha256 (Join-Path $packageRoot 'PACKAGE_MANIFEST.json'))) 'O2D5 extracted package manifest changed.'

$extractedEntry = Join-Path $extractRoot 'Invoke-O2D5Direct.ps1'
$extractedWrapper = Join-Path $extractRoot 'RUN_O2D5.cmd'
$extractedInvocation = Join-Path $extractRoot 'INVOCATION.json'
$extractedHarnessJson = & $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File $harnessGuard -PowerShellScript $extractedEntry -Preflight -AsJson
Assert-True ($LASTEXITCODE -eq 0) 'O2D5 extracted harness guard failed.'
$extractedWrapperJson = & $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File $wrapperGuard -PowerShellScript $extractedEntry -CmdWrapper $extractedWrapper -InvocationManifest $extractedInvocation -RequirePreflightSwitch -AsJson
Assert-True ($LASTEXITCODE -eq 0) 'O2D5 extracted wrapper guard failed.'
$extractedHarness = $extractedHarnessJson | ConvertFrom-Json
$extractedWrapperResult = $extractedWrapperJson | ConvertFrom-Json
Assert-True ([string]$extractedHarness.state -eq 'PASS_ARGOS_POWERSHELL_HARNESS_SAFETY' -and [string]$extractedWrapperResult.state -eq 'PASS_ARGOS_POWERSHELL_WRAPPER_PREFLIGHT') 'O2D5 extracted source guard state changed.'

$priorPreference = $ErrorActionPreference
try { $ErrorActionPreference='Continue'; $refusalRows=@(& $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File $extractedEntry -InvocationManifest $extractedInvocation -Preflight 2>&1); $refusalExit=$LASTEXITCODE }
finally { $ErrorActionPreference=$priorPreference }
$refusalText = $refusalRows -join [Environment]::NewLine
Assert-True ($refusalExit -ne 0 -and ($refusalText.Contains('O2D5 refuses this computer:') -or $refusalText.Contains('O2D5 required file is absent:'))) 'O2D5 extracted laptop refusal changed.'
Assert-True (-not (Test-Path -LiteralPath 'D:\A2\w\ocv\O2D5_20260825T190855Z_54B4C08C') -and -not (Test-Path -LiteralPath 'D:\A2\o\ocv\O2D5_20260825T190855Z_54B4C08C') -and -not (Test-Path -LiteralPath 'D:\A2\x\O2D5R_20260825T190855Z_54B4C08C.zip')) 'O2D5 laptop refusal wrote a live result.'

$finalGate = [ordered]@{
    schema='argos_o2d5_final_package_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D5_FINAL_PACKAGE_GATE';lifecycle='FROZEN';revision='O2D5_20260825T190855Z_54B4C08C'
    zipPath='final/ARGOS_O2D5.zip';zipBytes=(Get-Item -LiteralPath $zipPath).Length;zipSha256=Get-Sha256 $zipPath;zipEntryCount=8
    packageManifestSha256=Get-Sha256 (Join-Path $packageRoot 'PACKAGE_MANIFEST.json');entrySha256=$entrySha;wrapperSha256=$wrapperSha;invocationSha256=$invocationSha
    engineSha256=$engineSha;referenceBundleSha256=$bundleSha;jobSha256=$jobSha;testGateSha256=$testGateSha;cloneGateSha256=$cloneGateSha;pathGateSha256=$pathGateSha;recoveryIntentSha256=$recoveryIntentSha
    exactExtractionVerified=$true;extractedHarnessState=[string]$extractedHarness.state;extractedWrapperState=[string]$extractedWrapperResult.state;extractedLaptopRefusalPassed=$true
    windowsPowerShell51SuccessAndInjectedOutboundFailurePassed=$true;localResultRetainedBeforeOutboundReturn=$true;hostAuthenticSignerAccessPreflightRequired=$true
    oneJbodExecutionAuthorized=$true;portalInboundUsed=$false;taskOrProcessRestartAuthorized=$false;providerActivationAuthorized=$false;sourceMutationAuthorized=$false;holdClearanceAuthorized=$false
    jbodContacted=$false;targetExecuted=$false;reviewOnly=$true;productionRoutingEnabled=$false;publicationAuthorized=$false
}
Write-JsonCreateNew -Path (Join-Path $partialRoot 'O2D5_FINAL_PACKAGE_GATE.json') -Value $finalGate -Depth 14
Remove-Item -LiteralPath $packageRoot -Recurse -Force
Move-Item -LiteralPath $partialRoot -Destination $finalRoot -ErrorAction Stop
$finalGate | ConvertTo-Json -Depth 14

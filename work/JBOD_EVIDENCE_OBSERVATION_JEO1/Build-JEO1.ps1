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
$packageRoot = Join-Path $PSScriptRoot 'pkg'
$partialRoot = Join-Path $PSScriptRoot 'final.partial'
$finalRoot = Join-Path $PSScriptRoot 'final'
$zipPath = Join-Path $partialRoot 'ARGOS_JEO1.zip'
$extractRoot = Join-Path $partialRoot 'extract'
$rehearsalInvocationPath = Join-Path $partialRoot 'INVOCATION_REHEARSAL.json'
$testGatePath = Join-Path $PSScriptRoot 'JEO1_TEST_GATE.json'
$pathGatePath = Join-Path $PSScriptRoot 'JEO1_PATH_GATE.json'
$preactionPath = Join-Path $PSScriptRoot 'JEO1_ZERO_RECURRENCE_PREACTION.json'
$windowsPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$wrapperGuard = Join-Path $project 'utilities\Confirm-ArgosPowerShellWrapper.ps1'
$harnessGuard = Join-Path $project 'utilities\Confirm-ArgosPowerShellHarnessSafety.ps1'

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-Sha256([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Write-JsonCreateNew([string]$Path, [object]$Value, [int]$Depth = 18) {
    Assert-True (-not (Test-Path -LiteralPath $Path)) "Create-new build path exists: $Path"
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}

$expectedFiles = @('AUDIT_JEO1.ps1','INVOCATION.json','PACKAGE_MANIFEST.json','README_FIRST.txt','RUN_JEO1.cmd')
foreach ($path in @($packageRoot,$testGatePath,$pathGatePath,$preactionPath,$windowsPowerShell,$wrapperGuard,$harnessGuard)) { Assert-True (Test-Path -LiteralPath $path) "JEO1 build dependency is absent: $path" }
Assert-True (-not (Test-Path -LiteralPath $partialRoot)) "JEO1 partial root must be fresh: $partialRoot"
Assert-True (-not (Test-Path -LiteralPath $finalRoot)) "JEO1 final root must be fresh: $finalRoot"
$actualFiles = @((New-Object IO.DirectoryInfo($packageRoot)).EnumerateFiles() | ForEach-Object { $_.Name } | Sort-Object)
Assert-True (@(Compare-Object -ReferenceObject $expectedFiles -DifferenceObject $actualFiles).Count -eq 0) 'JEO1 package source has a missing or extra file.'
Assert-True (@((New-Object IO.DirectoryInfo($packageRoot)).EnumerateDirectories()).Count -eq 0) 'JEO1 package source has an unexpected directory.'
$manifestPath = Join-Path $packageRoot 'PACKAGE_MANIFEST.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
Assert-True ([string]$manifest.schema -eq 'argos_jeo1_direct_admin_package_manifest_v1' -and [string]$manifest.revision -eq 'JEO1') 'JEO1 package manifest identity changed.'
Assert-True (@($manifest.files).Count -eq 4) 'JEO1 package manifest file count changed.'
foreach ($entry in @($manifest.files)) {
    $source = Join-Path $packageRoot ([string]$entry.path)
    Assert-True (Test-Path -LiteralPath $source -PathType Leaf) "JEO1 manifest file is absent: $($entry.path)"
    Assert-True ((Get-Item -LiteralPath $source).Length -eq [int64]$entry.bytes -and (Get-Sha256 $source) -eq [string]$entry.sha256) "JEO1 manifest file changed: $($entry.path)"
}
$testGate = Get-Content -LiteralPath $testGatePath -Raw | ConvertFrom-Json
$pathGate = Get-Content -LiteralPath $pathGatePath -Raw | ConvertFrom-Json
Assert-True ([string]$testGate.state -eq 'PASS_JEO1_DIRECT_ADMIN_READ_ONLY_TEST_GATE' -and [bool]$testGate.windowsPowerShell51Passed -and -not [bool]$testGate.targetMutationsPerformed) 'JEO1 exact test gate changed.'
Assert-True ([string]$pathGate.state -eq 'PASS_JEO1_COMPLETE_DIRECT_ADMIN_ROUTE_PATH_GATE' -and [int]$pathGate.maximumEffectiveLength -lt 200) 'JEO1 path gate changed.'
Assert-True (-not (Test-Path -LiteralPath 'D:\A2\x\JEO1') -and -not (Test-Path -LiteralPath 'D:\A2\x\JEO1R_LOCAL.zip')) 'JEO1 laptop build found a live JBOD evidence root.'

if ($Preflight) {
    [ordered]@{schema='argos_jeo1_build_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_JEO1_BUILD_PREFLIGHT';packageManifestSha256=Get-Sha256 $manifestPath;testGateSha256=Get-Sha256 $testGatePath;pathGateSha256=Get-Sha256 $pathGatePath;targetExecuted=$false;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 8
    return
}

[void](New-Item -ItemType Directory -Path $partialRoot)
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::CreateFromDirectory($packageRoot, $zipPath, [IO.Compression.CompressionLevel]::Optimal, $false)
[void](New-Item -ItemType Directory -Path $extractRoot)
[IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $extractRoot)
$extractedFiles = @((New-Object IO.DirectoryInfo($extractRoot)).EnumerateFiles() | ForEach-Object { $_.Name } | Sort-Object)
Assert-True (@(Compare-Object -ReferenceObject $expectedFiles -DifferenceObject $extractedFiles).Count -eq 0) 'JEO1 extracted package has a missing or extra file.'
Assert-True (@((New-Object IO.DirectoryInfo($extractRoot)).EnumerateDirectories()).Count -eq 0) 'JEO1 extracted package has an unexpected directory.'
$fileRows = New-Object Collections.Generic.List[object]
foreach ($name in $expectedFiles) {
    $source = Join-Path $packageRoot $name
    $extracted = Join-Path $extractRoot $name
    Assert-True ((Get-Item -LiteralPath $source).Length -eq (Get-Item -LiteralPath $extracted).Length -and (Get-Sha256 $source) -eq (Get-Sha256 $extracted)) "JEO1 extracted file changed: $name"
    $fileRows.Add([pscustomobject]@{path=$name;bytes=(Get-Item -LiteralPath $source).Length;sha256=Get-Sha256 $source})
}
$auditPath = Join-Path $extractRoot 'AUDIT_JEO1.ps1'
$wrapperPath = Join-Path $extractRoot 'RUN_JEO1.cmd'
$invocationPath = Join-Path $extractRoot 'INVOCATION.json'
$harnessJson = & $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File $harnessGuard -PowerShellScript $auditPath -Preflight -AsJson
Assert-True ($LASTEXITCODE -eq 0) 'JEO1 extracted harness guard failed.'
$harnessResult = $harnessJson | ConvertFrom-Json
$wrapperJson = & $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File $wrapperGuard -PowerShellScript $auditPath -CmdWrapper $wrapperPath -InvocationManifest $invocationPath -RequirePreflightSwitch -AsJson
Assert-True ($LASTEXITCODE -eq 0) 'JEO1 extracted wrapper guard failed.'
$wrapperResult = $wrapperJson | ConvertFrom-Json
Assert-True ([string]$harnessResult.state -eq 'PASS_ARGOS_POWERSHELL_HARNESS_SAFETY' -and [string]$wrapperResult.state -eq 'PASS_ARGOS_POWERSHELL_WRAPPER_PREFLIGHT') 'JEO1 extracted guard state changed.'

$rehearsalInvocation = Get-Content -LiteralPath $invocationPath -Raw | ConvertFrom-Json
$rehearsalInvocation.rehearsal = $true
$rehearsalInvocation.outputRoot = Join-Path $partialRoot 'rehearsal_output'
$rehearsalInvocation.localResultPath = Join-Path $partialRoot 'rehearsal_local.zip'
$rehearsalInvocation.returnPath = Join-Path $partialRoot 'rehearsal_return.zip'
$rehearsalInvocation.treeSources = @(
    [ordered]@{id='CACHE';root=(Join-Path $partialRoot 'fixture_cache');maximumFiles=250000;maximumDirectories=300000},
    [ordered]@{id='METADATA';root=(Join-Path $partialRoot 'fixture_metadata');maximumFiles=250000;maximumDirectories=300000},
    [ordered]@{id='DASHBOARD_OUTPUTS';root=(Join-Path $partialRoot 'fixture_dashboard');maximumFiles=250000;maximumDirectories=300000}
)
Write-JsonCreateNew -Path $rehearsalInvocationPath -Value $rehearsalInvocation -Depth 24
$rehearsalJson = & $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File $auditPath -InvocationManifest $rehearsalInvocationPath -Preflight -Rehearsal
Assert-True ($LASTEXITCODE -eq 0) 'JEO1 extracted rehearsal preflight failed.'
$rehearsalResult = $rehearsalJson | ConvertFrom-Json
Assert-True ([string]$rehearsalResult.state -eq 'PASS_JEO1_DIRECT_ADMIN_READ_ONLY_PREFLIGHT') 'JEO1 extracted rehearsal preflight state changed.'
Assert-True (-not (Test-Path -LiteralPath ([string]$rehearsalInvocation.outputRoot)) -and -not (Test-Path -LiteralPath ([string]$rehearsalInvocation.localResultPath))) 'JEO1 rehearsal preflight wrote evidence.'

$negativeArguments = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$auditPath,'-InvocationManifest',$invocationPath,'-Preflight')
$priorPreference = $ErrorActionPreference
try { $ErrorActionPreference = 'Continue'; $negativeRows = @(& $windowsPowerShell @negativeArguments 2>&1); $negativeExit = $LASTEXITCODE }
finally { $ErrorActionPreference = $priorPreference }
$negativeText = $negativeRows -join [Environment]::NewLine
Assert-True ($negativeExit -ne 0 -and $negativeText.Contains('JEO1 refuses this computer: TXSH-LUPW0JLTPR')) 'JEO1 extracted laptop refusal changed.'
Assert-True (-not (Test-Path -LiteralPath 'D:\A2\x\JEO1') -and -not (Test-Path -LiteralPath 'D:\A2\x\JEO1R_LOCAL.zip')) 'JEO1 laptop refusal wrote a live result.'

$archive = [IO.Compression.ZipFile]::OpenRead($zipPath)
try { $entryNames = @($archive.Entries | ForEach-Object { $_.FullName.Replace('/','\') } | Sort-Object); Assert-True (@(Compare-Object -ReferenceObject $expectedFiles -DifferenceObject $entryNames).Count -eq 0) 'JEO1 ZIP entry set changed.' }
finally { $archive.Dispose() }
$finalGate = [ordered]@{
    schema='argos_jeo1_final_package_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_JEO1_FINAL_PACKAGE_GATE';lifecycle='FROZEN';revision='JEO1'
    zipPath='final/ARGOS_JEO1.zip';zipBytes=(Get-Item -LiteralPath $zipPath).Length;zipSha256=Get-Sha256 $zipPath;zipEntryCount=$expectedFiles.Count;zipEntries=$expectedFiles;fileRows=$fileRows.ToArray()
    packageManifestSha256=Get-Sha256 $manifestPath;testGateSha256=Get-Sha256 $testGatePath;pathGateSha256=Get-Sha256 $pathGatePath;preactionSha256=Get-Sha256 $preactionPath
    exactExtractionVerified=$true;extractedHarnessState=[string]$harnessResult.state;extractedWrapperState=[string]$wrapperResult.state;extractedRehearsalPreflightState=[string]$rehearsalResult.state
    extractedLaptopRefusalPassed=$true;jbodContacted=$false;targetMutationsPerformed=$false;imageBytesRead=$false;oneObservationExecutionAuthorized=$true
    reviewOnly=$true;productionRoutingEnabled=$false
}
Write-JsonCreateNew -Path (Join-Path $partialRoot 'JEO1_FINAL_PACKAGE_GATE.json') -Value $finalGate -Depth 16
Move-Item -LiteralPath $partialRoot -Destination $finalRoot
$finalGate | ConvertTo-Json -Depth 16

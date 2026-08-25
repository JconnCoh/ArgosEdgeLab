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
$zipLeaf = 'ARGOS_O2A2.zip'
$zipPath = Join-Path $partialRoot $zipLeaf
$verifyRoot = Join-Path $partialRoot 'verify'
$verifyReturnRoot = Join-Path $partialRoot 'verify_return'
$rehearsalInvocationPath = Join-Path $partialRoot 'INVOCATION_REHEARSAL.json'
$prepublicationGatePath = Join-Path $PSScriptRoot 'O2A2_PREPUBLICATION_GATE.json'
$preactionPath = Join-Path $PSScriptRoot 'O2A2_ZERO_RECURRENCE_PREACTION.json'
$testGatePath = Join-Path $PSScriptRoot 'O2A2_TEST_GATE_R3.json'
$windowsPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$wrapperGuard = Join-Path $project 'utilities\Confirm-ArgosPowerShellWrapper.ps1'
$harnessGuard = Join-Path $project 'utilities\Confirm-ArgosPowerShellHarnessSafety.ps1'

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Assert-Pin([string]$Path, [string]$Sha256) {
    Assert-True (Test-Path -LiteralPath $Path -PathType Leaf) "Pinned file is absent: $Path"
    Assert-True ((Get-Sha256 $Path) -eq $Sha256) "Pinned file changed: $Path"
}

function Write-JsonCreateNew([string]$Path, [object]$Value, [int]$Depth = 16) {
    Assert-True (-not (Test-Path -LiteralPath $Path)) "Create-new JSON path exists: $Path"
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}

$pins = [ordered]@{
    'AUDIT_O2A2.ps1' = '9CD452765661B59DAC18A5EB0C6848936068A24CAF003E451460BE0C787FB4DD'
    'RUN_O2A2.cmd' = 'D53C65BA49272EE5FC3E50EEEAE8168CF2811DA556EFBD9C7A2CD3EC7179AD67'
    'INVOCATION.json' = '971ED59F4D3CBF9A4DF7771188DC8C9EC62965F7A1B3B463CAE3FA13ECCFDCA4'
    'README_FIRST.txt' = 'BBA41C1186083DAD4B1155E52DEB7518BBA2EEA358371B83DDC20AC41E0CC986'
    'PACKAGE_MANIFEST.json' = 'E21FE57902B329E0EB3EE790D53DCBFE7E9999E6143143E67D0EE004B2C4284A'
}
foreach ($leaf in $pins.Keys) { Assert-Pin (Join-Path $packageRoot $leaf) ([string]$pins[$leaf]) }
Assert-Pin $prepublicationGatePath 'EF759171069BB04C31FEC33B3987C2419239D8F148BCF1524391F787D82CE497'
Assert-Pin $preactionPath 'F02ED85408A3D3C7B335F40B4E94FC62431A9E3601506F2B9488788D047211D1'
Assert-Pin $testGatePath 'EAFDE4D1634E7C5F3E0858217DA4168F63ED8F570A912DEF06D81C5423DDD377'
Assert-True (Test-Path -LiteralPath $windowsPowerShell -PathType Leaf) 'Windows PowerShell 5.1 is absent.'
Assert-True (-not (Test-Path -LiteralPath $partialRoot)) "O2A2 partial final root exists: $partialRoot"
Assert-True (-not (Test-Path -LiteralPath $finalRoot)) "O2A2 final root exists: $finalRoot"

$packageManifest = Get-Content -LiteralPath (Join-Path $packageRoot 'PACKAGE_MANIFEST.json') -Raw | ConvertFrom-Json
Assert-True ([string]$packageManifest.schema -eq 'argos_o2a2_direct_admin_package_manifest_v1') 'Package manifest schema changed.'
Assert-True (@($packageManifest.files).Count -eq 4) 'Package manifest file count changed.'
Assert-True ([bool]$packageManifest.reviewOnly -and -not [bool]$packageManifest.productionRoutingEnabled) 'Package authority changed.'
$prepublicationGate = Get-Content -LiteralPath $prepublicationGatePath -Raw | ConvertFrom-Json
Assert-True ([string]$prepublicationGate.state -eq 'PASS_O2A2_PREPUBLICATION_GATE') 'Prepublication gate is not PASS.'
$testGate = Get-Content -LiteralPath $testGatePath -Raw | ConvertFrom-Json
Assert-True ([string]$testGate.state -eq 'PASS_O2A2_DIRECT_ADMIN_READ_ONLY_TEST_GATE' -and [bool]$testGate.windowsPowerShell51Passed) 'Exact package test gate is not PASS.'

if ($Preflight) {
    [ordered]@{
        schema = 'argos_o2a2_build_preflight_v1'
        createdUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_O2A2_BUILD_PREFLIGHT'
        packageFileCount = 5
        packageManifestSha256 = Get-Sha256 (Join-Path $packageRoot 'PACKAGE_MANIFEST.json')
        prepublicationGateSha256 = Get-Sha256 $prepublicationGatePath
        preactionSha256 = Get-Sha256 $preactionPath
        targetExecuted = $false
        mutationsPerformed = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 6
    return
}

[void](New-Item -ItemType Directory -Path $partialRoot)
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::CreateFromDirectory($packageRoot, $zipPath, [IO.Compression.CompressionLevel]::Optimal, $false)
[void](New-Item -ItemType Directory -Path $verifyRoot)
[IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $verifyRoot)

$extractedFiles = @(Get-ChildItem -LiteralPath $verifyRoot -File)
Assert-True ($extractedFiles.Count -eq 5) 'Extracted O2A2 file count changed.'
foreach ($leaf in $pins.Keys) { Assert-Pin (Join-Path $verifyRoot $leaf) ([string]$pins[$leaf]) }

$extractedAudit = Join-Path $verifyRoot 'AUDIT_O2A2.ps1'
$extractedWrapper = Join-Path $verifyRoot 'RUN_O2A2.cmd'
$extractedInvocation = Join-Path $verifyRoot 'INVOCATION.json'
$harnessJson = & $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File $harnessGuard -PowerShellScript $extractedAudit -Preflight -AsJson
Assert-True ($LASTEXITCODE -eq 0) 'Extracted audit harness guard failed.'
$harnessResult = $harnessJson | ConvertFrom-Json
Assert-True ([string]$harnessResult.state -eq 'PASS_ARGOS_POWERSHELL_HARNESS_SAFETY') 'Extracted audit harness state changed.'
$wrapperJson = & $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File $wrapperGuard -PowerShellScript $extractedAudit -CmdWrapper $extractedWrapper -InvocationManifest $extractedInvocation -RequirePreflightSwitch -AsJson
Assert-True ($LASTEXITCODE -eq 0) 'Extracted wrapper guard failed.'
$wrapperResult = $wrapperJson | ConvertFrom-Json
Assert-True ([string]$wrapperResult.state -eq 'PASS_ARGOS_POWERSHELL_WRAPPER_PREFLIGHT') 'Extracted wrapper state changed.'

[void](New-Item -ItemType Directory -Path $verifyReturnRoot)
$rehearsalInvocation = Get-Content -LiteralPath $extractedInvocation -Raw | ConvertFrom-Json
$rehearsalInvocation.rehearsal = $true
$rehearsalInvocation.outputRoot = Join-Path $partialRoot 'rehearsal_output'
$rehearsalInvocation.returnPath = Join-Path $verifyReturnRoot 'O2A2R.zip'
Write-JsonCreateNew -Path $rehearsalInvocationPath -Value $rehearsalInvocation -Depth 18
$rehearsalJson = & $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File $extractedAudit -InvocationManifest $rehearsalInvocationPath -Preflight -Rehearsal
Assert-True ($LASTEXITCODE -eq 0) 'Extracted audit rehearsal preflight failed.'
$rehearsalResult = $rehearsalJson | ConvertFrom-Json
Assert-True ([string]$rehearsalResult.state -eq 'PASS_O2A2_DIRECT_ADMIN_READ_ONLY_PREFLIGHT') 'Extracted rehearsal preflight state changed.'
Assert-True (-not (Test-Path -LiteralPath ([string]$rehearsalInvocation.outputRoot))) 'Rehearsal preflight created its output root.'
Assert-True (-not (Test-Path -LiteralPath ([string]$rehearsalInvocation.returnPath))) 'Rehearsal preflight created its return ZIP.'

$liveOutputRoot = 'C:\O2A2'
$liveLocalZip = Join-Path $verifyRoot 'O2A2R_LOCAL.zip'
$liveReturnZip = [string](Get-Content -LiteralPath $extractedInvocation -Raw | ConvertFrom-Json).returnPath
Assert-True (-not (Test-Path -LiteralPath $liveOutputRoot)) 'Live O2A2 root exists before extracted negative control.'
Assert-True (-not (Test-Path -LiteralPath $liveLocalZip)) 'Extracted local result exists before negative control.'
Assert-True (-not (Test-Path -LiteralPath $liveReturnZip)) 'Share return exists before negative control.'
$negativeText = & $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File $extractedAudit -InvocationManifest $extractedInvocation -Preflight 2>&1 | Out-String
$negativeExit = $LASTEXITCODE
Assert-True ($negativeExit -ne 0) 'Extracted live preflight did not refuse the laptop.'
Assert-True ($negativeText.Contains('O2A2 refuses this computer: TXSH-LUPW0JLTPR')) 'Extracted live preflight refusal signature changed.'
Assert-True (-not (Test-Path -LiteralPath $liveOutputRoot)) 'Negative control created the live output root.'
Assert-True (-not (Test-Path -LiteralPath $liveLocalZip)) 'Negative control created the local result ZIP.'
Assert-True (-not (Test-Path -LiteralPath $liveReturnZip)) 'Negative control created the share return ZIP.'

Copy-Item -LiteralPath $prepublicationGatePath -Destination (Join-Path $partialRoot 'O2A2_PREPUBLICATION_GATE.json') -ErrorAction Stop
$zipHash = Get-Sha256 $zipPath
$entryRows = @(
    foreach ($leaf in $pins.Keys) {
        [ordered]@{ path = [string]$leaf; sha256 = Get-Sha256 (Join-Path $verifyRoot $leaf); bytes = (Get-Item -LiteralPath (Join-Path $verifyRoot $leaf)).Length }
    }
)
$finalGate = [ordered]@{
    schema = 'argos_o2a2_final_package_gate_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_O2A2_FINAL_PACKAGE_GATE'
    lifecycle = 'FROZEN'
    revision = 'O2A2'
    zipLeaf = $zipLeaf
    zipSha256 = $zipHash
    zipBytes = (Get-Item -LiteralPath $zipPath).Length
    archiveEntryCount = $entryRows.Count
    archiveEntries = $entryRows
    exactZipExtractionPassed = $true
    extractedHarnessState = [string]$harnessResult.state
    extractedWrapperState = [string]$wrapperResult.state
    extractedRehearsalPreflightState = [string]$rehearsalResult.state
    extractedLaptopRefusalPassed = $true
    liveOutputRootCreated = $false
    shareReturnCreated = $false
    jbodContacted = $false
    targetMutationsPerformed = $false
    imageBytesRead = $false
    publicationAuthorized = $true
    oneObservationExecutionAuthorized = $true
    reviewOnly = $true
    productionRoutingEnabled = $false
}
Write-JsonCreateNew -Path (Join-Path $partialRoot 'O2A2_FINAL_PACKAGE_GATE.json') -Value $finalGate -Depth 12
Move-Item -LiteralPath $partialRoot -Destination $finalRoot
$finalGate | ConvertTo-Json -Depth 12

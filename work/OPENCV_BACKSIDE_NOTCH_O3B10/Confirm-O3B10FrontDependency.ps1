#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$path = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03CorpusR1\NativeFrontsideWaferPoseOpenCvV2R5.py'
$expected = '47F70976D0F3AE0461166D7D3438FE7B11FFE71E8257FD918554F7909E0B9E24'
if ($env:COMPUTERNAME -ne 'A1025645101') { throw 'Front dependency verification reached the wrong computer.' }
if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw 'Frozen R5 front dependency is absent after install.' }
if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $expected) { throw 'Frozen R5 front dependency hash mismatch.' }
[ordered]@{
    schema = 'argos_ocv03_front_dependency_install_v1'
    state = 'PASS_O3B10_FRONT_DEPENDENCY_INSTALLED'
    path = $path
    sha256 = $expected
    processActionPerformed = $false
    sourceImagesMutated = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
} | ConvertTo-Json -Compress

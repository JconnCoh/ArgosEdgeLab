#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$path = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03CorpusR1\NativeFrontsideWaferPoseOpenCvV2.py'
$expected = '304219822CC3C7CC8E0ED81BD89E230529057E47E0E7DA4C95FE041F3AF69FAC'
if ($env:COMPUTERNAME -ne 'A1025645101') { throw 'Front core dependency verification reached the wrong computer.' }
if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw 'Frozen front core dependency is absent after install.' }
if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $expected) { throw 'Frozen front core dependency hash mismatch.' }
[ordered]@{
    schema = 'argos_ocv03_front_core_dependency_install_v1'
    state = 'PASS_O3B10_FRONT_CORE_DEPENDENCY_INSTALLED'
    path = $path
    sha256 = $expected
    processActionPerformed = $false
    sourceImagesMutated = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
} | ConvertTo-Json -Compress

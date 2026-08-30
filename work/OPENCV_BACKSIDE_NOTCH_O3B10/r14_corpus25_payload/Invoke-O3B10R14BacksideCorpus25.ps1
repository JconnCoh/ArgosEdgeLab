#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
function Require([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Sha([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Quote([string]$Value) { if ($Value -notmatch '[\s"]') { return $Value }; return '"' + $Value.Replace('"', '\"') + '"' }

$python = 'D:\AFCV1\rt\python.exe'
$pythonHash = '7D96A4ED35D6E596CD9DD8933FEAFC66349CC21F75BE3B15C89FD336E50140C1'
$r1Root = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03CorpusR1'
$r2Root = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03CorpusR2'
$runner = Join-Path $r2Root 'Run-OpenCvKlarfCorpusR2.py'
$runnerHash = '20102DD8502EEC798BE1199B1B074922D24A8AE8343A180762EA1CD78BB8EFF6'
$front = Join-Path $r1Root 'FullPerimeterWaferTopologyOpenCvR7.py'
$frontHash = 'A6E63914D8669E3E733EA2BFC78FAF78F77B1FC5A54E9CC4D051F2AC34D2296B'
$back = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03_BacksideNotchDevelopment_O3B10R14.py'
$backHash = 'E8627409BC4134AFD653603DDE1795861ACEF46C8ED240F69CACBAD90A14F10D'
$backConfig = Join-Path $r1Root 'BACKSIDE_NOTCH_CONFIG_R2.json'
$backConfigHash = '38F9DFD4724EF12674FB27408539BF8525173B91DF9066573829DC02F6D20184'
$reviewRoot = 'D:\KLARFExport\_ArgosReview'
$output = Join-Path $reviewRoot 'C14RUN1'

Require ($env:COMPUTERNAME -eq 'A1025645101') 'Backside corpus launch reached the wrong computer.'
foreach ($dependency in @(
    @{Path=$python; Hash=$pythonHash},
    @{Path=$runner; Hash=$runnerHash},
    @{Path=$front; Hash=$frontHash},
    @{Path=$back; Hash=$backHash},
    @{Path=$backConfig; Hash=$backConfigHash}
)) {
    Require (Test-Path -LiteralPath $dependency.Path -PathType Leaf) "Backside corpus dependency absent: $($dependency.Path)"
    Require ((Sha $dependency.Path) -eq $dependency.Hash) "Backside corpus dependency changed: $($dependency.Path)"
}
Require (-not (Test-Path -LiteralPath $output)) 'Create-new backside corpus output already exists.'
if ($Preflight) {
    [ordered]@{state='PASS_O3B10_R14_BACKSIDE_CORPUS25_PREFLIGHT';pairLimit=25;side='BACK';output=$output;processStarted=$false;imageBytesRead=$false;reviewOnly=$true} | ConvertTo-Json -Compress
    return
}

[void](New-Item -ItemType Directory -Path $reviewRoot -Force)
[void](New-Item -ItemType Directory -Path $output)
$arguments = @(
    '-B', $runner,
    '--klarf-root', 'D:\KLARFExport',
    '--output-root', $output,
    '--front-engine', $front,
    '--front-dependency-root', $r1Root,
    '--back-engine', $back,
    '--back-config', $backConfig,
    '--side', 'BACK',
    '--maximum-pairs', '25',
    '--discovery-cap', '20000',
    '--stdout-log', (Join-Path $output 'runner.stdout.log'),
    '--stderr-log', (Join-Path $output 'runner.stderr.log')
)
$start = New-Object Diagnostics.ProcessStartInfo
$start.FileName = $python
$start.Arguments = (@($arguments | ForEach-Object { Quote ([string]$_) }) -join ' ')
$start.WorkingDirectory = $r2Root
$start.UseShellExecute = $true
$start.CreateNoWindow = $true
$start.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
$process = New-Object Diagnostics.Process
$process.StartInfo = $start
Require $process.Start() 'Backside corpus worker did not start.'
Start-Sleep -Seconds 3
Require (-not $process.HasExited) ("Backside corpus worker exited immediately with code $($process.ExitCode).")
[ordered]@{
    schema='argos_ocv03_r14_backside_corpus25_launch_v1'
    state='PASS_O3B10_R14_BACKSIDE_CORPUS25_LAUNCHED'
    pairLimit=25
    side='BACK'
    pid=$process.Id
    creationTimeUtc=$process.StartTime.ToUniversalTime().ToString('o')
    output=$output
    progressRelativePath='_ArgosReview/C14RUN1/SUMMARY.json'
    sourceImagesMutated=$false
    existingProcessActionPerformed=$false
    ownedProcessStarted=$true
    reviewOnly=$true
    productionRoutingEnabled=$false
} | ConvertTo-Json -Compress

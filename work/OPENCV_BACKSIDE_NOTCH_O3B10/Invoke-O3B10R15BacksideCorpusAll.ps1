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
$back = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03_BacksideNotchDevelopment_O3B10R15.py'
$backHash = 'F16A024EEA34F01502BD62B9C750FD6AA95D6BD75D9F8A03D07FBF7B2A0EB64C'
$backConfig = Join-Path $r1Root 'BACKSIDE_NOTCH_CONFIG_R3.json'
$backConfigHash = 'B3AD3EBDA8B89A6862E99E38D68BB05B939742A38A86A5B3A982745B1801B821'
$reviewRoot = 'D:\KLARFExport\_ArgosReview'
$output = Join-Path $reviewRoot 'C15RUN2'

Require ($env:COMPUTERNAME -eq 'A1025645101') 'R15 backside corpus launch reached the wrong computer.'
foreach ($dependency in @(
    @{Path=$python; Hash=$pythonHash},
    @{Path=$runner; Hash=$runnerHash},
    @{Path=$front; Hash=$frontHash},
    @{Path=$back; Hash=$backHash},
    @{Path=$backConfig; Hash=$backConfigHash}
)) {
    Require (Test-Path -LiteralPath $dependency.Path -PathType Leaf) "R15 corpus dependency absent: $($dependency.Path)"
    Require ((Sha $dependency.Path) -eq $dependency.Hash) "R15 corpus dependency changed: $($dependency.Path)"
}
Require (-not (Test-Path -LiteralPath $output)) 'Create-new R15 backside corpus output already exists.'
if ($Preflight) {
    [ordered]@{state='PASS_O3B10_R15_BACKSIDE_CORPUS_ALL_PREFLIGHT';expectedPairCount=943;side='BACK';output=$output;processStarted=$false;imageBytesRead=$false;reviewOnly=$true} | ConvertTo-Json -Compress
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
Require $process.Start() 'R15 backside corpus worker did not start.'
Start-Sleep -Seconds 3
Require (-not $process.HasExited) ("R15 backside corpus worker exited immediately with code $($process.ExitCode).")
[ordered]@{
    schema='argos_ocv03_r15_backside_corpus_all_launch_v1'
    state='PASS_O3B10_R15_BACKSIDE_CORPUS_ALL_LAUNCHED'
    expectedPairCount=943
    side='BACK'
    pid=$process.Id
    creationTimeUtc=$process.StartTime.ToUniversalTime().ToString('o')
    output=$output
    progressRelativePath='_ArgosReview/C15RUN2/SUMMARY.json'
    sourceImagesMutated=$false
    existingProcessActionPerformed=$false
    ownedProcessStarted=$true
    reviewOnly=$true
    productionRoutingEnabled=$false
} | ConvertTo-Json -Compress

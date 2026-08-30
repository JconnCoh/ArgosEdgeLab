#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight)
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
function Require([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}
function Sha([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash}
$python='D:\AFCV1\rt\python.exe';$pythonHash='7D96A4ED35D6E596CD9DD8933FEAFC66349CC21F75BE3B15C89FD336E50140C1'
$root='C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03CorpusR1'
$runner=Join-Path $root 'Run-OpenCvKlarfCorpus.py'
$front=Join-Path $root 'FullPerimeterWaferTopologyOpenCvR7.py'
$backConfig=Join-Path $root 'BACKSIDE_NOTCH_CONFIG.json'
$back='C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03_BacksideNotchDevelopment_O3B10R4.py'
$output='D:\C10I1'
Require ($env:COMPUTERNAME-eq'A1025645101') 'Corpus inventory reached the wrong computer.'
Require ((Sha $python)-eq$pythonHash) 'Corpus inventory Python runtime changed.'
foreach($path in @($runner,$front,$backConfig,$back)){Require (Test-Path -LiteralPath $path -PathType Leaf) "Corpus dependency absent: $path"}
Require (-not(Test-Path -LiteralPath $output)) 'Corpus inventory output already exists.'
if($Preflight){[ordered]@{state='PASS_O3B10_CORPUS_INVENTORY_PREFLIGHT';output=$output;imageBytesRead=$false;processStarted=$false;reviewOnly=$true}|ConvertTo-Json -Compress;return}
$arguments=@('-B',$runner,'--klarf-root','D:\KLARFExport','--output-root',$output,'--front-engine',$front,'--front-dependency-root',$root,'--back-engine',$back,'--back-config',$backConfig,'--discovery-cap','20000','--inventory-only')
$start=New-Object Diagnostics.ProcessStartInfo;$start.FileName=$python;$start.Arguments=($arguments|ForEach-Object{'"'+($_.Replace('"','\"'))+'"'})-join' ';$start.UseShellExecute=$false;$start.CreateNoWindow=$true;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
$process=New-Object Diagnostics.Process;$process.StartInfo=$start;Require $process.Start() 'Corpus inventory child did not start.';$outTask=$process.StandardOutput.ReadToEndAsync();$errTask=$process.StandardError.ReadToEndAsync();if(-not$process.WaitForExit(900000)){try{$process.Kill()}catch{};throw 'Corpus inventory exceeded 900 seconds.'};$stdout=$outTask.Result;$stderr=$errTask.Result;Require ($process.ExitCode-eq0) ('Corpus inventory failed: '+$stderr)
$terminal=$stdout.Trim()|ConvertFrom-Json;Require ([string]$terminal.state-eq'PASS_REVIEW_ONLY_KLARF_CORPUS_INVENTORY') 'Corpus inventory terminal state changed.'
[ordered]@{schema='argos_ocv03_corpus_inventory_terminal_v1';state='PASS_O3B10_CORPUS_INVENTORY';pairCount=[int]$terminal.pairCount;sourceProblemCount=[int]$terminal.sourceProblemCount;inventoryPath=[string]$terminal.inventoryPath;ownedChildProcessCount=1;sourceMutationPerformed=$false;existingProcessActionPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Compress

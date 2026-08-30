#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight)
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
function Require([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}
function Sha([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash}
function Quote([string]$Value){if($Value-notmatch'[\s"]'){return $Value};return '"'+$Value.Replace('"','\"')+'"'}
$python='D:\AFCV1\rt\python.exe';$pythonHash='7D96A4ED35D6E596CD9DD8933FEAFC66349CC21F75BE3B15C89FD336E50140C1'
$root='C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03CorpusR1'
$runner=Join-Path $root 'Run-OpenCvKlarfCorpus.py';$runnerHash='37B2205F2C871A3F37C791DFF7CDFC216E249EEBDD97A0116DD9E151AFE5E884'
$front=Join-Path $root 'FullPerimeterWaferTopologyOpenCvR7.py';$backConfig=Join-Path $root 'BACKSIDE_NOTCH_CONFIG.json'
$back='C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03_BacksideNotchDevelopment_O3B10R5.py'
$scribe=Join-Path $root 'ArgosOpenCvScribeV1R5.py'
$referenceZip=Join-Path $PSScriptRoot 'C10_REFERENCES.zip';$referenceZipHash='F383E88CD27FC1A415B47E25C93D5011D7BD00B88BE2383B4F72333534A99EDF'
$reviewRoot='D:\KLARFExport\_ArgosReview';$references=Join-Path $reviewRoot 'C10RES1';$referencePartial=$references+'.partial';$output=Join-Path $reviewRoot 'C10RUN1'
Require ($env:COMPUTERNAME-eq'A1025645101') 'Corpus launch reached the wrong computer.'
Require ((Sha $python)-eq$pythonHash) 'Corpus launch Python runtime changed.'
Require ((Sha $runner)-eq$runnerHash) 'Corpus runner changed.'
foreach($path in @($front,$backConfig,$back,$scribe,$referenceZip)){Require (Test-Path -LiteralPath $path -PathType Leaf) "Corpus launch dependency absent: $path"}
Require ((Sha $referenceZip)-eq$referenceZipHash) 'Corpus reference ZIP changed.'
Require (-not(Test-Path -LiteralPath $references)) 'Corpus reference root already exists.'
Require (-not(Test-Path -LiteralPath $referencePartial)) 'Corpus reference partial already exists.'
Require (-not(Test-Path -LiteralPath $output)) 'Corpus output root already exists.'
if($Preflight){[ordered]@{state='PASS_O3B10_CORPUS_LAUNCH_PREFLIGHT';pairCount=1886;output=$output;references=$references;processStarted=$false;imageBytesRead=$false;reviewOnly=$true}|ConvertTo-Json -Compress;return}
[void](New-Item -ItemType Directory -Path $reviewRoot -Force)
[void](New-Item -ItemType Directory -Path $referencePartial)
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::ExtractToDirectory($referenceZip,$referencePartial)
$manifest=Join-Path $referencePartial 'PORTABLE_GLYPH_REFERENCE_MANIFEST.json'
Require ((Sha $manifest)-eq'AECAF49BD0ACFC07C4B2973AF1889ABD9F3708C1411820A667FD6330B90F1229') 'Corpus reference manifest changed after extraction.'
Move-Item -LiteralPath $referencePartial -Destination $references
[void](New-Item -ItemType Directory -Path $output)
$arguments=@('-B',$runner,'--klarf-root','D:\KLARFExport','--output-root',$output,'--front-engine',$front,'--front-dependency-root',$root,'--back-engine',$back,'--back-config',$backConfig,'--scribe-engine',$scribe,'--reference-manifest',(Join-Path $references 'PORTABLE_GLYPH_REFERENCE_MANIFEST.json'),'--reference-root',('glyphs='+(Join-Path $references 'glyphs')),'--reference-root',('glyphs_v5_confirmed_20260806='+(Join-Path $references 'glyphs_v5_confirmed_20260806')),'--discovery-cap','20000','--stdout-log',(Join-Path $output 'runner.stdout.log'),'--stderr-log',(Join-Path $output 'runner.stderr.log'))
$start=New-Object Diagnostics.ProcessStartInfo;$start.FileName=$python;$start.Arguments=(@($arguments|ForEach-Object{Quote ([string]$_)})-join' ');$start.WorkingDirectory=$root;$start.UseShellExecute=$true;$start.CreateNoWindow=$true;$start.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden
$process=New-Object Diagnostics.Process;$process.StartInfo=$start;Require $process.Start() 'Corpus worker did not start.';Start-Sleep -Seconds 3;Require (-not$process.HasExited) ("Corpus worker exited immediately with code $($process.ExitCode).")
[ordered]@{schema='argos_ocv03_corpus_worker_launch_v1';state='PASS_O3B10_CORPUS_WORKER_LAUNCHED';pairCount=1886;pid=$process.Id;creationTimeUtc=$process.StartTime.ToUniversalTime().ToString('o');output=$output;progressRelativePath='_ArgosReview/C10RUN1/SUMMARY.json';stdoutRelativePath='_ArgosReview/C10RUN1/runner.stdout.log';stderrRelativePath='_ArgosReview/C10RUN1/runner.stderr.log';sourceImagesMutated=$false;existingProcessActionPerformed=$false;ownedProcessStarted=$true;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Compress

[CmdletBinding()]
param([switch]$Preflight = $true)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if(-not $Preflight){throw 'Specify -Preflight.'}
$o='D:\A2\o\ocv\R18R2';$w='D:\A2\w\ocv\R18R2'
function F([string]$p){
 if(-not(Test-Path -LiteralPath $p -PathType Leaf)){return [pscustomobject]@{path=$p;exists=$false}}
 $i=Get-Item -LiteralPath $p
 [pscustomobject]@{path=$p;exists=$true;bytes=[int64]$i.Length;sha256=(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash;lastWriteUtc=$i.LastWriteTimeUtc.ToString('o')}
}
$cp=Join-Path $w 'RUNTIME_CONFIGURATION.json'
$c=$null
if(Test-Path -LiteralPath $cp -PathType Leaf){
 if((Get-Item -LiteralPath $cp).Length -gt 1048576){throw 'Oversized runtime config.'}
 $c=Get-Content -LiteralPath $cp -Raw|ConvertFrom-Json
}
$f=@(
 F (Join-Path $o 'FAILURE.json')
 F $cp
 F (Join-Path $w 'OPENCV_SCRIBE_R18R\Run-R18RReferenceIsolatedCorpus.py')
 F (Join-Path $w 'OPENCV_SCRIBE_R18R\ArgosOpenCvScribeV1R18R.py')
 F (Join-Path $w 'OPENCV_SCRIBE_R18P\Run-R18PReferenceIsolatedCorpus.py')
)
[ordered]@{
 schema='argos_opencv_scribe_r18r2_terminal_state_observation_v1';checkedUtc=[DateTime]::UtcNow.ToString('o')
 state='PASS_R18R2_TERMINAL_STATE_OBSERVED';computerName=$env:COMPUTERNAME;process37456Present=($null-ne(Get-Process -Id 37456 -ErrorAction SilentlyContinue));files=$f
 configuration=$(if($null-eq$c){$null}else{[ordered]@{schema=$c.schema;revision=$c.revision;proposalRoot=$c.proposalRoot;providerPath=$c.providerPath;providerSha256=$c.providerSha256;cropSweepPath=$c.cropSweepPath;cropSweepSha256=$c.cropSweepSha256;reviewCaseCount=@($c.reviewCases).Count;authority=$c.authority}})
 sourceImagesReadByObservation=$false;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false
}|ConvertTo-Json -Depth 8 -Compress

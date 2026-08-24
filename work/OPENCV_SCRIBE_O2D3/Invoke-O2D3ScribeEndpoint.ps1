[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Rehearsal,
    [string]$PayloadRoot=$PSScriptRoot,
    [string]$RuntimeRoot='D:\AFCV1\rt',
    [string]$WorkRoot='D:\A2\w\ocv\O2D3',
    [string]$OutputRoot='D:\A2\o\ocv\O2D3',
    [string]$SourceAliasRoot='D:\KLARFExport\PatternedFront\Lot_62619-433',
    [string]$RehearsalJobPath=''
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
function Get-Sha256([string]$LiteralPath){$s=[IO.File]::OpenRead($LiteralPath);$h=[Security.Cryptography.SHA256]::Create();try{return([BitConverter]::ToString($h.ComputeHash($s))).Replace('-','')}finally{$h.Dispose();$s.Dispose()}}
function Assert-File([string]$LiteralPath,[string]$Expected){if(-not(Test-Path -LiteralPath $LiteralPath -PathType Leaf)){throw "O2D3 required file missing: $LiteralPath"};if((Get-Sha256 $LiteralPath)-ne$Expected){throw "O2D3 required file changed: $LiteralPath"}}
function Invoke-BoundedPython([string]$Python,[string]$Engine,[string]$Job,[string]$Result,[int]$TimeoutMs){
    $si=New-Object Diagnostics.ProcessStartInfo;$si.FileName=$Python;$si.Arguments='"'+$Engine+'" --job "'+$Job+'" --result "'+$Result+'"';$si.UseShellExecute=$false;$si.CreateNoWindow=$true;$si.RedirectStandardOutput=$true;$si.RedirectStandardError=$true
    $p=New-Object Diagnostics.Process;$p.StartInfo=$si;if(-not$p.Start()){throw'O2D3 Python did not start.'};$ot=$p.StandardOutput.ReadToEndAsync();$et=$p.StandardError.ReadToEndAsync();if(-not$p.WaitForExit($TimeoutMs)){try{$p.Kill()}catch{};throw"O2D3 Python exceeded $TimeoutMs milliseconds."};$r=[pscustomobject]@{ExitCode=$p.ExitCode;Stdout=$ot.Result;Stderr=$et.Result};$p.Dispose();return$r
}

$engineSource=Join-Path $PayloadRoot 'ArgosOpenCvScribeV1.py'
$bundle=Join-Path $PayloadRoot 'O2D3_REFS.zip'
$jobSource=if($Rehearsal-and-not[string]::IsNullOrWhiteSpace($RehearsalJobPath)){$RehearsalJobPath}else{Join-Path $PayloadRoot 'O2D3_SLOT16_JOB.json'}
$python=Join-Path $RuntimeRoot 'python.exe'
$subst=Join-Path $env:SystemRoot 'System32\subst.exe'
$installation='D:\AFCV1\INSTALLATION.json'
$engineSha='3CE7E93B9C922B02DE8E8BF712FC715BE24FF7D232B7EC3DDBB86EC7A05273B9'
$bundleSha='56DF00E37A195E7BC3E026E4950DFB5A0AA7E7AF49A6FF39020B071840CCFBD6'
$jobSha='21E829F4D6703218CEC58ABB366DD18A40AE019A129D1043291ACE2729763A6C'
$installationSha='1289EC11F092233D3AAB5ACF416B0212F1874F698F9BBC2B474829939BCDF596'
$aliasName='X:';$aliasPath='X:\';$partial=$WorkRoot+'.partial';$failed=$WorkRoot+'.failed';$resultPath=Join-Path $OutputRoot 'RESULT.json';$gatePath=Join-Path $OutputRoot 'RUN_GATE.json'
Assert-File $engineSource $engineSha;Assert-File $bundle $bundleSha
if($Rehearsal){if(-not(Test-Path -LiteralPath $jobSource -PathType Leaf)){throw'O2D3 rehearsal job missing.'}}else{Assert-File $jobSource $jobSha;Assert-File $installation $installationSha}
foreach($p in @($python,$subst)){if(-not(Test-Path -LiteralPath $p -PathType Leaf)){throw"O2D3 executable missing: $p"}}
if(-not(Test-Path -LiteralPath $SourceAliasRoot -PathType Container)){throw"O2D3 alias anchor missing: $SourceAliasRoot"}
$pc=Get-Command -Name $python -CommandType Application -ErrorAction Stop;$sc=Get-Command -Name $subst -CommandType Application -ErrorAction Stop
if(-not[IO.Path]::GetFullPath($pc.Source).Equals([IO.Path]::GetFullPath($python),[StringComparison]::OrdinalIgnoreCase)-or-not[IO.Path]::GetFullPath($sc.Source).Equals([IO.Path]::GetFullPath($subst),[StringComparison]::OrdinalIgnoreCase)){throw'O2D3 executable resolution changed.'}
if((Test-Path -LiteralPath $aliasPath)-or$null-ne(Get-PSDrive -Name X -ErrorAction SilentlyContinue)){throw'O2D3 X: is already in use.'}
$job=Get-Content -Raw -LiteralPath $jobSource|ConvertFrom-Json
if([string]$job.schema-ne'argos_opencv_scribe_job_v1'-or-not[bool]$job.authority.reviewOnly-or[bool]$job.authority.automaticIdentityAuthority-or[bool]$job.authority.productionEligible-or[bool]$job.authority.mayClearHolds-or-not[bool]$job.search.boundedExceptionSearch){throw'O2D3 job contract changed.'}
foreach($channel in @('bf','df')){$src=$job.inputs.$channel;if([string]$src.ioPathClass-ne'SHORT_DOS_DEVICE_ALIAS'-or[string]$src.aliasName-ne$aliasName-or[string]$src.aliasAnchorCanonicalPath-ne$SourceAliasRoot-or-not([string]$src.path).StartsWith($aliasPath,[StringComparison]::OrdinalIgnoreCase)-or-not([string]$src.canonicalProvenancePath).StartsWith('D:\',[StringComparison]::OrdinalIgnoreCase)){throw"O2D3 source contract changed: $channel"}}
if(-not$Rehearsal){if([string]$job.identity.lotId-ne'62619-433'-or[string]$job.identity.slotId-ne'Slot16'-or@($job.search.expectedRegions).Count-ne 0-or[string]$job.outputRoot-ne$OutputRoot){throw'O2D3 live identity contract changed.'}}
foreach($p in @($WorkRoot,$partial,$failed,$OutputRoot,$resultPath,$gatePath)){if(Test-Path -LiteralPath $p){throw"O2D3 create-new target exists: $p"}}
if($Preflight){[ordered]@{schema='argos_o2d3_endpoint_preflight_v1';state='PASS_O2D3_ENDPOINT_PREFLIGHT';rehearsal=[bool]$Rehearsal;runtimeExecutable=$python;substExecutable=$subst;engineSha256=$engineSha;bundleSha256=$bundleSha;jobSha256=Get-Sha256 $jobSource;workRoot=$WorkRoot;outputRoot=$OutputRoot;sourceAliasName=$aliasName;sourceAliasRoot=$SourceAliasRoot;sourceAliasPresentBefore=$false;sourceImageBytesRead=$false;imagePixelsDecoded=$false;processStarted=$false;mutationsPerformed=$false;reviewOnly=$true;productionEligible=$false}|ConvertTo-Json -Depth 6;return}

$aliasCreated=$false;$failureMessage='';$result=$null
try{
    [void](New-Item -ItemType Directory -Path $partial -Force);Add-Type -AssemblyName System.IO.Compression.FileSystem;[IO.Compression.ZipFile]::ExtractToDirectory($bundle,$partial)
    $enginePath=Join-Path $partial 'ArgosOpenCvScribeV1.py';$jobPath=Join-Path $partial 'JOB.json';Copy-Item -LiteralPath $engineSource -Destination $enginePath;Copy-Item -LiteralPath $jobSource -Destination $jobPath
    if((Get-Sha256 $enginePath)-ne$engineSha-or(Get-Sha256 $jobPath)-ne(Get-Sha256 $jobSource)){throw'O2D3 staged payload changed.'};Move-Item -LiteralPath $partial -Destination $WorkRoot;$enginePath=Join-Path $WorkRoot 'ArgosOpenCvScribeV1.py';$jobPath=Join-Path $WorkRoot 'JOB.json'
    $create=& $subst $aliasName $SourceAliasRoot 2>&1|Out-String;if($LASTEXITCODE-ne 0-or-not(Test-Path -LiteralPath $aliasPath -PathType Container)){throw('O2D3 alias creation failed: '+$create.Trim())};$aliasCreated=$true
    $allMappings=& $subst 2>&1|Out-String;$matching=@(($allMappings-split'\r?\n')|Where-Object{$_-match'(?i)^\s*X:\\:\s*=>\s*(.+?)\s*$'})
    if($matching.Count-ne 1){throw'O2D3 alias mapping cardinality changed.'};$match=[regex]::Match($matching[0],'(?i)^\s*X:\\:\s*=>\s*(.+?)\s*$');$target=$match.Groups[1].Value.Trim().TrimEnd('\')
    if(-not$target.Equals($SourceAliasRoot.TrimEnd('\'),[StringComparison]::OrdinalIgnoreCase)){throw"O2D3 alias target mismatch: $target"}
    $inv=Invoke-BoundedPython -Python $python -Engine $enginePath -Job $jobPath -Result $resultPath -TimeoutMs 1800000;if($inv.ExitCode-ne 0){throw('O2D3 provider failed with exit '+$inv.ExitCode+': '+$inv.Stderr.Trim())}
    if(-not(Test-Path -LiteralPath $resultPath -PathType Leaf)){throw'O2D3 result missing.'};$result=Get-Content -Raw -LiteralPath $resultPath|ConvertFrom-Json
    if([string]$result.schema-ne'argos_opencv_scribe_result_v1'-or[string]$result.revision-ne'ARGOS_OPENCV_SCRIBE_V1R2_20260824'-or[bool]$result.eligibleIdentity-or-not[bool]$result.authority.reviewOnly-or[bool]$result.authority.automaticIdentityAuthority-or[bool]$result.authority.productionEligible-or[bool]$result.authority.mayClearHolds){throw'O2D3 result authority changed.'}
    foreach($channel in @('bf','df')){$ev=$result.provenance.sources.$channel;if([string]$ev.ioPathClass-ne'SHORT_DOS_DEVICE_ALIAS'-or[string]$ev.aliasName-ne$aliasName-or[string]$ev.aliasAnchorCanonicalPath-ne$SourceAliasRoot-or[string]::IsNullOrWhiteSpace([string]$ev.canonicalProvenancePath)){throw"O2D3 result provenance changed: $channel"}}
    if([int]$result.provenance.references.referenceCount-ne 456-or[string]$result.provenance.references.missingBodyReferenceLabels-ne'IJKOQVWXYZ'-or-not[bool]$result.provenance.bfDfIndependent-or-not[bool]$result.provenance.boundedExceptionSearchUsed-or[bool]$result.provenance.fixedImageRectangleUsed){throw'O2D3 provider provenance changed.'}
}catch{$failureMessage=$_.Exception.Message}finally{if($aliasCreated){$remove=& $subst $aliasName '/D' 2>&1|Out-String;if($LASTEXITCODE-ne 0-and[string]::IsNullOrWhiteSpace($failureMessage)){$failureMessage='O2D3 alias removal failed: '+$remove.Trim()}}}
$aliasRemoved=(-not(Test-Path -LiteralPath $aliasPath))-and$null-eq(Get-PSDrive -Name X -ErrorAction SilentlyContinue)
if(-not$aliasRemoved-and[string]::IsNullOrWhiteSpace($failureMessage)){$failureMessage='O2D3 alias remains after exit.'}
if(-not[string]::IsNullOrWhiteSpace($failureMessage)){if(Test-Path -LiteralPath $partial){if(-not(Test-Path -LiteralPath $failed)){Move-Item -LiteralPath $partial -Destination $failed -ErrorAction SilentlyContinue}};[ordered]@{schema='argos_o2d3_endpoint_failure_v1';state='HOLD_O2D3_OPENCV_SCRIBE_ENDPOINT_ERROR';detail=$failureMessage;sourceAliasName=$aliasName;sourceAliasRemoved=$aliasRemoved;inspectionTasksChanged=$false;processorTaskChanged=$false;sourceDeletionPerformed=$false;waferActionPerformed=$false;reviewOnly=$true;productionEligible=$false}|ConvertTo-Json -Depth 5 -Compress|Write-Error;throw$failureMessage}
$candidates=@($result.candidates|ForEach-Object{[ordered]@{string=[string]$_.string;directImageFirstSupport=[bool]$_.directImageFirstSupport;channels=@($_.channels);polarities=@($_.polarities);maximumScore=[double]$_.maximumScore}})
$gate=[ordered]@{schema='argos_o2d3_opencv_scribe_development_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D3_OPENCV_SCRIBE_DEVELOPMENT_EXECUTED';disposition='PENDING_GATE';rehearsal=[bool]$Rehearsal;lotId=[string]$job.identity.lotId;acquisitionId=[string]$job.identity.acquisitionId;slotId=[string]$job.identity.slotId;engineSha256=$engineSha;jobSha256=Get-Sha256 $jobPath;bundleSha256=$bundleSha;resultPath=$resultPath;resultSha256=Get-Sha256 $resultPath;resultState=[string]$result.state;imageFirstString=[string]$result.imageFirstString;checksumState=[string]$result.checksumState;localization=$result.localization;candidates=$candidates;holds=@($result.holds);inputProvenance=$result.provenance.sources;sourceAliasName=$aliasName;sourceAliasRoot=$SourceAliasRoot;sourceAliasCreated=$true;sourceAliasTargetVerified=$true;sourceAliasRemoved=$true;referenceCoverageComplete=[bool]$result.provenance.references.referenceCoverageComplete;missingReferenceLabels=[string]$result.provenance.references.missingBodyReferenceLabels;boundedExceptionSearchUsed=[bool]$result.provenance.boundedExceptionSearchUsed;fixedImageRectangleUsed=[bool]$result.provenance.fixedImageRectangleUsed;inspectionTasksChanged=$false;processorTaskChanged=$false;sourceMutationPerformed=$false;sourceDeletionPerformed=$false;waferActionPerformed=$false;holdsCleared=$false;providerActivated=$false;reviewOnly=$true;productionEligible=$false}
[IO.File]::WriteAllText($gatePath,(($gate|ConvertTo-Json -Depth 12)+[Environment]::NewLine),(New-Object Text.UTF8Encoding($false)));$gate|ConvertTo-Json -Depth 12 -Compress

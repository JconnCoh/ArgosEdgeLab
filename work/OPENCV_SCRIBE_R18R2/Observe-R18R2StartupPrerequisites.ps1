[CmdletBinding()]
param([switch]$Preflight = $true)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if(-not $Preflight){throw 'Specify -Preflight.'}
$w='D:\A2\w\ocv\R18R2';$cp=Join-Path $w 'RUNTIME_CONFIGURATION.json'
if(-not(Test-Path -LiteralPath $cp -PathType Leaf)){throw 'Runtime configuration absent.'}
$c=Get-Content -LiteralPath $cp -Raw|ConvertFrom-Json
$rows=@()
foreach($x in @($c.reviewCases)){
 $id=[string]$x.physicalIdentity;$d=Join-Path ([string]$c.proposalRoot) $id
 $bf=Join-Path $d 'BF_SCRIBE_ORIENTED_DETECTOR_INPUT.png'
 $df=Join-Path $d 'DF_SCRIBE_ORIENTED_DETECTOR_INPUT.png'
 $rows+=[pscustomobject]@{physicalIdentity=$id;directoryPresent=(Test-Path -LiteralPath $d -PathType Container);bfPresent=(Test-Path -LiteralPath $bf -PathType Leaf);dfPresent=(Test-Path -LiteralPath $df -PathType Leaf)}
}
$missing=@($rows|Where-Object{-not$_.directoryPresent-or-not$_.bfPresent-or-not$_.dfPresent})
$pairs=@($c.reviewCases|ForEach-Object{([string]$_.bfSha256).ToUpperInvariant()+'|'+([string]$_.dfSha256).ToUpperInvariant()})
$refs=@(
 [pscustomobject]@{name='baseManifest';present=(Test-Path -LiteralPath ([string]$c.references.manifestPath) -PathType Leaf)}
 [pscustomobject]@{name='supplementalManifest';present=(Test-Path -LiteralPath ([string]$c.references.supplementalManifestPath) -PathType Leaf)}
)
[ordered]@{
 schema='argos_opencv_scribe_r18r2_startup_prerequisite_observation_v1';checkedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R18R2_STARTUP_PREREQUISITES_OBSERVED';computerName=$env:COMPUTERNAME
 reviewCaseCount=$rows.Count;missingCaseCount=$missing.Count;missingCases=$missing;duplicateConfiguredSourcePairCount=($pairs.Count-@($pairs|Sort-Object -Unique).Count);referencePaths=$refs
 sourceImageBytesRead=$false;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false
}|ConvertTo-Json -Depth 6 -Compress

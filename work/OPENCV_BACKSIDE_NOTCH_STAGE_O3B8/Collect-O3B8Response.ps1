#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight,[switch]$Collect)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if([bool]$Preflight -eq [bool]$Collect){throw 'Specify exactly one mode.'}
function Assert-O3B8([bool]$Value,[string]$Message){if(-not $Value){throw $Message}}
function Get-Sha([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash}
function Get-Required([object]$Object,[string]$Name){$p=$Object.PSObject.Properties[$Name];if($null-eq$p){throw "Required property absent: $Name"};$p.Value}
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$requestId='REQ_O3B8_20260828A'
$responseToken='R_7C9CE498A3CE_20260828225916939_4aba731c'
$sourceZip='U:\ProjectPortalRO\responses\'+$responseToken+'.ready.zip'
$zipBytes=2663
$zipHash='DE38C4BBFBEF71D73F68875CA0AED620ADF52FD71EDAF813FFF5E2ED2159AA2D'
$responseRoot=Join-Path $PSScriptRoot 'response_exact'
$readyRoot=Join-Path $responseRoot ($responseToken+'.ready')
$partialRoot=$readyRoot+'.partial'
$terminalGate=Join-Path $PSScriptRoot 'O3B8_SIGNED_TERMINAL_RESPONSE_GATE.json'
$verifier=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalResponse.ps1'
$certificate=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\active\JBOD_ENDPOINT_SIGNER.cer'
foreach($path in @($sourceZip,$verifier,$certificate)){Assert-O3B8 (Test-Path -LiteralPath $path -PathType Leaf) "O3B8 collection prerequisite missing: $path"}
Assert-O3B8 ((Get-Item -LiteralPath $sourceZip).Length -eq $zipBytes -and (Get-Sha $sourceZip) -eq $zipHash) 'O3B8 response ZIP changed.'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive=[IO.Compression.ZipFile]::OpenRead($sourceZip)
try{
  $entry=$archive.GetEntry('PORTAL_RESPONSE_MANIFEST.json')
  Assert-O3B8 ($null-ne$entry -and $entry.Length -le 1048576) 'O3B8 response manifest entry missing or too large.'
  $stream=$entry.Open();$reader=New-Object IO.StreamReader($stream,(New-Object Text.UTF8Encoding($false,$true)))
  try{$manifest=$reader.ReadToEnd()|ConvertFrom-Json}finally{$reader.Dispose();$stream.Dispose()}
}finally{$archive.Dispose()}
Assert-O3B8 ([string](Get-Required $manifest 'requestId') -eq $requestId -and [string](Get-Required $manifest 'responseId') -eq $responseToken -and [string](Get-Required $manifest 'state') -eq 'PASS_MAINTENANCE_PATCH' -and [string](Get-Required $manifest 'sourceRole') -eq 'JBOD' -and [bool](Get-Required $manifest 'reviewOnly') -and -not [bool](Get-Required $manifest 'productionRoutingEnabled')) 'O3B8 response terminal manifest contract changed.'
foreach($path in @($readyRoot,$partialRoot,$terminalGate)){Assert-O3B8 (-not(Test-Path -LiteralPath $path)) "O3B8 create-new collection target exists: $path"}
if($Preflight){[ordered]@{schema='argos_ocv03_o3b8_response_collection_preflight_v1';state='PASS_O3B8_RESPONSE_COLLECTION_PREFLIGHT';requestId=$requestId;responseToken=$responseToken;sourceZipBytes=$zipBytes;sourceZipSha256=$zipHash;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 5;return}
[void](New-Item -ItemType Directory -Path $partialRoot)
[IO.Compression.ZipFile]::ExtractToDirectory($sourceZip,$partialRoot)
& $verifier -PackagePath $partialRoot -EndpointCertificatePath $certificate -ExpectedSourceRole JBOD -ExpectedRequestId $requestId|Out-Null
$stdoutPath=Join-Path $partialRoot 'MAINTENANCE.stdout.txt'
$stderrPath=Join-Path $partialRoot 'MAINTENANCE.stderr.txt'
$resultPath=Join-Path $partialRoot 'RESULT.json'
foreach($path in @($stdoutPath,$stderrPath,$resultPath)){Assert-O3B8 (Test-Path -LiteralPath $path -PathType Leaf) "O3B8 response file missing: $path"}
Assert-O3B8 ((Get-Item -LiteralPath $stderrPath).Length -eq 0 -and (Get-Item -LiteralPath $stdoutPath).Length -le 1048576) 'O3B8 maintenance output bounds changed.'
$stage=Get-Content -LiteralPath $stdoutPath -Raw|ConvertFrom-Json
$maintenance=Get-Content -LiteralPath $resultPath -Raw|ConvertFrom-Json
$sources=@(Get-Required $stage 'sources')
Assert-O3B8 ([string](Get-Required $stage 'schema') -eq 'argos_ocv03_o3b8_short_stage_result_v1' -and [string](Get-Required $stage 'state') -eq 'PASS_O3B8_EXACT_BACKSIDE_PAIR_STAGED' -and [string](Get-Required $stage 'outputRoot') -eq 'D:\B8O1' -and [string](Get-Required $stage 'aliasDrive') -eq 'Q:' -and [bool](Get-Required $stage 'aliasRemoved') -and $sources.Count -eq 2 -and [int](Get-Required $stage 'sourceImageReadCount') -eq 2 -and -not [bool](Get-Required $stage 'imageDecoded') -and -not [bool](Get-Required $stage 'pixelProcessingPerformed') -and -not [bool](Get-Required $stage 'sourceMutationPerformed') -and -not [bool](Get-Required $stage 'sourceDeletionPerformed') -and -not [bool](Get-Required $stage 'taskOrExistingProcessActionPerformed') -and -not [bool](Get-Required $stage 'providerActivated') -and -not [bool](Get-Required $stage 'thresholdOrAlgorithmChanged') -and -not [bool](Get-Required $stage 'holdsCleared')) 'O3B8 signed stage result contract changed.'
$expected=@{BF_BACKSIDE=@('BF.bmp','F41BDF5CAAFDABF4C8A9BFCE21B0CB0587AA74C93354C3B41B099713B4CB290B');DF_BACKSIDE=@('DF.bmp','8546F979E83B9749CCFEB1241DAF0393D24534DB8F5E94706DFCD8D3FDC9BB7C')}
foreach($row in $sources){$channel=[string](Get-Required $row 'channel');Assert-O3B8 ($expected.ContainsKey($channel)) "Unexpected O3B8 channel: $channel";$pair=$expected[$channel];Assert-O3B8 ([string](Get-Required $row 'outputName') -eq $pair[0] -and [string](Get-Required $row 'sourceSha256') -eq $pair[1] -and [string](Get-Required $row 'outputSha256') -eq $pair[1] -and [int64](Get-Required $row 'sourceBytes') -eq 475379874 -and [int64](Get-Required $row 'outputBytes') -eq 475379874 -and [bool](Get-Required $row 'sourceStableDuringCopy')) "O3B8 signed source/output row failed: $channel"}
Assert-O3B8 ([string](Get-Required $maintenance 'state') -eq 'PASS_MAINTENANCE_PATCH' -and [int](Get-Required $maintenance 'exitCode') -eq 0 -and [bool](Get-Required $maintenance 'reviewOnly') -and -not [bool](Get-Required $maintenance 'productionRoutingEnabled')) 'O3B8 maintenance result changed.'
Move-Item -LiteralPath $partialRoot -Destination $readyRoot
$gate=[ordered]@{schema='argos_ocv03_o3b8_signed_terminal_response_gate_v1';collectedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3B8_SIGNED_EXACT_BACKSIDE_PAIR_STAGED';requestId=$requestId;responseToken=$responseToken;sourceZipBytes=$zipBytes;sourceZipSha256=$zipHash;signedResponseVerified=$true;endpointState='PASS_MAINTENANCE_PATCH';stageState='PASS_O3B8_EXACT_BACKSIDE_PAIR_STAGED';outputRoot='D:/B8O1';brightfield=[ordered]@{path='D:/B8O1/BF.bmp';bytes=475379874;sha256=$expected.BF_BACKSIDE[1]};darkfield=[ordered]@{path='D:/B8O1/DF.bmp';bytes=475379874;sha256=$expected.DF_BACKSIDE[1]};aliasRemoved=$true;sourceStableDuringCopy=$true;sourceMutationPerformed=$false;sourceDeletionPerformed=$false;taskOrExistingProcessActionPerformed=$false;imageDecoded=$false;pixelProcessingPerformed=$false;providerActivated=$false;thresholdOrAlgorithmChanged=$false;holdsCleared=$false;retryAuthorized=$false;collectedRoot=$readyRoot;reviewOnly=$true;productionRoutingEnabled=$false}
[IO.File]::WriteAllText($terminalGate,(($gate|ConvertTo-Json -Depth 8)+[Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))
$gate|ConvertTo-Json -Depth 8

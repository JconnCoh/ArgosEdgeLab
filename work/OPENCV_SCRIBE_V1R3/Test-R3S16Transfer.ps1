#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight,[switch]$Gate)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if(([bool]$Preflight)-eq([bool]$Gate)){throw'Specify exactly one of -Preflight or -Gate.'}
$zip=Join-Path $PSScriptRoot 'R3S16_PAYLOAD.zip'
$chunkRoot=Join-Path $PSScriptRoot 'transfer_chunks'
$gatePath=Join-Path $PSScriptRoot 'R3S16_TRANSFER_GATE.json'
$expectedZipSha='33B183483B25FDF9F48C102E61C5457F802B72BCE9418C34A782AF18E5456279'
function Assert-Exact([bool]$Condition,[string]$Message){if(-not$Condition){throw$Message}}
function Get-ExactShaBytes([byte[]]$Bytes){$hasher=[Security.Cryptography.SHA256]::Create();try{return([BitConverter]::ToString($hasher.ComputeHash($Bytes))).Replace('-','')}finally{$hasher.Dispose()}}
Assert-Exact (Test-Path -LiteralPath $zip -PathType Leaf) 'Payload ZIP absent.'
Assert-Exact ((Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash-eq$expectedZipSha) 'Payload ZIP changed.'
$scripts=@(Get-ChildItem -LiteralPath $chunkRoot -Filter 'Stage-R3S16-Part-*.ps1' -File|Sort-Object Name)
Assert-Exact ($scripts.Count-eq 22) 'Transfer script count changed.'
$rows=New-Object Collections.Generic.List[object]
$memory=New-Object IO.MemoryStream
try{
  for($index=0;$index-lt$scripts.Count;$index++){
    $script=$scripts[$index]
    Assert-Exact ($script.Name-eq('Stage-R3S16-Part-{0:d3}.ps1'-f$index)) "Transfer script order changed: $($script.Name)"
    Assert-Exact ($script.Length-le 2048) "Transfer script exceeds proven command class: $($script.Name)"
    $tokens=$null;$errors=$null
    [Management.Automation.Language.Parser]::ParseFile($script.FullName,[ref]$tokens,[ref]$errors)|Out-Null
    Assert-Exact ($errors.Count-eq 0) "Transfer script parser error: $($script.Name)"
    $source=[IO.File]::ReadAllText($script.FullName)
    $base64Match=[regex]::Match($source,'FromBase64String\(''([^'']+)''\)')
    $hashMatch=[regex]::Match($source,'\$hash-ne''([A-F0-9]{64})''')
    $partMatch=[regex]::Match($source,'Join-Path \$root ''(p[0-9]{3}\.bin)''')
    Assert-Exact ($base64Match.Success-and$hashMatch.Success-and$partMatch.Success) "Transfer script literals incomplete: $($script.Name)"
    $bytes=[Convert]::FromBase64String($base64Match.Groups[1].Value)
    $partSha=Get-ExactShaBytes $bytes
    Assert-Exact ($partSha-eq$hashMatch.Groups[1].Value) "Transfer part hash mismatch: $($script.Name)"
    $memory.Write($bytes,0,$bytes.Length)
    $rows.Add([pscustomobject]@{index=$index;part=$partMatch.Groups[1].Value;partBytes=$bytes.Length;partSha256=$partSha;script=$script.Name;scriptBytes=$script.Length;scriptSha256=(Get-FileHash -LiteralPath $script.FullName -Algorithm SHA256).Hash})
  }
  $reconstructed=$memory.ToArray()
}
finally{$memory.Dispose()}
Assert-Exact ($reconstructed.Length-eq(Get-Item -LiteralPath $zip).Length) 'Reconstructed payload byte count changed.'
Assert-Exact ((Get-ExactShaBytes $reconstructed)-eq$expectedZipSha) 'Reconstructed payload hash changed.'
$result=[ordered]@{schema='argos_r3s16_short_transfer_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R3S16_SHORT_TRANSFER_GATE';payloadZipPath='R3S16_PAYLOAD.zip';payloadZipBytes=$reconstructed.Length;payloadZipSha256=$expectedZipSha;partCount=$rows.Count;maximumScriptBytes=[int](($scripts|Measure-Object Length -Maximum).Maximum);provenCommandSourceLimit=2048;allWindowsPowerShellParserPassed=$true;allPartHashesPassed=$true;exactReconstructionPassed=$true;parts=$rows.ToArray();targetExecuted=$false;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}
if($Preflight){$result|ConvertTo-Json -Depth 8;return}
Assert-Exact (-not(Test-Path -LiteralPath $gatePath)) 'Transfer gate create-new target exists.'
[IO.File]::WriteAllText($gatePath,(($result|ConvertTo-Json -Depth 8)+[Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))
$result|ConvertTo-Json -Depth 8

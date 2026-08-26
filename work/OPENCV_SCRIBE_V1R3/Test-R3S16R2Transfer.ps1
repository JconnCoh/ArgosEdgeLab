#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight,[switch]$Gate)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if(([bool]$Preflight)-eq([bool]$Gate)){throw'Specify exactly one of -Preflight or -Gate.'}
$manifestPath=Join-Path $PSScriptRoot 'R3S16R2_TRANSFER_MANIFEST.json'
$scriptRoot=Join-Path $PSScriptRoot 'transfer_r2'
$gatePath=Join-Path $PSScriptRoot 'R3S16R2_TRANSFER_GATE.json'
function Assert-Exact([bool]$Condition,[string]$Message){if(-not$Condition){throw$Message}}
function Get-BytesSha([byte[]]$Bytes){$hasher=[Security.Cryptography.SHA256]::Create();try{return([BitConverter]::ToString($hasher.ComputeHash($Bytes))).Replace('-','')}finally{$hasher.Dispose()}}
function Assert-Script([object]$Row){$path=Join-Path $scriptRoot ([string]$Row.script);Assert-Exact (Test-Path -LiteralPath $path -PathType Leaf) "Script absent: $($Row.script)";Assert-Exact ((Get-Item -LiteralPath $path).Length-eq[int64]$Row.scriptBytes) "Script bytes changed: $($Row.script)";Assert-Exact ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash-eq[string]$Row.scriptSha256) "Script hash changed: $($Row.script)";$tokens=$null;$errors=$null;[Management.Automation.Language.Parser]::ParseFile($path,[ref]$tokens,[ref]$errors)|Out-Null;Assert-Exact ($errors.Count-eq 0) "Parser failure: $($Row.script)";Assert-Exact ([int64]$Row.scriptBytes-le 2048) "Script exceeds command limit: $($Row.script)";return $path}
$manifest=Get-Content -Raw -LiteralPath $manifestPath|ConvertFrom-Json
Assert-Exact ([string]$manifest.schema-eq'argos_r3s16r2_short_transfer_manifest_v1') 'Manifest schema changed.'
Assert-Exact ([string]$manifest.sourcePayloadZipSha256-eq'33B183483B25FDF9F48C102E61C5457F802B72BCE9418C34A782AF18E5456279') 'Payload pin changed.'
$helperMemory=New-Object IO.MemoryStream
try{foreach($row in @($manifest.partWriter.writerParts)){[void](Assert-Script $row);$source=[IO.File]::ReadAllText((Join-Path $scriptRoot ([string]$row.script)));$match=[regex]::Match($source,"FromBase64String\('([^']+)'\)");Assert-Exact $match.Success "Writer part literal absent: $($row.script)";$bytes=[Convert]::FromBase64String($match.Groups[1].Value);Assert-Exact ($bytes.Length-eq[int]$row.partBytes-and(Get-BytesSha $bytes)-eq[string]$row.partSha256) "Writer part content changed: $($row.script)";$helperMemory.Write($bytes,0,$bytes.Length)};$helper=$helperMemory.ToArray()}finally{$helperMemory.Dispose()}
Assert-Exact ($helper.Length-eq[int]$manifest.partWriter.bytes-and(Get-BytesSha $helper)-eq[string]$manifest.partWriter.sha256) 'Part writer reconstruction changed.'
[void](Assert-Script $manifest.partWriter.assembler)
$payloadMemory=New-Object IO.MemoryStream
try{foreach($row in @($manifest.payloadParts)){[void](Assert-Script $row);$source=[IO.File]::ReadAllText((Join-Path $scriptRoot ([string]$row.script)));$match=[regex]::Match($source,"StagePart\.ps1' '(p[0-9]{3}\.bin)' '([^']+)' '([A-F0-9]{64})'");Assert-Exact $match.Success "Payload part literal absent: $($row.script)";$bytes=[Convert]::FromBase64String($match.Groups[2].Value);Assert-Exact ($match.Groups[1].Value-eq[string]$row.part-and$match.Groups[3].Value-eq[string]$row.partSha256) "Payload part identity changed: $($row.script)";Assert-Exact ($bytes.Length-eq[int]$row.partBytes-and(Get-BytesSha $bytes)-eq[string]$row.partSha256) "Payload part content changed: $($row.script)";$payloadMemory.Write($bytes,0,$bytes.Length)};$payload=$payloadMemory.ToArray()}finally{$payloadMemory.Dispose()}
Assert-Exact ($payload.Length-eq[int]$manifest.sourcePayloadZipBytes-and(Get-BytesSha $payload)-eq[string]$manifest.sourcePayloadZipSha256) 'Payload reconstruction changed.'
$result=[ordered]@{schema='argos_r3s16r2_short_transfer_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R3S16R2_SHORT_TRANSFER_GATE';manifestSha256=(Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash;partWriterSha256=[string]$manifest.partWriter.sha256;payloadZipBytes=$payload.Length;payloadZipSha256=[string]$manifest.sourcePayloadZipSha256;writerPartCount=@($manifest.partWriter.writerParts).Count;payloadPartCount=@($manifest.payloadParts).Count;maximumCommandScriptBytes=[int]$manifest.maximumCommandScriptBytes;commandSourceLimit=[int]$manifest.commandSourceLimit;allWindowsPowerShellParserPassed=$true;exactHelperReconstructionPassed=$true;exactPayloadReconstructionPassed=$true;targetExecuted=$false;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}
if($Preflight){$result|ConvertTo-Json -Depth 6;return}
Assert-Exact (-not(Test-Path -LiteralPath $gatePath)) 'Gate create-new target exists.'
[IO.File]::WriteAllText($gatePath,(($result|ConvertTo-Json -Depth 6)+[Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))
$result|ConvertTo-Json -Depth 6

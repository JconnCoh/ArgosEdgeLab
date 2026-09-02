$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$utf8 = New-Object Text.UTF8Encoding($false)
$inputs = @(
    [ordered]@{name='runner';path=(Join-Path $root 'Diagnose-R33RotationHolderAblation.py');hash='924650DAE81E51F92A25E12ACD1252279FE2BD9A7EE82D2E1744C729F655233C'},
    [ordered]@{name='cases';path=(Join-Path $root 'R28ROT1_CASES.json');hash='90D4DC156D85F2F684E616248E23729E3E0F0111D64E456891DDDB519F2AD6AB'}
)
function Compress-Base64([string]$path) {
    $bytes = [IO.File]::ReadAllBytes($path)
    $memory = New-Object IO.MemoryStream
    $gzip = New-Object IO.Compression.GzipStream($memory,[IO.Compression.CompressionMode]::Compress,$true)
    $gzip.Write($bytes,0,$bytes.Length);$gzip.Dispose()
    $value = [Convert]::ToBase64String($memory.ToArray());$memory.Dispose();$value
}
function String-Sha([string]$value) {
    $digest=[Security.Cryptography.SHA256]::Create()
    try { ([BitConverter]::ToString($digest.ComputeHash($utf8.GetBytes($value)))).Replace('-','') }
    finally { $digest.Dispose() }
}
foreach($input in $inputs){if((Get-FileHash $input.path).Hash-ne$input.hash){throw "$($input.name) changed"}}
$runner64=Compress-Base64 $inputs[0].path;$runner64Hash=String-Sha $runner64
$cases64=Compress-Base64 $inputs[1].path;$cases64Hash=String-Sha $cases64
$commands=[ordered]@{}
$commands['R33ROT1_DIRECT_INIT.ps1']=@'
$ErrorActionPreference='Stop';$s='D:\R33T2RT';$r='D:\R33ROT1RT';$o='D:\R33ROT1';$p=@(@("$s\Detect-BacksideNotchOpenCvR33.py",'1D1F6FC63B719063AB95B53AF580C0A9C8CA40801D0F573F7BE09EF9603BA6D3'),@("$s\BACKSIDE_NOTCH_CONFIG_R13.json",'27010B75F2E5CCB601E710A63D73F5483072F6EB797F9D72A0632F993E6E4AD3'),@('D:\AFCV1\rt\python.exe','7D96A4ED35D6E596CD9DD8933FEAFC66349CC21F75BE3B15C89FD336E50140C1'));if((Test-Path $r)-or(Test-Path $o)){throw 'R33ROT1 namespace exists'};foreach($x in $p){if(-not(Test-Path $x[0])-or(Get-FileHash $x[0]).Hash-ne$x[1]){throw "pin failed: $($x[0])"}};Copy-Item $s $r -Recurse;[ordered]@{state='PASS_R33ROT1_INIT';runtime=$r;outputAbsent=$true}|ConvertTo-Json -Compress
'@
$chunkSize=[Math]::Ceiling($runner64.Length/4)
for($index=0;$index-lt4;$index++){
    $offset=$index*$chunkSize;$length=[Math]::Min($chunkSize,$runner64.Length-$offset)
    $chunk=$runner64.Substring($offset,$length);$method=if($index-eq0){'WriteAllText'}else{'AppendAllText'};$number=$index+1
    $commands[("R33ROT1_DIRECT_CHUNK{0}.ps1"-f$number)]="`$ErrorActionPreference='Stop';`$p='D:\R33ROT1RT\runner.b64';[IO.File]::$method(`$p,'$chunk',(New-Object Text.UTF8Encoding(`$false)));[ordered]@{state='PASS_R33ROT1_CHUNK$number';bytes=(Get-Item `$p).Length}|ConvertTo-Json -Compress"
}
$commands['R33ROT1_DIRECT_FREEZE.ps1']=@"
`$ErrorActionPreference='Stop';`$r='D:\R33ROT1RT';`$p="`$r\runner.b64";if((Get-FileHash `$p).Hash-ne'$runner64Hash'){throw 'R33ROT1 transfer changed'};`$b=[Convert]::FromBase64String([IO.File]::ReadAllText(`$p));`$m=New-Object IO.MemoryStream(,`$b);`$g=New-Object IO.Compression.GzipStream(`$m,[IO.Compression.CompressionMode]::Decompress);`$f=[IO.File]::Create("`$r\Diagnose-R33RotationHolderAblation.py");`$g.CopyTo(`$f);`$f.Dispose();`$g.Dispose();`$m.Dispose();`$h=(Get-FileHash "`$r\Diagnose-R33RotationHolderAblation.py").Hash;if(`$h-ne'924650DAE81E51F92A25E12ACD1252279FE2BD9A7EE82D2E1744C729F655233C'){throw 'R33ROT1 runner mismatch'};[ordered]@{state='PASS_R33ROT1_RUNNER_FROZEN';sha256=`$h}|ConvertTo-Json -Compress
"@
$commands['R33ROT1_DIRECT_CASES.ps1']=(@'
$ErrorActionPreference='Stop';$r='D:\R33ROT1RT';$z='__CASES64__';$b=[Convert]::FromBase64String($z);$m=New-Object IO.MemoryStream(,$b);$g=New-Object IO.Compression.GzipStream($m,[IO.Compression.CompressionMode]::Decompress);$f=[IO.File]::Create("$r\R28ROT1_CASES.json");$g.CopyTo($f);$f.Dispose();$g.Dispose();$m.Dispose();$h=(Get-FileHash "$r\R28ROT1_CASES.json").Hash;if($h-ne'90D4DC156D85F2F684E616248E23729E3E0F0111D64E456891DDDB519F2AD6AB'){throw 'R33ROT1 cases mismatch'};[ordered]@{state='PASS_R33ROT1_CASES_FROZEN';sha256=$h}|ConvertTo-Json -Compress
'@).Replace('__CASES64__',$cases64)
$commands['R33ROT1_DIRECT_START.ps1']=@'
$ErrorActionPreference='Stop';$r='D:\R33ROT1RT';$o='D:\R33ROT1';$py='D:\AFCV1\rt\python.exe';$u="$r\Diagnose-R33RotationHolderAblation.py";$d="$r\Detect-BacksideNotchOpenCvR33.py";$c="$r\BACKSIDE_NOTCH_CONFIG_R13.json";$m="$r\R28ROT1_CASES.json";if((Test-Path $o)-or(Get-FileHash $u).Hash-ne'924650DAE81E51F92A25E12ACD1252279FE2BD9A7EE82D2E1744C729F655233C'-or(Get-FileHash $m).Hash-ne'90D4DC156D85F2F684E616248E23729E3E0F0111D64E456891DDDB519F2AD6AB'){throw 'R33ROT1 start premise changed'};$v=@('-B',$u,'--cases',$m,'--detector',$d,'--config',$c,'--output',$o);$p=Start-Process $py -ArgumentList $v -WorkingDirectory $r -WindowStyle Hidden -RedirectStandardOutput "$r\stdout.txt" -RedirectStandardError "$r\stderr.txt" -PassThru;Start-Sleep -Milliseconds 500;$p.Refresh();if($p.HasExited){throw "R33ROT1 exited early: $($p.ExitCode)"};[ordered]@{state='PASS_R33ROT1_STARTED';pid=$p.Id;creationUtc=$p.StartTime.ToUniversalTime().ToString('o');executionCount=8}|ConvertTo-Json -Compress
'@
foreach($entry in $commands.GetEnumerator()){
    $path=Join-Path $root $entry.Key;[IO.File]::WriteAllText($path,[string]$entry.Value,$utf8)
    $length=([IO.File]::ReadAllText($path)).Length;if($length-gt2048){throw "$($entry.Key) exceeds 2048: $length"}
    [pscustomobject]@{Path=$path;Characters=$length;Sha256=(Get-FileHash $path).Hash}
}

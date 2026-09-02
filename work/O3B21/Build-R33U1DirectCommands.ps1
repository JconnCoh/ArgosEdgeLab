$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$runner = Join-Path $root 'Run-R33Union.py'
$runnerHash = '2A003BE9F85F6AFDB6073013659C79FC2F91975384DAE07DD924E83F4235AA7E'
if ((Get-FileHash -LiteralPath $runner -Algorithm SHA256).Hash -ne $runnerHash) {
    throw 'R33 union runner changed.'
}
$bytes = [IO.File]::ReadAllBytes($runner)
$memory = New-Object IO.MemoryStream
$gzip = New-Object IO.Compression.GzipStream($memory, [IO.Compression.CompressionMode]::Compress, $true)
$gzip.Write($bytes, 0, $bytes.Length)
$gzip.Dispose()
$base64 = [Convert]::ToBase64String($memory.ToArray())
$memory.Dispose()
$utf8 = New-Object Text.UTF8Encoding($false)
$digest = [Security.Cryptography.SHA256]::Create()
try { $base64Hash = ([BitConverter]::ToString($digest.ComputeHash($utf8.GetBytes($base64)))).Replace('-', '') }
finally { $digest.Dispose() }

$commands = [ordered]@{}
$commands['R33U1_DIRECT_INIT.ps1'] = @'
$ErrorActionPreference='Stop';$s='D:\R33T2RT';$r='D:\R33U1RT';$o='D:\R33U1';$p=@(@("$s\Detect-BacksideNotchOpenCvR33.py",'1D1F6FC63B719063AB95B53AF580C0A9C8CA40801D0F573F7BE09EF9603BA6D3'),@("$s\BACKSIDE_NOTCH_CONFIG_R13.json",'27010B75F2E5CCB601E710A63D73F5483072F6EB797F9D72A0632F993E6E4AD3'),@('D:\AFCV1\rt\python.exe','7D96A4ED35D6E596CD9DD8933FEAFC66349CC21F75BE3B15C89FD336E50140C1'),@('D:\R31VAL2\FROZEN_CASES.json','CF13707EC49ED3DED99CA077D6F92ECB0D6FED234E9BB51E3E72AFD7581A96AE'),@('D:\R31VAL2\SUMMARY.json','0C8877CB774F00B459E6C3CD07CEE843F8815F0A8DF46833357EFB5331FC48A3'),@('D:\R32M1\SUMMARY.json','89B1C232C5D8E89FA1831A83E3A1206928ABB5D0B8E60074CDDA450EBACF7FD9'));if((Test-Path $r)-or(Test-Path $o)){throw 'R33U1 namespace exists'};foreach($x in $p){if(-not(Test-Path $x[0])-or(Get-FileHash $x[0]).Hash-ne$x[1]){throw "pin failed: $($x[0])"}};Copy-Item $s $r -Recurse;[ordered]@{state='PASS_R33U1_INIT';runtime=$r;outputAbsent=$true}|ConvertTo-Json -Compress
'@

$chunkSize = [Math]::Ceiling($base64.Length / 3)
for ($index = 0; $index -lt 3; $index++) {
    $offset = $index * $chunkSize
    $length = [Math]::Min($chunkSize, $base64.Length - $offset)
    $chunk = $base64.Substring($offset, $length)
    $method = if ($index -eq 0) { 'WriteAllText' } else { 'AppendAllText' }
    $number = $index + 1
    $commands[("R33U1_DIRECT_CHUNK{0}.ps1" -f $number)] =
        "`$ErrorActionPreference='Stop';`$p='D:\R33U1RT\runner.b64';[IO.File]::$method(`$p,'$chunk',(New-Object Text.UTF8Encoding(`$false)));[ordered]@{state='PASS_R33U1_CHUNK$number';bytes=(Get-Item `$p).Length}|ConvertTo-Json -Compress"
}

$commands['R33U1_DIRECT_FREEZE.ps1'] = @"
`$ErrorActionPreference='Stop';`$r='D:\R33U1RT';`$p="`$r\runner.b64";if((Get-FileHash `$p).Hash-ne'$base64Hash'){throw 'R33U1 transfer changed'};`$b=[Convert]::FromBase64String([IO.File]::ReadAllText(`$p));`$m=New-Object IO.MemoryStream(,`$b);`$g=New-Object IO.Compression.GzipStream(`$m,[IO.Compression.CompressionMode]::Decompress);`$f=[IO.File]::Create("`$r\Run-R33Union.py");`$g.CopyTo(`$f);`$f.Dispose();`$g.Dispose();`$m.Dispose();`$h=(Get-FileHash "`$r\Run-R33Union.py").Hash;if(`$h-ne'$runnerHash'){throw 'R33U1 runner hash changed'};[ordered]@{state='PASS_R33U1_RUNNER_FROZEN';sha256=`$h}|ConvertTo-Json -Compress
"@

$commands['R33U1_DIRECT_EXTRAS.ps1'] = @'
$ErrorActionPreference='Stop';$r='D:\R33U1RT';$a=@();$c=@(@(17,89.73126526163422),@(21,89.99985223452285),@(24,89.6831921685261));foreach($x in $c){$j=Get-Content "D:\R32M1\J23_S$($x[0]).json" -Raw|ConvertFrom-Json;$a+=[ordered]@{id="BackSide_BowComp\Lot_62625-956\62625-956_20260729122701\Slot$($x[0])|BACK";group='R33_SENTINEL';bf=[string]$j.bf;df=[string]$j.df;bfSha256=[string]$j.bfSha256;dfSha256=[string]$j.dfSha256;expectedPairedCandidateCount=1;expectedMeanAngleDegrees=$x[1];maximumAngleDeltaDegrees=.000001;expectedConfirmationMode='DF_STRONG_MORPHOLOGY_ANCHORED_BF_LOCAL_PROMINENCE_APPEARANCE';expectedShallowModeRatioGateApplies=$false}};$p="$r\EXTRA_CASES.json";if(Test-Path $p){throw 'extras exist'};[IO.File]::WriteAllText($p,($a|ConvertTo-Json -Depth 5),(New-Object Text.UTF8Encoding($false)));[ordered]@{state='PASS_R33U1_EXTRAS_FROZEN';count=$a.Count;sha256=(Get-FileHash $p).Hash}|ConvertTo-Json -Compress
'@

$commands['R33U1_DIRECT_START.ps1'] = @'
$ErrorActionPreference='Stop';$r='D:\R33U1RT';$o='D:\R33U1';$py='D:\AFCV1\rt\python.exe';$d="$r\Detect-BacksideNotchOpenCvR33.py";$u="$r\Run-R33Union.py";$c="$r\BACKSIDE_NOTCH_CONFIG_R13.json";$e="$r\EXTRA_CASES.json";$b='D:\R31VAL2\FROZEN_CASES.json';if(Test-Path $o){throw 'R33U1 output exists'};$eh=(Get-FileHash $e).Hash;$v=@('-B',$u,'--cases',$b,'--cases-sha256','CF13707EC49ED3DED99CA077D6F92ECB0D6FED234E9BB51E3E72AFD7581A96AE','--extra-cases',$e,'--extra-cases-sha256',$eh,'--detector',$d,'--detector-sha256','1D1F6FC63B719063AB95B53AF580C0A9C8CA40801D0F573F7BE09EF9603BA6D3','--config',$c,'--config-sha256','27010B75F2E5CCB601E710A63D73F5483072F6EB797F9D72A0632F993E6E4AD3','--python',$py,'--python-sha256','7D96A4ED35D6E596CD9DD8933FEAFC66349CC21F75BE3B15C89FD336E50140C1','--output',$o,'--workers','4','--maximum-dimension','2400','--maximum-per-case-seconds','180');$p=Start-Process $py -ArgumentList $v -WorkingDirectory $r -WindowStyle Hidden -RedirectStandardOutput "$r\stdout.txt" -RedirectStandardError "$r\stderr.txt" -PassThru;Start-Sleep -Milliseconds 500;$p.Refresh();if($p.HasExited){throw "R33U1 exited early: $($p.ExitCode)"};[ordered]@{state='PASS_R33U1_STARTED';pid=$p.Id;creationUtc=$p.StartTime.ToUniversalTime().ToString('o');extraCasesSha256=$eh;workers=4}|ConvertTo-Json -Compress
'@

foreach ($entry in $commands.GetEnumerator()) {
    $path = Join-Path $root $entry.Key
    [IO.File]::WriteAllText($path, [string]$entry.Value, $utf8)
    $length = ([IO.File]::ReadAllText($path)).Length
    if ($length -gt 2048) { throw "$($entry.Key) exceeds 2048 characters: $length" }
    [pscustomobject]@{
        Path = $path
        Characters = $length
        Sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    }
}

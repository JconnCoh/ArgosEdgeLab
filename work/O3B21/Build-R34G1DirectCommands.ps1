$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$zip = Join-Path $root 'R34G1_PAYLOAD.zip'
$zipHash = '62253EBE723D8E96BFBEF1F7AA0FE7FBEEFD060ED986ABB11154356075830B61'
if ((Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash -ne $zipHash) {
    throw 'R34G1 payload ZIP changed.'
}
$base64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($zip))
$utf8 = New-Object Text.UTF8Encoding($false)
$digest = [Security.Cryptography.SHA256]::Create()
try {
    $base64Hash = ([BitConverter]::ToString(
        $digest.ComputeHash($utf8.GetBytes($base64))
    )).Replace('-', '')
} finally {
    $digest.Dispose()
}

$commands = [ordered]@{}
$commands['R34G1_DIRECT_INIT.ps1'] = @'
$ErrorActionPreference='Stop';$s='D:\R33U2RT';$r='D:\R34G1RT';$o='D:\R34G1';$p=@(@("$s\Detect-BacksideNotchOpenCvR33.py",'1D1F6FC63B719063AB95B53AF580C0A9C8CA40801D0F573F7BE09EF9603BA6D3'),@("$s\BACKSIDE_NOTCH_CONFIG_R13.json",'27010B75F2E5CCB601E710A63D73F5483072F6EB797F9D72A0632F993E6E4AD3'),@("$s\EXTRA_CASES.json",'F10A71C89A873EC2A671ED00803E84152711D22E7A3800F516ECB6BA5AF98681'),@('D:\AFCV1\rt\python.exe','7D96A4ED35D6E596CD9DD8933FEAFC66349CC21F75BE3B15C89FD336E50140C1'),@('D:\R31VAL2\FROZEN_CASES.json','CF13707EC49ED3DED99CA077D6F92ECB0D6FED234E9BB51E3E72AFD7581A96AE'),@('D:\R33U2\FROZEN_CASES.json','48AA1CABC1B2DCD41B8A2A63361AECE0CF5A22A74BEE252E88D229BBE6E57E4F'),@('D:\R33U2\SUMMARY.json','B258ADFCB2E5503338AD984B6E223A9DD80EBAA63751253294B8945390180272'),@('D:\R33ROT1RT\R28ROT1_CASES.json','90D4DC156D85F2F684E616248E23729E3E0F0111D64E456891DDDB519F2AD6AB'));if((Test-Path $r)-or(Test-Path $o)){throw 'R34G1 namespace exists'};foreach($x in $p){if(-not(Test-Path $x[0])-or(Get-FileHash $x[0]).Hash-ne$x[1]){throw "pin failed: $($x[0])"}};if(@(Get-ChildItem 'D:\R33U2\jobs' -File -Filter 'J*.json').Count-ne301){throw 'source job count changed'};Copy-Item $s $r -Recurse;Copy-Item 'D:\R33ROT1RT\R28ROT1_CASES.json' $r;[ordered]@{state='PASS_R34G1_INIT';runtime=$r;outputAbsent=$true;sourceJobCount=301}|ConvertTo-Json -Compress
'@

$chunkSize = 1750
$chunkCount = [Math]::Ceiling($base64.Length / $chunkSize)
for ($index = 0; $index -lt $chunkCount; $index++) {
    $offset = $index * $chunkSize
    $length = [Math]::Min($chunkSize, $base64.Length - $offset)
    $chunk = $base64.Substring($offset, $length)
    $method = if ($index -eq 0) { 'WriteAllText' } else { 'AppendAllText' }
    $number = $index + 1
    $commands[("R34G1_DIRECT_CHUNK{0:D2}.ps1" -f $number)] =
        "`$ErrorActionPreference='Stop';`$p='D:\R34G1RT\payload.b64';[IO.File]::$method(`$p,'$chunk',(New-Object Text.UTF8Encoding(`$false)));[ordered]@{state='PASS_R34G1_CHUNK_$number';bytes=(Get-Item `$p).Length}|ConvertTo-Json -Compress"
}

$commands['R34G1_DIRECT_DECODE.ps1'] = @"
`$ErrorActionPreference='Stop';`$r='D:\R34G1RT';`$p="`$r\payload.b64";if((Get-FileHash `$p).Hash-ne'$base64Hash'){throw 'R34G1 transfer changed'};`$z="`$r\R34G1_PAYLOAD.zip";[IO.File]::WriteAllBytes(`$z,[Convert]::FromBase64String([IO.File]::ReadAllText(`$p)));if((Get-FileHash `$z).Hash-ne'$zipHash'){throw 'R34G1 ZIP changed'};`$x="`$r\g1_stage";if(Test-Path `$x){throw 'R34G1 stage exists'};Expand-Archive -LiteralPath `$z -DestinationPath `$x;[ordered]@{state='PASS_R34G1_DECODED';zipSha256=(Get-FileHash `$z).Hash;stage=`$x}|ConvertTo-Json -Compress
"@

$commands['R34G1_DIRECT_FREEZE.ps1'] = @'
$ErrorActionPreference='Stop';$r='D:\R34G1RT';$x="$r\g1_stage";$lp="$x\R34G1_PAYLOAD_LOCK.json";if((Get-FileHash $lp).Hash-ne'1C0F1D026F143215BDFD0E4A06ADEC26459FE58B10CA066818051FC42220CB4E'){throw 'payload lock changed'};$l=Get-Content $lp -Raw|ConvertFrom-Json;if($l.schema-ne'argos_o3b21_r34g1_draft_test_payload_lock_v1'-or@($l.files).Count-ne13){throw 'payload lock schema changed'};Add-Type -AssemblyName System.IO.Compression.FileSystem;$a=[IO.Compression.ZipFile]::OpenRead("$r\R34G1_PAYLOAD.zip");try{$n=@($a.Entries|ForEach-Object{$_.FullName})}finally{$a.Dispose()};$e=@($l.files|ForEach-Object{$_.name})+@('R34G1_PAYLOAD_LOCK.json');if($n.Count-ne14-or@(Compare-Object ($n|Sort-Object) ($e|Sort-Object)).Count){throw 'ZIP entry set changed'};foreach($f in $l.files){$p="$x\$($f.name)";if(-not(Test-Path $p)-or(Get-FileHash $p).Hash-ne$f.sha256){throw "payload file changed: $($f.name)"}};Copy-Item "$x\*" $r -Force;foreach($f in $l.files){if((Get-FileHash "$r\$($f.name)").Hash-ne$f.sha256){throw "runtime file changed: $($f.name)"}};[ordered]@{state='PASS_R34G1_PAYLOAD_FROZEN';fileCount=13;detectorSha256=(Get-FileHash "$r\Detect-BacksideNotchOpenCvR34.py").Hash;planSha256=(Get-FileHash "$r\R34G1_PLAN.json").Hash}|ConvertTo-Json -Compress
'@

$commands['R34G1_DIRECT_START.ps1'] = @'
$ErrorActionPreference='Stop';$r='D:\R34G1RT';$o='D:\R34G1';$py='D:\AFCV1\rt\python.exe';$u="$r\Run-R34CompositeGate.py";$p="$r\R34G1_PLAN.json";if((Test-Path $o)-or(Get-FileHash $py).Hash-ne'7D96A4ED35D6E596CD9DD8933FEAFC66349CC21F75BE3B15C89FD336E50140C1'-or(Get-FileHash $u).Hash-ne'2A919A4725A94DF5590668EE173BDCB4621E779B4D6629F19AA70A0282BE9E5C'-or(Get-FileHash $p).Hash-ne'10B22D836F21C8CF614D360F2EA515BFC7E2804AE02F5DFB8C6AD2173C090204'){throw 'R34G1 start premise changed'};$v=@('-B',$u,'--plan',$p);$q=Start-Process $py -ArgumentList $v -WorkingDirectory $r -WindowStyle Hidden -RedirectStandardOutput "$r\R34G1.stdout.txt" -RedirectStandardError "$r\R34G1.stderr.txt" -PassThru;Start-Sleep -Milliseconds 500;$q.Refresh();if($q.HasExited){throw "R34G1 exited early: $($q.ExitCode)"};[ordered]@{state='PASS_R34G1_STARTED';pid=$q.Id;creationUtc=$q.StartTime.ToUniversalTime().ToString('o');phases=@(141,9,301,8)}|ConvertTo-Json -Compress
'@

foreach ($entry in $commands.GetEnumerator()) {
    $path = Join-Path $root $entry.Key
    [IO.File]::WriteAllText($path, [string]$entry.Value, $utf8)
    $tokens = $null
    $errors = $null
    [Management.Automation.Language.Parser]::ParseFile(
        $path, [ref]$tokens, [ref]$errors
    ) | Out-Null
    $length = ([IO.File]::ReadAllText($path)).Length
    if ($length -gt 2048 -or @($errors).Count -ne 0) {
        throw "$($entry.Key) failed direct-command construction: length=$length parse=$(@($errors).Count)"
    }
    [pscustomobject]@{
        Path = $path
        Characters = $length
        Sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    }
}

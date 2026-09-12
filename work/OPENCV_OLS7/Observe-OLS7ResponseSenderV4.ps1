$ErrorActionPreference='Stop'
$schema='argos_ols7_response_sender_observation_v4'
try{
if($env:COMPUTERNAME-ne'A1025645101'){throw "HOST_MISMATCH:$($env:COMPUTERNAME)"}
$root='C:\ProgramData\ArgosProjectPortalRO'
$state=Join-Path $root 'state\transport_JBOD_RESPONSE_SENDER'
$status=Join-Path $state 'STATUS.json'
$log=Join-Path $state 'relay.log'
$name='R_4165D2AA78E1_20260911165403415_1688d84f.ready'
$p=Join-Path (Join-Path $root 'to_argos\pending') $name
$s=Join-Path (Join-Path $root 'to_argos\sent') $name
$statusValue=$null
if(Test-Path -LiteralPath $status -PathType Leaf){$i=Get-Item -LiteralPath $status;if($i.Length-gt 1048576){throw 'Oversize sender status'};$statusValue=Get-Content -LiteralPath $status -Raw|ConvertFrom-Json}
$tail=@();if(Test-Path -LiteralPath $log -PathType Leaf){$tail=@(Get-Content -LiteralPath $log -Tail 20)}
$tcp=@(Get-NetTCPConnection -RemotePort 48717 -ErrorAction SilentlyContinue|Select-Object -First 8 LocalAddress,LocalPort,RemoteAddress,RemotePort,State,OwningProcess)
$r=[ordered]@{schema=$schema;state='PASS_OLS7_RESPONSE_SENDER_OBSERVATION';computerName=$env:COMPUTERNAME;status=$statusValue;logTail=$tail;tcp48717=$tcp;target=[ordered]@{pending=Test-Path -LiteralPath $p;sent=Test-Path -LiteralPath $s};mutationsPerformed=$false}
}catch{$m=[string]$_.Exception.Message;if($m.Length-gt500){$m=$m.Substring(0,500)};$r=[ordered]@{schema=$schema;state='FAIL_OLS7_RESPONSE_SENDER_OBSERVATION';error=$m;mutationsPerformed=$false}}
$r|ConvertTo-Json -Compress -Depth 10|clip.exe

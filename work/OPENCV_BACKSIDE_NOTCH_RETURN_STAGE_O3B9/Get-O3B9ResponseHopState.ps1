$n='R_18F2B7C72A1D_20260828231116568_06be2a92.ready'
$b='C:\ProgramData\ArgosProjectPortalRO'
function M($p){$x=Get-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue;[ordered]@{path=$p;exists=[bool]$x;type=if(!$x){'absent'}elseif($x.PSIsContainer){'dir'}else{'file'};length=if($x-and!$x.PSIsContainer){$x.Length}else{$null};lastWriteUtc=if($x){$x.LastWriteTimeUtc.ToString('o')}else{$null}}}
$paths=@("$b\to_argos\pending\$n","$b\to_argos\sent\$n","$b\to_argos\archive\$n","$b\endpoint_jbod\responses\pending\$n","$b\endpoint_jbod\responses\sent\$n")
$p="$b\to_argos\pending\$n";$children=@();if(Test-Path -LiteralPath $p){$children=@(Get-ChildItem -LiteralPath $p -Force|Select-Object -First 12|ForEach-Object{[ordered]@{name=$_.Name;type=if($_.PSIsContainer){'dir'}else{'file'};length=if($_.PSIsContainer){$null}else{$_.Length};lastWriteUtc=$_.LastWriteTimeUtc.ToString('o')}})}
[ordered]@{schema='argos_o3b9_response_hop_state_v1';state='PASS_EXACT_RESPONSE_HOP_AUDIT';computer=$env:COMPUTERNAME;responseName=$n;exact=@($paths|ForEach-Object{M $_});pendingChildren=$children;processQueriesPerformed=$false;mutationsPerformed=$false}|ConvertTo-Json -Depth 5 -Compress

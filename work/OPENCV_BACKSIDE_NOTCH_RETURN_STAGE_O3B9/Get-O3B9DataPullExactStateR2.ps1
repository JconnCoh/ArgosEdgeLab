$r='REQ_20260828T231141586Z_443AAB1C0271'
$b='C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod'
function M($p){$x=Get-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue;[ordered]@{path=$p;exists=[bool]$x;type=if(!$x){'absent'}elseif($x.PSIsContainer){'dir'}else{'file'};length=if($x-and!$x.PSIsContainer){$x.Length}else{$null};lastWriteUtc=if($x){$x.LastWriteTimeUtc.ToString('o')}else{$null}}}
$lp="$b\state\ledger\$r.json"
$paths=@($lp,"$b\pending\$r.ready","$b\processed\completed\$r.ready","$b\processed\failed\$r.ready",'D:\KLARFExport\B8R1\BF.bmp','D:\KLARFExport\B8R1\DF.bmp')
$raw=if((Test-Path -LiteralPath $lp)-and((Get-Item -LiteralPath $lp).Length-le 12000)){Get-Content -LiteralPath $lp -Raw}else{$null}
[ordered]@{schema='argos_o3b9_pull_exact_state_r2_v1';state='PASS_EXACT_FILE_AUDIT';computer=$env:COMPUTERNAME;requestId=$r;exact=@($paths|ForEach-Object{M $_});ledgerRaw=$raw;processQueriesPerformed=$false;directoryEnumerationPerformed=$false;mutationsPerformed=$false}|ConvertTo-Json -Depth 5 -Compress

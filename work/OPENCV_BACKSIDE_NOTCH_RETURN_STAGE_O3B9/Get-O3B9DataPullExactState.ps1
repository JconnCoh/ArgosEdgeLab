$r='REQ_20260828T231141586Z_443AAB1C0271'
$b='C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod'
function M($p){$x=Get-Item -LiteralPath $p -ErrorAction SilentlyContinue;if($x){[ordered]@{path=$p;type=if($x.PSIsContainer){'dir'}else{'file'};length=if($x.PSIsContainer){$null}else{$x.Length};lastWriteUtc=$x.LastWriteTimeUtc.ToString('o')}}else{[ordered]@{path=$p;type='absent';length=$null;lastWriteUtc=$null}}}
$lp="$b\state\ledger\$r.json"
$ledger=if(Test-Path -LiteralPath $lp){Get-Content -LiteralPath $lp -Raw}else{$null}
$p=@($lp,"$b\pending\$r.ready","$b\processed\completed\$r.ready","$b\processed\failed\$r.ready",'D:\KLARFExport\B8R1\BF.bmp','D:\KLARFExport\B8R1\DF.bmp')
$roots=@("$b\state\work","$b\state\response_quarantine","$b\responses\pending",'C:\ProgramData\ArgosProjectPortalRO\to_argos\pending')
$recent=@()
foreach($q in $roots){$items=@(Get-ChildItem -LiteralPath $q -Force -ErrorAction SilentlyContinue|Sort-Object LastWriteTimeUtc -Descending|Select-Object -First 8);$recent+=[ordered]@{root=$q;items=@($items|ForEach-Object{[ordered]@{name=$_.Name;type=if($_.PSIsContainer){'dir'}else{'file'};length=if($_.PSIsContainer){$null}else{$_.Length};lastWriteUtc=$_.LastWriteTimeUtc.ToString('o')}})}}
[ordered]@{schema='argos_o3b9_pull_exact_state_v1';state='PASS_EXACT_FILE_AUDIT';computer=$env:COMPUTERNAME;requestId=$r;ledgerRaw=$ledger;exact=@($p|ForEach-Object{M $_});recent=$recent;processQueriesPerformed=$false;mutationsPerformed=$false}|ConvertTo-Json -Depth 7 -Compress

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($env:COMPUTERNAME-ne'A1025645101'){throw'Wrong host'}
function Get-ExactSha([string]$p){$s=[IO.File]::OpenRead($p);$hsh=[Security.Cryptography.SHA256]::Create();try{([BitConverter]::ToString($hsh.ComputeHash($s))).Replace('-','')}finally{$hsh.Dispose();$s.Dispose()}}
$roots=@('D:\O2D5\ARGOS_O2D5','D:\O2D5','D:\A2\x\O2D5')
$rows=@()
foreach($r in $roots){foreach($n in @('O2D5_REFS.zip','ArgosOpenCvScribeV1.py','PACKAGE_MANIFEST.json')){$p=Join-Path $r $n;if(Test-Path -LiteralPath $p -PathType Leaf){$i=Get-Item -LiteralPath $p;$rows+=@{path=$p;bytes=$i.Length;sha256=(Get-ExactSha $p)}}}}
[ordered]@{schema='argos_r3_installed_o2d5_assets_v2';state='PASS_R3_INSTALLED_O2D5_ASSET_OBSERVATION';computerName=$env:COMPUTERNAME;rows=$rows;imageBytesRead=$false;pixelsDecoded=$false;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Compress -Depth 5

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($env:COMPUTERNAME-ne'A1025645101'){throw'Wrong host'}
$root='D:\A2\x\r3s16_8A6DE04B\parts'
[IO.Directory]::CreateDirectory($root)|Out-Null
$path=Join-Path $root 'p014.bin'
if(Test-Path -LiteralPath $path){throw'Part exists'}
$bytes=[Convert]::FromBase64String('2EBPGrZGqj5pKk1dMZr6WFGamqL8OTEs3fWUti1VqjCZoQSO5kFPKkY7rqsYnm911I7l64ruu4qrtPVm07I9o+10tJatm4rT1kzFVjxTcw27pdoW4/YN33FWrZZq+Zpuabrr6JrTMSzd0DTNszVfVY226Tm2a7edTlNpeZbbUlTTNNuKYbRMxW+1PE9im5hmnJemu76ieK2OpZqa17Gdlqc0da9taorr25qlWFbH61h+27R032+ZSlOxlY5qtBXH8W1XlypVlGQ0iGPOTm0apueoqq+YzWar5bYsy9Ysx2+ruq001aavGp22r5uGb9q207TbnbbRNM2WaTuur5mM3d1UKOa3PdN0DMP3282m2bJ81+m4Lavpm6qqOGqzqTedttPqKB1F02zTtBWt7fmOrrQ8ra06UqUaCU627iiaabc0y9HbrtuxDbfl23an2TIMS1d0Q7EVte01Dd1UVMfybFPTDUPxTcN0Dd1VpUo1JTjFWSD26GidlqE4pqYaHV1VDKXj6LbjaU6raRmG17I0v2167bbuNF3F0QzbtFuOb2iaraqapfhSpZotF4uArDk733UM3XTdptm0VM3VTdu0fcvyFF/pdKyOaXpaS/M122tbbV1tW2rb9VS1bfimaiuayW7zHpPvPck9+2o1v95/xeHq6+ummQaEoiDu8cXvpEb+W6pU8ZKmS1rww2/k9xdKiyUPgnz4PH3jL5QyK1wmFC2gWOc7n9WvhH5N13SOkwZ8gDvbCpirlsj6l6OxdX5ujfuDy8a3DCe5SXOSQdPVvlrDD4PRhD+yP5Oh549yqcIpe58wSupXAZ2D6tVoFBKU0iHGFEgWmeFskMLEWbHhO/hZHbYa6Vp4IFvx/NphazI6H4xVfeL2h54znnwa2IWCiyBBU5jRlzlcWf89H1ju5MK67PveaLzbXraMD9aKuwLS0Btdn29pZwGFz1JeX04+WGOvoIUPMFzySPjMAu8/nnNdPuhpgOIleVaAb/XPr4cF/8p0mfBAC6wsg4TWvYcg')
$stream=[IO.File]::Open($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try{$stream.Write($bytes,0,$bytes.Length)}finally{$stream.Dispose()}
$hash=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash;if($hash-ne'54F181530E38DD5863B2EA317CC91FBB5B37E8E8168380B6CD37D3858E003ACC'){throw'Part hash mismatch'}
[ordered]@{schema='argos_r3s16_transfer_part_v1';state='PASS_R3S16_TRANSFER_PART';part='p014.bin';bytes=$bytes.Length;sha256=$hash;mutationsPerformed=$true;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Compress
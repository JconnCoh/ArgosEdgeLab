$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($env:COMPUTERNAME-ne'A1025645101'){throw'Wrong host'}
$root='D:\A2\x\r3s16_8A6DE04B\parts'
[IO.Directory]::CreateDirectory($root)|Out-Null
$path=Join-Path $root 'p017.bin'
if(Test-Path -LiteralPath $path){throw'Part exists'}
$bytes=[Convert]::FromBase64String('xG6d5pi0shex0a0X5YL2nKiQ83KeOuISfyyDGE1RyKN3o+hKiWTI7rrUp+KewEM9jEAx/rZM8qrgxTKmyBGbGIlW1k6HXW/riQp8Tb2wspzoTeacm93dND9WJoQ3CZkLHaOMypS8CchSCEoSGIGQ4HQvPf8WUpF/qkJL98ozGhAGWrYFWspiaiQiKlrww2Mw4AtKWs3JOZ6hMIhdlH0HdR/FFBJw4sIVCmHfZZ0vVpGUWtuA9bP3UWmyjON6AqsRP7zcNaKGTyAcpUEI6zMItJZudBRTbSoykFwwJRDWMzYJpjHGBLAGEDs4Vsfv+uqPN5hEkMDo9v2jSM+9Z7N8sYil927IzyO6pmHvxg0oHKMFq02vaXiJ7xvbboqEJbmb0YDCnnRljUaTg17b1dDzz/sfPo6l7rZJv23Xd1l9vqSQiHpvH2t3t0iwqelsOv/VFbiOD4rH7vaNgc3RWTGb47cuN00+wp+60fY3f+pmPCT0F8EM2iz+sKooL+FS9ADjzIUhjmBUVIzCRvIycju6WFLui9kVJFNMFmX67PuA5DXfEPLKbTebErxCEeQmsgpKE7v8VyizTVlDvKQomXlJcBdvF2yeaRAYeU20qVRY9VYB4GaFUXTLGwMidrO/PPq73BwwWYuMAAqfkysAWFFU50R1ZsGLu3jNLg6M1hmFi0Z/wLtqBGbsbnkdL2aYvL3JP1Gatzu8B0qCkI7xVnCNX9tpWbCD0/UxNCZMgm0zoygR+LlWApQ5ixf6xy9xz1HSG9hvO8r8lF4K4z+n3EE9NKLBDEYg3/c2XP6C0J3KT0ulXALrqpTYX+AVPAqHc3ZPjogH6yNh76fMLodIFQBYAd170pECxf9FbQ3qeaFY3irX4oXDBXVWFh6u2J0MqIsGAyiVvgdnzXRoFM2LOvwBFBnUpKvcp/PAfAakd5xQdC8aY4IWNfnQWp5LUjv5B0BNynUUQI1dVk79WhGw43lYB+zrtatH+KKDohGnMAlXk4yf8EQQTVZN6QkcyNcW0Z83')
$stream=[IO.File]::Open($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try{$stream.Write($bytes,0,$bytes.Length)}finally{$stream.Dispose()}
$hash=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash;if($hash-ne'87FA77855DBF9648B7C25FEFDCFC2B1C974D51E4F1452F17D242A2CD0AF85B27'){throw'Part hash mismatch'}
[ordered]@{schema='argos_r3s16_transfer_part_v1';state='PASS_R3S16_TRANSFER_PART';part='p017.bin';bytes=$bytes.Length;sha256=$hash;mutationsPerformed=$true;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Compress
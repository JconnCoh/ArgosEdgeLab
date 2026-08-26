$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($env:COMPUTERNAME-ne'A1025645101'){throw'Wrong host'}
$root='D:\A2\x\r3s16_8A6DE04B\parts'
[IO.Directory]::CreateDirectory($root)|Out-Null
$path=Join-Path $root 'p007.bin'
if(Test-Path -LiteralPath $path){throw'Part exists'}
$bytes=[Convert]::FromBase64String('UJ2NrLHkKoXAVG1jOopK2gOUriHOKt2KHkB7ZhYO6XsNnScIQ0ek1ezcwRNzLKW/KVdqIJOhUtkpTw0evUq0oeYmVdN4k8E1Bl3kEcRQI+UqA5KYHHPGmKiVQPpATHOqF32gta95wOoU+keqxLOUJw9VVYrDRCqp/hF3b6nL1OIph+4TTB0YPY25rADskSEGzzf5afqz13HKfT0oFE7o++LJHcY70enE6SiNobSAk5UnpsSYYHLgiB8b63htFzYVkRdhCDOBpuhuUjdVuHhThVh9JTtbyelUdI9LUVDlIhfPRII5iquOjChD7db4r3Bmr3Q/6Tiz4AHN/Af9+BVueyl5vAhklWEybBTz0EUj+hxLulA+y2Jpt8pg6WBjVfHvB8/PgCxvsNiOeTw/aMgU7R87rdMNu7qH1Sf2d0gjPZrLcJ99x/PyzqXCYbV0kLfF2J/jWeWuhswn7nbQRt3Cdi2e5nuJcQNEl4ScQdHQB4+tASuuhsgBxe8SmMoL6BKVUJpfSAkON5RixH8lhh3FIM1IpERM0h4UiL5b0Z4JJnB0q7CagMbdFRQeH1yI8lKt8sUW3RalNOcwItk+xzPwTsC1P9adCO1SXCBmUAYrGrqPvjBIM4pY0ouyyPIryqT5wNW34xAHuXqWq+7kobi7R3Yw4+tSwIjBkpZljdWdAXiXEVzjRO8xksT/Td7qs+Bg9FryFctiNuqP96Y6zhaFhK507oU6bgJy20o9ZM8lM4GabOBTp8LMS+45yBwEaTkkgUW0+0w0U4MguxKIlFg5jNKWvCgSsW7EyY9RknBsmS0c5i/IOSRdeaFK1wRp9ieXUkxQhy3yZB1DmGgcYe7m8Pp2MHZ740EPVR4xFL9AkL7YXaE+sTdKb4ZMSsMBOxN/se18YNFx0mqq9BzkJS+BLaNK1mJllQKb15glUpBX1WmfnbE621Mz4ek6jlKYVZK4CGgcidUQ2HKNykoAb9fAI1c4xxGs+uvz6srkqCfmUFkdFJxKOlrNpBWZ0KnqTJt3')
$stream=[IO.File]::Open($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try{$stream.Write($bytes,0,$bytes.Length)}finally{$stream.Dispose()}
$hash=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash;if($hash-ne'E1B49A206E5787A771A4960D408C398CF2A19EA66E85FBA390D9F4B07740498D'){throw'Part hash mismatch'}
[ordered]@{schema='argos_r3s16_transfer_part_v1';state='PASS_R3S16_TRANSFER_PART';part='p007.bin';bytes=$bytes.Length;sha256=$hash;mutationsPerformed=$true;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Compress
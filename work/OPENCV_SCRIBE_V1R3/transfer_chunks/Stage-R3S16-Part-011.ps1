$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($env:COMPUTERNAME-ne'A1025645101'){throw'Wrong host'}
$root='D:\A2\x\r3s16_8A6DE04B\parts'
[IO.Directory]::CreateDirectory($root)|Out-Null
$path=Join-Path $root 'p011.bin'
if(Test-Path -LiteralPath $path){throw'Part exists'}
$bytes=[Convert]::FromBase64String('vYybPSu4BiF1f39Xrlptt3f1dvj+4+jjxL36eHk7vLkcuJ96l8Mf6NUw8jnAgL1TSs7nSuw91zILT7EprG1/M+c+W0EnsyW8QSbi+gWBaMmqA4eizJKiwAv3TGPZFDU9cOvXodkdD94NxoPr/sDtjz4NxuAqzedY8/y0ECx+tx/hx2tY1G/HPTgl9kfX74YXiP7HOOeCP/AwXq9gjKkO8nzUH4uLQ7H36qbUIJ+ScMcAfJaUV0ORZ+AGrsNMMx6Me9e/qg6Nr8RiGA/+8XE4HvxAt0Zk6tXIVsy+9EKm+EIw8XpE5BORqyJkOOkaDaWu6gWmqE4+XrnvesPLHyH7Ot7LsIIYfD0O9ElZspl+icsDT4JFMMfZ0zT/NTxdTf4xDi9JKClodJss5RnzY64u4YWgVIhM3Yl3agZzhq4HuExOZGVh4qHum8/9DbwgE/jPFe8R1RtpynmEZS4Qm8ItMbjjwl4Lby/LD/4YfQf6J+7PVPWEkqno7J26x7CI11BoCg8bnu/bFIlphiqTr0YYQ/eoN4T4QeR9sB1mvDbSuJtQvLfV6rDC+ygJ0Od4hiYoaVqbygLDWYDcqbk0L+dhcB/MQq5tbB32zgtTClKRuGNZxbsZxOkBKBACsFTJoKaU9CIQIuPkOrtGSWIhaEKM4TaSYmEi+2ldj27dwafe5UeQrHvINQNt6NoXUTDvhuPJbS4HcOOjpjeNtiTwDcTY1nfIxzJWI5XoCPK9YosOF90crE75RCQ0KG39p9dyFtXZ4jlAK2JD9W7aC6ngDkG/Vajae+3wMg6rgFYroRda46wkr+xKKRIoDiAqQ0AYb4/y895MjwK63HD7RJSyQhmtPD5hzUpM4ggjcFUaHApHWb399+VGj64auVw+Xuf264vBp8Hl6AbU2IIt2cp1hL5GJ4k8Pl9wyMxP4epTbV7/fquWyrF5ki0LL0ArRstUQ4JILITR7IFUXlsjwqYaVPtujcCVPcBG3kynMkRn35D8mF3MUsluA7k7lHeF8gFdfUz7')
$stream=[IO.File]::Open($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try{$stream.Write($bytes,0,$bytes.Length)}finally{$stream.Dispose()}
$hash=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash;if($hash-ne'20DD1976447736F5DEA4143CAF8D94250EEE1C1ED7E7F79B0031821C1DB00E53'){throw'Part hash mismatch'}
[ordered]@{schema='argos_r3s16_transfer_part_v1';state='PASS_R3S16_TRANSFER_PART';part='p011.bin';bytes=$bytes.Length;sha256=$hash;mutationsPerformed=$true;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Compress
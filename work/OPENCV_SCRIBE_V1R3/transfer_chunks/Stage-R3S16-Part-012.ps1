$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($env:COMPUTERNAME-ne'A1025645101'){throw'Wrong host'}
$root='D:\A2\x\r3s16_8A6DE04B\parts'
[IO.Directory]::CreateDirectory($root)|Out-Null
$path=Join-Path $root 'p012.bin'
if(Test-Path -LiteralPath $path){throw'Part exists'}
$bytes=[Convert]::FromBase64String('e3k5GhVIPuY36trW5iOrQ21WnfbZK5rCadwlmP+gmGArBotiaX82tyMZQFCWhRxecs7HT9iHxchpz3OHuJCrgP4h5KRQ8awOM53X5lN0jhVvQsR3h4PcgTeeXan3s6MqN7ga4l5wMbp1r3q34+HvckeDF9kNxu6nV+7g917/1r0ZjUtrXLyr+hNPZIfBX+i6D+K36xag8aXZOXC0PgArVqSwNRlO/5JNSrsFgXeLim4Bera4WJDDpdXBF78WbWZe8qUX+W8x+eVGHjtveNLX9uyKSotgy/0haDIQb44L7mPK/erVsMeLLSt8t+u7OHRy1+1FOewYIxHTC3ljeHUftByWCXHDo0ubLkRvky1jacMvLAzxwvlRFO6qG/Y2WbyCtzWrFnsEV9X4gZ0jCqL7w0LH2q7CIxDCeAB9PgK48nb9kHvJBykkqgdChdFgnjf4uT/HM3ivxJrvzTA1gjv1wq54+4P5XnhAfOR1DxNxldXneLbvNQ/0kKibzueR+NnJDBrXK1a8YwIA62DgYxoTKCMJvIcxyXN0QfYv4mQW+D5H8W8fYgOnYs4dc4Kdytl0ilNnXkZyvOuaxqLjtCIYTtOL7lq4WQBE0gZdI181IhUU95fEJOEl2j8cfmSMRc58QrAYYRZmpuyxobDknoShJ1K1Z0p1FwQzJFgMT6rjnVSqquKSymkq07dXNP71dMoWmCCC0vkvug/D27KP7dK0h0Zl2U1UuIUI+LFJre7zcF9PzQ4IO1dRZBCxASxbQfaeF2b8MFUKH1OaZh4MS4lCeRJwYdOxpdnAC1WYp/ot3y4BYmETZoHc0yeb1cpLdgq44pGsV+jGwZFAaqo6v0d6PHFeZCfVGIBkgRL6jhMSGyJGY7ZAo9yigv6y4KEBVjrCRC+1cgwsMmjOljQKiRpA/mtjgDHZc2iVxhhL8lTf0QZdEId7xKch+cqb4F8oYvD2H3gPcUF0VG2KpqW5Ynw+RrlhOBdPHfY17zUMhsw42USgJ0Cv6Ju6ZFoKKTJfpQ4K')
$stream=[IO.File]::Open($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try{$stream.Write($bytes,0,$bytes.Length)}finally{$stream.Dispose()}
$hash=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash;if($hash-ne'C45569F393518E7B664D16A09F37ED0C1C63F1F38D5BEDE7EE41EB4E183D3EED'){throw'Part hash mismatch'}
[ordered]@{schema='argos_r3s16_transfer_part_v1';state='PASS_R3S16_TRANSFER_PART';part='p012.bin';bytes=$bytes.Length;sha256=$hash;mutationsPerformed=$true;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Compress
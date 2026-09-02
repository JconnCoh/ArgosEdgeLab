$ErrorActionPreference='Stop'
function Clip([string]$value){if($null-eq$value){return ''};if($value.Length-gt1500){return $value.Substring($value.Length-1500)};return $value}
$stderr=Get-Content -LiteralPath 'D:\R32C953\runner.stderr.log' -Tail 30 -ErrorAction SilentlyContinue|Out-String
$stdout=Get-Content -LiteralPath 'D:\R32C953\runner.stdout.log' -Tail 30 -ErrorAction SilentlyContinue|Out-String
$top=@(Get-ChildItem -LiteralPath 'D:\R32C953' -Force -ErrorAction SilentlyContinue|Sort-Object Name|Select-Object -First 20|ForEach-Object{[ordered]@{n=$_.Name;d=$_.PSIsContainer;b=if($_.PSIsContainer){0}else{$_.Length};t=$_.LastWriteTimeUtc.ToString('o')}})
$dirs=@(Get-ChildItem -LiteralPath 'D:\R32C953\i' -Directory -ErrorAction SilentlyContinue)
[ordered]@{schema='argos_r32c953_failure_observation_v2';stderr=Clip $stderr;stdout=Clip $stdout;top=$top;itemCount=$dirs.Count;firstItems=@($dirs|Sort-Object Name|Select-Object -First 3 -ExpandProperty Name);mutationsPerformed=$false;imageBytesRead=$false}|ConvertTo-Json -Depth 5 -Compress

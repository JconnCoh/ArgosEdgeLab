$ErrorActionPreference='Stop'
if($env:COMPUTERNAME-ne'A1025645101'){throw'Wrong host'}
$ps=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$result=& $ps -NoProfile -ExecutionPolicy Bypass -File 'D:\A2\x\r3s16r3_8A6DE04B\ctl\StagePart.ps1' -Part 'p025.bin' -Data 'Nl9ESVJFQ1RfSk9CLmpzb25QSwUGAAAAAAQABAAXAQAAmkAAAAAA' -ExpectedSha '5FB2E6A025AE121757D020B2F5B0DA7616ADE1D44B3457B44E27A88882A88E6E'
if($LASTEXITCODE-ne 0-or$result-ne'PASS_R3S16R3_PART|p025.bin|5FB2E6A025AE121757D020B2F5B0DA7616ADE1D44B3457B44E27A88882A88E6E'){throw'Writer result'}
$result